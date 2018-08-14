import csv, yaml, argparse, pandas as pd, os
from collections import OrderedDict

class HLPM:
	arg_dict = OrderedDict()
	frame_cdyn = OrderedDict()

	def parse_knobs(self, f):
		fl = open(f, 'r')
		arg_dict = yaml.load(fl)
		self.arg_dict['default-cfg'] = arg_dict['config_arguments']['Default_base_config'].strip()
		self.arg_dict['base-cfg'] = arg_dict['config_arguments']['Base_config'].strip()
		self.arg_dict['hlpm-output'] = arg_dict['config_arguments']['hlpm-output'].strip()
		self.arg_dict['ccf-file']  = arg_dict['config_arguments']['ccf-file'].strip()
		self.arg_dict['target-cfg'] = arg_dict['config_arguments']['target_config'].strip()
		self.arg_dict['chosen-workloads'] = arg_dict['config_arguments']['chosen-workloads'].strip()
		self.arg_dict['output-path'] = arg_dict['config_arguments']['output-path'].strip()

	def copy_weights(self,wl):
		"""
		Copy the Cdyn weights from file containing all ccf values to Inputs/hlp_cdyn_weights.yaml
		"""
		cdyn_weights_stream = open(self.arg_dict['ccf-file'],"r")
		cdyn_weights = yaml.load(cdyn_weights_stream)
		pred_cdyn = open("hlp_cdyn_weights.yaml","r")
		cdyn_data = yaml.load(pred_cdyn)
		prev_name = ''
		prev_gen = ''
		curr_gen = self.arg_dict['base-cfg']
		for gen in cdyn_data:
			prev_gen = gen
			for workload in cdyn_data[gen]:
				prev_name = workload
				for cluster in cdyn_data[gen][workload]:
					cdyn_data[gen][workload][cluster].update(cdyn_weights[curr_gen][wl.strip()][cluster])
		pred_cdyn.close()
		cdyn_data[prev_gen][wl.strip()] = cdyn_data[prev_gen].pop(prev_name)
		cdyn_data[curr_gen] = cdyn_data.pop(prev_gen)
		write_cdyn = open("hlp_cdyn_weights.yaml","w")
		yaml.dump(cdyn_data, write_cdyn, default_flow_style=False)
		write_cdyn.close()
		cdyn_weights_stream.close()

	###Calculate the Cluster Cdyn and dump the results
	def predict(self):
		print("###################################Processing...########################################\n")
		chosen_wl_file = self.arg_dict['chosen-workloads']
		chosen_wl_stream = open(chosen_wl_file,'r')
		chosen_wl = chosen_wl_stream.readlines()
		print("Predicting for " + str(len(chosen_wl)) + " workload(s)....")
		print("-------------------------------------------------------------\n")
		for wl in chosen_wl:
			self.copy_weights(wl)
			wl_name = wl.strip()
			wl_path = self.arg_dict['output-path'] + "/" + wl_name
			os.system("mkdir -p " + wl_path )
			print("Predicting for : " + wl.strip())
			wl_util =  wl.strip()+"_util.yaml"
			if wl_util not in os.listdir(wl_path):	#Check if util file is not present in output directory, if no, copy util file from hlpm training output and use that file
				os.system("cp " + self.arg_dict['hlpm-output']+'/'+ wl.strip()+ '/util_data/util_data_base.yaml ' + wl_path + "/" + wl_util)
			util_file = wl_path + "/"+ wl_util
			mpf_info = open("mapping.yaml", "r")
			cwf_data = open("hlp_cdyn_weights.yaml")
			uf = open(util_file, 'r')
			util_data = yaml.load(uf)
			f = open(wl_path+"/"+wl_name+'.yaml', 'w')
			csv_file=open(wl_path+"/"+wl_name+'.csv','w')
			csv_file.write("Frame,EU_Active,EU_Inactive,Sampler_Active,Sampler_Inactive,L3_Active,L3_Inactive,GAM_Active,GAM_Inactive,COLOR_Active,COLOR_Inactive,Rest_Active,Rest_Inactive,Total")
			csv_file.write("\n")
			cls_scl = pd.read_csv("hlp_cluster_scaling.csv")
			prs_scl = pd.read_csv("hlp_process_scaling.csv")
			cw_data = yaml.load(cwf_data)
			mp_info = yaml.load(mpf_info)
			sm1 = prs_scl.index[prs_scl['Destination'] == self.arg_dict['target-cfg']]
			sm2 = prs_scl.index[prs_scl['Source'] == self.arg_dict['base-cfg']]
			cfg = self.arg_dict['base-cfg']
			print("SM1 is :" +str(sm1))
			print("SM2 is :" +str(sm2))
			print("cfg is :" +str(cfg))
			if sm2.empty:
				cfg = self.arg_dict['default-cfg']
				sm2 = prs_scl.index[prs_scl['Source'] == cfg]
				if sm2.empty:
					cfg = 'Gen9LP'
					sm2 = prs_scl.index[prs_scl['Source'] == cfg]
			idx = list(set(sm1).intersection(set(sm2)))[0]
			psf = prs_scl.iloc[idx, prs_scl.columns.get_loc('Process_scaling_factor')]
			di = prs_scl.iloc[idx, prs_scl.columns.get_loc('Driver_improvement')]
			for frame in util_data:
				c_Flag = False
				fr_name = (util_data[frame]['frame_name']).strip()
				wl_name = (util_data[frame]['frame_name'].split('__'))[0].strip()
				Total = 0
				self.frame_cdyn['workload'] = wl_name
				self.frame_cdyn['target-config'] =  self.arg_dict['target-cfg']
				self.frame_cdyn[fr_name] = OrderedDict()
				csv_line=fr_name+","
				for cluster in mp_info:
					util_active = util_data[frame]['cluster_stat'][cluster]['active_util']
					util_inactive = 1 - util_active
					N_instances = util_data[frame]['cluster_stat'][cluster]['num_instances']
					map_name = mp_info[cluster].strip()
					m1 = cls_scl.index[cls_scl['Cluster'] == map_name]
					m2 = cls_scl.index[cls_scl['Type'] == 'Active']
					m3 = cls_scl.index[cls_scl['Destination'] == self.arg_dict['target-cfg']]
					m4 = cls_scl.index[cls_scl['Source'] == cfg]
					m5 = cls_scl.index[cls_scl['Type'] == 'Inactive']
					bm1 = list(set(m1).intersection(set(m2)))
					bm2 = list(set(bm1).intersection(set(m3)))
					bm3 = list(set(bm2).intersection(set(m4)))[0]
					bm4 = list(set(m1).intersection(set(m5)))
					bm5 = list(set(bm4).intersection(set(m3)))
					bm6 = list(set(bm5).intersection(set(m4)))[0]
					csf_active = cls_scl.iloc[bm3, cls_scl.columns.get_loc('Scaling-Factor')]
					csf_inactive = cls_scl.iloc[bm6, cls_scl.columns.get_loc('Scaling-Factor')]
					cw_active = 0.0
					cw_inactive = 0.0
					wl_name = wl_name.split('--')[0]
					if cfg in cw_data:
						if wl_name in cw_data[cfg]:
							c_Flag = True
							cw_active = cw_data[cfg][wl_name][map_name]['Active']
							cw_inactive = cw_data[cfg][wl_name][map_name]['Inactive']
					#Now calculate the Cluster Cdyn
					cdyn_active = util_active * cw_active * psf * di * csf_active * N_instances
					cdyn_inactive = util_inactive * cw_inactive * psf * di * csf_inactive * N_instances
					clust_cdyn = cdyn_active + cdyn_inactive
					fac_a = cw_active * psf * di * csf_active
					fac_i = cw_inactive * psf * di * csf_inactive
					print(cluster + "_Active_CW: " + str(fac_a) + "  " + cluster + "_Inactive_CW: " + str(fac_i))
					Total = Total + clust_cdyn
					self.frame_cdyn[fr_name][map_name] = OrderedDict()
					self.frame_cdyn[fr_name][map_name]['Active'] = float(cdyn_active)
					self.frame_cdyn[fr_name][map_name]['Inactive'] = float(cdyn_inactive)
					csv_line=csv_line+str(cdyn_active)+","+str(cdyn_inactive)+","
				#now Go on with the Rest portion
				rutil_active = 1.0
				rutil_inactive = rutil_active - 1
				rm1 = cls_scl.index[cls_scl['Cluster'] == 'Rest']
				rm2 = cls_scl.index[cls_scl['Type'] == 'Active']
				rm3 = cls_scl.index[cls_scl['Destination'] == self.arg_dict['target-cfg']]
				rm4 = cls_scl.index[cls_scl['Source'] == cfg]
				rm5 = cls_scl.index[cls_scl['Type'] == 'Inactive']
				rbm1 = list(set(rm1).intersection(set(rm2)))
				rbm2 = list(set(rbm1).intersection(set(rm3)))
				rbm3 = list(set(rbm2).intersection(set(rm4)))[0]
				rbm4 = list(set(rm1).intersection(set(rm5)))
				rbm5 = list(set(rbm4).intersection(set(rm3)))
				rbm6 = list(set(rbm5).intersection(set(rm4)))[0]
				rcsf_active = cls_scl.iloc[rbm3, cls_scl.columns.get_loc('Scaling-Factor')]
				rcsf_inactive = cls_scl.iloc[rbm6, cls_scl.columns.get_loc('Scaling-Factor')]
				rcw_active = 0.0
				rcw_inactive =0.0
				if c_Flag == True:
					rcw_active = cw_data[cfg][wl_name]['Rest']['Active']
					rcw_inactive = cw_data[cfg][wl_name]['Rest']['Inactive']
				rcdyn_active = float(rutil_active * rcw_active * psf * di * rcsf_active)
				rcdyn_inactive = float(rutil_inactive * rcw_inactive * psf * di * rcsf_inactive)
				rcdyn_clust = rcdyn_active + rcdyn_inactive
				Total = Total + rcdyn_clust
				self.frame_cdyn[fr_name]['Rest'] = OrderedDict()
				self.frame_cdyn[fr_name]['Rest']['Active'] = float(rcdyn_active)
				self.frame_cdyn[fr_name]['Rest']['Inactive'] = float(rcdyn_inactive)
				self.frame_cdyn[fr_name]['Total'] = float(Total)
				csv_line=csv_line+str(rcdyn_active)+","+str(rcdyn_inactive)+","+str(Total)
				csv_file.write(csv_line)
				csv_file.write("\n")
				r_a = rcw_active * psf * di * rcsf_active
				r_i = rcw_inactive * psf * di * rcsf_inactive
				print("Rest_Active_CW: %s Rest_Inactive_CW: %s" % (r_a, r_i))
				print('\n')
			yaml.dump(self.frame_cdyn, f, default_flow_style = False)
			self.frame_cdyn.clear()
			#close all the opened resources
			chosen_wl_stream.close()
			f.close()
			mpf_info.close()
			cwf_data.close()
			uf.close()
			print("-------------------------------------------------------------")
		print("#############################Done Generating Results#############################")

	#####Constructor#####
	def __init__(self, f):
		self.parse_knobs(f)
		self.predict()

########MAIN Function############
if __name__ == '__main__':
	#Read the arguments
	parser = argparse.ArgumentParser()
	parser.add_argument("--input", "-i", type=str, required=True)
	args = parser.parse_args()
	fn = args.input
	hlp = HLPM(fn)
