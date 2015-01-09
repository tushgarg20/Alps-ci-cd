from lib.optparse_ext import OptionParser
import re
import os
import sys
import shlex
import subprocess
import lib.yaml as yaml

#############################
# Command Line Arguments
#############################

parser = OptionParser()
parser.add_option("-i","--input",dest="input_dir",
                  help="Input Directory where all frame residency files are present")
parser.add_option("-t","--tracelist",dest="tracefile",
                  help="Path to file containing list of residency files")
parser.add_option("-o","--output",dest="output_dir",
                  help="Output directory where you want to dump workload residency files and ALPS Models")
parser.add_option("-s","--script",dest="script_dir",
                  help="Path to ALPS repository you want to use")
parser.add_option("-a","--architecture",dest="dest_config",
                  help="Specify Gsim Config used for run. For e.g. bdw_gt2.cfg")
parser.add_option("-c","--cfg",dest="alps_config", default=None,
                  help="Path to ALPS Config File (alps_cfg.yaml) [default: %default]")
parser.add_option("-w","--weights",dest="weights",
                  help="CSV file containing frame weights")
parser.add_option("--debug",action="store_true",dest="run_debug",default=False,
                  help="Run build_alps in debug mode [default: %default]")

(options,args) = parser.parse_args()

#######################################
# Global Variables
#######################################
sd = options.script_dir
filename = ''
od = options.output_dir
wl_hash = {}
weights_hash = {}


#######################################
# Parsing ALPS CFG File
#######################################
if options.alps_config is not None:
    filename = options.alps_config
else:
    if options.dest_config.find('bdw') > -1 or  options.dest_config.find('chv') > -1:
        filename = '%s/alps_cfg_annealing.yaml' % sd
    elif options.dest_config.find('icl') > -1:
        filename = '%s/alps_cfg_icl.yaml' % sd
    else:
        filename = '%s/alps_cfg.yaml' % sd

f = open(os.path.abspath(filename),'r')
cfg_data = yaml.load(f)
f.close()

input_file = sd + '/' + cfg_data['ALPS Input File'][0]
arch = options.dest_config

########################################
# Subroutines
########################################
def get_data(line,separator):
  res = line.split(separator)
  i = 0
  while(i < len(res)):
    res[i] = res[i].strip()
    i = i + 1
  return res

########################################
# Parsing Tracelist
########################################
try:
  tf = open(os.path.abspath(options.tracefile),'r')
except IOError:
  print("Can't open", options.tracefile)
  exit(10000)

for line in tf:
  line = line.strip()
  matchObj = re.search('(.*)_f(\d+)_(.*)res.csv',line)
  frame = int(matchObj.group(2))
  wl = matchObj.group(1) + '_' + matchObj.group(3)
  if(wl[-1] == '.' or wl[-1] == '_'):
    wl = wl[:-1]
  if(wl not in wl_hash):
    wl_hash[wl] = {}
  if(frame not in wl_hash[wl]):
    wl_hash[wl][frame] = {}
  wl_hash[wl][frame]['res_file'] = line

tf.close()

#########################################
# Reading Ref Frames Weights
#########################################
try:
  wf = open(os.path.abspath(options.weights),'r')
except IOError:
  print("Can't open",options.weight,'file')
  exit(10000)

for line in wf:
  data = get_data(line,',')
  matchObj = re.search('(.*)_f(\d+)_(.*)res.csv',data[0])
  frame = int(matchObj.group(2))
  wl = matchObj.group(1) + '_' + matchObj.group(3)
  if(wl[-1] == '.' or wl[-1] == '_'):
    wl = wl[:-1]
  if(wl not in weights_hash):
    weights_hash[wl] = {}
  if(frame not in weights_hash[wl]):
    weights_hash[wl][frame] = {}
  if(len(data) < 2):
    weights_hash[wl][frame]['weight'] = 0
  else:
    try:
      weights_hash[wl][frame]['weight'] = float(data[1])
    except ValueError:
      print("Weight is missing for", line)
      weights_hash[wl][frame]['weight'] = 0

wf.close()

########################################
# Creating WL Residency and ALPS Model
########################################
keys = list(wl_hash.keys())

for i in range(len(keys)):
  wl = keys[i]
  frames = list(wl_hash[wl].keys())
  stats_hash = {}
  stats_order = []
  for j in range(len(frames)):
    frame = frames[j]
    try:
      res_file = open(os.path.abspath(options.input_dir+'/'+wl_hash[wl][frame]['res_file']),'r')
    except IOError:
      print("Can't open",wl_hash[wl][frame]['res_file'])
      exit(10000)
    if(wl not in stats_hash):
      stats_hash[wl] = {}
    if(frame not in stats_hash[wl]):
      stats_hash[wl][frame] = {}
    for line in res_file:
      data = get_data(line,',')
      if(len(data) == 0):
        continue
      if(j == 0):
        stats_order = stats_order + [data[0]]
      if(len(data) == 1):
        stats_hash[wl][frame][data[0]] = 0
      else:
        try:
          value = float(data[1])
        except ValueError:
          value = 0
        stats_hash[wl][frame][data[0]] = value

  #############################################
  # Individual Res files have been read
  # Now generate workload level residencies
  #############################################
  try:
    out_file = open(os.path.abspath(od + '/' + wl + '.res.csv'),'w')
  except IOError:
    print("Can't open output file for",wl)
    exit(10000)
  for k in range(len(stats_order)):
    stat = stats_order[k]
    wl_value = 0
    sum_of_weights = 0
    for l in range(len(frames)):
      frame = frames[l]
      sum_of_weights += weights_hash[wl][frame]['weight']
      wl_value += stats_hash[wl][frame][stat] * weights_hash[wl][frame]['weight']
    if(sum_of_weights <= 0):
      wl_value = 0
    else:
      wl_value = wl_value/sum_of_weights
    print('{0},{1}'.format(stat,wl_value), file=out_file)
  out_file.close()

  build_alps_script = sd + '/' + 'build_alps.py'
  build_alps_cmd = ['/usr/intel/pkgs/python/3.1.2/bin/python',build_alps_script]
  res_file = od + '/' + wl + '.res.csv'
  alps_file = od + '/' + wl + '.yaml'
  build_alps_cmd += ['-i',input_file,'-a',arch,'-r',res_file,'-o',alps_file]
  if options.run_debug:
    build_alps_cmd += ['--debug']

  try:
    process = subprocess.Popen(build_alps_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=False)
    output = process.communicate()[0]
    ExitCode = process.wait()
  except Exception:
    ExitCode = 10000
    print("Error: Can't open subprocess for build_alps")
  if(ExitCode>1):
    exit(ExitCode)

####################################
# End of Script
####################################


