from lib.optparse_ext import OptionParser
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
parser.add_option("-p","--prefix",dest="prefix", default='psim',
                  help="OutFilePrefix used to run gsim [default: %default]")
parser.add_option("-o","--output-dir",dest="output_dir",default=None,
                  help="Path to the output directory where stat exists [default: %default]")
parser.add_option("-i","--input",dest="input", default='/p/gat/tools/gsim_alps/inputs.txt',
                  help="Path to inputs.txt [default: %default]")
parser.add_option("-f","--formula",dest="formula", default='formula.txt',
                  help="List all formulae to use seperated by space Format: \"<path_to_formula> <path_to_formula>...\"   [default: Formulae from central repo]")
parser.add_option("-l","--local",action="store_true",dest="run_local",default=False,
                  help="Run users scripts from user_dir [default: %default]")
parser.add_option("-b","--only-build-alps",action="store_true",dest="build_alps_only",default=False,
                  help="Run users scripts from current path [default: %default]")
parser.add_option("-a","--architecture",action="store", dest="dest_config", default=None,
                  help="Specify Gsim Config used for run. For e.g. bdw_gt2.cfg or just specify the three letter acronym For E.g. BDW, SKL, CNL, BXT [default: %default]")
parser.add_option("-d","--dir",action="store", dest="user_dir", default='.',
                  help=" user_dir where stat2res and build_alps scripts exist ( only used when --local is enabled) [default: %default]")

(options,args) = parser.parse_args()

print ("Building Alps model \n")
print (options.wl_name)
print (options.output_dir)
print (options.dest_config)

res = options.output_dir + '/' + options.wl_name + '_res.csv'
log = options.output_dir + '/' + options.wl_name + '_res_log.txt'
stat = options.output_dir + '/' + options.prefix + '.stat'
yaml = options.output_dir + '/' + 'alps_' + options.wl_name + '.yaml'

if not options.run_local:
    read_stats_cmd = ['/p/gat/tools/gsim_alps/ReadStats.pl','-csv','-o', res, '-e', log, stat]
    if options.formula == 'formula.txt':
        read_stats_cmd += ['/p/gat/tools/gsim_alps/Inputs/eu_stat2res_formula.txt', '/p/gat/tools/gsim_alps/Inputs/l3_stat2res_formula.txt', '/p/gat/tools/gsim_alps/Inputs/gti_stat2res_formula.txt', '/p/gat/tools/gsim_alps/Inputs/sampler_stat2res_formula.txt']
    else:
        for line in options.formula.split():
            read_stats_cmd += [ line ]
    build_alps_cmd = ['/usr/intel/pkgs/python/3.1.2/bin/python', '/p/gat/tools/gsim_alps/build_alps.py', '-i', '/p/gat/tools/gsim_alps/inputs.txt', '-r', res, '-a', options.dest_config, '-o', yaml ]

else:
    read_stats_script = options.user_dir + '/ReadStats.pl'
    build_alps_script = options.user_dir + '/build_alps.py'
    read_stats_cmd = [read_stats_script,'-csv','-o', res, '-e', log, stat]
    if options.formula != 'formula.txt':
        for line in options.formula.split():
            read_stats_cmd += [ line ]
    else:
        read_stats_cmd += ['/p/gat/tools/gsim_alps/Inputs/eu_stat2res_formula.txt', '/p/gat/tools/gsim_alps/Inputs/l3_stat2res_formula.txt', '/p/gat/tools/gsim_alps/Inputs/gti_stat2res_formula.txt', '/p/gat/tools/gsim_alps/Inputs/sampler_stat2res_formula.txt']

    build_alps_cmd = ['/usr/intel/pkgs/python/3.1.2/bin/python', build_alps_script, '-i', options.input, '-r', res, '-a', options.dest_config, '-o', yaml ]

if not options.build_alps_only:
    try:
        process = subprocess.Popen(read_stats_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=False)
        output = process.communicate()[0]
        #print (output)
        ExitCode = process.wait()
    except Exception:
        print ('Error: Read_stats failed to open subprocess')

    if ExitCode > 1:
        print ("ReadStats failed with exitcode : ", ExitCode)
        exit(ExitCode) 

try:
    process = subprocess.Popen(build_alps_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=False)
    output = process.communicate()[0]
    ExitCode = process.wait()
    #print (output)
except Exception:
    print ('Error: build_alps failed to open subprocess')

if ExitCode > 1:
    print ("build_alps failed with exitcode : ", ExitCode) 
    exit(ExitCode) 
