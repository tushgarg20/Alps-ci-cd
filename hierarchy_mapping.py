import os
import sys
import re
import lib.yaml as yaml
import csv
import time
import lib.argparse
import copy
from collections import OrderedDict


#######################################################################
#######################################################################
###### Physical level parttiton to logical level Unit Mapping   #######
###### Usage: Python hierarchy_mapping.py -i <alps_output.yaml> #######
######    -m <hierarchy_definition_file.yaml> -o <output.yaml>  #######

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

def partition_to_unit_mapping(cdyn_dict,map_dict,out_file):
    
    misc_clusters = ['EU','ROSS','Sampler','SQIDI','DSSC','UNCORE','GTI','GAM','HDC','L3_Bank','L3Node','Fabric','COLOR','Z','ROSC','FF','rFF']
    infra_units = {}
    for ele in misc_clusters:
        if ele == 'rFF':
            infra_units['rFF'] = ['rOTHER_CLKGLUE','rOTHER_DFX','rOTHER_DOP','rOTHER_NONCLKGLUE']
        elif ele == 'FF':
            infra_units['FF'] = ['OTHER_Assign','OTHER_CLKGLUE','OTHER_CPunit','OTHER_DFX','OTHER_DOP','OTHER_NONCLKGLUE','OTHER_Repeater','OTHER_SMALL','TEGSSOL_Assign','TEGSSOL_CLKGLUE','TEGSSOL_CPunit','TEGSSOL_DFX','TEGSSOL_DOP','TEGSSOL_NONCLKGLUE','TEGSSOL_Repeater','TEGSSOL_SMALL']
        elif ele == 'Sampler':
            infra_units['Sampler'] = ['DFRSMP_Assign','DFRSMP_CLKGLUE','DFRSMP_CPunit','DFRSMP_DFX','DFRSMP_DOP','DFRSMP_NONCLKGLUE','DFRSMP_Repeater','DFRSMP_SMALL','MEDIASMP_Assign','MEDIASMP_CLKGLUE','MEDIASMP_CPunit','MEDIASMP_DFX','MEDIASMP_DOP','MEDIASMP_NONCLKGLUE','MEDIASMP_Repeater','MEDIASMP_SMALL']
        else:
            infra_units[ele] = ['Assign','CLKGLUE','CPunit','DFX','DOP','NONCLKGLUE','Repeater','SMALL']

    infra = {}
    total = {}
    for clusters in misc_clusters:
        infra_sum = 0.0
        non_infra_sum = 0.0
        for units in cdyn_dict['unit_cdyn_numbers(pF)'][clusters].keys():
            if units in infra_units[clusters]:
                infra_sum = infra_sum + cdyn_dict['unit_cdyn_numbers(pF)'][clusters][units]
            else:

                non_infra_sum = non_infra_sum + cdyn_dict['unit_cdyn_numbers(pF)'][clusters][units]
            
        infra[clusters] = round(infra_sum,2)
        unit_sum = non_infra_sum
        total[clusters] = round(unit_sum,2)

    map_copy = copy.deepcopy(map_dict)

    power_list = []
    new_power_list = []
    new_power_list2 =[]

    dfs(map_dict,new_power_list)

    map_out = {}

    for path in new_power_list:
        try:
            path[-1] = cdyn_dict['unit_cdyn_numbers(pF)'][path[-3]][path[-2]]
        except:
            path[-1] = 0

        d = map_out

        i = 0
        while(True):
            if('infra' not in d and i >= 0 and (i == len(path)-2) and path[i-1] in  misc_clusters ):
                d['infra'] = 0
                
            if(i >= 0 and (i == len(path)-2) and path[i-1] in  misc_clusters and path[i] not in infra_units[path[i-1]] ):
                d['infra'] += float(path[-1])
                d['infra'] = float('%.3lf'%float(d['infra']))
            if(i == len(path)-2):
                d[path[i]] = float('%.3f'%float(path[i+1]))
                break
            if(path[i] not in d):
                d[path[i]] = {}
            d = d[path[i]]

            i = i+1
        
    dfs(map_out,new_power_list2)
    map_out2 = {}

    for path in new_power_list2:
        #import pdb; pdb.set_trace()
        if path[-2] == 'infra':
            path[-1] = round((path[-1] / total[path[-3]]) * infra[path[-3]],2)

        d = map_out2

        i = 0
        while(True):
            if('total' not in d and i >= 0):
                d['total'] = 0
   
            if(i >= 0):
                d['total'] += float(path[-1])
                d['total'] = float('%.3f'%float(d['total']))

            if(i == len(path)-2):
                d[path[i]] = float('%.3f'%float(path[i+1]))
                break
            if(path[i] not in d):
                d[path[i]] = {}
            d = d[path[i]]

            i = i+1
    yaml.dump(map_out2,out_file,default_flow_style=False)                            
        

if __name__ == '__main__':

    parser = lib.argparse.ArgumentParser(description='This script does the partiton to unit mapping')
    parser.add_argument('-i','--input_yaml',dest="ip_yaml", help="ALPS cdyn file")
    parser.add_argument('-m','--map_file',dest="map_file", help="New mapping file")
    parser.add_argument('-o','--out_yaml',dest="out_yaml", help="Output yaml file with new mapping")
    args, sub_args = parser.parse_known_args()

    if args.out_yaml:
        out_file = open(args.out_yaml,'w')
    else:
        sys.exit("Please give the output file name!")
    
    cdyn_file = open(args.ip_yaml, "r")
    mapping_file = open(args.map_file,"r")
    cdyn_dict = yaml.load(cdyn_file)
    map_dict = yaml.load(mapping_file)
    
    partition_to_unit_mapping(cdyn_dict, map_dict,out_file)
