#!/bin/bash
#SBATCH --job-name=pdfRemediation
#SBATCH --output=logs/clean_%j.out
#SBATCH --error=logs/clean_%j.err
#SBATCH --cluster=chip-gpu
#SBATCH --account=cmsc447sp26
#SBATCH --partition=gpu     # Standard GPU partition

# --- GPU CONFIGURATION ---
#SBATCH --gres=gpu:7
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=24:00:00

# --- 1. ENVIRONMENT SETUP ---
echo "Job started on $(hostname) at $(date)"

echo "Loading modules..."
module purge
module load ollama/0.13.5

eval "$(conda shell.bash hook)"

# Activate your specific environment
echo "Activating Conda environment: marker_env"
conda activate /umbc/class/cmsc447sp26/common/conda/marker_env

# --- 2. STARTING OLLAMA SERVER ---
echo "Starting local Ollama server..."
export OLLAMA_MODELS=~/.ollama/models

export OLLAMA_NUM_PARALLEL=4
export OLLAMA_MAX_QUEUE=16

# Starts the server in the background
ollama serve > logs/ollama_server_$SLURM_JOB_ID.log 2>&1 &
OLLAMA_PID=$!

# Give it time to initialize
sleep 30
echo "Ollama server active (PID: $OLLAMA_PID)"

# --- 3. RUN THE REMEDIATION ---
marker_single /umbc/class/cmsc447sp26/common/pdfRemediationPipeline/testPDFs/calc_questions.pdf --output_dir ./output
#marker_single /umbc/class/cmsc447sp26/common/pdfRemediationPipeline/testPDFs/calc_questions.pdf --output_dir ./output --use_llm --llm_service marker.services.ollama.OllamaService --ollama_model llama3.1:70b --ollama_base_url http://localhost:11434 --paginate_output --force_ocr --redo_inline_math

# --- 4. CLEANUP ---
echo "Job finished at $(date). Stopping Ollama..."
kill $OLLAMA_PID
