import os
import yaml
import pandas as pd


def load_config(config_file):
    with open(config_file, "r") as in_fh:
        # Read the file into memory as a string so that we can try
        # parsing it twice without seeking back to the beginning and
        # re-reading.
        config = in_fh.read()

    config_dict = dict()
    valid_json = True
    valid_yaml = True

    try:
        config_dict = json.loads(config)
    except:
        print "Error trying to load the config file in JSON format"
        valid_json = False

    try:
        config_dict = yaml.safe_load(config)
    except:
        print "Error trying to load the config file in YAML format"
        valid_yaml = False
        
import os
from ruamel import yaml

config_file = "Test.yml"

with open(config_file, "r") as in_fh:
    config_dict = yaml.safe_load(in_fh)

config_dict = dict()
valid_json = True
valid_yaml = True

try:
    config_dict = json.load(in_fh)
except:
    print("Error trying to load the config file in JSON format")
    valid_json = False

try:
    config_dict = yaml.load(in_fh)
except:
    print("Error trying to load the config file in YAML format")
    valid_yaml = False

in_fh.close()

if not valid_yaml and not valid_json:
    print("The config file is neither JSON or YAML")
    sys.exit(1)
    
with open("alps_formula_tgllp.yml") as f:
     list_doc = yaml.load(f)

for sense in list_doc:
    if sense["name"] == "sense_2":
         sense["value"] = 1234

with open("test.yml", "w") as f:
    yaml.dump(list_doc, f)
    
import re
s = 'mov 66 (56.9%)  5406720 (56.9%)'
t1 = s.split('\?s', 3)
len(t1)


