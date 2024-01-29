import nibabel as nib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import sys
import os
import json

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
fig, axs = plt.subplots(3, 3, figsize=(15, 10))
plt.figtext(0.01,0.85,content, fontsize='large')
plt.subplots_adjust(left=0.2, right=0.9, bottom=0.1, top=0.85, wspace=0.2, hspace=0.4)

r0c0=plt.subplot2grid((3,3), (0,0))
r0c1=plt.subplot2grid((3,3), (0,1))
r0c2=plt.subplot2grid((3,3), (0,2))
r1c0=plt.subplot2grid((3,3), (1,0))
r1c1=plt.subplot2grid((3,3), (1,1))
r1c2=plt.subplot2grid((3,3), (1,2))
r2c01=plt.subplot2grid((3,3), (2,0), colspan=2)
r2c2=plt.subplot2grid((3,3), (2,2))
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
r0c0.imshow(roi_slice, cmap='viridis', aspect='equal')
r0c0.imshow(brain_slice, cmap='gray', alpha=0.7, aspect='equal')
r0c0.set_title('Middle Brain Slice\n of B0 with ROI', fontsize=10)


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
r0c1.imshow(roi_slice, cmap='viridis', aspect='equal', extent=(5,6,5,6))
r0c1.imshow(brain_slice, cmap='gray', alpha=0.7, aspect='equal', extent=(5,6,5,6))
r0c1.set_title('Middle Brain Slice\n of B0 with ROI', fontsize=10)
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
r0c2.imshow(roi_slice, cmap='viridis',aspect='equal', extent=(5,6,5,6))
r0c2.imshow(brain_slice, cmap='gray', alpha=0.7, aspect='equal', extent=(5,6,5,6))
r0c2.set_title('Middle Brain Slice\n of B0 with ROI', fontsize=10)
#fig = plt.figure(frameon=False)

print("Plot result...")
# Plot the result
connectome1=r1c1.imshow(connectome_data_1, cmap='viridis')

import matplotlib.colors as colors
r1c0.imshow(connectome_data_1, cmap='viridis',vmin=0.0, vmax=0.001*np.max(connectome_data_1))
fig.colorbar(connectome1, ax=r1c0)
r1c0.set_title('Connectome weighted by \n number of streamlines (0 to 0.001*max)', fontsize=10)

connectome2 = r1c1.imshow(connectome_data_2, cmap='viridis')
fig.colorbar(connectome2, ax=r1c1)
r1c1.set_title('Connectome weighted by \n mean length of streamlines', fontsize=10)

connectome3 = r1c2.imshow(connectome_data_3, cmap='viridis')
fig.colorbar(connectome3, ax=r1c2)
r1c2.set_title('Connectome weighted by \n fractional anisotropy (FA)', fontsize=10)
r2c01.axis('off')
with open(json_file, 'r') as file:
    data = json.load(file)
# Create a list of tuples for table data
table_data = [(metric, values[0]) for metric, values in data.items()]
table = r2c01.table(cellText=table_data, colLabels=["Metric", "Value"], loc='center', cellLoc='center')
table.auto_set_font_size(False)
table.set_fontsize(12)

# Adjust the layout for better visibility
table.auto_set_column_width([0, 1])

# Create a bar chart
r2c2.title.set_text('Histogram of Connectome\nedge weights (NOS weighed)')    
# r2c2.grid() 
r2c2.hist(connectome_data_1.flatten(), bins=10)
r2c2.set_xlabel("Frequency")
r2c2.set_ylabel("NOS")



# Save the visualization as a PNG file
plt.savefig(output_file)
#plt.show()

print("Done.")
