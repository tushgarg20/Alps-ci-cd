# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

# Import all libraries needed for the tutorial
# General syntax to import specific functions in a library: 
##from (library) import (specific library function)
from pandas import DataFrame, read_csv
# General syntax to import a library but no functions: 
##import (library) as (give the library a nickname/alias)
import matplotlib.pyplot as plt
import pandas as pd #this is how I usually import pandas
import csv # CSV package
import sys #only needed to determine Python version number
import matplotlib #only needed to determine Matplotlib version number
import numpy as np
import statsmodels.api as sm
from matplotlib.backends.backend_pdf import PdfPages
from collections import Counter


#Open the text file and read contents

with open('Instr_snapshot.txt',"r") as f:
    wordlist = [r.split()[0] for r in f]
#Instruction opcode keys
opcode_keys = {'mac':0, 'mad':0, 'mov':0,'mul':0,'add':0, 'sel':0, 'send':0, 'or':0}

index=0
opcode_sw_count = 0
mad_mov_sw = 0
mac_mov_sw = 0
mad_mul_sw = 0
mac_mul_sw = 0
mad_add_sw = 0
send_sw = 0
#opcode_options = {0: 'mac', 1: 'mad', 2: 'mov', 3: 'mul', 4: 'add', 5: 'sel', 6: 'send', 7: 'or'}
#opcode_counts = [0,0,0,0,0,0,0,0]

opcode_counts = Counter(opcode_keys)
#opcode_counts.keys() = {'mac', 'mad', 'mov', 'mul', 'add', 'sel', 'send', 'or'}

no_of_lines = len(wordlist)
for i in wordlist:
    if index+1 < no_of_lines:
     curr_word = wordlist[index]
     next_word = wordlist[index+1]
     #Opcode count statistics
     opcode_counts[curr_word] += 1
     if curr_word != next_word:
       opcode_sw_count = opcode_sw_count + 1
       if (curr_word == 'mad' and next_word == 'mov') or (next_word == 'mad' and curr_word == 'mov'):
           mad_mov_sw = mad_mov_sw + 1
       if (curr_word == 'mac' and next_word == 'mov') or (next_word == 'mac' and curr_word == 'mov'):
           mac_mov_sw = mac_mov_sw + 1
       if (curr_word == 'mad' and next_word == 'mul') or (next_word == 'mad' and curr_word == 'mul'):
           mad_mul_sw = mad_mul_sw + 1
       if (curr_word == 'mad' and next_word == 'add') or (next_word == 'mad' and curr_word == 'add'):
           mad_add_sw = mad_add_sw + 1
       if curr_word == 'send' or next_word == 'send':
           send_sw = send_sw + 1
       
    index = index + 1
    
print("Opcode switch count is %d\n", opcode_sw_count)

import csv

path = 'Q2'

opcode_collection = [collections.Counter() for i in range(11)]
i=0
sys.stdout = open("opcode_stats.txt", 'w')
for file in os.listdir(path):
    current = os.path.join(path, file)
    if os.path.isfile(current):
      opcode_collection[i] = opcode_total_count_estimator(current)
      print(current)
      print(opcode_collection[i])
      i += 1
opcode_collection


#Extract the instruction count from the opcode line
def instr_count(line):
    instr = re.search("\s\d+\s|$", line).group()
    if instr:
      instr_cnt = int(instr)
    else:
      instr_cnt = 0
    return(instr_cnt)
    

import re
import pandas as pd
opcode_profile = open("Q2_dx11_3dMark11_opcode_profile.out", 'r')
opcode_list = r"^(mad|mac|mul|add)\s"
#matches = re.search(r'(?=^[a-zA-Z]+\s\d+\s\d+\s\(\d+\.?\d+%\)$)([a-zA-Z]+).*?\((\d+\.?\d+)',str,re.MULTILINE)
# Read in the workload level data
XL_data = pd.read_excel('Energy_Estimate_per_Instructions_EU.xlsx', sheet_name ='Energy_Costs')
# Extract the desired sheet from the XLS sheet
#Cdyn_data = XL_data.parse('Energy_Costs')
# Extract the workload names
Col_names = XL_data.columns.values
count = 0
for line in opcode_profile:
     count +=1 
     matches = re.search(r'(?=[a-zA-Z]+\s\d+\s\d+\s\(\d+\.?\d+%\)$)([a-zA-Z]+).*?\((\d+\.?\d+)',line)
     if matches:
         print(matches.group(1))
         print(matches.group(2))
     if re.search(r"kernels:\s",line):
        num_kernels = instr_count(line)
     elif re.search(r"instructions:\s",line):   
        instruction_count = instr_count(line)
     elif re.search(r"\(\s\d+.\d+%\)|\(\d+.\d+%\)", line):
         #print(line)
         operand = re.search(r"\w+", line).group()
         percent = re.findall(r"\d+.\d+", line)[1]
         print(operand, percent)
         #percent = re.match(r"(.*?)%",substr).group()
     #elif re.search(r'(?=[a-zA-Z]+\s\d+\s\d+\s\(\d+\.?\d+%\)$)([a-zA-Z]+).*?\((\d+\.?\d+)',line,re.MULTILINE):
         #matches = re.search(r'(?=[a-zA-Z]+\s\d+\s\d+\s\(\d+\.?\d+%\)$)([a-zA-Z]+).*?\((\d+\.?\d+)',line,re.MULTILINE)
         #print(matches.group(1))
        # print(matches.group(2))
print(count)    
     #Extract the SIMD width and instr. count for all opcode lines
     
     #numbers = [int(s) for s in line.split() if s.isdigit()]   
    
import re
str = "mul    16      360140832 (22.4%)"

matches = re.search(r'((...))', str)
#matches = re.search(r'(?=[a-zA-Z]+\s+\d+\s+\d+\s+\(\d+\.?\d+%\)$)',str)
print(matches.group(1))
print(matches.group(2))