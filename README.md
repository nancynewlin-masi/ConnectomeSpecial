# MASI Lab Connectome Special
Code implementation by Nancy Newlin.

## setup.sh
For a given dataset on nfs2, matches prequal and slant outputs. Then, sets up commands to run connectome special in a job array format. 

## main.sh
This is a wrapper around the singularity command to make sure all of the input directories are properly bound and on accre, runs the singularity, and then sends the outputs of the singularity to nfs2 (automatically generates the destination as "/nfs2/harmonization/raw/${DATASETNAME}_ConnectomeSpecial/sub-#_ses-#_run-#", with the naming as appropriate. 

## The Singularity 
Example: singularity run --bind ${workingpath_accre}/PreQual/:/DIFFUSION/,${workingpath_accre}/Slant/:/SLANT/,${workingpath_accre}/Output/:/OUTPUTS/ ${singularity_path}

## Outputs
* Graph measures computed using the Brain Connectivity Toolbox (global and nodal)
* Connectome weighted by Number of streamlines between brain regions
* Connectome weighted by average length in mm of streamline connecting brain regions
* Connectome weighted by average FA
* QA document

## Quality Control - Example visualization
The following document is generated automatically.
{WIP}

## Technical Notes
This script performs probabilistic tractography (MRtrix "iFOD2" algorithm, the default algorithm) using a white matter FOD. It is anatomicall constrained ("-act" setting on) using a 5-tissue-type mask generated from the associated structural image (T1 weighted scan). 
The atlas is SLANT https://github.com/MASILab/SLANTbrainSeg/tree/master. It determines the dimensions of the connectivity matrix (i.e. connectome). 
The lookup table is at /SUPPLEMENTAL/slant_origlabels.txt. 
Currently, the script defualt generates 10 million streamlines. We map this version to a connectome.
Then, to reduce the size we use a scilpy script to compress the tck file (track files can't be reduced easily by zipping/gzipping). 

## References
Please cite the following if using this singularity. 

* Tractography/Connectomics: https://www.mrtrix.org/
Tournier, J.-D.; Smith, R. E.; Raffelt, D.; Tabbara, R.; Dhollander, T.; Pietsch, M.; Christiaens, D.; Jeurissen, B.; Yeh, C.-H. & Connelly, A. MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. NeuroImage, 2019, 202, 116137
* Graph measures: https://sites.google.com/site/bctnet/
Complex network measures of brain connectivity: Uses and interpretations.
Rubinov M, Sporns O (2010) NeuroImage 52:1059-69.
* Tractogram compression: https://github.com/scilus/scilpy
* Image registration: https://github.com/ANTsX/ANTs/tree/master
Avants BB, Epstein CL, Grossman M, Gee JC. Symmetric diffeomorphic image registration with cross-correlation: evaluating automated labeling of elderly and neurodegenerative brain. Med Image Anal. 2008 Feb;12(1):26-41. doi: 10.1016/j.media.2007.06.004. Epub 2007 Jun 23. PMID: 17659998; PMCID: PMC2276735.
* If you're wondering why 10,000,000 streamlines, I wrote a paper about streamlines & graph measure robustness: https://onlinelibrary.wiley.com/doi/abs/10.1002/jmri.28631 Newlin NR, Rheault F, Schilling KG, Landman BA. Characterizing streamline count invariant graph measures of structural connectomes. J Magn Reson Imaging. 2023;
