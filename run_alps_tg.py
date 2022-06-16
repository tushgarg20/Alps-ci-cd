import csv, os, sys, glob, argparse, subprocess, time, yaml, fileinput
import pandas as pd
import numpy as np



#check number of yaml files is equal to number of stat.gz files
def checkYamlFiles():
    while True:
        print('WAITING FOR YAML FILES')
        time.sleep(3)
        dirs = os.listdir()
        #dirs = [dir for dir in os.listdir() if not os.path.isfile(dir)]
        yaml, stat = 0, 0
        for i in dirs:
            if i[-4:] == 'yaml':
                yaml += 1
            if i[-7:] == 'stat.gz':
                stat += 1
        print(stat, yaml, os.getcwd())
        if stat == yaml:
            break


def checkRows(alpsResFile, alps_timegraph, fileName):
    while True:
        print('Waiting for alps timegraph generation for ', fileName)
        time.sleep(30)
        temp_df = pd.read_csv(alps_timegraph, delim_whitespace=True)
        print('Current rows ', alpsResFile.shape[0], temp_df.shape[0])
        if alpsResFile.shape[0] == temp_df.shape[0]:
            break




parser = argparse.ArgumentParser()

parser.add_argument('-a', help = 'architecture name')
parser.add_argument('-s', help = 'ALPS directory')
parser.add_argument('-i', help = 'Input txt file inside /ALPS/ ')
parser.add_argument('-loc', help = 'Result Location from forge')
args = parser.parse_args()

tg_location = str(args.loc)
arch, input_txt, alps = str(args.a), str(args.i), str(args.s)

os.chdir(tg_location)

for res_location in os.listdir():
    os.chdir(res_location)
    #run perl script to launch alps for getting the res.csv and yaml files with the cdyn nums
    print('*********RUNNING ALPS IN + ' + res_location + '**************')
    tlist = 'ls *stat.gz > tracelist'
    subprocess.Popen(tlist, shell=True)
    run_alps_command = 'perl ' + alps + '/runall_alps.pl -i tracelist -o . -s ' + alps + ' -a ' + arch + ' -p sc_normal6 -q /VPG/All-VPG/ARCH/Kaolin/Users --'+arch+ ' -m kaolin'
    subprocess.Popen(run_alps_command, shell=True)

    #WAIT FOR YAML FILES TO GENERATE
    time.sleep(5)#waiting
    checkYamlFiles()
    print('YAML FILES GENERATED SUCCESSFULLY')



    #num_L3_Bank_UnitName
    #stat Variable
    NumEus = -1
    NumDss = -1
    NumSlices = -1
    tginterval = -1
    NumBanks = -1
    NumNodes = -1
    NumZPipes = -1
    Freq = -1
    statVar = {'NumEus':NumEus,
            'NumDss':NumDss,
            'NumSlices':NumSlices,
            'tginterval':tginterval,
            'NumBanks':NumBanks,
            'NumNodes':NumNodes,
            'NumZPipes':NumZPipes,
            'CrClock.num':Freq}
    
    #timegraph variable
    # CrClocks = -1
    # BaseClocks = -1
    num_ZPipes = 1


    print('***********************Variables Declared Successfully************')


    #gunzip all the files
    for file in glob.glob('*gz'):
        if file.endswith("stat.gz") or file.endswith("txt.gz"):
            cmd = 'gunzip ' + file
            subprocess.Popen(cmd, shell=True)
    time.sleep(2)


    print('***************gunziped all the files inside + ' + res_location +' ************************')


    for file in glob.glob('*.kaolin_Timegraph.txt'):
        fileName = file[:-len('.kaolin_Timegraph.txt')]
        kaolinTimegraph = file
        statName = fileName + '.stat'
        for line in fileinput.input(files = statName):
            line = line.split(' ')
            for i in statVar.keys():
                var = statVar[i]
                if line[0].endswith(i):
                    try:
                        statVar[i] = float(line[1][:-1])
                    except ValueError:
                        statVar[i] = str(line[1][:-1])
        fileinput.close()
        NumEus = statVar['NumEus']
        NumDss = statVar['NumDss']
        NumSlices = statVar['NumSlices']
        tginterval = statVar['tginterval']
        NumBanks = statVar['NumBanks']
        NumNodes = statVar['NumNodes']
        num_ZPipes = statVar['NumZPipes']
        Freq = statVar['CrClock.num']
        #take num_ZPipes for timegraph file
        df = pd.read_csv(file, delim_whitespace=True)
        print(df.shape)
        alpsResFile = pd.DataFrame(index=np.arange(df.shape[0]))
        #Instance count
        alpsResFile['NumEus'] = NumEus
        alpsResFile['NumDss'] = NumDss
        alpsResFile['NumSlices'] = NumSlices
        alpsResFile['tginterval'] = tginterval
        alpsResFile['NumBanks'] = NumBanks
        alpsResFile['NumNodes'] = NumNodes
        alpsResFile['Freq'] = Freq
        alpsResFile['num_ZPipes'] = num_ZPipes
        alpsResFile['FPS'] = Freq * 1000000 / tginterval
        alpsResFile['num_Slices'] = NumSlices
        alpsResFile['numEUs'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['numFGs'] = NumSlices * NumDss * NumEus
        alpsResFile['num_DSSs'] = NumDss
        alpsResFile['num_DSS'] = NumSlices * NumDss
        alpsResFile['num_Z_HIZ'] = NumSlices * num_ZPipes
        alpsResFile['num_COLOR_RCC'] =  NumSlices * num_ZPipes
        alpsResFile['num_EU_TC'] = NumSlices * NumDss * NumEus
        alpsResFile['num_EU_FPU0'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_EU_FPU1'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_EU_EM'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_EU_ExtraPipe'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_EU_GRF'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_EU_GA'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_EU_Accumulator'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_FF_VFBE'] = NumSlices
        alpsResFile['num_ROSC_WMFE'] = NumSlices
        alpsResFile['num_ROSS_MA_TDL'] = NumSlices * NumDss * 4
        alpsResFile['num_LSC_L1'] = NumSlices * NumDss
        alpsResFile['num_L3_Bank_LTCD_Data'] = NumSlices * NumDss
        alpsResFile['num_L3Node_Node'] = NumSlices
        alpsResFile['num_Fabric_Fabrics'] = NumSlices
        alpsResFile['num_L3_Slices'] = NumSlices
        alpsResFile['num_L3_Bank_Foveros'] = NumSlices * NumDss
        alpsResFile['num_Sampler_SC'] = NumSlices * NumDss
        alpsResFile['num_Sampler_Main'] = NumSlices * NumDss
        alpsResFile['num_Sampler_Fetch'] = NumSlices * NumDss
        alpsResFile['num_GAM_GAMFTLB'] = NumSlices
        alpsResFile['num_SQIDI_SQD'] = NumDss
        alpsResFile['num_DSSC_SLMBE'] = NumSlices * NumDss
        alpsResFile['num_HDC_HDCREQCMD'] = NumSlices * NumDss
        alpsResFile['num_Other_Others'] = NumSlices * NumDss
        alpsResFile['num_LSC_ROW'] = NumSlices * NumDss
        alpsResFile['num_LSC_inf'] = NumSlices * NumDss
        alpsResFile['num_Other_NodeX'] = NumSlices * 2
        alpsResFile['num_Other_Infra'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_EU_inf'] = NumSlices * NumDss * NumEus * 2
        alpsResFile['num_EU_euinf'] = NumSlices * NumDss * NumEus * 2
        #EU
        alpsResFile['FPU0_Utilization'] = df['Total_Fpu0Cycles'] / (NumEus * NumDss * NumSlices * tginterval)
        alpsResFile['PS2_EU_FPU0'] = alpsResFile['FPU0_Utilization']
        alpsResFile['FPU1_Utilization'] = df['Total_Int_Cycles']/ (NumEus * NumDss * NumSlices * tginterval)
        alpsResFile['PS2_EU_FPU1'] = alpsResFile['FPU1_Utilization']
        alpsResFile['PS2_EU_DPAS'] = df['Total_SystCycles']/ (NumEus * NumDss * NumSlices * tginterval)
        #L3 Bank
        alpsResFile['PS2_L3_Active'] = (df['L3_Read_Trans'] + df['L3_Write_Trans']) / (NumSlices * NumDss * tginterval)
        alpsResFile['PS2_L3_Idle'] = 1
        #L3 Node
        alpsResFile['PS2_L3Node_Active'] = alpsResFile['PS2_L3_Active']
        alpsResFile['PS2_L3Node_Idle'] = 1
        #LSC
        alpsResFile['PS2_LSC'] = (df['Lsc.Active']) / (NumBanks * NumDss * NumSlices * tginterval)
        alpsResFile['PS2_LSC_Idle'] = 1
        alpsResFile['PS2_LSC_Read'] = alpsResFile['PS2_LSC'] / 2
        alpsResFile['PS2_LSC_Write'] = alpsResFile['PS2_LSC_Read']
        alpsResFile['PS2_chiplet_eu_infra'] = alpsResFile['PS2_L3_Active']
        alpsResFile['PS2_chiplet_noneu_infra_idle'] = 1
        #Other
        alpsResFile['PS2_ROW'] = alpsResFile['PS2_LSC']
        alpsResFile['PS2_ROW_Idle'] = 1
        alpsResFile['PS2_NodeX'] = (df['L3_Read_Trans'] + df['L3_Write_Trans']) / (tginterval * NumSlices * 2)
        alpsResFile['PS2_BGF'] = 1
        alpsResFile['PS2_CAM_SPINE'] = 1
        alpsResFile['PS2_CAM_SPINE_COMPUTE'] = 1
        alpsResFile['PS2_CAM_SPINE_RAMBO'] = 1
        alpsResFile['PS2_Infra_emu_const'] = 1
        alpsResFile['PS2_infra'] = 1
        alpsResFile['PS2_SPINE'] = 1

        #GAM
        alpsResFile['PS2_GAM'] = (df['readbuf'] + df['WriteBuf']) / (tginterval * NumSlices)
        #SQUIDI
        alpsResFile['PS2_SQIDI'] = alpsResFile['PS2_GAM']
        alpsResFile['PS2_SQIDI_RPT'] = alpsResFile['PS2_SQIDI']
        #Sampler
        alpsResFile['PS2_Sampler_SC'] = df['sc_requests'] / (tginterval * NumDss * NumSlices)
        alpsResFile['PS2_Sampler_SC_Idle'] = 1
        #FF
        alpsResFile['PS2_VFBE'] = df['PS2_VFBE'] / (tginterval *  NumSlices)
        alpsResFile['PS1_VFBE'] = df['PS1_VFBE'] / (tginterval *  NumSlices)
        alpsResFile['PS2_TE_Enabled'] = df['PS2_TE_Enabled'] / (tginterval *  NumSlices)
        alpsResFile['PS2_VSFE'] = df['PS2_VSFE'] / (tginterval *  NumSlices)
        alpsResFile['PS2_HS_Enabled'] = df['PS2_HS_Enabled'] / (tginterval *  NumSlices)
        alpsResFile['PS2_GS_Enabled'] = df['PS2_GS_Enabled'] / (tginterval *  NumSlices)
        alpsResFile['PS2_TDS_Enabled'] = df['PS2_TDS_Enabled'] / (tginterval *  NumSlices)
        alpsResFile['PS1_VF'] = alpsResFile['PS1_VFBE']
        alpsResFile['PS1_VSFE'] = df['PS1_VSFE'] / (tginterval *  NumSlices)
        alpsResFile['PS1_GS'] = df['PS1_GS'] / (tginterval *  NumSlices)
        alpsResFile['PS1_CS'] = df['PS1_CS'] / (tginterval *  NumSlices)
        alpsResFile['PS2_CL_NoMustclip'] = df['PS2_CL_NoMustclip'] / (tginterval *  NumSlices)
        alpsResFile['PS2_WM_MSAA_PARTIALLYLIT'] = df['PS2_WM_MSAA_PARTIALLYLIT'] / (tginterval *  NumSlices)
        alpsResFile['PS2_WM_FLUSH'] = df['PS2_WM_FLUSH'] / (tginterval *  NumSlices)
        alpsResFile['PS2_WM_NOMSAA_PARTIALLYLIT'] = df['PS2_WM_NOMSAA_PARTIALLYLIT'] / (tginterval *  NumSlices)
        alpsResFile['PS2_RASTERXBAR'] = df['PS2_RASTERXBAR'] / (tginterval *  NumSlices)
        #COLOR
        alpsResFile['PS2_RCC_ALLOC_MISSES'] = df['PS2_RCC_ALLOC_MISSES'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS1_RCC'] = df['PS1_RCC'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_RCPBE_FIX_BLD'] = df['PS2_RCPBE_FIX_BLD'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_RCC_ALLOC_HITS'] = df['PS2_RCC_ALLOC_HITS'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_RCPBE_8PPC_FIX_BLD'] = df['PS2_RCPBE_8PPC_FIX_BLD'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_RCPBE_8PPC_FIX_WRT'] = df['PS2_RCPBE_8PPC_FIX_WRT'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_RCC_CACHE_READ'] = alpsResFile['PS2_RCC_ALLOC_HITS'] + alpsResFile['PS2_RCC_ALLOC_MISSES']
        alpsResFile['PS2_RCPBE_16PPC_FIX_BLD'] = df['PS2_RCPBE_16PPC_FIX_BLD'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_RCPBE_16PPC_WRT'] = df['PS2_RCPBE_16PPC_WRT'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_RCPBE_4PPC_FLT_BLD'] = df['PS2_RCPBE_4PPC_FLT_BLD'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_RCPBE_4PPC_WRT'] = df['PS2_RCPBE_4PPC_WRT'] / (tginterval * NumSlices * num_ZPipes)
        #Z
        alpsResFile['PS1_HIZ'] = df['PS1_HIZ'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS1_IZ'] = df['PS1_IZ'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS0_Z_IDLE'] = df['PS0_Z_IDLE'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_Z_HIZ_CLR'] = df['PS2_Z_HIZ_CLR'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_Z_HIZ_STC_CLR'] = df['PS2_Z_HIZ_STC_CLR'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_Z_HIZ_PASS_HIZ_CACHE_FIT'] = df['PS2_Z_HIZ_PASS_HIZ_CACHE_FIT'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_Z_HIZ_DEPTH_FAIL'] = df['PS2_Z_HIZ_DEPTH_FAIL'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_Z_HIZ_FAIL_IZ_PASS'] = df['PS2_Z_HIZ_FAIL_IZ_PASS'] / (tginterval * NumSlices * num_ZPipes)
        alpsResFile['PS2_Z_HIZ_AMBIG_IZ_PASS'] = df['PS2_Z_HIZ_AMBIG_IZ_PASS'] / (tginterval * NumSlices * num_ZPipes)
        #Foveros
        alpsResFile['Foveros_compute'] = alpsResFile['PS2_L3_Active']
        alpsResFile['Foveros_compute_idle'] = 1
        alpsResFile['Foveros_rambo'] = alpsResFile['PS2_L3_Active']
        alpsResFile['Foveros_rambo_idle'] = 1
        alpsResFile['Foveros_base'] = alpsResFile['PS2_L3_Active']
        alpsResFile['Foveros_base_idle'] = 1
        #take num_ZPipes for timegraph file
        alpsResFileName = fileName + '_alpsResFile.txt'
        alpsResFile.to_csv(alpsResFileName , index=False, sep='\t')


        print('*********Computed Utilisation Successfully inside + ' + res_location + '/' + file + ' ******************')


        #wrapper script to generate all the alps_timegraph files
        #note that you have to get the res.csv already to perform this step

        res_file = fileName + '.res.csv'
        timegraph_file = file
        yaml_file = fileName + '.yaml'
        alps_timegraph = fileName + '_alps_Timegraph.txt'
        command = 'python ' + alps + '/build_alps.py -r ' + res_file + ' -i ' + alps + '/' + input_txt + ' -a ' + arch + ' -t ' + alpsResFileName + ' -o ' + yaml_file  +' -z ' + alps_timegraph
        subprocess.Popen(command, shell=True)
        
        
        
        time.sleep(10)
        checkRows(alpsResFile, alps_timegraph, fileName)

        print('*********ALPS Timegraph generated from build_alps.py************')

        print('*********wrapper script to generated all the alps_timegraph files**********')

        
        #now the df contains the data from res csv
        df = pd.read_csv(res_file ,usecols=[0,1], header=None)
        a,b,c = float(df[df[0] == 'PS2_EU_FPU0'][1]),float(df[df[0] == 'PS2_EU_FPU1'][1]),float(df[df[0] == 'PS2_EU_DPAS'][1])
        FPU0 = float(df[df[0] == 'PS2_EU_FPU0'][1])
        FPU1 = float(df[df[0] == 'PS2_EU_FPU1'][1])
        DPAS =  float(df[df[0] == 'PS2_EU_DPAS'][1])
        utilAlpsRes = max(a,c)

        with open(yaml_file, 'r') as filee:
            yml = yaml.safe_load(filee)
        cdynEU = float(yml['cluster_cdyn_numbers(pF)']['EU']['total'])
        cdynFPU0 = float(yml['unit_cdyn_numbers(pF)']['EU']['FPU0'])
        cdynFPU1 = float(yml['unit_cdyn_numbers(pF)']['EU']['FPU1'])
        cdynDPAS = float(yml['unit_cdyn_numbers(pF)']['EU']['ExtraPipe'])
        try:
            cdynEUInf = float(yml['unit_cdyn_numbers(pF)']['EU']['euinf'])
        except KeyError:
            cdynEUInf = 0
        cdynMajor = cdynFPU0 + cdynFPU1 + cdynDPAS + cdynEUInf
        cdynRest = float(yml['cluster_cdyn_numbers(pF)']['EU']['total']) - cdynMajor
        
        try:
            cdyn_wt_FPU0 =  cdynFPU0 / FPU0
        except ZeroDivisionError:
            cdyn_wt_FPU0 = 0

        try:
            cdyn_wt_FPU1 =  cdynFPU1 / FPU1
        except ZeroDivisionError:
            cdyn_wt_FPU1 = 0

        try:
            cdyn_wt_DPAS = cdynDPAS / DPAS
        except ZeroDivisionError:
            cdyn_wt_DPAS = 0

        try:
            cdyn_wt_rest = cdynRest / utilAlpsRes
        except ZeroDivisionError:
            cdyn_wt_rest = 0

        try:
            cdynSampler = float(yml['cluster_cdyn_numbers(pF)']['Sampler']['total'])
            sampler_util = float(df[df[0] == 'PS2_Sampler_SC'][1])
        except KeyError:
            cdynSampler = 0
            sampler_util = 1

        try:
            samplerCdynWt = cdynSampler / sampler_util
        except ZeroDivisionError:
            samplerCdynWt = 0

        #outputDF from *alps_timegraph.txt
        outputDF = pd.read_csv(alps_timegraph, delim_whitespace=True)
        # print('*****************************************************************************',outputDF.shape)
        #utilisationDF from *kaolin*Timegraph.txt
        util = alpsResFile.copy()
        kaolin_TG = pd.read_csv(timegraph_file, delim_whitespace=True)
        print(util.shape, outputDF.shape)
        # util.to_csv('util.csv')
        cols = ['PS2_EU_FPU0', 'PS2_EU_FPU1', 'PS2_EU_DPAS', 'PS2_Sampler_SC']
        # print(util.columns)
        util = util[cols]

        #implement computation of cdyns here and update the outputdf here and save back to alps_timegraph.txt
        if util.shape[0] != outputDF.shape[0]:
            # print(outputDF.shape[0], util.shape[0])
            print("Number of Data rows in alps_timegraph.txt and *kaolin_timegraph.txt is not same")
        else:
            _min_row = min(util.shape[0], outputDF.shape[0])
            for i in range(_min_row):
                a = float(util['PS2_EU_FPU0'][i])
                b = float(util['PS2_EU_FPU1'][i])
                c = float(util['PS2_EU_DPAS'][i])

                #computation of sampler cdyn
                sampUtil = float(util['PS2_Sampler_SC'][i])
                samplerCdyn = samplerCdynWt * sampUtil
                #cluster_cdyn_numbers(pF).Sampler
                try:
                    outputDF['cluster_cdyn_numbers(pF).Sampler'][i] = samplerCdyn
                except KeyError:
                    pass

                ####################


                maxUtil = max(a,c)
                fpu0_cdyn = a * cdyn_wt_FPU0
                fpu1_cdyn = b * cdyn_wt_FPU1
                dpas_cdyn = c * cdyn_wt_DPAS
                #infra_cdyn = cdyn_wt_EUInf
                other_cdyn = maxUtil * cdyn_wt_rest
                #ans = maxUtil * cdynWeight
                Total_EU_Cdyn = fpu0_cdyn + fpu1_cdyn + dpas_cdyn + other_cdyn
                try:
                    temp_eu_inf = outputDF['unit_cdyn_numbers(pF).EU.euinf'][i]
                except KeyError:
                    temp_eu_inf = 0
                outputDF['cluster_cdyn_numbers(pF).EU'][i] = temp_eu_inf + fpu0_cdyn + fpu1_cdyn + dpas_cdyn + other_cdyn
                outputDF['unit_cdyn_numbers(pF).EU.FPU0'][i] = fpu0_cdyn
                outputDF['unit_cdyn_numbers(pF).EU.FPU1'][i] = fpu1_cdyn
                outputDF['unit_cdyn_numbers(pF).EU.ExtraPipe'][i] = dpas_cdyn
                outputDF['unit_cdyn_numbers(pF).EU.EM'][i] = other_cdyn

                try:
                    outputDF_fabric = outputDF['cluster_cdyn_numbers(pF).Fabric'][i]
                except KeyError:
                    outputDF_fabric = 0
                
                try:
                    outputDF_ff = outputDF['cluster_cdyn_numbers(pF).FF'][i]
                except KeyError:
                    outputDF_ff = 0

                try:
                    outputDF_color = outputDF['cluster_cdyn_numbers(pF).COLOR'][i]
                except KeyError:
                    outputDF_color = 0

                try:
                    outputDF_z = outputDF['cluster_cdyn_numbers(pF).Z'][i]
                except KeyError:
                    outputDF_z = 0

                outputDF['Total_GT_Cdyn(nF)'][i] = samplerCdyn + outputDF['cluster_cdyn_numbers(pF).EU'][i] + outputDF_fabric + outputDF_z + outputDF_color + outputDF_ff + outputDF['cluster_cdyn_numbers(pF).GAM'][i] + outputDF['cluster_cdyn_numbers(pF).L3Node'][i] +outputDF['cluster_cdyn_numbers(pF).L3_Bank'][i] + outputDF['cluster_cdyn_numbers(pF).LSC'][i] + outputDF['cluster_cdyn_numbers(pF).Other'][i] + outputDF['cluster_cdyn_numbers(pF).SQIDI'][i] + (Total_EU_Cdyn/1000)
        list_cluster = ['Total_GT_Cdyn(nF)', 'cluster_cdyn_numbers(pF).EU', 'cluster_cdyn_numbers(pF).L3_Bank', 'cluster_cdyn_numbers(pF).SQIDI', 'cluster_cdyn_numbers(pF).L3Node','cluster_cdyn_numbers(pF).LSC','cluster_cdyn_numbers(pF).Other', 'cluster_cdyn_numbers(pF).GAM', 'cluster_cdyn_numbers(pF).Fabric', 'cluster_cdyn_numbers(pF).FF', 'cluster_cdyn_numbers(pF).COLOR', 'cluster_cdyn_numbers(pF).Z', 'cluster_cdyn_numbers(pF).Sampler']
        
        for col_name in list_cluster:
            try:
                kaolin_TG =  kaolin_TG.join(outputDF[col_name], how= 'right')
            except KeyError:
                continue

        timegraph_cdyn_file = file.replace(".kaolin_Timegraph.txt", ".kaolin_cdyn_Timegraph.txt")
        # kaolin_TG.to_csv(timegraph_file, index = False, sep='\t')
        kaolin_TG.to_csv(timegraph_cdyn_file, index = False, sep='\t')
        outputDF.to_csv(alps_timegraph, index = False, sep='\t')

        #gzip back all the files
        #alps_Timegraph.txt.gz
        cmd = 'gzip -f ' + alps_timegraph
        subprocess.Popen(cmd, shell=True)
        #kaolin_Timegraph.txt.gz
        cmd = 'gzip -f ' + timegraph_file
        subprocess.Popen(cmd, shell=True)

        #changes 02/06/2022
        cmd = 'gzip -f ' + timegraph_cdyn_file
        subprocess.Popen(cmd, shell=True)

        #stat.gz
        cmd = 'gzip -f ' + statName
        subprocess.Popen(cmd, shell=True)
        #stats.gz
        # cmd = 'gzip ' + statName + 's'
        # subprocess.Popen(cmd, shell=True)

        print(file + 'Computations Done Successfully')


    os.chdir('..')
    
