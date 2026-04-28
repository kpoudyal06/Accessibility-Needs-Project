import time
import slurm_api  # Hypothetical module to interact with sbatch/sacct
import database   # Hypothetical module to query your SQL db
import mailer     # Hypothetical module to send emails

def main_loop():
    # Run forever, but sleep at the end of each cycle so we don't fry the server
    while True:
        
        # ---------------------------------------------------------
        # PHASE 1: Handle NEW Submissions (Pending -> Running)
        # ---------------------------------------------------------
        pending_jobs = database.get_jobs_by_status("Pending")
        
        for job in pending_jobs:
            submission_id = job.pdf_submission_id
            directory_path = f"/shared/submissions/{submission_id}/"
            
            # Submit the sbatch script for this directory
            slurm_job_id = slurm_api.submit_job(directory_path)
            
            if slurm_job_id:
                # Update DB immediately so we don't submit it twice
                database.update_job(
                    submission_id=submission_id, 
                    new_status="Running", 
                    cluster_slurm_id=slurm_job_id
                )

        # ---------------------------------------------------------
        # PHASE 2 & 3: Check RUNNING Jobs (Running -> Finished/Error)
        # ---------------------------------------------------------
        running_jobs = database.get_jobs_by_status("Running")
        
        for job in running_jobs:
            slurm_id = job.cluster_slurm_id
            submission_id = job.pdf_submission_id
            directory_path = f"/shared/submissions/{submission_id}/"
            
            # Check SLURM for the status of this specific job
            slurm_status = slurm_api.check_status(slurm_id) 
            
            if slurm_status == "COMPLETED" or slurm_status == "FAILED":
                
                # Check the .err file to confirm actual success/failure
                error_file_path = f"{directory_path}/job.err"
                if has_critical_errors(error_file_path):
                    final_status = "Error"
                else:
                    final_status = "Success"
                
                # Extract research metrics (hardware, runtime, etc.)
                metrics = extract_research_data(directory_path, slurm_id)
                
                # Save everything to the database
                database.log_research_metrics(submission_id, metrics)
                database.update_job(submission_id, new_status=final_status)
                
                # Send the notification email
                user_email = job.email
                mailer.send_notification(user_email, submission_id, final_status)

        # ---------------------------------------------------------
        # SLEEP: Give the server a break before checking again
        # ---------------------------------------------------------
        time.sleep(30) # Wait 30 seconds before looping again
