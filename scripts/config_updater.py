import pandas as pd
import sys
import fileinput
import argparse

def precedence(cfg):
    if cfg == 'ADL':
        return ['Gen7','Gen7.5','Gen8','Gen9LPClient','Gen9.5LP','Gen10LP','Gen11LP','Gen11','Gen11halo','Gen12LP','Gen12HP_512','Gen12HP_384','Gen12DG','Gen12HP', 'ADL' ]
    elif cfg =='DG2':
        return ['DG2' ]
    elif cfg =='Xe2':
        return ['DG2','Xe2']
    elif cfg == 'Xe2_HPG':
        return ['DG2','Xe2', 'Xe2_HPG']
    elif cfg =='Xe2_Plan':
        return ['DG2','Xe2_Plan']
    elif cfg =='Xe2_BNA4_Plan':
        return ['DG2','Xe2_Plan','Xe2_BNA4_Plan']
    elif cfg =='DG2p5':
        return ['DG2', 'DG2p5']
    elif cfg =='MTL':
        return ['DG2','MTL']
    elif cfg =='LNL':
        return ['DG2','MTL','LNL']
    elif cfg =='PTL':
        return ['DG2','MTL','LNL','PTL']
    elif cfg =='CPL':
        return ['DG2','MTL','LNL','CPL']
    elif cfg =='Xe3':
        return ['DG2','PVC', 'PVCDP', 'Xe3' ]
    elif cfg =='PVCDP':
        return ['DG2','PVC', 'PVCDP' ]
    elif cfg == 'PVCXT':
        return ['DG2','PVC', 'PVCDP', 'PVCXT']
    elif cfg == 'PVCXTTrend':
        return ['DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend']
    elif cfg == 'RLT1':
        return ['DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend','RLT1']
    elif cfg =='Xe3_XPC':
        return ['DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend','RLT1', 'Xe3_XPC']
    elif cfg == 'RLTCONCEPT':
        return ['DG2','PVC', 'PVCDP', 'RLTCONCEPT']
    elif cfg == 'RLTB_EC_0_5':
        return ['DG2','PVC','PVCDP','PVCXT','PVCXTTrend','RLTB_EC_0_5']
    elif cfg == 'Xe3_FCS'
        return ['DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend', 'RLT1', 'Xe3_FCS']
    elif cfg == 'Xe3_FCS_SW':
        return ['DG2','PVC', 'PVCDP', 'PVCXT', 'PVCXTTrend', 'RLT1', 'Xe3_FCS_SW']
    elif cfg == 'PVCK2xSA':
        return ['DG2','PVC', 'PVCDP', 'PVCXT', 'PVCK2xSA']
    else:
        return ['DG2', 'PVC_Scaled','PVC','PVC_A21','PVCDP','PVC2']


parser = argparse.ArgumentParser(description='This tool is config updater')
parser.add_argument('-c','--config',dest="config_location",
           help="Input config params file")
parser.add_argument('-s','--alps',dest="alps_location",
           help="Source ALPS Directory")
parser.add_argument('-new',dest="new_config",
           help="Name of the NEW config for which the scalers is to be updated")
parser.add_argument('-o',dest="old_cfg",
           help="Name of the OLD config from which the new one is derived")
options = parser.parse_args()


alps_location = options.alps_location
config_location = options.config_location
new_config = options.new_config
old_cfg = options.old_cfg


#output_inst == 4 instruction type for others already mentioned



# f= fileinput.input(alps_location + '/Inputs/syn_cdyn_cagr_cam.csv')


#we have to take care of the scalers from pre configs to the new one too, like we have done downstairs 
#in case of new config we have to add all the combination of scalers to 1 prior
#unit
if new_config != None:
    #unit
    unitCluster = dict()
    tempDf = pd.read_csv(alps_location + '/Inputs/unit_cdyn_cagr_cam.csv' , usecols=[0,1,2,3,4])
    a = tempDf['Unit']
    a = set(a)
    a = list(a)
    l = {i:list() for i in (a)}
    for i in range(tempDf.shape[0]):
        l[tempDf['Unit'][i]].append(tempDf['Cluster'][i])
    for i in (l.keys()):
        l[i] = set(l[i])
        l[i] = list(l[i])
    unitCluster = l
    pres = precedence(new_config)
    pres.reverse()
    for unitname in unitCluster.keys():
        for clustername in unitCluster[unitname]:
            for i in range(len(pres)):
                arch = pres[i]
                tt = tempDf[(tempDf['Unit'] == unitname) & (tempDf['Cluster'] == clustername) & (tempDf['Source'] == arch) & (tempDf['Destination'] == new_config)]
                if tt.shape[0] == 0 and arch != new_config:
                    # unit part does not need to have all the combinations of rows to be updated

                    # new_row = {'Unit':unitname, 'Cluster': clustername, 'Source': arch, 'Destination': new_config, 'Cdyn reduction': 1.0}
                    # tempDf = tempDf.append(new_row, ignore_index = True)
                    
                    #append all the scalers for pre configs
                    for j in range(i+1, len(pres)):
                        prevArch = pres[j]
                        if prevArch != new_config:
                            tt1 = tempDf[(tempDf['Unit'] == unitname) & (tempDf['Cluster'] == clustername) & (tempDf['Source'] == prevArch) & (tempDf['Destination'] == arch)]
                            if tt1.shape[0] != 0:
                                new_scaler = 1
                                factor_mul = list(tt1['Cdyn reduction'])[0]
                                factor_mul = float(factor_mul)
                                if factor_mul != 1:
                                    new_row = {'Unit':unitname, 'Cluster': clustername, 'Source': prevArch, 'Destination': new_config, 'Cdyn reduction': factor_mul}
                                    tempDf = tempDf.append(new_row, ignore_index = True)
                    

    tempDf.columns = ['Unit', 'Cluster', 'Source', 'Destination', 'Cdyn reduction']
    tempDf = tempDf.fillna('NA')
    tempDf.to_csv(alps_location + '/Inputs/unit_cdyn_cagr_cam.csv', index = False)

    #cluster
    clusters = list()
    tempDf = pd.read_csv(alps_location + '/Inputs/syn_cdyn_cagr_cam.csv' , usecols=[0,1,2,3])
    a = list(tempDf['Cluster'])
    a = set(a)
    a = list(a)
    clusters = a
    for clustername in clusters:
        for i in range(len(pres)):
            arch = pres[i]
            tt = tempDf[(tempDf['Cluster'] == clustername) & (tempDf['Source'] == arch) & (tempDf['Destination'] == new_config)]
            if tt.shape[0] == 0 and arch != new_config:
                new_row = {'Cluster': clustername, 'Source': arch, 'Destination': new_config, 'Cdyn Reduction': 1.0, }
                tempDf = tempDf.append(new_row, ignore_index = True)

                #append all the scalers for pre configs
                for j in range(i+1, len(pres)):
                    prevArch = pres[j]
                    if prevArch != new_config:
                        tt1 = tempDf[(tempDf['Cluster'] == clustername) & (tempDf['Source'] == prevArch) & (tempDf['Destination'] == arch)]
                        if tt1.shape[0] != 0:
                            new_scaler = 1
                            factor_mul = list(tt1['Cdyn Reduction'])[0]
                            new_row = {'Cluster': clustername, 'Source': prevArch, 'Destination': new_config, 'Cdyn Reduction': factor_mul}
                            tempDf = tempDf.append(new_row, ignore_index = True)

    tempDf.columns = ['Cluster', 'Source', 'Destination', 'Cdyn reduction']
    tempDf = tempDf.fillna('NA')
    tempDf.to_csv(alps_location + '/Inputs/syn_cdyn_cagr_cam.csv', index = False)

    #process cam
    tempDf = pd.read_csv(alps_location + '/Inputs/process_cam.csv' , usecols=[0,1,2,3])
    for i in range(len(pres)):
        arch = pres[i]
        tt = tempDf[(tempDf['Source'] == arch) & (tempDf['Destination'] == new_config)]
        if tt.shape[0] == 0 and arch != new_config:
            new_row = {'Source': arch, 'Destination': new_config, 'Scaling_Factor_Syn': 1.0, 'Scaling_Factor_EBB': 1.0}
            tempDf = tempDf.append(new_row, ignore_index = True)

            #append all the scalers for pre configs
            for j in range(i+1, len(pres)):
                prevArch = pres[j]
                if prevArch != new_config:
                    tt1 = tempDf[(tempDf['Source'] == prevArch) & (tempDf['Destination'] == arch)]
                    if tt1.shape[0] != 0:
                        new_scaler = 1
                        factor_mul = list(tt1['Scaling_Factor_Syn'])[0]
                        new_row = {'Source': prevArch, 'Destination': new_config, 'Scaling_Factor_Syn': factor_mul, 'Scaling_Factor_EBB': factor_mul}
                        tempDf = tempDf.append(new_row, ignore_index = True)


    tempDf.columns = ['Source', 'Destination', 'Scaling_Factor_Syn', 'Scaling_Factor_EBB']
    tempDf = tempDf.fillna('NA')
    tempDf.to_csv(alps_location + '/Inputs/process_cam.csv', index = False)


#separating the 4 field ,3 field,5 field entry data as inst_4,inst_3,inst_5 respectievely from config param file.

df = pd.read_csv(config_location, header = None)

df = df.fillna('None')
tt = ['None' for i in range(df.shape[0])]
df[df.shape[1]] = tt
df[df.shape[1]] = tt
# print(df)
inst_3,inst_4,inst_5 = [],[],[]

for i in range(df.shape[0]):
    d = dict()
    if df[4][i] == 'None':
        if df[3][i] == 'None':
            d['Source_config'] = df[0][i]
            d['Target_config'] = df[1][i]
            d['Scaler'] = df[2][i]
            inst_3.append(d)
        else:
            d['Source_config'] = df[1][i]
            d['Target_config'] = df[2][i]
            d['Scaler'] = df[3][i]
            d['Cluster'] = df[0][i]
            inst_4.append(d)
    else:
        d['Source_config'] = df[2][i]
        d['Target_config'] = df[3][i]
        d['Scaler'] = df[4][i]
        d['Cluster'] = df[1][i]
        d['Unit'] = df[0][i]
        inst_5.append(d)

#classifying the data that doesnot contain"#" and "NA"(in scaler entry) from syn_cdyn_cagr_cam file and appending it to the new list as output_inst.

f= fileinput.input(alps_location + '/Inputs/syn_cdyn_cagr_cam.csv')
i = 0
output_inst = []
for line in f:
    i += 1
    if i > 1:
        arr = line.split(',')
        arr[-1] = arr[-1][:-1]
        if arr[0][0] != '#':
            if arr[3] != 'NA':
                if type(arr[3]) == str:
                    if len(arr[3]) != 0:
                        arr[3] = float(arr[3])
                else:
                    arr[3] = float(arr[3])
                
            output_inst.append(arr[:4])
f.close()

for i in output_inst:
    if i[3] != 'NA':
        if type(i[3]) == str:
            if len(i[3]) != 0:
                i[3] = float(i[3])
        else:
            i[3] = float(i[3])

# output_inst(Checking whether a scaler exists for the given pattern; if yes, replace with the new scaler).

for ins in inst_4:
    k = False
    for i in range(len(output_inst)):
        if output_inst[i][0] == ins['Cluster'] and output_inst[i][1] == ins['Source_config'] and output_inst[i][2] == ins['Target_config']:
            output_inst[i][3] = float(ins['Scaler'])
            k = True
    if k == False:
        temp = [ins['Cluster'], ins['Source_config'], ins['Target_config'], float(ins['Scaler'])]
        output_inst.append(temp)
        
    #2nd step(For the given target config and cluster, scan all patterns with different base configs and scalers.
#For each different base config, update the scaler as  Existing Scaler * Scaler)

    for i in range(len(output_inst)):
        if output_inst[i][0] == ins['Cluster'] and output_inst[i][2] == ins['Target_config'] and output_inst[i][1] != ins['Source_config']:
            if output_inst[i][3] != 'NA':
                output_inst[i][3] = float(output_inst[i][3]) * float(ins['Scaler'])  

    #If target config is new, add new patterns for all Configs from DG2 (or bottommost config in hierarchy)           

def is_present_inst_4(cluster, base, target, output_inst):
    for i in range(len(output_inst)):
        ins = output_inst[i]
        if ins[1] == base and ins[0] == cluster and ins[2] == target:
            return i
    return -1

for ins in inst_4:
    cluster, base, target, scaler = ins['Cluster'], ins['Source_config'], ins['Target_config'], ins['Scaler']
    pre_list = precedence(base)
    br = False
    for i in range(len(pre_list)-1, -1, -1):
        if br == True:
            break
        if pre_list[i] == 'Gen11LP':
            br = True

        if pre_list[i] != base and pre_list[i] != target:
            pres = is_present_inst_4(cluster, pre_list[i], target, output_inst)
            if pres == -1:
                scale1 = is_present_inst_4(cluster, pre_list[i], base, output_inst)
    #                 print(scale1)
                if scale1 != -1:
    #                     print('hhh')
                    ne= float(scaler)* float(output_inst[scale1][3])
                    # print(pre_list[i], pres, ne)
                    temp = [cluster, pre_list[i], target, ne]
                    output_inst.append(temp)

    temp = [cluster, target, target, 1.0]
    output_inst.append(temp)

f= fileinput.input(alps_location + '/Inputs/process_cam.csv')
i = 0
output_inst_3 = []
for line in f:
    i += 1
    if i > 1:
        arr = line.split(',')
        arr[-1] = arr[-1][:-1]
        if arr[0][0] != '#':
            if arr[2] != 'NA':
                if type(arr[2]) == str:
                    if len(arr[2]) != 0:
                        arr[2] = float(arr[2])
                else:
                    arr[2] = float(arr[2])                    
            output_inst_3.append(arr[:3])
f.close()
#similar steps hav been done for 3  field entry data in a same sequence as we have done for above 4 field entry data.
for i in output_inst_3:
    if i[2] != 'NA':
        if type(i[2]) == str:
            if len(i[2]) != 0:
                i[2] = float(i[2])
        else:
            i[2] = float(i[2])

for ins in inst_3:
    k = False
    for i in range(len(output_inst_3)):
        if output_inst_3[i][0] == ins['Source_config'] and output_inst_3[i][1] == ins['Target_config']:
            output_inst_3[i][2] = float(ins['Scaler'])
            k = True
    if k == False:
        temp = [ ins['Source_config'], ins['Target_config'], float(ins['Scaler'])]
        output_inst_3.append(temp)
        
    #2nd step
    for i in range(len(output_inst_3)):
        if output_inst_3[i][1] == ins['Target_config'] and output_inst_3[i][0] != ins['Source_config']:
                output_inst_3[i][2] = float(output_inst_3[i][2]) * float(ins['Scaler'])  
            

def is_present_inst_3(base, target, output_inst_3):
    for i in range(len(output_inst_3)):
        ins = output_inst_3[i]
        if ins[1] == target and ins[0] == base:
            return i
    return -1
    


for ins in inst_3:
    base, target, scaler =  ins['Source_config'], ins['Target_config'], ins['Scaler']
    pre_list = precedence(base)
    br = False
    for i in range(len(pre_list)-1, -1, -1):
        if br == True:
            break
        if pre_list[i] == 'Gen11LP':
            br = True

        if pre_list[i] != base and pre_list[i] != target:
            pres = is_present_inst_3( pre_list[i], target, output_inst_3)
            if pres == -1:
                scale1 = is_present_inst_3( pre_list[i], base, output_inst_3)
    #                 print(scale1)
                if scale1 != -1:
    #                     print('hhh')
                    ne= float(scaler)* float(output_inst_3[scale1][2])
                    # print(pre_list[i], pres, ne)
                    temp = [ pre_list[i], target, ne]
                    output_inst_3.append(temp)

    temp = [target, target, 1.0]
    output_inst_3.append(temp)



#similar steps hav been done for 5 field entry data in a same sequence as we have done for above 3 and 4 field entry data.

f= fileinput.input(alps_location + '/Inputs/unit_cdyn_cagr_cam.csv')
i = 0
output_inst_5 = []
for line in f:
    i += 1
    if i > 1:
        arr = line.split(',')
        arr[-1] = arr[-1][:-1]
        if arr[0][0] != '#':
            if arr[4] != 'NA':
                arr[4] = float(arr[4])
            output_inst_5.append(arr[:5])
f.close()

#extract the scalers for cdyn.csv
cdynInst = []
tempInst_5 = []
for i in inst_5:
    if i['Unit'] == 'cdyn':
        new_entry = dict()
        for j in i.keys():
            if j != 'Cluster' and j != 'Unit':
                new_entry[j] = i[j]
        new_entry['State'] = i['Cluster']
        cdynInst.append(new_entry)
    else:
        tempInst_5.append(i)
inst_5 = tempInst_5

#update the cdyn.csv
cdynDF = pd.read_csv(alps_location + '/Inputs/cdyn.csv', usecols = [0,1,2,3,4,5,6])

for entry in cdynInst:
    done = 0
    for i in range(cdynDF.shape[0]):
        if entry['State'] == str(cdynDF['State'][i])[0:len(entry['State'])]:
            if str(cdynDF['Source'][i]) == entry['Target_config']:
                cdynDF['Weight'][i] = float(entry['Scaler'])
                done = 1
                break
    if done == 0:
        for i in range(cdynDF.shape[0]):
            if entry['State'] == str(cdynDF['State'][i])[0:len(entry['State'])]:
                if str(cdynDF['Source'][i]) == entry['Source_config']:
                    try:
                        new_wt = float(cdynDF['Weight'][i]) * float(entry['Scaler'])
                    except ValueError:
                        new_wt = 'NA'
                    new_row = {'State': str(cdynDF['State'][i]), 'Source': entry['Target_config'], 'Stepping': str(cdynDF['Stepping'][i]), 'Weight': new_wt, 'Type': str(cdynDF['Type'][i]), 'RefGC': cdynDF['RefGC'][i], 'Comments': 'Config Updater Script Changed this'}
                    cdynDF = cdynDF.append(new_row, ignore_index = True)

cdynDF = cdynDF.fillna('NA')
cdynDF.to_csv(alps_location + '/Inputs/cdyn.csv', index = False)


# print(cdynDF.columns)
# print(cdynInst)

for i in output_inst_5:
    if i[4] != 'NA':
        i[4] = float(i[4])

for ins in inst_5:
    k = False
    for i in range(len(output_inst_5)):
        if output_inst_5[i][0] == ins['Unit'] and output_inst_5[i][1] == ins['Cluster'] and output_inst_5[i][2] == ins['Source_config'] and output_inst_5[i][3]==ins['Target_config']:
            output_inst_5[i][4] = float(ins['Scaler'])
            k = True
    if k == False:
        temp = [ins['Unit'] ,ins['Cluster'], ins['Source_config'], ins['Target_config'], float(ins['Scaler'])]
        output_inst_5.append(temp)
        
    #2nd step
    for i in range(len(output_inst_5)):
        if output_inst_5[i][0] == ins['Unit'] and output_inst_5[i][1] == ins['Cluster'] and output_inst_5[i][2] != ins['Source_config'] and output_inst_5[i][3]==ins['Target_config'] :
            if output_inst_5[i][4] != 'NA':
                output_inst_5[i][4] = float(output_inst_5[i][4]) * float(ins['Scaler'])  
            
def is_present_inst_5(unit, cluster, base, target, output_inst_5):
    for i in range(len(output_inst_5)):
        ins = output_inst_5[i]
        if ins[2] == base and ins[0] == unit and ins[1] == cluster and ins[3]== target:
            return i
    return -1
    


for ins in inst_5:
    unit ,cluster, base, target, scaler = ins['Unit'], ins['Cluster'], ins['Source_config'], ins['Target_config'], ins['Scaler']
    pre_list = precedence(base)
    br = False
    for i in range(len(pre_list)-1, -1, -1):
        if br == True:
            break
        if pre_list[i] == 'Gen11LP':
            br = True

        if pre_list[i] != base and pre_list[i] != target:
            pres = is_present_inst_5(unit, cluster, pre_list[i], target, output_inst_5)
            if pres == -1:
                scale1 = is_present_inst_5(unit, cluster, pre_list[i], base, output_inst_5)
    #                 print(scale1)
                if scale1 != -1:
    #                     print('hhh')
                    ne= float(scaler)* float(output_inst_5[scale1][4])
    #                print(pre_list[i], pres, ne)
                    temp = [unit, cluster, pre_list[i], target, ne]
                    output_inst_5.append(temp)
    
    temp = [unit, cluster, target, target, 1.0]
    output_inst_5.append(temp)


#Output of all the files corresponding to thier names,and updating the files in heir same location.


tt = pd.DataFrame(output_inst_5, columns=['Unit', 'Cluster', 'Source', 'Destination', 'Cdyn reduction'])
tt = tt.fillna('NA')
tt.to_csv(alps_location + '/Inputs/unit_cdyn_cagr_cam.csv', index = False)


tt = pd.DataFrame(output_inst, columns=['Cluster', 'Source', 'Destination', 'Cdyn Reduction'])
tt = tt.fillna('NA')
tt.to_csv(alps_location + '/Inputs/syn_cdyn_cagr_cam.csv', index = False)

for i in range(len(output_inst_3)):
    output_inst_3[i].append(output_inst_3[i][2])
tt = pd.DataFrame(output_inst_3, columns=['Source', 'Destination', 'Scaling_Factor_Syn', 'Scaling_Factor_EBB'])
tt = tt.fillna('NA')
tt.to_csv(alps_location + '/Inputs/process_cam.csv', index = False)


#update the stepping.csv and voltage.csv

#stepping.csv
stepping = pd.read_csv(alps_location + '/Inputs/stepping.csv')
new_row = {'Gen': new_config, 'Source': 'A0', 'Destination': 'B0', 'Cdyn Reduction': 1.0}
stepping = stepping.append(new_row, ignore_index = True)
new_row = {'Gen': new_config, 'Source': 'A0', 'Destination': 'C0', 'Cdyn Reduction': 1.0}
stepping = stepping.append(new_row, ignore_index = True)
new_row = {'Gen': new_config, 'Source': 'B0', 'Destination': 'C0', 'Cdyn Reduction': 1.0}
stepping = stepping.append(new_row, ignore_index = True)

stepping.to_csv(alps_location + '/Inputs/stepping.csv', index = False)

#voltage.csv
