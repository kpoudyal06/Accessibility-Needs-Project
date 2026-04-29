#!/bin/bash
# Update job status
# Usage: ./db_update_job_status.sh <job_id> <status>

DB_PATH="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/accessibility.db"

JOB_ID="$1"
STATUS="$2"

sqlite3 "$DB_PATH" <<EOF
PRAGMA foreign_keys = ON;
UPDATE HPCJob SET Current_Status = '$STATUS' WHERE Cluster_Slurm_ID = '$JOB_ID';
EOF

echo "JOB_UPDATE_SUCCESS:$JOB_ID"