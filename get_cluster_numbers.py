from lib.optparse_ext import OptionParser
import re
import sys
import os
import lib.yaml as yaml

#############################
# Command Line Arguments
#############################
parser = OptionParser()
parser.add_option("-i","--input",dest="input_file",
                  help="Input file containing path to all ALPS Models")
parser.add_option("-o","--output",dest="output_file",
				  help="Output CSV file")

(options,args) = parser.parse_args()

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
	cluster_data = alps_data['cluster_cdyn_numbers(pF)']
	clusters = sorted(cluster_data.keys())
	num_clusters = len(clusters)
	if(count == 0):
		print("Frame",end=',',file=output_file)
		track = 1
		for cluster in clusters:
			if(track == num_clusters):
				print(cluster,file=output_file)
			else:
				print(cluster,end=',',file=output_file)
				track = track+1
		
	frame = line.split(".yaml")
	print(frame[0],end=',',file=output_file)
	track = 1
	for cluster in clusters:
		if(track == num_clusters):
			print(cluster_data[cluster]['total'],file=output_file)
		else:
			print(cluster_data[cluster]['total'],end=',',file=output_file)
			track = track + 1
	count = count + 1

tracefile.close()
output_file.close()
	
