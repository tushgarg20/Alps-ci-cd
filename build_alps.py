import lib.argparse
import lib.yaml as yaml
import re
import os
import sys
import subprocess
import string
import zipfile
import gzip
from copy import deepcopy
import numpy as np
from scipy.interpolate import pchip_interpolate
#############################
# Command Line Arguments
#############################
##def files_callback(option,opt,value,parser):
##    setattr(parser.values,option.dest,value.split(" "))

#### Gets options from command line
parser = lib.argparse.ArgumentParser(description='This tool builds ALPS-G (Architecture Level Power Simultor - Graphics) Models')
parser.add_argument('-v','--voltage',dest="operating_voltage",
           help="Operating Voltage of the architecture")
parser.add_argument('-s','--voltage_cdyn_sf',dest="voltage_cdyn_scaling_factor",
           help="Voltage dependant Cdyn scaling factor (0-1)")
parser.add_argument('-i','--input',dest="input_file",
           help="Input file containing path to all input files")
parser.add_argument('-r','--residency',dest="residency_file",
           help="Name of input Residency file")
parser.add_argument('-t','--timegraph',dest="timegraph_file",
           help="Name of input Timegraph file")
parser.add_argument('-o','--output',dest="output_file",
           help="Name of output YAML file")
parser.add_argument('-z','--timegraph_output',dest="output_timegraph_file",
           help="Name of timegraph output file")
parser.add_argument('-a','--architecture',dest="dest_config",
           help="Specify Gsim Config used for run. For e.g. bdw_gt2.cfg")
parser.add_argument('--debug',action="store_true",dest="run_debug",default=False,
           help="Run build_alps in debug mode [default: %sdefault]" % "%%")
parser.add_argument('--gc',action="store_true",dest="dump_gc",default=False,
           help="Dump gate counts in output files [default: %sdefault]" % "%%")
parser.add_argument('--bcw',action="store_true",dest="dump_cw",default=False,
           help="Dump base cdyn weights [default: %sdefault]" % "%%")
parser.add_argument('--ecw',action="store_true",dest="dump_ecw",default=False,
           help="Dump eff cdyn weights [default: %sdefault]" % "%%")
parser.add_argument('-m','--method', dest="method",default=False,
           help="run alps method [default: %sdefault]" % "%%")
options = parser.parse_args()

print ("**********************************")
print ("****** Trekking the ALPS!!! ******")
print ("**********************************")

#################################
# Global Variables
#################################

I = {} ### Instance Hash
C = {} ### Effective Cdyn

#cdyn_precedence_selector()
# Input: cfg - the name of the arch cfg e.g: Gen12HP, PVC etc
# Returns the list of arch config precedence for a given arch config
def cdyn_precedence_selector(cfg):
  if cfg == 'ADL':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'ADL' ], 'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','ADL']}
  elif cfg =='DG2':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2' ],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2',] }
  elif cfg =='Xe2':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','Xe2'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','Xe2'] }
  elif cfg =='Xe2_Plan':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','Xe2_Plan'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','Xe2_Plan'] }
  elif cfg =='Xe2_BNA4_Plan':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','Xe2_Plan', 'Xe2_BNA4_Plan'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','Xe2_Plan', 'Xe2_BNA4_Plan'] }
  elif cfg =='Xe2_HPG':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','Xe2'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','Xe2'] }
  elif cfg =='DG2p5':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2', 'DG2p5',],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','DG2p5',] }
  elif cfg =='MTL':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','MTL' ],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','MTL'] }
  elif cfg =='LNL':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','MTL','LNL' ],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2', 'MTL','LNL'] }
  elif cfg =='CPL':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','MTL','LNL', 'CPL' ],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2', 'MTL','LNL', 'CPL'] }
  elif cfg =='PTL':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2', 'MTL','LNL', 'PTL' ],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2', 'MTL', 'LNL','PTL'] }
  elif cfg =='Xe3':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'Xe3' ],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'Xe3'] }
  elif cfg =='PVCDP':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP' ],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP'] }
  elif cfg =='PVCXT':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'PVCXT' ],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'PVCXT'] }
  elif cfg =='PVCXTTrend':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend'] }
  elif cfg =='RLT1':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend', 'RLT1'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend','RLT1'] }
  elif cfg =='Xe3_XPC':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend', 'RLT1', 'Xe3_XPC'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend','RLT1', 'Xe3_XPC'] }
  elif cfg =='Xe3_FCS_SW':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend', 'RLT1', 'Xe3_FCS', 'Xe3_FCS_SW'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend','RLT1', 'Xe3_FCS', 'Xe3_FCS_SW'] }

  elif cfg =='Xe3_FCS':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend', 'RLT1', 'Xe3_FCS'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend','RLT1', 'Xe3_FCS'] }
  elif cfg =='RLTCONCEPT':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'RLTCONCEPT'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'RLTCONCEPT'] }
  elif cfg =='RLTB_EC_0_5':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC','PVCDP', 'PVCXT','PVCXTTrend', 'RLTB_EC_0_5'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC','PVCDP','PVCXT','PVCXTTrend','RLTB_EC_0_5'] }
  elif cfg =='PVCK2xSA':
      cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC', 'PVCDP', 'PVCXT', 'PVCK2xSA'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP','DG2','PVC', 'PVCDP', 'PVCXT', 'PVCK2xSA'] }
  else:
    cdyn_precedence_hash = {'client': ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2', 'PVC_Scaled','PVC','PVC_A21','PVCDP','PVC2'],
        	                'lp': ['Gen7','Gen7.5','Gen8','Gen8SoC','Gen9LPClient','Gen9LPSoC','Gen10LP','Gen10LPSoC','Gen11LP','Gen11','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'DG2','PVC_Scaled','PVC','PVC_A21','PVCDP','PVC2']
                       }
  return(cdyn_precedence_hash) 

new_gc = {}         ##Gate Count
process_hash = {}   ##Process
voltage_hash = {}   ##Voltage scaling factor

##Used for parsing scaling factor files
cdyn_cagr_hash = {'syn':{},'ebb':{}}
unit_cdyn_cagr_hash ={}
gc_scaling_cfg_hash ={}
stepping_hash = {}

common_cfg = options.dest_config.lower() ##Config chosen

#path = []
paths = []
linest_coeff = {}

log_file     = options.output_file + ".log"
debug_file   = options.output_file + ".cdyn.log"
patriot_file = options.output_file + ".patriot"

if (options.dump_cw):
    weights_file = options.output_file + ".base_weights.csv"
    wf = open(weights_file,'w')
if (options.dump_ecw):
    eff_weights_file = options.output_file + ".eff_weights.csv"
    eff_wf = open(eff_weights_file,'w')

###Print basic details in log file
lf = open(log_file,'w')
if (options.run_debug):
    df = open(debug_file,'w')
    print("Weight,Config,Stepping",file=df)

if common_cfg.find('bdw') > -1 :
    cfg ='Gen8'
elif common_cfg.find('skl') > -1 :
    cfg ='Gen9LPClient'
elif common_cfg.find('kbl') > -1 :
    cfg ='Gen9.5LP'
elif common_cfg.find('chv') > -1 :
    cfg ='Gen8SoC'
elif common_cfg.find('bxt') > -1 :
    cfg ='Gen9LPSoC'
elif common_cfg.find('glv') > -1 :
    cfg ='Gen9LPSoC'    
elif common_cfg.find('cnl_h') > -1 :
    cfg ='Gen11'
elif common_cfg.find('cnl') > -1 :
    cfg ='Gen10LP'
elif common_cfg.find('owf') > -1 :
    cfg ='Gen10LPSoC'
elif common_cfg.find('icllp') > -1  or common_cfg.find('icl_gen11_1x8x8') > -1:
    cfg ='Gen11LP'
elif common_cfg.find('icl') > -1 :
    cfg ='Gen11'
elif common_cfg.find('pvc_scaled') > -1 :
    cfg ='PVC_Scaled'   
elif common_cfg.find('pvc_a21') > -1 :
    cfg ='PVC_A21'   
elif common_cfg.find('pvc2') > -1 :
    cfg ='PVC2'   
elif common_cfg.find('pvcdp') > -1 :
    cfg ='PVCDP'   
elif common_cfg.find('pvcxttrend') > -1 :
    cfg ='PVCXTTrend'
elif common_cfg.find('rlt1') > -1 :
    cfg ='RLT1' 
elif common_cfg.find('xe3_fcs_sw') > -1 :
    cfg ='Xe3_FCS_SW'   
elif common_cfg.find('xe3_fcs') > -1 :
    cfg ='Xe3_FCS'    
elif common_cfg.find('xe3_xpc') > -1 :
    cfg ='Xe3_XPC'    
elif common_cfg.find('pvcxt') > -1 :
    cfg ='PVCXT'   
elif common_cfg.find('rltconcept') > -1 :
    cfg ='RLTCONCEPT'   
elif common_cfg.find('rltb_ec_0_5') > -1 :
    cfg ='RLTB_EC_0_5'   
elif common_cfg.find('pvck2xsa') > -1 :
    cfg ='PVCK2xSA'   
elif common_cfg.find('mtl') > -1 :
    cfg ='MTL'   
elif common_cfg.find('tglhp_512') > -1 :
    cfg ='Gen12HP_512'
elif common_cfg.find('tglhp_384') > -1 :
    cfg ='Gen12HP_384'
elif common_cfg.find('tglhp') > -1 or common_cfg.find('ats') > -1:
    cfg ='Gen12HP'
elif common_cfg.find('pvc') > -1 :
    cfg ='PVC'
elif common_cfg.find('tgldg') > -1 :
    cfg ='Gen12DG'
elif common_cfg.find('dg2p5') > -1 :
    cfg ='DG2p5'
elif common_cfg.find('lnl') > -1 :
    cfg ='LNL'
elif common_cfg.find('ptl') > -1 :
    cfg ='PTL'
elif common_cfg.find('cpl') > -1 :
    cfg ='CPL'
elif common_cfg.find('xe3') > -1 :
    cfg ='Xe3'
elif common_cfg.find('xe2_bna4_plan') > -1 :
    cfg ='Xe2_BNA4_Plan'
elif common_cfg.find('xe2_plan') > -1 :
    cfg ='Xe2_Plan'
elif common_cfg.find('dg2') > -1 :
    cfg ='DG2'
elif common_cfg.find('tgllp') > -1 :
    cfg ='Gen12LP'
elif common_cfg.find('adl') > -1 :
    cfg ='ADL'
elif common_cfg.find('xe2') > -1 :
    cfg ='Xe2'
elif common_cfg.find('tgl') > -1 :
    cfg ='Gen12LP'

else:
    print (cfg, "--> Config not supported\n");
    print("Command Line -->",file=lf)
    print (" ".join(sys.argv),file=lf)
    print("",file=lf)
    print ("Config not Supported",file=lf)
    print("Exit",file=lf)
    lf.close()
    exit(2);
if common_cfg.find('cnl_h') > -1 :
    cfg_gc = "Gen11halo"
elif common_cfg.find('icllp') > -1 or common_cfg.find('icl_gen11_1x8x8') > -1 :
    cfg_gc = "Gen11LP"
elif common_cfg.find('tgllpall') > -1 :
    cfg_gc = "Gen12LPAllGc"
elif common_cfg.find('tgllppwr') > -1 :
    cfg_gc = "Gen12LPPwrGc"
elif common_cfg.find('tglhp_512') > -1 :
    cfg_gc ='Gen12HP_512'
elif common_cfg.find('tglhp_384') > -1 :
    cfg_gc ='Gen12HP_384'
elif common_cfg.find('tglhp') > -1 or common_cfg.find('ats') > -1:
    cfg_gc = "Gen12HP"
elif common_cfg.find('pvc') > -1 :
    cfg_gc = "PVC"
elif common_cfg.find('pvc2') > -1 :
    cfg_gc = "PVC2"
elif common_cfg.find('pvcdp') > -1 :
    cfg_gc = "PVCDP"
elif common_cfg.find('pvcxt') > -1 :
    cfg_gc = "PVCXT"
elif common_cfg.find('pvcxttrend') > -1 :
    cfg_gc = "PVCXTTrend"
elif common_cfg.find('rlt1') > -1 :
    cfg_gc = "RLT1"
elif common_cfg.find('xe3_fcs') > -1 :
    cfg_gc = "Xe3_FCS"
elif common_cfg.find('xe3_fcs_sw') > -1 :
    cfg_gc = "Xe3_FCS_SW"
elif common_cfg.find('xe3_xpc') > -1 :
    cfg_gc = "Xe3_XPC"
elif common_cfg.find('rltconcept') > -1 :
    cfg_gc = "RLTCONCEPT"
elif common_cfg.find('rltb_ec_0_5') > -1 :
    cfg_gc = "RLTB_EC_0_5"
elif common_cfg.find('pvck2xsa') > -1 :
    cfg_gc = "PVCK2xSA"
elif common_cfg.find('mtl') > -1 :
    cfg_gc = "MTL"
elif common_cfg.find('lnl') > -1 :
    cfg_gc = "LNL"
elif common_cfg.find('ptl') > -1 :
    cfg_gc = "PTL"
elif common_cfg.find('cpl') > -1 :
    cfg_gc = "CPL"
elif common_cfg.find('tgllp') > -1 :
    cfg_gc = "Gen12LP"
elif common_cfg.find('tgl') > -1 :
    cfg_gc = "Gen12LP"
elif common_cfg.find('tgldg') > -1 :
    cfg_gc = "Gen12LP"
elif common_cfg.find('dg2p5') > -1 :
    cfg_gc = "DG2p5"
elif common_cfg.find('xe3') > -1 :
    cfg_gc = "Xe3"
elif common_cfg.find('xe2_bna4_plan') > -1 :
    cfg_gc = "Xe2_BNA4_Plan"
elif common_cfg.find('xe2_plan') > -1 :
    cfg_gc = "Xe2_Plan"
elif common_cfg.find('xe2') > -1 :
    cfg_gc = "Xe2"
elif common_cfg.find('dg2') > -1 :
    cfg_gc = "DG2"
elif common_cfg.find('adl') > -1 :
    cfg_gc = "ADL"
elif common_cfg.find('glv') > -1 :
    cfg_gc = "Gen9LPglv"
else:
    cfg_gc = cfg

print(" ")

print("Command Line -->",file=lf)
print(" ".join(sys.argv),file=lf)
print("",file=lf)

#Select the appropriate CDYN selector list 
cdyn_precedence_hash = cdyn_precedence_selector(cfg)
if(cfg == 'Gen8' or cfg == 'Gen9LPClient' or cfg == 'Gen9.5LP' or cfg == 'Gen10LP' or cfg == 'Gen11' or cfg == 'Gen11LP' or cfg == 'Gen12LP' or cfg == 'ADL' or cfg == 'Gen12DG' or cfg == 'Gen12HP' or cfg =='PVC'or cfg == 'DG2' or cfg == 'DG2p5' or cfg =='PVC2' or cfg =='MTL'or cfg == 'LNL'or cfg =='PTL' or cfg == 'CPL' or cfg =='PVCDP' or cfg == 'Xe2' or cfg == 'Xe2_Plan' or cfg == 'Xe2_BNA4_Plan' or cfg == 'Xe3' or cfg == 'PVCXT' or cfg == 'PVCXTTrend' or cfg == 'RLT1' or cfg == 'Xe3_FCS' or cfg == 'Xe3_FCS_SW' or cfg == 'Xe3_XPC' or cfg == 'RLTCONCEPT' or cfg == 'PVCK2xSA' or cfg == 'RLTB_EC_0_5' or cfg == 'Xe2_HPG'):
    cdyn_precedence = cdyn_precedence_hash['client']
else:
    cdyn_precedence = cdyn_precedence_hash['lp']
scripts_dir = os.path.abspath(os.path.dirname(__file__))

print("Running scripts from: " + scripts_dir)

#################################
# Subroutines
#################################
def get_data(line, separator):
    res = line.split(separator)
    i = 0
    while(i < len(res)):##looping to get rid of the "\n"
        res[i] = res[i].strip()
        i = i + 1
    return res

def dfs(adict, paths, path=[]):
    if(type(adict) is not dict):
        path.append(adict)
        paths.append(path + [])
        path.pop()
        return
    for key in adict:
        path.append(key)
        dfs(adict[key],paths,path)
        if(path):
            path.pop()
    return

def split_string(source, splitlist):
    index = 0
    flag = True
    result = []
    word = ""
    while(index < len(source)):
        char = source[index]
        if char in splitlist:
            if(word):
                result.append(word)
                word = ""
            result.append(char)
            char = ""

        word = word + char
        index = index + 1
    if(word):
        result.append(word)
    return result

def get_base_config(stat):
    if(stat not in cdyn_hash):
        print ("No cdyn weight is available for", stat, file=lf)
        return None,None
    i = cdyn_precedence.index(cfg)
    while(i >= 0):
        config = cdyn_precedence[i]
        if(config in cdyn_hash[stat]):
            if('C0' in cdyn_hash[stat][config]):
                return config,'C0'
            if('B0' in cdyn_hash[stat][config]):
                return config,'B0'
            elif('A0' in cdyn_hash[stat][config]):
                return config,'A0'
            else:
                print ("Stepping is unknown for", stat, " for config - ", config, file=lf)
                return config, None
        i = i-1

    print ("Not able to find matching cdyn weight for", stat, file=lf)
    return None,None

def Cdyn_VSF(current_operating_voltage, prev_gen_operating_voltage,cdyn_reduction_factor_per_volt):
    if (current_operating_voltage < prev_gen_operating_voltage):
        scaling_factor = 1 - cdyn_reduction_factor_per_volt * (prev_gen_operating_voltage - current_operating_voltage)
    else:
        scaling_factor = 1/(1 - cdyn_reduction_factor_per_volt * abs(prev_gen_operating_voltage - current_operating_voltage))
    return scaling_factor

def get_eff_cdyn(cluster,unit,stat):
    base_cfg,stepping = get_base_config(stat)
    if(base_cfg == None or stepping == None):
        return 0
    if(options.run_debug):
        print ("{0},{1},{2}".format(stat,base_cfg,stepping),file=df)
        print (stat,",",base_cfg,",",stepping,file=df)
    base_cdyn = cdyn_hash[stat][base_cfg][stepping]['weight']
    cdyn_type = cdyn_hash[stat][base_cfg][stepping]['type']
    ref_gc    = cdyn_hash[stat][base_cfg][stepping]['ref_gc']

    if(ref_gc == ''): #If ref gc is not present in cdyn sheet, picking it from gc sheet
        if(cdyn_type == 'syn'):
            if((cluster not in new_gc) or (unit not in new_gc[cluster]) or (base_cfg not in new_gc[cluster][unit])):
                print ("Reference gate count is not available for", cluster, ",", unit, file=lf)
                ref_gc = 0
            else:
                ref_gc = new_gc[cluster][unit][base_cfg]
        else:
            ref_gc = 1
    if(cdyn_type == 'syn'):
        #print(base_cfg, cfg)
        process_sf = process_hash[base_cfg][cfg]['syn']
    else:
        process_sf = process_hash[base_cfg][cfg]['ebb']
    if(process_sf == 'NA'):
        process_sf = 0

    ##voltage scaling information
    if(options.operating_voltage):
        voltage_sf = Cdyn_VSF(float(options.operating_voltage),new_voltage_hash[base_cfg],voltage_cdyn_scaling_factor_hash[cfg])
    else:
        voltage_sf = Cdyn_VSF(new_voltage_hash[cfg],new_voltage_hash[base_cfg],voltage_cdyn_scaling_factor_hash[cfg])
    ##print (cfg, base_cfg)
    ##voltage_sf = voltage_hash[base_cfg][cfg]
    ##if(voltage_sf == 'NA'):
    ##    voltage_sf = 0

    stepping_sf = stepping_hash[base_cfg][stepping]['C0'] if (stepping =='A0' or stepping == 'B0') else 1
    try:
        unit_scalar = float (unit_cdyn_cagr_hash[unit][cluster][base_cfg][cfg])
    except:
        unit_scalar = 1
    #print (cluster,base_cfg,cfg,unit_scalar)
    cdyn_cagr_sf = cdyn_cagr_hash[cdyn_type][cluster][base_cfg][cfg] * unit_scalar
    instances = 0
    newproduct_gc = 1
    instance_string = cluster + "_" + unit
    if(instance_string not in I):
        print ("Number of instances for", unit, "are unknown",file=lf)
        instances = 0
    else:
        instances = I[instance_string]
    if(cdyn_type == 'syn'):
        #print(cluster, unit,cfg_gc)
        if((cluster not in new_gc) or (unit not in new_gc[cluster]) or (cfg_gc not in new_gc[cluster][unit])):
            print ("Gate count is not available for", cluster, ",", unit, file=lf)
            newproduct_gc = 0
        else:
            newproduct_gc = new_gc[cluster][unit][cfg_gc]
    else:
        newproduct_gc = 1

    gc_sf = newproduct_gc/ref_gc if ref_gc > 0 else 0

    try:
        gc_scalar_bool = gc_scaling_cfg_hash[cluster][base_cfg][cfg]
    except:
        gc_scalar_bool = 'True'

    if(gc_scalar_bool == 'False' or gc_scalar_bool == 'True'): # by default putting gc scaler 1 as we are not doing any gatecount based scaling
        gc_sf = 1.0
	
    eff_cdyn = base_cdyn*instances*gc_sf*process_sf*voltage_sf*stepping_sf*cdyn_cagr_sf
    e_cdyn = base_cdyn*gc_sf*process_sf*voltage_sf*stepping_sf*cdyn_cagr_sf
    if (options.dump_cw):
        print (str(stat)+","+str(base_cfg)+","+str(base_cdyn),file=wf)
    if (options.dump_ecw):
        print (str(stat)+","+str(base_cfg)+","+str(e_cdyn),file=eff_wf)
        print (str(stat)+","+str(base_cfg)+","+str(gc_sf)+","+str(process_sf)+","+str(voltage_sf)+","+str(stepping_sf)+","+str(cdyn_cagr_sf)+","+str(e_cdyn),file=eff_wf)

    return eff_cdyn

def which_cfg_to_use(track_cfg):
    base_i = cdyn_precedence.index(cfg)
    cfg_list = []
    stepping_hash = {}
    for pair in track_cfg:
        if ((pair[0] not in cdyn_precedence) or (pair[1] != 'A0' and pair[1] != 'B0' and pair[1] != 'C0')):
            continue
        i = cdyn_precedence.index(pair[0])
        if ((i <= base_i) and (i not in cfg_list)):
            cfg_list.append(i)
            if(pair[0] not in stepping_hash):
                stepping_hash[pair[0]] = []
            stepping_hash[pair[0]].append(pair[1])

    if(len(cfg_list) == 0):
        return None,None
    use_cfg = cdyn_precedence[max(cfg_list)]
    if(len(stepping_hash[use_cfg]) == 0):
        return None,None
    use_stepping = max(stepping_hash[use_cfg])
    return use_cfg,use_stepping

def get_linest_coeff(data_points):
    slope,intercept = 0,0
    sigma_xy = 0
    sigma_sqrx = 0
    sigma_x = 0
    sigma_y = 0
    n = len(data_points)
    for elem in data_points:
        sigma_x += elem[0]
        sigma_y += elem[1]
        sigma_xy += elem[0] * elem[1]
        sigma_sqrx += elem[0]**2
    mean_x = sigma_x/n
    mean_y = sigma_y/n
    slope = (sigma_xy - (n * mean_x * mean_y))/(sigma_sqrx - (n * mean_x * mean_x))
    intercept = mean_y - (slope * mean_x)
    return slope,intercept

def cdyn_from_toggle_rate(data_points, res):
    data_points1 = np.array(data_points)
    data_points = data_points1[data_points1[:,0].argsort()]
    x, y = data_points[:,0], data_points[:,1]
    if res < x[0]:
        return y[0] - (((y[1] - y[0]) / (x[1] - x[0])) * (x[0] - res))
    elif res > x[-1]:
        return y[-1] + (res - x[-1]) * ((y[-1] - y[-2]) / (x[-1] - x[-2]))
    else: 
        y1 = pchip_interpolate(x, y, [res])
        return y1[0] 



def eval_linest(key_tuple,cluster,unit):
    k_cdyn, k_res = key_tuple[0],key_tuple[1]
    if(k_res not in R):
        print ("Residency for", k_res, "is not there!!",file=lf)
        return 0
    if(k_cdyn in linest_coeff):
        return (linest_coeff[k_cdyn]['slope']*R[k_res] + linest_coeff[k_cdyn]['intercept'])

    cdyn_list = []
    data_points = []
    track_cfg = []

    for cdyn in cdyn_hash:
        if(re.search(k_cdyn+'_\d+%',cdyn) and cdyn not in cdyn_list):
            cdyn_list.append(cdyn)
            for config in cdyn_hash[cdyn]:
                for stepping in cdyn_hash[cdyn][config]:
                    if((config,stepping) not in track_cfg):
                        track_cfg.append((config,stepping))

    #print("{0}: {1}".format(k_cdyn,track_cfg))
    use_cfg,use_stepping = which_cfg_to_use(track_cfg)
    if(use_cfg == None or use_stepping == None):
        print("No toggle rate cdyn number is available for ",k_cdyn,file=lf)
        return 0
    #print(cfg,stepping)

    for cdyn in cdyn_list:
        if(use_cfg not in cdyn_hash[cdyn] or use_stepping not in cdyn_hash[cdyn][use_cfg]):
            continue
        cdyn_val = get_eff_cdyn(cluster,unit,cdyn)
        base_config,stepping = get_base_config(cdyn) 
        matchObj = re.search(k_cdyn+'_(\d+)%',cdyn)
        x_val = float(matchObj.group(1))/100
        #if(cdyn_val > 0):
        data_points.append([x_val,cdyn_val])


    if(len(data_points) == 0):
        return 0
    if(len(data_points) == 1):
        if (options.dump_ecw):
            print (str(k_cdyn)+","+str(base_config)+","+str(data_points[0][1]/I[cluster+"_"+unit]),file=eff_wf)
        if (options.dump_cw):
            print (str(k_cdyn)+","+str(base_config)+","+str(data_points[0][1]/I[cluster+"_"+unit]),file=wf)
        return data_points[0][1]
    #linest_coeff[k_cdyn] = {'slope':0,'intercept':0}
    #linest_coeff[k_cdyn]['slope'],linest_coeff[k_cdyn]['intercept'] = get_linest_coeff(data_points)
    eff_cdyn_tr = cdyn_from_toggle_rate(data_points, R[k_res])
    #temp = 0
    #temp = (linest_coeff[k_cdyn]['slope']*R[k_res] + linest_coeff[k_cdyn]['intercept']) / I[cluster+"_"+unit]
    if (options.dump_ecw):
        print (str(k_cdyn)+","+str(base_config)+","+str(eff_cdyn_tr / I[cluster+"_"+unit]),file=eff_wf)
    if (options.dump_cw):
        print (str(k_cdyn)+","+str(base_config)+","+str((linest_coeff[k_cdyn]['slope']*R[k_res] + linest_coeff[k_cdyn]['intercept']) / I[cluster+"_"+unit]),file=wf)
    #return (linest_coeff[k_cdyn]['slope']*R[k_res] + linest_coeff[k_cdyn]['intercept'])
    return eff_cdyn_tr
def eval_formula(alist):
    result = 0
    formula = alist[-1]
    formula = "".join(formula.split())
    power_stat = alist[-2]
    cluster = alist[0]
    unit = alist[1]
    formula_data = split_string(formula,"+-/*()")
    cdyn_vars = []
    res_vars = []
    linest_vars = []
    i = 0
    while(i < len(formula_data)):
        if(formula_data[i] == 'R'):
            formula_data[i] = 'R['+power_stat+']'
            res_vars.append(formula_data[i])
        elif(formula_data[i] == 'C'):
            formula_data[i] = 'C['+power_stat+']'
            cdyn_vars.append(formula_data[i])
        elif(re.search(r'^R\[.*\]',formula_data[i])):
            res_vars.append(formula_data[i])
        elif(re.search(r'^C\[.*\]',formula_data[i])):
            cdyn_vars.append(formula_data[i])
        elif(re.search(r'^LINEST\[.*,.*\]',formula_data[i])):
            matchObj = re.search(r'^LINEST\[(.*),(.*)\]',formula_data[i])
            cdyn_var = matchObj.group(1)
            res_var = matchObj.group(2)
            if(cdyn_var == 'C'):
                cdyn_var = 'C['+power_stat+']'
            if(res_var == 'R'):
                res_var = 'R['+power_stat+']'
            linest_vars.append((i,(cdyn_var,res_var)))
        i = i+1

    for elem in res_vars:
        key = split_string(elem,"[]")[2]
        if(key not in R):
            print ("Residency for", key, "is not there!!", file=lf)
            return 0

    for elem in cdyn_vars:
        key = split_string(elem,"[]")[2]
        C[key] = get_eff_cdyn(cluster,unit,key)

    for elem in linest_vars:
        c_key = split_string(elem[1][0],"[]")[2]
        r_key = split_string(elem[1][1],"[]")[2]
        formula_data[elem[0]] = str(eval_linest((c_key,r_key),cluster,unit))

    formula = "".join(formula_data)
    formula = formula.replace("[","['")
    formula = formula.replace("]","']")
    result = eval(formula)
    return result

def dump_patriot_output():
    pf = open(patriot_file,'w')
    print('{0} {1}'.format('FPS',gt_cdyn['FPS']),file=pf)
    for key in key_stats['key_stats']:
        print('{0} {1}'.format(key,key_stats['key_stats'][key]),file=pf)
    print('{0} {1}'.format('Cdyn',gt_cdyn['Total_GT_Cdyn(nF)']*1000),file=pf)
    for cluster in output_cdyn_data['GT']:
        if(cluster == 'cdyn'):
            continue
        stat_str = cluster
        print('{0} {1}'.format(stat_str+'.Cdyn',float('%.3f'%output_cdyn_data['GT'][cluster]['cdyn'])),file=pf)
        for unit in output_cdyn_data['GT'][cluster]:
            if(unit == 'cdyn'):
                continue
            stat_str = cluster + '.' + unit
            print('{0} {1}'.format(stat_str+'.Cdyn',float('%.3f'%output_cdyn_data['GT'][cluster][unit]['cdyn'])),file=pf)
            power_list = []
            dfs(output_yaml_data['ALPS Model(pF)']['GT'][cluster][unit],power_list)
            #print(power_list)
            for state in power_list:
                stat_str = cluster + '.' + unit
                length = len(state)
                for i in range(0,length-1):
                    if(i == length-2):
                        if(state[i] == 'total'):
                            stat_str = stat_str + '.Cdyn'
                        else:
                            stat_str = stat_str + '.' + state[i] + '.Cdyn'
                    else:
                        stat_str = stat_str + '.' + state[i]
                print('{0} {1}'.format(stat_str,state[-1]),file=pf)
    pf.close()


####################################
## Parsing Build ALPS Config File

## --Config file lists paths to various input files
####################################

input_hash = {}
infile = open(options.input_file,'r')
for line in infile:
    data = get_data(line,"=")
    if (data[1].find("/") == 0):
        input_hash[data[0]] = data[1]
    else:
        input_hash[data[0]] = scripts_dir + "/" + data[1]

##############################
# Parsing Residency File and storing data in a hash
##############################
R = {}
resfile = open(options.residency_file,'r')
for line in resfile:
    data = get_data(line,",")
    test = data[0]
    if(re.search(r'^num_.*',test)):
        key_data = test.split("_")
        del(key_data[0])
        I["_".join(key_data)] = float(data[1])
    else:
        if(data[1] == 'n/a' or float(data[1]) < 0):
            R[data[0]] = 0
        else:
            R[data[0]] = float(data[1])
resfile.close()


##############################
# Parsing Cdyn File
##############################
cdyn_hash  = {}
cdyn_file  = open(input_hash['Cdyn'],'r') ##Getting Cdyn file path from hash
first_line = cdyn_file.readline()  ##never used again - used to only move down a line
for line in cdyn_file:
    data = get_data(line,",")
    #print(data)
    if(data[0] not in cdyn_hash):
        cdyn_hash[data[0]] = {}
    if(data[1] not in cdyn_hash[data[0]]):
        cdyn_hash[data[0]][data[1]] = {}
    if(data[2] not in cdyn_hash[data[0]][data[1]]):
        cdyn_hash[data[0]][data[1]][data[2]] = {}
    cdyn_hash[data[0]][data[1]][data[2]]['weight'] = float(data[3])
    cdyn_hash[data[0]][data[1]][data[2]]['type'] = data[4]
    cdyn_hash[data[0]][data[1]][data[2]]['ref_gc'] = float(data[5])
cdyn_file.close()

################################
# Parsing Gate Count File
################################
gc_file = open(input_hash['GateCount'],'r')
header_line = gc_file.readline()
header_data = get_data(header_line,",")[2:]
for line in gc_file:
    data = get_data(line,",")
    length = len(data)
    if(data[1] not in new_gc):
        new_gc[data[1]] = {}
    if(data[0] not in new_gc[data[1]]):
        new_gc[data[1]][data[0]] = {}
    for i in range(2,length):
        new_gc[data[1]][data[0]][header_data[i-2]] = float(data[i])
gc_file.close()

################################
# Parsing Scaling Factor Files
################################
# Process Scaling Factor
process_file = open(input_hash['Process_Scaling_Factors'],'r')
first_line   = process_file.readline()
for line in process_file:
    data = get_data(line,",")
    if(data[0] not in process_hash):
        process_hash[data[0]] = {}
    if(data[1] not in process_hash[data[0]]):
        process_hash[data[0]][data[1]] = {'syn':{},'ebb':{}}
    process_hash[data[0]][data[1]]['syn'] = float(data[2]) if data[2] != 'NA' else data[2]
    process_hash[data[0]][data[1]]['ebb'] = float(data[3]) if data[3] != 'NA' else data[3]
process_file.close()

# the voltage.csv file has only the configs and their default operating voltages
new_voltage_hash = {}
voltage_cdyn_scaling_factor_hash = {}
voltage_file = open(input_hash['Voltage_Scaling_Factors'],'r')
first_line = voltage_file.readline()
for line in voltage_file:
    data = get_data(line,",")
    new_voltage_hash[data[0]] = float(data[1])
    voltage_cdyn_scaling_factor_hash[data[0]] = float(data[2])
voltage_file.close()

##for printing/book-keeping purposes
operating_voltage = new_voltage_hash[cfg]
voltage_cdyn_scaling_factor = voltage_cdyn_scaling_factor_hash[cfg]

if (options.operating_voltage):
    print ("Config: ",cfg)
    print ("Voltage: ", options.operating_voltage)
    operating_voltage = float(options.operating_voltage)
    #new_voltage_hash[cfg] = float(options.operating_voltage)

if (options.voltage_cdyn_scaling_factor):
    print ("Config: ",cfg)
    print ("Voltage Cdyn Sclaing Factor: ", options.voltage_cdyn_scaling_factor)
    voltage_cdyn_scaling_factor_hash[cfg] = float(options.voltage_cdyn_scaling_factor)
    voltage_cdyn_scaling_factor = float(options.voltage_cdyn_scaling_factor)
#print (new_voltage_hash)

##Old way of doing things - read in a voltage scaling factor
##voltage_file = open(input_hash['Voltage_Scaling_Factors'],'r')
##first_line = voltage_file.readline()
##for line in voltage_file:
##    data = get_data(line,",")
##    if(data[0] not in voltage_hash):
##        voltage_hash[data[0]] = {}
##    if(data[1] not in voltage_hash[data[0]]):
##        voltage_hash[data[0]][data[1]] = {}
##    voltage_hash[data[0]][data[1]] = float(data[2]) if data[2] != 'NA' else data[2]
##voltage_file.close()

syn_cdyn_cagr_file = open(input_hash['syn_cdyn_cagr'],'r')
first_line = syn_cdyn_cagr_file.readline()
for line in syn_cdyn_cagr_file:
    data = get_data(line,",")
    if(data[0] not in cdyn_cagr_hash['syn']):
        cdyn_cagr_hash['syn'][data[0]] = {}
    if(data[1] not in cdyn_cagr_hash['syn'][data[0]]):
        cdyn_cagr_hash['syn'][data[0]][data[1]] = {}
    cdyn_cagr_hash['syn'][data[0]][data[1]][data[2]] = float(data[3]) if data[3]!='NA' else data[3]
syn_cdyn_cagr_file.close()

ebb_cdyn_cagr_file = open(input_hash['ebb_cdyn_cagr'],'r')
first_line = ebb_cdyn_cagr_file.readline()
for line in ebb_cdyn_cagr_file:
    data = get_data(line,",")
    if(data[0] not in cdyn_cagr_hash['ebb']):
        cdyn_cagr_hash['ebb'][data[0]] = {}
    if(data[1] not in cdyn_cagr_hash['ebb'][data[0]]):
        cdyn_cagr_hash['ebb'][data[0]][data[1]] = {}
    cdyn_cagr_hash['ebb'][data[0]][data[1]][data[2]] = float(data[3]) if data[3]!='NA' else data[3]
ebb_cdyn_cagr_file.close()

stepping_file = open(input_hash['cdyn_stepping'],'r')
first_line = stepping_file.readline()
for line in stepping_file:
    data = get_data(line,",")
    if(data[0] not in stepping_hash):
        stepping_hash[data[0]] = {}
    if(data[1] not in stepping_hash[data[0]]):
        stepping_hash[data[0]][data[1]] = {}
    stepping_hash[data[0]][data[1]][data[2]] = float(data[3]) if data[3]!='NA' else data[3]
stepping_file.close()

unit_cdyn_cagr_file = open(input_hash['unit_cdyn_cagr'],'r')
first_line = unit_cdyn_cagr_file.readline()
for line in unit_cdyn_cagr_file:
    data = get_data(line,",")
    if(data[0] not in unit_cdyn_cagr_hash):
        unit_cdyn_cagr_hash[data[0]] = {}
    if(data[1] not in unit_cdyn_cagr_hash[data[0]]):
        unit_cdyn_cagr_hash[data[0]][data[1]] = {}
    if(data[2] not in unit_cdyn_cagr_hash[data[0]][data[1]]):
        unit_cdyn_cagr_hash[data[0]][data[1]][data[2]] = {}
    unit_cdyn_cagr_hash[data[0]][data[1]][data[2]][data[3]] = float(data[4])

unit_cdyn_cagr_file.close()

try:
    gc_scaling_cfg_file = open(input_hash['gc_scaling_cfg'],'r')
    first_line = gc_scaling_cfg_file.readline()
    for line in gc_scaling_cfg_file:
        data = get_data(line,",")
        if(data[0] not in gc_scaling_cfg_hash):
            gc_scaling_cfg_hash[data[0]] = {}
        if(data[1] not in gc_scaling_cfg_hash[data[0]]):
            gc_scaling_cfg_hash[data[0]][data[1]] = {}
        gc_scaling_cfg_hash[data[0]][data[1]][data[2]] = data[3]

    gc_scaling_cfg_file.close()
except KeyError:
    print("GC scaling options file not defined in input file - ",options.input_file)
except IOError:
    print("Can't open GC scaling options file - usually defined in <alps repo>/Inputs/gc_scaling_cfg.csv")
    print("Exiting")
    exit(2)


#############################
# Parse ALPS Formula File
#############################
formula_files = get_data(input_hash['ALPS_formula_file'],",")
for ff in formula_files:
    f = open(ff,'r')
    yaml_data = yaml.load(f)
    f.close()
    dfs(yaml_data,paths)

output_list = deepcopy(paths)
output_yaml_data = {'ALPS Model(pF)':{'GT':{}}}
output_cdyn_data = {'GT':{}}
gt_cdyn = {}
key_stats = {'key_stats':{}}
key_stats['key_stats']['Operating Voltage'] = operating_voltage
key_stats['key_stats']['Voltage dependent Cdyn Scaling Factor'] = voltage_cdyn_scaling_factor

for path in output_list:
    print(path)
    path[-1] = eval_formula(path)
    d = output_yaml_data['ALPS Model(pF)']['GT']
    cdyn_d = output_cdyn_data['GT']
    if(len(path) == 2):
        if(path[0] == 'FPS'):
            gt_cdyn['FPS'] = float('%.3f'%float(path[-1]))
        else:
            key_stats['key_stats'][path[0]] = float('%.3f'%float(path[1]))
        continue
    i = 0
    while(True):
        if('cdyn' not in cdyn_d and i < 3):
            cdyn_d['cdyn'] = 0
        if(i < 3):
            cdyn_d['cdyn'] += path[-1]
        if('total' not in d and i >= 3):
            d['total'] = 0
        if(i >= 3):
            d['total'] += path[-1]
            d['total'] = float('%.3f'%float(d['total']))
        if(i == len(path)-2):
            d[path[i]] = float('%.3f'%float(path[i+1]))
            break
        if(path[i] not in d):
            d[path[i]] = {}
        if(path[i] not in cdyn_d and i < 2):
            cdyn_d[path[i]] = {}
        d = d[path[i]]
        if(i < 2):
            cdyn_d = cdyn_d[path[i]]
        i = i+1

#######################################
# Creating Overview datastructures
#######################################
cluster_cdyn_numbers = {'cluster_cdyn_numbers(pF)':{}}
unit_cdyn_numbers = {'unit_cdyn_numbers(pF)':{}}
gt_cdyn['Total_GT_Cdyn(nF)'] = float('%.3f'%float(output_cdyn_data['GT']['cdyn']/1000))
gt_cdyn['Total_GT_Cdyn_syn(nF)'] = 0
gt_cdyn['Total_GT_Cdyn_ebb(nF)'] = 0
gt_cdyn['Total_GT_Cdyn_infra(nF)'] = 0
for cluster in output_cdyn_data['GT']:
    if(cluster == 'cdyn'):
        continue

    cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster] = {}
    cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['total'] = float('%.3f'%float(output_cdyn_data['GT'][cluster]['cdyn']))
    cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['syn'] = 0
    cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['ebb'] = 0
    cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['inf'] = 0
    unit_cdyn_numbers['unit_cdyn_numbers(pF)'][cluster] = {}
    for unit in output_cdyn_data['GT'][cluster]:
        if(unit == 'cdyn'):
            continue
        unit_cdyn_numbers['unit_cdyn_numbers(pF)'][cluster][unit] = float('%.3f'%float(output_cdyn_data['GT'][cluster][unit]['cdyn']))
        unit_lc = unit.lower()
        if(unit_lc.find("grf") != -1 or unit_lc.find("ram") != -1 or unit_lc.find("cache") != -1 or unit_lc.find("ebb") != -1):
            cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['ebb'] += float(output_cdyn_data['GT'][cluster][unit]['cdyn'])
            gt_cdyn['Total_GT_Cdyn_ebb(nF)'] += float(output_cdyn_data['GT'][cluster][unit]['cdyn'])
        elif (unit_lc.find("assign") != -1 or unit_lc.find("clkglue") != -1 or unit_lc.find("cpunit") != -1 or
              unit_lc.find("dfx") != -1    or unit_lc.find("dop") != -1     or        unit_lc.find("repeater") != -1 or unit_lc.find("spine") != -1):
            cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['inf'] += float(output_cdyn_data['GT'][cluster][unit]['cdyn'])
            gt_cdyn['Total_GT_Cdyn_infra(nF)'] += float(output_cdyn_data['GT'][cluster][unit]['cdyn'])
        else:
            cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['syn'] += float(output_cdyn_data['GT'][cluster][unit]['cdyn'])
            gt_cdyn['Total_GT_Cdyn_syn(nF)'] += float(output_cdyn_data['GT'][cluster][unit]['cdyn'])
        cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['syn'] = float('%.3f'%cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['syn'])
        cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['ebb'] = float('%.3f'%cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['ebb'])
        cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['inf'] = float('%.3f'%cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['inf'])

phy_cdyn_numbers = {'physical_cdyn_numbers(nF)':{}}
phy_cdyn_numbers['physical_cdyn_numbers(nF)'] = {}
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"] = {}
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['syn'] = 0
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['ebb'] = 0
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['inf'] = 0
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"] = {}
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['syn'] = 0
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['ebb'] = 0
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['inf'] = 0
for cluster in cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']:
    cluster_lc = cluster.lower()
    if ( cluster_lc.find("ff") != -1 or cluster_lc.find("gti") != -1 or cluster_lc.find("other") != -1 or cluster_lc.find("gam") != -1):
        phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['syn'] += cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['syn']
        phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['ebb'] += cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['ebb']
        phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['inf'] += cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['inf']
    else:
        phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['syn']   += cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['syn']
        phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['ebb']   += cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['ebb']
        phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['inf']   += cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster]['inf']

gt_cdyn['Total_GT_Cdyn_syn(nF)']   = float('%.3f'%(gt_cdyn['Total_GT_Cdyn_syn(nF)']/1000))
gt_cdyn['Total_GT_Cdyn_ebb(nF)']   = float('%.3f'%(gt_cdyn['Total_GT_Cdyn_ebb(nF)']/1000))
gt_cdyn['Total_GT_Cdyn_infra(nF)'] = float('%.3f'%(gt_cdyn['Total_GT_Cdyn_infra(nF)']/1000))

phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['syn']   = float('%.3f'%(phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['syn']/1000))
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['ebb']   = float('%.3f'%(phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['ebb']/1000))
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['inf']   = float('%.3f'%(phy_cdyn_numbers['physical_cdyn_numbers(nF)']["slice"]['inf']/1000))
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['syn'] = float('%.3f'%(phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['syn']/1000))
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['ebb'] = float('%.3f'%(phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['ebb']/1000))
phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['inf'] = float('%.3f'%(phy_cdyn_numbers['physical_cdyn_numbers(nF)']["unslice"]['inf']/1000))


yaml_hash    = output_yaml_data['ALPS Model(pF)']['GT']
label        = 'idle_active_cdyn_dist'
gt_top       = '0GT_level(fF)'
cluster_top  = '0total'
gt_cdyn_dist = {label:{}}
gt_cdyn_dist[label][gt_top] = {}
for category in ['clock_idle', 'clock_stall', 'clock_active', 'infra_idle', 'infra_stall', 'infra_active', 'func_idle', 'func_stall', 'func_active']:
    gt_cdyn_dist[label][gt_top][category] = 0

for cluster in yaml_hash:
    gt_cdyn_dist[label][cluster] = {}
    gt_cdyn_dist[label][cluster][cluster_top] = {}
    for category in ['clock_idle', 'clock_stall', 'clock_active', 'infra_idle', 'infra_stall', 'infra_active','func_idle', 'func_stall', 'func_active']:
        gt_cdyn_dist[label][cluster][cluster_top][category] = 0
    for unit in yaml_hash[cluster]:
        gt_cdyn_dist[label][cluster][unit] = {}
        for category in ['clock_idle', 'clock_stall', 'clock_active', 'infra_idle', 'infra_stall', 'infra_active', 'func_idle', 'func_stall', 'func_active']:
            gt_cdyn_dist[label][cluster][unit][category] = 0

        for state in yaml_hash[cluster][unit]:
            state_lc = state.lower()
            category = ""
            if (state_lc.find("_dop") != -1 or state_lc.find("_clkglue") != -1 or state_lc.find("clockspine") != -1 or state_lc.find("cpunit") != -1 ):
                if (state_lc.find("ps0_") == 0):
                    category = "clock_idle"
                elif (state_lc.find("ps1_") == 0):
                    category = "clock_stall"
                elif (state_lc.find("ps2_") == 0):
                    category = "clock_active"
                else:
                    if (yaml_hash[cluster][unit][state] > 0):
                        print ("")
                    else:
                        continue
            elif (state_lc.find("_nonclkglue") != -1 or state_lc.find("_dfx") != -1 or state_lc.find("repeater") != -1 or state_lc.find("assign") != -1 ):
                if (state_lc.find("ps0_") == 0):
                    category = "infra_idle"
                elif (state_lc.find("ps1_") == 0):
                    category = "infra_stall"
                elif (state_lc.find("ps2_") == 0):
                    category = "infra_active"
                else:
                    if (yaml_hash[cluster][unit][state] > 0):
                        print ("")
                    else:
                        continue
            else:
                if (state_lc.find("ps0_") == 0):
                    category = "func_idle"
                elif (state_lc.find("ps1_") == 0):
                    category = "func_stall"
                else:
                    category = "func_active"

            try:
                gt_cdyn_dist[label][cluster][unit][category]        += yaml_hash[cluster][unit][state]
                gt_cdyn_dist[label][cluster][cluster_top][category] += yaml_hash[cluster][unit][state]
                gt_cdyn_dist[label][gt_top][category]               += yaml_hash[cluster][unit][state]
                # print (cluster, unit, state, category, yaml_hash[cluster][unit][state])
            except:
                for sub in yaml_hash[cluster][unit][state]:
                    if (sub.find("total") == 0):
                        continue
                    gt_cdyn_dist[label][cluster][unit][category]        += yaml_hash[cluster][unit][state][sub]
                    gt_cdyn_dist[label][cluster][cluster_top][category] += yaml_hash[cluster][unit][state][sub]
                    gt_cdyn_dist[label][gt_top][category]               += yaml_hash[cluster][unit][state][sub]
                    # print (cluster, unit, sub, category, yaml_hash[cluster][unit][state][sub])

for category in ['clock_idle', 'clock_stall' , 'clock_active', 'infra_idle', 'infra_stall', 'infra_active', 'func_idle', 'func_stall', 'func_active', ]:
    gt_cdyn_dist[label][gt_top][category] = float('%.3f'%(gt_cdyn_dist[label][gt_top][category]/1000))

for cluster in gt_cdyn_dist[label]:
    if (cluster.find(gt_top) == 0):
        continue
    for unit in gt_cdyn_dist[label][cluster]:
        for category in gt_cdyn_dist[label][cluster][unit]:
            gt_cdyn_dist[label][cluster][unit][category] = float('%.3f'%(gt_cdyn_dist[label][cluster][unit][category]/1000))

print ("")

######################################
# Including gatecounts in output files
######################################

if (options.dump_gc):
    for cluster in new_gc.keys():
        for unit in new_gc[cluster].keys():
            inst_name = cluster + '_' + unit 
            if inst_name not in I.keys():
                new_gc[cluster][unit].update({'numInstances': 'NA'}) 
                new_gc[cluster][unit].update({'total_gc' : 'NA'})
            else:
                new_gc[cluster][unit].update({'numInstances':I[cluster + '_' + unit]}) 
                total_gc_unit = new_gc[cluster][unit]['numInstances'] * new_gc[cluster][unit]['Gen11LP'] 
                new_gc[cluster][unit].update({'total_gc' : total_gc_unit})


common_cfg = options.dest_config.lower()

if (common_cfg.find('pvc') > -1) or (common_cfg.find('rlt') > -1):
    if options.method == 'kaolin':
        if (common_cfg.find('pvc') > -1):
            #Calculating Chiplet_Cdyn and Base_Cdyn
            Chiplet_Cdyn =  [float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['EU']['total']),
                    float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['LSC']['total']),
		    float(output_yaml_data['ALPS Model(pF)']['GT']['Other']['Others']['PS2_CAM_SPINE_COMPUTE']),
                    float(output_yaml_data['ALPS Model(pF)']['GT']['L3_Bank']['Foveros']['Foveros_compute']),
                    float(output_yaml_data['ALPS Model(pF)']['GT']['L3_Bank']['Foveros']['Foveros_compute_idle'])]
            Chiplet_Cdyn = sum(Chiplet_Cdyn) / 1000
            Chiplet_Cdyn = round(Chiplet_Cdyn,3)

            Base_Cdyn = float(gt_cdyn['Total_GT_Cdyn(nF)']) - Chiplet_Cdyn

            Base_Cdyn = round(Base_Cdyn, 3)

            gt_cdyn['Total_Chiplet_Cdyn(nF)'] = Chiplet_Cdyn
            gt_cdyn['Total_Base_Cdyn(nF)'] = Base_Cdyn

        else:
            #Calculating Chiplet_Cdyn and Base_Cdyn
            Chiplet_Cdyn =  [float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['EU']['total']),
                    float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['LSC']['total']),
                    float(output_yaml_data['ALPS Model(pF)']['GT']['L3_Bank']['Foveros']['Foveros_compute']),
                    float(output_yaml_data['ALPS Model(pF)']['GT']['L3_Bank']['Foveros']['Foveros_compute_idle'])]
            Chiplet_Cdyn = sum(Chiplet_Cdyn) / 1000
            Chiplet_Cdyn = round(Chiplet_Cdyn,3)

            Base_Cdyn = float(gt_cdyn['Total_GT_Cdyn(nF)']) - Chiplet_Cdyn

            Base_Cdyn = round(Base_Cdyn, 3)

            gt_cdyn['Total_Chiplet_Cdyn(nF)'] = Chiplet_Cdyn
            gt_cdyn['Total_Base_Cdyn(nF)'] = Base_Cdyn

if (common_cfg.find('rlt') > -1) or (common_cfg.find('pvc') > -1):
    if (options.method == 'cam'):
        #Calculating Chiplet_Cdyn and Base_Cdyn
        Chiplet_Cdyn =  [float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['EU']['total']),
	float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['LSC']['total']),
	float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['ROW']['total']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['Foveros']['DSS']['PS2_CAM_COMPUTE_FOVEROS']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['Foveros']['DSS']['PS2_CAM_COMPUTE_FOV_INFRA']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_ARB']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_ARB_INFRA']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_SPINE_INFRA'])]
        Chiplet_Cdyn = sum(Chiplet_Cdyn) / 1000
        Chiplet_Cdyn = round(Chiplet_Cdyn,3)

        Base_Cdyn = float(gt_cdyn['Total_GT_Cdyn(nF)']) - Chiplet_Cdyn

        Base_Cdyn = round(Base_Cdyn, 3)

        gt_cdyn['Total_Chiplet_Cdyn(nF)'] = Chiplet_Cdyn
        gt_cdyn['Total_Base_Cdyn(nF)'] = Base_Cdyn

if (common_cfg == 'xe3_fcs'):
    if (options.method == 'cam'):
        #Calculating Chiplet_Cdyn and Base_Cdyn
        Chiplet_Cdyn =  [float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['EU']['total']),
	float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['LSC']['total']),
	float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['ROW']['total']),
	float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['CSC']['total']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['Foveros']['DSS']['PS2_CAM_COMPUTE_FOVEROS']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['Foveros']['DSS']['PS2_CAM_COMPUTE_FOV_INFRA']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_ARB']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_ARB_INFRA']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_SPINE_INFRA'])]
        Chiplet_Cdyn = sum(Chiplet_Cdyn) / 1000
        Chiplet_Cdyn = round(Chiplet_Cdyn,3)

        Base_Cdyn = float(gt_cdyn['Total_GT_Cdyn(nF)']) - Chiplet_Cdyn

        Base_Cdyn = round(Base_Cdyn, 3)

        gt_cdyn['Total_Chiplet_Cdyn(nF)'] = Chiplet_Cdyn
        gt_cdyn['Total_Base_Cdyn(nF)'] = Base_Cdyn

if (common_cfg == 'xe3_fcs_sw'):
    if (options.method == 'cam'):
        #Calculating Chiplet_Cdyn and Base_Cdyn
        Chiplet_Cdyn =  [float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['EU']['total']),
	float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['LSC']['total']),
	float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['ROW']['total']),
	float(cluster_cdyn_numbers['cluster_cdyn_numbers(pF)']['CSC']['total']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['Foveros']['DSS']['PS2_CAM_COMPUTE_FOVEROS']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['Foveros']['DSS']['PS2_CAM_COMPUTE_FOV_INFRA']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_ARB']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_ARB_INFRA']),
	float(output_yaml_data['ALPS Model(pF)']['GT']['FabricsSpine']['SpineCompute']['PS2_CAM_COMPUTE_SPINE_INFRA'])]
        Chiplet_Cdyn = sum(Chiplet_Cdyn) / 1000
        Chiplet_Cdyn = round(Chiplet_Cdyn,3)

        SW_Die_Cdyn = [float(output_yaml_data['ALPS Model(pF)']['GT']['Foveros']['SWDie']['PS2_CAM_SW_DIE_FOVEROS']),
                       float(output_yaml_data['ALPS Model(pF)']['GT']['Foveros']['SWDie']['PS2_CAM_SW_DIE_FOV_INFRA'])]
        SW_Die_Cdyn = sum(SW_Die_Cdyn) / 1000
        SW_Die_Cdyn = round(SW_Die_Cdyn,3)

        Base_Cdyn = float(gt_cdyn['Total_GT_Cdyn(nF)']) - Chiplet_Cdyn - SW_Die_Cdyn

        Base_Cdyn = round(Base_Cdyn, 3)

        gt_cdyn['Total_Chiplet_Cdyn(nF)'] = Chiplet_Cdyn
        gt_cdyn['Total_Base_Cdyn(nF)'] = Base_Cdyn
        gt_cdyn['Total_SW_Die_Cdyn(nF)'] = SW_Die_Cdyn

####################################
# Generating output YAML file
####################################
of = open(options.output_file,'w')
yaml.dump(gt_cdyn,of,default_flow_style=False)
yaml.dump(phy_cdyn_numbers,of,default_flow_style=False)
yaml.dump(cluster_cdyn_numbers,of,default_flow_style=False)
yaml.dump(unit_cdyn_numbers,of,default_flow_style=False)
yaml.dump(key_stats,of,default_flow_style=False)
yaml.dump(output_yaml_data,of,default_flow_style=False)
yaml.dump(gt_cdyn_dist,of,default_flow_style=False)

if (options.dump_gc):
    yaml.dump(new_gc,of,default_flow_style=False)

of.close()

dump_patriot_output()

##########################################
# Timegraph Code
##########################################
##################################################################
# Utility functions for dumping output in the desired format
##################################################################
def getsortedkeys(in_dict):
    #Takes a dictionary as input
    #Return the sorted first levels keys of the dictionary as a list
    outputlist = []
    for key in in_dict:
        outputlist.append(key)
    return sorted(outputlist)



def getallsortedkeyvals(in_dict, value_list):
    #Beware : Recursive function
    #Expects elements of the dictionaries to be either
    #dictionaries themselves or singular elements
    #no lists
    if(isinstance(in_dict, dict) is False):
        value_list.append(in_dict)
    else:
        for key in getsortedkeys(in_dict):
            getallsortedkeyvals(in_dict[key], value_list)


def getallsortedpaths(in_dict, path_lists, memory=[]):
    #Beware : Recursive function
    #Expects elements of the dictionaries to be either
    #dictionaries themselves or singular elements
    #no lists
    if(isinstance(in_dict, dict) is False):
        path_lists.append(deepcopy(memory))
        memory.pop(-1)
    else:
        for key in getsortedkeys(in_dict):
            memory.append(key)
            getallsortedpaths(in_dict[key], path_lists, memory)
        if memory:
            memory.pop(-1)


def combine_list(in_list, sep):
    combine = ''
    for ele in in_list:
        combine = combine + ele + sep
    return combine[:-1]

def print_header(in_list_of_lists, file_handle):
    for ele in in_list_of_lists:
        print(combine_list(ele, '.') + '\t', end="", file=file_handle)

def print_line(in_list, sep, file_handle):
    for ele in in_list:
        print(ele, sep,file=file_handle, end="")

def print_head(in_dict, file_handle):
    paths = []
    getallsortedpaths(in_dict, paths)
    print_header(paths, file_handle)

def print_value(in_dict, file_handle):
    keyvalues = []
    getallsortedkeyvals(in_dict, keyvalues)
    print_line(keyvalues, '\t', file_handle)

#if num_string is present
#strip num_ and return string
#else return false
def strip_num(in_string):
    if(re.search(r'^num_.*',in_string)):
        key = in_string.split("_")
        del(key[0])
        return "_".join(key)
    else:
        return False

#######################################################
# Alps for timegraph input
########################################################
#Info:
#-------------------------------------------------------
# A lot of code can be merged.
# Unavoidable copy and paste of code for the time being
#-------------------------------------------------------

#Capturing the residency dependent part of the main build_alps.py script into a function
#----------------------------------------------------------------------------------------
def tiny_build_alps(with_header):
    #Initialising erstwhile global variables
    #----------------------------------------------------------
    local_output_list = deepcopy(paths)
    local_output_yaml_data = {'ALPS Model(pF)':{'GT':{}}}
    local_output_cdyn_data = {'GT':{}}
    local_gt_cdyn = {}
    local_key_stats = {'key_stats':{}}
    local_cluster_cdyn_numbers = {'cluster_cdyn_numbers(pF)':{}}
    local_unit_cdyn_numbers = {'unit_cdyn_numbers(pF)':{}}
    #----------------------------------------------------------
    for path in local_output_list:
        path[-1] = eval_formula(path)
        d = local_output_yaml_data['ALPS Model(pF)']['GT']
        cdyn_d = local_output_cdyn_data['GT']
        if(len(path) == 2):
            if(path[0] == 'FPS'):
                local_gt_cdyn['FPS'] = float('%.3f'%float(path[-1]))
            else:
                local_key_stats['key_stats'][path[0]] = float('%.3f'%float(path[1]))
            continue
        i = 0
        while(True):
            if('cdyn' not in cdyn_d and i < 3):
                cdyn_d['cdyn'] = 0
            if(i < 3):
                cdyn_d['cdyn'] += path[-1]
            if('total' not in d and i >= 3):
                d['total'] = 0
            if(i >= 3):
                d['total'] += path[-1]
                d['total'] = float('%.3f'%float(d['total']))
            if(i == len(path)-2):
                d[path[i]] = float('%.3f'%float(path[i+1]))
                break
            if(path[i] not in d):
                d[path[i]] = {}
            if(path[i] not in cdyn_d and i < 2):
                cdyn_d[path[i]] = {}
            d = d[path[i]]
            if(i < 2):
                cdyn_d = cdyn_d[path[i]]
            i = i+1
    #######################################
    # Creating(locally) Overview datastructures
    #######################################
    local_gt_cdyn['Total_GT_Cdyn(nF)'] = float('%.3f'%float(local_output_cdyn_data['GT']['cdyn']/1000))
    for cluster in local_output_cdyn_data['GT']:
        if(cluster == 'cdyn'):
            continue
        local_cluster_cdyn_numbers['cluster_cdyn_numbers(pF)'][cluster] = float('%.3f'%float(local_output_cdyn_data['GT'][cluster]['cdyn']))
        local_unit_cdyn_numbers['unit_cdyn_numbers(pF)'][cluster] = {}
        for unit in local_output_cdyn_data['GT'][cluster]:
            if(unit == 'cdyn'):
                continue
            local_unit_cdyn_numbers['unit_cdyn_numbers(pF)'][cluster][unit] = float('%.3f'%float(local_output_cdyn_data['GT'][cluster][unit]['cdyn']))
    ###################################################
    #New Code for printing timegraph output
    ###################################################
    if(with_header):
        #Print the header line.
        print_head(local_gt_cdyn, op_timegraph_file)
        print_head(local_cluster_cdyn_numbers, op_timegraph_file)
        print_head(local_unit_cdyn_numbers, op_timegraph_file)
        print_head(local_key_stats, op_timegraph_file)
        print_head(local_output_yaml_data, op_timegraph_file)
        print(file=op_timegraph_file)

    #Print the power number (values)
    print_value(local_gt_cdyn, op_timegraph_file)
    print_value(local_cluster_cdyn_numbers, op_timegraph_file)
    print_value(local_unit_cdyn_numbers, op_timegraph_file)
    print_value(local_key_stats, op_timegraph_file)
    print_value(local_output_yaml_data, op_timegraph_file)
    print(file=op_timegraph_file)


if(options.timegraph_file and options.output_timegraph_file):
    ####################################
    # Parsing Timegraph input file
    ####################################
    #----------------------------------------------------
    #Read the timegraph input file row by row
    #And essentially run build_alps for each row
    #And dump output values into a timegraph style file
    if options.timegraph_file.lower().endswith('.gz'):
        timegraph_file = gzip.open(options.timegraph_file, 'r')
    elif options.timegraph_file.lower().endswith('.zip'):
        zip_root = zipfile.ZipFile(options.timegraph_file, 'r')
        timegraph_file = zip_root.open(zip_root.namelist()[0])
    else:
        timegraph_file = open(options.timegraph_file, 'rb')     #'b' needed for decode()

    #Creating timegraph output file
    op_timegraph_file = open(options.output_timegraph_file, 'w')
    #tiny_build_alps(True)
    with_header = True
    header = timegraph_file.readline().decode().strip().split('\t')
    for line in timegraph_file:
        R = {}
        I = {}
        row = line.decode().strip().split('\t')
        index = 0
        for ele in header:
            if(strip_num(ele) is False):
                try:
                    R[ele] = float(row[index])
                    if(R[ele] < 0):
                        R[ele] = 0
                except ValueError:
                    print("Float conversion failed for", ele, file=lf)
                    R[ele] = 0
            else:
                try:
                    I[strip_num(ele)] = float(row[index])
                except ValueError:
                    print("Float converstion failed", ele, file=lf)
            index = index + 1
        tiny_build_alps(with_header)
        with_header= False

    timegraph_file.close()
    op_timegraph_file.close()


#Closing the log files at the complete end
print("Exit",file=lf)
lf.close()
if(options.run_debug):
    df.close()

