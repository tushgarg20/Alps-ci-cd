#!/usr/bin/env python
from lib.optparse_ext import OptionParser
import lib.yaml as yaml
import re
import os
import csv

################################################################################

def print_help ():

    path = os.path.abspath(__file__)
    print ("")
    print (path, " --y1 yaml_file_#1 --y2 yaml_file_#2")
    print ("    compare two ALPS result yaml files")
    return

################################################################################

parser = OptionParser()
parser.add_option("--y1", dest="yref", help="alps yaml file #1")
parser.add_option("--y2", dest="ynew", help="alps yaml file #2")
parser.add_option("--cfg", dest="cfg", help="alps yaml file #2")
(options, args) = parser.parse_args()

if (not options.yref or not options.ynew):
    print_help()
    exit(0)

################################################################################

alps_dir = os.path.dirname(__file__)
fh = open(os.path.dirname(__file__)+"/Inputs/Cdynmax.csv", 'r')
cdyn_max = {}
lines = csv.reader (fh)
for line in lines:
    cdyn_max[line[0]] = line[1]

print()

################################################################################

yaml_data = {}
f = open(options.yref, 'r')
yaml_data['ref'] = yaml.load(f)
f = open(options.ynew, 'r')
yaml_data['new'] = yaml.load(f)

header_list = [ 'FPS', 'Total_GT_Cdyn(nF)']
for header in header_list:
    print ("%-30s %10.3f    %15.3f" % (header, yaml_data['ref'][header], yaml_data['new'][header]) )

try:
    cfg    = options.cfg
    header = 'Total_GT_Cdyn(nF)'
    ar_ref = float(yaml_data['ref'][header]) / float(cdyn_max[cfg])
    ar_new = float(yaml_data['new'][header]) / float(cdyn_max[cfg])
    fps_new = yaml_data['new']['FPS']
    fps_ref = yaml_data['ref']['FPS']
    ar_iso = ar_ref * fps_new / fps_ref + 0.2122 * ( 1 - fps_new / fps_ref )
    print ("%-30s %10.3f    %15.3f    %15.3f %10.3f%%" % ("Apps_Ratio",  ar_ref, ar_new, ar_iso, ar_new/ar_iso*100 - 100 ) )
except:
    print ()

header_list = [ 'Total_GT_Cdyn_ebb(nF)', 'Total_GT_Cdyn_syn(nF)', 'Total_GT_Cdyn_infra(nF)' ]
for header in header_list:
    print ("%-30s %10.3f    %15.3f" % (header, yaml_data['ref'][header], yaml_data['new'][header]) )

cat_list = [ "physical_cdyn_numbers(pF)",  "cluster_cdyn_numbers(pF)" ]
for category in cat_list:
    print (category, ":")
    try:
        sec_list  = list(yaml_data['ref'][category].keys())
    except:
        continue
    try:
        sec_list += list(yaml_data['new'][category].keys())
    except:
        continue
    sec_list.sort()
    sec_done  = {}

    cdyn_total_ref = yaml_data['ref']['Total_GT_Cdyn(nF)']
    cdyn_total_new = yaml_data['new']['Total_GT_Cdyn(nF)']

    for cluster in sec_list:
        if cluster in sec_done.keys():
            continue
        else:
            sec_done[cluster] = 1

        print ("    ", cluster)
        for type in [ 'ebb', 'syn', 'inf', 'total' ]:
            try:
                num1 = yaml_data['ref'][category][cluster][type]
            except:
                num1 = 0
            try:
                num2 = yaml_data['new'][category][cluster][type]
            except:
                num2 = 0
            if (type == 'total'):
                print ("        %-22s %10.3f %5.1f%%  %10.3f %5.1f%% " % (type, num1, num1/cdyn_total_ref/10, num2, num2/cdyn_total_ref/10), end="" )
            else:
                print ("        %-22s %10.3f %5s   %10.3f %5s  " % (type, num1, "", num2, ""), end="" )

            if (num1 != num2 and num2 != 0 and num1 != 0):
                p_inc = float((float(num2)-float(num1)))
                print ("%10.1f%% %10.2f" % (float(p_inc/num1*100), p_inc))
            else:
                print ("%10s %10s" % ("-","-"))

category = "unit_cdyn_numbers(pF)"
print (category, ":")
sec_done = {}
for cluster in sec_list:
    if cluster in sec_done.keys():
        continue
    else:
        sec_done[cluster] = 1

    print ("    ", cluster)
    try:
        unit_list  = list(yaml_data['ref'][category][cluster].keys())
    except:
        unit_list  = []
    try:
        unit_list += list(yaml_data['new'][category][cluster].keys())
    except:
        print ()

    unit_list.sort()
    done_list  = {}
    for unit in unit_list:
        if unit in done_list.keys():
            continue
        else:
            done_list[unit] = 1

        try:
            num1 = yaml_data['ref'][category][cluster][unit]
        except:
            num1 = 0
        try:
            num2 = yaml_data['new'][category][cluster][unit]
        except:
            num2 = 0
        print ("        %-22s %10.3f %10.3f" % (unit, num1, num2), end="" )
        if (num1 != num2 and num1 != 0 and num2 != 0):
            p_inc = float(num2)-float(num1)
            print ("%10.1f%% %10.2f" % (float(float(p_inc/float(num1)*100)), float(p_inc)))
        else:
            print ("%10s %10s" % ("-", "-"))

category = "ALPS Model(pF)"
print (category, ":")
sec_done = {}
for cluster in sec_list:
    if cluster in sec_done.keys():
        continue
    else:
        sec_done[cluster] = 1

    print ("    ", cluster)
    try:
        unit_list  = list(yaml_data['ref'][category]['GT'][cluster].keys())
    except:
        unit_list  = []
    try:
        unit_list += list(yaml_data['new'][category]['GT'][cluster].keys())
    except:
        continue
    unit_list.sort()
    done_list  = {}
    for unit in unit_list:
        if unit in done_list.keys():
            continue
        else:
            done_list[unit] = 1

        print ("      ", unit)

        try:
            stat_list  = list(yaml_data['ref'][category]['GT'][cluster][unit].keys())
        except:
            stat_list  = []
        try:
            stat_list += list(yaml_data['new'][category]['GT'][cluster][unit].keys())
        except:
            print ();
        stat_list.sort()
        stat_done = {}
        for stat in stat_list:
            if stat in stat_done.keys():
                continue
            else:
                stat_done[stat] = 1
            try:
                key_list = yaml_data['new'][category]['GT'][cluster][unit][stat].keys()
            except:
                try:
                    ref_num = yaml_data['ref'][category]['GT'][cluster][unit][stat]
                except:
                    ref_num = 0.0
                try:
                    new_num = yaml_data['new'][category]['GT'][cluster][unit][stat]
                except:
                    new_num = 0.0
                try:
                    print ("%8s %-40s   %10.3f %10.3f" % ("", stat, float(ref_num), float(new_num)), end="")
                    num1 = ref_num
                    num2 = new_num
                    if (num1 != num2 and num1 != 0 and num2 != 0):
                        p_inc = float(float(num2)-float(num1))
                        print ("%10.1f%% %10.2f" % (float(p_inc/float(num1)*100), p_inc))
                    else:
                        print ("%10s %10s" % ("-","-"))
                    continue
                except:
                    print ()

            print ("%8s %-20s" % ("", stat))
            try:
                ref_num = yaml_data['ref'][category]['GT'][cluster][unit][stat]['total']
            except:
                ref_num = 0.0
            try:
                print ("%10s %-40s %10.3f %10.3f" %
                       ("", "total",
                        ref_num,
                        yaml_data['new'][category]['GT'][cluster][unit][stat]['total']), end="")
            except:
                try:
                    new_num = yaml_data['new'][category]['GT'][cluster][unit][stat]
                except:
                    new_num = 0.0
                print ("%10s %-40s %10.3f %10.3f" % ("", "total", ref_num, new_num))
                continue

            num1 = ref_num
            num2 = yaml_data['new'][category]['GT'][cluster][unit][stat]['total']
            if (num1 != num2 and num1 != 0 and num2 != 0):
                p_inc = float(float(num2)-float(num1))
                print ("%10.1f%% %10.2f" % (float(p_inc/float(num1)*100), p_inc))
            else:
                print ("%10s %10s" % ("-","-"))

            for sub_stat in key_list:
                if sub_stat == "total":
                    continue
                stat_print = sub_stat.replace(stat+"_",'  ')
                try:
                    ref_num = yaml_data['ref'][category]['GT'][cluster][unit][stat][sub_stat]
                except:
                    ref_num = 0.0
                print ("%10s %-40s %10.3f %10.3f" %
                       ("", stat_print,
                        ref_num,
                        yaml_data['new'][category]['GT'][cluster][unit][stat][sub_stat]), end="")

                num1 = ref_num
                num2 = yaml_data['new'][category]['GT'][cluster][unit][stat][sub_stat]
                if (num1 != num2 and num1 != 0 and num2 != 0):
                    p_inc = float(float(num2)-float(num1))
                    print ("%10.1f%% %10.2f" % (float(p_inc/float(num1)*100), p_inc))
                else:
                    print ("%10s %10s" % ("-","-"))

print ()
