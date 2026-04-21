# alphafold2-apptainer-DRAC

AlphaFold2 workflow for running inside an **Apptainer** container on the Digital Research Alliance of Canada (DRAC) clusters (e.g., Narval/Beluga/Cedar).

This repository documents how to:

- Build an `alphafold2.sif` Apptainer image in your `$HOME`
- Run **local AlphaFold2** jobs via SLURM using that container
- By optimizing the official script to run a **two-stage** pipeline to avoid wasting GPU resources:
  - **Stage A (CPU-only):** MSA/template search + feature generation (**no GPU requested**)
  - **Stage B (GPU):** inference (+ optional relax) using **precomputed MSAs** (**GPU requested**)

---

## 1. Repository structure

```text
alphafold2-apptainer-DRAC/
├─ apptainer/
│  └─ alphafold2.def                # Apptainer definition file (builds alphafold2.sif)
├─ scripts/
│  ├─ af2-msas-cpu-array.sh         # Stage A: CPU-only MSA/features (array job)
│  └─ af2-infer-gpu-array.sh        # Stage B: GPU inference (array job, uses precomputed MSAs)
├─ tools/
│  └─ run_alphafold_msa_only.py     # Patched driver: run MSA/template/features only (no inference)
└─ README.md
```

All implementation details are in the `.def` and `.sh` files in this repo.

---

## 2. Requirements

On DRAC (e.g. Narval/Beluga/Cedar):

* Valid Alliance account & allocation  <!-- * `StdEnv/2020` (or cluster-recommended) module stack -->
* `apptainer` module
* Access to AlphaFold2 databases via:

  * Local `$SCRATCH` (if you maintain your own copy), or
  * `/cvmfs/bio.data.computecanada.ca/content/databases/Core/alphafold2_dbs/`

Paths inside the scripts assume DRAC-style environment. Adjust for your project/account if needed.

---

## 3. Build the Apptainer image (`alphafold2.sif`)

Since building the container can take a long time, it is strongly recommended to do this inside a `tmux` session on a **fixed login node** to avoid interruptions.

1) SSH to a specific login node and confirm the hostname:

```bash
ssh <username>@narval3.alliancecan.ca
hostname
```

Make a note of the hostname (e.g. `narval3.alliancecan.ca`). You must reconnect to the **same node** later when re-attaching to `tmux`.

2) Start a `tmux` session:

```bash
tmux new -s build_container
```

3) Inside the `tmux` session, load Apptainer and go to the repo directory:

```bash
module load apptainer
cd ~/alphafold2-apptainer-DRAC
```

4) Build the Apptainer image:

```bash
apptainer build ~/alphafold2.sif apptainer/alphafold2.def
```

5) You can safely detach from tmux while the build is running:

- Press `Ctrl+B` then `D` to detach.

6) To resume and check progress later:

- First SSH back to the same login node you used in step 1 (e.g. `narval3`)
- Then list and attach the session:

```bash
tmux ls
tmux attach -t build_container
```

After a successful build, you should see the image under your home directory:

```bash
ls -lh ~/alphafold2.sif
```


## 4. Prepare `$SCRATCH` layout

```bash
mkdir -p $SCRATCH/af2/input
mkdir -p $SCRATCH/af2/output
mkdir -p $SCRATCH/af2/log
mkdir -p $SCRATCH/af2/tools
```

Copy the file `run_alphafold_msa_only.py` (required by `scripts/af2-msas-cpu-array.sh`) to the `$SCRATCH` directory:

```bash
cd ~/alphafold2-apptainer-DRAC
cp tools/run_alphafold_msa_only.py $SCRATCH/af2/tools/
```

You can verify it exists:

```bash
ls -lh $SCRATCH/af2/tools/run_alphafold_msa_only.py
```

Put your FASTA files into:

```text
$SCRATCH/af2/input/*.fasta
```

### AF2 multimer FASTA format (local AlphaFold2)

For local AlphaFold2 multimer, a complex is represented by multiple FASTA entries in the same file (one entry per chain), e.g.:

```text
>ChainA
SEQUENCE_A...
>ChainB
SEQUENCE_B...
```

Do NOT use ColabFold’s `:`-concatenated chain format (e.g., `SEQA:SEQB`) for local AF2.


## 5. Decide array size

Both Stage A and Stage B scripts select the FASTA file based on the task index (`$SLURM_ARRAY_TASK_ID`) and a sorted list of FASTA files:

- Task 1 uses the **1st** FASTA in the sorted list
- Task 2 uses the **2nd** FASTA in the sorted list
- ...
- Task N uses the **Nth** FASTA in the sorted list

Therefore, you must set `--array=1-N` where **N is the number of FASTA files** in `$SCRATCH/af2/input`.

Check the list and its stable order with:

```bash
cd $SCRATCH/af2/input
find "$PWD" -maxdepth 1 -type f -name "*.fasta" | sort | nl -ba
```

If the last index shown is `N`, submit with one of:

- safest: `--array=1-N%1` (one job at a time)
- limited parallelism: `--array=1-N%2` or `--array=1-N%4`

> Tip: Always keep `sort` so the mapping between array index and FASTA file is deterministic.


## 6. Stage A (CPU-only): MSAs/templates/features

Submit Stage A job:

```bash
cd $SCRATCH/af2
sbatch scripts/af2-msas-cpu-array.sh
```

In this stage:

- request **no GPU**
- run MSA tools (JackHMMER / HHblits) + template search
- write MSAs and intermediate files under:

```text
$SCRATCH/af2/output/<target_name>/msas/
```

Resource notes:

- MSA search is CPU + I/O heavy; runtime varies.
- Start conservative, then tune:
  - `--cpus-per-task=1` or `2` (use historical **CPU Efficiency** / `TotalCPU` as guidance)
  - memory often needs **≥ 32G** for `full_dbs` (use historical **MaxRSS** as guidance)
  - limit concurrency with `%2` / `%4` to avoid launching too many heavy searches simultaneously



## 7. Stage B (GPU): inference using precomputed MSAs

After Stage A completes for your targets, submit Stage B job:

```bash
cd $SCRATCH/af2
sbatch scripts/af2-infer-gpu-array.sh
```

This stage:

- request a GPU
- script has set `--use_precomputed_msas=True` so no MSA tools run during this stage
- run JAX model inference and (optionally) Amber relax depending on `--models_to_relax`

Resource notes:

- For small 2-chain complexes, a common baseline is:
  - `--gpus-per-node=1`
  - `--cpus-per-task=2`
  - `--mem=24G`
  - `--time=02:00:00`
  - `--array=1-N%1` (most stable)


## 8. Outputs Confirm

Inside each target folder:

- `ranked_0.pdb` is the **top-ranked** prediction (best by AF2 ranking metric)
- `ranked_1.pdb`, `ranked_2.pdb`, ... are lower-ranked

Relaxation behavior depends on `--models_to_relax`:

- `best`: only the top-ranked structure is relaxed (most common for speed)
- `all`: relax all predictions (slow)
- `none`: no relax (fastest)



## 9. Notes & troubleshooting
- All examples assume DRAC clusters; adapt `--account`, partitions/queues, and paths to your environment.

- If a job fails, inspect the corresponding `*.out` and `*.err` logs.
  With the default patterns used in the scripts (`--output=%x-%A_%a.out`, `--error=%x-%A_%a.err`), you will typically see:
    - Stage A logs: `af2_msas-<ArrayID>_<TaskID>.out/.err`
    - Stage B logs: `af2_infer-<ArrayID>_<TaskID>.out/.err`

* Common issues:

  * Wrong or missing database paths
  * Invalid FASTA format (illegal characters, extra spaces)
* If you modify `alphafold2.def` or core dependencies, rebuild `alphafold2.sif`.

- UniRef30 path: On DRAC, UniRef30 is provided as an HH-suite database **prefix**, not a directory.
  - Example prefix:
    - `/.../uniref30/UniRef30_2021_03`
  - Backing files look like:
    - `UniRef30_2021_03_a3m.ffdata`, `..._a3m.ffindex`, `..._hhm.ffdata`, `..._hhm.ffindex`


- What is `run_alphafold_msa_only.py`?

  - Stage A is designed to generate MSAs/templates/features only without running inference.  `tools/run_alphafold_msa_only.py` is a **patched copy** of AlphaFold2’s `run_alphafold.py` that:
    - runs the data pipeline (JackHMMER / HHblits + template search + feature generation)
    - writes outputs under `$SCRATCH/af2/output/<target_name>/` (e.g., `msas/`, `features.pkl`)
    - exits before the JAX model inference / relaxation stage




## 10. Related Projects

* **[colabFold-apptainer-DRAC](https://github.com/DongdongHou006/colabfold-apptainer-DRAC)**: Our standard ColabFold (v1.5.5) deployment workflow for DRAC clusters. It features a two-step workflow to bypass public server quota limits and resolve the "no-internet-access" restriction on the compute node.
  
---
For internal use by DRAC users who need a reproducible AlphaFold2 Apptainer workflow with a CPU/GPU split.
