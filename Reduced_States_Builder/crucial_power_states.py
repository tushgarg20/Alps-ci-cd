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
import sys #only needed to determine Python version number
import matplotlib #only needed to determine Matplotlib version number
import numpy
import statsmodels.api as sm

# Enable inline plotting
#matplotlib inline

Cdyn_data = pd.read_csv('State_level_cdyn.csv')

# Extract the power states that contribute to 95% of total Cdyn
## Sort the data frame based on Cdyn values
## Normalize the Cdyn values by total Cdyn value
## Extract the power states that sum up to 0.95 of Total Cdyn
Cdyn_data['Cdyn'].max()
Cdyn_data['Cdyn'].min()
Cdyn_data['Cdyn'].sum()
Cdyn_data['Cdyn'].value_counts(bins=20)
#Cdyn_data['Cdyn'] /= Cdyn_data['Cdyn'].sum()
#Cdyn_normalized = Cdyn_data['Cdyn'].apply(lambda x: x / x.max())
Cdyn_data.loc[Cdyn_data.sort_values(by='Cdyn', ascending=False)['Cdyn'] >= .01,'Power State']
#i=0
#count = [0]*20
#percentage = [0]*20
#for i in range(0,20):
#    limit = round(0.8 + i*0.01, 2)
#    print(limit)
#    power_states = Cdyn_data.loc[Cdyn_data.sort_values(by='Cdyn', ascending=False)['Cdyn'].cumsum() <= limit,'Power State']
#    unique_power_states = list(power_states.unique())
#    count[i] = len(unique_power_states)
#    percentage[i] = limit*100
    
    
    
plt.plot(count, percentage)
plt.ylabel('Percentage of total power')
plt.xlabel('Number of power states')
plt.axis([200,600, 80, 100])
plt.show()

#Define indicies based on the unique frame names
Cdyn_data.set_index(keys=['Frame name'], drop=False,inplace=True)
# get a list of names
names=Cdyn_data['Frame name'].unique().tolist()


total_power_states = []
count=[0]*77
number_power_states = [0]*77
for i in range(0, len(names)):
    Frame_Cdyn_data = Cdyn_data.loc[Cdyn_data['Frame name'] == names[i]]
    limit = 0.95
    Frame_Cdyn_data['Cdyn'] /= Frame_Cdyn_data['Cdyn'].sum()
    power_states = Frame_Cdyn_data.loc[Frame_Cdyn_data.sort_values(by='Cdyn', ascending=False)['Cdyn'].cumsum() <= limit,'Power State']
    unique_power_states = list(power_states.unique())
    number_power_states [i] = len(unique_power_states)
    delta_states = list(set(unique_power_states) - set(total_power_states))
    total_power_states = total_power_states + delta_states

 
    

 