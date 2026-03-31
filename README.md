# alphafold2-apptainer-DRAC

AlphaFold2 workflow for running inside an Apptainer container on the Digital Research Alliance of Canada (DRAC) clusters.

This repository documents how to:

- Build an `alphafold2.sif` Apptainer image in your `$HOME`
- Submit AlphaFold2 jobs via SLURM using that container
- Optionally run batch predictions from multiple FASTA files

---

## 1. Repository structure

```text
alphafold2-apptainer-DRAC/
├─ apptainer/
│  └─ alphafold2.def           # Apptainer definition file (builds alphafold2.sif)
├─ scripts/
│  ├─ af2-container.sh         # SLURM script: run AlphaFold2 for a single FASTA
│  └─ af2-container-batch.sh   # SLURM script: submit multiple FASTA jobs (optional)
└─ README.md
````

All implementation details are in the `.def` and `.sh` files in this repo.



## 2. Requirements

On DRAC (e.g. Narval/Beluga/Cedar):

* Valid Alliance account & allocation  <!-- * `StdEnv/2020` (or cluster-recommended) module stack -->
* `apptainer` module
* Access to AlphaFold2 databases via:

  * Local `$SCRATCH` (if you maintain your own copy), or
  * `/cvmfs/bio.data.computecanada.ca/content/databases/Core/alphafold2_dbs/`

Paths inside the scripts assume DRAC-style environment. Adjust for your project/account if needed.



## 3. Build the Apptainer image (`alphafold2.sif`)

Since building the container can take a long time, it is strongly recommended to do this inside a `tmux` session on a fixed login node to avoid interruptions.

1. SSH to a specific Narval login node and confirm the hostname, for example:
  ```bash
  ssh <username>@narval3.alliancecan.ca
  hostname
  ```
Make a note of the hostname (e.g. narval3.alliancecan.ca). You must reconnect to the same node later when re-attaching to `tmux`.

2. Start a `tmux` session:

  ```bash
  tmux new -s build_container
  ```

3. Inside the `tmux` session, load Apptainer and go to the repo directory:

  ```bash 
  module load apptainer
  cd ~/alphafold2-apptainer-DRAC
  ```
4. Build the Apptainer image:
  ```bash 
  apptainer build alphafold2.sif apptainer/alphafold2.def
  ```
5. You can safely detach from tmux while the build is running:
  * Press `Ctrl+B` then `D` to detach.

6. To resume and check progress later:
  * First SSH back to the same login node you used in step 1 (e.g.):
    ```bash 
    ssh <username>@narval3.alliancecan.ca
    ```
  * Then list and attach the session:
    ```bash 
    tmux ls
    tmux attach -t build_container
    ```
After a successful build, you should see the image under your home directory:

```bash
ls ~/alphafold2.sif
```


## 4. Run AlphaFold2 (single job)

Prepare input/output directories in `$SCRATCH`:

```bash
mkdir -p $SCRATCH/af2/input
mkdir -p $SCRATCH/af2/output
```

Copy the `af2-container.sh` to `$SCRATCH/af2/` and your FASTA file(s) into `input/`, then submit:

```bash
cd $SCRATCH/af2
sbatch --job-name=af2_container scripts/af2-container.sh
```

The `af2-container.sh` script typically:

* Loads required modules
* Binds database directories (CVMFS)
* Uses `alphafold2.sif` to run `run_alphafold.py`

* Reads `$SCRATCH/af2/input/*.fasta` and writes results to `$SCRATCH/af2/output/`

Update in the script as needed:

* Walltime / memory and GPU requests
* `--account=...`
* `DOWNLOAD_DIR=...` database directories 
* `alphafold2.sif` paths
* `--fasta_paths=...`



## 5. Run AlphaFold2 (Batch mode)

Place multiple `.fasta` files into:

```bash
$SCRATCH/af2/input/
```

Submit the batch script:

```bash
cd $SCRATCH/af2
sbatch scripts/af2-container-batch.sh
```

`af2-container-batch.sh` should submit one AlphaFold2 job per FASTA file in the input directory (see script for details).

Updata the number of your FASTA files in the script:`SBATCH --array=...` 



## 6. Notes & troubleshooting

* All examples assume DRAC clusters; adapt `--account`, partitions/queues, and paths to your environment.
* If a job fails, please always inspect the corresponding `alphafold2.job*.err`,`alphafold2.job*.out` log of a single job and `af2_batch-*.err`,`af2_batch-*.out` log of batch mode.
* Common issues:

  * Wrong or missing database paths
  * Invalid FASTA format (illegal characters, extra spaces)
* If you modify `alphafold2.def` or core dependencies, rebuild `alphafold2.sif`.



## 7. Related Projects

* **[ColabFold-Apptainer-DRAC](https://github.com/DongdongHou006/colabfold-apptainer-DRAC)**: Our standard ColabFold (v1.5.5) deployment workflow for DRAC clusters. It features a two-step workflow to bypass public server quota limits and resolve the "no-internet-access" restriction on the compute node.


---
For internal use by DRAC users who need a reproducible AlphaFold2 Apptainer workflow.

