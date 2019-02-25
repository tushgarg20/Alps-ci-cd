import os, sys, re, subprocess, csv, itertools, parser, argparse, pdb, time, shlex
import lib.yaml as yaml
from subprocess import call
import lib.yaml as yaml  # requires PyYAML
import lib.argparse
from pathlib import Path


def read_cdyn_file(cdyn_file_name):
    cdyn_wt={}

    with open(cdyn_file_name) as csvfile:
        obj=(csv.reader(csvfile))
        for row in obj:
            cdyn_wt.setdefault(row[0],{})
            cdyn_wt[row[0]].setdefault(row[1],{})
            cdyn_wt[row[0]][row[1]]=[row[3]]

    return cdyn_wt


def alps_post_process(cdyn_dict,wl,lf,arch):

    cluster_cdyn={}
    unit_cdyn={}
    GT_cdyn={}
    #print (cdyn_dict,file=lf)
    header_list = ['FPS','Total_GT_Cdyn(nF)','Total_GT_Cdyn_ebb(nF)','Total_GT_Cdyn_infra(nF)','Total_GT_Cdyn_syn(nF)']
    for elements in header_list:
        num=cdyn_dict[elements]
        print ((elements+",\t").expandtabs(26)+(str(num)).expandtabs(16),file=lf)

    print("##### Cluster level cdyn #####",file=lf)
    print ("",file=lf)
    cluster_cdyn={}
    GT_cdyn = 0
    num = 0
    for clusters in cdyn_dict['cluster_cdyn_numbers(pF)'].keys():
        if arch == 'tglhp':
            if clusters == "L3Node":
                num = cdyn_dict['cluster_cdyn_numbers(pF)']["L3_Bank"]["total"] / 2.7
            elif clusters == "Fabric":
                num = cdyn_dict['cluster_cdyn_numbers(pF)']["L3_Bank"]["total"] / 5.03
            elif clusters == "SQIDI":
                num = cdyn_dict['cluster_cdyn_numbers(pF)']["GAM"]["total"] * 1.713
            elif clusters == "GTI":
                num = (cdyn_dict['cluster_cdyn_numbers(pF)']["GAM"]["total"] * 0.0307) + 10.57
            elif clusters == "UNCORE":
                num = cdyn_dict['cluster_cdyn_numbers(pF)']["GAM"]["total"] * 0.519
            else:
                num=cdyn_dict['cluster_cdyn_numbers(pF)'][clusters]["total"]
            print ((clusters+",\t").expandtabs(26)+(str(num)+",\t").expandtabs(36),file=lf)
        else:
            num=cdyn_dict['cluster_cdyn_numbers(pF)'][clusters]["total"]
            print ((clusters+",\t").expandtabs(26)+(str(num)+",\t").expandtabs(36),file=lf)
        GT_cdyn = GT_cdyn + num
    print (("GT_Cdyn,\t").expandtabs(26)+(str(GT_cdyn)).expandtabs(16),file=lf)
                    
    print("##### Unit level cdyn #####",file=lf)
    print("",file=lf)
    for cluster in cdyn_dict['unit_cdyn_numbers(pF)'].keys():
        for unit in cdyn_dict['unit_cdyn_numbers(pF)'][cluster].keys():
            #cdyn_unit=cdyn_dict.get('unit_cdyn_numbers(pF)',{}).get(clusters,{}).get(units)
            num=cdyn_dict['unit_cdyn_numbers(pF)'][cluster][unit]
            print ((cluster+",\t"+unit+",\t").expandtabs(50)+(str(num)+",\t").expandtabs(36),file=lf)

if __name__ == '__main__':
    
    parser = lib.argparse.ArgumentParser(description='Script to post process the ALPS data and put it in s')

    parser.add_argument('-o','--out_dir',dest="out_dir",default=False, help="Output directory")
    parser.add_argument('-i','--alps_dir',dest="alps_dir", help="ALPS directory")
    parser.add_argument('-a', '--arch', dest="arch", help="Architecture")
    args, sub_args = parser.parse_known_args()
   
    
    timestr = time.strftime("%Y%m%d-%H%M%S")
    if args.out_dir:
        out_d = args.out_dir
        out_directory = "./"+out_d
    else:
        out_d = "out_dir"
        out_directory = "./"+out_d+"-"+timestr

    if os.path.isdir(out_directory):
        sys.exit("Error: Log directory already exists")
    else:
        os.makedirs(out_directory)

    if os.path.isdir(options.alps_dir):

        for files in os.listdir(options.alps_dir):
            if files.endswith(".yaml"):
                wl = re.split(".yaml",files)
                out_f = wl[0]+".csv"
                lf = open(out_directory+"/"+out_f,'w')
                print ("###### Workload: "+wl[0]+"######",file=lf)
                print ("", file=lf)
                yaml_file = open(options.alps_dir+"/"+files,'r')
                cdyn_dict = yaml.load(yaml_file)
                alps_post_process(cdyn_dict,wl1[0],lf,options.arch)

                            
    elif os.path.isfile(options.alps_dir):
        if options.alps_dir.endswith("yaml"):
            wl = re.split(".yaml")
            out_f = wl[0]+".csv"
            lf = open(out_directory+"/"+out_f,'w')
            print ("###### Workload: "+wl[0]+"######",file=lf)
            print ("", file=lf)
            yaml_file = open(options.alps_dir+"/"+files,'r')
            cdyn_dict = yaml.load(yaml_file)
            alps_post_process(cdyn_dict,wl1[0],lf,options.arch)

    else:
        pass
	    

