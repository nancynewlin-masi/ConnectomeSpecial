# How to run/Inputs:
bash main.sh {diffusion data directory} {freesurfer output directory} {unique ID}  {output directory}
* Diffusion Data directory: Should be PreQualled data. Expects to be named as dwmri.nii.gz, dwmri.bvec, dwmri.bval
* Freesurfer output directory: expects to be organized as it is output from Freesurfer processing. We use aparc+aseg.mgz and T1.mgz from here to make the Desikan Killany atlas and 5tt mask.
* Unique ID: Can be anything, but it's needed to keep the temporary directories separate when processing a lot at once. Example: subject_session_run
* Output directory: wherever you want the output to be stored.

# Outputs
* Graph measures computed using the Brain Connectivity Toolbox
* Connectome weighted by Number of streamlines between brain regions
* Connectome weighted by average length in mm of streamline connecting brain regions

# Customizable hyperparameters
* The number of streamlines used for tractography are 10,000,000. This can be changed in the script.
* The working directory is where the script expected the "support_scripts" folder to be, and where the temporary directories will be made.

# Technical Notes
This script performs probabilistic tractography (MRtrix "iFOD2" algorithm, the default algorithm) using a white matter FOD. It is anatomicall constrained ("-act" setting on) using a 5-tissue-type mask generated from the associated structural image (T1 weighted scan). 
The atlas is SLANT https://github.com/MASILab/SLANTbrainSeg/tree/master. It determines the dimensions of the connectivity matrix (i.e. connectome). 
The lookup table is at /SUPPLEMENTAL/slant_origlabels.txt. 
Currently, the script defualt generates 10 million streamlines. We map this version to a connectome.
Then, to reduce the size we use a scilpy script to compress the tck file (track files can't be reduced easily by zipping/gzipping). 

# References
* Tractography/Connectomics: https://www.mrtrix.org/
Tournier, J.-D.; Smith, R. E.; Raffelt, D.; Tabbara, R.; Dhollander, T.; Pietsch, M.; Christiaens, D.; Jeurissen, B.; Yeh, C.-H. & Connelly, A. MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. NeuroImage, 2019, 202, 116137
* Graph measures: https://sites.google.com/site/bctnet/
Complex network measures of brain connectivity: Uses and interpretations.
Rubinov M, Sporns O (2010) NeuroImage 52:1059-69.
* Tractogram compression: https://github.com/scilus/scilpy
* Image registration: https://github.com/ANTsX/ANTs/tree/master
Avants BB, Epstein CL, Grossman M, Gee JC. Symmetric diffeomorphic image registration with cross-correlation: evaluating automated labeling of elderly and neurodegenerative brain. Med Image Anal. 2008 Feb;12(1):26-41. doi: 10.1016/j.media.2007.06.004. Epub 2007 Jun 23. PMID: 17659998; PMCID: PMC2276735.
* If you're wondering why 10,000,000 streamlines, I wrote a paper about streamlines & graph measure robustness: https://onlinelibrary.wiley.com/doi/abs/10.1002/jmri.28631 Newlin NR, Rheault F, Schilling KG, Landman BA. Characterizing streamline count invariant graph measures of structural connectomes. J Magn Reson Imaging. 2023;
