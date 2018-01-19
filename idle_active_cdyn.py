import os
import sys
import lib.yaml as yaml
import re
import shlex 
import subprocess
from subprocess import call
import csv
import pdb
import lib.yaml as yaml  # requires PyYAML
import itertools
import lib.argparse
import logging
from pathlib import Path
import time
#from collections import OrderedDict

def read_cdyn_file(cdyn_file_name):
    cdyn_wt={}

    with open(cdyn_file_name) as csvfile:
        obj=(csv.reader(csvfile))
        for row in obj:
            cdyn_wt.setdefault(row[0],{})
            cdyn_wt[row[0]].setdefault(row[1],{})
            cdyn_wt[row[0]][row[1]]=[row[3]]
            '''cdyn_wt[row[1]].setdefault(row[2],{})
            cdyn_wt[row[1]][row[2]][row[0]]=[row[3],row[4],row[5]]'''

    return cdyn_wt

def idle_stall_active(cdyn_dict,lf):

    unit_idle_cdyn = {}
    unit_stall_cdyn = {}
    unit_active_cdyn ={}
    cluster_idle_cdyn = {}
    cluster_stall_cdyn = {}
    cluster_active_cdyn = {}
    
    value = 1.0
  
    if value == 1.0:
        print("",file=lf)
        #print (("cluster,unit,state,\t").expandtabs(66)+("Residency 1,\tResidency 2,\tcdyn_wt1,\tcdyn_wt2,\tcdyn1,\tcdyn2,\tcdyn_diff").expandtabs(16),file=lf)

        for cluster in cdyn_dict['unit_cdyn_numbers(pF)'].keys():
            cluster_idle_cdyn_val = cluster_stall_cdyn_val = cluster_active_cdyn_val = 0.0
            for unit in cdyn_dict['unit_cdyn_numbers(pF)'][cluster].keys():
                category="ALPS Model(pF)"
                idle_cdyn = stall_cdyn = active_cdyn = 0.0
                for stat in cdyn_dict[category]['GT'][cluster][unit].keys():
                                
                    try:
                        key_list = cdyn_dict[category]['GT'][cluster][unit][stat].keys()
                    except:
                        key_list=[]
                        if stat.startswith('PS0_'):
                            idle_cdyn = idle_cdyn + cdyn_dict[category]['GT'][cluster][unit][stat]
                            cluster_idle_cdyn_val = cluster_idle_cdyn_val + cdyn_dict[category]['GT'][cluster][unit][stat]
                        elif stat.startswith('PS1_'):
                            stall_cdyn = stall_cdyn + cdyn_dict[category]['GT'][cluster][unit][stat]
                            cluster_stall_cdyn_val = cluster_stall_cdyn_val + cdyn_dict[category]['GT'][cluster][unit][stat]
                        else:
                            active_cdyn = active_cdyn + cdyn_dict[category]['GT'][cluster][unit][stat]
                            cluster_active_cdyn_val = cluster_active_cdyn_val + cdyn_dict[category]['GT'][cluster][unit][stat]                               

                    if len(key_list) != 0:
		    
                        for sub_stat in key_list:
                            if sub_stat == "total":
                                continue
                                    #stat_print = sub_stat.replace(stat+"_",'  ')
                            if sub_stat.startswith('PS0_'):
                                idle_cdyn = idle_cdyn + cdyn_dict[category]['GT'][cluster][unit][stat][sub_stat]
                                cluster_idle_cdyn_val = cluster_idle_cdyn_val + cdyn_dict[category]['GT'][cluster][unit][stat][sub_stat]
                            elif sub_stat.startswith('PS1_'):
                                stall_cdyn = stall_cdyn + cdyn_dict[category]['GT'][cluster][unit][stat][sub_stat]
                                cluster_stall_cdyn_val = cluster_stall_cdyn_val + cdyn_dict[category]['GT'][cluster][unit][stat][sub_stat]
                            else:
                                active_cdyn = active_cdyn + cdyn_dict[category]['GT'][cluster][unit][stat][sub_stat]
                                cluster_active_cdyn_val = cluster_active_cdyn_val + cdyn_dict[category]['GT'][cluster][unit][stat][sub_stat]
			    
                
                unit_idle_cdyn[unit+","+cluster] = ["idle",round(idle_cdyn,2)]
                unit_stall_cdyn[unit+","+cluster] = ["stall",round(stall_cdyn,2)]
                unit_active_cdyn[unit+","+cluster] = ["active",round(active_cdyn,2)]
                #print (cluster,unit,unit_idle_cdyn[unit][2])
            cluster_idle_cdyn[cluster] = ["idle",round(cluster_idle_cdyn_val,2)]
            cluster_stall_cdyn[cluster] = ["stall",round(cluster_stall_cdyn_val,2)]
            cluster_active_cdyn[cluster] = ["active",round(cluster_active_cdyn_val,2)]
            #print (cluster,cluster_active_cdyn[cluster][1])
	    
    GT_idle_cdyn = GT_stall_cdyn = GT_active_cdyn = 0.0
    for clusters in cluster_idle_cdyn.keys():

        GT_idle_cdyn = round(GT_idle_cdyn + cluster_idle_cdyn[clusters][1],2)
    for clusters in cluster_stall_cdyn.keys():

        GT_stall_cdyn = round(GT_stall_cdyn + cluster_stall_cdyn[clusters][1],2)
    for clusters in cluster_active_cdyn.keys():

        GT_active_cdyn = round(GT_active_cdyn + cluster_active_cdyn[clusters][1],2)

    print ("######## GT Cdyn Breakup ########",file=lf)
    print ("",file=lf)
    print ("GT_idle_cdyn,",GT_idle_cdyn,file=lf)
    print ("GT_stall_cdyn,",GT_stall_cdyn,file=lf)
    print ("GT_active_cdyn,",GT_active_cdyn,file=lf)
    
    print ("",file=lf)
    print ("######## Clusterwise Cdyn Breakup ########",file=lf)
    print ("",file=lf)
    temp_list = [cluster_idle_cdyn,cluster_stall_cdyn,cluster_active_cdyn]
    for item in temp_list:
        for key,values in item.items():
            print(str(key)+","+str(values[0])+","+str(values[1]),file=lf)
    print ("",file=lf)
    print ("######## Unitwise Cdyn Breakup ########",file=lf)
    print ("",file=lf)
    temp_list2 = [unit_idle_cdyn,unit_stall_cdyn,unit_active_cdyn]
    for item in temp_list2:
        for key,values in item.items():
            print(str(key)+","+str(values[0])+","+str(values[1]),file=lf)


if __name__ == '__main__':
    
    parser = lib.argparse.ArgumentParser(description='This script will do the sanity check on the ALPS outputs')

    parser.add_argument('-o','--log_file',dest="out_log",default=False, help="Output log directory")
    parser.add_argument('-f','--input_file',dest="input_file", help="Input yaml file")
    args, sub_args = parser.parse_known_args()
 
    
    timestr = time.strftime("%Y%m%d-%H%M%S")
    if args.out_log:
        log_d = args.out_log
        log_directory = "./"+log_d
    else:
        log_d = "out_log"
        log_directory = "./"+log_d+"-"+timestr

    if os.path.isdir(log_directory):
        sys.exit("Error: Log directory already exists")
    else:
        os.makedirs(log_directory)
	
    log_f = "idle_active_cdyn.csv"
    lf = open(log_directory+"/"+log_f,'w')
    yaml_file = open(args.input_file,'r')
    cdyn_dict = yaml.load(yaml_file)
    idle_stall_active(cdyn_dict,lf)
    
