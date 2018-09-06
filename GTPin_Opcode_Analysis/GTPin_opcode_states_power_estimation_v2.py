# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""
import os
import re
import pandas as pd

#Extract the instruction count from the opcode line
def instr_count(line):
    instr = re.search("\s\d+\s|$", line).group()
    if instr:
      instr_cnt = int(instr)
    else:
      instr_cnt = 0
    return(instr_cnt)
    
####################################################################################
# Function: EU_CDYN_per_frame
# Calculates the overall EU CDYN for a given frame given the inputs of opcode counts,CDYN weights
# and compute unit activity factors.
# Inputs:
#  1. opcode_file: GTPin output for the frame listing opcode counts
#  2. Cdyn_wt_file: Estimated CDyn cost for each instruction type. This is calculated from the
#      CDyn weights for all involved units provided from GLS (in Excel format)
#  3. FPU_activity_factor: PS2_EU_FPU0 residency as calculated in ALPS
#  4. EM_activity_factor:  PS2_EU_EM residency as calculated in ALPS
#  5. numEUs: Number of EUs (96 in Gen12LP)
# Outputs:
#  1. EU CDYN: Overall EU CDYN (syn + ebb) without infra power
######################################################################################


def EU_CDYN_per_frame(opcode_file, Cdyn_wt_file, FPU_activity_factor, EM_activity_factor, numEUs):
  opcode_profile = open(opcode_file, 'r')
  mad_opcode_list = ['dp4', 'dph', 'dp3', 'dp2', 'line', 'mad', 'frc', 'rndu', 'rndd', 'rnde', 'rndz', 'lzd']
  mac_opcode_list = ['mac', 'mach']
  add_opcode_list = ['add','avg','not','and','or','xor','shr','shl','cmp','cmpn','f2h','h2f','bfrev','bfe','bfi1','bfi2','fbh','fbl','cbit','addc','subb','asr']
  sel_opcode_list = ['sel','jmpi','brd','if','brc','else','endif','case','while','break','cont','halt','call','return','fork','wait','nop','csel']
  mov_opcode_list = ['mov', 'movi']
  send_opcode_list = ['send', 'sends', 'sendc', 'sendsc']
  #matches = re.search(r'(?=^[a-zA-Z]+\s\d+\s\d+\s\(\d+\.?\d+%\)$)([a-zA-Z]+).*?\((\d+\.?\d+)',str,re.MULTILINE)
  # Read in the workload level data
  XL_data = pd.read_excel(Cdyn_wt_file, sheet_name ='Energy_Costs')
  # Extract the desired sheet from the XLS sheet
  #Cdyn_data = XL_data.parse('Energy_Costs')
  # Extract the workload names
  Col_names = XL_data.columns.values
  count = 0
  mad_count = 0
  mac_count = 0
  sel_count = 0
  add_count = 0
  send_count = 0
  math_count = 0
  mul_count = 0
  mov_count = 0
  #Calculate the opcode counts for the frame based on the GTPin opcode profile data
  for line in opcode_profile:
     count +=1 
     if re.search(r"kernels:\s",line):
        num_kernels = instr_count(line)
     elif re.search(r"instructions:\s",line):   
        instruction_count = instr_count(line)
     elif re.search(r"\(\s\d+.\d+%\)|\(\d+.\d+%\)", line):
         #print(line)
         opcode = re.search(r"\w+", line).group()
         inst_count = int(re.findall(r"\d+", line)[1])
         percent = re.findall(r"\d+.\d+", line)[1]
         #print(opcode, instr_count, percent)
         if opcode in mad_opcode_list:
             mad_count += inst_count
         if opcode == 'mul':
             mul_count += inst_count
         if opcode in mov_opcode_list:
             mov_count += inst_count
         if opcode in mac_opcode_list:
             mac_count += inst_count
         if opcode in add_opcode_list:
             add_count += inst_count
         if opcode in sel_opcode_list:
             sel_count += inst_count  
         if opcode in send_opcode_list:
             send_count += inst_count
         if opcode == 'math':
             math_count += inst_count
  #print(mad_count, mac_count, add_count, mul_count, send_count, math_count, mov_count, sel_count)        
  #print(instruction_count)
  fpu_instr_count = instruction_count - send_count - math_count
  #Calculate the residency for each of the opcode types
  mad_fp32_res = (mad_count*FPU_activity_factor)/fpu_instr_count
  mac_fp32_res = (mac_count*FPU_activity_factor)/fpu_instr_count
  mul_fp32_res = (mul_count*FPU_activity_factor)/fpu_instr_count
  add_fp32_res = (add_count*FPU_activity_factor)/fpu_instr_count
  mov_fp32_res = (mov_count*FPU_activity_factor)/fpu_instr_count
  sel_fp32_res = (sel_count*FPU_activity_factor)/fpu_instr_count
  send_res = send_count/instruction_count
  # Extract the corresponding CDyn wt.
  mad32_cdyn_wt = XL_data.loc[XL_data['Instruction'] == 'mad32', 'Total Cost (max)'].iloc[0]
  mac32_cdyn_wt = XL_data.loc[XL_data['Instruction'] == 'mac32', 'Total Cost (max)'].iloc[0]
  mul32_cdyn_wt = XL_data.loc[XL_data['Instruction'] == 'mul32', 'Total Cost (max)'].iloc[0]
  add32_cdyn_wt = XL_data.loc[XL_data['Instruction'] == 'add32', 'Total Cost (max)'].iloc[0]
  mov32_cdyn_wt = XL_data.loc[XL_data['Instruction'] == 'mov32', 'Total Cost (max)'].iloc[0]
  sel32_cdyn_wt = XL_data.loc[XL_data['Instruction'] == 'sel32', 'Total Cost (max)'].iloc[0]
  send_cdyn_wt = XL_data.loc[XL_data['Instruction'] == 'send', 'Total Cost (max)'].iloc[0]
  EM_cdyn_wt = XL_data.loc[XL_data['Instruction'] == 'math', 'Total Cost (max)'].iloc[0]
  #Calculate the component CDYN values
  mad32_cdyn = mad_fp32_res*mad32_cdyn_wt
  mac32_cdyn = mac_fp32_res*mac32_cdyn_wt
  mul32_cdyn = mul_fp32_res*mul32_cdyn_wt
  add32_cdyn = add_fp32_res*add32_cdyn_wt
  mov32_cdyn = mov_fp32_res*mov32_cdyn_wt
  sel32_cdyn = sel_fp32_res*sel32_cdyn_wt
  EM_cdyn = EM_activity_factor*EM_cdyn_wt
  send_cdyn = send_res*send_cdyn_wt
  #Calculate the overall frame level CDYN
  frame_CDYN = (mad32_cdyn + mac32_cdyn + mul32_cdyn + add32_cdyn + mov32_cdyn + sel32_cdyn + EM_cdyn + send_cdyn)*numEUs
  return(frame_CDYN)  


import os
opcode_file = 'Aug20_G3_G2_opcode_profiles\G3_battlefield_f106.txt'
Cdyn_wt_file = 'Energy_Estimate_per_Instructions_EU.xlsx'
FPU_activity_factor =[0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.42279, 0.37397, 0.40257, 0.40194, 0.40062, 0.40697, 0.412997, 0.44144, 0.423318]
EM_activity_factor = [0.066644, 0.06644, 0.06644, 0.06644, 0.06644,0.0672,0.05899,0.06375,0.06375,0.06384,0.0657,0.0667,0.06827,0.07048]
numEUs = 96
frame_count = 0
path = 'Aug20_G3_G2_opcode_profiles'
outfile = open("WL_CDYN_data.txt", 'w')
for file in os.listdir(path):
    current = os.path.join(path, file)
    if os.path.isfile(current):
      frame_CDYN = EU_CDYN_per_frame(current, Cdyn_wt_file, FPU_activity_factor[frame_count], EM_activity_factor[frame_count], numEUs)
      print(frame_CDYN)
      outfile.write("{}   {}".format(current,frame_CDYN))
      outfile.write("\n")
    frame_count += 1  
outfile.close()

path = 'Aug20_G3_G2_opcode_profiles'
sys.stdout = open("WL_CDYN_data.txt", 'w')
for file in os.listdir(path):
    current = os.path.join(path, file)
    if os.path.isfile(current):
      


#Stride pattern extractor from an opcode line
#Input arguments: Line from the .stat file, Index --> 1:DST,2:SRC0,3:SRC1,4:SRC2     
def stride_pattern_extractor(line, pos):
    di = {}     
    if '<' in line:
        l = line.replace('>','<').split('<')
        for position in range(1,len(l),2):
            flag = False
            vals = l[position].replace(';',',').split(',')
            for digit in '0123456789':
                if digit in vals:
                    flag = True
            if flag:
                di[(position+1)//2] = l[position].replace(';',',').split(',')
    test = di.get(pos)
    if test:
       pattern = [int(x) for x in test]
    else:
        pattern = []
    num_elements = len(pattern)
    return(num_elements, pattern)

#Extract the exec size flag
#0:SIMD8, 1:SIMD16
def extract_exec_size(line):
    simd8_flag = 0
    simd16_flag = 0
    exec_size = re.findall("\(\d+\)", line)
    if exec_size == ['(8)']:
       simd8_flag = 1
    if exec_size == ['(16)']:
       simd16_flag = 1
    return(simd8_flag, simd16_flag)   
    
#Swizzle count detector function
def swizzle_count_estimator(file, type):
    #Read the file 
    if type == 'zip':
      with gzip.open(file,"rb") as f:
         gSimFile = f.readlines()
    else:
       with open(file,"r") as f:
         gSimFile = f.readlines()
    #lines = []    # all the line results 
    pattern = []
    swizzle_count = [0,0,0]
    scalar_count = [0,0,0]
    swizzle_percentage = [0,0,0]
    scalar_percentage = [0,0,0]
    total_opcode_count = 0
    opcode_count = 0
    simd16_flag = 0
    simd8_flag = 0
    num_elem = 0
    opcode_expr = r"\w+\s+\(\d+\)"
    for line in gSimFile:  # go over each line
        #oneLine = []       # matches for one line 
        #swizzle_flag = 0   # Reset the flag to detect swizzle in next line
        line = line.strip()
        #Estimate the opcode count
        if re.search(opcode_expr, line):
           #Estimate the opcode count
           opcode_count = instr_count(line)
           total_opcode_count += opcode_count
           if opcode_count:
                # Extract the SIMD-ness of the opcode
                simd8_flag, simd16_flag = extract_exec_size(line)
                #Extract the stride pattern for each source
                for m in range(2,5):
                    num_elem, pattern = stride_pattern_extractor(line,m)          
                    if pattern and num_elem == 3:
                        #Any regioning that is not flat involves a swizzle
                        if pattern[0] != pattern[1]*pattern[2] and (pattern != [1,1,0] ):
                            swizzle_count[m-2] += opcode_count
                        #Scalar case as well
                        if pattern == [0,1,0]:
                            scalar_count[m-2] += opcode_count
                    if pattern and num_elem <= 2:
                        if pattern != [8,1] or pattern != 1:
                            swizzle_count[m-2] += opcode_count
                    if m==4 and num_elem == 0: #2 Src operand case
                        src0_pattern = stride_pattern_extractor(line,2)
                        src1_pattern = stride_pattern_extractor(line,3)
                        if src0_pattern:
                           if src0_pattern == [8,8,1] and simd16_flag: 
                              swizzle_count[0] += opcode_count
                           if src0_pattern == [16,16,1] and simd8_flag: 
                              swizzle_count[0] += opcode_count  
                           if src1_pattern:
                              if src1_pattern == [8,8,1] and simd16_flag: 
                                swizzle_count[1] += opcode_count      
                              if src1_pattern == [16,16,1] and simd8_flag: 
                                swizzle_count[1] += opcode_count              
    #Calculate the overall swizzle and scalar percentages for each source
    for i in range(0,3):
        swizzle_percentage[i] = swizzle_count[i]/total_opcode_count
        scalar_percentage[i] = scalar_count[i]/total_opcode_count
    return(swizzle_count, swizzle_percentage, scalar_count, scalar_percentage)
    



swizzle_count, swizzle_percentage, scaler_count, scalar_percentage = swizzle_count_estimator(opcode_file, 'normal')
   #Extract the SIMD width and instr. count for all opcode lines
     
     #numbers = [int(s) for s in line.split() if s.isdigit()]   
    
import re
import pandas as pd #this is how I usually import pandas
import csv # CSV package
import sys #only needed to determine Python version number
import matplotlib #only needed to determine Matplotlib version number
import numpy as np
import statsmodels.api as sm
from matplotlib.backends.backend_pdf import PdfPages
from collections import Counter


#Open the text file and read contents

with open('GTA5-G3_f167.txt',"r") as f:
    wordlist = [r.split()[0] for r in f]
#Instruction opcode keys
opcode_keys = {'mac':0, 'mad':0, 'mov':0,'mul':0,'add':0, 'sel':0, 'send':0, 'or':0}
str = "mul 16   16      360140832 (22.4%)"

#matches = re.search(r'((...))', str)
matches = re.search(r'(?=[a-zA-Z]+\s+\d+\s+\d+\s+\(\d+\.?\d+%\)$)',str)
if matches:
  parts = matches.string.split()
  opcode = parts[0]
  simd_width = int(parts[1])
  instr_count = int(parts[2])
  print(opcode)
  print(instr_count)
#print(matches.group(1))
