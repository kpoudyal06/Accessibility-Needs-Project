#!/bin/bash
# Initialize database with schema

DB_PATH="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/accessibility.db"
SCHEMA_PATH="/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/createDB.sql"

# Enable foreign keys and execute schema
sqlite3 "$DB_PATH" <<EOF
PRAGMA foreign_keys = ON;
.read $SCHEMA_PATH
EOF

echo "DB_INIT_SUCCESS"