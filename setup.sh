# This code is meant to run in a place that can "see" nfs2 (i.e. NOT from an accre job node). 
# Provided with a dataset path and a directory you want this code to run in. 
# It will create a folder with the dataset name (extracted from the path provided), and populate scripts (named like 1.sh, 2.sh,...) meant to be run as a job array on accre. 
# This code finds each prequal directory and matches it with a slant-ticv output directory.

export DATASETPATH=${1} # full path to directory you want to search over. Ex. /nfs2/harmonization/BIDS/BIOCARD/derivatives/
export WORKINGDIR=${2} # wherever you want to run the slurm from

export DATASET=$(echo "$DATASETPATH" | awk -F'/' '{print $(NF-2)}')
echo "Dataset name:" ${DATASET}
find ${DATASETPATH} -name "PreQual*" -type d >> ${WORKINGDIR}/listoflocations_${DATASET}
export index=1
mkdir ${WORKINGDIR}/scripts_${DATASET}
while IFS= read -r line; do
  echo Prequal directory: $line
  found_directory=$(find "${line}/../" -type d -name "SLANT-TICV*" -print -quit)

  if [ -n "$found_directory" ]; then
    echo "First SLANT directory found: $found_directory"
  else
    echo "No directory named SLANT* found."
  fi

  echo "#!/bin/bash" >> ${WORKINGDIR}/scripts_${DATASET}/${index}.sh
  echo "bash ${WORKINGDIR}/main.sh $line $found_directory" >> ${WORKINGDIR}/scripts_${DATASET}/${index}.sh
  export index=$((++index))
done < ${WORKINGDIR}/listoflocations_${DATASET}

mkdir /nfs2/harmonization/raw/${DATASET}_ConnectomeSpecial/
echo "$($index-1) directories found."
