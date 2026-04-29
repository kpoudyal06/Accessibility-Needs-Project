#!/bin/bash
# Insert user and return User_ID
# Usage: ./db_insert_user.sh <student_id> <email>

DB_PATH="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/accessibility.db"

STUDENT_ID="$1"
EMAIL="$2"

# Sanitize inputs (basic - enhance as needed)
STUDENT_ID="${STUDENT_ID//\'/''}"
EMAIL="${EMAIL//\'/''}"

USER_ID=$(sqlite3 "$DB_PATH" <<EOF
PRAGMA foreign_keys = ON;
INSERT INTO Users (Student_ID, Email) VALUES ('$STUDENT_ID', '$EMAIL');
SELECT last_insert_rowid();
EOF
)

echo "USER_ID:$USER_ID"