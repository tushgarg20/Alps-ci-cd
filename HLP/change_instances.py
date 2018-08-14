import yaml
from collections import OrderedDict
import os

class INSTANCES:
	arg_dict = OrderedDict()

	def parse_input(self, f):
		f1 = open(f, 'r')
		arg_dict = yaml.load(f1)
		self.arg_dict['chosen-workloads'] = arg_dict['instances-arguments']['chosen-workloads']
		self.arg_dict['hlpm-output'] = arg_dict['instances-arguments']['hlpm-output'].strip()
		self.arg_dict['output-path'] = arg_dict['instances-arguments']['output-path'].strip()
		self.arg_dict['DepthZ'] = arg_dict['instances-arguments']['DepthZ']
		self.arg_dict['EU_IPC'] = arg_dict['instances-arguments']['EU_IPC']
		self.arg_dict['GEOM'] = arg_dict['instances-arguments']['GEOM']
		self.arg_dict['GTI'] = arg_dict['instances-arguments']['GTI']
		self.arg_dict['HDC'] = arg_dict['instances-arguments']['HDC']
		self.arg_dict['L3'] = arg_dict['instances-arguments']['L3']
		self.arg_dict['MEM'] = arg_dict['instances-arguments']['MEM']
		self.arg_dict['PB'] = arg_dict['instances-arguments']['PB']
		self.arg_dict['PSD'] = arg_dict['instances-arguments']['PSD']
		self.arg_dict['ROWBUS'] = arg_dict['instances-arguments']['ROWBUS']
		self.arg_dict['SAMPLER'] = arg_dict['instances-arguments']['SAMPLER']
		self.arg_dict['SBE'] = arg_dict['instances-arguments']['SBE']
		self.arg_dict['TLB'] = arg_dict['instances-arguments']['TLB']
		self.arg_dict['WM'] = arg_dict['instances-arguments']['WM']

	def modify_instances(self):
		"""
		Changes the number of instances of clusters in a util_data_base.yaml file for the chosen workloads
		Copies the file from the hlpm output if the results file is not present
		"""
		print("###################################Processing...########################################\n")
		chosen_workloads_f = self.arg_dict['chosen-workloads']
		chosen_workloads_file = open(chosen_workloads_f,'r')
		chosen_workloads = chosen_workloads_file.readlines()	
		for workload in chosen_workloads:
			if not workload.strip():
				continue
			util_file = workload.strip() + "_util.yaml"
			util_path = self.arg_dict['output-path'] + "/" + workload.strip()
			os.system("mkdir -p " + util_path)          #Creates output directory if it does not exist
			if util_file not  in os.listdir(util_path):
				os.system("cp " + self.arg_dict['hlpm-output'] + "/util_data/util_database.yaml " + util_path + "/" + util_file)
			uf = open(util_path + "/" + util_file, 'r')
			mpf_info = open("Inputs/mapping.yaml", "r")
			util_data = yaml.load(uf)
			mp_info = yaml.load(mpf_info)	#Cluster name mapping
			#Changing the number of instances
			for frame in util_data:
				for cluster in mp_info:
					N_instances = util_data[frame]['cluster_stat'][cluster]['num_instances']
					util_data[frame]['cluster_stat'][cluster]['num_instances'] = self.arg_dict[cluster]
			uf.close()
			util_target_file = open(util_path+ "/" +util_file, "w")
			yaml.dump(util_data, util_target_file, default_flow_style=False)
			mpf_info.close()
			util_target_file.close()
			print("Changed number of instances for : " + workload.strip())
		print("\n#############################Done Generating Results#############################")

	def __init__(self, f):
		self.parse_input(f)
		self.modify_instances()

if __name__ == '__main__':
	import argparse
	parser = argparse.ArgumentParser()
	parser.add_argument("--input", "-i", type=str, required=True)
	args = parser.parse_args()
	fn = args.input
	instances = INSTANCES(fn)
