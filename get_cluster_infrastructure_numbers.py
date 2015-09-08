import lib.argparse
import re
import sys
import os
import lib.yaml as yaml

#############################
# Command Line Arguments
#############################
parser = lib.argparse.ArgumentParser(description='Get contribution of infrastructure units for each cluster')
parser.add_argument("-i","--input",dest="input_file",
                  help="Input file containing path to all ALPS Models")
parser.add_argument("-o","--output",dest="output_file",
				  help="Output CSV file")

options= parser.parse_args()

flag = os.path.isfile(options.input_file)
if(flag):
    tracefile = open(options.input_file,'r')
else:
    print("Tracefile doesn't exist")
    exit(2)

output_file = open(options.output_file,'w')
count = 0
for line in tracefile:
    line = line.strip()
    flag = os.path.isfile(line)
    if(not flag):
        print("Can't open ALPS Model",line)
        exit(2)
    else:
        alps_file = open(line,'r')
    alps_data = yaml.load(alps_file)
    alps_file.close()
    unit_data = alps_data['unit_cdyn_numbers(pF)']
    clusters = sorted(unit_data.keys())
    num_clusters = len(clusters)
    if(count == 0):
        print("Frame",end=',',file=output_file)
        print("FPS",end=',',file=output_file)
        print("GT_Cdyn",end=',',file=output_file)
        for cluster in clusters:
            units = sorted(unit_data[cluster].keys())
            for unit in units:
                if 'GLUE' in unit:
                    print(cluster+"."+unit,end=',',file=output_file)
                elif 'DOP' in unit:
                    print(cluster+"."+unit,end=',',file=output_file)
                elif 'DFX' in unit:
                    print(cluster+"."+unit,end=',',file=output_file)
                elif 'Assign' in unit:
                    print(cluster+"."+unit,end=',',file=output_file)
                elif 'CPunit' in unit:
                    print(cluster+"."+unit,end=',',file=output_file)
                ##elif 'SMALL' in unit:
                ##    print(cluster+"."+unit,end=',',file=output_file)
                elif 'Repeater' in unit:
                    print(cluster+"."+unit,end=',',file=output_file)
            print(cluster+"infra",end=',',file=output_file)
    print("",file=output_file)

    frame = line.split(".yaml")
    print(frame[0],end=',',file=output_file)
    print(alps_data['FPS'],end=',',file=output_file)
    print(1000*float(alps_data['Total_GT_Cdyn(nF)']),end=',',file=output_file)
    for cluster in clusters:
        units = sorted(unit_data[cluster].keys())
        total_cluster_infra = 0.0
        for unit in units:
            if 'GLUE' in unit:
                print(unit_data[cluster][unit],end=',',file=output_file)
                total_cluster_infra += float(unit_data[cluster][unit])
            elif 'DOP' in unit:
                print(unit_data[cluster][unit],end=',',file=output_file)
                total_cluster_infra += float(unit_data[cluster][unit])
            elif 'DFX' in unit:
                print(unit_data[cluster][unit],end=',',file=output_file)
                total_cluster_infra += float(unit_data[cluster][unit])
            elif 'Assign' in unit:
                total_cluster_infra += float(unit_data[cluster][unit])
                print(unit_data[cluster][unit],end=',',file=output_file)
            elif 'CPunit' in unit:
                total_cluster_infra += float(unit_data[cluster][unit])
                print(unit_data[cluster][unit],end=',',file=output_file)
            elif 'Repeater' in unit:
                total_cluster_infra += float(unit_data[cluster][unit])
                print(unit_data[cluster][unit],end=',',file=output_file)
            ##elif 'SMALL' in unit:
            ##    total_cluster_infra += float(unit_data[cluster][unit])
            ##    print(unit_data[cluster][unit],end=',',file=output_file)
        print(total_cluster_infra,end=',',file=output_file)
    #print("",file=output_file)
    count = count + 1

tracefile.close()
output_file.close()
