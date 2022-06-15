import sys
import os
import re
import lib.argparse
import lib.yaml as yaml
import time
import csv

# This function parses the residency file and writes the data into a dictionary
def read_residency_file(residency_file):
    res_dir = {}
    with open(residency_file) as csvfile:
        obj=(csv.reader(csvfile))
        for row in obj:
            res_dir[row[0]]=[row[1]]
    return res_dir

# This function dumps the unit wise cdyn along with its type and the optional instance count in the text file
def dump_unit_cdyn(yaml_dict,res_dict,unit_list,state_list,lf):

    output_list = []

    if unit_list == 1 or (unit_list !=1 and state_list != 1):

        for clusters in yaml_dict['unit_cdyn_numbers(pF)'].keys():
            for units in yaml_dict['unit_cdyn_numbers(pF)'][clusters].keys():
                unit_lc = units.lower()
                unit_cdyn = yaml_dict['unit_cdyn_numbers(pF)'][clusters][units]
            
                # Stores the cluster name, unit name, type, cdyn and instance count in the list if the type is "ebb"
                if(unit_lc.find("grf") != -1 or unit_lc.find("ram") != -1 or unit_lc.find("cache") != -1 or unit_lc.find("ebb") != -1):
                    if res_dict != None:
                        if 'num_'+clusters+"_"+units in res_dict.keys():
                            instance_count = res_dict['num_'+clusters+"_"+units][0]
                            output_list.append([clusters,"ebb_cdyn",units,unit_cdyn,instance_count])
                        else:
                            output_list.append([clusters,"ebb_cdyn",units,unit_cdyn,"-"])
                    else:
                    
                        output_list.append([clusters,"ebb_cdyn",units,unit_cdyn])
                    
            # Stores the cluster name, unit name, type, cdyn and instance count in the list if the type is "inf"
                elif (unit_lc.find("assign") != -1 or unit_lc.find("clkglue") != -1 or unit_lc.find("cpunit") != -1 or unit_lc.find("dfx") != -1    or unit_lc.find("dop") != -1 or unit_lc.find("repeater") != -1):
                    if res_dict != None:
                        if 'num_'+clusters+"_"+units in res_dict.keys():
                            instance_count = res_dict['num_'+clusters+"_"+units][0]
                            output_list.append([clusters,"inf_cdyn",units,unit_cdyn,instance_count])
                        else:
                            output_list.append([clusters,"inf_cdyn",units,unit_cdyn,"-"])
                    else:
                        output_list.append([clusters,"inf_cdyn",units,unit_cdyn])
            # Stores the cluster name, unit name, type, cdyn and instance count in the list if the type is "syn"
                else:
                    if res_dict != None:
                        if 'num_'+clusters+"_"+units in res_dict.keys():
                            instance_count = res_dict['num_'+clusters+"_"+units][0] 
                            output_list.append([clusters,"syn_cdyn",units,unit_cdyn,instance_count])
                        else:
                            output_list.append([clusters,"syn_cdyn",units,unit_cdyn,"-"])
                    else:
                        output_list.append([clusters,"syn_cdyn",units,unit_cdyn])
        output_list.sort()
        if res_dict != None:
            print ("cluster,Cdyn_type,Unit,Cdyn,Instance_count",file=lf)
            for value in output_list:
                print (value[0]+","+value[1]+","+value[2]+","+str(value[3])+","+str(value[4]),file=lf)
        else:
            print ("cluster,Cdyn_type,Unit,Cdyn",file=lf)
            for value in output_list:
                print (value[0]+","+value[1]+","+value[2]+","+str(value[3]),file=lf)
    
    if state_list == 1:
        key_list=[]
        for clusters in yaml_dict['ALPS Model(pF)']['GT'].keys():
            for units in yaml_dict['ALPS Model(pF)']['GT'][clusters].keys():
                for states in yaml_dict['ALPS Model(pF)']['GT'][clusters][units].keys():
                    try:
                        key_list = yaml_dict['ALPS Model(pF)']['GT'][clusters][units][states].keys()
                        for sub_stat in key_list:
                            if sub_stat == "total":
                                continue
                            else:
                                cdyn_number = yaml_dict['ALPS Model(pF)']['GT'][clusters][units][states][sub_stat]
                                output_list.append([clusters,units,sub_stat,cdyn_number])
                    except:
                        cdyn_number = yaml_dict['ALPS Model(pF)']['GT'][clusters][units][states]
                        output_list.append([clusters,units,states,cdyn_number])
    
        print ("cluster,Unit,State,Cdyn",file=lf)
        output_list.sort()
        for value in output_list:
            print (value[0]+","+value[1]+","+value[2]+","+(str(value[3])),file=lf)
    #Key stat dump
    key_stat_list=[]
    for keys in yaml_dict['key_stats'].keys():
        key_stat_value = yaml_dict['key_stats'][keys]
        key_stat_list.append([keys,key_stat_value])
    print ("",file=lf)
    print ("######### Key stats ##########", file=lf)
    for value in key_stat_list:
        print (value[0]+","+str(value[1]),file=lf)
    print ("",file=lf)
    
if __name__ == '__main__':

    parser = lib.argparse.ArgumentParser("This script will dump the unit wise cdyn numbers in the text file")
    parser.add_argument('-i','--yaml_file',dest='yaml_dump',default=False, help="Yaml file containing the final cdyn number")
    parser.add_argument('-r','--res_file',dest='res_file',default=False,help="Residency file containing the instance count")
    parser.add_argument('-o','--out_file',dest='out_file',default=False,help="Output file in which output of the script is dumped")
    parser.add_argument('-u','--units',dest='unit_list',nargs='?', const = 1, help="Dump the cdyn number unit wise")
    parser.add_argument('-s','--states',dest='state_list',nargs='?', const = 1, help="Dump the cdyn number state wise")
    parser.add_argument('-l','--input_file',dest='input_yamls', default=False,help="Input file containing the list of yaml files")
    args, sub_args = parser.parse_known_args()

    # Timestamp is appended to the output file name 
    timestr = time.strftime("%Y%m%d-%H%M%S")
    if args.out_file:
        out_f = args.out_file
        out_file = "./"+out_f
    else:
        out_f = "unit_cdyn_dump"
        out_file = "./"+out_f+"-"+timestr+".txt"
    
    # Check if the output file is already exisits!!
    if os.path.isfile(out_file):
        sys.exit("Error: Output file already exists!")
    else:
        lf = open(out_file,"w")

    if args.res_file:
        res_dict = read_residency_file(args.res_file)
    else:
        res_dict = None
    units=args.unit_list
    states=args.state_list

    if units == states == 1:
        sys.exit("Error: You should give either -u or -s, but not both!")

    # yaml.load function return dict
    if (args.input_yamls == False) and (args.yaml_dump != False):
        yaml_file = open(args.yaml_dump,"r")
        yaml_dict=yaml.load(yaml_file)
        dump_unit_cdyn(yaml_dict,res_dict,units,states,lf)

    elif (args.input_yamls != False) and (args.yaml_dump == False):
        with open(args.input_yamls) as f:
            mylist = f.read().splitlines()
        for lines in mylist:
            print ("########## "+ os.path.abspath(lines) +"##########",file=lf)
            print (lines)
            yaml_file = open(lines,"r")
            yaml_dict=yaml.load(yaml_file)
            dump_unit_cdyn(yaml_dict,res_dict,units,states,lf)
    elif (args.input_yamls != False) and (args.yaml_dump != False):
        sys.exit("Error: Either -i or -l allowed at a time, but not both!")
    else:
        sys.exit("Error: Please give the proper input!")
