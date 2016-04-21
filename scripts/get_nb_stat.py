#!/usr/intel/bin/python

import re
import argparse
parser = argparse.ArgumentParser(description="Read Power state XLSX")
parser.add_argument('-d', '--dir',  dest="dir",  help="GSim run output directory")
parser.add_argument('-f', '--freq', dest="freq", help="GSim Freq; required to calulate FPS")
args = parser.parse_args()

if (args.freq):
    freq = float(args.freq)
else:
    freq = 0

fh_sum = open (args.dir+"/data/summary.csv.json", "r")
for line in fh_sum:
    data_hash = line.split(":[")
    break

data_len   = len(data_hash)
field_line = data_hash[data_len-1].replace('"', '')
cnt_stop   = 0
if (field_line.find("level_name") == -1):
    field_line = 'level_name,test,test_index,path,frame_weight,category,device,sim_type,psim_config,indigo,build_type,result,run_time,max_chunk_time,time_cpu_user,start_time,end_time,stats,misscorrelation,clocks,error_info,error_percent,test_args,override_args,test_dir,chunk_info,chunk_split'
else:
    cnt_stop +=1

field_list = field_line.split(",")
frame_list = {}
for i,data in enumerate(data_hash):
    item_list = data.split(",")
    if (len(item_list) < 10):
        continue
    frame_list[i] = {}
    for jj,item in enumerate(item_list):
        if (jj < len(field_list)):
            field = field_list[jj]
            item  = item.replace('"','')
            frame_list[i][field] = item

print ("")
sow = {}
wkld_frame  = {}
wkld_status = {}
result_list = {}
for frame in frame_list:
    level  = frame_list[frame]["level_name"]
    result = frame_list[frame]["result"]
    test   = frame_list[frame]["test_args"]
    cfg    = frame_list[frame]["psim_config"]
    weight = frame_list[frame]["frame_weight"].strip()
    clock  = frame_list[frame]["clocks"]
    wkld   = re.sub("_f\d\d\d\d\d_", "_", test)
    if (weight == "frame_weight"):
        continue
    if (weight == ""):
        weight = 0
    if (cfg in sow):
        pass
    else:
        sow[cfg] = {}
    if (wkld in sow[cfg]):
        sow[cfg][wkld] += float(weight)
    else:
        sow[cfg][wkld]  = float(weight)
    if (wkld in wkld_frame):
        pass
    else:
        wkld_frame[wkld] = {}
    if (cfg in wkld_status):
        pass
    else:
        wkld_status[cfg] = {}
    if (wkld in wkld_status[cfg]):
        pass
    else:
        wkld_status[cfg][wkld] = {}
    if (result in wkld_status[cfg][wkld]):
        pass
    else:
        wkld_status[cfg][wkld][result] = {}
    wkld_frame[wkld][test] = float(weight)
    wkld_status[cfg][wkld][result][test] = float(clock)
    if (result in result_list):
        pass
    else:
        result_list[result] = 1

for result in sorted(result_list.keys()):
    print ("{0:7s} | ".format(result), end="")
print ("{6:10s} | {0:15s} | {1:20s} | {2:25s} | {3:35s} | {4:15s} | {5}".
       format("cfg", "api", "title", "setting", "capture", "driver", "total_weight"))

fot_fps = {}
for cfg in sorted(sow.keys()):
    fot_fps[cfg] = {}
    for wkld in sorted(sow[cfg].keys()):
        fot_fps[cfg][wkld] = {}
        jk_list = wkld.split("/")
        if (wkld.find("GPGPU")==-1):
            i = 0
        else:
            i = 2
        if (wkld.find("/")==-1):
            continue
        api     = jk_list[i]
        title   = jk_list[i+1]
        rest    = jk_list[-1]
        jk_list = rest.split("_")
        setting = jk_list[0]
        capture = jk_list[1]
        driver  = jk_list[-1].replace(".memtrace","")
        for result in sorted(result_list.keys()):
            fot_fps[cfg][wkld][result] = {}
            local_weight = 0
            local_clock  = 0
            if (result in wkld_status[cfg][wkld]):
                for frame in wkld_status[cfg][wkld][result]:
                    if (frame in wkld_frame[wkld]):
                        local_weight += wkld_frame[wkld][frame]
                        local_clock  += wkld_frame[wkld][frame] * wkld_status[cfg][wkld][result][frame]
            if (local_weight == 0):
                print (" {0:6s} | ".format("-"), end="")
            else:
                print ("{0:7.4f} | ".format(local_weight), end="")
            fot_fps[cfg][wkld][result]['weight'] = local_weight
            fot_fps[cfg][wkld][result]['clock']  = local_clock

        print (" {6:10.4f}  | {0:15s} | {1:20s} | {2:25s} | {3:35s} | {4:15s} | {5:30s} | {6:6.4f}".
               format(cfg, api, title, setting, capture, driver, sow[cfg][wkld]), end="")
        # for frame in wkld_frame[wkld]:
        #     print ("  {0:80s} {1:10s}".format(wkld, str(wkld_frame[wkld][frame])))
        print ("")
                    
print ("")
print ("")
print (" ", end="")
for result in sorted(result_list.keys()):
    print ("    {0:15s}| ".format(result), end="")
print ("")

for cfg in sorted(sow.keys()):
    for wkld in sorted(sow[cfg].keys()):
        for result in sorted(result_list.keys()):
            local_weight = fot_fps[cfg][wkld][result]['weight']
            if (local_weight == 0):
                local_clock = 0
            else:
                local_clock  = fot_fps[cfg][wkld][result]['clock'] / local_weight
            if (local_weight == 0):
                print ("{0:8s} {1:10s} |".format("   -", "   -"), end="")
            else:
                if (freq != 0 and local_clock != 0):
                    fps = freq * 1000000 / local_clock
                else:
                    fps = local_clock
                print ("{0:6.3f} {1:12.2f} |".format(local_weight, fps), end="")
        print(" {0:6s} {1}".format(cfg, wkld))
        
