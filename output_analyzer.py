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


def compare_cdyn_dir(cdyn_dict1,cdyn_dict2,res_file_dict1,res_file_dict2,cdyn_csv_dict1,cdyn_csv_dict2,lf,options,arch_name,cluster_list=None,units_list=None):

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
            print ((elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num1)+",\t"+str(diff)).expandtabs(16),file=lf)
        cdyn_by_fps1 = round(cdyn_dict1['Total_GT_Cdyn(nF)']/cdyn_dict1['FPS'],2)
        cdyn_by_fps2 = round(cdyn_dict2['Total_GT_Cdyn(nF)']/cdyn_dict1['FPS'],2)
        ratio_diff = round(float(cdyn_by_fps2-cdyn_by_fps1),2)
        print (("Total_GT_Cdyn/FPS,\t").expandtabs(26)+(str(cdyn_by_fps1)+",\t"+str(cdyn_by_fps2)+",\t"+str(diff)).expandtabs(16),file=lf)
        print ("",file=lf)


    if "clusters" in options:
        print("##### Cluster cdyn differences #####",file=lf)
        print ("",file=lf)
        cluster_cdyn={}
        for clusters in cdyn_dict1['cluster_cdyn_numbers(pF)'].keys():
            if "clusters_list" in options:
                if cluster_list != None:
                    clust=re.split(',',cluster_list)
                    if clusters in clust:
                        print(clusters,":",file=lf)
                        types=['syn','inf','ebb','total']
                        for elements in types:
                            num1=cdyn_dict1['cluster_cdyn_numbers(pF)'][clusters][elements]
                            num2=cdyn_dict2['cluster_cdyn_numbers(pF)'][clusters][elements]
                            diff=round(float(num2-num1),2)
                            print (("    "+elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                            #Finding sum of all unit wise gate count which yields total cluster gate count
                            #cluster_gc_sum(clusters,elements,cdyn_dict1,cdyn_dict2)
                            sum_gc1=sum_gc2=0.0
                            for items in cluster_syn_dict.keys():
                                if re.search(clusters,items):
                                #if clusters in items:
                                    for ff_keys in cdyn_dict1[clusters].keys():
                                        if ff_keys not in cluster_syn_dict[items] and elements == 'inf':
                                            sum_gc1=sum_gc1+cdyn_dict1[clusters][ff_keys][arch_name]
                                        if ff_keys in cluster_syn_dict[items] and elements == 'syn':
                                            sum_gc1=sum_gc1+cdyn_dict1[clusters][ff_keys][arch_name]
                                        if elements == 'ebb':
                                            sum_gc1=1.0 
                        
                            for items in cluster_syn_dict.keys():
                                #if clusters in items:
                                if re.search(clusters,items):
                                    for ff_keys in cdyn_dict2[clusters].keys():
                                        if ff_keys not in cluster_syn_dict[items] and elements == 'inf':
                                            sum_gc2=sum_gc2+cdyn_dict2[clusters][ff_keys][arch_name]
                                        if ff_keys in cluster_syn_dict[items] and elements == 'syn':
                                            sum_gc2=sum_gc2+cdyn_dict2[clusters][ff_keys][arch_name]
                                        if elements == 'ebb':
                                            sum_gc2=1.0
                            if elements == 'total':
                                continue
                            else:
                                if (sum_gc1 == 0.0 or sum_gc2 == 0.0):
                                    continue
                                else:
                                    cdyn_by_gc1=(num1/sum_gc1)
                                    cdyn_by_gc2=(num2/sum_gc2)
                                    cdyn_by_gc_diff = float(cdyn_by_gc2-cdyn_by_gc1)
                                    #print (("    "+elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(40),file=lf)
                                    print (("    cdyn_"+elements+"/gc_"+elements+",\t").expandtabs(26)+(str(cdyn_by_gc1)+",\t"+str(cdyn_by_gc2)+",\t"+str(cdyn_by_gc_diff)).expandtabs(36),file=lf)
                        #cluster_cdyn[elements]=[clusters,num1,num2,diff]
                    
            if "clusters_all" in options:
                print(clusters,":",file=lf)
                types=['syn','inf','ebb','total']
                for elements in types:
                    num1=cdyn_dict1['cluster_cdyn_numbers(pF)'][clusters][elements]
                    num2=cdyn_dict2['cluster_cdyn_numbers(pF)'][clusters][elements]
                    if num1!=0 and num2!=0:
                        diff=round(((num2/num1)-1)*100,1)
                    else:
                        continue
                    #diff=round(float(num2-num1),2)
                    if diff > float(tolerance):
                        print (("    "+elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                        sum_gc1=sum_gc2=0.0
                        for items in cluster_syn_dict.keys():
                            if re.search(clusters,items):
                            #if clusters in items:
                                for ff_keys in cdyn_dict1[clusters].keys():
                                    if ff_keys not in cluster_syn_dict[items] and elements == 'inf':
                                        sum_gc1=sum_gc1+cdyn_dict1[clusters][ff_keys][arch_name]
                                    if ff_keys in cluster_syn_dict[items] and elements == 'syn':
                                        sum_gc1=sum_gc1+cdyn_dict1[clusters][ff_keys][arch_name]
                                    if elements == 'ebb':
                                        sum_gc1=1.0 
                        
                        for items in cluster_syn_dict.keys():
                            #if clusters in items:
                            if re.search(clusters,items):
                                for ff_keys in cdyn_dict2[clusters].keys():
                                    if ff_keys not in cluster_syn_dict[items] and elements == 'inf':
                                        sum_gc2=sum_gc2+cdyn_dict2[clusters][ff_keys][arch_name]
                                    if ff_keys in cluster_syn_dict[items] and elements == 'syn':
                                        sum_gc2=sum_gc2+cdyn_dict2[clusters][ff_keys][arch_name]
                                    if elements == 'ebb':
                                        sum_gc2=1.0
                        if elements == 'total':
                            continue
                        else:
                            if (sum_gc1 == 0.0 or sum_gc2 == 0.0):
                                continue
                            else:
                                cdyn_by_gc1=(num1/sum_gc1)
                                cdyn_by_gc2=(num2/sum_gc2)
                                cdyn_by_gc_diff = float(cdyn_by_gc2-cdyn_by_gc1)
                                #print (("    "+elements+",\t").expandtabs(26)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(40),file=lf)
                                print (("    cdyn_"+elements+"/gc_"+elements+",\t").expandtabs(26)+(str(cdyn_by_gc1)+",\t"+str(cdyn_by_gc2)+",\t"+str(cdyn_by_gc_diff)).expandtabs(36),file=lf)


    if "units" in options:
        print("",file=lf)
        print("##### Unit cdyn differences #####",file=lf)
        print("",file=lf)

        for cluster in cdyn_dict1['unit_cdyn_numbers(pF)'].keys():
            print (cluster,":",file=lf)
            if units_list != None and "units_list" in options:
                for unit in cdyn_dict1['unit_cdyn_numbers(pF)'][cluster].keys():
                    unit_name=re.split(',',units_list)
                    if unit in unit_name:
                        if unit in cdyn_dict2['unit_cdyn_numbers(pF)'][cluster].keys():
                        #cdyn_unit=cdyn_dict.get('unit_cdyn_numbers(pF)',{}).get(clusters,{}).get(units)
                            num1=cdyn_dict1['unit_cdyn_numbers(pF)'][cluster][unit]
                            num2=cdyn_dict2['unit_cdyn_numbers(pF)'][cluster][unit]
                            diff=round((num2-num1),2)
                            gc1=cdyn_dict1[cluster][unit][arch_name]
                            gc2=cdyn_dict2[cluster][unit][arch_name]
                            cdyn_by_gc1=(num1/gc1)
                            cdyn_by_gc2=(num2/gc2)
                            cdyn_by_gc_diff = float(cdyn_by_gc2-cdyn_by_gc1) 
                            print (("  "+unit+"\t").expandtabs(50)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                            #print (("  cdyn_"+unit+"/gc_"+unit+",\t").expandtabs(50)+(str(cdyn_by_gc1)+",\t"+str(cdyn_by_gc2)+",\t"+str(cdyn_by_gc_diff)).expandtabs(36),file=lf)
                            category="ALPS Model(pF)"
                            for stat in cdyn_dict1[category]['GT'][cluster][unit].keys():
                                
                                try:
                                    key_list = cdyn_dict2[category]['GT'][cluster][unit][stat].keys()
                                    print ("    "+stat+":",file=lf)
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

                                    if ((stat in cdyn_csv_dict1.keys()) and (arch_name in cdyn_csv_dict1[stat].keys())):
                                        wt1=round(float(cdyn_csv_dict1[stat][arch_name][0]),2)
                                    else: 
                                        wt1="-"
                                    if ((stat in cdyn_csv_dict2.keys()) and (arch_name in cdyn_csv_dict2[stat].keys())):
                                        wt2=round(float(cdyn_csv_dict2[stat][arch_name][0]),2)
                                    else: 
                                        wt2="-"
                                    if stat in res_file_dict1.keys():
                                        res1=round(float(res_file_dict1[stat][0]),2)
                                    else:
                                        res1="-"
                                    if stat in res_file_dict2.keys():
                                        res2=round(float(res_file_dict2[stat][0]),2)
                                    else:
                                        res2="-"
                                    
                                
                                    num1 = ref_num
                                    num2 = new_num
                                    diff=round((num2-num1),2)
                                    print (("    "+stat+"\t").expandtabs(50)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                                    print (("      CDYN_WT\t").expandtabs(50)+(str(wt1)+",\t"+str(wt2)).expandtabs(36),file=lf)
                                    print (("      RES_VALUE\t").expandtabs(50)+(str(res1)+",\t"+str(res2)).expandtabs(36),file=lf)

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
                                    
                                    if ((sub_stat in cdyn_csv_dict1.keys()) and (arch_name in cdyn_csv_dict1[sub_stat].keys())):
                                        wt1=round(float(cdyn_csv_dict1[sub_stat][arch_name][0]),2)
                                    else: 
                                        wt1="-"
                                    if ((sub_stat in cdyn_csv_dict2.keys()) and (arch_name in cdyn_csv_dict2[sub_stat].keys())):
                                        wt2=round(float(cdyn_csv_dict2[sub_stat][arch_name][0]),2)
                                    else: 
                                        wt2="-"
                                    if sub_stat in res_file_dict1.keys():
                                        res1=round(float(res_file_dict1[sub_stat][0]),2)
                                    else:
                                        res1="-"
                                    if sub_stat in res_file_dict2.keys():
                                        res2=round(float(res_file_dict2[sub_stat][0]),2)
                                    else:
                                        res2="-"

                                    
                                    num1 = ref_num
                                    num2 = new_num
                                    diff=round((num2-num1),2)
                                    print (("      "+sub_stat+"\t").expandtabs(50)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                                    print (("        CDYN_WT\t").expandtabs(50)+(str(wt1)+",\t"+str(wt2)).expandtabs(36),file=lf)
                                    print (("        RES_VALUE\t").expandtabs(50)+(str(res1)+",\t"+str(res2)).expandtabs(36),file=lf)
                        #unit_cdyn[units]=[clusters,cdyn_unit]
                        else:
                            continue
            if "units_all" in options:
                for unit in cdyn_dict1['unit_cdyn_numbers(pF)'][cluster].keys():
                    if unit in cdyn_dict2['unit_cdyn_numbers(pF)'][cluster].keys():
                        #cdyn_unit=cdyn_dict.get('unit_cdyn_numbers(pF)',{}).get(clusters,{}).get(units)
                        num1=cdyn_dict1['unit_cdyn_numbers(pF)'][cluster][unit]
                        num2=cdyn_dict2['unit_cdyn_numbers(pF)'][cluster][unit]
                        if num1 !=0 and num2 !=0:
                            diff=round(((num2/num1)-1)*100,1)
                        else:
                            continue
                        if diff > float(tolerance):
                            print (("  "+unit+"\t").expandtabs(50)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)

                            category="ALPS Model(pF)"
                            for stat in cdyn_dict1[category]['GT'][cluster][unit].keys():
                                try:
                                    key_list = cdyn_dict2[category]['GT'][cluster][unit][stat].keys()
                                    print ("    "+stat+":",file=lf)
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
                                    '''try:
                                        wt1=round(cdyn_csv_dict1[stat][arch_name],2)
                                    except:
                                        wt1=0
                                    try:
                                        wt2=round(cdyn_csv_dict2[stat][arch_name],2)
                                    except:
                                        wt2=0
                                    try:
                                        res1=round(res_file_dict1[stat],2)
                                    except:
                                        res1=0.0
                                    try:
                                        res2=round(res_file_dict2[stat],2)
                                    except:
                                        res2=0.0'''
                                    #print (cdyn_csv_dict1[stat][arch_name],res_file_dict1[stat])
                                    if ((stat in cdyn_csv_dict1.keys()) and (arch_name in cdyn_csv_dict1[stat].keys())):
                                        wt1=round(float(cdyn_csv_dict1[stat][arch_name][0]),2)
                                    else: 
                                        wt1="-"
                                    if ((stat in cdyn_csv_dict2.keys()) and (arch_name in cdyn_csv_dict2[stat].keys())):
                                        wt2=round(float(cdyn_csv_dict2[stat][arch_name][0]),2)
                                    else: 
                                        wt2="-"
                                    if stat in res_file_dict1.keys():
                                        res1=round(float(res_file_dict1[stat][0]),2)
                                    else:
                                        res1="-"
                                    if stat in res_file_dict2.keys():
                                        res2=round(float(res_file_dict2[stat][0]),2)
                                    else:
                                        res2="-"
                                    #try:
                                    num1 = ref_num
                                    num2 = new_num
                                    diff=round((num2-num1),2)
                                    print (("    "+stat+"\t").expandtabs(50)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                                    print (("      CDYN_WT\t").expandtabs(50)+(str(wt1)+",\t"+str(wt2)).expandtabs(36),file=lf)
                                    print (("      RES_VALUE\t").expandtabs(50)+(str(res1)+",\t"+str(res2)).expandtabs(36),file=lf)
                                    '''except:
                                        pass'''

                                for sub_stat in key_list:
                                    if sub_stat == "total":
                                        continue
                                    stat_print = sub_stat.replace(stat+"_",'  ')
                                    try:
                                        ref_num = cdyn_dict1[category]['GT'][cluster][unit][stat][sub_stat]
                                    except:
                                        ref_num = 0.0
                                    try:
                                        new_num = cdyn_dict2[category]['GT'][cluster][unit][stat][sub_stat]
                                    except:
                                        new_num = 0.0

                                    if ((sub_stat in cdyn_csv_dict1.keys()) and (arch_name in cdyn_csv_dict1[sub_stat].keys())):
                                        wt1=round(float(cdyn_csv_dict1[sub_stat][arch_name][0]),2)
                                    else: 
                                        wt1="-"
                                    if ((sub_stat in cdyn_csv_dict2.keys()) and (arch_name in cdyn_csv_dict2[sub_stat].keys())):
                                        wt2=round(float(cdyn_csv_dict2[sub_stat][arch_name][0]),2)
                                    else: 
                                        wt2="-"
                                    if sub_stat in res_file_dict1.keys():
                                        res1=round(float(res_file_dict1[sub_stat][0]),2)
                                    else:
                                        res1="-"
                                    if sub_stat in res_file_dict2.keys():
                                        res2=round(float(res_file_dict2[sub_stat][0]),2)
                                    else:
                                        res2="-"

                                    num1 = ref_num
                                    num2 = new_num
                                    diff=round((num2-num1),2)
                                    print (("      "+sub_stat+"\t").expandtabs(50)+(str(num1)+",\t"+str(num2)+",\t"+str(diff)).expandtabs(36),file=lf)
                                    print (("        CDYN_WT\t").expandtabs(50)+(str(wt1)+",\t"+str(wt2)).expandtabs(36),file=lf)
                                    print (("        RES_VALUE\t").expandtabs(50)+(str(res1)+",\t"+str(res2)).expandtabs(36),file=lf)
                        else:
                            continue


    '''print (unit_cdyn,file=lf)

    print("",file=lf)
    print(("Cluster_name,\ttype,\tdir1_cdyn,\tdir2_cdyn,\tdiff").expandtabs(30),file=lf)
    for key,value in cluster_cdyn.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+",\t"+str(value[3])).expandtabs(30),file=lf)'''

    '''print("",file=lf)
    print(("Cluster_name,\tcluster_ebb,\tcdyn_cluster_infra,\tcdyn_cluster_syn,\tcdyn_cluster_total").expandtabs(30),file=lf)
    for key,value in cluster_cdyn2.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+",\t"+str(value[3])).expandtabs(30),file=lf)

    print ("",file=lf)
    print(("Unit_name,\tCluster_name,\tcdyn_unit").expandtabs(30),file=lf)
    #order = OrderedDict(sorted(unit_cdyn.items(),key=lambda x: x[1][0]))
    for key,value in unit_cdyn.items():
        print ((key+",\t"+value[0]+",\t"+str(value[1])).expandtabs(30),file=lf)'''       


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

        if "compare_cdyn_dir" in cmd_args:
            options.clear()
            clusters=units=None
            cdyn_out_dir1_index=cmd_args.index("-f1")
            cdyn_out_dir1=cmd_args[cdyn_out_dir1_index+1]
            abs_path1=os.path.abspath(cdyn_out_dir1)
            cdyn_out_dir2_index=cmd_args.index("-f2")
            cdyn_out_dir2=cmd_args[cdyn_out_dir2_index+1]
            abs_path2=os.path.abspath(cdyn_out_dir2)
            arch_index=cmd_args.index("-arch")
            arch=cmd_args[arch_index+1]
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
            if "-tol" in cmd_args:
                tol_index=cmd_args.index("-tol")
                tolerance=cmd_args[tol_index+1]
            else:
                tolerance=None

            workloads_index=cmd_args.index("-wl")
            workloads=cmd_args[workloads_index+1]
            
            # Reading the cdyn.csv file from the command line
            if "-c1" in cmd_args:
                cdyn_csv_index1=cmd_args.index("-c1")
                cdyn_csv1=cmd_args[cdyn_csv_index1+1]
                cdyn_csv_dict1=read_cdyn_file(cdyn_csv1)
            else:
                cdyn_csv_dict1=None
            if "-c2" in cmd_args:
                cdyn_csv_index2=cmd_args.index("-c2")
                cdyn_csv2=cmd_args[cdyn_csv_index2+1]
                cdyn_csv_dict2=read_cdyn_file(cdyn_csv2)
            else:
                cdyn_csv_dict2=None

            if os.path.isfile(workloads):
                wl_txt=open(workloads, 'r')
                
            if os.path.isdir(cdyn_out_dir1) and os.path.isdir(cdyn_out_dir2):
                log_f = "compare_cdyn_dir"+str(index)+".log"
                lf = open(log_directory+"/"+log_f,'w')
                print ('########### Output file/direcotories:'+abs_path1+' and '+abs_path2+' ##########',file=lf)
                for lines in wl_txt:
                    for files in os.listdir(cdyn_out_dir1):
                        if files.endswith(".yaml"):
                            if files == lines.strip():
                                for files2 in os.listdir(cdyn_out_dir2):
                                    wl1 = re.split('.yaml', files)
                                    wl2 = re.split('.yaml', files2)
                                    if files == files2:
                                
                                        print ("###### Workload: "+wl1[0]+"######",file=lf)
                                        print ("", file=lf)
                                        yaml_file1 = open(cdyn_out_dir1+"/"+files,'r')
                                        yaml_file2 = open(cdyn_out_dir2+"/"+files2,'r')
                                        cdyn_dict1 = yaml.load(yaml_file1)
                                        cdyn_dict2 = yaml.load(yaml_file2)
                                        res_file1=wl1[0]+".res.csv"
                                        res_file2=wl2[0]+".res.csv"
                                        res_file_dict1=read_residency_file(res_file1,optional=abs_path1)
                                        res_file_dict2=read_residency_file(res_file2,optional=abs_path2)
                                        compare_cdyn_dir(cdyn_dict1,cdyn_dict2,res_file_dict1,res_file_dict2,cdyn_csv_dict1,cdyn_csv_dict2,lf,options,arch,clusters,units)
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
