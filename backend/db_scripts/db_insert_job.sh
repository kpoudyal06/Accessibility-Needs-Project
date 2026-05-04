#!/bin/bash
# Insert HPC job
# Usage: ./db_insert_job.sh <job_id> <submission_id>

DB_PATH="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/accessibility.db"

JOB_ID="$1"
SUBMISSION_ID="$2"

sqlite3 "$DB_PATH" <<EOF
PRAGMA foreign_keys = ON;
INSERT INTO HPCJob (Cluster_Slurm_ID, PDF_Submission_ID, Current_Status)
VALUES ('$JOB_ID', $SUBMISSION_ID, 'QUEUED');
EOF

echo "JOB_INSERT_SUCCESS:$JOB_ID"
