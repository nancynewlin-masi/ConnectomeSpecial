import nibabel as nib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import sys
import os
import json
import pandas as pd

brain_file=sys.argv[1]
roi_file=sys.argv[2]

connectome_file_1=sys.argv[3]
connectome_file_2=sys.argv[4]
connectome_file_3=sys.argv[5]

json_file=sys.argv[6]
log_file = sys.argv[7]
output_file=sys.argv[8]

with open(log_file, 'r') as file:
    lines = file.readlines()
    print('The list of the strings:',lines)
lines_short=lines[0:5]
content = ''.join(lines_short)

print("Connectome at",connectome_file_1,"output file at",output_file)

connectome_data_1 = np.load(connectome_file_1)
connectome_data_2 = np.load(connectome_file_2)
connectome_data_3 = np.load(connectome_file_3)

#fig, (ax1, ax2, ax3, ax4) = plt.subplots(4, 1)
fig, axs = plt.subplots(4, 3, figsize=(12, 12))

for i in np.arange(0,4):
    for j in np.arange(0,3):
        axs[i,j].axis('off')



plt.figtext(0.01,0.90,content, fontsize='large')
plt.subplots_adjust(left=0.1, right=0.9, bottom=0.1, top=0.85, wspace=0.4, hspace=0.4)


r0c0=plt.subplot2grid((4,3), (0,0))
r0c1=plt.subplot2grid((4,3), (0,1))
r0c2=plt.subplot2grid((4,3), (0,2))
r1c0=plt.subplot2grid((4,3), (1,0))
r1c1=plt.subplot2grid((4,3), (1,1))
r1c2=plt.subplot2grid((4,3), (1,2))
r2c0=plt.subplot2grid((4,3), (2,0))
r2c1=plt.subplot2grid((4,3), (2,1))
r2c2=plt.subplot2grid((4,3), (2,2))
r2c01=plt.subplot2grid((4,3), (3,0), colspan=3)
r0c0.axis('off')   
r0c1.axis('off')   
r0c2.axis('off')   
# Load NIfTI files
print("Loading images with nibabel...")
brain_img = nib.load(brain_file)
roi_img = nib.load(roi_file)

# Get data arrays
brain_data = brain_img.get_fdata()
roi_data = roi_img.get_fdata()

# Ensure the dimensions match
if brain_data.shape != roi_data.shape:
        raise ValueError("Brain and ROI dimensions do not match.")

print("Get middle slice of brain...")
# Get the middle slice index
middle_slice_index = brain_data.shape[2] // 2
print("Middle slice detected at ", brain_data.shape[2], "/2", middle_slice_index )

# Extract middle slices
brain_slice = brain_data[:, :, middle_slice_index]
roi_slice = roi_data[:, :, middle_slice_index]

print("Get some overlay...")
# Overlay ROI on brain slice
#overlaid_slice = np.ma.masked_where(roi_slice == 1, brain_slice)
#fig = plt.figure(frameon=False)

print("Plot result...")
# Plot the result
r0c0.imshow(np.rot90(roi_slice), cmap='viridis', aspect='equal')
r0c0.imshow(np.rot90(brain_slice), cmap='gray', alpha=0.7, aspect='equal')
r0c0.set_title('B0 with ROI seg - Axial\nR|L', fontsize=10)


# Get the middle slice index
middle_slice_index = brain_data.shape[0] // 2
print("Middle slice detected at ", brain_data.shape[2], "/2", middle_slice_index )

# Extract middle slices
brain_slice = brain_data[middle_slice_index, :, :]
roi_slice = roi_data[middle_slice_index, :, :]

print("Get some overlay...")
# Overlay ROI on brain slice
#overlaid_slice = np.ma.masked_where(roi_slice == 1, brain_slice)
#fig = plt.figure(frameon=False)

print("Plot result...")
# Plot the result
r0c1.imshow(np.rot90(roi_slice), cmap='viridis', aspect='equal', extent=(5,6,5,6))
r0c1.imshow(np.rot90(brain_slice), cmap='gray', alpha=0.7, aspect='equal', extent=(5,6,5,6))
r0c1.set_title('B0 with ROI seg - Coronal\nP|A', fontsize=10)
#fig = plt.figure(frameon=False)

# Get the middle slice index
middle_slice_index = brain_data.shape[1] // 2
print("Middle slice detected at ", brain_data.shape[2], "/2", middle_slice_index )

# Extract middle slices
brain_slice = brain_data[:, middle_slice_index, :]
roi_slice = roi_data[:, middle_slice_index, :]

print("Get some overlay...")
# Overlay ROI on brain slice
#overlaid_slice = np.ma.masked_where(roi_slice == 1, brain_slice)
#fig = plt.figure(frameon=False)

print("Plot result...")
# Plot the result
r0c2.imshow(np.rot90(roi_slice), cmap='viridis',aspect='equal', extent=(5,6,5,6))
r0c2.imshow(np.rot90(brain_slice), cmap='gray', alpha=0.7, aspect='equal', extent=(5,6,5,6))
r0c2.set_title('B0 with ROI seg - Coronal\nR|L', fontsize=10)
#fig = plt.figure(frameon=False)
plt.axis('off')

print("Plot result...")
# Plot the result
connectome1=r1c1.imshow(connectome_data_1, cmap='viridis')

import matplotlib.colors as colors
r1c0.imshow(connectome_data_1, cmap='viridis',vmin=0.0, vmax=0.001*np.max(connectome_data_1))
fig.colorbar(connectome1, ax=r1c0)
r1c0.set_title('Connectome weighted by \n number of streamlines (0 to 0.001*max)', fontsize=10)
plt.axis('off')
connectome2 = r1c1.imshow(connectome_data_2, cmap='viridis')
fig.colorbar(connectome2, ax=r1c1)
r1c1.set_title('Connectome weighted by \n mean length of streamlines', fontsize=10)
plt.axis('off')
connectome3 = r1c2.imshow(connectome_data_3, cmap='viridis')
fig.colorbar(connectome3, ax=r1c2)
r1c2.set_title('Connectome weighted by \n fractional anisotropy (FA)', fontsize=10)
plt.axis('off')



with open(json_file, 'r') as file:
    data = json.load(file)
# Create a list of tuples for table data
table_data = [(metric, values[0]) for metric, values in data.items()]
absrange = ['[0,1]','[0,1]','[-1,1]','[0,1]','[0,inf]','[0,MaxStreamlines]','[0,inf]','[0,inf]','[0,1]', '[0,1]','[0,inf]','[0,inf]']
exprange = ['[0,0.002]','[0.5,0.9]','[-0.01,0.01]','[0,40]','[0, 0.06]','[0, 10,000]','[50,90]','[50,90]','[0.7,0.9]','[0,1]','[0,250]','[0,10]']
print("abs range shape:",np.shape(absrange))
df1 = pd.DataFrame(table_data, columns=['Metric', 'Value'])
print(df1)
print([absrange, exprange])
df2 = pd.DataFrame({'Absolute Range': absrange, 'Expected Range': exprange})
print(df2)
df = df1.join(df2, how='outer')
print(df)
print(df.shape)
df = df.round(3)
table = r2c01.table(cellText=df.reset_index().values, colLabels=df.reset_index().columns, loc='center', cellLoc='center')
# bet centrality, modularity, assortativity, participation, clustering, nodal strength, local eff, glob eff, density, rich club, path length, edge count

table.auto_set_font_size(False)
table.set_fontsize(9)

# Adjust the layout for better visibility
table.auto_set_column_width([0, 1])

# Create a bar chart
#r2c0.title.set_text('Histogram of Connectome\nedge weights (NOS weighed)',fontsize=10)    
r2c0.set_title('Histogram of Connectome\nedge weights (NOS weighed)', fontsize=10)
# r2c2.grid() 
r2c0.hist(connectome_data_1.flatten(), bins=10)
r2c0.set_xlabel("Frequency")
r2c0.set_ylabel("NOS")

r2c1.set_title('Histogram of Connectome\nedge weights (Mean Length weighed)', fontsize=10)    
# r2c2.grid() 
r2c1.hist(connectome_data_2.flatten(), bins=10)
r2c1.set_xlabel("Frequency")
r2c1.set_ylabel("Mean Length")

r2c2.set_title('Histogram of Connectome\nedge weights (Mean FA weighed)', fontsize=10)    
# r2c2.grid() 
r2c2.hist(connectome_data_3.flatten(), bins=10)
r2c2.set_xlabel("Frequency")
r2c2.set_ylabel("Mean FA")
plt.axis('off')


# Save the visualization as a PNG file
plt.savefig(output_file)
#plt.show()

print("Done.")
