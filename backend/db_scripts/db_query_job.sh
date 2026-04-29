#!/bin/bash
# Query job status
# Usage: ./db_query_job.sh <job_id>

DB_PATH="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/accessibility.db"

JOB_ID="$1"

RESULT=$(sqlite3 "$DB_PATH" <<EOF
PRAGMA foreign_keys = ON;
SELECT Current_Status FROM HPCJob WHERE Cluster_Slurm_ID = '$JOB_ID';
EOF
)

if [ -z "$RESULT" ]; then
  echo "JOB_NOT_FOUND"
else
  echo "JOB_STATUS:$RESULT"
fi