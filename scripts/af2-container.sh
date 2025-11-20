#!/bin/bash

#SBATCH --time=24:00:00                  # Requested walltime
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --ntasks=1                      # Number of tasks (MPI processes)
#SBATCH --cpus-per-task=8               # Number of CPU cores per task
#SBATCH --gpus-per-node=1               # Number of GPUs
#SBATCH --mem=64GB                      # Requested memory
#SBATCH --job-name=alphafold_ATPase     # Job name
#SBATCH --account=def-yanyan-ab         # Account allocation code
#SBATCH --output=alphafold2.job%j.out    # Output file
#SBATCH --error=alphafold2.job%j.err      # Error file

################################################################################

cd $SLURM_SUBMIT_DIR

module load apptainer

DOWNLOAD_DIR="/cvmfs/bio.data.computecanada.ca/content/databases/Core/alphafold2_dbs/2024_01"
INPUT_DIR=$SCRATCH/af2/input
OUTPUT_DIR=$SCRATCH/af2/output

apptainer exec \
   --nv \
   -B /lustre06/project \
   -B /scratch \
   -B /cvmfs \
   --home=$PWD \
   /home/houd/alphafold2.sif \
   python /opt/alphafold/run_alphafold.py \
   #--fasta_paths=${INPUT_DIR}/B.H.68.V.fasta \
   --fasta_paths=${INPUT_DIR}/B.T.9.P.G.10.R.T.12.Y.fasta \
   --output_dir=${OUTPUT_DIR} \
   --data_dir=${DOWNLOAD_DIR} \
   --db_preset=full_dbs \
   --model_preset=multimer \
   --bfd_database_path=${DOWNLOAD_DIR}/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
   --mgnify_database_path=${DOWNLOAD_DIR}/mgnify/mgy_clusters_2022_05.fa \
   --template_mmcif_dir=${DOWNLOAD_DIR}/pdb_mmcif/mmcif_files \
   --obsolete_pdbs_path=${DOWNLOAD_DIR}/pdb_mmcif/obsolete.dat \
   --pdb_seqres_database_path=${DOWNLOAD_DIR}/pdb_seqres/pdb_seqres.txt \
   --uniprot_database_path=${DOWNLOAD_DIR}/uniprot/uniprot.fasta \
   --uniref30_database_path=${DOWNLOAD_DIR}/uniref30/UniRef30_2021_03 \
   --uniref90_database_path=${DOWNLOAD_DIR}/uniref90/uniref90.fasta \
   --max_template_date=2023-12-31 \
   --use_gpu_relax='True'

