#!/bin/bash

# --- CONFIGURATION ---
# The directory where the website drops the "pdf_submission_id" folders
WATCH_DIR="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/fileUploadLocation"
LOG_FILE="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/watcher.log"
SBATCH_SCRIPT="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/scripts/submit_pdfRemediation.sh"
DB_INSERT_SCRIPT="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/db_scripts/db_insert_job.sh"

echo "Watcher started at $(date). Monitoring: $WATCH_DIR" >> "$LOG_FILE"

while true; do
    for folder in "$WATCH_DIR"/*/; do
        if [ ! -f "$folder/job.submitted" ]; then
                
                echo "$(date): New submission detected: $SUB_ID" >> "$LOG_FILE"

                # 1. Submit the SLURM job
                # UPDATED: We override the output and error paths so they drop directly into the job's folder
                SUBMIT_OUT=$(sbatch --output="${folder}slurm_%j.out" --error="${folder}slurm_%j.err" "$SBATCH_SCRIPT" "$folder" "$SUB_ID")
                
                SLURM_ID=$(echo $SUBMIT_OUT | awk '{print $4}')

                # 2. Create the 'lock' file so we don't submit this again
                echo "$SLURM_ID" > "$folder/job.submitted"

                # 3. Log it for your research tracking
                echo "$(date): $SUB_ID submitted to SLURM with ID: $SLURM_ID" >> "$LOG_FILE"
                
                # 4. Insert the job into the database
                if [ -f "$DB_INSERT_SCRIPT" ]; then
                    bash "$DB_INSERT_SCRIPT" "$SLURM_ID" "$SUB_ID" >> "$LOG_FILE"
                    echo "$(date): Database successfully updated for Submission $SUB_ID (Slurm ID: $SLURM_ID)" >> "$LOG_FILE"
                else
                    echo "$(date): ERROR - Database insert script not found at $DB_INSERT_SCRIPT" >> "$LOG_FILE"
                fi
            fi
    done

    sleep 30
done