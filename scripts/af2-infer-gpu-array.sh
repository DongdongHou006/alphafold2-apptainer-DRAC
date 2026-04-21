#!/bin/bash
#SBATCH --job-name=af2_infer
#SBATCH --account=def-yanyan-ab
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --gpus-per-node=1
#SBATCH --mem=24G
#SBATCH --output=%x-%A_%a.out
#SBATCH --error=%x-%A_%a.err
#SBATCH --array=1-8%1

set -euo pipefail

echo "Stage 2 (GPU inference, use precomputed MSAs) task ${SLURM_ARRAY_TASK_ID} on $(hostname)"
cd "$SLURM_SUBMIT_DIR"

# ---- Paths ----
DOWNLOAD_DIR="/cvmfs/bio.data.computecanada.ca/content/databases/Core/alphafold2_dbs/2024_01"
INPUT_DIR="$SCRATCH/af2/input"
OUTPUT_DIR="$SCRATCH/af2/output"
SIF="/home/houd/alphafold2.sif"

# ---- Execution Parameters ----
MODEL_PRESET="multimer"
DB_PRESET="full_dbs"
MAX_TEMPLATE_DATE="2023-12-31"
NUM_MULTIMER_PRED_PER_MODEL=5
MODELS_TO_RELAX="none"

# ---- Pick FASTA for this array task (stable order) ----
readarray -t FASTA_FILES < <(find "${INPUT_DIR}" -maxdepth 1 -type f -name "*.fasta" | sort)
N=${#FASTA_FILES[@]}
IDX=$((SLURM_ARRAY_TASK_ID - 1))
if (( IDX < 0 || IDX >= N )); then
  echo "ERROR: task ${SLURM_ARRAY_TASK_ID} out of range; found ${N} fasta files in ${INPUT_DIR}"
  exit 1
fi
FASTA_PATH="${FASTA_FILES[$IDX]}"
TARGET="$(basename "$FASTA_PATH" .fasta)"

echo "FASTA:  ${FASTA_PATH}"
echo "TARGET: ${TARGET}"
echo "OUTPUT: ${OUTPUT_DIR}"

# ---- Pre-flight checks: Stage A must have produced MSAs under output/<TARGET>/msas ----
MSA_DIR="${OUTPUT_DIR}/${TARGET}/msas"
if [[ ! -d "$MSA_DIR" ]]; then
  echo "ERROR: precomputed MSA directory not found: ${MSA_DIR}"
  echo "       Please run Stage A (MSA-only) first to generate MSAs for this target."
  exit 1
fi

module load apptainer

# ---- GPU inference only (skip MSA generation) ----
apptainer exec --cleanenv \
  --nv \
  -B /lustre06/project \
  -B /scratch \
  -B /cvmfs \
  "$SIF" \
  python /opt/alphafold/run_alphafold.py \
    --fasta_paths="${FASTA_PATH}" \
    --output_dir="${OUTPUT_DIR}" \
    --data_dir="${DOWNLOAD_DIR}" \
    --db_preset="${DB_PRESET}" \
    --model_preset="${MODEL_PRESET}" \
    --use_precomputed_msas=True \
    --bfd_database_path="${DOWNLOAD_DIR}/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt" \
    --mgnify_database_path="${DOWNLOAD_DIR}/mgnify/mgy_clusters_2022_05.fa" \
    --template_mmcif_dir="${DOWNLOAD_DIR}/pdb_mmcif/mmcif_files" \
    --obsolete_pdbs_path="${DOWNLOAD_DIR}/pdb_mmcif/obsolete.dat" \
    --pdb_seqres_database_path="${DOWNLOAD_DIR}/pdb_seqres/pdb_seqres.txt" \
    --uniprot_database_path="${DOWNLOAD_DIR}/uniprot/uniprot.fasta" \
    --uniref30_database_path="${DOWNLOAD_DIR}/uniref30/UniRef30_2021_03" \
    --uniref90_database_path="${DOWNLOAD_DIR}/uniref90/uniref90.fasta" \
    --max_template_date="${MAX_TEMPLATE_DATE}" \
    --num_multimer_predictions_per_model="${NUM_MULTIMER_PRED_PER_MODEL}" \
    --use_gpu_relax='True'

echo "Stage 2 done for task ${SLURM_ARRAY_TASK_ID}"