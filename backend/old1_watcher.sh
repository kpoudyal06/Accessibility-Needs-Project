#!/bin/bash

# --- VARIABLES TO FILL IN ---
WATCH_DIR="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/fileUploadLocation"
LOG_FILE="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/watcher.log"

echo "Starting watcher on $WATCH_DIR at $(date)" >> "$LOG_FILE"

while true; do
    # Look for any .pdf files in the directory
    for file in "$WATCH_DIR"/*.pdf; do
        # Check if the file actually exists (handles the case where no PDFs are found)
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            
            # 1. Print to the log file
            echo "$(date): Found new file - $filename" >> "$LOG_FILE"
            
            # 2. Rename the file so we don't process it again on the next loop
            mv "$file" "${file}.processed"
        fi
    done
    
    # Wait 5 seconds before checking again
    sleep 5
done
