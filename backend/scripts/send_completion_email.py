import sqlite3
import smtplib
import sys
from email.message import EmailMessage

# 1. Get Job ID from the command line
slurm_id = sys.argv[1]
job_id = sys.argv[2]
db_path = "/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/accessibility.db"

# 2. Connect to DB and get the email
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Join HPCJob, Submissions, and Users to find the email for this specific job
query = """
    SELECT Users.Email, HPCJob.Email_Sent 
    FROM HPCJob
    JOIN Submissions ON HPCJob.PDF_Submission_ID = Submissions.PDF_Submission_ID
    JOIN Users ON Submissions.User_ID = Users.User_ID
    WHERE HPCJob.Cluster_Slurm_ID = ?
"""
cursor.execute(query, (slurm_id,))
result = cursor.fetchone()

if result:
    user_email = result[0]
    email_sent = result[1]
    
    # 3. Prevent Spam
    if email_sent == 0:
        # Send the email
        msg = EmailMessage()
        msg.set_content(f"Hello,\n\nYour PDF file for Job {job_id} has been successfully remediated. Please go to the PDF Remediation Site to download.\n\nThank you,\nUMBC PDF Remediator")
        msg["Subject"] = f"Job Complete - {job_id}"
        msg["From"] = "pdf-remediator@umbc.edu"
        msg["To"] = user_email
        
        s = smtplib.SMTP("smtp.umbc.edu")
        s.send_message(msg)
        s.quit()
        
        # 4. Update the DB so it never sends again
        cursor.execute("UPDATE HPCJob SET Email_Sent = 1 WHERE Cluster_Slurm_ID = ?", (slurm_id,))
        conn.commit()
        print(f"EMAIL_SUCCESS: Sent to {user_email}")
    else:
        print("EMAIL_SKIPPED: Already sent for this job.")

else:
    print(f"EMAIL_FAILED: Could not find User/Email for Slurm ID {slurm_id} in the database.")

conn.close()
