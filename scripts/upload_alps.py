import mysql.connector
import yaml
from optparse_ext import OptionParser

###############################################
# Command Line Arguments
###############################################
parser = OptionParser()
parser.add_option("-i","--input",dest="input_file",
                  help="Input ALPS Model")
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
parser.add_option("--api",dest="api",
                  help="Workload belongs to which api")
parser.add_option("--title",dest="title",
                  help="Workload Title")
parser.add_option("--setting",dest="setting",
                  help="Frame belongs to which setting. perf,entry,i3,i5 etc")
parser.add_option("--frame",dest="frame",
                  help="Frame number")
parser.add_option("--capture",dest="capture",
                  help="Gfxbench details")
parser.add_option("--driver",dest="driver",
                  help="Driver used for capturing the aub file")

(options,args) = parser.parse_args()

##############################################
# Global Variables
##############################################
paths = []
cluster_id = {}
unit_id = {}

##############################################
# Subroutines
##############################################
def dfs(adict, path=[]):
    if(type(adict) is not dict):
        path.append(adict)
        paths.append(path + [])
        path.pop()
        return
    for key in adict:
        path.append(key)
        dfs(adict[key],path)
        if(path):
            path.pop()
    return

def get_config_id(config,sku):
        query = "SELECT id from archtbl WHERE config='"+config+"' AND sku='"+sku+"'"
        #print (query)
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query = "INSERT INTO archtbl (config,sku) values ('"+config+"','"+sku+"')"
                #print (query)
                pcursor.execute(query)
                pcnx.commit()
                query = "SELECT id FROM archtbl WHERE config='"+config+"' AND sku='"+sku+"'"
                pcursor.execute(query)
                result = pcursor.fetchall()
                return result[0][0]
        else:
                return result[0][0]

def get_frame_id(api,title,setting,capture,frame):
        query = ("SELECT frameid FROM frames WHERE "
                 "api='" + api + "' AND "
                 "title='" + title + "' AND "
                 "setting='" + setting + "' AND "
                 "capture='" + capture + "' AND "
                 "framenum='" + str(frame) + "'"
                 )
        #print(query)
        acursor.execute(query)
        result = acursor.fetchall()
        if(len(result) == 0):
                query = ("INSERT INTO frames "
                         "(api,title,setting,capture,framenum) "
                         "values (%s, %s, %s, %s, %s)"
                         )
                data = (api,title,setting,capture,frame)
                acursor.execute(query,data)
                acnx.commit()
                query = ("SELECT frameid FROM frames WHERE "
                 "api='" + api + "' AND "
                 "title='" + title + "' AND "
                 "setting='" + setting + "' AND "
                 "capture='" + capture + "' AND "
                 "framenum='" + str(frame) + "'"
                 )
                acursor.execute(query)
                result = acursor.fetchall()
                return result[0][0]
        else:
                return result[0][0]

def get_aub_id(frameid,driver):
        query = "SELECT id from aubtbl WHERE frameid='"+str(frameid)+"' AND aubtag='"+driver+"'"
        #print (query)
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query = "INSERT INTO aubtbl (frameid,aubtag) values ('"+str(frameid)+"','"+driver+"')"
                #print (query)
                pcursor.execute(query)
                pcnx.commit()
                query = "SELECT id from aubtbl WHERE frameid='"+str(frameid)+"' AND aubtag='"+driver+"'"
                pcursor.execute(query)
                result = pcursor.fetchall()
                return result[0][0]
        else:
                return result[0][0]

def get_tool_id(tool,gsim_tag,config):
        query = ("SELECT id FROM tooltbl WHERE "
                 "tool='" + tool + "' AND "
                 "gsim_tag='" + gsim_tag + "' AND "
                 "config='" + config + "'"
                 )
        #print(query)
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query = ("INSERT INTO tooltbl "
                         "(tool,gsim_tag,config) "
                         "values (%s, %s, %s)"
                         )
                data = (tool,gsim_tag,config)
                pcursor.execute(query,data)
                pcnx.commit()
                query = ("SELECT id FROM tooltbl WHERE "
                 "tool='" + tool + "' AND "
                 "gsim_tag='" + gsim_tag + "' AND "
                 "config='" + config + "'"
                 )
                pcursor.execute(query)
                result = pcursor.fetchall()
                return result[0][0]
        else:
                return result[0][0]

def get_cluster_id(cluster):
        query = "SELECT id FROM cluster WHERE cluster_name='" + cluster + "'"
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query = "INSERT INTO cluster (cluster_name) values ('" + cluster + "')"
                pcursor.execute(query)
                pcnx.commit()
                query = "SELECT id FROM cluster WHERE cluster_name='" + cluster + "'"
                pcursor.execute(query)
                result = pcursor.fetchall()
                return result[0][0]
        else:
                return result[0][0]

def get_unit_id(unit):
        query = "SELECT id FROM unit WHERE unit_name='" + unit + "'"
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query = "INSERT INTO unit (unit_name) values ('" + unit + "')"
                pcursor.execute(query)
                pcnx.commit()
                query = "SELECT id FROM unit WHERE unit_name='" + unit + "'"
                pcursor.execute(query)
                result = pcursor.fetchall()
                return result[0][0]
        else:
                return result[0][0]

def get_stat_id(stat):
        query = "SELECT id FROM stats WHERE stat_name='" + stat + "'"
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query = "INSERT INTO stats (stat_name) values ('" + stat + "')"
                pcursor.execute(query)
                pcnx.commit()
                query = "SELECT id FROM stats WHERE stat_name='" + stat + "'"
                pcursor.execute(query)
                result = pcursor.fetchall()
                return result[0][0]
        else:
                return result[0][0]

def insert_alps_numbers(aubid,toolid,configid,user,gsim_tag,alps_tag,version,clusterid,unitid,statid,value):
        query = ("SELECT id FROM alps_results_0 WHERE "
                 "aubid='" + str(aubid) + "' AND "
                 "toolid='" + str(toolid) + "' AND "
                 "archid='" + str(configid) + "' AND "
                 "user='" + user + "' AND "
                 "gsim_tag='" + gsim_tag + "' AND "
                 "alps_tag='" + alps_tag + "' AND "
                 "version='" + version + "' AND "
                 "clusterid='" + str(clusterid) + "' AND "
                 "unitid='" + str(unitid) + "' AND "
                 "statid='" + str(statid) + "'"
                 )
        #print(query)
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query =("INSERT INTO alps_results_0 "
                        "(aubid,toolid,archid,user,gsim_tag,alps_tag,version,clusterid,unitid,statid,value) "
                        "values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"
                        )
                data = (aubid,toolid,configid,user,gsim_tag,alps_tag,version,clusterid,unitid,statid,value)
                pcursor.execute(query, data)
                pcnx.commit()
        else:
                resultid = result[0][0]
                query = ("UPDATE alps_results_0 SET "
                         "aubid='" + str(aubid) + "',"
                         "toolid='" + str(toolid) + "',"
                         "archid='" + str(configid) + "', "
                         "user='" + user + "', "
                         "gsim_tag='" + gsim_tag + "', "
                         "alps_tag='" + alps_tag + "', "
                         "version='" + version + "', "
                         "clusterid='" + str(clusterid) + "', "
                         "unitid='" + str(unitid) + "', "
                         "statid='" + str(statid) + "', "
                         "value='" + str(value) + "' "
                         "WHERE id='" + str(resultid) + "'"
                         )
                pcursor.execute(query)
                pcnx.commit()

def insert_overview_numbers(aubid,toolid,configid,user,gsim_tag,alps_tag,version,fps,total_gt_cdyn,total_gt_cdyn_syn,total_gt_cdyn_ebb):
        query = ("SELECT id FROM overview WHERE "
                 "aubid='" + str(aubid) + "' AND "
                 "toolid='" + str(toolid) + "' AND "
                 "archid='" + str(configid) + "' AND "
                 "user='" + user + "' AND "
                 "gsim_tag='" + gsim_tag + "' AND "
                 "alps_tag='" + alps_tag + "' AND "
                 "version='" + version + "'"
                 )
        #print(query)
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query =("INSERT INTO overview "
                        "(aubid,toolid,archid,user,gsim_tag,alps_tag,version,FPS,Total_GT_Cdyn,Total_GT_Cdyn_syn,Total_GT_Cdyn_ebb) "
                        "values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"
                        )
                data = (aubid,toolid,configid,user,gsim_tag,alps_tag,version,fps,total_gt_cdyn,total_gt_cdyn_syn,total_gt_cdyn_ebb)
                pcursor.execute(query, data)
                pcnx.commit()
        else:
                resultid = result[0][0]
                query = ("UPDATE overview SET "
                         "aubid='" + str(aubid) + "',"
                         "toolid='" + str(toolid) + "',"
                         "archid='" + str(configid) + "', "
                         "user='" + user + "', "
                         "gsim_tag='" + gsim_tag + "', "
                         "alps_tag='" + alps_tag + "', "
                         "version='" + version + "', "
                         "FPS='" + str(fps) + "', "
                         "Total_GT_Cdyn='" + str(total_gt_cdyn) + "', "
                         "Total_GT_Cdyn_syn='" + str(total_gt_cdyn_syn) + "', "
                         "Total_GT_Cdyn_ebb='" + str(total_gt_cdyn_ebb) + "' "
                         "WHERE id='" + str(resultid) + "'"
                         )
                pcursor.execute(query)
                pcnx.commit()

def insert_key_stats(aubid,toolid,configid,user,gsim_tag,alps_tag,version,statid,value):
        query = ("SELECT id FROM keystatstbl WHERE "
                 "aubid='" + str(aubid) + "' AND "
                 "toolid='" + str(toolid) + "' AND "
                 "archid='" + str(configid) + "' AND "
                 "user='" + user + "' AND "
                 "gsim_tag='" + gsim_tag + "' AND "
                 "alps_tag='" + alps_tag + "' AND "
                 "version='" + version + "' AND "
                 "statid='" + str(statid) + "'"
                 )
        #print(query)
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query =("INSERT INTO keystatstbl "
                        "(aubid,toolid,archid,user,gsim_tag,alps_tag,version,statid,value) "
                        "values (%s, %s, %s, %s, %s, %s, %s, %s, %s)"
                        )
                data = (aubid,toolid,configid,user,gsim_tag,alps_tag,version,statid,value)
                pcursor.execute(query, data)
                pcnx.commit()
        else:
                resultid = result[0][0]
                query = ("UPDATE keystatstbl SET "
                         "aubid='" + str(aubid) + "',"
                         "toolid='" + str(toolid) + "',"
                         "archid='" + str(configid) + "', "
                         "user='" + user + "', "
                         "gsim_tag='" + gsim_tag + "', "
                         "alps_tag='" + alps_tag + "', "
                         "version='" + version + "', "
                         "statid='" + str(statid) + "', "
                         "value='" + str(value) + "' "
                         "WHERE id='" + str(resultid) + "'"
                         )
                pcursor.execute(query)
                pcnx.commit()

def insert_cluster_numbers(aubid,toolid,configid,user,gsim_tag,alps_tag,version,clusterid,value,value_syn,value_ebb):
        query = ("SELECT id FROM cluster_numbers WHERE "
                 "aubid='" + str(aubid) + "' AND "
                 "toolid='" + str(toolid) + "' AND "
                 "archid='" + str(configid) + "' AND "
                 "user='" + user + "' AND "
                 "gsim_tag='" + gsim_tag + "' AND "
                 "alps_tag='" + alps_tag + "' AND "
                 "version='" + version + "' AND "
                 "clusterid='" + str(clusterid) + "'"
                 )
        #print(query)
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query =("INSERT INTO cluster_numbers "
                        "(aubid,toolid,archid,user,gsim_tag,alps_tag,version,clusterid,value,value_syn,value_ebb) "
                        "values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"
                        )
                data = (aubid,toolid,configid,user,gsim_tag,alps_tag,version,clusterid,value,value_syn,value_ebb)
                pcursor.execute(query, data)
                pcnx.commit()
        else:
                resultid = result[0][0]
                query = ("UPDATE cluster_numbers SET "
                         "aubid='" + str(aubid) + "',"
                         "toolid='" + str(toolid) + "',"
                         "archid='" + str(configid) + "', "
                         "user='" + user + "', "
                         "gsim_tag='" + gsim_tag + "', "
                         "alps_tag='" + alps_tag + "', "
                         "version='" + version + "', "
                         "clusterid='" + str(clusterid) + "', "
                         "value='" + str(value) + "', "
                         "value_syn='" + str(value_syn) + "', "
                         "value_ebb='" + str(value_ebb) + "' "
                         "WHERE id='" + str(resultid) + "'"
                         )
                pcursor.execute(query)
                pcnx.commit()

def insert_unit_numbers(aubid,toolid,configid,user,gsim_tag,alps_tag,version,clusterid,unitid,value):
        query = ("SELECT id FROM unit_numbers WHERE "
                 "aubid='" + str(aubid) + "' AND "
                 "toolid='" + str(toolid) + "' AND "
                 "archid='" + str(configid) + "' AND "
                 "user='" + user + "' AND "
                 "gsim_tag='" + gsim_tag + "' AND "
                 "alps_tag='" + alps_tag + "' AND "
                 "version='" + version + "' AND "
                 "clusterid='" + str(clusterid) + "' AND "
                 "unitid='" + str(unitid) + "'"
                 )
        #print(query)
        pcursor.execute(query)
        result = pcursor.fetchall()
        if(len(result) == 0):
                query =("INSERT INTO unit_numbers "
                        "(aubid,toolid,archid,user,gsim_tag,alps_tag,version,clusterid,unitid,value) "
                        "values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"
                        )
                data = (aubid,toolid,configid,user,gsim_tag,alps_tag,version,clusterid,unitid,value)
                pcursor.execute(query, data)
                pcnx.commit()
        else:
                resultid = result[0][0]
                query = ("UPDATE unit_numbers SET "
                         "aubid='" + str(aubid) + "',"
                         "toolid='" + str(toolid) + "',"
                         "archid='" + str(configid) + "', "
                         "user='" + user + "', "
                         "gsim_tag='" + gsim_tag + "', "
                         "alps_tag='" + alps_tag + "', "
                         "version='" + version + "', "
                         "clusterid='" + str(clusterid) + "', "
                         "unitid='" + str(unitid) + "', "
                         "value='" + str(value) + "' "
                         "WHERE id='" + str(resultid) + "'"
                         )
                pcursor.execute(query)
                pcnx.commit()

###############################################
# Parsing Input ALPS Model
###############################################
af = open(options.input_file,'r')
yaml_data = yaml.load(af)
af.close()
dfs(yaml_data['ALPS Model(pF)'])
##for path in paths:
##        print(path)

###############################################
# Connect to database
###############################################
pdb_config = {
        'host': "gama.iind.intel.com",
        'port': "3307",
        'user':  "gama_adm",
        'passwd': "gama@dm1N",
        'db': "newpowerdb"
}

adb_config = {
        'host': "gama.iind.intel.com",
        'port': "3307",
        'user': "gama_adm",
        'passwd': "gama@dm1N",
        'db': "archrast"
}

pcnx = mysql.connector.connect(**pdb_config)
acnx = mysql.connector.connect(**adb_config)
pcursor = pcnx.cursor()
acursor = acnx.cursor()

################################################
# Uploading data into the database
################################################
configid = get_config_id(options.config,options.sku)
frameid = get_frame_id(options.api,options.title,
                       options.setting,options.capture,int(options.frame))
aubid = get_aub_id(frameid,options.driver)
toolid = get_tool_id(options.tool,options.gsim_tag,options.tool_config)
for path in paths:
        length = len(path)
        if(length < 5 or path[-2] == 'total'):
                continue
        cluster = path[1]
        unit = path[2]
        stat_name = path[3]
        i = 4
        if(length > 5):
                while(i < length-1):
                        stat_name = stat_name + "." + path[i]
                        i+=1
        if(cluster not in cluster_id):
                cluster_id[cluster] = get_cluster_id(cluster)
        if(unit not in unit_id):
                unit_id[unit] = get_unit_id(unit)
        statid = get_stat_id(stat_name)
        insert_alps_numbers(aubid,toolid,configid,options.user,options.gsim_tag,options.alps_tag,options.version,
                            cluster_id[cluster],unit_id[unit],statid,path[-1])

insert_overview_numbers(aubid,toolid,configid,options.user,options.gsim_tag,options.alps_tag,options.version,
                        yaml_data['FPS'],yaml_data['Total_GT_Cdyn(nF)'],
                        yaml_data['Total_GT_Cdyn_syn(nF)'],yaml_data['Total_GT_Cdyn_ebb(nF)'])

for keys in yaml_data['key_stats']:
    #print (keys)
    statid = get_stat_id(keys)
    insert_key_stats(aubid,toolid,configid,options.user,options.gsim_tag,options.alps_tag,options.version,
                     statid,yaml_data['key_stats'][keys])

for cluster in yaml_data['cluster_cdyn_numbers(pF)']:
    insert_cluster_numbers(aubid,toolid,configid,options.user,options.gsim_tag,options.alps_tag,options.version,
                           cluster_id[cluster],yaml_data['cluster_cdyn_numbers(pF)'][cluster]['total'],
                           yaml_data['cluster_cdyn_numbers(pF)'][cluster]['syn'],yaml_data['cluster_cdyn_numbers(pF)'][cluster]['ebb'])

adict = yaml_data['unit_cdyn_numbers(pF)']
for cluster in adict:
    for unit in adict[cluster]:
        insert_unit_numbers(aubid,toolid,configid,options.user,options.gsim_tag,options.alps_tag,options.version,
                            cluster_id[cluster],unit_id[unit],adict[cluster][unit])

##print(yaml_data['FPS'],yaml_data['Total_GT_Cdyn(nF)'])
##query = ("SELECT DISTINCT api FROM frames")
##acursor.execute(query)
##for api in acursor:
##	print(api)
pcursor.close()
acursor.close()
pcnx.close()
acnx.close()
