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
echo "Running Connectome Special version 1.0.0" >> ${OUTPUTDIR}/log.txt
date >> ${OUTPUTDIR}/log.txt
echo "SUBJECT_SESSION=$subses" >> ${OUTPUTDIR}/log.txt
echo "PARCELLATION=Slant, 133 ROIs" >> ${OUTPUTDIR}/log.txt
echo "NUMBER OF STREAMLINES=10,000,000" >> ${OUTPUTDIR}/log.txt
echo "REGISTRATION SOFTWARE=epireg" >> ${OUTPUTDIR}/log.txt

# Hyper parameters
export NUMSTREAMS=100   #10000000
export WORKINGDIR=/ConnectomeSpecial/

# Set up temporary directory that will be deleted at the end of processing
mkdir /OUTPUTS/TEMP/
export TEMPDIR=/OUTPUTS/TEMP/


# Define look up tables for atlas. One will be ordered, the other the original lookup table.
export ORIGLABELS=/ConnectomeSpecial/SUPPLEMENTAL/slant_origlabels.txt
export DESTLABELS=/ConnectomeSpecial/SUPPLEMENTAL/slant_orderedlabels.txt

#echo "Moving dwi to accre..."
#scp newlinnr@hickory.accre.vanderbilt.edu:${PREQUALDIR}/* newlinnr@hickory.accre.vanderbilt.edu:${TEMPDIR}
echo "Check for DWI"
export DWI=$(find $PREQUALDIR/PREPROCESSED/ -name "*dwmri.nii.gz")
export BVEC=$(find $PREQUALDIR/PREPROCESSED/ -name "*bvec")
export BVAL=$(find $PREQUALDIR/PREPROCESSED/ -name "*bval")

echo "Successfully DWI found at ${DWI}, ${BVEC}, ${BVAL}." >> ${OUTPUTDIR}/log.txt

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
    echo "Registering T1 to diffusion space..." >> ${OUTPUTDIR}/log.txt
    echo "Extract B0..."
    dwiextract ${DWI} -fslgrad ${BVEC} ${BVAL} - -bzero |  mrmath - mean ${TEMPDIR}/b0.nii.gz -axis 3

    if test -f "${TEMPDIR}/b0.nii.gz"; then
        echo "Successfully extracted B0 from DWI. Saving to /OUTPUTS/">> ${OUTPUTDIR}/log.txt
        cp ${TEMPDIR}/b0.nii.gz ${OUTPUTDIR}
    else
        echo "FAILED: Could not extract B0 from DWI.">> ${OUTPUTDIR}/log.txt
        exit 0;
    fi

    #echo "Apply PreQual brain mask to T1 image..." >> ${OUTPUTDIR}/log.txt
    #mri_mask ${T1} ${PREQUALDIR}/PREPROCESSED/mask.nii.gz ${TEMPDIR}/T1_brain.nii.gz
    echo "Apply brain mask to T1 image..." >> ${OUTPUTDIR}/log.txt
    bet ${T1} ${TEMPDIR}/T1_brain.nii.gz

    if test -f "${TEMPDIR}/T1_brain.nii.gz"; then
        echo "Successfully processed T1 brain." >> ${OUTPUTDIR}/log.txt
    else
        echo "FAILED: Could not get T1 brain." >> ${OUTPUTDIR}/log.txt
        exit 0;
    fi

    echo "Apply transforms to atlas image to register to subject space..."  >> ${OUTPUTDIR}/log.txt
    epi_reg --epi=${TEMPDIR}/b0.nii.gz --t1=${T1} --t1brain=${TEMPDIR}/T1_brain.nii.gz --out=${TEMPDIR}/b02t1

    if test -f "${TEMPDIR}/b02t1.mat"; then
        echo "Successfully computed a registration transform between T1 and b0." >> ${OUTPUTDIR}/log.txt
    else
        echo "FAILED: Registration failed. Exiting." >> ${OUTPUTDIR}/log.txt
        exit 0;
    fi

    echo "Convert transform to go in oppisite direction..."  >> ${OUTPUTDIR}/log.txt
    convert_xfm -omat ${TEMPDIR}/t12b0.mat -inverse ${TEMPDIR}/b02t1.mat

    echo "Apply transform to T1..."  >> ${OUTPUTDIR}/log.txt  # ${TEMPDIR}/T1_bet.nii.gz
    flirt -in ${T1} -ref ${TEMPDIR}/b0.nii.gz -applyxfm -init ${TEMPDIR}/t12b0.mat  -out ${TEMPDIR}/T1_inDWIspace.nii.gz
    if test -f "${TEMPDIR}/T1_inDWIspace.nii.gz"; then
        echo "CHECK: Registered T1 found. Proceeding to next step." >> ${OUTPUTDIR}/log.txt
    else
        echo "ERROR FOUND: Registration failed. Exiting" >> ${OUTPUTDIR}/log.txt
        exit 0;
    fi
fi

echo "Labelconvert to get the Slant atlas..." >> ${OUTPUTDIR}/log.txt
labelconvert ${SLANTSEG} $ORIGLABELS  $DESTLABELS ${TEMPDIR}/atlas_slant_t1.nii.gz
if test -f "${TEMPDIR}/atlas_slant_t1.nii.gz"; then
    echo "Successfully label converted slant image to sequential labels (1..n)." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: Could not label convert slant image to sequential labels (1..n)." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Apply transform to atlas..." >> ${OUTPUTDIR}/log.txt
flirt -in ${TEMPDIR}/atlas_slant_t1.nii.gz -ref ${TEMPDIR}/b0.nii.gz -applyxfm -init ${TEMPDIR}/t12b0.mat -out ${TEMPDIR}/atlas_slant_subj.nii.gz  -interp nearestneighbour
if test -f "${TEMPDIR}/atlas_slant_subj.nii.gz"; then
    echo "Successfully applied transform to atlas." >> ${OUTPUTDIR}/log.txt
    echo "Saving atlas as ${TEMPDIR}/atlas_slant_subj.nii.gz..." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/atlas_slant_subj.nii.gz ${OUTPUTDIR}
    export ATLAS=${TEMPDIR}/atlas_slant_subj.nii.gz
else
    echo "FAILED: Could not apply transform to atlas." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Estimate response functions for wm, gm, and csf..." >> ${OUTPUTDIR}/log.txt
# Estimate response functions
dwi2response tournier ${DWI} ${TEMPDIR}/sfwm.txt -fslgrad ${BVEC} ${BVAL}

echo "Get FOD functions from the estimated response function -single fiber white matter only-..." >> ${OUTPUTDIR}/log.txt
# Make FOD functions
echo "Checking how many shells dwi2response found..." >> ${OUTPUTDIR}/log.txt
nr_lines=$(wc -l < ${TEMPDIR}/sfwm.txt)
if [ $nr_lines -le 4 ]; then
    echo "NUMBER OF SHELLS=Single shell acquisition." >> ${OUTPUTDIR}/log.txt
    dwi2fod csd ${DWI} ${TEMPDIR}/sfwm.txt ${TEMPDIR}/wmfod.nii.gz  -fslgrad ${BVEC} ${BVAL}
else
    echo "NUMBER OF SHELLS=Multi shell acquisition." >> ${OUTPUTDIR}/log.txt
    echo "Recomputing response functions for each tissue type..." >> ${OUTPUTDIR}/log.txt
    dwi2response dhollander ${DWI} ${TEMPDIR}/wm.txt ${TEMPDIR}/gm.txt ${TEMPDIR}/csf.txt -fslgrad ${BVEC} ${BVAL}
    dwi2fod msmt_csd ${DWI} ${TEMPDIR}/wm.txt ${TEMPDIR}/wmfod.nii.gz  ${TEMPDIR}/gm.txt ${TEMPDIR}/gmfod.nii.gz  ${TEMPDIR}/csf.txt ${TEMPDIR}/csffod.nii.gz -fslgrad ${BVEC} ${BVAL}
fi

if test -f "${TEMPDIR}/wmfod.nii.gz"; then
    echo "Successfully estimated white matter fod." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: Did not estimate white matter fod." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi


echo "Get 5tt mask..."  >> ${OUTPUTDIR}/log.txt
# Get 5tt mask. "premasked" flag because the T1 has already been masked to be brain only.
5ttgen fsl ${TEMPDIR}/T1_brain.nii.gz ${TEMPDIR}/5tt_image.nii.gz -premasked

if test -f "${TEMPDIR}/5tt_image.nii.gz"; then
    echo "Successfully extracted five tissue type mask." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: Did not extract five tissue type mask." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Use 5tt mask to get the GM/WM boundary..."  >> ${OUTPUTDIR}/log.txt
# Get Grey matter -White matter boundary
5tt2gmwmi ${TEMPDIR}/5tt_image.nii.gz ${TEMPDIR}/gmwmSeed.nii.gz
if test -f "${TEMPDIR}/gmwmSeed.nii.gz"; then
    echo "Successfully extracted grey-matter white matter boundary." >> ${OUTPUTDIR}/log.txt
else
    echo "FAILED: Did not extract grey-matter white matter boundary." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Start tracking using probabilistic ACT... Warning: this step will be storage and time intensive." >> ${OUTPUTDIR}/log.txt
# Generate 10 million streamlines
# Takes time, and will be several GB of space
tckgen -act ${TEMPDIR}/5tt_image.nii.gz -backtrack -seed_gmwmi ${TEMPDIR}/gmwmSeed.nii.gz -select ${NUMSTREAMS} ${TEMPDIR}/wmfod.nii.gz ${TEMPDIR}/tractogram_${NUMSTREAMS}.tck
if test -f "${TEMPDIR}/tractogram_${NUMSTREAMS}.tck"; then
    echo "Successfully tracked 10 million streamlines." >> ${OUTPUTDIR}/log.txt
    echo "Save tck file as TCK_FILE=${TEMPDIR}/tractogram_${NUMSTREAMS}.tck..."  >> ${OUTPUTDIR}/log.txt
    export TCK_FILE=${TEMPDIR}/tractogram_${NUMSTREAMS}.tck
else
    echo "FAILED: Did create tractogram. Check storage space available." >> ${OUTPUTDIR}/log.txt
    exit 0;
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
    cp ${TEMPDIR}/CONNECTOME_Weight_NUMSTREAMLINES_NumStreamlines_${NUMSTREAMS}_Atlas_SLANT.csv ${OUTPUTDIR}
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

# Compress tractogram, save
python /APPS/scilpy/scil_compress_streamlines.py ${TCK_FILE} ${TEMPDIR}/tracks_${NUMSTREAMS}_compressed.tck
if test -f "${TEMPDIR}/tracks_${NUMSTREAMS}_compressed.tck"; then
    echo "Successfully compressed tck file. Saving to /OUTPUTS/." >> ${OUTPUTDIR}/log.txt
    cp ${TEMPDIR}/tracks_${NUMSTREAMS}_compressed.tck ${OUTPUTDIR}
else
    echo "FAILED: Did not compute nodal graph measures." >> ${OUTPUTDIR}/log.txt
    exit 0;
fi

echo "Completed Connectome special." >> ${OUTPUTDIR}/log.txt
date >> ${OUTPUTDIR}/log.txt

echo "Creating QA document..."
python /ConnectomeSpecial/CODE/qa.py ${TEMPDIR}/b0.nii.gz ${ATLAS} ${OUTPUTDIR}/CONNECTOME_NUMSTREAM.npy ${OUTPUTDIR}/CONNECTOME_LENGTH.npy ${OUTPUTDIR}/CONNECTOME_FA.npy ${OUTPUTDIR}/graphmeasures.json ${OUTPUTDIR}/log.txt ${OUTPUTDIR}/ConnectomeQA.png

echo "Cleaning temporary directory..."
rm -r ${TEMPDIR}
