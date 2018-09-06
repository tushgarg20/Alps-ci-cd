file = open('Manhattan_Stat_Files/GcaGemmBench_SGEMM_media_block_rw_b_rm_32x2_x86_tgllp_2018-06-05_ci-main-70858_1_1024.aub.gz.stat','r')

text = file.readlines()
di = {}

for num in range(1,len(text)-1):
    di[num] = {}

lind = 0
for line in range(len(text)):
    lind += 1
    if '<' in text[line]:
        flag = False
        l = text[line].replace('>','<').split('<')
        for position in range(1,len(l),2):
            vals = l[position].replace(';',',').split(',')
            for digit in '0123456789':
                if digit in vals:
                    flag = True
            if flag:
                di[lind][(position+1)//2] = l[position].replace(';',',').split(',')
    else:
        di[lind] = {}
    line = file.readline()
    

lines_with_nums = []  #List of lines with numerical values
for i in range(1,len(di)+1):
    if di[i]:
        lines_with_nums.append(i)
        
print(lines_with_nums)

file = 'Manhattan_Stat_Files/ogles_gfxbench3-0-6_ab-manhattan-1920x1080__and-cht-v2_f00087_ci-main-66088-ptbr-on.stat'
import gzip
with open(file, 'r') as f:
    file_content = f.read()
decompressedFile = gzip.GzipFile(fileobj=file)
type(file_content)
