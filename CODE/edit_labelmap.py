#Author: Michael Kim

# Updates the labelmap for a SLANT-TICV segmentation to be that of another input labelmap


import numpy as np
import nibabel as nib
from tqdm import tqdm
import argparse

def pa():
    parser = argparse.ArgumentParser(description='Update label map for SLANT-TICV segmentation')
    parser.add_argument('label_map', type=str, help='Path to ORIGINAL label map that is to be updated')
    parser.add_argument('file1', type=str, help='Path to new label LUT file')
    parser.add_argument('file2', type=str, help='Path to old label LUT file (that corresponds to the original SLANT-TICV label map)')
    parser.add_argument('output', type=str, help='Path to save updated label map')
    #parser.add_argument('--wstem', action='store_true', help='Use this flag if the new label file includes the brainstem')
    return parser.parse_args()


def load_labels(file_path):
    labels = {}
    with open(file_path, 'r') as file:
        for line in file:
            parts = line.strip().split()
            try:
                label_id = int(parts[0])
            except:
                print(f'Error parsing label: {parts}')
                continue
            label_name = ' '.join(parts[1:-4])
            r, g, b, a = map(int, parts[-4:])
            labels[label_id] = (label_name, r, g, b, a)
    return labels

def create_mapping(file1_labels, file2_labels):
    mapping = {}
    removed_labels = []
    mapped = False
    for id2, (name2, _, _, _, _) in file2_labels.items():
        mapped = False
        for id1, (name1, _, _, _, _) in file1_labels.items():
            if name2 == name1:
                mapping[id2] = id1
                mapped = True
                break
        if not mapped:
            removed_labels.append(id2)
            print(f'No mapping found for label {id2}: {name2}')
    return mapping, removed_labels

def update_label_map(label_map_file, mapping, removed_labels, outfile):
    img = nib.load(label_map_file)
    data = img.get_fdata()

    #zero out all removed labels
    for label in tqdm(removed_labels):
        data[data == label] = 0

    for old_label, new_label in tqdm(mapping.items()):
        # print(f'Updating label {old_label} to {new_label}')
        # if data[130,100,42] == old_label:
        #     print(old_label)
        #     print(new_label)
        data[data == old_label] = new_label
        #print(data[130,100,42])


    new_img = nib.Nifti1Image(data, img.affine)
    # if wstem:
    #     new_img_file = label_map_file.replace('.nii.gz', '_updated_wstem.nii.gz')
    # else:
    #     new_img_file = label_map_file.replace('.nii.gz', '_updated.nii.gz')
    nib.save(new_img, outfile)
    print(f'Updated label map saved as: {outfile}')

def main():

    args = pa()

    new_label_file = args.file1
    old_label_file = args.file2
    label_map_file = args.label_map
    output_file = args.output

    #file1_path = '/Users/Michael/Downloads/ConnectomeOrderedSLANTLabels.txt'
    #file2_path = '/Users/Michael/Downloads/slant_origlabels.txt'
    #file3_path = '/Users/Michael/Downloads/ConnectomeOrderedSLANTLabels_w_brainstem.txt'
    #label_map_path = '/Users/Michael/Downloads/test_seg.nii.gz'

    new_labels = load_labels(new_label_file)
    old_labels = load_labels(old_label_file)
    #file3_labels = load_labels(file3_path)
    
    #create a mapping for old labels to the ones that exist in the new label file
    mapping, removed_labels = create_mapping(new_labels, old_labels)
    valid_mapping = {k: v for k, v in mapping.items() if v in new_labels}

    #update the label map
    update_label_map(label_map_file, valid_mapping, removed_labels, output_file)

    # Remove any mappings for labels not 

    # mapping1, removed_labels1 = create_mapping(file1_labels, file2_labels)
    
    # # Remove any mappings for labels not in file1
    # valid_mapping = {k: v for k, v in mapping1.items() if v in file1_labels}

    # update_label_map(label_map_path, valid_mapping, removed_labels1, wstem=False)

    #above seems to work, now need to do the same for the labels with the brainstem

    #mapping3, removed_labels3 = create_mapping(file3_labels, file2_labels)
    #valid_mapping3 = {k: v for k, v in mapping3.items() if v in file3_labels}
    #for k, v in valid_mapping3.items():
    #    print(f'{k}: {file2_labels[k]} -> {v}: {file3_labels[v]}')
    #update_label_map(label_map_path, valid_mapping3, removed_labels3, wstem=True)

if __name__ == "__main__":
    main()

