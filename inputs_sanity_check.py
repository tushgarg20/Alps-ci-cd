from __future__ import division
import shlex 
import subprocess
from subprocess import call
import sys
import csv
import pdb
import re
import lib.yaml as yaml  # requires PyYAML
import itertools
import lib.argparse
import logging
import logging.handlers
import os
from pathlib import Path
import time



## Finds the slope and intercept for the given data_points
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
    #try:
    slope = (sigma_xy - (n * mean_x * mean_y))/float(sigma_sqrx - (n * mean_x * mean_x))
    #except ZeroDivisionError:
    #pass
    intercept = mean_y - (slope * mean_x)
    return slope,intercept

## Read the cdyn.csv file into the dictianory
def read_cdyn_file(cdyn_file_name):
    cdyn_wt={}

    with open(cdyn_file_name) as csvfile:
        obj=(csv.reader(csvfile))
        for row in obj:
            cdyn_wt.setdefault(row[1],{})
            cdyn_wt[row[1]].setdefault(row[2],{})
            cdyn_wt[row[1]][row[2]][row[0]]=[row[3],row[4],row[5]]

    return cdyn_wt

def read_gc_file(gc_file_name):
    cdyn_gc={}
    gen_list=['Gen9LPClient','Gen9LPSoC','Gen9LPglv','Gen9.5LP','Gen10LP','Gen11','Gen11LP','Gen12LPAllGc','Gen12LPPwrGc','Gen12LP']
    index=2
    rows=0
    for element in gen_list:
        with open(gc_file_name) as csvfile:
            obj=(csv.reader(csvfile))
            next(obj, None)
            for row in obj:
                rows=rows+1
                cdyn_gc.setdefault(element,{})
                cdyn_gc[element].setdefault(row[1],{})
                cdyn_gc[element][row[1]][row[0]]=[row[index]]
            index=index+1
    return cdyn_gc

## Read residency file in to the directory
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


def compare_gc(gc_dict, src_gen, target_gen, scaling_factor, tolerance, log_dir,index,abs_path):
    skey = re.split('_', src_gen)
    sgen = skey[0]
    sstep = skey[1]
    tkey = re.split('_', target_gen)
    tgen = tkey[0]
    tstep = tkey[1]
    list_of_xstates = []
    list_of_comm_states = []
    list_of_individual_tarstates = []
    src_tar_gc_zero=[]
    src_gc_zero=[]
    tar_gc_zero=[]
    new_tar_pstate=[]
    sf=scaling_factor
    bin_one={}
    bin_two={}
    bin_three={}
    bin_four={}
    bin_five={}
    bin_six={}
    cluster_gc_diff_bin={}
    ratio_diff_bin = {}
    tolerance=float(tolerance)
    bin_count=5.0
    tol=tolerance
    if tolerance > 0.0:
        bin_range=round((100.0-tolerance)/bin_count,2)
    else:
        bin_range=-round((100.0+tolerance)/bin_count,2)
    infra_states=['Assign','CLKGLUE','DOP','NONCLKGLUE','CPunit','Repeater']
    xinfra_states=['SMALL','DFX']

    log_f = "compare_gc-"+sgen+"-"+tgen+"-tol_"+str(tolerance)+"-scal_fact_"+str(sf)+"-"+str(index)+".log"
    lf = open(log_dir+"/"+log_f,'w')
    print ('########### Check1: Units for which '+abs_path+':gate count differ by more than tolerance of '+str(tolerance)+'% ##########', file=lf)
    print ("",file=lf)
    print (('Unit,\tCluster,\tGC:'+str(src_gen)+',\tGC:'+str(target_gen)+',\tDiff').expandtabs(usw), file = lf)
    
    for cluster in gc_dict[sgen].keys():
        gc_src_sum = 0.0
        gc_tgt_sum = 0.0
        gc_xinfra_src_sum =0.0
        gc_xinfra_tgt_sum =0.0

        for units in gc_dict[sgen][cluster].keys():
            if any(x in units for x in infra_states):
                continue
            src_gc = round(float(gc_dict[sgen][cluster][units][0]),1)
            if units in gc_dict[tgen][cluster].keys():
                tgt_gc = round(float(gc_dict[tgen][cluster][units][0]),1)
                if (src_gc == 0.0 and tgt_gc == 0.0):
                    src_tar_gc_zero.append(units)
                if (src_gc == 0.0):
                    src_gc_zero.append(units)
                if (tgt_gc == 0.0):
                    tar_gc_zero.append(units)
                if src_gc != 0.0 and tgt_gc != 0.0:
                    pstate_gc_diff = round((((sf*tgt_gc)/src_gc)-1)*100,1)
                    gc_src_sum = round(gc_src_sum+src_gc,1)
                    gc_tgt_sum = round(gc_tgt_sum+tgt_gc,1)
                    if units in xinfra_states:
                        gc_xinfra_src_sum=gc_xinfra_src_sum+src_gc
                        gc_xinfra_tgt_sum=gc_xinfra_tgt_sum+src_gc
                    src_ratio = round(gc_xinfra_src_sum/gc_src_sum,2)
                    tgt_ratio = round(gc_xinfra_tgt_sum/gc_tgt_sum,2)
                    ratio_diff_bin[cluster] = [src_ratio,tgt_ratio] 
                    
                    cluster_gc_diff = round((((sf*gc_tgt_sum)/gc_src_sum)-1)*100,1)
                        
                    if tolerance < 0.0:
                        # Check if the difference in RefGC is more than tolerance.
                        if cluster_gc_diff < tolerance:
                            cluster_gc_diff_bin[cluster]=[gc_src_sum,gc_tgt_sum,cluster_gc_diff]

                        if pstate_gc_diff < tolerance:
                            if tolerance >= pstate_gc_diff >= (tolerance+(bin_range*1.0)):
                                bin_one[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*1.0)) >= pstate_gc_diff >= (tolerance+(bin_range*2.0)):
                                bin_two[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*2.0)) >= pstate_gc_diff >= (tolerance+(bin_range*3.0)):
                                bin_three[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*3.0)) >= pstate_gc_diff >= (tolerance+(bin_range*4.0)):
                                bin_four[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*4.0)) >= pstate_gc_diff >= (tolerance+(bin_range*5.0)):
                                if any(x in units for x in xinfra_states):
                                    continue
                                bin_five[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            else:
                                if pstate_gc_diff < -100.0:
                                    bin_six[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                    else:
                        if cluster_gc_diff > tolerance:
                            cluster_gc_diff_bin[cluster]=[gc_src_sum,gc_tgt_sum,cluster_gc_diff]

                        if pstate_gc_diff > tolerance:
                            if tolerance <= pstate_gc_diff <= (tolerance+(bin_range*1.0)):
                                bin_one[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*1.0)) <= pstate_gc_diff <= (tolerance+(bin_range*2.0)):
                                bin_two[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*2.0)) <= pstate_gc_diff <= (tolerance+(bin_range*3.0)):
                                bin_three[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*3.0)) <= pstate_gc_diff <= (tolerance+(bin_range*4.0)):
                                bin_four[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*4.0)) <= pstate_gc_diff <= (tolerance+(bin_range*5.0)):
                                if any(x in units for x in xinfra_states):
                                    continue
                                bin_five[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            else:
                                if pstate_gc_diff > 100.0:
                                    bin_six[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

    list_dict=[bin_one,bin_two,bin_three,bin_four,bin_five]
    index = 1
    for value in list_dict:
        temp = round(tolerance,2)
        temp2= temp+bin_range
        print ("",file=lf)
        print ("########## Bin:"+str(index)+" Difference range: "+str(temp)+"% - "+str(temp2)+"% ##########",file=lf)
        for key, value in value.items():
            print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+",\t"+str(value[3])+"%").expandtabs(usw),file=lf)
        tolerance=tolerance+bin_range
        index=index+1

    print ("",file=lf)
    print ("########## Difference more than "+str(tol+(bin_range*5.0))+"% ##########",file=lf)
    for key, value in bin_six.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+",\t"+str(value[3])+"%").expandtabs(usw),file=lf) 

    print ("",file=lf)
    print ('########### Check2: Clusters for which '+abs_path+':gate count differ by more than tolerance of '+str(tol)+'% ##########', file=lf)
    print ("",file=lf)
    print (('Cluster,\tCluster GC:'+str(src_gen)+',\tCluster GC:'+str(target_gen)+',\tDiff').expandtabs(usw), file = lf)
    for key, value in cluster_gc_diff_bin.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(usw),file=lf)

    print ("",file=lf)
    print ('########### Check3: Clusters for which '+abs_path+': ratio between non-infra units gate count to total cluster gate count ##########', file=lf)
    print ("",file=lf)
    print (('Cluster,\tSource_gen_ratio:'+str(sgen)+',\tTarget_gen_ratio:'+str(tgen)).expandtabs(usw), file = lf)
    for key, value in ratio_diff_bin.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])).expandtabs(usw),file=lf)
        
    print ("",file=lf)
    print ("########## "+src_gen+" units with Design DB GC 0.0 ##########",file=lf)
    for states in src_gc_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+target_gen+" units with Design DB GC 0.0 ##########",file=lf)
    for states in tar_gc_zero:
        print(states, file =lf)

def compare_gc_files(gc_dict1, gc_dict2, src_gen, target_gen, scaling_factor, tolerance, log_dir,index,abs_path1, abs_path2):
    skey = re.split('_', src_gen)
    sgen = skey[0]
    sstep = skey[1]
    tkey = re.split('_', target_gen)
    tgen = tkey[0]
    tstep = tkey[1]
    list_of_xstates = []
    list_of_comm_states = []
    list_of_individual_tarstates = []
    src_tar_gc_zero=[]
    src_gc_zero=[]
    tar_gc_zero=[]
    new_tar_pstate=[]
    sf=scaling_factor
    bin_one={}
    bin_two={}
    bin_three={}
    bin_four={}
    bin_five={}
    bin_six={}
    cluster_gc_diff_bin={}
    ratio_diff_bin={}
    tolerance=float(tolerance)
    bin_count=5.0
    tol=tolerance
    if tolerance > 0.0:
        bin_range=round((100.0-tolerance)/bin_count,2)
    else:
        bin_range=-round((100.0+tolerance)/bin_count,2)
    infra_states=['Assign','CLKGLUE','DOP','NONCLKGLUE','CPunit','Repeater']
    xinfra_states=['SMALL','DFX']

    log_f = "compare_gc-"+sgen+"-"+tgen+"-tol_"+str(tolerance)+"-scal_fact_"+str(sf)+"-"+str(index)+".log"
    lf = open(log_dir+"/"+log_f,'w')
    print ('########### Units for which '+abs_path1+' and '+abs_path2+':gate counts differ by more than tolerance of '+str(tolerance)+'% ##########', file=lf)
    #print ('Unit,Cluster,GC:'+str(src_gen)+',GC:'+str(target_gen)+',Diff', file = lf)
    print (('Unit,\tCluster,\tGC:'+str(src_gen)+',\tGC:'+str(target_gen)+',\tDiff').expandtabs(usw), file = lf)
    
    for cluster in gc_dict1[sgen].keys():
        gc_src_sum = 0.0
        gc_tgt_sum = 0.0
        gc_xinfra_src_sum =0.0
        gc_xinfra_tgt_sum =0.0
        for units in gc_dict1[sgen][cluster].keys():
            if any(x in units for x in infra_states):
                continue
            src_gc = round(float(gc_dict1[sgen][cluster][units][0]),1)
            if units in gc_dict2[tgen][cluster].keys():
                tgt_gc = round(float(gc_dict2[tgen][cluster][units][0]),1)
                if (src_gc == 0.0 and tgt_gc == 0.0):
                    src_tar_gc_zero.append(units)
                if (src_gc == 0.0):
                    src_gc_zero.append(units)
                if (tgt_gc == 0.0):
                    tar_gc_zero.append(units)
                if src_gc != 0.0 and tgt_gc != 0.0:
                    pstate_gc_diff = round((((sf*tgt_gc)/src_gc)-1)*100,1)
                    gc_src_sum = round(gc_src_sum+src_gc,1)
                    gc_tgt_sum = round(gc_tgt_sum+tgt_gc,1)
                    if units in xinfra_states:
                        gc_xinfra_src_sum=gc_xinfra_src_sum+src_gc
                        gc_xinfra_tgt_sum=gc_xinfra_tgt_sum+src_gc
                    src_ratio = round(gc_xinfra_src_sum/gc_src_sum,5)
                    tgt_ratio = round(gc_xinfra_tgt_sum/gc_tgt_sum,5)
                    ratio_diff_bin[cluster] = [src_ratio,tgt_ratio] 
                    
                    cluster_gc_diff = round((((sf*gc_tgt_sum)/gc_src_sum)-1)*100,1)

                    if tolerance < 0.0:
                        if cluster_gc_diff < tolerance:
                            cluster_gc_diff_bin[cluster]=[gc_src_sum,gc_tgt_sum,cluster_gc_diff]

                        # Check if the difference in GC is more than tolerance.
                        if pstate_gc_diff < tolerance:
                            if tolerance >= pstate_gc_diff >= (tolerance+(bin_range*1.0)):
                                bin_one[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*1.0)) >= pstate_gc_diff >= (tolerance+(bin_range*2.0)):
                                bin_two[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*2.0)) >= pstate_gc_diff >= (tolerance+(bin_range*3.0)):
                                bin_three[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*3.0)) >= pstate_gc_diff >= (tolerance+(bin_range*4.0)):
                                bin_four[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*4.0)) >= pstate_gc_diff >= (tolerance+(bin_range*5.0)):
                                if any(x in units for x in xinfra_states):
                                    continue
                                bin_five[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            else:
                                if pstate_gc_diff < -100.0:
                                    bin_six[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                    else:
                        if cluster_gc_diff > tolerance:
                            cluster_gc_diff_bin[cluster]=[gc_src_sum,gc_tgt_sum,cluster_gc_diff]

                        if pstate_gc_diff > tolerance:
                            if tolerance <= pstate_gc_diff <= (tolerance+(bin_range*1.0)):
                                bin_one[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*1.0)) <= pstate_gc_diff <= (tolerance+(bin_range*2.0)):
                                bin_two[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*2.0)) <= pstate_gc_diff <= (tolerance+(bin_range*3.0)):
                                bin_three[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*3.0)) <= pstate_gc_diff <= (tolerance+(bin_range*4.0)):
                                bin_four[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            elif (tolerance+(bin_range*4.0)) <= pstate_gc_diff <= (tolerance+(bin_range*5.0)):
                                if any(x in units for x in xinfra_states):
                                    continue
                                bin_five[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

                            else:
                                if pstate_gc_diff > 100.0:
                                    bin_six[units]=[cluster, src_gc,tgt_gc,pstate_gc_diff]

    list_dict=[bin_one,bin_two,bin_three,bin_four,bin_five]
    index = 1
    for value in list_dict:
        temp = round(tolerance,2)
        temp2=round(temp+bin_range,2)
        print ("",file=lf)
        print ("########## Bin:"+str(index)+" Difference range: "+str(temp)+"% - "+str(temp2)+"% ##########",file=lf)
        for key, value in value.items():
            print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+",\t"+str(value[3])+"%").expandtabs(usw),file=lf)
        tolerance=round(tolerance+bin_range,2)
        index=index+1

    print ("",file=lf)
    print ("########## Difference more than "+str(tol+(bin_range*5.0))+"% ##########",file=lf)
    for key, value in bin_six.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+",\t"+str(value[3])+"%").expandtabs(usw),file=lf) 

    print ("",file=lf)
    print ('########### Check2: Clusters for which '+abs_path1+' and '+abs_path2+':gate counts differ by more than tolerance of '+str(tolerance)+'% ##########', file=lf)
    print ("",file=lf)
    print (('Cluster,\tCluster GC:'+str(src_gen)+',\tCluster GC:'+str(target_gen)+',\tDiff').expandtabs(usw), file = lf)
    for key, value in cluster_gc_diff_bin.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(usw),file=lf)

    print ("",file=lf)
    print ('########### Check3: Clusters for which '+abs_path+'and '+abs_path2+': ratio between non-infra units gate count to total cluster gate count ##########', file=lf)
    print ("",file=lf)
    print (('Cluster,\tSource_gen_ratio:'+str(sgen)+',\tTarget_gen_ratio:'+str(tgen)).expandtabs(usw), file = lf)
    for key, value in ratio_diff_bin.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])).expandtabs(usw),file=lf)
        
    print ("",file=lf)
    print ("########## "+abs_path1+":"+src_gen+" units with Design DB GC 0.0 ##########",file=lf)
    for states in src_gc_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+abs_path2+":"+target_gen+" units with Design DB GC 0.0 ##########",file=lf)
    for states in tar_gc_zero:
        print(states, file =lf)


## This function finds the difference in reference gate count among two given generation.
def compare_cdyn_Refgc(cdyn_dict, src_gen_step, target_gen_step, scaling_factor, tolerance, log_dir,index,abs_path):
    skey = re.split('_', src_gen_step)
    sgen = skey[0]
    sstep = skey[1]
    tkey = re.split('_', target_gen_step)
    tgen = tkey[0]
    tstep = tkey[1]
    list_of_xstates = []
    list_of_comm_states = []
    list_of_individual_tarstates = []
    src_tar_gc_zero=[]
    src_gc_zero=[]
    tar_gc_zero=[]
    new_tar_pstate=[]
    sf=scaling_factor
    bin_one={}
    bin_two={}
    bin_three={}
    bin_four={}
    bin_five={}
    bin_six={}
    tolerance=float(tolerance)
    bin_count=5.0
    tol=tolerance
    if tolerance > 0.0:
        bin_range=round((100.0-tolerance)/bin_count,2)
    else:
        bin_range=-round((100.0+tolerance)/bin_count,2)
    infra_states=['Assign','CLKGLUE','DOP','DFX','SMALL','NONCLKGLUE','CPunit','Repeater']

    log_f = "compare_cdyn_gc-"+sgen+"-"+tgen+"-tol_"+str(tolerance)+"-scal_fact_"+str(sf)+"-"+str(index)+".log"
    lf = open(log_dir+"/"+log_f,'w')
    print ('########### Units for which '+abs_path+':RefGC  differ by more than tolerance of '+str(tolerance)+'% ##########', file=lf)
    print (('Unit,\tRefGC: '+str(src_gen_step)+',\tRefGC: '+str(target_gen_step)+',\tDiff').expandtabs(usw), file = lf)

    for src_pstate in  cdyn_dict[sgen][sstep].keys():
        if any(x in src_pstate for x in infra_states):
            continue
        elif src_pstate.startswith('PS0') and cdyn_dict[sgen][sstep][src_pstate][1] == 'syn' :
            unit_name = re.split('PS0_', src_pstate)
            src_pstate_cdyn_gc = round(float(cdyn_dict[sgen][sstep][src_pstate][2]),1)
            if src_pstate in cdyn_dict[tgen][tstep].keys():
                list_of_comm_states.append(src_pstate)
                tgt_pstate_cdyn_gc = round(float(cdyn_dict[tgen][tstep][src_pstate][2]),1)
                if (src_pstate_cdyn_gc == 0.0 and tgt_pstate_cdyn_gc == 0.0):
                    src_tar_gc_zero.append(unit_name[1])
                if (src_pstate_cdyn_gc == 0.0):
                    src_gc_zero.append(unit_name[1])
                if (tgt_pstate_cdyn_gc == 0.0):
                    tar_gc_zero.append(unit_name[1])
                if src_pstate_cdyn_gc != 0.0 and tgt_pstate_cdyn_gc != 0.0:
                    pstate_cdyn_diff = round((((sf*tgt_pstate_cdyn_gc)/src_pstate_cdyn_gc)-1)*100,1)
                    if tolerance < 0.0:
                        # Check if the difference in RefGC is more than tolerance.
                        if pstate_cdyn_diff < tolerance:
                            if tolerance >= pstate_cdyn_diff >= (tolerance+(bin_range*1.0)):
                                bin_one[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            elif (tolerance+(bin_range*1.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*2.0)):
                                bin_two[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            elif (tolerance+(bin_range*2.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*3.0)):
                                bin_three[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            elif (tolerance+(bin_range*3.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*4.0)):
                                bin_four[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            elif (tolerance+(bin_range*4.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*5.0)):
                                bin_five[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            else:
                                if pstate_cdyn_diff < -100.0:
                                    bin_six[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                    else:
                        if pstate_cdyn_diff > tolerance:
                            if tolerance <= pstate_cdyn_diff <= (tolerance+(bin_range*1.0)):
                                bin_one[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            elif (tolerance+(bin_range*1.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*2.0)):
                                bin_two[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            elif (tolerance+(bin_range*2.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*3.0)):
                                bin_three[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            elif (tolerance+(bin_range*3.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*4.0)):
                                bin_four[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            elif (tolerance+(bin_range*4.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*5.0)):
                                bin_five[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                            else:
                                if pstate_cdyn_diff > 100.0:
                                    bin_six[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]
            else:
                list_of_xstates.append(unit_name[1])

    for tar_pstate in cdyn_dict[tgen][tstep].keys():
        if any(x in tar_pstate for x in infra_states):
            continue
        elif tar_pstate.startswith('PS0') and cdyn_dict[tgen][tstep][tar_pstate][1] == 'syn' :
            unit_name = re.split('PS0_', tar_pstate)
            if tar_pstate not in cdyn_dict[sgen][sstep].keys():
                new_tar_pstate.append(unit_name[1])
                    
    list_dict=[bin_one,bin_two,bin_three,bin_four,bin_five]
    index = 1
    for value in list_dict:
        temp = round(tolerance,2)
        temp2= round(temp+bin_range,2)
        print ("",file=lf)
        print ("########## Bin:"+str(index)+" Difference range: "+str(temp)+"% - "+str(temp2)+"% ##########",file=lf)
        for key, value in value.items():
            new_key = re.split('PS0_', key)
            print ((new_key[1]+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(usw),file=lf)
        tolerance=tolerance+bin_range
        index=index+1

    print ("",file=lf)
    print ("########## Difference more than "+str(tol+(bin_range*5.0))+"% ##########",file=lf)
    for key, value in bin_six.items():
        new_key = re.split('PS0_', key)
        print ((new_key[1]+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(usw),file=lf)                    
        
    print ("",file=lf)
    print ("########## "+src_gen_step+" units with RefGC 0.0 ##########",file=lf)
    for states in src_gc_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+target_gen_step+" units with RefGC 0.0 ##########",file=lf)
    for states in tar_gc_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+target_gen_step+" units not in "+src_gen_step+" ##########", file=lf)
    print ("",file=lf)
    for states in new_tar_pstate :
        print (states, file =lf)
    print ("",file=lf)
    print ("########## "+src_gen_step+" units not in "+target_gen_step+" ##########", file=lf)
    print ("",file=lf)
    for states in list_of_xstates :
        print (states, file =lf)

## This function finds the difference in reference gate count among two given generation of two different cdyn files.
def compare_cdyn_Refgc_files(cdyn_dict1,cdyn_dict2,src_gen_step, target_gen_step, scaling_factor, tolerance, log_dir,index,abs_path1,abs_path2):
    skey = re.split('_', src_gen_step)
    sgen = skey[0]
    sstep = skey[1]
    tkey = re.split('_', target_gen_step)
    tgen = tkey[0]
    tstep = tkey[1]
    list_of_xstates = []
    list_of_comm_states = []
    list_of_individual_tarstates = []
    src_tar_gc_zero=[]
    src_gc_zero=[]
    tar_gc_zero=[]
    new_tar_pstate=[]
    sf=scaling_factor
    bin_one={}
    bin_two={}
    bin_three={}
    bin_four={}
    bin_five={}
    bin_six={}
    tolerance=float(tolerance)
    bin_count=5.0
    tol=tolerance
    if tolerance > 0.0:
        bin_range=round((100.0-tolerance)/bin_count,2)
    else:
        bin_range=-round((100.0+tolerance)/bin_count,2)
    infra_states=['Assign','CLKGLUE','DOP','DFX','SMALL','NONCLKGLUE']

    log_f = "compare_cdyn_Refgc_diff_rel-"+sgen+"-"+tgen+"-tol_"+str(tolerance)+"-scal_fact_"+str(sf)+"-"+str(index)+".log"
    lf = open(log_dir+"/"+log_f,'w')

    print ('########### Units for which '+abs_path1+':RefGC and '+abs_path2+':RefGC differ by more than tolerance of '+str(tolerance)+'% ##########', file=lf)
    print (('Unit,\tRefGC: '+str(src_gen_step)+',\tRefGC: '+str(target_gen_step)+',\tDiff').expandtabs(usw), file = lf)

    for src_pstate in  cdyn_dict1[sgen][sstep].keys():
        if any(x in src_pstate for x in infra_states):
            continue
        elif src_pstate.startswith('PS0') and cdyn_dict1[sgen][sstep][src_pstate][1] == 'syn' :
            if src_pstate.count('_')==1:
                unit_name = re.split('_', src_pstate)
                src_pstate_cdyn_gc = round(float(cdyn_dict1[sgen][sstep][src_pstate][2]),1)
                if src_pstate in cdyn_dict2[tgen][tstep].keys():
                    list_of_comm_states.append(src_pstate)
                    tgt_pstate_cdyn_gc = round(float(cdyn_dict2[tgen][tstep][src_pstate][2]),1)
                    if (src_pstate_cdyn_gc == 0.0 and tgt_pstate_cdyn_gc == 0.0):
                        src_tar_gc_zero.append(unit_name[1])
                    if (src_pstate_cdyn_gc == 0.0):
                        src_gc_zero.append(unit_name[1])
                    if (tgt_pstate_cdyn_gc == 0.0):
                        tar_gc_zero.append(unit_name[1])
                    if src_pstate_cdyn_gc != 0.0 and tgt_pstate_cdyn_gc != 0.0:
                        pstate_cdyn_diff = round((((sf*tgt_pstate_cdyn_gc)/src_pstate_cdyn_gc)-1)*100,1)
                        if tolerance < 0.0:
                            if pstate_cdyn_diff < tolerance:
                                if tolerance >= pstate_cdyn_diff >= (tolerance+(bin_range*1.0)):
                                    bin_one[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                elif (tolerance+(bin_range*1.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*2.0)):
                                    bin_two[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                elif (tolerance+(bin_range*2.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*3.0)):
                                    bin_three[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                elif (tolerance+(bin_range*3.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*4.0)):
                                    bin_four[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                elif (tolerance+(bin_range*4.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*5.0)):
                                    bin_five[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                else:
                                    if pstate_cdyn_diff < -100.0:
                                        bin_six[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                        else:
                            if pstate_cdyn_diff > tolerance:
                                if tolerance <= pstate_cdyn_diff <= (tolerance+(bin_range*1.0)):
                                    bin_one[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                elif (tolerance+(bin_range*1.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*2.0)):
                                    bin_two[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                elif (tolerance+(bin_range*2.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*3.0)):
                                    bin_three[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                elif (tolerance+(bin_range*3.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*4.0)):
                                    bin_four[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                elif (tolerance+(bin_range*4.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*5.0)):
                                    bin_five[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]

                                else:
                                    if pstate_cdyn_diff > 100.0:
                                        bin_six[src_pstate]=[src_pstate_cdyn_gc,tgt_pstate_cdyn_gc,pstate_cdyn_diff]
                else:
                    list_of_xstates.append(unit_name[1])

    for tar_pstate in cdyn_dict2[tgen][tstep].keys():
        if any(x in tar_pstate for x in infra_states):
            continue
        elif tar_pstate.startswith('PS0') and cdyn_dict2[tgen][tstep][tar_pstate][1] == 'syn' :
            unit_name = re.split('PS0_', tar_pstate)
            if tar_pstate not in cdyn_dict1[sgen][sstep].keys():
                new_tar_pstate.append(unit_name[1])

    list_dict=[bin_one,bin_two,bin_three,bin_four,bin_five]
    index = 1
    for value in list_dict:
        temp = round(tolerance,2)
        temp2= round(temp+bin_range,2)
        print ("",file=lf)
        print ("########## Bin:"+str(index)+" Difference range: "+str(temp)+"% - "+str(temp2)+"% ##########",file=lf)
        for key, value in value.items():
            new_key = re.split('PS0_',key)
            print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(usw),file=lf)
        tolerance=tolerance+bin_range
        index=index+1

    print ("",file=lf)
    print ("########## Difference more than "+str(tol+(bin_range*5.0))+"% ##########",file=lf)
    for key, value in bin_six.items():
        new_key = re.split('PS0_',key)
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(usw),file=lf)
    
    print ("",file=lf)
    print ("########## "+abs_path1+":"+src_gen_step+" units with RefGC 0.0 ##########",file=lf)
    for states in src_gc_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+abs_path2+":"+target_gen_step+" units with RefGC 0.0 ##########",file=lf)
    for states in tar_gc_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+abs_path2+":"+target_gen_step+" units not in "+abs_path1+":"+src_gen_step+" ##########", file=lf)
    print ("",file=lf)
    for states in new_tar_pstate :
        print (states, file =lf)
    print ("",file=lf)
    print ("########## "+abs_path1+":"+src_gen_step+" units not in "+abs_path2+":"+target_gen_step+" ##########", file=lf)
    print ("",file=lf)
    for states in list_of_xstates :
        print (states, file =lf)

def compare_cdyn_wt(cdyn_dict, src_gen_step, target_gen_step, scaling_factor, tolerance, log_dir,index,abs_path):
    
    skey = re.split('_', src_gen_step)
    sgen = skey[0]
    sstep = skey[1]
    tkey = re.split('_', target_gen_step)
    tgen = tkey[0]
    tstep = tkey[1]
    list_of_xstates = []
    list_of_comm_states = []
    list_of_individual_tarstates = []
    src_tar_wt_zero=[]
    src_wt_zero=[]
    tar_wt_zero=[]
    sf=scaling_factor
    bin_one={}
    bin_two={}
    bin_three={}
    bin_four={}
    bin_five={}
    bin_six={}
    tolerance=float(tolerance)
    bin_count=5.0
    tol=tolerance
    if tolerance > 0.0:
        bin_range=round((100.0-tolerance)/bin_count,2)
    else:
        bin_range=-round((100.0+tolerance)/bin_count,2)
    log_f = "compare_cdyn_wt-"+sgen+"-"+tgen+"-tol_"+str(tolerance)+"-scal_fact_"+str(sf)+"-"+str(index)+".log"
    lf = open(log_dir+"/"+log_f,'w')
    print ('########### Power states for which '+abs_path+':Cdyn weights differ by more than tolerance of '+str(tolerance)+'% ##########', file=lf)
    print (('Power State,\tCdyn Weight: '+str(src_gen_step)+',\tCdyn Weight: '+str(target_gen_step)+',\tDiff').expandtabs(sw), file = lf)

    for src_pstate in  cdyn_dict[sgen][sstep].keys():
        src_pstate_cdyn_wt = round(float(cdyn_dict[sgen][sstep][src_pstate][0]),2) # Replaced 'Weight by 0
        if src_pstate in cdyn_dict[tgen][tstep].keys():
            src_pstate_new=re.split('_(\d+)%',src_pstate)
            list_of_comm_states.append(src_pstate_new[0])
            tgt_pstate_cdyn_wt = round(float(cdyn_dict[tgen][tstep][src_pstate][0]),2) # Replaced 'Weight by 0
            if (src_pstate_cdyn_wt == 0.0 and tgt_pstate_cdyn_wt == 0.0):
                src_tar_wt_zero.append(src_pstate)
            if (src_pstate_cdyn_wt == 0.0):
                src_wt_zero.append(src_pstate)
            if (tgt_pstate_cdyn_wt == 0.0):
                tar_wt_zero.append(src_pstate)
            if src_pstate_cdyn_wt != 0.0 and tgt_pstate_cdyn_wt != 0.0:
                pstate_cdyn_diff = round((((sf*tgt_pstate_cdyn_wt)/src_pstate_cdyn_wt)-1)*100,1)
                if tolerance < 0.0:
                    if pstate_cdyn_diff < tolerance:
                        if tolerance >= pstate_cdyn_diff >= (tolerance+(bin_range*1.0)):
                            bin_one[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*1.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*2.0)):
                            bin_two[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*2.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*3.0)):
                            bin_three[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*3.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*4.0)):
                            bin_four[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*4.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*5.0)):
                            bin_five[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        else:
                            if pstate_cdyn_diff < -100.0:
                                bin_six[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                else:
                    if pstate_cdyn_diff > tolerance:
                        if tolerance <= pstate_cdyn_diff <= (tolerance+(bin_range*1.0)):
                            bin_one[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*1.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*2.0)):
                            bin_two[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*2.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*3.0)):
                            bin_three[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*3.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*4.0)):
                            bin_four[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*4.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*5.0)):
                            bin_five[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        else:
                            if pstate_cdyn_diff > 100.0:
                                bin_six[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]
        else:
            continue

    src_plot_x=[]
    temp_src_pstate=[]
    temp_tar_pstate=[]
    new_tar_pstate=[]
    intcep_neg_pstate=[]
    new_tar_state=[]
    dup_tar_pstate=[]
    slope_intercep_zero=[]
    for tar_pstate in cdyn_dict[tgen][tstep].keys():
        if tar_pstate in list_of_comm_states:
            continue
        if tar_pstate.endswith('%'):
            if (round(float(cdyn_dict[tgen][tstep][tar_pstate][0]),2) == 0.0):
                if tar_pstate not in tar_wt_zero:
                    tar_wt_zero.append(tar_pstate)
            elif tar_pstate in cdyn_dict[sgen][sstep].keys():
                if (round(float(cdyn_dict[sgen][sstep][tar_pstate][0]),2) == 0.0):
                    if tar_pstate not in src_wt_zero:
                        src_wt_zero.append(tar_pstate) 
            else:
                for src_pstate in cdyn_dict[sgen][sstep].keys():
                    if src_pstate.endswith('%'):
                        src_pstate1=re.split('_(\d+)%',src_pstate)
                        tar_pstate1=re.split('_(\d+)%',tar_pstate)
                        if src_pstate1[0] == tar_pstate1[0]:
                            list_of_comm_states.append(tar_pstate1[0])
                            src_matchObj = re.search('_(\d+)%', src_pstate)
                            tar_matchObj = re.search('_(\d+)%', tar_pstate)
                            src_x_val = float(src_matchObj.group(1))/100
                            src_y_val = round(float(cdyn_dict[sgen][sstep][src_pstate][0]),2)
                            tar_x_val = float(tar_matchObj.group(1))/100
                            data_points.append([src_x_val, src_y_val])
                            temp_src_pstate.append(src_pstate)
                            temp_tar_pstate = tar_pstate
                            i=0

            if (len(data_points) == 0):
                continue
            if (len(data_points) == 1):
                data_points.clear()
                continue
            slope, intercept = get_linest_coeff(data_points)
            if intercept<0:
                intcep_neg_pstate.append(tar_pstate)
                data_points.clear()
                continue
            if slope == 0 and intercept == 0:
                slope_intercep_val = re.split('_(\d+)%', temp_tar_pstate)
                if slope_intercep_val[0] not in slope_intercep_zero:
                    slope_intercep_zero.append(slope_intercep_val[0])
                data_points.clear()
                continue

            tar_matchObj = re.search('_(\d+)%', temp_tar_pstate)
            tar_x_val = float(tar_matchObj.group(1))/100
            tar_new_weight = round(float((slope*tar_x_val+intercept)),5)
            tar_old_weight = round(float(cdyn_dict[tgen][tstep][temp_tar_pstate][0]),5)
            pstate_cdyn_diff = round((((sf*tar_old_weight)/tar_new_weight)-1)*100,2)
            if tolerance < 0.0:
                if pstate_cdyn_diff < tolerance:
                    if tolerance >= pstate_cdyn_diff >= (tolerance+(bin_range*1.0)):
                        bin_one[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*1.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*2.0)):
                        bin_two[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*2.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*3.0)):
                        bin_three[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*3.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*4.0)):
                        bin_four[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*4.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*5.0)):
                        bin_five[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    else:
                        if pstate_cdyn_diff < -100.0:
                            bin_six[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

            else:
                if pstate_cdyn_diff > tolerance:
                    if tolerance <= pstate_cdyn_diff <= (tolerance+(bin_range*1.0)):
                        bin_one[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*1.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*2.0)):
                        bin_two[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*2.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*3.0)):
                        bin_three[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*3.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*4.0)):
                        bin_four[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*4.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*5.0)):
                        bin_five[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    else:
                        if pstate_cdyn_diff > 100.0:
                            bin_six[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]     

            temp_src_pstate.clear()
            data_points.clear()

        elif (round(float(cdyn_dict[tgen][tstep][tar_pstate][0]),2) == 0.0):
            if tar_pstate not in tar_wt_zero:
                tar_wt_zero.append(tar_pstate)
        elif tar_pstate in cdyn_dict[sgen][sstep].keys():
            if (round(float(cdyn_dict[sgen][sstep][tar_pstate][0]),2) == 0.0):
                if tar_pstate not in src_wt_zero:
                    src_wt_zero.append(tar_pstate)

        else: 
            if tar_pstate not in cdyn_dict[sgen][sstep].keys():
                new_tar_pstate.append(tar_pstate)
    for src_pstate in cdyn_dict[sgen][sstep].keys():
        if src_pstate not in cdyn_dict[tgen][tstep].keys():
            src_pstate_new= re.split('_(\d+)%', src_pstate)
            if src_pstate_new[0] not in list_of_comm_states:
                list_of_xstates.append(src_pstate)
        
    
    list_dict=[bin_one,bin_two,bin_three,bin_four,bin_five]
    index = 1
    for value in list_dict:
        temp = round(tolerance,2)
        temp2= round(temp+bin_range),2
        print ("",file=lf)
        print ("########## Bin:"+str(index)+" Difference range: "+str(temp)+"% - "+str(temp2)+"% ##########",file=lf)
        for key, value in value.items():
            print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(sw),file=lf)
        tolerance=tolerance+bin_range
        index=index+1

    print ("",file=lf)
    print ("########## Difference more than "+str(tol+(bin_range*5.0))+"% ##########",file=lf)
    for key, value in bin_six.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(sw),file=lf)
    
    print ("",file=lf)
    print ("########## "+src_gen_step+" states with weights 0.0 ##########",file=lf)
    for states in src_wt_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+target_gen_step+" states with weights 0.0 ##########",file=lf)
    for states in tar_wt_zero:
        print(states, file =lf)

    '''print("",file=lf)
    print("#####Common states#####", file=lf)
    for states in list_of_comm_states:
        print(states,file=lf)'''

    print ("",file=lf)
    print ("########## "+target_gen_step+" states not in "+src_gen_step+" ##########", file=lf)
    print ("",file=lf)
    for states in new_tar_pstate :
        print (states, file =lf)
    print ("",file=lf)
    print ("########## "+src_gen_step+" states not in "+target_gen_step+" ##########", file=lf)
    print ("",file=lf)
    for states in list_of_xstates :
        print (states, file =lf)
    print ("",file=lf)
    print ("########## States with negative intercept ##########",file=lf)
    print ("",file=lf)
    for states in intcep_neg_pstate:
        new_state=re.split('_\d+%',states)
        print (new_state[0],file=lf)
    print ("",file=lf)
    print ("########## States with slope and intercept 0.0 ##########",file=lf)
    print ("",file=lf)
    for states in slope_intercep_zero:
        print (states,file=lf)

    #Closing the log files at the complete end
    lf.close()

def compare_cdyn_csv(cdyn_dict1, cdyn_dict2, src_gen_step, target_gen_step,scaling_factor, tolerance, log_dir,index,abs_path1,abs_path2):

    skey = re.split('_', src_gen_step)
    sgen = skey[0]
    sstep = skey[1]
    tkey = re.split('_', target_gen_step)
    tgen = tkey[0]
    tstep = tkey[1]
    list_of_xstates = []
    list_of_comm_states = []
    list_of_individual_tarstates = []
    src_tar_wt_zero=[]
    src_wt_zero=[]
    tar_wt_zero=[]
    tolerance=float(tolerance)
    sf=scaling_factor
    bin_one={}
    bin_two={}
    bin_three={}
    bin_four={}
    bin_five={}
    bin_six={}
    tolerance=float(tolerance)
    bin_count=5.0
    tol=tolerance
    if tolerance > 0.0:
        bin_range=round((100.0-tolerance)/bin_count,2)
    else:
        bin_range=-round((100.0+tolerance)/bin_count,2)
    log_f = "compare_cdyn_csv_diff_rel-"+sgen+"-"+tgen+"-tol_"+str(tolerance)+"-scal_fact_"+str(sf)+"-"+str(index)+".log"
    lf = open(log_dir+"/"+log_f,'w')

    print ('########### Power states for which '+abs_path1+':Cdyn weights and '+abs_path2+':Cdyn weights differ by more than tolerance of '+str(tolerance)+'% ##########', file=lf)
    print (('Power State,\tCdyn Weight: '+str(src_gen_step)+',\tCdyn Weight: '+str(target_gen_step)+',\tDiff').expandtabs(sw), file = lf)

    for src_pstate in  cdyn_dict1[sgen][sstep].keys():
        src_pstate_cdyn_wt = round(float(cdyn_dict1[sgen][sstep][src_pstate][0]),2) # Replaced 'Weight by 0
        if src_pstate in cdyn_dict2[tgen][tstep].keys():
            src_pstate_new=re.split('_\d+%',src_pstate)
            list_of_comm_states.append(src_pstate_new[0])
            tgt_pstate_cdyn_wt = round(float(cdyn_dict2[tgen][tstep][src_pstate][0]),2) # Replaced 'Weight by 0
            if (src_pstate_cdyn_wt == 0.0 and tgt_pstate_cdyn_wt == 0.0):
                src_tar_wt_zero.append(src_pstate)
            if (src_pstate_cdyn_wt == 0.0):
                src_wt_zero.append(src_pstate)
            if (tgt_pstate_cdyn_wt == 0.0):
                tar_wt_zero.append(src_pstate)
            if src_pstate_cdyn_wt != 0.0 and tgt_pstate_cdyn_wt != 0.0:
                pstate_cdyn_diff = round((((sf*tgt_pstate_cdyn_wt)/src_pstate_cdyn_wt)-1)*100,1)
                if tolerance < 0.0:
                    if pstate_cdyn_diff < tolerance:
                        if tolerance >= pstate_cdyn_diff >= (tolerance+(bin_range*1.0)):
                            bin_one[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*1.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*2.0)):
                            bin_two[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*2.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*3.0)):
                            bin_three[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*3.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*4.0)):
                            bin_four[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*4.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*5.0)):
                            bin_five[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        else:
                            if pstate_cdyn_diff < -100.0:
                                bin_six[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                else:
                    if pstate_cdyn_diff > tolerance:
                        if tolerance <= pstate_cdyn_diff <= (tolerance+(bin_range*1.0)):
                            bin_one[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*1.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*2.0)):
                            bin_two[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*2.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*3.0)):
                            bin_three[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*3.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*4.0)):
                            bin_four[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        elif (tolerance+(bin_range*4.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*5.0)):
                            bin_five[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                        else:
                            if pstate_cdyn_diff > 100.0:
                                bin_six[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]
        else:
            continue

    src_plot_x=[]
    temp_src_pstate=[]
    temp_tar_pstate=[]
    new_tar_pstate=[]
    intcep_neg_pstate=[]
    new_tar_state=[]
    dup_tar_pstate=[]
    slope_intercep_zero=[]
    for tar_pstate in cdyn_dict2[tgen][tstep].keys():
        if tar_pstate in list_of_comm_states:
            continue
        if tar_pstate.endswith('%'):
            if (round(float(cdyn_dict2[tgen][tstep][tar_pstate][0]),2) == 0.0):
                if tar_pstate not in tar_wt_zero:
                    tar_wt_zero.append(tar_pstate)
            elif tar_pstate in cdyn_dict1[sgen][sstep].keys():
                if (round(float(cdyn_dict1[sgen][sstep][tar_pstate][0]),2) == 0.0):
                    if tar_pstate not in src_wt_zero:
                        src_wt_zero.append(tar_pstate)
            else:
                for src_pstate in cdyn_dict1[sgen][sstep].keys():
                    if src_pstate.endswith('%'):
                        src_pstate1=re.split('_\d+%',src_pstate)
                        tar_pstate1=re.split('_\d+%',tar_pstate)
                        if src_pstate1[0] == tar_pstate1[0]:
                            list_of_comm_states.append(tar_pstate1[0])
                            src_matchObj = re.search('_(\d+)%', src_pstate)
                            tar_matchObj = re.search('_(\d+)%', tar_pstate)
                            src_x_val = float(src_matchObj.group(1))/100
                            src_y_val = round(float(cdyn_dict1[sgen][sstep][src_pstate][0]),2)
                            tar_x_val = float(tar_matchObj.group(1))/100
                            data_points.append([src_x_val, src_y_val])
                            temp_src_pstate.append(src_pstate)
                            temp_tar_pstate = tar_pstate

            if (len(data_points) == 0):
                continue
            if (len(data_points) == 1):
                data_points.clear()
                continue
            slope, intercept = get_linest_coeff(data_points)
            if intercept<0:
                intcep_neg_pstate.append(tar_pstate)
                data_points.clear()
                continue
            if slope == 0 and intercept == 0:
                slope_intercep_val = re.split('_(\d+)%', temp_tar_pstate)
                if slope_intercep_val[0] not in slope_intercep_zero:
                    slope_intercep_zero.append(temp_tar_pstate)
                data_points.clear()
                continue

            tar_matchObj = re.search('_(\d+)%', temp_tar_pstate)
            tar_x_val = float(tar_matchObj.group(1))/100
            tar_new_weight = round(float((slope*tar_x_val+intercept)),2)
            tar_old_weight = round(float(cdyn_dict2[tgen][tstep][temp_tar_pstate][0]),2)
            pstate_cdyn_diff = round((((sf*tar_old_weight)/tar_new_weight)-1)*100,1)
            if tolerance < 0.0:
                if pstate_cdyn_diff < tolerance:
                    if tolerance >= pstate_cdyn_diff >= (tolerance+(bin_range*1.0)):
                        bin_one[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*1.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*2.0)):
                        bin_two[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*2.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*3.0)):
                        bin_three[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*3.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*4.0)):
                        bin_four[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*4.0)) >= pstate_cdyn_diff >= (tolerance+(bin_range*5.0)):
                        bin_five[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    else:
                        if pstate_cdyn_diff < -100.0:
                            bin_six[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

            else:
                if pstate_cdyn_diff > tolerance:
                    if tolerance <= pstate_cdyn_diff <= (tolerance+(bin_range*1.0)):
                        bin_one[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*1.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*2.0)):
                        bin_two[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*2.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*3.0)):
                        bin_three[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*3.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*4.0)):
                        bin_four[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    elif (tolerance+(bin_range*4.0)) <= pstate_cdyn_diff <= (tolerance+(bin_range*5.0)):
                        bin_five[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

                    else:
                        if pstate_cdyn_diff > 100.0:
                            bin_six[src_pstate]=[src_pstate_cdyn_wt,tgt_pstate_cdyn_wt,pstate_cdyn_diff]

            temp_src_pstate.clear()
            data_points.clear()

        elif (round(float(cdyn_dict2[tgen][tstep][tar_pstate][0]),2) == 0.0):
            if tar_pstate not in tar_wt_zero:
                tar_wt_zero.append(tar_pstate)

        elif tar_pstate in cdyn_dict1[sgen][sstep].keys():
            if (round(float(cdyn_dict1[sgen][sstep][tar_pstate][0]),2) == 0.0):
                if tar_pstate not in src_wt_zero:
                    src_wt_zero.append(tar_pstate)                        
        
        else:
            if tar_pstate not in cdyn_dict1[sgen][sstep].keys():
                new_tar_pstate.append(tar_pstate)

    for src_pstate in cdyn_dict1[sgen][sstep].keys():
        if src_pstate not in cdyn_dict2[tgen][tstep].keys():
            src_pstate_new= re.split('_(\d+)%', src_pstate)
            if src_pstate_new[0] not in list_of_comm_states:
                list_of_xstates.append(src_pstate)

    list_dict=[bin_one,bin_two,bin_three,bin_four,bin_five]
    index = 1
    for value in list_dict:
        temp = round(tolerance,2)
        temp2= round(temp+bin_range,2)
        print ("",file=lf)
        print ("########## Bin:"+str(index)+" Difference range: "+str(temp)+"% - "+str(temp2)+"% ##########",file=lf)
        for key, value in value.items():
            print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(sw),file=lf)
        tolerance=tolerance+bin_range
        index=index+1

    print ("",file=lf)
    print ("########## Difference more than "+str(tol+(bin_range*5.0))+"% ##########",file=lf)
    for key, value in bin_six.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(sw),file=lf)

    print ("",file=lf)
    print ("########## "+abs_path1+":"+src_gen_step+" states with weights 0.0 ##########",file=lf)
    for states in src_wt_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+abs_path2+":"+target_gen_step+" states with weights 0.0 ##########",file=lf)
    for states in tar_wt_zero:
        print(states, file =lf)
    print ("",file=lf)
    print ("########## "+abs_path2+":"+target_gen_step+" states not in "+abs_path1+":"+src_gen_step+" ##########", file=lf)
    print ("",file=lf)
    for states in new_tar_pstate :
        print (states, file =lf)
    print ("",file=lf)
    print ("########## "+abs_path1+":"+src_gen_step+" states not in "+abs_path2+":"+target_gen_step+" ##########", file=lf)
    print ("",file=lf)
    for states in list_of_xstates :
        print (states, file =lf)
    print ("",file=lf)
    print ("########## States with negative intercept ##########",file=lf)
    print ("",file=lf)
    for states in intcep_neg_pstate:
        new_state=re.split('_\d+%',states)
        print (new_state[0],file=lf)
    print ("",file=lf)
    print ("########## States with slope and intercept 0.0 ##########",file=lf)
    print ("",file=lf)
    for states in slope_intercep_zero:
        print (states,file=lf)

    #Closing the log files at the complete end
    lf.close()

## This function finds the sum of the residencies 
def sum_of_residencies(res_dict, neg_res_states, undef_res):

    res1=0.0
    res2=0.0
    res3=0.0
    res_xstates={}
    res_lt_xstates={}
    temp=[]
    for states in res_dict.keys():
        if states not in neg_res_states:
            if states.startswith('PS0'):
                if res_dict[states][0] == 'n/a':
                    undef_res.append(states)
                    continue
                res1=float(res_dict[states][0])
                unit = re.split('PS0_',states)
                if 'PS1_'+unit[1] in res_dict.keys():
                    if res_dict['PS1_'+unit[1]][0] == 'n/a':
                        undef_res.append(states)
                        continue
                    res2 = float(res_dict['PS1_'+unit[1]][0])
                for ps2_states in res_dict.keys():
                    res3=0
                    if ps2_states.startswith('PS2'):
                        if ps2_states not in neg_res_states:
                            if '_'+unit[1]+'_' in ps2_states:
                                if res_dict[ps2_states][0] == 'n/a':
                                    undef_res.append(states)
                                    continue
                                res3=res3+float(res_dict[ps2_states][0])
                                temp.append(ps2_states)

                fin_res = round((res1+res2+res3),4)
                if fin_res > 1.0:
                    res_xstates[unit[1]]=fin_res
                if fin_res < 1.0:
                    res_lt_xstates[unit[1]]=fin_res
                temp.clear()
                res1=res2=res3=0
    return undef_res, res_xstates, res_lt_xstates

def residency_check(res_dict,lf):

    neg_res_states = []
    res_xstates = {}
    res_lt_xstates = {}
    res_state_values=[]
    neg_res_state={}
    undef_res=[]
    for states in res_dict.keys():
        if states.startswith('PS'):
            if res_dict[states][0] == 'n/a':
                undef_res.append(states)
                continue
            res_value = round(float(res_dict[states][0]),2)
            if res_value < 0.0:
                neg_res_states.append(states)
                neg_res_state[states]=res_value

    undef_res, res_xstates, res_lt_xstates = sum_of_residencies(res_dict,neg_res_states,undef_res)

    print ("######### Power states with negative residencies #########",file=lf)
    print("",file=lf)
    print (("States,\tValue").expandtabs(sw),file=lf)
    for key, value in neg_res_state.items():
        print((key+",\t"+str(value)).expandtabs(sw),file=lf)  

    print ("",file=lf)
    print ("########## Units for which sum of residencies more than 1.0 ##########",file=lf)
    print ("",file=lf)
    print (("Unit,\tValue").expandtabs(sw),file=lf)
    for key, value in res_xstates.items():
        print((key+",\t"+str(value)).expandtabs(sw),file=lf)
    print ("",file=lf)

    print ("########## Units for which sum of residencies less than 1.0 ##########",file=lf)
    print ("",file=lf)
    print (("Unit,\tValue").expandtabs(sw),file=lf)
    for key, value in res_lt_xstates.items():
        print((key+",\t"+str(value)).expandtabs(sw),file=lf)
    print ("",file=lf)

    print ("########## States with undefined residencies ##########",file=lf)
    for states in undef_res:
        print(states, file=lf)

def residency_compare(res_dict1, res_dict2, scal_fact, unit_list, lf):
    
    list_of_common_states=[]
    list_of_only_src_states=[]
    neg_res_state_src={}
    neg_res_state_tar={}
    neg_res_states_src=[]
    neg_res_states_tar=[]
    undef_res_src=[]
    undef_res_tar=[]
    check_one={}
    check_two={}
    given_units = re.split(',',unit_list)
    FPS_of_resdir1=res_dict1.get('FPS')
    FPS_of_resdir2=res_dict2.get('FPS')
    print (("State,\tSource_reidency,\tTarget_residency,\tRatio").expandtabs(sw),file=lf)
    print ("", file=lf)
    for state in res_dict1.keys():
        if state.startswith('PS0'):
            unit=re.split('PS0_', state)
            if unit[1] in given_units:
                for source_pstate in res_dict1.keys():
                    if ('_'+unit[1]+'_' in source_pstate and source_pstate.startswith('PS2')) or ('_'+unit[1] in source_pstate and source_pstate.startswith('PS0')) or ('_'+unit[1] in source_pstate and source_pstate.startswith('PS1')) :
                        if source_pstate in res_dict2.keys():
                            list_of_common_states.append(source_pstate)
                            if res_dict1[source_pstate][0] == 'n/a':
                                undef_res_src.append(source_pstate)
                                continue
                            if res_dict2[source_pstate][0] == 'n/a':
                                undef_res_tar.append(source_pstate)
                            res_value_src = round(float(res_dict1[source_pstate][0]),2)
                            res_value_tar = round(float(res_dict2[source_pstate][0]),2)
                            if res_value_src < 0.0:
                                neg_res_states_src.append(source_pstate)
                                neg_res_state_src[source_pstate]=res_value_src
                            if res_value_tar < 0.0:
                                neg_res_states_tar.append(source_pstate)
                                neg_res_state_tar[source_pstate]=res_value_tar
                            if res_value_src > 0.0 and res_value_tar> 0.0 and res_dict1[source_pstate][0] != 'n/a' and res_dict2[source_pstate][0] != 'n/a':
                                res_diff= round(scal_fact*(res_value_tar/res_value_src),2)
                                check_one[source_pstate]=[res_value_src,res_value_tar,res_diff]
                            if res_value_src > 0.0 and res_value_tar> 0.0 and res_dict1[source_pstate][0] != 'n/a' and res_dict2[source_pstate][0] != 'n/a':
                                res_diff= round(scal_fact*(res_value_tar/res_value_src)*(float(FPS_of_resdir2[0])/float(FPS_of_resdir1[0])),2)
                                check_two[source_pstate]=[res_value_src,res_value_tar,res_diff]
                                #print((source_pstate+",\t"+str(res_value_src)+",\t"+str(res_value_tar)+",\t"+str(res_diff)).expandtabs(sw),file=lf)
                        else:
                            if source_pstate not in list_of_only_src_states:
                                list_of_only_src_states.append(source_pstate)
            else:
                continue
        else:
            continue
    res1=0.0
    res2=0.0
    res3=0.0
    res_xstates_src={}
    res_lt_xstates_src={}
    res_xstates_tar={}
    res_lt_xstates_tar={}
    temp=[]
    for source_pstate in res_dict1.keys():
        if source_pstate.startswith('PS0'):
            if source_pstate not in neg_res_states_src:
                unit=re.split('PS0_', source_pstate)
                if unit[1] in given_units:
                    if res_dict1[source_pstate][0] == 'n/a':
                        continue
                    res1=float(res_dict1[source_pstate][0])
                    if 'PS1_'+unit[1] in res_dict1.keys():
                        if res_dict1['PS1_'+unit[1]][0] == 'n/a':
                            continue
                        res2 = float(res_dict1['PS1_'+unit[1]][0])
                    for ps2_states in res_dict1.keys():
                        res3=0
                        if ps2_states.startswith('PS2'):
                            if ps2_states not in neg_res_states_src:
                                if '_'+unit[1]+'_' in ps2_states:
                                    if res_dict1[ps2_states][0] == 'n/a':
                                        continue
                                    res3=res3+float(res_dict1[ps2_states][0])
                                    temp.append(ps2_states)

                    fin_res = round((res1+res2+res3),4)
                    if fin_res > 1.0:
                        res_xstates_src[unit[1]]=fin_res
                    if fin_res < 1.0:
                        res_lt_xstates_src[unit[1]]=fin_res
                    res1=res2=res3=0
                    temp.clear()

    for tar_pstate in res_dict2.keys():
        if tar_pstate.startswith('PS0'):
            if tar_pstate not in neg_res_states_tar:
                unit=re.split('PS0_', tar_pstate)
                if unit[1] in given_units:
                    if res_dict2[tar_pstate][0] == 'n/a':
                        continue
                    res1=float(res_dict2[tar_pstate][0])
                    if 'PS1_'+unit[1] in res_dict2.keys():
                        if res_dict2['PS1_'+unit[1]][0] == 'n/a':
                            continue
                        res2 = float(res_dict2['PS1_'+unit[1]][0])
                    for ps2_states in res_dict2.keys():
                        res3=0
                        if ps2_states.startswith('PS2'):
                            if ps2_states not in neg_res_states_tar:
                                if '_'+unit[1]+'_' in ps2_states:
                                    if res_dict2[ps2_states][0] == 'n/a':
                                        continue
                                    res3=res3+float(res_dict2[ps2_states][0])
                                    temp.append(ps2_states)

                    fin_res = round((res1+res2+res3),4)
                    if fin_res > 1.0:
                        res_xstates_tar[unit[1]]=fin_res
                    if fin_res < 1.0:
                        res_lt_xstates_tar[unit[1]]=fin_res
                    res1=res2=res3=0
                    temp.clear()
    print ("",file=lf)
    print ("######### Check 1: Ratio between target residncy and source residency #########",file=lf)
    print (("State,\tValue").expandtabs(sw),file=lf)
    for key, value in check_one.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(sw),file=lf)
    print ("",file=lf)

    print ("",file=lf)
    print ("######### Check 2: Ratio between target residncy and source residency when FPS is considered #########",file=lf)
    print (("State,\tValue").expandtabs(sw),file=lf)
    for key, value in check_two.items():
        print ((key+",\t"+str(value[0])+",\t"+str(value[1])+",\t"+str(value[2])+"%").expandtabs(sw),file=lf)
    print ("",file=lf) 
  
    print ("",file=lf)
    print ("######### Source power states with negative residencies #########",file=lf)
    print (("State,\tValue").expandtabs(sw),file=lf)
    for key, value in neg_res_state_src.items():
        print((key+",\t"+str(value)).expandtabs(sw),file=lf)
    print ("",file=lf)

    print ("######### Target power states with negative residencies #########",file=lf)
    for key, value in neg_res_state_tar.items():
        print(key+","+str(value),file=lf)
    print("",file=lf)


    print ("",file=lf)
    print ("########## Source Units for which sum of residencies more than 1.0 ##########",file=lf)
    print ("",file=lf)
    print (("Unit,\tValue").expandtabs(sw),file=lf)
    for key, value in res_xstates_src.items():
        print((key+",\t"+str(value)).expandtabs(sw),file=lf)
    print ("",file=lf)

    print ("########## Source Units for which sum of residencies less than 1.0 ##########",file=lf)
    print ("",file=lf)
    print (("Unit,\tValue").expandtabs(sw),file=lf)
    for key, value in res_lt_xstates_src.items():
        print((key+",\t"+str(value)).expandtabs(sw),file=lf)
    print ("",file=lf)

    print ("",file=lf)
    print ("########## Target Units for which sum of residencies more than 1.0 ##########",file=lf)
    print ("",file=lf)
    print (("Unit,\tValue").expandtabs(sw),file=lf)
    for key, value in res_xstates_tar.items():
        print((key+",\t"+str(value)).expandtabs(sw),file=lf)
    print ("",file=lf)

    print ("########## Target Units for which sum of residencies less than 1.0 ##########",file=lf)
    print ("",file=lf)
    print (("Unit,\tValue").expandtabs(sw),file=lf)
    for key, value in res_lt_xstates_tar.items():
        print((key+",\t"+str(value)).expandtabs(sw),file=lf)
    print ("",file=lf)

    print ("########## Source states with undefined residencies ##########",file=lf)
    for states in undef_res_src:
        print(states, file=lf)
    print ("",file=lf)

    print ("########## Target states with undefined residencies ##########",file=lf)
    for states in undef_res_tar:
        print(states, file=lf)
    print ("",file=lf)

    print ("########## Source states not in target states ##########",file=lf)
    for states in list_of_only_src_states:
        print (states, file=lf)
    print("",file=lf)


def residency_histogram(ps_list,res_dir,lf,abs_path):
    given_states = re.split(',',ps_list)
    for elements in given_states:
        print ("########## Input state name: "+elements+" ##########",file=lf)
        res_histo(elements, res_dir,lf,abs_path)

def res_histo(pstate, res_dir, lf,abs_path):
    res_negative = {}
    res_not_defined ={}
    bin_one={}
    bin_two={}
    bin_three={}
    bin_four={}
    bin_five={}
    bin_six={}
    for files in os.listdir(res_dir):
        if files.endswith(".csv"):
            wl = re.split('.res.csv', files)
            #print ("###### Workload: "+wl[0]+"######",file=lf)
            #print ("", file=lf)
            res_dict=read_residency_file(files,optional=abs_path)
            for states in res_dict.keys():
                if states == pstate:
                    residency_value = round(float(res_dict[states][0]),2)
                    wl_name = wl[0]
                    if residency_value < 0.0:
                        res_negative[wl_name] = [residency_value]
                        continue
                    elif residency_value == 'n/a':
                        res_not_defined[wl_name] = [residency_value]
                    elif residency_value >= 0.0 and residency_value != 'n/a' :
                        if 0.0 <= residency_value <= 0.2:
                            bin_one[wl_name] = [residency_value]
                        elif 0.2 <= residency_value <= 0.4:
                            bin_two[wl_name] = [residency_value]
                        elif 0.4 <= residency_value <= 0.6:
                            bin_three[wl_name] = [residency_value]
                        elif 0.6 <= residency_value <= 0.8:
                            bin_four[wl_name] = [residency_value]
                        elif 0.8 <= residency_value <= 1.0:
                            bin_five[wl_name] = [residency_value]
                        else:
                            bin_six[wl_name] = [residency_value]
                else:
                    continue

    list_dict=[bin_one,bin_two,bin_three,bin_four,bin_five]
    index = 1
    temp = 0.0
    for value in list_dict:
        temp2= round((temp+0.2),2)
        print ("",file=lf)
        print ("########## Bin:"+str(index)+" Residency range: "+str(temp)+" - "+str(temp2)+" ##########",file=lf)
        for key, value in value.items():
            print (key+","+str(value[0]),file=lf)
        temp=temp2
        index=index+1
    
    print ("",file=lf)
    print ("########## Bin:6 Residency more than 1.0 ##########",file=lf)
    for key, value in bin_six.items():
        print (key+","+str(value[0]),file=lf)
    
    print ("",file=lf)
    print ("########## Workload for which residency is negative ##########",file=lf)
    for key, values in res_negative.items():
        print (key+","+str(value[0]),file=lf)

    print ("",file=lf)
    print ("########## Workload for which residency is not defined ##########",file=lf)
    for key, values in res_not_defined.items():
        print (key+","+str(value[0]),file=lf)
    print ("",file=lf)
        
     
if __name__ == '__main__':

    parser = lib.argparse.ArgumentParser(description='This script will do the sanity check on the ALPS inputs')
    parser.add_argument("function",
                         nargs="?",
                         choices=['compare_cdyn_wt', 'compare_cdyn_csv'],
                         default='compare_cdyn_wt',
                         )
    parser.add_argument('-o','--log_file',dest="out_log",default=False, help="Output log directory")
    parser.add_argument('-f','--input_file',dest="input_text", help="Input text file")
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
    
    list_of_gens=['Gen9LPClient_A0','Gen10LP_A0','Gen11LP_A0','Gen12LP_A0','Gen11_A0']
    src_tar_same=[]
    data_points = []
    not_src_gen=[]
    not_tar_gen=[]
    sgen_notin_rev=[]
    tgen_notin_rev=[]
    improper_inputs=[]
    sw = 44
    usw = 20
    index=1
    ip_file = open(args.input_text,'r')
    i=1
    for lines in ip_file:
        cmd_args = lines.split()
        if "compare_cdyn_wt" in cmd_args:
            # Read command line inputs to variables
            tol_index=cmd_args.index("-tol")
            tolerance=cmd_args[tol_index+1]
            cdyn_wt_file_index=cmd_args.index("-i")
            cdyn_wt_file=cmd_args[cdyn_wt_file_index+1]
            abs_path=os.path.abspath(cdyn_wt_file)
            source_process_index=cmd_args.index("-s")
            source_process=cmd_args[source_process_index+1]
            target_process_index=cmd_args.index("-t")
            target_process=cmd_args[target_process_index+1]
            if source_process not in list_of_gens:
                not_src_gen.append(lines)
                continue
            if target_process not in list_of_gens:
                not_tar_gen.append(lines)
                continue
            if source_process == target_process:
                src_tar_same.append(lines)
                i=i+1
                continue
            cdyn_wt_dict = read_cdyn_file(cdyn_wt_file)
            if "-c" in cmd_args:
                scal_fact_index=cmd_args.index("-c")
                scal_fact=float(cmd_args[scal_fact_index+1])
                compare_cdyn_wt(cdyn_wt_dict, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path)
            else:
                scal_fact=1
                compare_cdyn_wt(cdyn_wt_dict, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path)

        elif "compare_cdyn_csv" in cmd_args:
            tol_index=cmd_args.index("-tol")
            tolerance=cmd_args[tol_index+1]
            cdyn_wt_file1_index=cmd_args.index("-f1")
            cdyn_wt_file1=cmd_args[cdyn_wt_file1_index+1]
            cdyn_wt_file2_index=cmd_args.index("-f2")
            cdyn_wt_file2=cmd_args[cdyn_wt_file2_index+1]
            abs_path1=os.path.abspath(cdyn_wt_file1)
            abs_path2=os.path.abspath(cdyn_wt_file2)
            source_process_index=cmd_args.index("-s")
            source_process=cmd_args[source_process_index+1]
            target_process_index=cmd_args.index("-t")
            target_process=cmd_args[target_process_index+1]
            if source_process not in list_of_gens:
                not_src_gen.append(lines)
                continue
            if target_process not in list_of_gens:
                not_tar_gen.append(lines)
                continue
            cdyn_wt_dict1 = read_cdyn_file(cdyn_wt_file1)
            cdyn_wt_dict2 = read_cdyn_file(cdyn_wt_file2)
            
            if "-c" in cmd_args:
                scal_fact_index=cmd_args.index("-c")
                scal_fact=float(cmd_args[scal_fact_index+1])
                compare_cdyn_csv(cdyn_wt_dict1, cdyn_wt_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path1,abs_path2)
            else:
                scal_fact=1
                compare_cdyn_csv(cdyn_wt_dict1, cdyn_wt_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path1,abs_path2)

        elif "compare_cdyn_csv_rev" in cmd_args:
            rev1_index=cmd_args.index("-r1")
            rev1=cmd_args[rev1_index+1]
            rev2_index=cmd_args.index("-r2")
            rev2=cmd_args[rev2_index+1]
            tol_index=cmd_args.index("-tol")
            tolerance=cmd_args[tol_index+1]
            source_process_index=cmd_args.index("-s")
            source_process=cmd_args[source_process_index+1]
            target_process_index=cmd_args.index("-t")
            target_process=cmd_args[target_process_index+1]
            path1= rev1+":Inputs/cdyn.csv"
            path2= rev2+":Inputs/cdyn.csv"
            os.system("git show "+path1+" > dummy_rev1.csv")
            os.system("git show "+path2+" > dummy_rev2.csv")
            if source_process not in list_of_gens:
                not_src_gen.append(lines)
                continue
            if target_process not in list_of_gens:
                not_tar_gen.append(lines)
                continue
            cdyn_wt_dict1 = read_cdyn_file('dummy_rev1.csv')
            cdyn_wt_dict2 = read_cdyn_file('dummy_rev2.csv')
            skey = re.split('_',source_process)
            sgen = skey[0]
            tkey = re.split('_',target_process)
            tgen = tkey[0]
            if sgen not in cdyn_wt_dict1.keys():
                sgen_notin_rev.append(lines)
                continue
            if tgen not in cdyn_wt_dict2.keys():
                tgen_not_rev.append(lines)
                continue

            if "-c" in cmd_args:
                scal_fact_index=cmd_args.index("-c")
                scal_fact=float(cmd_args[scal_fact_index+1])
                compare_cdyn_csv(cdyn_wt_dict1, cdyn_wt_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,path1,path2)
            else:
                scal_fact=1
                compare_cdyn_csv(cdyn_wt_dict1, cdyn_wt_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,path1,path2)

            os.remove('dummy_rev1.csv')
            os.remove('dummy_rev2.csv')

            

        elif "residency_check" in cmd_args:
            res_file_index=cmd_args.index("-f")
            res_file=cmd_args[res_file_index+1]
            abs_path=os.path.abspath(res_file)
            if os.path.isdir(res_file):
                log_f = "compare_res_"+str(index)+".log"
                lf = open(log_directory+"/"+log_f,'w')
                print ('########### Input residency file:'+abs_path+'##########',file=lf)
                for files in os.listdir(res_file):
                    if files.endswith(".csv"):
                        wl = re.split('.res.csv', files)
                        print ("###### Workload: "+wl[0]+"######",file=lf)
                        print ("", file=lf)
                        res_dict=read_residency_file(files,optional=abs_path)
                        residency_check(res_dict,lf)
                            
            elif os.path.isfile(res_file):
                log_f = "compare_res_"+str(index)+".log"
                lf = open(log_directory+"/"+log_f,'w')
                print ('########### Input residency file:'+abs_path+'##########',file=lf)
                res_dict=read_residency_file(res_file)
                residency_check(res_dict,lf)
            else:
                improper_inputs.append(lines)
                continue

        elif "residency_compare" in cmd_args:
            non_common_wl=[]
            res_file1_index=cmd_args.index("-f1")
            res_file2_index=cmd_args.index("-f2")
            res_file1=cmd_args[res_file1_index+1]
            res_file2=cmd_args[res_file2_index+1]
            abs_path1=os.path.abspath(res_file1)
            abs_path2=os.path.abspath(res_file2)
            unit_list_index=cmd_args.index("-l")
            unit_list=cmd_args[unit_list_index+1]
            if os.path.isdir(res_file1) and os.path.isdir(res_file2):
                log_f = "compare_res_"+str(index)+".log"
                lf = open(log_directory+"/"+log_f,'w')
                print ('########### Input residency file/directory:'+abs_path1+' and '+abs_path2+'##########',file=lf)
                for files in os.listdir(res_file1):
                    if files.endswith(".csv"):
                        for files2 in os.listdir(res_file2):
                            wl1 = re.split('.res.csv', files)
                            wl2 = re.split('.res.csv', files2)
                            if files == files2:
                                print ("###### Workload: "+wl1[0]+" ######",file=lf)
                                print ("", file=lf)
                                res_dict1=read_residency_file(files,optional=abs_path1)
                                res_dict2=read_residency_file(files2,optional=abs_path2)
                                if "-c" in cmd_args:
                                    scal_fact_index=cmd_args.index("-c")
                                    scal_fact=float(cmd_args[scal_fact_index+1]) 
                                    residency_compare(res_dict1,res_dict2,scal_fact,unit_list,lf)
                                else:
                                    scal_fact=1
                                    residency_compare(res_dict1,res_dict2,scal_fact,unit_list,lf)
                            else:
                                non_common_wl.append(wl1)
                                non_common_wl.append(wl2)
            elif os.path.isfile(res_file1) and os.path.isfile(res_file2): 
                res_file1_index=cmd_args.index("-f1")
                res_file2_index=cmd_args.index("-f2")
                res_file1=cmd_args[res_file1_index+1]
                res_file2=cmd_args[res_file2_index+1]
                abs_path1=os.path.abspath(res_file1)
                abs_path2=os.path.abspath(res_file2)
                res_dict1=read_residency_file(res_file1)
                res_dict2=read_residency_file(res_file2)
                log_f = "compare_res_"+str(index)+".log"
                lf = open(log_directory+"/"+log_f,'w')
                print ('########### Input residency file/directory:'+abs_path1+' and '+abs_path2+'##########',file=lf)
                if "-c" in cmd_args:
                    scal_fact_index=cmd_args.index("-c")
                    scal_fact=float(cmd_args[scal_fact_index+1]) 
                    residency_compare(res_dict1,res_dict2,scal_fact,unit_list,lf)
                else:
                    scal_fact=1
                    residency_compare(res_dict1,res_dict2,scal_fact,unit_list,lf)
            else:
                improper_inputs.append(lines)
                continue
                

        elif "compare_cdyn_Refgc" in cmd_args:
            tol_index=cmd_args.index("-tol")
            tolerance=cmd_args[tol_index+1]
            cdyn_gc_file_index=cmd_args.index("-i")
            cdyn_gc_file=cmd_args[cdyn_gc_file_index+1]
            abs_path=os.path.abspath(cdyn_gc_file)
            source_process_index=cmd_args.index("-s")
            source_process=cmd_args[source_process_index+1]
            target_process_index=cmd_args.index("-t")
            target_process=cmd_args[target_process_index+1]
            if source_process not in list_of_gens:
                not_src_gen.append(lines)
                continue
            if target_process not in list_of_gens:
                not_tar_gen.append(lines)
                continue
            if source_process == target_process:
                src_tar_same.append(lines)
                i=i+1
                continue
            cdyn_gc_dict = read_cdyn_file(cdyn_gc_file)
            if "-c" in cmd_args:
                scal_fact_index=cmd_args.index("-c")
                scal_fact=float(cmd_args[scal_fact_index+1])
                compare_cdyn_Refgc(cdyn_gc_dict, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path)
            else:
                scal_fact=1
                compare_cdyn_Refgc(cdyn_gc_dict, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path)

        elif "compare_cdyn_Refgc_files" in cmd_args:
            tol_index=cmd_args.index("-tol")
            tolerance=cmd_args[tol_index+1]
            cdyn_gc_file1_index=cmd_args.index("-f1")
            cdyn_gc_file1=cmd_args[cdyn_gc_file1_index+1]
            cdyn_gc_file2_index=cmd_args.index("-f2")
            cdyn_gc_file2=cmd_args[cdyn_gc_file2_index+1]
            abs_path1=os.path.abspath(cdyn_gc_file1)
            abs_path2=os.path.abspath(cdyn_gc_file2)
            source_process_index=cmd_args.index("-s")
            source_process=cmd_args[source_process_index+1]
            target_process_index=cmd_args.index("-t")
            target_process=cmd_args[target_process_index+1]
            if source_process not in list_of_gens:
                not_src_gen.append(lines)
                continue
            if target_process not in list_of_gens:
                not_tar_gen.append(lines)
                continue
            cdyn_gc_dict1 = read_cdyn_file(cdyn_gc_file1)
            cdyn_gc_dict2 = read_cdyn_file(cdyn_gc_file2)
            
            if "-c" in cmd_args:
                scal_fact_index=cmd_args.index("-c")
                scal_fact=float(cmd_args[scal_fact_index+1])
                compare_cdyn_Refgc_files(cdyn_gc_dict1, cdyn_gc_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path1,abs_path2)
            else:
                scal_fact=1
                compare_cdyn_Refgc_files(cdyn_gc_dict1, cdyn_gc_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path1,abs_path2)

        elif "compare_cdyn_Refgc_rev" in cmd_args:
            rev1_index=cmd_args.index("-r1")
            rev1=cmd_args[rev1_index+1]
            rev2_index=cmd_args.index("-r2")
            rev2=cmd_args[rev2_index+1]
            tol_index=cmd_args.index("-tol")
            tolerance=cmd_args[tol_index+1]
            source_process_index=cmd_args.index("-s")
            source_process=cmd_args[source_process_index+1]
            target_process_index=cmd_args.index("-t")
            target_process=cmd_args[target_process_index+1]
            path1= rev1+":Inputs/cdyn.csv"
            path2= rev2+":Inputs/cdyn.csv"
            os.system("git show "+path1+" > dummy_rev1.csv")
            os.system("git show "+path2+" > dummy_rev2.csv")
            if source_process not in list_of_gens:
                not_src_gen.append(lines)
                continue
            if target_process not in list_of_gens:
                not_tar_gen.append(lines)
                continue
            cdyn_gc_dict1 = read_cdyn_file('dummy_rev1.csv')
            cdyn_gc_dict2 = read_cdyn_file('dummy_rev2.csv')
            skey = re.split('_',source_process)
            sgen = skey[0]
            tkey = re.split('_',target_process)
            tgen = tkey[0]
            if sgen not in cdyn_wt_dict1.keys():
                sgen_notin_rev.append(lines)
                continue
            if tgen not in cdyn_wt_dict2.keys():
                tgen_not_rev.append(lines)
                continue

            if "-c" in cmd_args:
                scal_fact_index=cmd_args.index("-c")
                scal_fact=float(cmd_args[scal_fact_index+1])
                compare_cdyn_Refgc_files(cdyn_wt_dict1, cdyn_wt_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,path1,path2)
            else:
                scal_fact=1
                compare_cdyn_Refgc_files(cdyn_wt_dict1, cdyn_wt_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,path1,path2)

            os.remove('dummy_rev1.csv')
            os.remove('dummy_rev2.csv')

        elif "compare_gc" in cmd_args:
            tol_index=cmd_args.index("-tol")
            tolerance=cmd_args[tol_index+1]
            cdyn_gc_file_index=cmd_args.index("-i")
            cdyn_gc_file=cmd_args[cdyn_gc_file_index+1]
            abs_path=os.path.abspath(cdyn_gc_file)
            source_process_index=cmd_args.index("-s")
            source_process=cmd_args[source_process_index+1]
            target_process_index=cmd_args.index("-t")
            target_process=cmd_args[target_process_index+1]
            if source_process not in list_of_gens:
                not_src_gen.append(lines)
                continue
            if target_process not in list_of_gens:
                not_tar_gen.append(lines)
                continue
            if source_process == target_process:
                src_tar_same.append(lines)
                i=i+1
                continue
            gc_dict = read_gc_file(cdyn_gc_file)
            if "-c" in cmd_args:
                scal_fact_index=cmd_args.index("-c")
                scal_fact=float(cmd_args[scal_fact_index+1])
                compare_gc(gc_dict, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path)
            else:
                scal_fact=1
                compare_gc(gc_dict, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path)

        elif "compare_gc_files" in cmd_args:
            tol_index=cmd_args.index("-tol")
            tolerance=cmd_args[tol_index+1]
            cdyn_gc_file1_index=cmd_args.index("-f1")
            cdyn_gc_file1=cmd_args[cdyn_gc_file1_index+1]
            cdyn_gc_file2_index=cmd_args.index("-f2")
            cdyn_gc_file2=cmd_args[cdyn_gc_file2_index+1]
            abs_path1=os.path.abspath(cdyn_gc_file1)
            abs_path2=os.path.abspath(cdyn_gc_file2)
            source_process_index=cmd_args.index("-s")
            source_process=cmd_args[source_process_index+1]
            target_process_index=cmd_args.index("-t")
            target_process=cmd_args[target_process_index+1]
            if source_process not in list_of_gens:
                not_src_gen.append(lines)
                continue
            if target_process not in list_of_gens:
                not_tar_gen.append(lines)
                continue
            gc_dict1 = read_gc_file(cdyn_gc_file1)
            gc_dict2 = read_gc_file(cdyn_gc_file2)
            
            if "-c" in cmd_args:
                scal_fact_index=cmd_args.index("-c")
                scal_fact=float(cmd_args[scal_fact_index+1])
                compare_gc_files(gc_dict1, gc_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path1,abs_path2)
            else:
                scal_fact=1
                compare_gc_files(gc_dict1, gc_dict2, source_process, target_process, scal_fact, tolerance, log_directory,index,abs_path1,abs_path2)

        elif "residency_histogram" in cmd_args:
            ps_list_index = cmd_args.index("-l")
            ps_list = cmd_args[ps_list_index+1]
            res_dir_index=cmd_args.index("-d")
            res_dir=cmd_args[res_dir_index+1]
            abs_path=os.path.abspath(res_dir)
            if os.path.isdir(res_dir):
                log_f = "res_histogram_"+str(index)+".log"
                lf = open(log_directory+"/"+log_f,'w')
                print ("########### Input residency file/directory:"+abs_path+"##########",file=lf)
                residency_histogram(ps_list,res_dir,lf,abs_path)        
            
        else:
            sys.exit("You have given unsupported functionality in the Input file")
        index=index+1
        i=i+1

    log_f = "tests_not_run.log"
    lf = open(log_directory+"/"+log_f,'w')

    print("###### Tests with invalid source_gen name ######",file=lf)
    for lines in not_src_gen:
        print (lines,file=lf)
    print("",file=lf)

    print("###### Tests with invalid target_gen name ######",file=lf)
    for lines in not_tar_gen:
        print (lines,file=lf)
    print ("",file=lf)

    print("###### Tests with source_gen name not in the source revision ######",file=lf)
    for lines in sgen_notin_rev:
        print (lines,file=lf)
    print("",file=lf)

    print("###### Tests with target_gen name not in the target revision ######",file=lf)
    for lines in tgen_notin_rev:
        print (lines,file=lf)
    print ("",file=lf)

    print("###### Tests with same source_gen and  target_gen name ######",file=lf)
    for lines in src_tar_same:
        print(lines,file=lf)
    print ("",file=lf)

    print("###### Improper input file or directory ######",file=lf)
    for lines in improper_inputs:
        print(lines,file=lf)
    print ("",file=lf)
        

    
