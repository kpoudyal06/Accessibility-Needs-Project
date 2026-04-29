#!/bin/bash
# Insert submission and return Submission_ID
# Usage: ./db_insert_submission.sh <user_id> <file_name>

DB_PATH="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/accessibility.db"

USER_ID="$1"
FILE_NAME="$2"

FILE_NAME="${FILE_NAME//\'/''}"

SUBMISSION_ID=$(sqlite3 "$DB_PATH" <<EOF
PRAGMA foreign_keys = ON;
INSERT INTO Submissions (User_ID, Upload_Timestamp, File_Name) 
VALUES ($USER_ID, datetime('now'), '$FILE_NAME');
SELECT last_insert_rowid();
EOF
)

echo "SUBMISSION_ID:$SUBMISSION_ID"