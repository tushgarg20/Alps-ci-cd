
import os, csv, argparse, pandas as pd, math, sys, re, time, yaml, numpy as np
from subprocess import PIPE, Popen, call
from collections import OrderedDict
from cvxopt import matrix, solvers
from pathlib import Path
import pdb, datetime


class HLPM:
	
	##Data related to QP
	#clusters=["EU_IPC","SAMPLER", "L3"]
	clusters = []
	names = ["EU", "Sampler", "L3_Bank", "L3Node", "Fabric"]
	cl_cdyn = []
	res_frames = []
	util_frames = []
	cdyn_frames = []
	cdyn_clusters = []
	sum_cw_clusters = []
	exp_cw = []
	ai_ratios = []
	cw_pred = []
	GT_active_cdyn = []
	GT_inactive_cdyn = []
	frame_cluster_cdyn_original = []
	frame_cluster_cdyn_calculated = []
	is_rest_broken = False


	###HLPM Functions: Has to be optimized more
	####@Do the training with rest broken into active and inactive components
	def training(self, result_trn, cdyn_trn, cfg, sc_b):
		is_rest_broken = True
		sum_rest =  0.0
		f=open(result_trn,'r')
		frame_dict = yaml.load(f)
		for x in self.names:
			self.cl_cdyn.append([])
		for x in range(len(self.clusters) + 1):
			self.cdyn_clusters.append([])
			self.sum_cw_clusters.append([])
		for x in range(len(self.sum_cw_clusters)):
			for y in range(2):
				self.sum_cw_clusters[x].append(0.0)
		for x in frame_dict:
			self.GT_active_cdyn.append(0.0)
			self.GT_inactive_cdyn.append(0.0)
		############@Read_Cluster Cdyn##############
		utils = [line.rstrip('\n') for line in open(cdyn_trn)]
		ut = 0
		for fl in utils:
			f = open(fl)
			reader = csv.reader(f)
			k_list = []
			for x in self.names:
				k_list.append([])
			for row in reader:		
				for col in row:
					i = 0
					if( col == 'GT_idle_cdyn' or col == 'GT_stall_cdyn'):
						self.GT_inactive_cdyn[ut] = self.GT_inactive_cdyn[ut] + float(row[1])
					elif (col == 'GT_active_cdyn'):
						self.GT_active_cdyn[ut] = self.GT_active_cdyn[ut] + float(row[1])
					for x in self.names:
						if ( col == x):
							k_list[i].append(row[2])
						i = i + 1
					break;
			ut = ut + 1
			j = 0
			for x in k_list:
				self.cl_cdyn[j].append(x)
				j = j + 1

		######@Some post processing for cluster_wise cdyn values#######
		i = 0
		for cl in self.cl_cdyn:
			j = 0
			for fr_cl in cl:
				cl_act_inact = []
				act_cluster = float(fr_cl[2])
				inact_cluster = float(fr_cl[0]) + float(fr_cl[1])
				cl_act_inact.append(act_cluster)
				cl_act_inact.append(inact_cluster)
				if(i == 3):
					self.cdyn_clusters[i - 1][j][0] = self.cdyn_clusters[i - 1][j][0] + act_cluster
					self.cdyn_clusters[i - 1][j][1] = self.cdyn_clusters[i - 1][j][1] + inact_cluster
				else:
					if(i>3):
						self.cdyn_clusters[i-1].append(cl_act_inact)
					else:
						self.cdyn_clusters[i].append(cl_act_inact)
				j = j + 1
			i = i + 1
		#print("GTActiveCdyn: ", GT_active_cdyn)
		#print("GTInactiveCdyn: ", GT_inactive_cdyn)
		#############@Read Utilizations################
		rest_active_sum = 0.0
		rest_inactive_sum = 0.0
		N_frame = 0
		for frame in frame_dict:
			res_list = []
			util_list = []
			util_clusters_active = []
			N_cluster = 0
			sum_cl_cdyn = 0.0
			util_rest = 1.0
			sum_active_cdyn = 0.0
			sum_inactive_cdyn = 0.0
			for cluster in self.clusters:
				N_instances = frame_dict[frame]['cluster_stat'][cluster]['num_instances']
				scalar = frame_dict[frame]['cluster_stat'][cluster]['scaling_factor']
				util_active = frame_dict[frame]['cluster_stat'][cluster]['active_util'] * scalar
				util_inactive = 1 - util_active
				###@Find Active and Inactive Residencies###
				res_active = util_active * N_instances
				res_inactive = util_inactive * N_instances
				util_clusters_active.append(util_active)
				util_list.append(util_active)
				util_list.append(util_inactive)
				res_list.append(res_active)
				res_list.append(res_inactive)
				#####@Find the cluster cdyn values of this frame######
				cdyn_cluster_active = self.cdyn_clusters[N_cluster][N_frame][0]
				cdyn_cluster_inactive = self.cdyn_clusters[N_cluster][N_frame][1]
				sum_cl_cdyn = sum_cl_cdyn + cdyn_cluster_active + cdyn_cluster_inactive
				sum_active_cdyn = sum_active_cdyn + cdyn_cluster_active
				sum_inactive_cdyn = sum_inactive_cdyn + cdyn_cluster_inactive
				self.sum_cw_clusters[N_cluster][0] = self.sum_cw_clusters[N_cluster][0] + (cdyn_cluster_active / N_instances)
				#if(util_inactive == 0):
				#	sum_cw_clusters[N_cluster][1] = sum_cw_clusters[N_cluster][1] + 0.0
				#else:
				self.sum_cw_clusters[N_cluster][1] = self.sum_cw_clusters[N_cluster][1] + (cdyn_cluster_inactive / N_instances)
				N_cluster = N_cluster + 1
			#####@Find the same for the rest portion########
			rest_active_cdyn = self.GT_active_cdyn[N_frame] - sum_active_cdyn
			rest_inactive_cdyn = self.GT_inactive_cdyn[N_frame] - sum_inactive_cdyn
			self.cdyn_clusters[N_cluster].append([])
			self.cdyn_clusters[N_cluster][N_frame].append(rest_active_cdyn)
			self.cdyn_clusters[N_cluster][N_frame].append(rest_inactive_cdyn)
			rest_active_sum = rest_active_sum + rest_active_cdyn
			rest_inactive_sum = rest_inactive_sum + rest_inactive_cdyn
			util_active_rest = max(util_clusters_active)
			util_inactive_rest = 1 - util_active_rest
			res_active_rest = util_active_rest * 1.0
			res_inactive_rest = util_inactive_rest * 1.0
			util_list.append(util_active_rest)
			util_list.append(util_inactive_rest)
			res_list.append(res_active_rest)
			res_list.append(res_inactive_rest)
			#sum_cw_clusters[N_cluster][0] = sum_cw_clusters[N_cluster][0] + (rest_active_cdyn / res_active_rest)
			self.sum_cw_clusters[N_cluster][0] = self.sum_cw_clusters[N_cluster][0] + (rest_active_cdyn / 1.0)
			#if(util_inactive_rest == 0):
			#	sum_cw_clusters[N_cluster][1] = sum_cw_clusters[N_cluster][1] + 0.0
			#else:
			self.sum_cw_clusters[N_cluster][1] = self.sum_cw_clusters[N_cluster][1] + (rest_inactive_cdyn / 1.0)
			GTCdyn = frame_dict[frame]['cdyn'] * 1000
			#print(GTCdyn, sum_cl_cdyn)
			RESTCdyn = GTCdyn - sum_cl_cdyn
			print("RA: %s RI: %s Tot: %s" %(rest_active_cdyn, rest_inactive_cdyn, RESTCdyn))
			self.cdyn_frames.append(GTCdyn)
			self.util_frames.append(util_list)
			self.res_frames.append(res_list)
			N_frame = N_frame + 1
		print("Average Rest Active Cdyn: ",rest_active_sum/len(frame_dict))
		print("Average Rest Inactive Cdyn: ",rest_inactive_sum/len(frame_dict))
		########@Print the Utilization Matrix#############
		print("\n##################Utilizations###############\n")
		m = 0
		for k in self.util_frames:
			#print("%s: %s" %(k, rest_cdyn[m]))
			print("%d. %s: %s" %(m+1, k, self.cdyn_frames[m]))
			m = m + 1
		########@Find the expected Cdyn_weights###########
		print("\n##################Expected Cdyn Weights###############\n")
		for k in self.sum_cw_clusters:
			x = (k[0]/N_frame) * float(sc_b)
			y = (k[1]/N_frame) * float(sc_b)
			self.exp_cw.append(x)
			self.exp_cw.append(y)
			self.ai_ratios.append(x/y)
		print(self.exp_cw)
		print("\n##################Active_inactive Ratios###############\n")
		print(self.ai_ratios)
		##############@Start QP##############
		###@@@Defnitions@@@######
		q_list = []
		h_list = []
		g_list = []
		temp = []
		ub = []
		ub_constrs = np.identity(len(self.exp_cw))
		lb_constrs = np.zeros((len(self.exp_cw),len(self.exp_cw)), int)
		np.fill_diagonal(lb_constrs, -1)
		ai_ratio_constrs = []
		for k in self.ai_ratios:
			ai_ratio_constrs.append([])
			h_list.append(0.00001)
		i = 0
		j = 0	
		for m in self.exp_cw:
			if(i == math.floor(len(self.exp_cw)/2)):
				break;
			for n in self.exp_cw:
				ai_ratio_constrs[i].append(0)
			ai_ratio_constrs[i][j] = 1
			ai_ratio_constrs[i][j+1] = -(self.ai_ratios[i])
			j = j + 2
			i = i + 1
		lb = []
		for k in self.exp_cw:
			q_list.append(1)
		A = matrix(np.array(self.res_frames), tc ='d')
		Atsp = [list(x) for x in zip(*(self.res_frames))]
		ATA = np.matmul(Atsp, A)
		#####@Set the lower and upper bounds######
		for k in self.exp_cw:
			ub.append(k + 1)
			lb.append(-(k - 1))
		h_list = h_list + ub + lb
		temp.append(ai_ratio_constrs)
		temp.append(ub_constrs)
		temp.append(lb_constrs)
		print("\n#############h and G matrices##############\n")
		print(h_list)
		for k in temp:
			for m in k:
				g_list.append(m)
				print(m)
		P = matrix(np.array(ATA), tc = 'd')
		q = matrix(np.array(q_list), tc = 'd')		
		h = matrix(np.array(h_list), tc = 'd')
		G = matrix(np.array(g_list), tc = 'd')
		##########@Perform QP##########
		sol = solvers.qp(P, q, G, h)
		self.cw_pred = sol['x']
		h = 0
		b = 0
		p = 0
		array_ai = ["Active", "Inactive"]
		for g in range(len(self.cw_pred)):
			print("%s: %f" %(array_ai[p], sol['x'][g]))
			if(p == 0):
				p = 1
			else:
				p = 0

		print("\n")
	######@Do the training without rest broken into active and inactive parts
	def training2(self, result_trn, cdyn_trn, cfg, sc_b, path):
		sum_rest =  0.0
		is_rest_broken = False
		f=open(result_trn,'r')
		frame_dict = yaml.load(f)
		for x in self.names:
			self.cl_cdyn.append([])
		for x in range(len(self.names) - 2):
			self.cdyn_clusters.append([])
			self.sum_cw_clusters.append([])
		for x in range(len(self.sum_cw_clusters)):
			for y in range(2):
				self.sum_cw_clusters[x].append(0.0)
		############@Read_Cluster Cdyn##############
		utils = [line.rstrip('\n') for line in open(cdyn_trn)]
		for fl in utils:
			f = open(fl)
			reader = csv.reader(f)
			k_list = []
			for x in self.names:
				k_list.append([])
			for row in reader:		
				for col in row:
					i = 0
					for x in self.names:
						if ( col == x):
							k_list[i].append(row[2])
						i = i + 1
					break;
			j = 0
			for x in k_list:
				self.cl_cdyn[j].append(x)
				j = j + 1
		######@Some post processing for cluster_wise cdyn values#######
		i = 0
		for cl in self.cl_cdyn:
			j = 0
			for fr_cl in cl:
				cl_act_inact = []
				act_cluster = float(fr_cl[2])
				inact_cluster = float(fr_cl[0]) + float(fr_cl[1])
				cl_act_inact.append(act_cluster)
				cl_act_inact.append(inact_cluster)
				if(i == 3 or i == 4):
					self.cdyn_clusters[2][j][0] = self.cdyn_clusters[2][j][0] + act_cluster
					self.cdyn_clusters[2][j][1] = self.cdyn_clusters[2][j][1] + inact_cluster
				else:
					if(i>4):
						self.cdyn_clusters[i-2].append(cl_act_inact)
					else:
						self.cdyn_clusters[i].append(cl_act_inact)
				j = j + 1
			i = i + 1
		#############@Read Utilizations################
		N_frame = 0
		for frame in frame_dict:
			res_list = []
			util_list = []
			cluster_cdyn_original = []
			N_cluster = 0
			sum_cl_cdyn = 0.0
			util_rest = 1.0
			for cluster in self.clusters:
				N_instances = frame_dict[frame]['cluster_stat'][cluster]['num_instances']
				scalar = frame_dict[frame]['cluster_stat'][cluster]['scaling_factor']
				util_active = frame_dict[frame]['cluster_stat'][cluster]['active_util'] * scalar
				util_inactive = 1 - util_active
				###@Find Active and Inactive Residencies###
				res_active = util_active * N_instances
				res_inactive = util_inactive * N_instances
				util_list.append(util_active)
				util_list.append(util_inactive)
				res_list.append(res_active)
				res_list.append(res_inactive)
				#####@Find the cluster cdyn values of this frame######
				cdyn_cluster_active = self.cdyn_clusters[N_cluster][N_frame][0]
				cdyn_cluster_inactive = self.cdyn_clusters[N_cluster][N_frame][1]
				cluster_cdyn_original.append(round(cdyn_cluster_active + cdyn_cluster_inactive, 2))
				
				sum_cl_cdyn = sum_cl_cdyn + cdyn_cluster_active + cdyn_cluster_inactive
				#sum_cw_clusters[N_cluster][0] = sum_cw_clusters[N_cluster][0] + (cdyn_cluster_active / res_active)
				self.sum_cw_clusters[N_cluster][0] = self.sum_cw_clusters[N_cluster][0] + (cdyn_cluster_active / N_instances)
				#if(util_inactive == 0):
				#	sum_cw_clusters[N_cluster][1] = sum_cw_clusters[N_cluster][1] + 0.0
				#else:
				self.sum_cw_clusters[N_cluster][1] = self.sum_cw_clusters[N_cluster][1] + (cdyn_cluster_inactive / N_instances)

				N_cluster = N_cluster + 1
			#####@Find the same for the rest portion########
			#@@@@@A dummy way of getting the configs@@@@@#
			#####@Get the values of gtcdyn, restcdyn etc######
			GTCdyn = frame_dict[frame]['cdyn'] * 1000
			RESTCdyn = GTCdyn - sum_cl_cdyn
			cluster_cdyn_original.append(round(RESTCdyn,2))
			#rest_cdyn.append(RESTCdyn)
			#print("%s %s: %s" % (RESTCdyn, util_rest, RESTCdyn/util_rest))
			util_list.append(1.0)
			res_list.append(util_rest)
			sum_rest = sum_rest + (RESTCdyn/1.0)
			GTC_less_Rest = GTCdyn - RESTCdyn
			self.cdyn_frames.append(GTCdyn)
			self.util_frames.append(util_list)
			self.res_frames.append(res_list)
			N_frame = N_frame + 1
			self.frame_cluster_cdyn_original.append(cluster_cdyn_original)
		sum_cw_rest = sum_rest
		fgh = open(path + "/utilizations_" + cfg + ".csv", "w+")
		wr = csv.writer(fgh)
		########@Print the Utilization Matrix#############
		print("\n##################Utilizations###############\n")
		m = 0
		for k in self.util_frames:
			#print("%s: %s" %(k, rest_cdyn[m]))
			print("%d. %s: %s" %(m+1, k, self.cdyn_frames[m]))
			wr.writerow(k)
			m = m + 1
		fgh.close()
		########@Find the expected Cdyn_weights###########
		print("\n##################Expected Cdyn Factors###############\n")
		for k in self.sum_cw_clusters:
			x = (k[0]/N_frame) * float(sc_b)
			y = (k[1]/N_frame) * float(sc_b)
			self.exp_cw.append(x)
			self.exp_cw.append(y)
			self.ai_ratios.append(x/y)
		self.exp_cw.append(sum_cw_rest/N_frame)
		print(self.exp_cw)
		print("\n##################Active_inactive Ratios###############\n")
		print(self.ai_ratios)
		##############@Start QP##############
		###@@@Defnitions@@@######
		q_list = []
		h_list = []
		g_list = []
		temp = []
		ub = []
		ub_constrs = np.identity(len(self.exp_cw))
		lb_constrs = np.zeros((len(self.exp_cw),len(self.exp_cw)), int)
		np.fill_diagonal(lb_constrs, -1)
		ai_ratio_constrs = []
		for k in self.ai_ratios:
			ai_ratio_constrs.append([])
			h_list.append(0.00001)
		i = 0
		j = 0	
		for m in self.exp_cw:
			if(i == math.floor(len(self.exp_cw)/2)):
				break;
			for n in self.exp_cw:
				ai_ratio_constrs[i].append(0)
			ai_ratio_constrs[i][j] = 1
			ai_ratio_constrs[i][j+1] = -(self.ai_ratios[i])
			j = j + 2
			i = i + 1
		lb = []
		for k in self.exp_cw:
			q_list.append(1)
		A = matrix(np.array(self.res_frames), tc ='d')
		Atsp = [list(x) for x in zip(*self.res_frames)]
		ATA = np.matmul(Atsp, A)
		#####@Set the lower and upper bounds######
		for k in self.exp_cw:
			ub.append(k + 1)
			lb.append(-(k - 1))
		h_list = h_list + ub + lb
		temp.append(ai_ratio_constrs)
		temp.append(ub_constrs)
		temp.append(lb_constrs)
		print("\n#############h and G matrices##############\n")
		print(h_list)
		for k in temp:
			for m in k:
				g_list.append(m)
				print(m)
		P = matrix(np.array(ATA), tc = 'd')
		q = matrix(np.array(q_list), tc = 'd')		
		h = matrix(np.array(h_list), tc = 'd')
		G = matrix(np.array(g_list), tc = 'd')
		##########@Perform QP##########
		workload_name=path.split("/")[-4]
		sol = solvers.qp(P, q, G, h)
		self.cw_pred = sol['x']
		array_ai = ["Active", "Inactive"]
		b = 0
		p = 0
		c_file = open(path + "/Cdyn_weights_" + cfg + ".csv", "w")
		####for identifying the generation
		cfg_dict=OrderedDict()
		cfg_dict={'icl' : 'Gen11LP',
		     'tgl': 'Gen12LP'}
		configuration= cfg.split("_")[0]
		####to write the CCF into the common yaml file ccf_yaml.yaml
		names=["EU","Sampler","L3","GAM","Rest"]

		####reading the existing ccf_yaml as a dictionary to be modified
		ccf_yaml=open("ccf_yaml.yaml" , "r")
		final_dict=yaml.load(ccf_yaml)
		values = OrderedDict()
		for key, value in final_dict.items():
			values.update(value)
		ccf_yaml.close()
		if (not final_dict):
			final_dict=OrderedDict()
		ccf_yaml=open("ccf_yaml.yaml" , "w")
		inner_dict=OrderedDict()
		outer_dict=OrderedDict()
		wl_dict=OrderedDict()
		complete_dict=OrderedDict()
		final_dict_new=OrderedDict()
		for g in range(len(self.cw_pred)):
			inner_dict[array_ai[p]]=sol['x'][g]
			print("%s  : %f  " %(array_ai[p], sol['x'][g]))
			if (g%2 == 1):
				outer_dict[names[g//2]]=inner_dict
				inner_dict=OrderedDict()
			c_file.write(array_ai[p] + "," + str(sol['x'][g]) + "\n")
			if(p == 0):
				p = 1
			else:
				p = 0
		outer_dict[names[g//2]]=inner_dict
		outer_dict[names[g//2]]['Inactive']=0
		wl_dict[workload_name]=outer_dict
		values.update(wl_dict)
		final_dict_new[cfg_dict[configuration]]=values
		####concatenating the new dictionary to existing dictionary
		yaml.dump(final_dict_new,ccf_yaml,default_flow_style=False)
		ccf_yaml.close()	
		####done writing to the common ccf_yaml file
		c_file.close()
	#####@@@Function to calculate the cdyn directly using weights and given utilizations####
	def calculate(self, result_file, c_b, c_t, s_b, op_path):
		###@Definitions######
		original_cdyn = []
		calculated_cdyn = []
		err_cdyn = []	
		
		util_clusters_active = []
		f1 = open(result_file, 'r')
		frame_dict = yaml.load(f1);
		cfg = c_t
		for frame in frame_dict:
			f_sum = 0.0
			m = 0
			rest_cdyn = 0.0
			original_cdyn.append(frame_dict[frame]['cdyn'] * 1000.0)
			cluster_cdyn_calculated = []
			for cluster in self.clusters:
				N_inst = frame_dict[frame]['cluster_stat'][cluster]['num_instances']
				sf = frame_dict[frame]['cluster_stat'][cluster]['scaling_factor']
				psf = frame_dict[frame]['cluster_stat'][cluster]['process_sf']
				util_active = frame_dict[frame]['cluster_stat'][cluster]['active_util'] * sf
				util_inactive = 1.0 - util_active
				cdyn_active = util_active * N_inst * self.cw_pred[m] * psf
				
				cdyn_inactive = util_inactive * N_inst * self.cw_pred[m+1] * psf
				#print("%s %s %s %s" %(util_active, cdyn_active, util_inactive, cdyn_inactive))

				util_clusters_active.append(util_active)
				print("%s: %s %s" %(cluster, cdyn_active,cdyn_inactive))
				c_sum = cdyn_active + cdyn_inactive
				f_sum = f_sum + c_sum
				cluster_cdyn_calculated.append(round(c_sum,2))
				m = m + 2
			ssf = 1.0
			ssf_a = 1.0
			ssf_i = 1.0
			if 'rest' in cfg:
				if 'sklgt2' in cfg.replace('_', ''):
					ssf_a = ssf_a * frame_dict[frame]['sklgt2_rest'][0][0]
					ssf_i = ssf_i * frame_dict[frame]['sklgt2_rest'][0][1]
				elif 'sklgt3' in cfg.replace('_', ''):
					ssf_a = ssf_a * frame_dict[frame]['sklgt2_rest'][1][0]
					ssf_i = ssf_i * frame_dict[frame]['sklgt2_rest'][1][1]
				elif 'sklgt4' in cfg.replace('_', ''):
					ssf_a = ssf_a * frame_dict[frame]['sklgt2_rest'][2][0]
					ssf_i = ssf_i * frame_dict[frame]['sklgt2_rest'][2][1]
				elif 'icl' in cfg.replace('_', ''):
					ssf_a = ssf_a * frame_dict[frame]['icl_rest'][0][0]
					ssf_i = ssf_i * frame_dict[frame]['icl_rest'][0][1]
				elif 'tgl' in cfg.replace('_', ''):
					ssf_a = ssf_a * frame_dict[frame]['icl_rest'][1][0]
					ssf_i = ssf_i * frame_dict[frame]['icl_rest'][1][1]

				util_active_rest = max(util_clusters_active)
				util_inactive_rest = 1 - util_active_rest
				rest_cdyn_active = ssf_a * self.cw_pred[m] * util_active_rest
				rest_cdyn_inactive = ssf_i * self.cw_pred[m+1] * util_inactive_rest
				rest_cdyn = rest_cdyn_active + rest_cdyn_inactive
				f_sum = f_sum + rest_cdyn
				print("Rest scaling factors used: ", ssf_a, ssf_i)
				print("Computed Rest Cdyn value: ", rest_cdyn_active + rest_cdyn_inactive)
				print("\n")
			elif('sklgt2' in cfg.replace('_', '')):
				ssf = ssf * frame_dict[frame]['sklgt2'][0]
				rest_cdyn = ssf * self.cw_pred[m] * 1.0
				print("CW pred: ",self.cw_pred[m])
				f_sum = f_sum + rest_cdyn
				print("Rest scaling factor used: ", ssf)
				print("Computed Rest Cdyn value: ", rest_cdyn)
			elif('sklgt3' in cfg.replace('_', '')):
				ssf = ssf * frame_dict[frame]['sklgt2'][1]
				rest_cdyn = ssf * self.cw_pred[m] * 1.0
				f_sum = f_sum + rest_cdyn
				print("Rest scaling factor used: ", ssf)
				print("Computed Rest Cdyn value: ", rest_cdyn)
			elif('icl' in cfg):
				print("#######For icl########")
				ssf = ssf * frame_dict[frame]['icl'][0]
				rest_cdyn = ssf * self.cw_pred[m] * 1.0
				f_sum = f_sum + rest_cdyn
				print("Rest scaling factor used: ", ssf)
				print("Computed Rest Cdyn value: ", rest_cdyn)
			elif('tgl' in cfg):
				ssf = ssf * frame_dict[frame]['icl'][1]
				rest_cdyn = ssf * self.cw_pred[m] * 1.0
				f_sum = f_sum + rest_cdyn
				print("Rest scaling factor used: ", ssf)
				print("Computed Rest Cdyn value: ", rest_cdyn)
			cluster_cdyn_calculated.append(round(rest_cdyn,2))
			self.frame_cluster_cdyn_calculated.append(cluster_cdyn_calculated)
			calculated_cdyn.append(f_sum)	
			print("\n")
		
		print("\nOriginal Cdyn: ", original_cdyn)
		print("\n")
		print("Calculated Cdyn: ", calculated_cdyn)
		print("\n")
		###@Calculate the gtcdyn difference####
		k = 0
		for i in original_cdyn:
			err_cdyn.append(round((((calculated_cdyn[k] - original_cdyn[k]) / original_cdyn[k])*100), 2))
			k = k + 1
		print("Error: ", err_cdyn)
		####@Write to a CSV file#####
		d_str2 = str(datetime.datetime.now()).replace(' ','_')
		fn = op_path + "/comparision_" + c_b + "_" + c_t + "_" + str(s_b) + "_" + d_str2 + ".csv"
		op_fl = open(fn, "w")
		cw_str = "CdynFactor_Predicted"
		for x in self.cw_pred:
			cw_str = cw_str + "," + str(x)
		cw_str = cw_str + "\n"
		op_fl.write("\n")
		b = 0
		op_fl.write("Original_Cdyn,Calculated_Cdyn, Error\n")
		for x in original_cdyn:
			text = str(round(original_cdyn[b],2)) + "," + str(round(calculated_cdyn[b],2)) + "," + str(round(err_cdyn[b],2)) + str("%")
			op_fl.write(text + "\n")
			b = b + 1
		op_fl.write("\n")
		f_idx = 1
		d_str = str(datetime.datetime.now()).replace(' ','_')
		
		c_fn = op_path + "/cluster_wise_error_of_frames_" + d_str + ".txt"
		c_file = open(c_fn, 'w')
		
		for i in range(len(self.frame_cluster_cdyn_original)):
			print("frame_"+ str(f_idx))
			c_file.write("frame" + str(f_idx) + "\n")
			c_idx = 1
			for j in range(len(self.frame_cluster_cdyn_original[i])):
				e_data = "cluster_" + str(c_idx) + ": original = " + str(self.frame_cluster_cdyn_original[i][j]) + " \tcalculated  = " + str(self.frame_cluster_cdyn_calculated[i][j]) + " \t%Error: " + str(round((((self.frame_cluster_cdyn_calculated[i][j] - self.frame_cluster_cdyn_original[i][j]) / self.frame_cluster_cdyn_original[i][j])*100), 2))
				print(e_data)
				c_file.write(e_data + "\n")
				c_idx = c_idx + 1
			f_idx = f_idx + 1
			c_file.write("\n")
			print("############")
		
		####HLPM Functions ends here
	###Function Invoker
	def Invoke(self, ut, ib, cb, ct, sf, op_path):
		#print("Do Something")
		cb = cb.replace('.cfg', '').strip()
		ct = ct.replace('.cfg', '').strip()
		#To break rest into components
		#self.training(ub, ib, cb, sf)
		#self.calculate(ut, cb, ct + "rest", sf, op_path)
		self.training2(ut, ib, cb, sf, op_path)
		self.calculate(ut, cb, ct, sf, op_path)
	###Constructor	
	def __init__(self, clusters):
    		self.clusters = clusters
class Data:

	####Global variables and Definitions
	main_knobs = ['run-tg', 'modify-tg', 'run-alps', 'run-hlpm', 'run-hlpm-only']
	tg_knobs = ['input-path', 'output-path', 'tg-path', 'cfg']
	modify_knobs = ['target-file', 'input-path-base', 'base-config', 'target-config','output-path-modified']
	alps_knobs = ['alps-path', 'gsim-output-path', 'alps-output-path', "alps-arch"]
	hlpm_knobs = ['tg-results-base', 'tg-results-target', 'alps-output-path-base', 'alps-output-path-target', 'hlpm-output-path', "cdyn-factor-scalar", 'base-conf', 'target-conf']
	hlpm_only_knobs = ['hlpm-input', 'cdyn-scalar', 'hlpm-output', 'idle-act-path', 'base-cfg', 'target-cfg']
	control_block = [False, False, False, False, False]
	knob_dict = {}
	glob_sel_dict = OrderedDict()
	glob_op_lw_dict = OrderedDict()
	##Commands processor
	def cmdline(self, command):
		process = Popen(
        	args=command,
        	stdout=PIPE,
		universal_newlines=True,
        	shell=True)
		return process.communicate()[0]
	def generateTG_new(self, knob_dict):
		mini_dict = {}

		inp_cfg = knob_dict['cfg']		
		tgp = knob_dict['tg-path']
		i_dir = knob_dict['input-path']
		o_path = knob_dict['output-path'] + "/"
		if not os.path.isdir(o_path):
			os.system("mkdir -p " + o_path)
		if 'max-gti-wr-tpt' in knob_dict and knob_dict['max-gti-wr-tpt']:
			mini_dict['max-gti-wr-tpt'] = knob_dict['max-gti-wr-tpt']
		if 'max-edram-tpt' in knob_dict and knob_dict['max-edram-tpt']:
			mini_dict['max-edram-tpt'] = knob_dict['max-edram-tpt']
		if 'max-edram-rd-tpt' in knob_dict and knob_dict['max-edram-rd-tpt']:
			mini_dict['max-edram-rd-tpt'] = knob_dict['max-edram-rd-tpt']
		if 'max-edram-wr-tpt' in knob_dict and knob_dict['max-edram-wr-tpt']:
			mini_dict['max-edram-wr-tpt'] = knob_dict['max-edram-wr-tpt']
		if 'max-mem-tpt' in knob_dict and knob_dict['max-mem-tpt']:
			mini_dict['max-mem-tpt'] = knob_dict['max-mem-tpt']
		if 'max-smp-tpt' in knob_dict and knob_dict['max-smp-tpt']:
			mini_dict['max-smp-tpt'] = knob_dict['max-smp-tpt']
		if 'max-smp-fetch-tpt' in knob_dict and knob_dict['max-smp-fetch-tpt']:
			mini_dict['max-smp-fetch-tpt'] = knob_dict['max-smp-fetch-tpt']
		if 'max-mt-tpt' in knob_dict and knob_dict['max-mt-tpt']:
			mini_dict['max-mt-tpt'] = knob_dict['max-mt-tpt']
		if 'max-vtx-rate' in knob_dict and knob_dict['max-vtx-rate']:
			mini_dict['max-vtx-rate'] = knob_dict['max-vtx-rate']
		if 'max-sf-cull-rate' in knob_dict and knob_dict['max-sf-cull-rate']:
			mini_dict['max-sf-cull-rate'] = knob_dict['max-sf-cull-rate']
		if 'max-sf-pass-rate' in knob_dict and knob_dict['max-sf-pass-rate']:
			mini_dict['max-sf-pass-rate'] = knob_dict['max-sf-pass-rate']
		if 'max-gafs-rd-rate' in knob_dict and knob_dict['max-gafs-rd-rate']:
			mini_dict['max-gafs-rd-rate'] = knob_dict['max-gafs-rd-rate']
		if 'max-cl-strip-rate' in knob_dict and knob_dict['max-cl-strip-rate']:
			mini_dict['max-cl-strip-rate'] = knob_dict['max-cl-strip-rate']
		if 'max-cl-list-rate' in knob_dict and knob_dict['max-cl-list-rate']:
			mini_dict['max-cl-list-rate'] = knob_dict['max-cl-list-rate']
		if 'max-l3-bank' in knob_dict and knob_dict['max-l3-bank']:
			mini_dict['max-l3-bank'] = knob_dict['max-l3-bank']
		if 'max-hdc' in knob_dict and knob_dict['max-hdc']:
			mini_dict['max-hdc'] = knob_dict['max-hdc']
		if 'max-ipc' in knob_dict and knob_dict['max-ipc']:
			mini_dict['max-ipc'] = knob_dict['max-ipc']
		if 'max-active-threads' in knob_dict and knob_dict['max-active-threads']:
			mini_dict['max-active-threads'] = knob_dict['max-active-threads']
		if 'max-zpipe-rate' in knob_dict and knob_dict['max-zpipe-rate']:
			mini_dict['max-zpipe-rate'] = knob_dict['max-zpipe-rate']
		if 'max-row-num' in knob_dict and knob_dict['max-row-num']:
			mini_dict['max-row-num'] = knob_dict['max-row-num']
		if 'num-eus' in knob_dict and knob_dict['num-eus']:
			mini_dict['num-eus'] = knob_dict['num-eus']
		if 'num-slices' in knob_dict and knob_dict['num-slices']:
			mini_dict['num-slices'] = knob_dict['num-slices']
		if 'num-subslices' in knob_dict and knob_dict['num-subslices']:
			mini_dict['num-subslices'] = knob_dict['num-subslices']
		knob_str = ""
		if (len(mini_dict) >= 1):
			for key in mini_dict:
				knob_str = knob_str + " --" + key + " " + mini_dict[key]
		####getting the list of frames from the tg_input directory
		wl=os.listdir(i_dir)
		wl_list=[]
		for wl_iter in wl:
			if (wl_iter.endswith('.gz')):
				wl_list.append(wl_iter)
		tracelist=[]		
		for trace_iter in wl_list:
			if (trace_iter.endswith('.Timegraph.gz')):
				tracelist.append(trace_iter.split('.Timegraph.gz')[0])	
		frame_index_no=0
		###iterating over all the frames of all workloads		
		for iter in range(len(tracelist)):
			frame_no=re.findall(r"f\d+",tracelist[iter])[0]
			app_name=tracelist[iter].split('.')[0]
			frame_index_no += 1
			fo_path = o_path+app_name.split('__')[0]+"/"
			hl2 = fo_path + app_name
			os.system("if test -d "+ hl2 +"; then rm -r "+ hl2 +"; fi")
			'''cfg_cmd = "zgrep '^# cfg file' " +i_dir+"/"+ tracelist[iter]+".stat.gz"
			cfg = self.cmdline(cfg_cmd).split(':')
			cfg = cfg[1].strip()
			cfg = cfg.split('_')[0]'''
			
			os.system("mkdir -p " + hl2)
			cmd = tgp + " --flat-input-path " + i_dir + "/" + " --output-path " + hl2 +"/"+ " --app-name " + app_name +" --frame-num " + str(frame_no) + " --save-util-time" + knob_str
			print("Executing Timegraph: ",cmd)
			os.system(cmd)
			'''if cfg in inp_cfg:
				print (cfg,inp_cfg)
				os.system("mkdir -p " + hl2)
				cmd = tgp + " --flat-input-path " + i_dir + "/" + " --output-path " + hl2 +"/"+ " --app-name " + app_name +" --frame-num " + str(frame_no) + " --save-util-time" + knob_str
				print("Executing Timegraph: ",cmd)
				os.system(cmd)
			else:
				tg_app_name=app_name+"___new"
				if (not tg_app_name+".Timegraph.gz" in wl_list):
					continue
				os.system("mkdir -p " + hl2)
				cmd = tgp + " --flat-input-path " + i_dir + "/"  + " --output-path " + hl2 +"/"+ " --app-name " + tg_app_name +" --frame-num " + str(frame_no) + " --save-util-time" + knob_str 
				print("Executing Timegraph: ",cmd)
				os.system(cmd)'''
		print("\n#####Done executing######\n")
		os.system("rm -f " + hl2 + "/*.pdf")
		
	def modify_psimTGFile_new(self, knob_dict):
		#@Definitions####
		mini_dict = {}
		for i in self.modify_knobs:
			mini_dict[i] = knob_dict[i]
##########################################################################################################################################################################################
		conf = mini_dict['target-config']
		o_dir = mini_dict['output-path-modified']+ "/"
		i_dir_base = mini_dict['input-path-base'] + "/"
		i_dir_target = mini_dict['target-file']
######################################################################################################################################################################################
		
		
		generation ={'ats':"Gen12HP",'tgl':"Gen12LP"}
		target_dict = OrderedDict()
		
		gen = generation[conf.split("_")[0]]
		targ_arch = open(i_dir_target,"r")
		targ_arch_yaml = yaml.load(targ_arch)
		target_dict = targ_arch_yaml[gen]['fps']
		
		neu=targ_arch_yaml[gen]['n_EU']
		nSubSlice=targ_arch_yaml[gen]['n_SubSlices']
		nSlices=targ_arch_yaml[gen]['n_Slices']
		nRows = targ_arch_yaml[gen]['n_Rows']
		neut = neu*nRows*nSlices*nSubSlice
		freq_t = targ_arch_yaml[gen]['Frequency']
		
		
		os.system("mkdir -p "+o_dir)
		base_dict = OrderedDict()
		
		
		base= os.listdir(i_dir_base)
		base_dir=[]
		for iter in base:
			if (iter.endswith(".stat.gz")):
				base_dir.append(iter)
	
		c1 = 0
		c2 = 0
		###find the common frames across the base and target configs and store them in a list
		for row in (base_dir):	
			
			pth = i_dir_base
			if pth in base_dict:
				base_dict[pth].append(row)
			else:
				base_dict[pth] = [row]
		
		'''for row in target_dir:
			
			pth = i_dir_target
			if pth in target_dict:
				target_dict[pth].append(row)
			else:
				target_dict[pth] = []'''
		b_dict = OrderedDict()
		t_dict = OrderedDict()
		for wl in [str(item) for item in target_dict.keys()]:
			x = re.search('f[0-9]+', wl)
			if x:
				x = x.group(0).strip()
				t_dict[x] = target_dict[wl]
				
		
		for wl in base_dict:
			for f in base_dict[wl]:
				x = re.search('f[0-9]+', f)
				if x:
					x = x.group(0).strip()
					b_dict[x] = f
		for fr in b_dict:
			if fr in t_dict:
				###Now do the things here: for Base
				#freq_b_cmd = "zgrep '^knob.CrClock.multiplier' " + b_dict[fr] + "/psim.stat.gz"
				clk_b_cmd = "zgrep '^CrClock.Clocks ' " + i_dir_base +"/" +b_dict[fr]
				#freq_b = self.cmdline(freq_b_cmd)
				#freq_b = float(re.search("[0-9]+", freq_b).group(0))
				clk_b = self.cmdline(clk_b_cmd)
				clk_b = int(re.search("[0-9]+", clk_b).group(0))
				#fps_b = (freq_b * (10**6)) / clk_b
				ns_cmd = "zgrep '^knob.global.NumSlices' " + i_dir_base +"/" +b_dict[fr]
				ns_res = self.cmdline(ns_cmd).split()
				nsb = float(ns_res[1].strip())
				nss_cmd = "zgrep '^knob.S0.NumSubSlices' " + i_dir_base +"/" +b_dict[fr]
				nss_res = self.cmdline(nss_cmd).split()
				nssb = float(nss_res[1].strip())
				nr_cmd = "zgrep '^knob.S0.SS0.NumRows' " +i_dir_base +"/" + b_dict[fr]
				nr_res = self.cmdline(nr_cmd).split()
				nrb = float(nr_res[1].strip())
				neu_cmd = "zgrep '^knob.S0.SS0.R0.NumEus' " +i_dir_base +"/" + b_dict[fr]
				neu_res = self.cmdline(neu_cmd).split()
				neub = float(neu_res[1].strip())
				neub = neub * nrb * nssb * nsb
				####Now do the things here: for Target
				
				fps_t = t_dict[fr]
				clk_t = (freq_t * (10**6)) / fps_t
				print("N_EUB: %s N_EUT: %s \n" % (neub, neut))
				#find fps ratio
				#r1 = (fps_t / freq_t) / (fps_b / freq_b)
				
				###This is what we need to input manually using a file
				r2 = (clk_b / clk_t) * (neub / neut)
				print("eur: ", neub/neut)
				print("clkr: ",clk_b/ clk_t)
				###invert the ratio
				r2 = float(1 / r2)
				print("TG scaling: ", r2)
				##Now create paths to base and target files
				base_file = i_dir_base +"/" +b_dict[fr].split(".stat.gz")[0]+".Timegraph.gz"
				target_file = o_dir +"/" +b_dict[fr].split(".stat.gz")[0]+".Timegraph.gz"
				print("\nModifying ....",base_file)
				print("To....", target_file)
				print("\n")
				##Retain the original file
				cmd = "cp " + base_file + " " + target_file
				os.system(cmd)
				os.system("gunzip -f " + target_file)
				target_text = target_file.replace(".gz", "")
				target_csv = target_file.replace("gz", "csv")
				os.system("sed 's/\t/,/g' " + target_text +" > " + target_csv)
				os.system("cp "+i_dir_base + "/" + b_dict[fr] + " " + o_dir)
				print("tg_interval_scalar: ", r2)
				r = csv.reader(open(target_csv, 'r')) # Here your csv file
				lines = list(r)
				for i in range(1,len(lines)):
					number = float(lines[i][1]) * r2
					deci_numb = float(str(number-int(number))[1:] )
					if deci_numb > 0.5:
						lines[i][1] = math.ceil(number)
					else:
						lines[i][1] = math.floor(number)
				writer = csv.writer(open(o_dir +'/temp.csv', 'w'))
				writer.writerows(lines)
				os.system("sed 's/,/\t/g' " + o_dir +"/temp.csv > " + target_text)
				#os.system('rm ' + target_csv)		 
				os.system('gzip ' + target_text)
				print("#############Done generating modified timegraph files##############")
		os.system("rm "+ o_dir + "/*.Timegraph.csv")

	def modify_psimTGFile(self, knob_dict):
		#@Definitions####
		mini_dict = {}
		for i in self.modify_knobs:
			mini_dict[i] = knob_dict[i]
##########################################################################################################################################################################################
		i_dir_base = mini_dict['input-path-base'] + "/tests/"
		i_path_base = i_dir_base + str(self.cmdline("ls " + i_dir_base).strip())
		i_dir_target = mini_dict['input-path-target'] + "/tests/"
		i_path_target = i_dir_target + str(self.cmdline("ls " + i_dir_target).strip())
######################################################################################################################################################################################

		ib_csv = knob_dict['input-path-base'] + "/data/summary.csv"
		it_csv = knob_dict['input-path-target'] + "/data/summary.csv"
		data_ft = pd.read_csv(it_csv,error_bad_lines=False)
		data_fb = pd.read_csv(ib_csv,error_bad_lines=False)
		base_dict = OrderedDict()
		target_dict = OrderedDict()
		c1 = 0
		c2 = 0
		###find the common frames across the base and target configs and store them in a list
		for row in range(len(data_fb)):	
			result = data_fb.iloc[row, data_fb.columns.get_loc('result')].strip()
			if result == 'ran' or result == 'passed' :
				c1 += 1
				#x = data_fb.iloc[row, data_fb.columns.get_loc('test_args')].strip()
				#base_list.append(x)
				pth = data_fb.iloc[row, data_fb.columns.get_loc('test')].strip()
				pth = pth.split("_")[0]
				pth2 = data_fb.iloc[row, data_fb.columns.get_loc('path')].strip()
				pth2 = pth2.replace('/', '_')
				pth = pth2 + '_' + pth
				test_dir = data_fb.iloc[row, data_fb.columns.get_loc('test_dir')].strip()
				if pth in base_dict:
					base_dict[pth].append(i_dir_base + "/" + test_dir)
				else:
					base_dict[pth] = []
		for row in range(len(data_ft)):
			result = data_ft.iloc[row, data_ft.columns.get_loc('result')].strip()
			if result == 'ran' or result == 'passed' :
				c2 += 1
				pth = data_ft.iloc[row, data_ft.columns.get_loc('test')].strip()
				pth = pth.split("_")[0]
				pth2 = data_ft.iloc[row, data_ft.columns.get_loc('path')].strip()
				pth2 = pth2.replace('/', '_')
				pth = pth2 + '_' + pth
				test_dir = data_ft.iloc[row, data_ft.columns.get_loc('test_dir')].strip()
				if pth in target_dict:
					target_dict[pth].append(i_dir_target + "/" + test_dir)
				else:
					target_dict[pth] = []
		b_dict = OrderedDict()
		t_dict = OrderedDict()
		for wl in target_dict:
			for f in target_dict[wl]:
				x = re.search('f[0-9]+', f)
				if x:
					x = x.group(0).strip()
					t_dict[x] = f
		for wl in base_dict:
			for f in base_dict[wl]:
				x = re.search('f[0-9]+', f)
				if x:
					x = x.group(0).strip()
					b_dict[x] = f
		for fr in t_dict:
			if fr in b_dict:
			
				###Now do the things here: for Base
				#freq_b_cmd = "zgrep '^knob.CrClock.multiplier' " + b_dict[fr] + "/psim.stat.gz"
				clk_b_cmd = "zgrep '^CrClock.Clocks ' " + b_dict[fr] + "/psim.stat.gz"
				#freq_b = self.cmdline(freq_b_cmd)
				#freq_b = float(re.search("[0-9]+", freq_b).group(0))
				clk_b = self.cmdline(clk_b_cmd)
				clk_b = int(re.search("[0-9]+", clk_b).group(0))
				#fps_b = (freq_b * (10**6)) / clk_b
				ns_cmd = "zgrep '^knob.global.NumSlices' " + b_dict[fr] + "/psim.stat.gz"
				ns_res = self.cmdline(ns_cmd).split()
				nsb = float(ns_res[1].strip())
				nss_cmd = "zgrep '^knob.S0.NumSubSlices' " + b_dict[fr] + "/psim.stat.gz"
				nss_res = self.cmdline(nss_cmd).split()
				nssb = float(nss_res[1].strip())
				nr_cmd = "zgrep '^knob.S0.SS0.NumRows' " + b_dict[fr] + "/psim.stat.gz"
				nr_res = self.cmdline(nr_cmd).split()
				nrb = float(nr_res[1].strip())
				neu_cmd = "zgrep '^knob.S0.SS0.R0.NumEus' " + b_dict[fr] + "/psim.stat.gz"
				neu_res = self.cmdline(neu_cmd).split()
				neub = float(neu_res[1].strip())
				neub = neub * nrb * nssb * nsb
				####Now do the things here: for Target
				#freq_t_cmd = "zgrep '^knob.CrClock.multiplier' " + t_dict[fr] + "/psim.stat.gz"
				clk_t_cmd = "zgrep '^CrClock.Clocks ' " + t_dict[fr] + "/psim.stat.gz"
				#freq_t = self.cmdline(freq_t_cmd)
				#freq_t = float(re.search("[0-9]+", freq_t).group(0))
				clk_t = self.cmdline(clk_t_cmd)
				clk_t = int(re.search("[0-9]+", clk_t).group(0))
				#fps_t = (freq_t * (10**6)) / clk_t
				ns_cmd = "zgrep 'knob.global.NumSlices' " + t_dict[fr] + "/psim.stat.gz"
				ns_res = self.cmdline(ns_cmd).split()
				nst = float(ns_res[1].strip())
				nss_cmd = "zgrep '^knob.S0.NumSubSlices' " + t_dict[fr] + "/psim.stat.gz"
				nss_res = self.cmdline(nss_cmd).split()
				nsst = float(nss_res[1].strip())
				nr_cmd = "zgrep '^knob.S0.SS0.NumRows' " + t_dict[fr] + "/psim.stat.gz"
				nr_res = self.cmdline(nr_cmd).split()
				nrt = float(nr_res[1].strip())
				neu_cmd = "zgrep '^knob.S0.SS0.R0.NumEus' " + t_dict[fr] + "/psim.stat.gz"
				neu_res = self.cmdline(neu_cmd).split()
				neut = float(neu_res[1].strip())
				neut = neut * nrt * nsst * nst
				print("N_EUB: %s N_EUT: %s \n" % (neub, neut))
				#find fps ratio
				#r1 = (fps_t / freq_t) / (fps_b / freq_b)
				r2 = (clk_b / clk_t) * (neub / neut)
				print("eur: ", neub/neut)
				print("clkr: ",clk_b/ clk_t)
				###invert the ratio
				r2 = float(1 / r2)
				print("TG scaling: ", r2)
				##Now create paths to base and target files
				base_file = b_dict[fr] + "/psim_Timegraph.txt.gz"
				target_file = b_dict[fr] + "/psim_Timegraph_" + mini_dict['target-config'].replace('.cfg', '') + ".txt.gz"
				print("\nModifying ....",base_file)
				print("To....", target_file)
				print("\n")
				##Retain the original file
				cmd = "cp " + base_file + " " + target_file
				os.system(cmd)
				os.system("gunzip " + target_file)
				target_text = target_file.replace("txt.gz", "txt")
				target_csv = target_file.replace("txt.gz", "csv")
				os.system("sed 's/\t/,/g' " + target_text +" > " + target_csv)
				print("tg_interval_scalar: ", r2)
				r = csv.reader(open(target_csv, 'r')) # Here your csv file
				lines = list(r)
				for i in range(1,len(lines)):
					number = float(lines[i][1]) * r2
					deci_numb = float(str(number-int(number))[1:] )
					if deci_numb > 0.5:
						lines[i][1] = math.ceil(number)
					else:
						lines[i][1] = math.floor(number)
				writer = csv.writer(open(b_dict[fr] + '/temp.csv', 'w'))
				writer.writerows(lines)
				os.system("sed 's/,/\t/g' " + b_dict[fr] + "/temp.csv > " + target_text)
				#os.system('rm ' + target_csv)		 
				os.system('gzip ' + target_text)
				print("#############Done generating modified timegraph files##############")

	def copyGsimStatFiles(self, mini_dict):	

		cmd_dict = OrderedDict()
		alp = mini_dict['alps-path']
		i_dir = mini_dict['gsim-output-path'] + "/tests/"
		i_csv = mini_dict['gsim-output-path'] + "/data/summary.csv"
		o_path = mini_dict['alps-output-path'] + "/"
		if not os.path.isdir(o_path):
			os.system("mkdir -p " + o_path)
		data_f = pd.read_csv(i_csv,error_bad_lines=False)
		sel_dict = OrderedDict()
		###IF TG is not already run
		if self.knob_dict['run-tg'] != 'true':
			level_wl_dict = OrderedDict()
			for row in range(len(data_f)):		
				pth = data_f.iloc[row, data_f.columns.get_loc('test')].strip()
				pth = pth.split("_")[0]
				pth2 = data_f.iloc[row, data_f.columns.get_loc('path')].strip()
				pth2 = pth2.replace('/', '_')
				result = data_f.iloc[row, data_f.columns.get_loc('result')].strip()
				error_info = data_f.iloc[row, data_f.columns.get_loc('error_info')]
				pth = pth2 + '_' + pth
				lvl_string = data_f.iloc[row, data_f.columns.get_loc('level_name')]
				lvl = (lvl_string.split('/'))[-1].strip()
				if result == 'passed' or result == 'ran':
					if lvl in level_wl_dict:
						level_wl_dict[lvl].add(pth)
					else:
						level_wl_dict[lvl] = set()
				####to set the status to 'passed' for wls with status = 'failed' but with mismatch gold less than 10% abs.
				elif result== 'failed':
					if error_info.startswith("mismatch"):
						error_value=error_info.replace(')','(').split('(')
						if (len(error_value)>1):
							if (float(error_value[1]) > -10 and float(error_value[1]) < 10):
								data_f[row, data_f.columns.get_loc('result')]='passed'
			lvl_list = list(level_wl_dict.keys())
			lvl_index = 1
			print("###################The list of Available Levels###################\n")
			max_str = max(lvl_list, key = len)
			for level in level_wl_dict:
				print('_' * len(max_str))
				print("[%d] %s" % (lvl_index,level))
				lvl_index += 1
			print('_' * len(max_str))
			inp_m = input("\nEnter comma seperated indices of levels: ")
			l_list = inp_m.split(',')
			for i in l_list:
				print("\n##################The workloads available under this level################# ")
				key = lvl_list[int(i)-1]
				j = 1
				set_list = list(level_wl_dict[key])
				set_l = max(set_list, key = len)
				for p in set_list:
					print('_' * len(set_l))
					print("[%d] %s" % (j, p))
					j += 1
				print('_' * len(set_l))
				inp_s = input("\nEnter comma seperated indices of workloads: ")
				s_list = inp_s.split(',')
				sel_dict[key] = []
				for k in s_list:
					sel_dict[key].append(set_list[int(k)-1])
			print("\n####################The list of workloads you selected##################\n")
			for sel in sel_dict:
				print("-----------------Level Name-----------------\n", sel)
				print("--------------------------------------------\n")
				for wl in sel_dict[sel]:
					print(wl)
				print("\n")
		else:
			sel_dict = self.glob_sel_dict
		in_lev_wl_dict = OrderedDict()
		op_lev_wl_dict = OrderedDict()
		for lev in sel_dict:
			lev_dir = o_path 
			#os.system("if test -d "+ lev_dir + "; then rm -r "+ lev_dir + "; fi")
			os.system("mkdir "+lev_dir)
			#print("Level dir: %s created" %lev_dir)
			if lev_dir in op_lev_wl_dict:
				for wl in sel_dict[lev]:
					wl_dir = wl + "/"
					hl2 = lev_dir + wl_dir
					os.system("if test -d "+ hl2 +"; then rm -r "+ hl2 +"; fi")
					os.system("mkdir " + hl2)
					op_lev_wl_dict[lev_dir][wl_dir] = set()
			else:
				op_lev_wl_dict[lev_dir] = OrderedDict()
				for wl in sel_dict[lev]:
					wl_dir = wl + "/"
					hl2 = lev_dir + wl_dir
					os.system("if test -d "+ hl2 +"; then rm -r "+ hl2 +"; fi")
					os.system("mkdir " + hl2)
					op_lev_wl_dict[lev_dir][wl_dir] = set()
					
		count = 0
		for row in range(len(data_f)):
			ll = data_f.iloc[row, data_f.columns.get_loc('level_name')].split("/")
			ll = ll[-1].strip()
			if (not re.match(r"[A-Za-z0-9_-]*f[0-9]+[A-Za-z0-9_-]*",data_f.iloc[row, data_f.columns.get_loc('test')])):
				continue
			test_nm = (data_f.iloc[row, data_f.columns.get_loc('test')]).split("__")[1]
			pth = data_f.iloc[row, data_f.columns.get_loc('test')].strip()
			pth = pth.split("_")[0]
			pth2 = data_f.iloc[row, data_f.columns.get_loc('path')].strip()
			pth2 = pth2.replace('/', '_')
			pth = pth2 + '_' + pth
			if ll in sel_dict and pth in sel_dict[ll]:
				test_path = pth
				fil_nm = test_path + "__" + test_nm + ".stat.gz"
				test_dir = data_f.iloc[row, data_f.columns.get_loc('test_dir')].strip()
				in_dir = i_dir + test_dir + "/"	
				#copying the stat files
				#we need to get the out directory
				wl_dir = pth + "/"
				hl2 = o_path + wl_dir
				os.system("cp " + in_dir +"/psim.stat.gz " + hl2 +"/" + fil_nm)		
				op_lev_wl_dict[o_path][wl_dir].add(hl2 + fil_nm)
				count += 1
		for lev in op_lev_wl_dict:
			for wl in op_lev_wl_dict[lev]:
				os.system("cd " + lev + wl + " && ls *stat.gz > " + lev + wl + "tracelist")
		return op_lev_wl_dict
		####################################################################################################################################

	def runALPS_edited(self, knob_dict):
		mini_dict = {}
		level_name = ""
		for i in self.alps_knobs:
			mini_dict[i] =knob_dict[i]
		alps_path = mini_dict['alps-path']
		op_lev_wl_dict = self.copyGsimStatFiles(mini_dict)
		self.op_lw_dict = op_lev_wl_dict
		#####################################################################################################################################
		
		for lev in op_lev_wl_dict:
			for wl in op_lev_wl_dict[lev]:
				#run ALPS here	 
				a = mini_dict['alps-arch']
				s = " -s " + mini_dict['alps-path']	
				i = " -i " +lev.split("_nfs")[0] + wl + "tracelist"
				o = " -o " +lev.split("_nfs")[0] + wl
				if 'skl' in a:
					alps_cmd = "perl " + alps_path + "/runall_alps.pl" + i + o + s + " -a " + a + " -p sc_normal2" + " -q /VPG/All-VPG/ARCH_HW/PNP"
				else:
					alps_cmd = "perl " + alps_path + "/runall_alps.pl" + i + o + s + " -a " + a + " -p sc_normal2" + " -q /VPG/All-VPG/ARCH_HW/PNP --" + a
				os.system(alps_cmd)
				print("\nRunning ALPS...Generating necessary files...Please Wait...")
				while True:
					time.sleep(7)
					os.system("nbstatus jobs --target sc_normal2 > jobs_status_"+wl[:-1]+".txt")
					if int(self.cmdline("wc -l < jobs_status_"+wl[:-1]+".txt").strip()) == 8:
						break;
				os.system("rm jobs_status_"+wl[:-1]+".txt")
				print("\n############Done Generating ALPS output##############\n")
				#####to get the path from level names and make a new directiry structure as path/wl/idle_active
				os.system("if test -d "+lev.split("_nfs")[0] + wl + "/idle_active/; then rm -r " + lev.split("_nfs")[0] + wl + "/idle_active/; fi")
				os.system("mkdir " +lev.split("_nfs")[0]  + wl + "/idle_active/")
				print("\n########Generating idle_active files########\n")
				os.system("ls "+lev.split("_nfs")[0]+wl)
				ia_path = lev.split("_nfs")[0]+ wl + "idle_active/"
				os.system("ls " + lev.split("_nfs")[0]+ wl + "*.yaml > "+lev.split("_nfs")[0] + wl + "/yaml_list.txt")
				yaml_list = open( lev.split("_nfs")[0]+wl +"/yaml_list.txt", "r")
				yaml_list = [line.split() for line in yaml_list]
				i = 0
				for yaml_file in yaml_list:
					s_file = yaml_file[0]
					s_file=s_file.split(".yaml")[0] + "/"
					ia_cmd = "python " + alps_path + "/idle_active_cdyn.py" + " -f " + yaml_file[0] + " -o " + ia_path + s_file.split("/")[-2] + "/" 
					print("Executing: ")
					os.system(ia_cmd)
					i = i + 1
				os.system("rm "+lev.split("_nfs")[0]+ wl + "/yaml_list.txt")
				#os.system("rm #*")
				print("############Done Generating idle_active.csv files###########\n")	
		######################################################################################################################################
		
	def runALPS(self, knob_dict):
		mini_dict = {}
		level_name = ""
		for i in self.alps_knobs:
			mini_dict[i] =knob_dict[i]
		alps_path = mini_dict['alps-path']
		op_lev_wl_dict = self.copyGsimStatFiles(mini_dict)
		self.op_lw_dict = op_lev_wl_dict
		#####################################################################################################################################
		
		for lev in op_lev_wl_dict:
			for wl in op_lev_wl_dict[lev]:
				#run ALPS here
				a = mini_dict['alps-arch']
				s = " -s " + mini_dict['alps-path']	
				i = " -i " + lev + wl + "tracelist"
				o = " -o " + lev + wl
				if 'skl' in a:
					alps_cmd = "perl " + alps_path + "/runall_alps.pl" + i + o + s + " -a " + a + " -p sc_normal2" + " -q /VPG/All-VPG/ARCH_HW/PNP"
				else:
					alps_cmd = "perl " + alps_path + "/runall_alps.pl" + i + o + s + " -a " + a + " -p sc_normal2" + " -q /VPG/All-VPG/ARCH_HW/PNP --" + a
				#perl $alps/runall_alps.pl -i tracelist -o . -a icllp -s $alps -p sc_normal2 -q /VPG/All-VPG/ARCH_HW/PNP --icllp
				os.system(alps_cmd)
				print("\nRunning ALPS...Generating necessary files...Please Wait...")
				while True:
					time.sleep(7)
					os.system("nbstatus jobs --target sc_normal2 > jobs_status_"+wl[:-1]+".txt")
					if int(self.cmdline("wc -l < jobs_status_"+wl[:-1]+".txt").strip()) == 8:
						break;
				os.system("rm jobs_status_"+wl[:-1]+".txt")
				print("\n############Done Generating ALPS output##############\n")
				os.system("if test -d "+ lev + wl + "/idle_active/; then rm -r "+ lev + wl + "/idle_active/; fi")
				os.system("mkdir " + lev + wl + "idle_active/")
				print("\n########Generating idle_active files########\n")
				ia_path = lev + wl + "idle_active/"
				os.system("ls " + lev + wl + "/*.yaml > " + lev + wl + "/yaml_list.txt")
				yaml_list = open(lev + wl +"/yaml_list.txt", "r")
				yaml_list = [line.split() for line in yaml_list]
				i = 0
				for yaml_file in yaml_list:
					s_file = re.search("f[0-9]+", yaml_file[0]).group(0).strip() + "/"
					ia_cmd = "python " + alps_path + "/idle_active_cdyn.py" + " -f " + yaml_file[0] + " -o " + ia_path + s_file
					print("Executing: ", ia_cmd)
					os.system(ia_cmd)
					i = i + 1
				os.system("rm " + lev + wl + "/yaml_list.txt")
				#os.system("rm #*")
				print("############Done Generating idle_active.csv files###########\n")	
		######################################################################################################################################
		
	##Utility Function: Taking longer time to execute: has to be optimized!
	def Utility1(self, csv_file,txt_file, target_config):
		mapping = {'GEOM':'Num_Geom','WM':'Num_WM','DepthZ':'Num_DepthZ','EU_IPC':'Num_EUs','PSD':'Num_PSD','ROWBUS':'Num_RowBus'
        	     ,'SAMPLER':'Num_Samplers','HDC':'Num_HDCs','L3':'Num_L3','PB':'Num_PBs','TLB':'Num_TLB',
        	     'GTI':'Num_GTI','MEM':'Num_Mem','SBE':'Num_SBE'}    
		cluster_wise_reqd = ['GEOM','WM','DepthZ','EU_IPC','PSD','ROWBUS','SAMPLER','HDC',
                		   'L3','PB','TLB','GTI','MEM','SBE']    
		instances = {}    
		col_wise_file_dict = {}
		row_wise_file_dict = {}
		cluster_stat = {}
		time_list = []
		row_wise_file_list = []
		config = ""
		for line in txt_file:
			l = line.split(':')
			instances[l[0].strip()] = l[1].strip('\n').strip('\t')
		config = instances['Config'].replace('.cfg','')
		next(csv_file)
		for line in csv_file:
			l = line.split(',')
			row_wise_file_dict[l[0]] = l[1:]
			row_wise_file_list.append(l)
			col_wise_file_zip = zip(*row_wise_file_list)
			for line in col_wise_file_zip:
				if(line[0] == '\n'):
					continue
				col_wise_file_dict[line[0]] = list(line[1:])
		header_list = list(col_wise_file_dict.keys());
		time_list = list(map(float,col_wise_file_dict['Tg_Interval']))
		total_time = sum(time_list)
		for i in cluster_wise_reqd:
			i_list = list(map(float,col_wise_file_dict[i]))
			prod_list = [x * y for x, y in zip(i_list, time_list)]
			#improving utilization of L3 by a scalar
			if 'icl' in config and i == 'L3':
				total_active_util = ((sum(prod_list)/total_time)/100) * 4.0
			else: 
				total_active_util = (sum(prod_list)/total_time)/100
			total_inactive_util = 1-total_active_util
			if(total_active_util > 1):
				total_active_util = 1
				total_inactive_util = 0
			n_value = mapping[i]
			num_instances = instances.get(n_value)
			sub_dict = {}
			sub_dict['active_util'] = total_active_util
			sub_dict['inactive_util'] = total_inactive_util
			##Remove this hardcoding
			sub_dict['process_sf'] = 1
			sub_dict['active_idle_cdyn_wt_ratio'] = 1
			##This is a tricky part and has to be handled and removed
			if i == 'L3':
				if config == 'skl_gt2':
					sub_dict['num_instances'] = 4
					sub_dict['scaling_factor'] = 6
				elif config == 'skl_gt3':
					sub_dict['num_instances'] = 4
					sub_dict['scaling_factor'] = 8
				#elif 'icl' in config:
				#	sub_dict['num_instances'] = 8
				#	sub_dict['scaling_factor'] = 1
				else:
					sub_dict['num_instances'] = float(num_instances)
					sub_dict['scaling_factor'] = 1
			else:
				sub_dict['num_instances'] = float(num_instances)
				sub_dict['scaling_factor'] = 1
			cluster_stat[i] = sub_dict
		csv_file.close()
		txt_file.close()
		target_config = target_config.replace('.cfg','')
		return {'cluster_stat':cluster_stat, 'cfg':target_config}
		
	##Utility Function
	def Utility2(self, f):
		for i,line in enumerate(f):
			if(i==1):
				l=line.split(':')
				cdyn=l[1].strip('\n')
				cdyn=cdyn.strip(' ')
				f.close()
				return {'cdyn':float(cdyn)}
	##Utility Function
	def Utility3(self, ipf,cdyn_flag, target_config):
		data_index =  1
		data_dict= OrderedDict()
		###Temporary hardcoding: Remove it
		sp_scf = {}
		sp_scf['sklgt2_rest'] = [[1.0, 1.0],[1.726,2.1809],[2.236,3.299]]
		sp_scf['sklgt2'] = [1.0, 1.849, 2.5236]
		sp_scf['icl_rest'] = [[1.0, 1.0], [1.0, 1.0]]
		sp_scf['icl'] = [1.0, 1.0]
		ip_file = open(ipf, "r")
		for line in ip_file:
			l=line.split(',')
			cdyn_file=l[0]
			util_file=l[1]
			num_inst_file=l[2].strip('\n')
			frame_name=util_file.split("/")[-2]
			if cdyn_flag:
				f=open(cdyn_file,'r')
				cdyn = self.Utility2(f)
			else:
				cdyn = {'cdyn':0}
			f=open(util_file,'r')
			g=open(num_inst_file,'r')
			util = self.Utility1(f,g, target_config)
			data_dict["Data_"+str(data_index)] = {'frame_name':frame_name}
			data_dict["Data_"+str(data_index)].update(sp_scf)
			data_dict["Data_"+str(data_index)].update(cdyn)
			data_dict["Data_"+str(data_index)].update(util)
			data_index = data_index+1
		ip_file.close()
		return data_dict
		
	def execHLPM(self, knob_dict):
		mini_dict = {}
		for i in self.hlpm_only_knobs:
			mini_dict[i] = knob_dict[i]
		inp_path = mini_dict['hlpm-input'] + '/'
		op_path = mini_dict['hlpm-output'] + '/'
		id_act_path = mini_dict['idle-act-path'] + '/' +"idle_act_base.txt"
		cfs = mini_dict['cdyn-scalar']
		util_target = inp_path + "util_data.yaml"
		base_cfg = mini_dict['base-cfg']
		target_cfg = mini_dict['target-cfg']
		clusters = ['EU_IPC', 'SAMPLER', 'L3']
		hlpm = HLPM(clusters)
		hlpm.Invoke(util_target, id_act_path, base_cfg, target_cfg, cfs, op_path)
	
	def runHLPM_new(self, knob_dict):
		mini_dict = {}
		for i in self.hlpm_knobs:
			mini_dict[i] = knob_dict[i]
		tg_base = mini_dict['tg-results-base'] + "/"
		tg_target = mini_dict['tg-results-target'] + "/"
		alps_base = mini_dict['alps-output-path-base'] + "/"
		alps_target = mini_dict['alps-output-path-target'] + "/"
		hlpm_output = mini_dict['hlpm-output-path'] + "/"
		if alps_base.strip() == '/' and alps_target.strip() == '/':
			cdyn_flag = False
		else:
			cdyn_flag = True
		if not os.path.isdir(hlpm_output):
			os.system("mkdir -p " + hlpm_output)
		#####iterating over all the workloads available within the directory 
		workloads=os.listdir(tg_base)
		for wl in workloads:
			####workload name is added as a subdirectory within the hlpm_output folder
			hlpm_output_path=hlpm_output +"/"+str(wl)+"/"
			os.system("if test -d "+ hlpm_output_path+"util_data/; then rm -r "+ hlpm_output_path +"util_data/; fi") 
			os.system("if test -d "+ hlpm_output_path +"input_data/; then rm -r "+ hlpm_output_path +"input_data/; fi") 
			os.system("mkdir -p " + hlpm_output_path +"util_data/")
			os.system("mkdir -p " + hlpm_output_path +"input_data/" )
			inp_pre_base = open(hlpm_output_path + "inp_pre_base.txt", "w+")
			inp_pre_target = open(hlpm_output_path + "inp_pre_target.txt", "w+")
			inp_idle_act_base = open(hlpm_output_path + "idle_act_base.txt", "w+")
			os.system("ls " + tg_base+"/"+str(wl)+"/  > " + hlpm_output_path + "/frames.txt")
			f =open(hlpm_output_path + "/frames.txt", 'r')
			frames = [line.split() for line in f]
			print("Processing....\n")
			####iterating over all the frames availbale within a workload
			for frame in frames:
				f_num = re.search('[0-9]+', frame[0]).group(0).strip()
				util_file_base = tg_base+"/"+wl+"/" + str(frame[0]) + "/"
				u_path = self.cmdline("ls " + util_file_base + "*util*").strip()
				util_file_base = u_path
				util_file_target = tg_target +"/"+wl+"/" +str(frame[0]) + "/"
				u_path = self.cmdline("ls " + util_file_target + "*util*").strip()
				util_file_target = u_path
				if '.gz' in util_file_base:
					os.system("gunzip " + util_file_base)
					print("Done extracting ", util_file_base)
					util_file_base = util_file_base.replace("csv.gz", "csv")
				if '.gz' in util_file_target:
					os.system("gunzip " + util_file_target)
					print("Done extracting ", util_file_target)
					util_file_target = util_file_target.replace("csv.gz", "csv")
				inst_file_base = util_file_base.replace("util-time.csv", "instances.txt")
				inst_file_target = util_file_target.replace("util-time.csv", "instances.txt")
				if cdyn_flag:
					y1 = str(self.cmdline("ls " + alps_base + wl +"/" + frame[0].strip() + ".yaml").strip())
					y2 = str(self.cmdline("ls " + alps_base + wl +"/" + frame[0].strip() + ".yaml").strip())
					if (not y1.endswith(".yaml") and not y2.endswith(".yaml")):
						continue
					idle_act_base = alps_base + wl + "/idle_active/" + str(frame[0]) + "/idle_active_cdyn.csv"
					s_write_base = y1.strip() + "," + util_file_base + "," + inst_file_base
					s_write_target = y2.strip() + "," + util_file_target + "," + inst_file_target
				else:
					idle_act_base = alps_base + wl + "/idle_active/" + str(frame[0]) + "/idle_active_cdyn.csv"
					s_write_base = "," + util_file_base + "," + inst_file_base
					s_write_target = "," + util_file_target + "," + inst_file_target	
				
				if frame == frames[-1]:
					inp_pre_base.write(s_write_base)
					inp_pre_target.write(s_write_target)		
					inp_idle_act_base.write(idle_act_base)
				else:
					inp_pre_base.write(s_write_base + "\n")
					inp_pre_target.write(s_write_target + "\n")
					inp_idle_act_base.write(idle_act_base + "\n")
			f.close()
			print("Generating Avg Utilization Yaml Data.....Please Wait.....")
			inp_pre_base.close()
			inp_pre_target.close()
			inp_idle_act_base.close()
			cb = self.knob_dict['base-conf']
			ct = self.knob_dict['target-conf']
			data_dict_base = self.Utility3(hlpm_output_path + "/inp_pre_base.txt",cdyn_flag, ct)
			#data_dict_target = self.Utility3("inp_pre_target.txt")
			print("Done Preprocessing!")
			util_data = open(hlpm_output_path + "util_data/" + "util_data.yaml", "w+")
			#util_data_target = open(hlpm_output_path + "util_data/" + "util_data_target.yaml", "w+") 
			yaml.dump(data_dict_base, util_data, default_flow_style=False)
			#yaml.dump(data_dict_target, util_data_target, default_flow_style=False)
			print("\n############Done generating utilization data###########\n")
			inp_idle_act_base.close()
			util_data.close()
			#util_data_target.close()
			os.system("mv " + hlpm_output_path + "inp_pre* " + hlpm_output_path + "input_data/")
			os.system("mv " + hlpm_output_path + "idle_act_base.txt " + hlpm_output_path + "input_data/")
			os.system("rm " + hlpm_output_path + "frames.txt")
			ut = hlpm_output_path + "util_data/" + "util_data.yaml"
			ib = hlpm_output_path + "input_data/idle_act_base.txt"
			sf = self.knob_dict['cdyn-factor-scalar']
			op_path = hlpm_output_path + "util_data/"

	def runHLPM(self, knob_dict):
		mini_dict = {}
		for i in self.hlpm_knobs:
			mini_dict[i] = knob_dict[i]
		tg_base = mini_dict['tg-results-base'] + "/"
		tg_target = mini_dict['tg-results-target'] + "/"
		alps_base = mini_dict['alps-output-path-base'] + "/"
		alps_target = mini_dict['alps-output-path-target'] + "/"
		hlpm_output = mini_dict['hlpm-output-path'] + "/"
		if not os.path.isdir(hlpm_output):
			os.system("mkdir -p " + hlpm_output)
		inp_pre_base = open(hlpm_output + "inp_pre_base.txt", "w+")
		inp_pre_target = open(hlpm_output + "inp_pre_target.txt", "w+")
		inp_idle_act_base = open(hlpm_output + "idle_act_base.txt", "w+")
		os.system("ls " + tg_base + " > " + hlpm_output + "/frames.txt")
		f =open(hlpm_output + "/frames.txt", 'r')
		frames = [line.split() for line in f]
		#print(frames)
		print("Processing....\n")
		for frame in frames:
			f_num = re.search('[0-9]+', frame[0]).group(0).strip()
			util_file_base = tg_base + frame[0] + "/"
			util_file_base = util_file_base + str(self.cmdline("ls " + util_file_base).strip()) + "/"
			b_path = self.cmdline("ls -d " + util_file_base + "*/").strip()
			u_path = self.cmdline("ls " + b_path + "*util*").strip()
			util_file_base = u_path
			util_file_target = tg_target + frame[0] + "/"
			util_file_target = util_file_target + str(self.cmdline("ls " + util_file_target).strip()) + "/"
			t_path = self.cmdline("ls -d " + util_file_target + "*/").strip() + "/"
			u_path = self.cmdline("ls " + t_path + "*util*").strip()
			util_file_target = u_path
			if '.gz' in util_file_base:
				os.system("gunzip " + util_file_base)
				print("Done extracting ", util_file_base)
				util_file_base = util_file_base.replace("csv.gz", "csv")
			if '.gz' in util_file_target:
				os.system("gunzip " + util_file_target)
				print("Done extracting ", util_file_target)
				util_file_target = util_file_target.replace("csv.gz", "csv")
			inst_file_base = util_file_base.replace("util-time.csv", "instances.txt")
			inst_file_target = util_file_target.replace("util-time.csv", "instances.txt")
			b_dir_list = os.listdir(str(alps_base)) 
			t_dir_list = os.listdir(str(alps_target))
			for dirc in b_dir_list:	
				s1_path = "/" + alps_base + dirc
				y1 = str(self.cmdline("ls " + s1_path + "/*/*f" + str(f_num) + "*.yaml").strip())
				if  y1.endswith('.yaml'):
					b_dir = dirc
					break
			for dirc in t_dir_list:
				s2_path = "/" + alps_target + dirc
				y2 = str(self.cmdline("ls " + s2_path + "/*/*" + str(f_num) + "*.yaml").strip())
				if y2.endswith('yaml'):
					t_dir = dirc
					break
			jk1 = (y1.split('/'))[-2]
			idle_act_base = alps_base + b_dir + jk1 + "/idle_active/" + frame[0] + "/idle_active_cdyn.csv"
			s_write_base = y1.strip() + "," + util_file_base + "," + inst_file_base
			s_write_target = y2.strip() + "," + util_file_target + "," + inst_file_target
			if frame == frames[-1]:
				inp_pre_base.write(s_write_base)
				inp_pre_target.write(s_write_target)		
				inp_idle_act_base.write(idle_act_base)
			else:
				inp_pre_base.write(s_write_base + "\n")
				inp_pre_target.write(s_write_target + "\n")
				inp_idle_act_base.write(idle_act_base + "\n")
		print(len(frames))	
		f.close()
		print("Generating Avg Utilization Yaml Data.....Please Wait.....")
		inp_pre_base.close()
		inp_pre_target.close()
		inp_idle_act_base.close()
		data_dict_base = self.Utility3(hlpm_output + "/inp_pre_base.txt")
		#data_dict_target = self.Utility3("inp_pre_target.txt")
		print("Done Preprocessing!")
		os.system("if test -d "+ hlpm_output +"util_data/; then rm -r "+ hlpm_output +"util_data/; fi") 
		os.system("if test -d "+ hlpm_output +"input_data/; then rm -r "+ hlpm_output +"input_data/; fi") 
		os.system("mkdir " + hlpm_output + "util_data/")
		os.system("mkdir " + hlpm_output + "input_data/" )
		util_data_base = open(hlpm_output + "util_data/" + "util_data_base.yaml", "w+")
		yaml.dump(data_dict_base, util_data_base, default_flow_style=False)
		print("\n############Done generating utilization data###########\n")
		inp_idle_act_base.close()
		util_data_base.close()
		os.system("mv " + hlpm_output + "/inp_pre* " + hlpm_output + "input_data/")
		os.system("mv " + hlpm_output + "/idle_act_base.txt " + hlpm_output + "input_data/")
		os.system("rm " + hlpm_output + "frames.txt")
		os.system("cp " + hlpm_output + "util_data/" + "util_data_base.yaml " + hlpm_output + "util_data/" + "util_data_target.yaml")
		ub = hlpm_output + "util_data/" + "util_data_base.yaml"
		ut = hlpm_output + "util_data/" + "util_data_target.yaml"
		ib = hlpm_output + "input_data/idle_act_base.txt"
		cb = self.knob_dict['base-conf']
		ct = self.knob_dict['target-conf']
		sf = self.knob_dict['cdyn-factor-scalar']
		op_path = hlpm_output + "util_data/"

	def parse_knobs(self,f):
		all_knobs = []
		all_knobs.append(self.tg_knobs)
		all_knobs.append(self.modify_knobs)
		all_knobs.append(self.alps_knobs)
		all_knobs.append(self.hlpm_knobs)
		all_knobs.append(self.hlpm_only_knobs)
		for line in f:
			line = line.strip()
			if line.startswith('#') or not line:
				continue;
			knob = line.split(':')
			self.knob_dict[knob[0].strip()] = knob[1].strip()
		missing_knobs = []
		i = 0
		print("\n##############KNOBS PROVIDED##############\n")
		for m_knob in self.main_knobs:
			if m_knob in self.knob_dict and self.knob_dict[m_knob] == 'true':
				self.control_block[i] = True
				print(all_knobs[i])
				for knb in all_knobs[i]:					
					if knb in self.knob_dict and self.knob_dict[knb]:
						print("%s: %s" % (knb, self.knob_dict[knb]))
					else:
						if knb not in ['alps-output-path-base', 'alps-output-path-target']:
							missing_knobs.append(knb)
				print("\n")
			elif m_knob in self.knob_dict and self.knob_dict[m_knob] == 'false':
				for knb in all_knobs[i]:
					print(knb)
					if knb in self.knob_dict and self.knob_dict[knb]:
						self.knob_dict.pop(knb)
			i = i + 1
		print("\n")
		if len(missing_knobs) != 0:
			print("Error: Please add the following knobs to input.txt")
			print(missing_knobs)
			sys.exit()
		for tf in range(len(self.control_block)):
			if self.control_block[tf] == True:
				self.call_list[tf](self.knob_dict)
		
	#####Constructor#####
	def __init__(self, f):
		self.call_list = [self.generateTG_new, self.modify_psimTGFile_new, self.runALPS_edited, self.runHLPM_new, self.execHLPM]
		self.parse_knobs(f)

########MAIN Function############
if __name__ == '__main__':
	
	parser = argparse.ArgumentParser()
	parser.add_argument("--input", "-i", type=str, required=True)
	args = parser.parse_args()
	fn = args.input
	f = open(fn, 'r')
	data = Data(f)
