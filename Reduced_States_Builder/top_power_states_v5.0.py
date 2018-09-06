# -*- coding: utf-8 -*-
"""
Created on Thu Jul 13 12:36:31 2017

@author: santoshn
"""

# Import all libraries needed for the tutorial
# General syntax to import specific functions in a library: 
##from (library) import (specific library function)
from pandas import DataFrame, read_csv
# General syntax to import a library but no functions: 
##import (library) as (give the library a nickname/alias)
import matplotlib.pyplot as plt
import pandas as pd #this is how I usually import pandas
import csv # CSV package
import sys #only needed to determine Python version number
import matplotlib #only needed to determine Matplotlib version number
import numpy as np
import statsmodels.api as sm
from matplotlib.backends.backend_pdf import PdfPages

# Enable inline plotting
#matplotlib inline


# For each frame, sum up all the Cdyn values that add up to 95% of the total 
# power for the frame. Take out only those power states that contribute to 95% 
# of total power.
# Return the power states & corresponding Cdyn values
## Input parameters: 
##     1. Cdyn_data : Dataframe consisting of the entire frames & Cdyn values
##     2. unit_name : UNit of analysis
##     3. frame_name: String that identifies the frame
##     4. power_threshold_limit: Percentage of total power that is used as the basis 
##                               for a threshold limit    
    
def top_power_states_per_frame(Cdyn_data, unit_name, frame_name, power_threshold):
    Frame_Cdyn_data = Cdyn_data.loc[Cdyn_data[unit_name] == frame_name]
    Test_sum = Frame_Cdyn_data['Cdyn'].sum()
    Frame_Cdyn_data['Cdyn'] /= Frame_Cdyn_data['Cdyn'].sum()
    Sorted_Cdyn_data = Frame_Cdyn_data.sort_values(by='Cdyn', ascending=False)
    power_states = Sorted_Cdyn_data.loc[Sorted_Cdyn_data['Cdyn'].cumsum() 
                  <= power_threshold,['Power State','Cdyn']]
    unique_power_states = power_states.drop_duplicates(['Power State'])
    return(power_states)

# For each workload, sum up all the Cdyn values that add up to 95% of the total 
# power for that workload. Take out only those power states that contribute to 95% 
# of total power.
# Returns the power states & corresponding Cdyn values
## Input parameters: 
##     1. Cdyn_data : Dataframe consisting of the entire frames & Cdyn values
##     2. power_threshold_limit: Percentage of total power that is used as the basis 
##                               for a threshold limit    
    
def top_power_states_per_workload(Cdyn_data, power_threshold):
    col_names = Cdyn_data.columns.values
    workload = col_names[1]
    Test_sum = Cdyn_data[workload].sum()
    Cdyn_data[workload] /= Cdyn_data[workload].sum()
    Sorted_Cdyn_data = Cdyn_data.sort_values(by= workload, ascending=False)
    power_states = Sorted_Cdyn_data.loc[Sorted_Cdyn_data[workload].cumsum() 
                  <= power_threshold,[col_names[0], col_names[1]]]
    unique_power_states = power_states.drop_duplicates([col_names[0]])
    # Define the Regex keys to uniquely identify the infrastructure states
    # Any state that ends with these partial strings are infra states
    infra_state_keys = {'Assign$', 'CLKGLUE$', 'CPUnit$', 'DFX$', 'DOP$', 'NONCLKGLUE$', 'Repeater$', 'SMALL$'}
    #Extract the infra power states from the workload level reduced power states
    #Partial string match in any of the strings in infra_state_keys will extract that row
    infra_power_states = unique_power_states[unique_power_states[col_names[0]].str.contains('|'.join(infra_state_keys))]
    #Calculate the Average Cdyn value of the Infra power states
    num_infra_states = len(infra_power_states)    
    infra_cdyn = infra_power_states[col_names[1]].sum()
    return(power_states, infra_power_states, infra_cdyn)


########################################################################################        
## Function name: top_level_power_states_analysis_for_all_workloads
## Description: Performs the analysis of power states at the granularity of the
##              a workload and identifies the the crucial power states in each unit. 
##              From these unit level power states, an algorithm is applied to 
##              combine and select a global list that is capable of charatectizing 
##              any individual unit.
## Input parameters:
##            1. Cdyn_data --- Dataframe/CSV file contain all the power data
##            2. unit_threshold --- Fraction of total Cdyn value to be used as 
##                                  as a stop criterion
##            3. global_threshold --- Threshold used for combining unit level data
##            4. <split>  - Ratio of split between training and test WLs. Default is no split
## Output parameters:
##            1. final power states
##            2. Average error estimate (error averaged across all workloads)
##            3. Std. deviation of the error across all WLs
##            4. Max error across all WLs
##            5. Error estimate in each WL
#####################################################################################

def top_level_power_states_analysis_for_all_workloads(Cdyn_data, unit_threshold, global_threshold, split = None):
    # Extract the power states that contribute to 95% of total Cdyn
    ## Sort the data frame based on Cdyn values
    ## Normalize the Cdyn values by total Cdyn value
    ## Extract the power states that sum up to 0.95 of Total Cdyn
    ## Default there is no split of data into train & test data
    if split is None:
        split = 1.0    
    # Select appropriate level for the analysis
    # Possible choices: Workload
    # The given Dataframe contains the following columns - Cluster, Unit, Power States
    # followed by Cdyn values for each workload
    # Extract the columns names in the dataframe
    Workload_names = Cdyn_data.columns.values
    # Number of WLs eliminating the columns for Cluster, Unit, Power States
    no_of_WL = len(Workload_names)-3
    # Initialize the total power states & counter
    number_power_states = [0]*no_of_WL
    cdyn_per_WL = [0]*no_of_WL
    # Set the number of training WLs and test WLs
    train_frames = round(no_of_WL*split)
    
    # Slice the dataframe and extract the power states and Cdyn values for one workload
    WL_data = Cdyn_data.loc[:, [Workload_names[2],Workload_names[3]]]

    WL_data = WL_data.drop(WL_data.index[0])
    #Rename the columns to 'Power State' and 'Cdyn' to represent the data 
    Workload_data = WL_data.rename(index=str, columns={Workload_names[2]:"Power State", Workload_names[3]: "Cdyn"})

    total_power_states, total_infra_states, infra_cdyn = top_power_states_per_workload(Workload_data, unit_threshold)
    cdyn_per_WL[0] = infra_cdyn*100
    number_power_states[0] = len(total_power_states)
    # Set the number of training frames and test frames
    #train_frames = round(no_of_WL*split)
    train_frames = no_of_WL
    #Iterate through the set of workloads
    #In each iteration, call the function that returns the top power states
    #Concatenate the top power states obtained per frame into a single dataframe
    #Select the combined list of top power states using
    #  1. Select all the common states 
    #  2. In the remaining power states, choose one of three methods to select
    #     additional states
    #      1. Cdyn values greater than a threshold
    #      2. Power states with an occurence frequency greater than a threshold
    #      3. Frequency * Cdyn values greater than a threshold
 
    for i in range(1, train_frames):
        # Slice the dataframe and extract the power states and Cdyn values for one workload
        WL_data = Cdyn_data.loc[:, [Workload_names[2],Workload_names[i+3]]]
        # Drop the superflous first row
        WL_data = WL_data.drop(WL_data.index[0])
        #Rename the columns to 'Power State' and 'Cdyn' to represent the data 
        Workload_data = WL_data.rename(index=str, columns={Workload_names[2]:"Power State", Workload_names[i+3]: "Cdyn"})
        #Obtain the top power states for the specified frame
        frame_power_states, infra_power_states, infra_cdyn = top_power_states_per_workload(Workload_data, unit_threshold)
        #infra_power_states = pd.concat([infra_power_states, infra_cdyn], axis = 0)
        #Count the number of top power states in each frame
        number_power_states[i] = len(frame_power_states)
        cdyn_per_WL[i] = infra_cdyn*100
        #Concatenate the top power states across a frame
        total_power_states = pd.concat([total_power_states, frame_power_states], axis=0)
        #Concatenate the infra power states
        total_infra_states = pd.concat([total_infra_states, infra_power_states], axis=0)
        # Calculate the average number of power states
        avg_power_states = int(np.mean(number_power_states))
    #Select the final list of power states
    final_power_states = top_total_power_states(total_power_states, 2, global_threshold) 
    #Select the final list of infrastructure power states
    #Always use 1 as threshold as no filtering is needed
    final_infra_states = top_total_power_states(total_infra_states, 2 , 1)             
    error_estimate = [0]*no_of_WL
    # Evaluate the test frames based on the final Power states
    # Calculate the average error 
    for i in range(0, no_of_WL):
        # Slice the dataframe and extract the power states and Cdyn values for one workload
        Workload_data = Cdyn_data.loc[:, [Workload_names[2],Workload_names[i+3]]]
        # Drop the superflous first row
        Workload_data = Workload_data.drop(Workload_data.index[0])
        #Obtain the top power states for the specified frame
        frame_power_states, infra_power_states, infra_cdyn = top_power_states_per_workload(Workload_data, unit_threshold)
        # Retain only the rows represented in final power states
        subset_power_states = frame_power_states[frame_power_states[Workload_names[2]].isin(final_power_states)]
        # Calculate the total Cdyn percentage of this subset of power states
        subset_Cdyn = subset_power_states[Workload_names[i+3]].sum()
        # Estimate the error in Cdyn estimation (in %)
        error_estimate[i] = (1.0 - subset_Cdyn)*100 
    
    avg_error = np.mean(error_estimate)
    std_error = np.std(error_estimate)
    max_error = max(error_estimate)
    return(final_power_states, error_estimate, cdyn_per_WL, avg_error, std_error, max_error)



# Extract a reduced set of power states from the combined set of power states
# Input parameters:
#    1. Total power states - Total power states for the entire set
#    2. Method: {0: Cdyn > 0.95/Avg_number_of power states, 1: Frequency of 
#        power state > 2, Cdyn*Frequency > 0.95/Avg_number_of_power_states}
# Output parameters:
#    1. Top total power states
def top_total_power_states(total_power_states, method, threshold):
     final_power_states = []
     col_name = total_power_states.columns.values
     Cdyn = col_name[1]
     Power_State = col_name[0]
     if method == 0:
        p_states = list(total_power_states.loc[total_power_states[Cdyn] >= 
                   0.001, Power_State])
        final_power_states = set(p_states)
     elif method==1:
         final_power_states = list(total_power_states[Power_State].value_counts()
                  [total_power_states[Power_State].value_counts() > 5].index)
  #      temp_states = list(total_power_states.loc[total_power_states['Cdyn'] >= 
  #                    0.95/avg_power_states, 'Power State'])
  #     final_power_states = set(temp_states)
     else:
        # Merge same power states by summing the corresponding Cdyn values 
        # Sort the merged power states by Cdyn values
        # Select the power states that contribute to 99.9% of the total Cdyn
        merged_p_states = total_power_states.groupby([Power_State]).sum().reset_index()
        merged_p_states = merged_p_states.sort_values(by = Cdyn, ascending=False).reset_index()
        Total_Cdyn = merged_p_states[Cdyn].sum()
        final_power_states = list(merged_p_states.loc[merged_p_states[Cdyn].cumsum() <= threshold*Total_Cdyn, Power_State ])
     return(final_power_states)
 
 
########################################################################################        
## Function name: top_level_power_states_analysis_per_unit
## Description: Performs the analysis of power states at the granularity of the
##              unit specified (frame, cluster, workload) and identifies the 
##              the crucial power states in each unit. From these unit level power 
##              states, an algorithm is applied to combine and select a global
##              list that is capable of charatectizing any individual unit.
## Input parameters:
##            1. Cdyn_data --- Dataframe/CSV file contain all the power data
##            2. unit_name --- Granularity of analysis -- e.g: 'Frame name'
##            3. unit_threshold --- Fraction of total Cdyn value to be used as 
##                                  as a stop criterion
##            4. global_threshold --- Threshold used for combining unit level data
## Output parameters:
##            1. final power states
##            2. Average error estimate (error averaged across all units)
#####################################################################################

def top_level_power_states_analysis_per_unit(Cdyn_data, unit_name, unit_threshold, global_threshold, split = None):
    # Extract the power states that contribute to 95% of total Cdyn
    ## Sort the data frame based on Cdyn values
    ## Normalize the Cdyn values by total Cdyn value
    ## Extract the power states that sum up to 0.95 of Total Cdyn
    ## Default there is no split of data into train & test data
    if split is None:
        split = 1.0    
    # Select appropriate level for the analysis
    # Possible choices: Frame name, Cluster
    #Define indices based on the unique frame names
    Cdyn_data.set_index(keys=[unit_name], drop=False, inplace=True)
    # get a list of frame names
    frames=Cdyn_data[unit_name].unique().tolist()

    # Initialize the total power states & counter
    number_power_states = [0]*len(frames)
    total_power_states = top_power_states_per_frame(Cdyn_data, unit_name, frames[0], unit_threshold)
    number_power_states[0] = len(total_power_states)
    # Set the number of training frames and test frames
    train_frames = round(len(frames)*split)


    #Iterate through the set of frames 
    #In each iteration, call the function that returns the top power states
    #Concatenate the top power states obtained per frame into a single dataframe
    #Select the combined list of top power states using
    #  1. Select all the common states 
    #  2. In the remaining power states, choose one of three methods to select
    #     additional states
    #      1. Cdyn values greater than a threshold
    #      2. Power states with an occurence frequency greater than a threshold
    #      3. Frequency * Cdyn values greater than a threshold
 
    for i in range(1, train_frames):
        #Obtain the top power states for the specified frame
        frame_power_states = top_power_states_per_frame(Cdyn_data, unit_name, frames[i], unit_threshold)
        #Count the number of top power states in each frame
        number_power_states [i] = len(frame_power_states)
        #Concatenate the top power states across a frame
        total_power_states = pd.concat([total_power_states, frame_power_states], axis=0)
                                 
        # Calculate the average number of power states
        avg_power_states = int(np.mean(number_power_states))

        #Select the final list of power states
        final_power_states = top_total_power_states(total_power_states, 2, global_threshold) 
              
        error_estimate = [0]*len(frames)
        # Evaluate the test frames based on the final Power states
        # Calculate the average error 
        for i in range(0, len(frames)):
            frame_power_states = top_power_states_per_frame(Cdyn_data, unit_name, frames[i], unit_threshold)
            # Retain only the rows represented in final power states
            subset_power_states = frame_power_states[frame_power_states['Power State'].isin(final_power_states)]
            # Calculate the total Cdyn percentage of this subset of power states
            subset_Cdyn = subset_power_states['Cdyn'].sum()
            # Estimate the error in Cdyn estimation (in %)
            error_estimate[i] = 1.0 - subset_Cdyn 
    
    avg_error = np.mean(error_estimate)
    std_error = np.std(error_estimate)
    max_error = max(error_estimate)
    return(final_power_states, avg_error, std_error, max_error)


########################################################################################        
## Function name: top_level_power_states_analysis_per_sub_unit
## Description: Performs the analysis of power states of an instance at the granularity 
##              of the unit specified (frame, cluster, workload) and identifies the 
##              the crucial power states in each unit. For instance, one can find the
##              top power states of the 'Sampler' cluster.
## Input parameters:
##            1. Cdyn_data --- Dataframe/CSV file contain all the power data
##            2. unit_name --- Granularity of analysis -- e.g: 'Frame name'
##            3. instance  --- instance of the unit
##            4. unit_threshold --- Fraction of total Cdyn value to be used as 
##                                  as a stop criterion
##            5. global_threshold --- Threshold used for combining unit level data
## Output parameters:
##            1. final power states
##            2. Average error estimate (error averaged across all frames in that subunit)
#####################################################################################

def top_level_power_states_analysis_per_sub_unit(Cdyn_data, unit_name, instance, unit_threshold, global_threshold):
    # Extract the power states that contribute to 95% of total Cdyn
    ## Sort the data frame based on Cdyn values
    ## Normalize the Cdyn values by total Cdyn value
    ## Extract the power states that sum up to 0.95 of Total Cdyn
    ## Default there is no split of data into train & test data
    # Select appropriate level for the analysis
    # Possible choices: Frame name, Cluster
    
    Frame_Cdyn_data = Cdyn_data.loc[Cdyn_data['Cluster_Name'] == instance]
    Cdyn_sum = Frame_Cdyn_data['Cdyn'].sum()
    Frame_Cdyn_data['Cdyn'] /= Frame_Cdyn_data['Cdyn'].sum()
    Sorted_Cdyn_data = Frame_Cdyn_data.sort_values(by = 'Cdyn', ascending=False)
    #Norm_Cdyn_sum = Frame_Cdyn_data['Cdyn'].sum()
    power_states = Sorted_Cdyn_data.loc[Sorted_Cdyn_data['Cdyn'].cumsum() <= 0.95,['Power State','Cdyn']]
    #unique_power_states = power_states.drop_duplicates(['Power State'])
    return(power_states)

split = 1.0
granularity = 'Workload'    
if granularity == 'Frame level':
    # Read in the Cdyn data (frame level data) from the CSV file 
    Cdyn_data = pd.read_csv('State_level_cdyn.csv')

if granularity == 'Workload':
    # Read in the workload level data
    XL_data = pd.ExcelFile('Workload_level_cdyn_Gen12LP_ww40.xlsx')
    # Extract the desired sheet from the XLS sheet
    Cdyn_data = XL_data.parse('Gen12LP_ww40_WL')
    # Extract the workload names
    Workload_names = Cdyn_data.columns.values

# Filter the infra power states and keep it in a separate file
# Select the top power states per workload 
# Add the infra power states 
# Perfrom the analysis for each workload (subframe)
# Combine the power states and select the final list



# Perform the power analysis and average estimate of final power states
# for unit level thresholds
i=0
count = [0]*6
percentage = [0]*6
avg_error_estimate = [0]*6
std_error_estimate = [0]*6
max_error_estimate = [0]*6
num_diff_states = [0]*6
infra_state_keys = {'Assign', 'CLKGLUE', 'CPunit', 'DFX', 'DOP', 'NONCLKGLUE', 'Repeater', 'SMALL'}
for i in range(0,4):
   threshold = 0.95+i*0.01
   # Select the file and read teh data based on the granularity defined
   if granularity == 'Workload':
        ## Compute the max power states, avg error etc across all workloads
        final_power_states, error_estimate, Cdyn_per_WL, avg_error, std_error, max_error = top_level_power_states_analysis_for_all_workloads(Cdyn_data, 0.95, threshold)
        #Identify the workloads that have more than 10% error
        WL_locs = [ n for n,j in enumerate(error_estimate) if j>0.1]
        #Iterate through the list and extract the power states for 90%
        # Cdyn coverage in this list. Merge the differntial power states
        #into the final list
        #initialize the total differental states
        total_diff_states = []
        num_diff_states[i] = 0
        for j in range(0, len(WL_locs)-1):
            # Slice the dataframe and extract the power states and Cdyn values for one workload
            WL_data = Cdyn_data.loc[:, [Workload_names[2],Workload_names[WL_locs[j]+3]]]
            # Drop the superflous first row
            WL_data = WL_data.drop(WL_data.index[0])
            #Rename the columns to 'Power State' and 'Cdyn' to represent the data 
            Workload_data = WL_data.rename(index=str, columns={Workload_names[2]:"Power State", Workload_names[i+3]: "Cdyn"})
            #Obtain the top power states for the specified frame
            WL_power_states, WL_infra_states, infra_cdyn = top_power_states_per_workload(Workload_data, 0.9)
            #Merge the additional states into this list
            WL_power_state_list = WL_power_states['Power State'].tolist()
            diff_states = list(set(WL_power_state_list) - set(final_power_states))
            #final_power_states = list(set(final_power_states)|set(WL_power_state_list))
            total_diff_states = list(set(total_diff_states)|set(diff_states))
        # Add these diff states to the final power_states
        #final_power_states = list(set(final_power_states)|set(total_diff_states))
        num_diff_states[i] = len(total_diff_states)
        # Filter out the infrastructure power states 
        infra_power_states = [s for s in final_power_states if any(s.endswith(xs) for xs in infra_state_keys)]
        #final_func_power_states = final_power_states - infra_power_states
        final_func_power_states = [x for x in final_power_states if x not in infra_power_states]
        count[i] = len(final_func_power_states)
            
        
   if granularity == 'Frame level':
        final_power_states, avg_error, std_error, max_error = top_level_power_states_analysis_per_unit(Cdyn_data, 'Frame name', threshold , threshold, split=0.9)
        unit_power_states = top_level_power_states_analysis_per_sub_unit(Cdyn_data, 'Cluster_Name', 'Fabric', 1.0 , 1.0)
        # Retain only the rows represented in final power states
        subset_power_states = unit_power_states[unit_power_states['Power State'].isin(final_power_states)]
        unique_power_states = subset_power_states.drop_duplicates(['Power State'])
        cluster_power_states = unit_power_states.drop_duplicates(['Power State'])
        #diff_power_states = cluster_power_states - unique_power_states
        filename = 'Sampler'+ str(i)
        count[i] = len(unique_power_states)
        # Calculate the total Cdyn percentage of this subset of power states
        subset_Cdyn = subset_power_states['Cdyn'].sum()
        # Estimate the error in Cdyn estimation (in %)
        avg_error = 1.0 - subset_Cdyn 
   percentage[i] = threshold*100
   avg_error_estimate[i] = round(avg_error, 2)
   max_error_estimate[i] = round(max_error)
   avg_infra_Cdyn = np.mean(Cdyn_per_WL)
   infra_Cdyn_stddev = np.std(Cdyn_per_WL)
   infra_Cdyn_spread = max(Cdyn_per_WL) - min(Cdyn_per_WL)

   
    
# Combine additional power states into final list if Subset_Cdyn < 0.9
if granularity == 'Frame level':
    if subset_Cdyn < 0.9:
        cluster_power_state_list = cluster_power_states['Power State'].tolist()
        final_ext_power_states = list(set(final_power_states)|set(cluster_power_state_list))
      
#final_power_states.to_csv('workload_level_final_power_states.csv')
with open(granularity + "_level_power_states.csv", "w", newline="") as fout:
            writer = csv.writer(fout, delimiter = ',')
            writer.writerows(final_power_states)

#with PdfPages('Error_Estimation_Error_WL_level_95%_98%.pdf') as pdf:
plt.figure(figsize=(7, 7))
plt.plot(error_estimate, marker='o', color = 'b')
plt.ylabel('Percentage of Estimation Error')
plt.xlabel('Workload')
plt.title('Power estimation error v/s workload(95% at WL, 98% global)')
plt.ylim(ymax = 100, ymin = 0)
plt.xlim(xmax = 80, xmin = 1)
plt.savefig('Error_Estimation_Error_WL_level_95%_98%.png')
plt.close()

#Extract the subdataframe based on the final power states 
#so that the o/p file contains: Cluster, Unit, Power State, Cdyn
final_power_states_subframe = Cdyn_data.loc[Cdyn_data['Power State'].isin(final_func_power_states)]
#final_power_states_subframe['Avg Cdyn'] = final_power_states_subframe[3:81].mean(axis=1)


#==============================================================================
# 
# with PdfPages('Power_Analysis_WL_level_85%.pdf') as pdf:
#     plt.figure(figsize=(7, 7))
#     plt.plot(count, percentage, marker='o', color = 'r')
#     plt.ylabel('Percentage of total power')
#     plt.xlabel('Number of power states')
#     plt.title('Power coverage v/s no. of power states (85% at WL level)')
#     plt.axis('tight')
#     pdf.savefig()
#     plt.close()
# 
# with PdfPages('Avg_Power_Estimation_Error_WL_level_85%.pdf') as pdf:
#     plt.figure(figsize=(7, 7))
#     plt.plot(count, avg_error_estimate, marker='o', color = 'b')
#     plt.ylabel('Percentage of Estimation Error')
#     plt.xlabel('Number of power states')
#     plt.title('Avg Power estimation error v/s power states(85% at WL level)')
#     plt.axis('tight')
#     pdf.savefig()
#     plt.close()
#     
# with PdfPages('Max_Power_Estimation_Error_WL_level_85%.pdf') as pdf:
#     plt.figure(figsize=(7, 7))
#     plt.plot(count, max_error_estimate, marker='o', color = 'b')
#     plt.ylabel('Percentage of Estimation Error')
#     plt.xlabel('Number of power states')
#     plt.title('Max Power estimation error v/s power states(85% at WL level)')
#     plt.axis('tight')
#     pdf.savefig()
#     plt.close()
#     
#     
# with PdfPages('Infra_Cdyn_power_per_WL_85%.pdf') as pdf:
#      plt.figure(figsize=(7, 7))
#      plt.plot(Cdyn_per_WL, marker='o', color = 'b')
#      plt.ylabel('Percentage Infra Cdyn power')
#      plt.xlabel('Workload')
#      plt.title('Infra State Power across WL (85% level)')
#      plt.axis('tight')
#      pdf.savefig()
#      plt.close()
#==============================================================================
#endif