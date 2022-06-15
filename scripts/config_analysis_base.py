import lib.argparse
import string
import csv
import sys
from copy import deepcopy
from collections import OrderedDict
#############################
# Command Line Arguments
#############################
#### Gets options from command line
parser = lib.argparse.ArgumentParser(
        description='This tool is used to analyse the goodness of a config compared to a base config',
        epilog = "Config analysis made easy man")
parser.add_argument('-s','--study_settings_file',dest="settings_file",
           help="Input file providing details on configuration settings")
##parser.add_argument('-bc','--base_config',dest="base_config",
##           help="Baseline Config/architecture")
##parser.add_argument('-ec','--evaluated_config',dest="eval_config",
##           help="Config to be evaluated against baseline config")
##parser.add_argument('-b','--base_result_file',dest="base_file",
##           help="Input file containing results from baseline config")
##parser.add_argument('-e','--eval_result_file',dest="eval_file",
##           help="Input file containing results from evaluation config")
parser.add_argument('--debug',action="store_true",dest="run_debug",default=False,
           help="Run tool in debug mode [default: %sdefault]" % "%%")

options = parser.parse_args()

##Obtain details of the settings
settings_data={}
settings = csv.DictReader(open(options.settings_file))

for row in settings:
    key = row.pop('Detail')
    settings_data[key] = row
##print (settings_data)

print ("*******************************************************")
print ("******* Generating results for " + settings_data['arch']['base_config'].upper() + settings_data['sku']['base_config'].upper() + " vs " + settings_data['arch']['eval_config'].upper() + settings_data['sku']['eval_config'].upper() + " *******")
print ("*******************************************************")
print ("************* May the best config win!!! **************")
print ("*******************************************************")

#################################
# Global Variables
#################################

base_config_name = settings_data['arch']['base_config'].upper() + settings_data['sku']['base_config'].upper()
eval_config_name = settings_data['arch']['eval_config'].upper() + settings_data['sku']['eval_config'].upper()
log_file = base_config_name + "_vs_" + eval_config_name + ".log"
debug_file = base_config_name + "_vs_" + eval_config_name + "_debug.log"
#results_file = base_config_name + "_vs_" + eval_config_name + "_results.csv"

###Print basic details in log file
lf = open(log_file,'w')
if (options.run_debug):
    df = open(debug_file,'w')

print ("Generating results for " + base_config_name + " vs " + eval_config_name,file=lf) 
print(" ",file=lf)
print("Command Line -->",file=lf)
print(" ".join(sys.argv),file=lf)
print("",file=lf)

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

def compute_energy(input_hash,frequency):
    output_hash = deepcopy(input_hash)
    workloads = list(input_hash.keys())
    clusters = list(input_hash[workloads[0]].keys())
    for wl in workloads:
        FPS = float(input_hash[wl]['FPS'])
        for cluster in clusters:
            if (cluster != 'FPS') and (cluster != 'SoW'):
                output_hash[wl][cluster] = float(input_hash[wl][cluster])/(FPS/float(frequency))
    #print (output_hash)
    return output_hash

def geomean(numbers):
    product = 1.0
    for n in numbers:
        product *= n
    return product ** (1.0/len(numbers))

def compute_geomean(input_hash):
    workloads = list(input_hash.keys())
    clusters = list(input_hash[workloads[0]].keys())
    output_hash = deepcopy(input_hash)
    output_hash.update({'GEOMEAN':input_hash[workloads[0]]})
    for cluster in clusters:
        data = []
        for wl in workloads:
            data.append(float(input_hash[wl][cluster]))
        geomean_value = geomean(data)
        output_hash['GEOMEAN'][cluster] = geomean_value
    return output_hash

def contribution_to_GT(input_hash):
    output_hash = deepcopy(input_hash)
    workloads = list(input_hash.keys())
    clusters = list(input_hash[workloads[0]].keys())
    for wl in workloads:
        GT_DATA = float(input_hash[wl]['GT Cdyn'])*1000  ## Converting to pF as clusters are in pF
        for cluster in clusters:
            if (cluster == 'GT Cdyn'):
                output_hash[wl][cluster] = 100.00 
            elif (cluster == 'FPS'):
                output_hash[wl][cluster] = float(output_hash[wl][cluster])
            else:
                output_hash[wl][cluster] = float(input_hash[wl][cluster])*100.00/GT_DATA
    return output_hash

###function to write Dictionary as CSV for debug
def write2csv(input_hash,filename):
    workloads = list(input_hash.keys())
    clusters = list(input_hash[workloads[0]].keys())
    clusters.insert(0,'FRAME')
    with open(filename, "w") as f:
        w = csv.DictWriter(f, clusters)
        #w.writeheader()
        headers = {}
        for i in w.fieldnames:
            headers[i]=i
        w.writerow(headers)
        for k in input_hash:
            w.writerow({field: input_hash[k].get(field) or k for field in clusters})




def get_percentage_diff(base_config_value, eval_config_value):
    improvement = (float(eval_config_value)/float(base_config_value)-1)*100
    return improvement
#################################################
####### Config Energy Efficiency Analysis ####### 
#################################################

##store data of base config in a dictionary
####****Deprecated: this way of doing things led to unordered dicts******
####base_data = csv.DictReader(open(settings_data['data_file']['base_config']))
####base_config_hash=OrderedDict()
####for row in base_data:
####    print(row)
####    key = row.pop('Frame')
####    if key in base_config_hash: ##same WL should typically never repeat
####        key = key + "_REPEAT_REPEAT"
####    base_config_hash[key]=row
base_config_hash=OrderedDict()
with open(settings_data['data_file']['base_config']) as f:
    csvReader = csv.reader(f)
    fields = next(csvReader)
    for row in csvReader:
        temp = OrderedDict(zip(fields, row))
        frame_name = temp.pop("Frame")
        base_config_hash[frame_name] = temp

##eval config data dumped to dict
eval_config_hash=OrderedDict()
with open(settings_data['data_file']['eval_config'],'r') as f:
    csvReader = csv.reader(f)
    fields = next(csvReader)
    for row in csvReader:
        temp = OrderedDict(zip(fields, row))
        frame_name = temp.pop("Frame")
        eval_config_hash[frame_name] = temp
#print (eval_config_hash)

## Step 1: Compute geomeans - 'GEOMEAN' will be a WL key in hash
base_config_hash = compute_geomean(base_config_hash)
eval_config_hash = compute_geomean(eval_config_hash)
write2csv(base_config_hash, base_config_name + "_geomean_computation.csv")
write2csv(eval_config_hash, eval_config_name + "_geomean_computation.csv")

## Step 2: compute cdyn/(fps/f) - a proxy metric for energy ##
base_config_energy_hash = OrderedDict()
eval_config_energy_hash = OrderedDict()
base_config_energy_hash = compute_energy(base_config_hash,settings_data['frequency_MHz']['base_config'])
eval_config_energy_hash = compute_energy(eval_config_hash,settings_data['frequency_MHz']['eval_config'])
write2csv(base_config_energy_hash, base_config_name + "_energy_computation.csv")
write2csv(eval_config_energy_hash, eval_config_name + "_energy_computation.csv")

## Step 3: Compute cluster contributions to GT 
## Baseline Config
baseline_cdyn_breakdown = OrderedDict() 
baseline_energy_breakdown = OrderedDict()
baseline_cdyn_breakdown = contribution_to_GT(base_config_hash)
baseline_energy_breakdown = contribution_to_GT(base_config_energy_hash)
## Evaluation Config
eval_cdyn_breakdown = OrderedDict()
eval_energy_breakdown = OrderedDict()
eval_cdyn_breakdown = contribution_to_GT(eval_config_hash)
eval_energy_breakdown = contribution_to_GT(eval_config_energy_hash)

write2csv(baseline_cdyn_breakdown, base_config_name + "_cdyn_breakdown.csv")
write2csv(baseline_energy_breakdown, base_config_name + "_energy_breakdown.csv")
write2csv(eval_cdyn_breakdown, eval_config_name + "_cdyn_breakdown.csv")
write2csv(eval_energy_breakdown, eval_config_name + "_energy_breakdown.csv")

## Step 4: Get missing WLs/Clusters in either config 
##Getting base config workload list and cluster list
base_config_workloads = list(base_config_hash.keys())
base_config_clusters = list(base_config_hash[base_config_workloads[0]].keys())
##Getting evaluation config workload list and cluster list
eval_config_workloads = list(eval_config_hash.keys())
eval_config_clusters = list(eval_config_hash[base_config_workloads[0]].keys())

##get handle of missing workloads in either config list
##to make it apples vs apples comparison, the WLs not present in either list needs to be removed and GEOMEANS should be recomputed
wl_eval_no_base = list(set(eval_config_workloads) - set (base_config_workloads))
wl_base_no_eval = list(set(base_config_workloads) - set (eval_config_workloads))
if wl_eval_no_base:
    print ("The following workloads are not found in " + settings_data['arch']['base_config'].upper() + settings_data['sku']['base_config'].upper() + " data: ", '\n'.join(wl_eval_no_base))
    print ("The following workloads are not found in " + settings_data['arch']['base_config'].upper() + settings_data['sku']['base_config'].upper() + " data: ", '\n'.join(wl_eval_no_base), file=lf)
    print (" ",file=lf)
    for wl in wl_eval_no_base:
        del eval_config_hash[wl]
        del eval_config_energy_hash[wl]
    del eval_config_hash['GEOMEAN']
    del eval_config_energy_hash['GEOMEAN']
    eval_config_hash = compute_geomean(eval_config_hash)
    eval_config_energy_hash = compute_energy(eval_config_hash,settings_data['frequency_MHz']['eval_config'])
if wl_base_no_eval:
    print("The following Workloads are not found in " + settings_data['arch']['eval_config'].upper() + settings_data['sku']['eval_config'].upper() + " data: ", '\n'.join(wl_base_no_eval))
    print("The following Workloads are not found in " + settings_data['arch']['eval_config'].upper() + settings_data['sku']['eval_config'].upper() + " data: ", '\n'.join(wl_base_no_eval), file=lf)
    print ("",file=lf)
    for wl in wl_base_no_eval:
        del base_config_hash[wl]
        del base_config_energy_hash[wl]
    del base_config_hash['GEOMEAN']
    del base_config_energy_hash['GEOMEAN']
    base_config_hash = compute_geomean(base_config_hash)
    base_config_energy_hash = compute_energy(base_config_hash,settings_data['frequency_MHz']['base_config'])

final_wl_comparison_list = list(set(eval_config_workloads) & set(base_config_workloads))
print ("WLs used for comparison: ", '\n'.join(final_wl_comparison_list), file=lf)
print ("",file=lf)

##get handle on the clusters that need to be compared
cluster_base_no_eval = list(set(base_config_clusters) - set(eval_config_clusters))
cluster_eval_no_base = list(set(eval_config_clusters) - set(base_config_clusters))

if cluster_base_no_eval:
    #final_cluster_comp_list = [item for item in base_config_clusters if item in eval_config_clusters]
    print (cluster_base_no_eval, "are clusters not present in " + settings_data['arch']['eval_config'].upper() + settings_data['sku']['eval_config'].upper())
    print (cluster_base_no_eval, "are clusters not present in " + settings_data['arch']['eval_config'].upper() + settings_data['sku']['eval_config'].upper(),file=lf)
if cluster_eval_no_base:
    #final_cluster_comp_list = [item for item in eval_config_clusters if item in base_config_clusters]
    print (cluster_eval_no_base, "are clusters not present in " + settings_data['arch']['base_config'].upper() + settings_data['sku']['base_config'].upper())
    print (cluster_eval_no_base, "are clusters not present in " + settings_data['arch']['base_config'].upper() + settings_data['sku']['base_config'].upper(),file=lf)

final_cluster_comp_list = [item for item in eval_config_clusters if item in base_config_clusters]
print(final_cluster_comp_list)
print ("Cluster level comparison being done for: ", (final_cluster_comp_list), file=lf)
print("",file=lf)


## Step 5: Compare the Clusters and print out percentage difference
cdyn_comparison_hash = OrderedDict()
for wl in final_wl_comparison_list:
    if wl not in cdyn_comparison_hash:
        cdyn_comparison_hash[wl]=OrderedDict()
    for cluster in final_cluster_comp_list:
        if (base_config_name + cluster) not in cdyn_comparison_hash[wl]:
            cdyn_comparison_hash[wl][cluster + "." + base_config_name] = 0
        if (eval_config_name + cluster) not in cdyn_comparison_hash[wl]:
            cdyn_comparison_hash[wl][cluster + "." + eval_config_name] = 0
        cdyn_comparison_hash[wl][cluster + "." + base_config_name] = float(base_config_hash[wl][cluster])
        cdyn_comparison_hash[wl][cluster + "." + eval_config_name] = float(eval_config_hash[wl][cluster])
        ##print(wl,cluster,float(base_config_hash[wl][cluster]),float(eval_config_hash[wl][cluster]))
        if cluster != 'SoW':
            if float(base_config_hash[wl][cluster]) == 0.0:
                #print(wl,cluster,float(base_config_hash[wl][cluster]),float(eval_config_hash[wl][cluster]))
                ##print(cdyn_comparison_hash[wl][cluster + "." + base_config_name])
                cdyn_comparison_hash[wl][cluster + ".Improvement"] = "NA"
            else:
                cdyn_comparison_hash[wl][cluster + ".Improvement"] = get_percentage_diff(base_config_hash[wl][cluster],eval_config_hash[wl][cluster])

write2csv (cdyn_comparison_hash, base_config_name + "_vs_" + eval_config_name + "_CDYN_comparison_table.csv")

energy_comparison_hash = OrderedDict()
for wl in final_wl_comparison_list:
    if wl not in energy_comparison_hash:
        energy_comparison_hash[wl]=OrderedDict()
    for cluster in final_cluster_comp_list:
        if (base_config_name + cluster) not in energy_comparison_hash[wl]:
            energy_comparison_hash[wl][cluster + "." + base_config_name] = 0
        if (eval_config_name + cluster) not in energy_comparison_hash[wl]:
            energy_comparison_hash[wl][cluster + "." + eval_config_name] = 0
        energy_comparison_hash[wl][cluster + "." + base_config_name] = float(base_config_energy_hash[wl][cluster])
        energy_comparison_hash[wl][cluster + "." + eval_config_name] = float(eval_config_energy_hash[wl][cluster])
        if cluster != 'SoW':
            if float(base_config_energy_hash[wl][cluster]) == 0.0:
                energy_comparison_hash[wl][cluster + ".Improvement"] = "NA"
            else:
                energy_comparison_hash[wl][cluster + ".Improvement"] = get_percentage_diff(base_config_energy_hash[wl][cluster],eval_config_energy_hash[wl][cluster])

write2csv (energy_comparison_hash, base_config_name + "_vs_" + eval_config_name + "_ENERGY_comparison_table.csv")

#Closing the log files at the complete end
print("Exit",file=lf)
lf.close()
if(options.run_debug):
    df.close()
