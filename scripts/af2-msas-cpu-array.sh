#!/bin/bash
#SBATCH --time=16:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64G
#SBATCH --job-name=af2_msas
#SBATCH --account=def-yanyan-ab
#SBATCH --output=%x-%A_%a.out
#SBATCH --error=%x-%A_%a.err
#SBATCH --array=1-12%4

set -euo pipefail

echo "Stage A (CPU-only MSA) task ${SLURM_ARRAY_TASK_ID} on $(hostname)"
cd "$SLURM_SUBMIT_DIR"

DOWNLOAD_DIR="/cvmfs/bio.data.computecanada.ca/content/databases/Core/alphafold2_dbs/2024_01"
INPUT_DIR="$SCRATCH/af2/input"
OUTPUT_DIR="$SCRATCH/af2/output"
PATCHED_SCRIPT="$SCRATCH/af2/tools/run_alphafold_msa_only.py"
SIF="/home/houd/alphafold2.sif"

# Basic checks
[[ -s "$PATCHED_SCRIPT" ]] || { echo "ERROR: missing patched script: $PATCHED_SCRIPT"; exit 1; }
grep -q "AF2_MSA_ONLY" "$PATCHED_SCRIPT" || { echo "ERROR: script not patched (AF2_MSA_ONLY not found)"; exit 1; }

mkdir -p "$OUTPUT_DIR"

# Pick FASTA for this task (stable order)
readarray -t FASTA_FILES < <(find "${INPUT_DIR}" -maxdepth 1 -type f -name "*.fasta" | sort)
N=${#FASTA_FILES[@]}
IDX=$((SLURM_ARRAY_TASK_ID - 1))
(( IDX >= 0 && IDX < N )) || { echo "ERROR: task ${SLURM_ARRAY_TASK_ID} out of range; found ${N} fasta files in ${INPUT_DIR}"; exit 1; }
FASTA_PATH="${FASTA_FILES[$IDX]}"

echo "FASTA:  ${FASTA_PATH}"
echo "OUTPUT: ${OUTPUT_DIR}"

module load apptainer

# CPU-only run (no --nv, no GPU requested)
apptainer exec \
  -B /lustre06/project \
  -B /scratch \
  -B /cvmfs \
  --env AF2_MSA_ONLY=1 \
  --env PYTHONPATH=/opt/alphafold \
  "$SIF" \
  python "$PATCHED_SCRIPT" \
    --fasta_paths="$FASTA_PATH" \
    --output_dir="$OUTPUT_DIR" \
    --data_dir="$DOWNLOAD_DIR" \
    --db_preset=full_dbs \
    --model_preset=multimer \
    --bfd_database_path="$DOWNLOAD_DIR/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt" \
    --mgnify_database_path="$DOWNLOAD_DIR/mgnify/mgy_clusters_2022_05.fa" \
    --template_mmcif_dir="$DOWNLOAD_DIR/pdb_mmcif/mmcif_files" \
    --obsolete_pdbs_path="$DOWNLOAD_DIR/pdb_mmcif/obsolete.dat" \
    --pdb_seqres_database_path="$DOWNLOAD_DIR/pdb_seqres/pdb_seqres.txt" \
    --uniprot_database_path="$DOWNLOAD_DIR/uniprot/uniprot.fasta" \
    --uniref30_database_path="$DOWNLOAD_DIR/uniref30/UniRef30_2021_03" \
    --uniref90_database_path="$DOWNLOAD_DIR/uniref90/uniref90.fasta" \
    --max_template_date=2023-12-31 \
    --use_gpu_relax=False
echo "Stage A done for task ${SLURM_ARRAY_TASK_ID}"