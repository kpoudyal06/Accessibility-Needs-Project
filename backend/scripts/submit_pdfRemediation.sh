#!/bin/bash
#SBATCH --job-name=pdfRemediation
#SBATCH --output=logs/clean_%j.out
#SBATCH --error=logs/clean_%j.err
#SBATCH --cluster=chip-gpu
#SBATCH --account=cmsc447sp26
#SBATCH --partition=gpu     

# --- GPU CONFIGURATION ---
#SBATCH --gres=gpu:7
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=24:00:00

# Variables passed from Watcher
JOB_DIR=$1
SUB_ID=$2

# --- 1. ENVIRONMENT SETUP ---
echo "Job started on $(hostname) at $(date)"
echo "Processing Submission ID: $SUB_ID in $JOB_DIR"

echo "Loading modules..."
module purge
module load ollama/0.13.5

eval "$(conda shell.bash hook)"

echo "Activating Conda environment: marker_env"
conda activate /umbc/class/cmsc447sp26/common/conda/marker_env

# --- 2. STARTING OLLAMA SERVER ---
echo "Starting local Ollama server..."
export OLLAMA_MODELS=~/.ollama/models
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_MAX_QUEUE=16

ollama serve > logs/ollama_server_$SLURM_JOB_ID.log 2>&1 &
OLLAMA_PID=$!

sleep 30
echo "Ollama server active (PID: $OLLAMA_PID)"

# --- 3. RUN THE REMEDIATION ---
echo "Running Bulk Marker processing..."
# Using standard 'marker' for directories, and forcing JSON output format
# marker "$JOB_DIR" --output_dir "$JOB_DIR/marker_output" --output_format json --use_llm --llm_service marker.services.ollama.OllamaService --ollama_model llama3.1:70b --ollama_base_url http://localhost:11434 --paginate_output --force_ocr --redo_inline_math
marker "$JOB_DIR" --output_dir "$JOB_DIR/marker_output" --output_format json 

# --- 4. RUN CONVERSION SCRIPT ---
echo "Converting Marker JSON output to PDF and HTML..."
mkdir -p "$JOB_DIR/final_results"
python /umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/scripts/convertDoc.py --input "$JOB_DIR/marker_output" --output "$JOB_DIR/final_results"

# --- 5. CLEANUP ---
echo "Job finished at $(date). Stopping Ollama..."
kill $OLLAMA_PID