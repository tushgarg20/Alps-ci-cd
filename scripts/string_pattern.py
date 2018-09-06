
pattern = ['1']

file = open('Instr_snapshot_test.txt','r')

text = file.readlines()
di = {}

for num in range(1,len(text)-1):
    di[num] = {}

num_lines = 0
lind = 0
for line in range(len(text)):
    if '<' in text[line]:
        lind += 1
        l = text[line].replace('>','<').split('<')
        for position in range(1,len(l),2):
            di[lind][(position+1)//2] = [int(x) for x in l[position].replace(';',',').split(',')] 
    num_lines +=1
    entry = di.get(2)
    pattern = entry.get(2)
    line = file.readline()

file = open('Instr_snapshot_test.txt','r')

text = file.readlines()

for line in text:
    pattern = stride_pattern_extractor(line,2)
    if pattern:
       test = pattern[0]*pattern[1]*pattern[2]

import re    
file = open('Instr_snapshot_test.txt','r')

text = file.readlines()

for line in text:
    exec_size, simd8_flag, simd16_flag = extract_exec_size(line)
    print(exec_size)
    print(simd8_flag)
    print(simd16_flag)
    print('\n')
    
    
    
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




# =============================================================================
# #file = open('Manhattan_Stat_Files/ogles_gfxbench3-0-6_ab-manhattan-1920x1080__and-cht-v2_f00087_ci-main-66088-ptbr-on.stat')
# file = open('Instr_snapshot_test.txt','r')
# 
# text = file.readlines()
# 
# for line in text:
#     pattern = re.findall('<(.*)>', line)
#     print(pattern)
#     #pattern = stride_pattern_extractor(line,2)
#     if pattern:
#        test = pattern[0]*pattern[1]*pattern[2]
# 
# =============================================================================



#Extract the instruction count from the opcode line
def instr_count(line):
    instr = re.search("\s\d+\s|$", line).group()
    if instr:
      instr_cnt = int(instr)
    else:
      instr_cnt = 0
    return(instr_cnt)
    
    
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
def swizzle_count_estimator(file):
    #Read the file 
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
# =============================================================================
#                 pattern = stride_pattern_extractor(line,3)
#                 if pattern:
#                     #Any regioning that is not flat involves a swizzle
#                     if pattern[0] != pattern[1]*pattern[2] and (pattern != [1,1,0] ):
#                         swizzle_count[1] += opcode_count
#                     #Scalar case as well
#                     if pattern == [0,1,0]:
#                         scalar_count[1] += opcode_count
#                 pattern = stride_pattern_extractor(line,4)
#                 if pattern:
#                     #Any regioning that is not flat involves a swizzle
#                     if pattern[0] != pattern[1]*pattern[2] and (pattern != [1,1,0] ):
#                         swizzle_count[2] += opcode_count
#                     #Scalar case as well
#                     if pattern == [0,1,0]:
#                         scalar_count[2] += opcode_count
#                 else: #2 source operand
# =============================================================================
                  
    #Calculate the overall swizzle and scalar percentages for each source
    for i in range(0,3):
        swizzle_percentage[i] = (swizzle_count[i]*100)/total_opcode_count
        scalar_percentage[i] = (scalar_count[i]*100)/total_opcode_count
    return(swizzle_count, swizzle_percentage, scalar_count, scalar_percentage)

import re

swizzle_count = [0,0,0]
scalar_count = [0,0,0]
swizzle_percentage = [0,0,0]
scalar_percentage = [0,0,0]
#swizzle_count, swizzle_percentage, scalar_count, scalar_percentage = swizzle_count_estimator('Manhattan_Stat_Files/ogles_gfxbench3-0-6_ab-manhattan-1920x1080__and-cht-v2_f00087_ci-main-66088-ptbr-on.stat')
swizzle_count, swizzle_percentage, scalar_count, scalar_percentage = swizzle_count_estimator('Manhattan_Stat_Files/GcaGemmBench_SGEMM_media_block_rw_b_rm_32x2_x86_tgllp_2018-06-05_ci-main-70858_1_1024.aub.gz.stat')


#Swizzle detector framework

import re

#Swizzle count detector function
def swizzle_count_estimator(file):
    #Read the file 
    with open(file,"r") as f:
        gSimFile = f.readlines()
    lines = []    # all the line results 
    pattern = []
    swizzle_count = [0, 0, 0]
    scalar_count  = [0, 0, 0]
    total_opcode_count = 0
    opcode_expr = r"\w+\s+\(\d+\)"
    for line in gSimFile:  # go over each line
        oneLine = []       # matches for one line 
        swizzle_flag = 0   # Reset the flag to detect swizzle in next line
        if re.search(opcode_expr, line):
           #Estimate the opcode count
           opcode_count = instr_count(line)
           total_opcode_count += opcode_count
           #Detect and analyze all the <VS; W, HS> patterns and look for swizzle or Scalar
           index = 0
           for m in re.findall("<(\d+); ?(\d+),(\d+)>", line):  # find all patterns
                index += 1
                # convert to int
                pattern = [int(x) for x in m] #convert to integer
                #Any regioning that is not flat involves a swizzle
                if pattern[0] != pattern[1]*pattern[2] and (pattern != [1,1,0] ):
                    swizzle_flag = 1
                    swizzle_count[index-1] += opcode_count
                #Scalar case as well
                if pattern == [0,1,0]:
                    scalar_count[index-1] += opcode_count
                oneLine.extend(map(int,m))
        
        #Detect and analyze all the <VS; HS> patterns and look for swizzle or Scalar
        #for m in re.findall("<(\d+); ?(\d+)>", line):  # find all patterns
        #    pattern = [int(x) for x in m]
            #Any regioning that is not flat involves a swizzle
        #    if pattern[0] != 8 or pattern[1] != 1:
        #        swizzle_flag = 1
        #    oneLine.extend(map(int,m))
        #Detect and analyze all the <W> patterns and look for swizzle or Scalar
        #for m in re.findall("<(\d)>", line):  # find all patterns
        #    pattern = [int(x) for x in m]
            #Any regioning that is not flat involves a swizzle
        #    if pattern[0] != 1:
        #        swizzle_flag = 1
        #    oneLine.extend(map(int,m))                       # convert to int, extend oneLine
        #if swizzle_flag:
        #   swizzle_count += 1
        #   lines.append(oneLine) #Collect all the lines that have swizzle
    #Estimate the swizzle percentage
    for i in range(0,2):
        swizzle_percentage[i] = (swizzle_count[i]*100)/total_opcode_count
        scalar_percentage[i] = (scalar_count[i]*100)/total_opcode_count
    print(scalar_count)
    print(swizzle_count)
    return(swizzle_count,swizzle_percentage, scalar_count, scalar_percentage)



swizzle_count = [0,0,0]
scalar_count = [0,0,0]
swizzle_percentage = [0,0,0]
scalar_percentage = [0,0,0]
#swizzle_count, swizzle_percentage, scalar_count, scalar_percentage = swizzle_count_estimator('Manhattan_Stat_Files/ogles_gfxbench3-0-6_ab-manhattan-1920x1080__and-cht-v2_f00087_ci-main-66088-ptbr-on.stat')
swizzle_count, swizzle_percentage, scalar_count, scalar_percentage = swizzle_count_estimator('Manhattan_Stat_Files/GcaGemmBench_SGEMM_media_block_rw_b_rm_32x2_x86_tgllp_2018-06-05_ci-main-70858_1_1024.aub.gz.stat')





   
import re    
file = open('Instr_snapshot_test.txt','r')

text = file.readlines()

num_lines = 0
lind = 0    
for line in text:
    di, dst_pattern =  stride_pattern_extractor(line, 2)
    print(di)
    print(dst_pattern)