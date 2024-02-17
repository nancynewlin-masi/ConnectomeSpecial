export prequalpath_nfs2=${1}
export slantpath_nfs2=${2}
export mypath=/nobackup/p_masi_brain_map/newlinnr/ConnectomeSpecial/
export myuser=newlinnr
export singularity_path=/nobackup/p_masi_brain_map/newlinnr/ConnectomeSpecial/ConnectomeSpecial.sif

# Extract sub- part
sub_part="${prequalpath_nfs2#*sub-}"
sub_part="${sub_part%%/*}"

# Extract ses- part
ses_part="${prequalpath_nfs2#*ses-}"
ses_part="${ses_part%%/*}"

# Extract PreQualrun- part
run_part="${prequalpath_nfs2#*PreQualrun-}"
run_part="${run_part%%/*}"

# Check if the "run_part" is empty using bash parameter expansion
if [ -z "${run_part}" ]; then
    echo "The 'run_part' is empty."
    export workingpath_accre=${mypath}/temp_sub-${sub_part}_ses-${ses_part}/
else
    echo "The 'run_part' contains: $run_part"
    export workingpath_accre=${mypath}/temp_sub-${sub_part}_ses-${ses_part}_run-${run_part}/
fi

echo "Subject: $sub_part"
echo "Session: $ses_part"
echo "Run: $run_part"


mkdir ${workingpath_accre}
scp -r ${myuser}@hickory.accre.vanderbilt.edu:${prequalpath_nfs2} ${myuser}@hickory.accre.vanderbilt.edu:${workingpath_accre}/PreQual/
scp -r ${myuser}@hickory.accre.vanderbilt.edu:${slantpath_nfs2} ${myuser}@hickory.accre.vanderbilt.edu:${workingpath_accre}/Slant/
mkdir ${workingpath_accre}/Output/
echo singularity run --bind ${workingpath_accre}/PreQual/:/DIFFUSION/,${workingpath_accre}/Slant/:/SLANT/,${workingpath_accre}/Output/:/OUTPUTS/ ${singularity_path}
