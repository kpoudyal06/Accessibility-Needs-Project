#!/bin/bash

# --- CONFIGURATION ---
# The directory where the website drops the "pdf_submission_id" folders
WATCH_DIR="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/fileUploadLocation"
LOG_FILE="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/watcher.log"
SBATCH_SCRIPT="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/scripts/process_job.slurm"

echo "Watcher started at $(date). Monitoring: $WATCH_DIR" >> "$LOG_FILE"

while true; do
    # Loop through every subdirectory in the upload location
    for folder in "$WATCH_DIR"/*/; do
        
        # Check if it's actually a directory (avoids issues if dir is empty)
        if [ -d "$folder" ]; then
            SUB_ID=$(basename "$folder")

            # FLAG CHECK: 
            # We check if 'job.submitted' exists. If it doesn't, this is a NEW job.
            if [ ! -f "$folder/job.submitted" ]; then
                
                echo "$(date): New submission detected: $SUB_ID" >> "$LOG_FILE"

                # 1. Submit the SLURM job
                # We pass the full folder path and the ID to the sbatch script
                # We capture the output to get the Slurm Job ID
                SUBMIT_OUT=$(sbatch "$SBATCH_SCRIPT" "$folder" "$SUB_ID")
                SLURM_ID=$(echo $SUBMIT_OUT | awk '{print $4}')

                # 2. Create the 'lock' file so we don't submit this again
                # We store the Slurm ID inside the flag file for easy reference
                echo "$SLURM_ID" > "$folder/job.submitted"

                # 3. Log it for your research tracking
                echo "$(date): $SUB_ID submitted to SLURM with ID: $SLURM_ID" >> "$LOG_FILE"
                
                # OPTIONAL: Here is where you'd run a quick SQL command to update 
                # the database status from 'Pending' to 'Running'
            fi
        fi
    done

    # Wait 30 seconds. In HPC, you don't want to hammer the file system every second.
    sleep 30
done
