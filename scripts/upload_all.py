from optparse_ext import OptionParser
import os

###############################################
# Command Line Arguments
###############################################
parser = OptionParser()
parser.add_option("-i","--input",dest="input_file",
                  help="Input Tracelist")
parser.add_option("-t","--tool",dest="tool",default='Gsim Indigo',
                  help="Name of simulator used")
parser.add_option("--tool_config",dest="tool_config",
                  help="Gsim Config used")
parser.add_option("--gsim_tag",dest="gsim_tag",
                  help="GIT Repository Tag for the simulator")
parser.add_option("--alps_tag",dest="alps_tag",
                  help="GIT Repository Tag for the ALPS Model")
parser.add_option("-c","--config",dest="config",
                  help="Config")
parser.add_option("-s","--sku",dest="sku",
                  help="SKU")
parser.add_option("-u","--user",dest="user",
                  help="Userid")
parser.add_option("-v","--version",dest="version",
                  help="Version you want to provide")

(options,args) = parser.parse_args()

def get_data(line,separator):
    res = line.split(separator)
    i = 0
    while(i < len(res)):
        res[i] = res[i].strip()
        i = i+1
    return res

tf = open(options.input_file,'r')
for line in tf:
    data = get_data(line,",")
    api,title,setting,frame,capture,driver,file = data
    scripts_dir = os.path.abspath(os.path.dirname(__file__))
    upload_cmd = ("python " + scripts_dir +"/upload_alps.py -i " + file + " -t '" + options.tool + "' --tool_config '" + options.tool_config +
                  "' --gsim_tag '" + options.gsim_tag + "' --alps_tag '" + options.alps_tag + "' -c '" + options.config + "' -s '" + options.sku +
                  "' -u '" + options.user + "' -v '" + options.version +
                  "' --api '" + api + "' --title '" + title + "' --setting '" + setting +
                  "' --frame '" + frame + "' --capture '" + capture + "' --driver '" + driver + "'"
                  )
    os.system(upload_cmd)
    #print(upload_cmd)
    print("Uploaded {0} {1} {2} {3} {4} {5}".format(api,title,setting,frame,capture,driver))

tf.close()
    


