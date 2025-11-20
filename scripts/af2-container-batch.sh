#!/bin/bash

#SBATCH --time=24:00:00                 # Requested walltime
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --ntasks=1                      # Number of tasks (MPI processes)
#SBATCH --cpus-per-task=8               # Number of CPU cores per task
#SBATCH --gpus-per-node=1               # Number of GPUs
#SBATCH --mem=32GB                      # Requested memory
#SBATCH --job-name=af2_batch            # Job name
#SBATCH --account=def-yanyan-ab         # Account allocation code
#SBATCH --output=%x-%A_%a.out           # (%x=jobname, %A=ArrayId, %a=TaskID)
#SBATCH --error=%x-%A_%a.err  
#SBATCH --array=1-4  
################################################################################
echo "Start Array Job ${SLURM_ARRAY_TASK_ID} on $(hostname)"

cd $SLURM_SUBMIT_DIR

DOWNLOAD_DIR="/cvmfs/bio.data.computecanada.ca/content/databases/Core/alphafold2_dbs/2024_01"
INPUT_DIR=$SCRATCH/af2/input
OUTPUT_DIR=$SCRATCH/af2/output

readarray -t FASTA_FILES < <(find "${INPUT_DIR}" -maxdepth 1 -type f -name "*.fasta")
FASTA_PATH=${FASTA_FILES[$((SLURM_ARRAY_TASK_ID - 1))]}

echo "The job will proceed: ${FASTA_PATH}"
echo "Output will save in: ${OUTPUT_DIR}"

module load apptainer

apptainer exec \
   --nv \
   -B /lustre06/project \
   -B /scratch \
   -B /cvmfs \
   --home=$PWD \
   /home/houd/alphafold2.sif \
   python /opt/alphafold/run_alphafold.py \
   --fasta_paths=${FASTA_PATH} \
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

echo "Array Job ${SLURM_ARRAY_TASK_ID} complete."
