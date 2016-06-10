import lib.argparse
import re
import sys
import os
import lib.yaml as yaml

#############################
# Command Line Arguments
#############################
parser = lib.argparse.ArgumentParser(description='Script to traverse yaml file to obtain Cdyn numbers at unit level')
parser.add_argument("-i","--input",dest="input_file",
                  help="Input file containing path to all ALPS Models")
parser.add_argument("-c","--cluster",dest="cluster_of_interest",
				  help="Input name of cluster if interested in generating unit level data for that cluster alone")
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

    ##Setting cluster of interest
    clusters=[]
    if(options.cluster_of_interest):
        ##clusters = ['ROSC'] ####- if you want to analyse only a particular cluster
        clusters.append(options.cluster_of_interest)
    else:
        clusters = sorted(unit_data.keys())

    if(count == 0):
        print("Frame",end=',',file=output_file)
        print("FPS",end=',',file=output_file)
        print("GT_Cdyn",end=',',file=output_file)
        for cluster in clusters:
            units = sorted(unit_data[cluster].keys())
            for unit in units:
                print(cluster+"."+unit,end=',',file=output_file)
                ##incase you want to exclude glue,dop,dfx and small numbers
                ##if 'GLUE' not in unit:
                ##    if 'DOP' not in unit:
                ##        if 'DFX' not in unit:
                ##            if 'SMALL' not in unit:
                ##                print(cluster+"."+unit,end=',',file=output_file)
        print("",file=output_file)

    frame = line.split(".yaml")
    print(frame[0],end=',',file=output_file)
    print(alps_data['FPS'],end=',',file=output_file)
    print(1000*float(alps_data['Total_GT_Cdyn(nF)']),end=',',file=output_file)
    for cluster in clusters:
        units = sorted(unit_data[cluster].keys())
        for unit in units:
            print(unit_data[cluster][unit],end=',',file=output_file)
            ##if 'GLUE' not in unit:
            ##    if 'DOP' not in unit:
            ##        if 'DFX' not in unit:
            ##            if 'SMALL' not in unit:
            ##                print(unit_data[cluster][unit],end=',',file=output_file)
    print("",file=output_file)
    count = count + 1

tracefile.close()
output_file.close()
