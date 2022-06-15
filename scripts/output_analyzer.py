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
import re
from io import StringIO
import tokenize
import parser 
import argparse
#import yaml

#from collections import OrderedDict

cluster_syn_dict={'list_of_FF_syn_items': ['CL', 'CS', 'DFX', 'GS', 'HPSDE', 'HPVS', 'HS', 'OACS', 'RS', 'SDE', 'SF', 'SOL', 'SVG', 'TDG', 'TDS', 'TE', 'TETG', 'TSG', 'URBM', 'VF', 'VFBE1', 'VFBE2', 'VFE', 'VSBE', 'VSFE'],'list_of_Sampler_syn_items' : ['AVS', 'CRE', 'DG', 'DM', 'FL', 'FT', 'IEF', 'IME', 'Media', 'MT', 'PL', 'SC', 'SI', 'SO', 'ST', 'SVSM'],'list_of_COLOR_syn_items': ['RCC', 'CC', 'DAPB', 'DAPRSC', 'MSC', 'RCPBCOM', 'RCPBPIX', 'RCPFE' ],'list_of_HDC_syn_items': ['HDCL1', 'HDCREQCMD1', 'HDCREQCMD2', 'HDCREQDATA', 'HDCRET', 'HDCRET1', 'HDCRET2', 'HDCTLB'],'list_of_Z_syn_items':['HIZ', 'RCZ', 'IZ', 'STC'],'list_of_rFF_syn_items':['rCL', 'rCS', 'rOV', 'rSF', 'rSVG', 'rVF', 'rVSBE', 'rVSFE', 'rVS_Cache'],'list_of_ROSS_syn_items':['BC', 'CPSS', 'GWL', 'IC', 'MA_IN', 'MA_OUT', 'PSD', 'TDL'],'list_of_eu_syn_items': ['EM', 'FPU0', 'FPU1', 'GA', 'TC'],'list_of_DSSC_syn_items':['BC', 'CPSS', 'DAPRSS', 'GWL', 'PSD'],'list_of_L3Node_syn_items':['LNE', 'LNI'],'list_of_L3Bank_syn_items':['LBI', 'LSQC', 'LSQD', 'LTCC', 'LTCD_Data', 'LTCD_EBB', 'LTCD_Tag', 'L3BankOther']}

def read_residency_file(residency_file,**keyword_parameters):
    res_dir = {}
    if ('optional' in keyword_parameters):
        with open(keyword_parameters['optional']+"/"+residency_file) as csvfile:
            obj=(csv.reader(csvfile))
            for row in obj:
                res_dir[row[0]]=[row[1]]
    else:
        with open(residency_file) as csvfile:
            obj=(csv.reader(csvfile))
            for row in obj:
                res_dir[row[0]]=[row[1]]
    return res_dir

def read_weight_file(weights_file,**keyword_parameters):
    weights_dir = {}
    if ('optional' in keyword_parameters):
        with open(keyword_parameters['optional']+"/"+weights_file) as csvfile:
            obj=(csv.reader(csvfile))
            for row in obj:
                weights_dir[row[0]]=[row[2]]
    else:
        with open(weights_file) as csvfile:
            obj=(csv.reader(csvfile))
            for row in obj:
                weights_dir[row[0]]=[row[2]]
    return weights_dir

def read_cdyn_file(cdyn_file_name):
    cdyn_wt={}

    with open(cdyn_file_name) as csvfile:
        obj=(csv.reader(csvfile))
        for row in obj:
            cdyn_wt.setdefault(row[0],{})
            cdyn_wt[row[0]].setdefault(row[1],{})
            cdyn_wt[row[0]][row[1]]=[row[3]]

    return cdyn_wt


def compare_cdyn_dir(cdyn_dict1,cdyn_dict2,res_file_dict1,res_file_dict2,cdyn_csv_dict1,cdyn_csv_dict2,wl,lf,options,cluster_list=None,units_list=None):

    cluster_cdyn1={}
    cluster_cdyn2={}
    unit_cdyn={}
    GT_cdyn={}
    #print (cdyn_dict,file=lf)
    #GT cdyn
    if "gt" in options:
        print("###### GT Cdyn differnces ######",file=lf)
        print("",file=lf)
        header_list = ['FPS','Total_GT_Cdyn(nF)','Total_GT_Cdyn_ebb(nF)','Total_GT_Cdyn_infra(nF)','Total_GT_Cdyn_syn(nF)']
        for elements in header_list:
            num1=cdyn_dict1[elements]
            num2=cdyn_dict2[elements]
            diff=round(float(num2-num1),2)
            print ((elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(16),file=lf)
        cdyn_by_fps1 = round(cdyn_dict1['Total_GT_Cdyn(nF)']/cdyn_dict1['FPS'],2)
        cdyn_by_fps2 = round(cdyn_dict2['Total_GT_Cdyn(nF)']/cdyn_dict2['FPS'],2)
        ratio_diff = round(float(cdyn_by_fps2-cdyn_by_fps1),2)
        print (("Total_GT_Cdyn/FPS,\t").expandtabs(26)+(str(cdyn_by_fps1)+",\t"+str(cdyn_by_fps2)+",\t"+str(diff)).expandtabs(16),file=lf)
        print ("",file=lf)
    
    if "fps" in options:
        print ("Workload name,FPS1,FPS2",file=lf)
        # FPS Comparision
        fps1=cdyn_dict1['FPS']
        fps2=cdyn_dict2['FPS']
        diff=round(float(fps2-fps1),2)
        #print (("Workload name,FPS1,FPS2,file=lf)
        print (wl+","+str(fps1)+","+str(fps2)+","+str(diff),file=lf)


    if "clusters" in options:
        print("###### GT Cdyn differnces ######",file=lf)
        print("",file=lf)
        header_list = ['FPS','Total_GT_Cdyn(nF)','Total_GT_Cdyn_ebb(nF)','Total_GT_Cdyn_infra(nF)','Total_GT_Cdyn_syn(nF)']
        for elements in header_list:
            num1=cdyn_dict1[elements]
            num2=cdyn_dict2[elements]
            diff=round(float(num2-num1),2)
            print ((elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(16),file=lf)
        print ("",file=lf)

        print("##### Cluster cdyn differences #####",file=lf)
        print ("",file=lf)
        cluster_cdyn={}
        for clusters in cdyn_dict1['cluster_cdyn_numbers(pF)'].keys():
            if "clusters_list" in options:
                if cluster_list != None:
                    clust=re.split(',',cluster_list)
                    if clusters in clust:
                        types=['total']
                        for elements in types:
                            num1=cdyn_dict1['cluster_cdyn_numbers(pF)'][clusters][elements]
                            num2=cdyn_dict2['cluster_cdyn_numbers(pF)'][clusters][elements]
                            diff=round(float(num2-num1),2)
                            print ((clusters+"_"+elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                            
                    
            if "clusters_all" in options:
                types=['total']
                for elements in types:
                    num1=cdyn_dict1['cluster_cdyn_numbers(pF)'][clusters][elements]
                    num2=cdyn_dict2['cluster_cdyn_numbers(pF)'][clusters][elements]

                    diff=round(float(num2-num1),2)
                    print ((clusters+"_"+elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                    
    if "units" in options:
        print("###### GT Cdyn differnces ######",file=lf)
        print("",file=lf)
        header_list = ['FPS','Total_GT_Cdyn(nF)','Total_GT_Cdyn_ebb(nF)','Total_GT_Cdyn_infra(nF)','Total_GT_Cdyn_syn(nF)']
        for elements in header_list:
            num1=cdyn_dict1[elements]
            num2=cdyn_dict2[elements]
            diff=round(float(num2-num1),2)
            print ((elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(16),file=lf)
        print ("",file=lf)
        print("##### Unit cdyn differences #####",file=lf)
        print("",file=lf)

        for cluster in cdyn_dict1['unit_cdyn_numbers(pF)'].keys():
            if units_list != None and "units_list" in options:
                for unit in cdyn_dict1['unit_cdyn_numbers(pF)'][cluster].keys():
                    unit_name=re.split(',',units_list)
                    if unit in unit_name:
                        if unit in cdyn_dict2['unit_cdyn_numbers(pF)'][cluster].keys():
                        #cdyn_unit=cdyn_dict.get('unit_cdyn_numbers(pF)',{}).get(clusters,{}).get(units)
                            num1=cdyn_dict1['unit_cdyn_numbers(pF)'][cluster][unit]
                            num2=cdyn_dict2['unit_cdyn_numbers(pF)'][cluster][unit]
                            diff=round((num2-num1),2)
                            print ((cluster+"_"+unit+"\t").expandtabs(50)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                            #print (("  cdyn_"+unit+"/gc_"+unit+",\t").expandtabs(50)+(str(cdyn_by_gc1)+",\t"+str(cdyn_by_gc2)+",\t"+str(cdyn_by_gc_diff)).expandtabs(36),file=lf)

            if "units_all" in options:
                for unit in cdyn_dict1['unit_cdyn_numbers(pF)'][cluster].keys():
                    if unit in cdyn_dict2['unit_cdyn_numbers(pF)'][cluster].keys():
                        #cdyn_unit=cdyn_dict.get('unit_cdyn_numbers(pF)',{}).get(clusters,{}).get(units)
                        num1=cdyn_dict1['unit_cdyn_numbers(pF)'][cluster][unit]
                        num2=cdyn_dict2['unit_cdyn_numbers(pF)'][cluster][unit]

                        diff=round((num2-num1),2)

                        print ((cluster+"_"+unit+",\t").expandtabs(50)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
## 11/30/2017 Changes
##def state_wise_cdyn_diff(cdyn_dict1,cdyn_dict2,cdyn_csv_dict1,cdyn_csv_dict2,res_file_dict1,res_file_dict2,file=lf):
    
    if "states" in options:
        print("",file=lf)
        print("##### State wise cdyn differences #####",file=lf)
        print("",file=lf)
        print (("cluster,unit,state,\t").expandtabs(66)+("Residency 1,\tResidency 2,\tcdyn_wt1,\tcdyn_wt2,\tcdyn1,\tcdyn2,\tcdyn_diff").expandtabs(16),file=lf)

        for cluster in cdyn_dict1['unit_cdyn_numbers(pF)'].keys():
            #print (cluster,":",file=lf)
            for unit in cdyn_dict2['unit_cdyn_numbers(pF)'][cluster].keys():
                if unit in cdyn_dict1['unit_cdyn_numbers(pF)'][cluster].keys() or unit not in cdyn_dict1['unit_cdyn_numbers(pF)'][cluster].keys():
                        
                    category="ALPS Model(pF)"
                    for stat in cdyn_dict2[category]['GT'][cluster][unit].keys():
                        #if stat in cdyn_dict1[category]['GT'][cluster][unit].keys():
                                
                        try:
                            key_list = cdyn_dict2[category]['GT'][cluster][unit][stat].keys()
                            #print ("    "+stat+":",file=lf)
                        except:
                            key_list=[]
                            try:
                                ref_num = cdyn_dict1[category]['GT'][cluster][unit][stat]
                                        
                            except:
                                ref_num = 0.0
                            try:
                                new_num = cdyn_dict2[category]['GT'][cluster][unit][stat]
                            except:
                                new_num = 0.0

                            if (stat in cdyn_csv_dict1.keys()):
                                wt1=(float(cdyn_csv_dict1[stat][0]))
                            else: 
                                wt1="-"
                            if (stat in cdyn_csv_dict2.keys()):
                                wt2=(float(cdyn_csv_dict2[stat][0]))
                            else: 
                                wt2="-"
                            if stat in res_file_dict1.keys():
                                res1=(float(res_file_dict1[stat][0]))
                            else:
                                res1="-"
                            if stat in res_file_dict2.keys():
                                res2=(float(res_file_dict2[stat][0]))
                            else:
                                res2="-"
                                    
                                
                            num1 = ref_num
                            num2 = new_num
                            diff=round((num2-num1),2)
                            print ((cluster+","+unit+","+stat+",\t").expandtabs(66)+(str(res1)+",\t"+str(res2)+",\t"+str(wt1)+",\t"+(str(wt2)+",\t"+str(num1)+",\t"+str(num2))+",\t"+str(diff)).expandtabs(16),file=lf)


                        for sub_stat in key_list:
                            if sub_stat == "total":
                                continue
                                    #stat_print = sub_stat.replace(stat+"_",'  ')
                            try:
                                ref_num = cdyn_dict1[category]['GT'][cluster][unit][stat][sub_stat]
                            except:
                                ref_num = 0.0
                            try:
                                new_num = cdyn_dict2[category]['GT'][cluster][unit][stat][sub_stat]
                            except:
                                new_num = 0.0
                                    
                            if (sub_stat in cdyn_csv_dict1.keys()):
                                wt1=(float(cdyn_csv_dict1[sub_stat][0]))
                            else: 
                                wt1="-"
                            if (sub_stat in cdyn_csv_dict2.keys()):
                                wt2=(float(cdyn_csv_dict2[sub_stat][0]))
                            else: 
                                wt2="-"
                            if sub_stat in res_file_dict1.keys():
                                res1=(float(res_file_dict1[sub_stat][0]))
                            else:
                                res1="-"
                            if sub_stat in res_file_dict2.keys():
                                res2=(float(res_file_dict2[sub_stat][0]))
                            else:
                                res2="-"

                                    
                            num1 = ref_num
                            num2 = new_num
                            diff=round((num2-num1),2)
                            print ((cluster+","+unit+","+sub_stat+",\t").expandtabs(66)+(str(res1)+",\t"+str(res2)+",\t"+str(wt1)+",\t"+(str(wt2)+",\t"+str(num1)+",\t"+str(num2))+",\t"+str(diff)).expandtabs(16),file=lf)

                else:
                    continue
    
def mysplit(formula):
     return([token[1] for token in tokenize.generate_tokens(StringIO(formula).readline) if token[1]])

def unlist_res_func(res_dir):
    unlist_res={}
    for key in res_dir.keys():
        try:
            unlist_res[key]=float(res_dir[key][0])
        except ValueError:
            unlist_res[key]=res_dir[key][0]
    return unlist_res
    
def validate_variables(list_of_var,gen_named_dict,comment,eqn):

    logical_operators=['>','<','==','>=','<=','!=']
    arithmetic_operators=['+','-','*','/','**','%','(',')']
    numbers=['0','1','2','3','4','5','6','7','8','9']
    boolean_operators=['and','or','not']

    res_dict={}
    for i in list_of_var:
           
            if(i not in arithmetic_operators and i[0] not in numbers and i not in boolean_operators and i not in logical_operators ):
             
                 try:
                     if(gen_named_dict[i]<0):
                         invalid_eqn[eqn]=["Invalid",comment,"Value Negative"]
                         return "Err"
                     else:
                         
                         res_dict.update({i:gen_named_dict[i]})
                 except KeyError as e:
                     invalid_eqn[eqn]=["Invalid",comment,"Value Not Found"]
                     return "Err"
    return res_dict
    
def evaluate_equation(line,unlist_res1,unlist_res2,lf):

    if(len(line.strip())==0):
        return
    if(',' not in line):
        print("Specify comment after equation separated by a ,")
        return
    eqn,comm=line.split(",")
    comment=comm.rstrip()
    eqn1=eqn

    if(unlist_res2==None):
        

        tokenized_eqn=mysplit(eqn)
        #print(tokenized_eqn)

        if( '[' in tokenized_eqn):
            #print("Invalid")
            invalid_eqn[eqn1]=["Invalid",comment,"Incorrect eqn format"]
            return
        
        res_dict=validate_variables(tokenized_eqn,unlist_res1,comment,eqn)
        if(res_dict=="Err"):
            return
        
        #print("Res dict is :")
        #print(res_dict)

        for key,value in res_dict.items():
            eqn=eqn.replace(key,str(value))

        #print("Final eqn is :"+eqn)

        try:
            print("Result :"+str(eval(eqn)))
            if(eval(eqn)):
                pass_eqn[eqn1]=["Pass",comment,"-"]
            else:
                fail_eqn[eqn1]=["Fail",comment,"-"]
        except NameError:
            invalid_eqn[eqn1]=["Invalid",comment,"Incorrect Eqn Format"]
            
        '''if(validate(tokenized_eqn,unlist_res1,comment,eqn)==0):
            return
        else:
            print(eqn+":"+str(eval(eqn,unlist_res1)))
            if(eval(eqn,unlist_res1)):
                
                pass_eqn[eqn]=["Pass",comment,"-"]
            else:
                fail_eqn[eqn]=["Fail",comment,"-"]'''
           

    else:

        for key in unlist_res1.keys():
            if(key.startswith('GenName_')):
                gen_name1=key
                break
        gen_name,gen_f1=gen_name1.split('_')

        print(gen_f1)

        for key in unlist_res2.keys():
            if(key.startswith('GenName_')):
                gen_name2=key
                break
        gen_name,gen_f2=gen_name2.split('_')

        print(gen_f2)


        #print("Eqn is ")
        #print(eqn)
        
        tokenized_eqn=mysplit(eqn)
        #print("Tokenized eqn is :")
        #print(tokenized_eqn)

        if('[' and ']' not in tokenized_eqn):
            
            invalid_eqn[eqn1]=["Invalid",comment,"Incorrect eqn format"]
            return

        gen_named_dict={}
        
        for key,value in unlist_res1.items():
            gen_named_dict[key+"["+str(gen_f1)+"]"]=value
        for key,value in unlist_res2.items():
            gen_named_dict[key+"["+str(gen_f2)+"]"]=value

        
        pat='\w+\[\w+\]'

        list_of_variables=re.findall(pat,eqn)

        #print("List of variables are :")
        #print(list_of_variables)

        res_dict=validate_variables(list_of_variables,gen_named_dict,comment,eqn)
        if(res_dict=="Err"):
            return
        
        #print("Res dict is :")
        #print(res_dict)

        for key,value in res_dict.items():
            eqn=eqn.replace(key,str(value))

        #print("Final eqn is :"+eqn)

        try:
            #print("Result :"+str(eval(eqn)))
            if(eval(eqn)):
                    
                pass_eqn[eqn1]=["Pass",comment,"-"]
            else:
                fail_eqn[eqn1]=["Fail",comment,"-"]
        except NameError:
            invalid_eqn[eqn1]=["Invalid",comment,"Incorrect Eqn Format"]
			
def validate_variables_as_list(list_of_var,gen_named_dict,comment,eqn):

    logical_operators=['>','<','==','>=','<=','!=']
    arithmetic_operators=['+','-','*','/','**','%','(',')']
    numbers=['0','1','2','3','4','5','6','7','8','9']
    boolean_operators=['and','or','not']
    res_dict={}
    for i in list_of_var:
            
            if(i not in arithmetic_operators and i[0] not in numbers and i not in boolean_operators and i not in logical_operators ):
             
                 try:
                     print(float(gen_named_dict[i][0]))
                     if(float(gen_named_dict[i][0])<0):
                         cdyn_invalid_eqn[eqn]=["Invalid",comment,"Value Negative"]
                         return "Err"
                     else:
                         
                         res_dict.update({i:gen_named_dict[i]})
                 except KeyError as e:
                     cdyn_invalid_eqn[eqn]=["Invalid",comment,"Value Not Found"]
                     return "Err"
    return res_dict

def evaluate_cdyn_equation(line,cdyn_dict1,cdyn_dict2,res_dict1,res_dict2,ecw_dict1,ecw_dict2,lf):

    if(len(line.strip())==0):
        return
    if(',' not in line):
        print("Specify comment after equation separated by a ,")
        return
    eqn,comm=line.split(",")
    comment=comm.rstrip()
    eqn1=eqn

    if(cdyn_dict2==None and res_dict2==None and ecw_dict2==None):
        tokenized_eqn=mysplit(eqn)
       
        if( '[' in tokenized_eqn):
            
            cdyn_invalid_eqn[eqn1]=["Invalid",comment,"Incorrect eqn format"]
            return

       
        res=validate_variables_as_list(tokenized_eqn,cdyn_dict1,comment,eqn)
        if(res=="Err"):
            return
       
        for key,value in res.items():
            eqn=eqn.replace(key,str(value[0]))

        try:
            print("Result :"+str(eval(eqn)))
            if(eval(eqn)):
                cdyn_pass_eqn[eqn1]=["Pass",comment,"-"]
            else:
                res1=validate_variables_as_list(tokenized_eqn,res_dict1,comment,eqn1)
                res2=validate_variables_as_list(tokenized_eqn,ecw_dict1,comment,eqn1)
                tot="Res File Values "+str(res1)+" Eff cdyn wt values "+str(res2)
                tot1=tot.replace(","," ")
                
                cdyn_fail_eqn[eqn1]=["Fail",comment,tot1]
        except NameError:
            cdyn_invalid_eqn[eqn1]=["Invalid",comment,"Incorrect Eqn Format"]
       
    else:

        for key in res_dict1.keys():
            if(key.startswith('GenName_')):
                gen_name1=key
                break
        gen_name,gen_f1=gen_name1.split('_')

        for key in res_dict2.keys():
            if(key.startswith('GenName_')):
                gen_name2=key
                break
        gen_name,gen_f2=gen_name2.split('_')
      
        tokenized_eqn=mysplit(eqn)
       
        if('[' and ']' not in tokenized_eqn):
            
            cdyn_invalid_eqn[eqn1]=["Invalid",comment,"Incorrect eqn format"]
            return

        gen_named_dict={}
        
        for key,value in res_dict1.items():
            gen_named_dict[key+"["+str(gen_f1)+"]"]=value
        for key,value in res_dict2.items():
            gen_named_dict[key+"["+str(gen_f2)+"]"]=value

        named_cdyn_dict={}

        for key,value in cdyn_dict1.items():
            named_cdyn_dict[key+"["+str(gen_f1)+"]"]=value
        for key,value in cdyn_dict2.items():
            named_cdyn_dict[key+"["+str(gen_f2)+"]"]=value

        eff_cdyn_dict={}

        for key,value in ecw_dict1.items():
            eff_cdyn_dict[key+"["+str(gen_f1)+"]"]=value
        for key,value in ecw_dict2.items():
            eff_cdyn_dict[key+"["+str(gen_f2)+"]"]=value

        pat='\w+\[\w+\]'

        list_of_variables=re.findall(pat,eqn)
        
        res_dict=validate_variables_as_list(list_of_variables,named_cdyn_dict,comment,eqn)
        if(res_dict=="Err"):
            return
        for key,value in res_dict.items():
            eqn=eqn.replace(key,str(value[0]))
        try:
            if(eval(eqn)):
                cdyn_pass_eqn[eqn1]=["Pass",comment,"-"]
            else:
                
                res1=validate_variables_as_list(list_of_variables,gen_named_dict,comment,eqn1)
               
                res2=validate_variables_as_list(list_of_variables,eff_cdyn_dict,comment,eqn1)
               
                tot="Res File Values "+str(res1)+" Eff cdyn wt values "+str(res2)
                tot1=tot.replace(","," ")
               
                cdyn_fail_eqn[eqn1]=["Fail",comment,tot1]
        except NameError:
            cdyn_invalid_eqn[eqn1]=["Invalid",comment,"Incorrect Eqn Format"]


if __name__ == '__main__':
    
    parser = lib.argparse.ArgumentParser(description='This script will do the sanity check on the ALPS outputs')

    parser.add_argument('-o','--log_file',dest="out_log",default=False, help="Output log directory")
    parser.add_argument('-f','--input_file',dest="input_text", help="Input text file")
    args, sub_args = parser.parse_known_args()
    

    list_of_gens=['Gen9LPClient_A0','Gen10LP_A0','Gen11LP_A0','Gen12LP_A0','Gen11_A0']
    src_tar_same=[]
    data_points = []
    not_src_gen=[]
    not_tar_gen=[]
    sgen_notin_rev=[]
    tgen_notin_rev=[]
    improper_inputs=[]
    
    pass_eqn={}
    fail_eqn={}
    invalid_eqn={}
	
    cdyn_fail_eqn={}
    cdyn_pass_eqn={}
    cdyn_invalid_eqn={}
    
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


    ip_file = open(args.input_text,'r')
    index=1
    options=[]
    i=1
    for lines in ip_file:
        cmd_args = lines.split()
        if("evaluate_cdyn_equation" in cmd_args):

            if("-d1" in cmd_args):
                res_dir1_index=cmd_args.index("-d1")
                res_dir1=cmd_args[res_dir1_index+1]
                abs_path1=os.path.abspath(res_dir1)
                print("D1 is "+res_dir1)
            else:
                print("Please specify name of Directory after -d1")
                sys.exit(1)
            
            if("-d2" in cmd_args):
                res_dir2_index=cmd_args.index("-d2")
                res_dir2=cmd_args[res_dir2_index+1]
                abs_path2=os.path.abspath(res_dir2)
            else:
                res_dir2_index=None
                res_dir2=None

            if("-eq" in cmd_args):
                eqn_file_index=cmd_args.index("-eq")
                eqn_file=cmd_args[eqn_file_index+1]
                abs_path3=os.path.abspath(eqn_file)
                print("Eq file is "+eqn_file)
            else:
                print("Please specify name of Equation File after -eq")
                sys.exit(1)

            if(res_dir2!=None):
                if os.path.isdir(res_dir1) and os.path.isdir(res_dir2) and os.path.isfile(eqn_file):

                    log_f="evaluate_cdyn_equation"+str(index)+".csv"
                    lf=open(log_directory+"/"+log_f,"w")

                    
                    for files in os.listdir(res_dir1):
                            if(files.endswith('res.csv')):
                                res_file1=files
                            elif(files.endswith('eff_weights.csv')):
                                eff_cdyn_wt_file1=files
                            else:
                                cdyn_wt_file1=files

                    for files in os.listdir(res_dir2):
                            if(files.endswith('res.csv')):
                                res_file2=files
                            elif(files.endswith('eff_weights.csv')):
                                eff_cdyn_wt_file2=files
                            else:
                                cdyn_wt_file2=files

                    res_dict1=read_residency_file(res_dir1+"/"+res_file1)
                    res_dict2=read_residency_file(res_dir2+"/"+res_file2)

                    ecw_dict1=read_weight_file(res_dir1+"/"+eff_cdyn_wt_file1)
                    ecw_dict2=read_weight_file(res_dir2+"/"+eff_cdyn_wt_file2)

                    cdyn_dict1=read_residency_file(res_dir1+"/"+cdyn_wt_file1)
                    cdyn_dict2=read_residency_file(res_dir2+"/"+cdyn_wt_file2)

                    eqn_f=open(eqn_file,'r')
                    for each_line in eqn_f:
                        evaluate_cdyn_equation(each_line,cdyn_dict1,cdyn_dict2,res_dict1,res_dict2,ecw_dict1,ecw_dict2,lf)

                    try:    
                        print("Equations "+",\t"+"Result"+",\t"+"Comment"+",\t"+"Reason(if any)"+",\t",file=lf)
                        for key,value in cdyn_pass_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2],file=lf)

                        for key,value in cdyn_fail_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2],file=lf)

                        for key,value in cdyn_invalid_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2],file=lf)

                        print ("",file=lf)

                        print("Pass : "+str(len(cdyn_pass_eqn))+" Fail : "+str(len(cdyn_fail_eqn))+" Invalid : "+str(len(cdyn_invalid_eqn)),file=lf)
                        print("Done!!")
                    except NameError:
                        print("Improper log file")
                else:
                    print("Improper files")

            else:
                    if os.path.isdir(res_dir1) and os.path.isfile(eqn_file):

                        log_f="evaluate_cdyn_equation"+str(index)+".csv"
                        lf=open(log_directory+"/"+log_f,"w")
                        
                        for files in os.listdir(res_dir1):
                            if(files.endswith('res.csv')):
                                res_file1=files
                            elif(files.endswith('eff_weights.csv')):
                                eff_cdyn_wt_file1=files
                            else:
                                cdyn_wt_file1=files

                        res_dict1=read_residency_file(res_dir1+"/"+res_file1)
                        cdyn_dict1=read_residency_file(res_dir1+"/"+cdyn_wt_file1)
                        ecw_dict1=read_weight_file(res_dir1+"/"+eff_cdyn_wt_file1)

                        eqn_f=open(eqn_file,'r')
                        for each_line in eqn_f:
                            evaluate_cdyn_equation(each_line,cdyn_dict1,None,res_dict1,None,ecw_dict1,None,lf)

                        try:    
                            print("Equations "+",\t"+"Result"+",\t"+"Comment"+",\t"+"Reason(if any)"+",\t",file=lf)
                            for key,value in cdyn_pass_eqn.items():
                                print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2],file=lf)

                            for key,value in cdyn_fail_eqn.items():
                                print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2],file=lf)

                            for key,value in cdyn_invalid_eqn.items():
                                print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2],file=lf)

                            print ("",file=lf)

                            print("Pass : "+str(len(cdyn_pass_eqn))+" Fail : "+str(len(cdyn_fail_eqn))+" Invalid : "+str(len(cdyn_invalid_eqn)),file=lf)
                            print("Done!!")
                        except NameError:
                            print("Improper log file")
                    else:
                        print("Improper files!Please check the files")
                        sys.exit(1)
						
        if("evaluate_equation" in cmd_args):

            if("-f1" in cmd_args):
                res_file1_index=cmd_args.index("-f1")
                res_file1=cmd_args[res_file1_index+1]
                abs_path1=os.path.abspath(res_file1)
            else:
                print("Please specify name of File1 after -f1")
                sys.exit(1)
            
            if("-f2" in cmd_args):
                res_file2_index=cmd_args.index("-f2")
                res_file2=cmd_args[res_file2_index+1]
                abs_path2=os.path.abspath(res_file2)
            else:
                res_file2_index=None
                res_file2=None
                unlist_res2=None

            if("-eq" in cmd_args):
                eqn_file_index=cmd_args.index("-eq")
                eqn_file=cmd_args[eqn_file_index+1]
                abs_path3=os.path.abspath(eqn_file)
            else:
                print("Please specify name of Equation File after -eq")
                sys.exit(1)

            if(res_file2!=None):
            
                if(os.path.isfile(res_file1) and os.path.isfile(res_file2) and os.path.isfile(eqn_file)):

                    log_f="analyze_equation"+str(index)+".csv"
                    lf=open(log_directory+"/"+log_f,"w")
                
                    res_dict1=read_residency_file(res_file1)
                    res_dict2=read_residency_file(res_file2)
                    unlist_res1=unlist_res_func(res_dict1)
                    unlist_res2=unlist_res_func(res_dict2)
                    eqn_f=open(eqn_file,'r')
                    for each_line in eqn_f:
                        if (len(each_line.strip())==0):
                            continue
                        else:
                            evaluate_equation(each_line,unlist_res1,unlist_res2,lf)
                    try:    
                        print("Equations "+",\t"+"Result"+",\t"+"Comment"+",\t"+"Reason(if any)"+",\t",file=lf)
                        for key,value in pass_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2]+",\t",file=lf)

                        for key,value in fail_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2]+",\t",file=lf)

                        for key,value in invalid_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2]+",\t",file=lf)

                        print ("",file=lf)

                        print("Pass : "+str(len(pass_eqn))+" Fail : "+str(len(fail_eqn))+" Invalid : "+str(len(invalid_eqn)),file=lf)
                        print("Done!!")
                    except NameError:
                        print("Improper file")
                else:
                    print("Improper files!Please check the files")
                    sys.exit(1)
                    
            else:
                if(os.path.isfile(res_file1) and os.path.isfile(eqn_file)):

                    log_f="analyze_equation"+str(index)+".csv"
                    lf=open(log_directory+"/"+log_f,"w")
                    
                    res_dict1=read_residency_file(res_file1)
                    unlist_res1=unlist_res_func(res_dict1)
                    eqn_f=open(eqn_file,'r')
                    for each_line in eqn_f:
                        if (len(each_line.strip())==0):
                            continue
                        evaluate_equation(each_line,unlist_res1,None,lf)
                    try:    
                        print("Equations "+",\t"+"Result"+",\t"+"Comment"+",\t"+"Reason(if any)"+",\t",file=lf)
                        for key,value in pass_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2]+",\t",file=lf)

                        for key,value in fail_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2]+",\t",file=lf)

                        for key,value in invalid_eqn.items():
                            print ((key+",\t")+value[0]+",\t"+value[1]+",\t"+value[2]+",\t",file=lf)

                        print ("",file=lf)

                        print("Pass : "+str(len(pass_eqn))+" Fail : "+str(len(fail_eqn))+" Invalid : "+str(len(invalid_eqn)),file=lf)
                        print("Done!!")
                    except NameError:
                        print("Improper file")
                    

    
                else:
                    print("Improper files!Please check the files")
                    sys.exit(1)

        if "compare_cdyn_dir" in cmd_args:
            options.clear()
            clusters=units=None
            cdyn_out_dir1_index=cmd_args.index("-f1")
            cdyn_out_dir1=cmd_args[cdyn_out_dir1_index+1]
            abs_path1=os.path.abspath(cdyn_out_dir1)
            cdyn_out_dir2_index=cmd_args.index("-f2")
            cdyn_out_dir2=cmd_args[cdyn_out_dir2_index+1]
            abs_path2=os.path.abspath(cdyn_out_dir2)
            #arch_index=cmd_args.index("-arch")
            #arch=cmd_args[arch_index+1]
            if "-fps" in cmd_args:
                options.append("fps")
            if "-gt" in cmd_args:
                options.append("gt")
            if "-clusters" in cmd_args:
                clusters_index = cmd_args.index("-clusters")
                clusters=cmd_args[clusters_index+1]
                options.append("clusters")
                options.append("clusters_list")
            else:
                if "-clusters_all" in cmd_args:
                    clusters=None
                    options.append("clusters")
                    options.append("clusters_all")
            if "-units" in cmd_args:
                units_index = cmd_args.index("-units")
                units=cmd_args[units_index+1]
                options.append("units")
                options.append("units_list")
            else:
                if "-units_all" in cmd_args:
                    units = None
                    options.append("units")
                    options.append("units_all")
            if "-states" in cmd_args:
                options.append("states")

            if "-tol" in cmd_args:
                tol_index=cmd_args.index("-tol")
                tolerance=cmd_args[tol_index+1]
            else:
                tolerance=None

            workloads_index=cmd_args.index("-wl")
            workloads=cmd_args[workloads_index+1]


            if os.path.isfile(workloads):
                wl_txt=open(workloads, 'r')


            if os.path.isdir(cdyn_out_dir1) and os.path.isdir(cdyn_out_dir2):
                log_f = "compare_cdyn_dir"+str(index)+".csv"
                lf = open(log_directory+"/"+log_f,'w')
                print ('########### Output file/directories:'+abs_path1+' and '+abs_path2+' ##########',file=lf)
                for lines in wl_txt:
                    for files in os.listdir(cdyn_out_dir1):
                        if files.endswith(".yaml"):
                            match11=re.split('__',files)
                            lines11=re.split('__',lines)
                            if match11[0] == lines11[0]: #files == lines.strip():
                                print (files)
                                for files2 in os.listdir(cdyn_out_dir2):
                                    match1 = re.split('__',files)
                                    match2 = re.split('__',files2)
                                    if (files2.endswith(".yaml")) and (match1[0] ==match2[0]):
                                        wl1 = re.split('.yaml', files)
                                        wl2 = re.split('.yaml', files2)
                                        print ("###### Workload: "+wl1[0]+"######",file=lf)
                                        print ("", file=lf)
                                        yaml_file1 = open(cdyn_out_dir1+"/"+files,'r')
                                        yaml_file2 = open(cdyn_out_dir2+"/"+files2,'r')
                                        cdyn_dict1 = yaml.load(yaml_file1)
                                        cdyn_dict2 = yaml.load(yaml_file2)
                                        if "-states" in cmd_args:
                                            res_file1=wl1[0]+".res.csv"
                                            res_file2=wl2[0]+".res.csv"
                                            weights_file1=wl1[0]+".yaml.eff_weights.csv"
                                            weights_file2=wl2[0]+".yaml.eff_weights.csv"
                                            cdyn_csv_dict1=read_weight_file(weights_file1,optional=abs_path1)
                                            cdyn_csv_dict2=read_weight_file(weights_file2,optional=abs_path2)
                                            res_file_dict1=read_residency_file(res_file1,optional=abs_path1)
                                            res_file_dict2=read_residency_file(res_file2,optional=abs_path2)
                                        else:
                                            cdyn_csv_dict1= None
                                            cdyn_csv_dict2= None
                                            res_file_dict1= None
                                            res_file_dict2= None
                                        compare_cdyn_dir(cdyn_dict1,cdyn_dict2,res_file_dict1,res_file_dict2,cdyn_csv_dict1,cdyn_csv_dict2,wl1[0],lf,options,clusters,units)
                                    else:
                                        continue
                            else:
                                continue
                            
            elif os.path.isfile(cdyn_out_dir1) and os.path.isfile(cdyn_out_dir2):
                res_dict1=read_residency_file(cdyn_out_dir1)
                res_dict2=read_residency_file(cdyn_out_dir2)
                log_f = "compare_res_files"+str(index)+".log"
                lf = open(log_directory+"/"+log_f,'w')
                print ('########### Output file/directory:'+abs_path1+' and '+abs_path2+'##########',file=lf) 
                compare_cdyn_dir(cdyn_dict1,cdyn_dict2,tolerance,lf)
		
	    

            else:
                improper_inputs.append(lines)
                continue
            
        index=index+1
