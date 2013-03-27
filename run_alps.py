from optparse import OptionParser
import shlex 
import subprocess


#############################
# Command Line Arguments
#############################
##def files_callback(option,opt,value,parser):
##    setattr(parser.values,option.dest,value.split(" "))

parser = OptionParser()
parser.add_option("-w","--workload",action="store",dest="wl_name", default=None,
                  help="workload name [default: %default] ")
parser.add_option("-p","--prefix",dest="prefix", default=None,
                  help="OutFilePrefix used to run gsim [default: %default]")
parser.add_option("-o","--output-dir",dest="output_dir",default=None,
                  help="Path to the output directory where stat exists [default: %default]")
parser.add_option("-a","--architecture",action="store", dest="dest_config", default=None,
                  help="Specify Gsim Config used for run. For e.g. bdw_gt2.cfg [default: %default]")

(options,args) = parser.parse_args()

print options.wl_name
print options.prefix
print options.output_dir
print options.dest_config

res = options.output_dir + '/' + options.wl_name + '_res.csv'
log = options.output_dir + '/' + options.wl_name + '_res_log.txt'
stat = options.output_dir + '/' + options.prefix + '.stat'
yaml = options.output_dir + '/' + 'alps_' + options.wl_name + '.yaml'

read_stats_cmd = ['/p/gat/tools/gsim_alps/ReadStats.pl','-csv','-o', res, '-e', log, stat, '/p/gat/tools/gsim_alps/Inputs/eu_stats2res_formula.txt', '/p/gat/tools/gsim_alps/Inputs/l3_stat2res_formula.txt', '/p/gat/tools/gsim_alps/Inputs/gti_stat2res_formula.txt']

build_alps_cmd = ['/usr/intel/pkgs/python/2.5/bin/python', '/p/gat/tools/gsim_alps/build_alps.py', '-i', '/p/gat/tools/gsim_alps/inputs.txt', '-r', res, '-a', options.dest_config, '-o', yaml ]

try:
    process = subprocess.Popen(read_stats_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=False)
    output = process.communicate()[0]
    print output
    ExitCode = process.wait()
except Exception:
    print 'Error: Read_stats failed to open subprocess'

if ExitCode > 1:
    print "ReadStats failed with exitcode : ", ExitCode 
    exit(ExitCode) 

try:
    process = subprocess.Popen(build_alps_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=False)
    output = process.communicate()[0]
    ExitCode = process.wait()
    print output
except Exception:
    print 'Error: build_alps failed to open subprocess' 

if ExitCode > 1:
    print "build_alps failed with exitcode : ", ExitCode 
    exit(ExitCode) 
