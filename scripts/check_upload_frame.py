import mysql.connector
import yaml
import time
import re
from optparse_ext import OptionParser

## --------------------------------------------------------------------------------
## command line argument
## --------------------------------------------------------------------------------
parser = OptionParser()
parser.add_option("-i","--input",   dest="input_file", help="Input ALPS Model")
parser.add_option(     "--gsim_tag",dest="gsim_tag",   help="GIT Repository Tag for the simulator")
parser.add_option(     "--alps_tag",dest="alps_tag",   help="GIT Repository Tag for the ALPS Model")
parser.add_option("-c","--config",  dest="config",     help="Config")
parser.add_option("-s","--sku",     dest="sku",        help="SKU")
parser.add_option("-u","--user",    dest="user",       help="Userid")
parser.add_option("-v","--version", dest="version",    help="Version you want to provide")
parser.add_option(     "--api",     dest="api",        help="Workload belongs to which api")
parser.add_option(     "--title",   dest="title",      help="Workload Title")
parser.add_option(     "--setting", dest="setting",    help="Frame belongs to which setting. perf,entry,i3,i5 etc")
parser.add_option(     "--frame",   dest="frame",      help="Frame number")
parser.add_option(     "--capture", dest="capture",    help="Gfxbench details")
parser.add_option(     "--driver",  dest="driver",     help="Driver used for capturing the aub file")

(options,args) = parser.parse_args()

## --------------------------------------------------------------------------------
## global variables
## --------------------------------------------------------------------------------
paths = []
cluster_id = {}
unit_id = {}
numTables = 4
frames = {}

options.user = 'alps'
toolid = 0
time_start = time.time()

pdb_config = {
    'host': "gama.iind.intel.com",
    'port': "3307",
    'user':  "gama_adm",
    'passwd': "gama@dm1N",
    'db': "newpowerdb"
}
pcnx    = mysql.connector.connect(**pdb_config)
pcursor = pcnx.cursor()

## --------------------------------------------------------------------------------
## main
## --------------------------------------------------------------------------------
def main():

    get_list_of_valid_frames()
    list_of_frames = sorted(frames.keys())
    for key in list_of_frames:
        (api,title,setting,capture,framenum) = key.split("=")
        if (key.find("t-rex") > -1):
            # print (key)
            pass

    tf = open(options.input_file,'r')
    time_last = time.time()
    for line in tf:
        data = get_data(line,",")
        (api,title,setting,frame,capture,driver,file) = data

        time_now    = time.time()
        time_elapse = time_now - time_last
        time_last   = time_now
        framenum    = int(frame)
        idx = api+"="+title+"="+setting+"="+capture+"="+str(framenum)
        if (idx in frames):
            if (driver in frames[idx]):
                pass
            else:
                print ("new driver of %s: %s" % (idx, driver))
        else:
            print ("missing %-10s %-40s %-35s %-20s %-30s %5d" % (api, title, setting, capture, driver, int(framenum)))

## --------------------------------------------------------------------------------
## subroutines
## --------------------------------------------------------------------------------

def get_list_of_valid_frames():
    query = ("SELECT api,title,setting,capture,framenum,aubtag " +
             "FROM aubtbl INNER JOIN archrast.frames on frames.frameid = aubtbl.frameid")
    pcursor.execute(query)
    result = pcursor.fetchall()
    if (len(result) == 0):
        print ("somthing wrong; no frames returned")
        return -1
    print ("list of "+ str(len(result)) + " frames")
    for i in range(len(result)):
        api      = result[i][0]
        title    = result[i][1]
        setting  = result[i][2]
        capture  = result[i][3]
        framenum = str(result[i][4])
        driver   = result[i][5]
        idx      = api+"="+title+"="+setting+"="+capture+"="+framenum
        if (idx in frames):
            pass
        else:
            frames[idx] = {}
        frames[idx][driver] = 1
    return    

def check_frame(api, title, setting, capture, frame, driver):
    return

def get_data(line,separator):
    res = line.split(separator)
    i = 0
    while(i < len(res)):
        res[i] = res[i].strip()
        i = i+1
    return res

## --------------------------------------------------------------------------------
## call the main
## --------------------------------------------------------------------------------
main();
