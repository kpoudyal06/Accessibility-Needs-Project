#!/bin/bash
#SBATCH --job-name=MarkerRemediate
#SBATCH --output=%j.out
#SBATCH --error=%j.err
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1        # We need a GPU for MarkerLLM
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# --- 1. SETUP ENVIRONMENT ---
# Load your modules or conda environment
source activate marker_env

# Variables passed from the Watcher script
JOB_DIR=$1      # The directory containing the PDFs (e.g. /path/to/submission_id)
SUB_ID=$2       # The internal PDF submission ID for logging

DB_KEY=$SLURM_JOB_ID #6-7 Digit Number 

echo "Starting processing for Submission: $SUB_ID"
echo "Job started at: $(date)"
start_time=$(date +%s)

# --- 2. RUN MARKERLLM ---
# We run it on the folder. Marker outputs to a subfolder by default.
echo "Step 1: Running MarkerLLM..."
marker_single "$JOB_DIR" --output_dir "$JOB_DIR/marker_output" --batch_multiplier 2

# --- 3. RUN CONVERSION SCRIPT ---
# This runs your convertDoc.py to turn the Markdown into Final PDF/HTML
echo "Step 2: Converting output to PDF and HTML..."
python /umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/scripts/convertDoc.py --input "$JOB_DIR/marker_output" --output "$JOB_DIR/final_results"

# --- 4. CALCULATE RESEARCH METRICS ---
echo "Step 3: Gathering Research Data..."
end_time=$(date +%s)
runtime=$((end_time - start_time))

# Get GPU info from the actual node it ran on
gpu_type=$(nvidia-smi --query-gpu=name --format=csv,noheader)

# Export these to a small temp file that the Watcher can read and put into SQL
echo "runtime:$runtime" > "$JOB_DIR/metrics.stats"
echo "gpu:$gpu_type" >> "$JOB_DIR/metrics.stats"
echo "nodes:$SLURM_NNODES" >> "$JOB_DIR/metrics.stats"

echo "Job finished at: $(date)"

# --- 5. FINALIZE AND NOTIFY ---
# This calls the reference script you just showed me
/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/db_update_job_status.sh "$SLURM_JOB_ID" "Completed"

# This sends the email
python3 /umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/scripts/send_completion_email.py "$SLURM_JOB_ID" "$SUB_ID"
