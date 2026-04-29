#!/bin/bash

# --- CONFIGURATION ---
WATCH_DIR="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/fileUploadLocation"
LOG_FILE="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/watcher.log"
SBATCH_SCRIPT="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/scripts/submit_pdfRemediation.sh"
DB_INSERT_SCRIPT="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/db_scripts/db_insert_job.sh"

# Prevents the script from crashing/looping if the directory is empty
shopt -s nullglob

echo "Watcher started at $(date). Monitoring: $WATCH_DIR" >> "$LOG_FILE"

while true; do
    # Iterate only through actual directories
    for folder in "$WATCH_DIR"/*/; do
        
        # Define SUB_ID by getting the folder name (removes the trailing slash)
        SUB_ID=$(basename "$folder")

        if [ ! -f "$folder/job.submitted" ]; then
                
                echo "$(date): New submission detected: $SUB_ID" >> "$LOG_FILE"

                # 1. Submit the SLURM job
                # Ensure variables are quoted to handle weird folder names
                SUBMIT_OUT=$(sbatch --output="${folder}slurm_%j.out" --error="${folder}slurm_%j.err" "$SBATCH_SCRIPT" "$folder" "$SUB_ID")
                
                # Extract Slurm ID (assumes format: "Submitted batch job 12345")
                SLURM_ID=$(echo "$SUBMIT_OUT" | awk '{print $4}')

                if [ -n "$SLURM_ID" ]; then
                    # 2. Create the 'lock' file
                    echo "$SLURM_ID" > "$folder/job.submitted"
                    echo "$(date): $SUB_ID submitted to SLURM with ID: $SLURM_ID" >> "$LOG_FILE"
                    
                    # 3. Insert into DB (Now SUB_ID is actually defined)
                    if [ -f "$DB_INSERT_SCRIPT" ]; then
                        bash "$DB_INSERT_SCRIPT" "$SLURM_ID" "$SUB_ID" >> "$LOG_FILE"
                        echo "$(date): Database successfully updated for $SUB_ID" >> "$LOG_FILE"
                    else
                        echo "$(date): ERROR - Database script missing" >> "$LOG_FILE"
                    fi
                else
                    echo "$(date): ERROR - Failed to get Slurm ID for $SUB_ID" >> "$LOG_FILE"
                fi
        fi
    done

    sleep 30
done
