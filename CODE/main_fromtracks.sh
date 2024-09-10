#Written by Nancy Newlin, edited by Michael Kim


# Directories
export PREQUALDIR=/DIFFUSION/
export SLANTDIR=/SLANT/
export OUTPUTDIR=/OUTPUTS/

# make slant folder in def file
# rename diffusion as prequal

# Get subject name...
export fullname=$(find ${SLANTDIR}/post/FinalResult/sub* -name '*seg*.nii.gz')
filename=$(basename "$fullname")
export subses=${filename%%_T1w_seg.nii.gz}
echo "NOTE: Beginning connectomics analysis with diffusion data at: ${PREQUALDIR}, Slant output at: ${SLANTDIR}."
echo "NOTE: Output will be stored at ${OUTPUTDIR}"
echo "Running Connectome Special version 1.2.0" >> ${OUTPUTDIR}/log.txt
date >> ${OUTPUTDIR}/log.txt
echo "SUBJECT_SESSION=$subses" >> ${OUTPUTDIR}/log.txt
echo "PARCELLATION=Slant, 133 ROIs" >> ${OUTPUTDIR}/log.txt
echo "NUMBER OF STREAMLINES=10,000,000" >> ${OUTPUTDIR}/log.txt
echo "REGISTRATION SOFTWARE=epireg" >> ${OUTPUTDIR}/log.txt

# Hyper parameters
export NUMSTREAMS=10000000
export WORKINGDIR=/ConnectomeSpecial/

# Set up temporary directory that will be deleted at the end of processing
mkdir /OUTPUTS/TEMP/
export TEMPDIR=/OUTPUTS/TEMP/
export TCK_FILE=/OUTPUTDIR/tracks_10000000_compressed.tck


# Define look up tables for atlas. One will be ordered, the other the original lookup table.
#export ORIGLABELS=/ConnectomeSpecial/SUPPLEMENTAL/slant_origlabels.txt
export DESTLABELS=/ConnectomeSpecial/SUPPLEMENTAL/slant_orderedlabels.txt
export ORIGLABELS=//ConnectomeSpecial//SUPPLEMENTAL//slant_ticv_orig_labels.txt
export NEWLABELS=//ConnectomeSpecial//SUPPLEMENTAL//ConnectomeOrderedSLANTLabels.txt
export NEWLABELS_STEM=//ConnectomeSpecial///SUPPLEMENTAL/ConnectomeOrderedSLANTLabels_w_brainstem.txt

#echo "Moving dwi to accre..."
#scp newlinnr@hickory.accre.vanderbilt.edu:${PREQUALDIR}/* newlinnr@hickory.accre.vanderbilt.edu:${TEMPDIR}
echo "Check for DWI"
export DWI=$(find $PREQUALDIR/PREPROCESSED/ -name "*dwmri.nii.gz")
export BVEC=$(find $PREQUALDIR/PREPROCESSED/ -name "*bvec")
export BVAL=$(find $PREQUALDIR/PREPROCESSED/ -name "*bval")

echo "Successfully DWI found at ${DWI}, ${BVEC}, ${BVAL}." >> ${OUTPUTDIR}/log.txt

if test -f "${TCK_FILE}"; then
    echo "Successfully found tractography at ${TCK_FILE}." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: Could not find a tractography file at ${TCK_FILE}" >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Check for T1"
#export T1=$(find ${ANATDIR} -name '*T1*.nii.gz' | head -n 1)
export T1=$(find ${SLANTDIR}/pre/ -name 'orig_target.nii.gz')
cp ${T1} ${TEMPDIR}/T1.nii.gz
export T1=${TEMPDIR}/T1.nii.gz

if test -f "${T1}"; then
    echo "Successfully found T1 image at ${T1}." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: Could not find a T1 image at ${T1}" >> ${OUTPUTDIR}/log.txt
    echo "SOLUTION: We are searching the Slant directory provided for the T1 image used as input to the Slant algorithm. Check that there is a valid Slant folder."
    exit 0;
fi

if test -f "${PREQUALDIR}/SCALARS/dwmri_tensor_fa.nii.gz"; then
    echo "Successfully found fa map at ${PREQUALDIR}/SCALARS/dwmri_tensor_fa.nii.gz.">> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: No fa map found at ${PREQUALDIR}/SCALARS/dwmri_tensor_fa.nii.gz.">> ${OUTPUTDIR}/log.txt
    exit 0;
fi

export SLANTSEG=$(find ${SLANTDIR}/post/FinalResult/sub* -name '*seg*.nii.gz')
if test -f "${SLANTSEG}"; then
    echo "Successfully found slant segmentation image at ${SLANTSEG}." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: No slant segmentation image at ${SLANTSEG}.">> ${OUTPUTDIR}/log.txt
    exit 0;
fi


if test -f "${TEMPDIR}/T1_inDWIspace.nii.gz"; then
    echo "Results found. Continue past registration..." >> ${OUTPUTDIR}/log.txt
else
    

    #echo "Apply PreQual brain mask to T1 image..." >> ${OUTPUTDIR}/log.txt
    #mri_mask ${T1} ${PREQUALDIR}/PREPROCESSED/mask.nii.gz ${TEMPDIR}/T1_brain.nii.gz
    echo "Apply brain mask to T1 image..." >> ${OUTPUTDIR}/log.txt
    #bet ${T1} ${TEMPDIR}/T1_brain.nii.gz
    fslmaths ${SLANTSEG} -bin ${TEMPDIR}/Brain_mask_inT1space.nii.gz
    fslmaths ${T1} -mul ${TEMPDIR}/Brain_mask_inT1space.nii.gz ${TEMPDIR}/T1_brain.nii.gz

    if test -f "${TEMPDIR}/T1_brain.nii.gz"; then
        echo "Successfully processed T1 brain." >> ${OUTPUTDIR}/log.txt
    else
        echo "FAILED: Could not get T1 brain." >> ${OUTPUTDIR}/log.txt
        exit 0;
    fi

    echo "Apply transforms to atlas image to register to subject space..."  >> ${OUTPUTDIR}/log.txt
    epi_reg --epi=${OUTPUTDIR}/b0.nii.gz --t1=${T1} --t1brain=${TEMPDIR}/T1_brain.nii.gz --out=${TEMPDIR}/b02t1

    if test -f "${TEMPDIR}/b02t1.mat"; then
        echo "Successfully computed a registration transform between T1 and b0." >> ${OUTPUTDIR}/log.txt
    else
        echo "FAILED: Registration failed. Exiting." >> ${OUTPUTDIR}/log.txt
        exit 0;
    fi

    echo "Convert transform to go in oppisite direction..."  >> ${OUTPUTDIR}/log.txt
    convert_xfm -omat ${TEMPDIR}/t12b0.mat -inverse ${TEMPDIR}/b02t1.mat

    echo "Apply transform to T1..."  >> ${OUTPUTDIR}/log.txt  # ${TEMPDIR}/T1_bet.nii.gz
    flirt -in ${T1} -ref ${OUTPUTDIR}/b0.nii.gz -applyxfm -init ${TEMPDIR}/t12b0.mat  -out ${TEMPDIR}/T1_inDWIspace.nii.gz
    if test -f "${TEMPDIR}/T1_inDWIspace.nii.gz"; then
        echo "CHECK: Registered T1 found. Proceeding to next step." >> ${OUTPUTDIR}/log.txt
    else
        echo "ERROR FOUND: Registration failed. Exiting" >> ${OUTPUTDIR}/log.txt
        exit 0;
    fi
fi

#echo "Labelconvert to get the Slant atlas..." >> ${OUTPUTDIR}/log.txt
#labelconvert ${SLANTSEG} $ORIGLABELS  $DESTLABELS ${TEMPDIR}/atlas_slant_t1.nii.gz
echo "Converting SLANT-TICV labelmap to remove CSF/WM regions (with and without brainstem)" >> ${OUTPUTDIR}/log.txt

### ADDED BY MICHAEL
python3 /CODE/edit_labelmap.py ${SLANTSEG} ${NEWLABELS} ${ORIGLABELS} ${TEMPDIR}/atlas_slant_t1.nii.gz
export ATLAS_STEM=${TEMPDIR}/atlas_slant_t1_w_stem.nii.gz
python3 /CODE/edit_labelmap.py ${SLANTSEG} ${NEWLABELS_STEM} ${ORIGLABELS} ${ATLAS_STEM}
### END ADDITION

if test -f "${TEMPDIR}/atlas_slant_t1.nii.gz"; then
    echo "Successfully label converted slant image to sequential labels (1..n)." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: Could not label convert slant image to sequential labels (1..n)." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

if test -f "${TEMPDIR}/atlas_slant_t1_w_stem.nii.gz"; then
    echo "Successfully label converted slant image to sequential labels (1..n+1) with stem." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: Could not label convert slant image to sequential labels (1..n+1) with stem." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi



echo "Apply transform to atlas..." >> ${OUTPUTDIR}/log.txt
flirt -in ${TEMPDIR}/atlas_slant_t1.nii.gz -ref ${OUTPUTDIR}/b0.nii.gz -applyxfm -init ${TEMPDIR}/t12b0.mat -out ${TEMPDIR}/atlas_slant_subj.nii.gz  -interp nearestneighbour
if test -f "${TEMPDIR}/atlas_slant_subj.nii.gz"; then
    echo "Successfully applied transform to atlas." >> ${OUTPUTDIR}/log.txt
    echo "Saving atlas as ${TEMPDIR}/atlas_slant_subj.nii.gz..." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/atlas_slant_subj.nii.gz ${OUTPUTDIR}
    export ATLAS=${TEMPDIR}/atlas_slant_subj.nii.gz
else
    echo "FAILED: Could not apply transform to atlas." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

### ADDED BY MICHAEL
export SLANT_SUBJ_STEM=${TEMPDIR}/atlas_slant_subj_stem.nii.gz
flirt -in ${ATLAS_STEM} -ref ${OUTPUTDIR}/b0.nii.gz -applyxfm -init ${TEMPDIR}/t12b0.mat -out ${SLANT_SUBJ_STEM} -interp nearestneighbour
if test -f "${SLANT_SUBJ_STEM}"; then
    echo "Successfully applied transform to atlas with stem." >> ${OUTPUTDIR}/log.txt
    echo "Saving atlas as ${SLANT_SUBJ_STEM}..." >> ${OUTPUTDIR}/log.txt
    cp ${SLANT_SUBJ_STEM} ${OUTPUTDIR}
    #export ATLAS=${TEMPDIR}/atlas_slant_subj.nii.gz
else
    echo "FAILED: Could not apply transform to atlas with stem." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi
### END ADDITION

echo "Applying transform to T1 brain..."
flirt -in ${TEMPDIR}/T1_brain.nii.gz -ref ${OUTPUTDIR}/b0.nii.gz -applyxfm -init ${TEMPDIR}/t12b0.mat -out ${TEMPDIR}/T1_brain_in_DWI.nii.gz 
if [[ -f ${TEMPDIR}/T1_brain_in_DWI.nii.gz ]]; then
	echo "T1 brain found in DWI space. Proceeding to next step." >> ${OUTPUTDIR}/log.txt
else
	echo "ERROR FOUND: Apply transform failed. Exiting" >> ${OUTPUTDIR}/log.txt
	exit 0
fi


echo "Map tracks to Connectomes -NOS, Mean Length, FA-, guided by atlas..." >> ${OUTPUTDIR}/log.txt
# Map tracks to connectome (weighted by NOS)
tck2connectome ${TCK_FILE} ${ATLAS} ${TEMPDIR}/CONNECTOME_Weight_NUMSTREAMLINES_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv -symmetric
if test -f "${TEMPDIR}/CONNECTOME_Weight_NUMSTREAMLINES_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv"; then
    echo "Successfully created connectome weighted by number of streamlines. Saiving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/CONNECTOME_Weight_NUMSTREAMLINES_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv ${OUTPUTDIR}
else
    echo "FAILED: Did not create connectome weighted by number of streamlines." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

python /ConnectomeSpecial/CODE/convertconnectometonp_nos.py  ${TEMPDIR}/CONNECTOME_Weight_NUMSTREAMLINES_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv  ${TEMPDIR}/CONNECTOME_NUMSTREAM.npy ${NUMSTREAMS}
if test -f "${TEMPDIR}/CONNECTOME_NUMSTREAM.npy"; then
    echo "Successfully converted csv to npy and performed adaptive thresholding. Saiving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/CONNECTOME_NUMSTREAM.npy ${OUTPUTDIR}
else
    echo "FAILED: Did not convert connectome." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

# Map tracks to connectome (weighted by Mean Length of streamline)
tck2connectome ${TCK_FILE} ${ATLAS} ${TEMPDIR}/CONNECTOME_Weight_MEANLENGTH_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv -scale_length -stat_edge mean -symmetric
if test -f "${TEMPDIR}/CONNECTOME_Weight_MEANLENGTH_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv"; then
    echo "Successfully created connectome weighted by mean length of streamlines. Saiving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/CONNECTOME_Weight_MEANLENGTH_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv ${OUTPUTDIR}
else
    echo "FAILED: Did not create connectome weighted by number of streamlines." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

# Convert to npy
python /ConnectomeSpecial/CODE/convertconnectometonp.py  ${TEMPDIR}/CONNECTOME_Weight_MEANLENGTH_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv ${TEMPDIR}/CONNECTOME_LENGTH.npy
if test -f "${TEMPDIR}/CONNECTOME_LENGTH.npy"; then
    echo "Successfully converted csv to npy. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/CONNECTOME_LENGTH.npy ${OUTPUTDIR}
else
    echo "FAILED: Did not convert connectome." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Compute FA per streamline and create the FA weighted connectome..." >> ${OUTPUTDIR}/log.txt
tcksample ${TCK_FILE} ${PREQUALDIR}/SCALARS/dwmri_tensor_fa.nii.gz ${TEMPDIR}/mean_FA_per_streamline.csv -stat_tck mean
tck2connectome ${TCK_FILE} ${ATLAS} ${TEMPDIR}/CONNECTOME_Weight_MeanFA_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv -scale_file ${TEMPDIR}/mean_FA_per_streamline.csv -stat_edge mean -symmetric
if test -f "${TEMPDIR}/CONNECTOME_Weight_MeanFA_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv"; then
    echo "Successfully created connectome weighted by mean FA. Saiving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/CONNECTOME_Weight_MeanFA_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv ${OUTPUTDIR}
else
    echo "FAILED: Did not create connectome weighted by number of streamlines." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

python /ConnectomeSpecial/CODE/convertconnectometonp.py  ${TEMPDIR}/CONNECTOME_Weight_MeanFA_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv ${TEMPDIR}/CONNECTOME_FA.npy
if test -f "${TEMPDIR}/CONNECTOME_FA.npy"; then
    echo "Successfully converted csv to npy. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/CONNECTOME_FA.npy ${OUTPUTDIR}
else
    echo "FAILED: Did not convert connectome." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

# Get graph measure
python /APPS/scilpy/getgraphmeasures.py  ${TEMPDIR}/CONNECTOME_NUMSTREAM.npy ${TEMPDIR}/CONNECTOME_LENGTH.npy  ${TEMPDIR}/graphmeasures.json --avg_node_wise
python /APPS/scilpy/getgraphmeasures.py  ${TEMPDIR}/CONNECTOME_NUMSTREAM.npy ${TEMPDIR}/CONNECTOME_LENGTH.npy  ${TEMPDIR}/graphmeasures_nodes.json

if test -f "${TEMPDIR}/graphmeasures.json"; then
    echo "Successfully computed global graph measures. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/graphmeasures.json ${OUTPUTDIR}
else
    echo "FAILED: Did not compute global graph measures." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

if test -f "${TEMPDIR}/graphmeasures_nodes.json"; then
    echo "Successfully computed nodal graph measures. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/graphmeasures_nodes.json ${OUTPUTDIR}
else
    echo "FAILED: Did not compute nodal graph measures." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

####
#these lines added by Michael Kim for computing connectome with brainstem

echo "Map tracks to Connectomes -NOS, Mean Length, FA-, guided by atlas with stem..." >> ${OUTPUTDIR}/log.txt
# Map tracks to connectome (weighted by NOS)
export CONN_WEIGHT_STEM=${TEMPDIR}/CONNECTOME_Weight_NUMSTREAMLINES_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT_w_stem.csv
tck2connectome ${TCK_FILE} ${SLANT_SUBJ_STEM} ${CONN_WEIGHT_STEM} -symmetric
if test -f "${CONN_WEIGHT_STEM}"; then
    echo "Successfully created connectome weighted by number of streamlines. Saiving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${CONN_WEIGHT_STEM} ${OUTPUTDIR}
else
    echo "FAILED: Did not create connectome weighted by number of streamlines." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

export CONN_NPY_STEM=${TEMPDIR}/CONNECTOME_NUMSTREAM_stem.npy
python /ConnectomeSpecial/CODE/convertconnectometonp_nos.py  ${CONN_WEIGHT_STEM}  ${CONN_NPY_STEM} ${NUMSTREAMS}
if test -f "${TEMPDIR}/CONNECTOME_NUMSTREAM.npy"; then
    echo "Successfully converted csv to npy with stem and performed adaptive thresholding. Saiving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${CONN_NPY_STEM} ${OUTPUTDIR}
else
    echo "FAILED: Did not convert connectome." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

# Map tracks to connectome (weighted by Mean Length of streamline)
export CONN_NOS_STEM=${TEMPDIR}/CONNECTOME_Weight_MEANLENGTH_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT_w_stem.csv
tck2connectome ${TCK_FILE} ${SLANT_SUBJ_STEM} ${CONN_NOS_STEM} -scale_length -stat_edge mean -symmetric
if test -f "${CONN_NOS_STEM}"; then
    echo "Successfully created connectome weighted by mean length of streamlines with stem. Saiving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${CONN_NOS_STEM} ${OUTPUTDIR}
else
    echo "FAILED: Did not create connectome weighted by number of streamlines with stem." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

# Convert to npy
export NOS_NPY_STEM=${TEMPDIR}/CONNECTOME_LENGTH_stem.npy
python /ConnectomeSpecial/CODE/convertconnectometonp.py  ${CONN_NOS_STEM} ${NOS_NPY_STEM}
if test -f "${NOS_NPY_STEM}"; then
    echo "Successfully converted csv to npy with stem. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${NOS_NPY_STEM} ${OUTPUTDIR}
else
    echo "FAILED: Did not convert connectome with stem NOS." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Compute FA per streamline and create the FA weighted connectome..." >> ${OUTPUTDIR}/log.txt
export FA_STEM_SCALE=${TEMPDIR}/mean_FA_per_streamline_w_stem.csv
export FA_STEM_CSV=${TEMPDIR}/CONNECTOME_Weight_MeanFA_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT_w_stem.csv
tcksample ${TCK_FILE} ${PREQUALDIR}/SCALARS/dwmri_tensor_fa.nii.gz ${FA_STEM_SCALE} -stat_tck mean
tck2connectome ${TCK_FILE} ${SLANT_SUBJ_STEM} ${FA_STEM_CSV} -scale_file ${FA_STEM_SCALE} -stat_edge mean -symmetric
if test -f "${FA_STEM_CSV}"; then
    echo "Successfully created connectome weighted by mean FA w stem. Saiving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${FA_STEM_CSV} ${OUTPUTDIR}
else
    echo "FAILED: Did not create connectome weighted by number of streamlines." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

export FA_STEM_NPY=${TEMPDIR}/CONNECTOME_FA_stem.npy
python /ConnectomeSpecial/CODE/convertconnectometonp.py  ${FA_STEM_CSV} ${FA_STEM_NPY}
if test -f "${FA_STEM_NPY}"; then
    echo "Successfully converted csv to npy. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${FA_STEM_NPY} ${OUTPUTDIR}
else
    echo "FAILED: Did not convert connectome w stem." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

# Get graph measure

export GLOBAL_STEM=${TEMPDIR}/graphmeasures_w_stem.json
export NODAL_STEM=${TEMPDIR}/graphmeasures_nodes_w_stem.json
python /APPS/scilpy/getgraphmeasures.py  ${CONN_NPY_STEM} ${NOS_NPY_STEM}  ${GLOBAL_STEM} --avg_node_wise
python /APPS/scilpy/getgraphmeasures.py  ${CONN_NPY_STEM} ${NOS_NPY_STEM}  ${NODAL_STEM}

if test -f "${GLOBAL_STEM}"; then
    echo "Successfully computed global graph measures. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${GLOBAL_STEM} ${OUTPUTDIR}
else
    echo "FAILED: Did not compute global graph measures w stem." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

if test -f "${NODAL_STEM}"; then
    echo "Successfully computed nodal graph measures. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${NODAL_STEM} ${OUTPUTDIR}
else
    echo "FAILED: Did not compute nodal graph measures w stem." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Completed Connectome special." >> ${OUTPUTDIR}/log.txt
date >> ${OUTPUTDIR}/log.txt

echo "Creating QA document..."
python /ConnectomeSpecial/CODE/qa.py ${OUTPUTDIR}/b0.nii.gz ${ATLAS} ${OUTPUTDIR}/CONNECTOME_NUMSTREAM.npy ${OUTPUTDIR}/CONNECTOME_LENGTH.npy ${OUTPUTDIR}/CONNECTOME_FA.npy ${OUTPUTDIR}/graphmeasures.json ${OUTPUTDIR}/log.txt ${OUTPUTDIR}/ConnectomeQA.png

echo "Cleaning temporary directory..."
rm -r ${TEMPDIR}
