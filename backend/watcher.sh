import time
import slurm_api  # sacct, sbatch
import database   # SQL interactions
import mailer     # Google/SMTP email
import file_ops   # os.remove, shutil.rmtree

def watcher_loop():
    while True:
        # 1. SUBMISSION PHASE
        # Find 'Pending' jobs -> Run sbatch (which runs MarkerLLM + PDF/HTML scripts)
        for job in database.get_jobs_by_status("Pending"):
            slurm_id = slurm_api.submit_job(job.folder_path)
            database.update_status(job.id, "Running", slurm_id)
            # Send 'Job Received' Email
            mailer.send(job.email, f"Job {job.id} is now in the queue.")

        # 2. MONITORING PHASE
        # Find 'Running' jobs -> Check if SLURM says they are done
        for job in database.get_jobs_by_status("Running"):
            if slurm_api.is_finished(job.slurm_id):
                if file_ops.check_for_errors(job.folder_path):
                    database.update_status(job.id, "Error")
                    mailer.send(job.email, "Job failed. Check logs.")
                else:
                    database.update_status(job.id, "Ready_For_Download")
                    mailer.send(job.email, "Success! Your files are ready to download.")

        # 3. CLEANUP PHASE (The Space Saver)
        # Find 'Downloaded' jobs -> Wipe the directory to save HPC space
        for job in database.get_jobs_by_status("Downloaded"):
            # We keep the database record for your research! 
            # We only delete the heavy PDF/HTML files.
            file_ops.delete_directory(job.folder_path)
            database.update_status(job.id, "Archived")
            print(f"Space cleared for job {job.id}")

        time.sleep(30)
