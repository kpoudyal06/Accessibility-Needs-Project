# Accessibility Needs Project

This project uses a Shiny web app running in WSL to accept PDF uploads. Since our UMBC cluster is protected by DUO, we use WinSCP and the Global Protect VPN (connect to `gpvpn.umbc.edu`) running in the background to automatically bridge the gap and sync the files directly to the cluster without constant 2FA prompts.

**Important Links:**

* **WinSCP Download:** [https://winscp.net/eng/download.php](https://winscp.net/eng/download.php)
* **Global Protect VPN:** [https://umbc.atlassian.net/wiki/x/rEXVAQ](https://umbc.atlassian.net/wiki/x/rEXVAQ)
* **WSL Download:** [https://learn.microsoft.com/en-us/windows/wsl/install](https://learn.microsoft.com/en-us/windows/wsl/install)

This guide will walk you through setting up the environment on your local Windows machine so you can test the backend and interact with the UI.

---

## Architecture Overview

The application uses a **backend database** architecture:
- **Frontend (WSL):** Shiny web app that handles user interface and file uploads
- **Backend (HPC Cluster):** SQLite database and shell scripts for database operations
- **Communication:** WinSCP `call` commands execute remote database scripts

---

## Prerequisites

Before you start, make sure you have the following installed on your machine:

1. **Windows Subsystem for Linux (WSL):** Specifically, Ubuntu. 
2. **WinSCP:** You must install the Windows version of WinSCP.
3. **R and the Shiny Package:** Installed *inside* your WSL environment. Run the following commands in your WSL terminal:

```bash
sudo apt install r-base-core
sudo apt update
sudo apt install -y libcurl4-openssl-dev libssl-dev libxml2-dev build-essential
sudo apt install -y r-cran-shiny r-cran-bslib r-cran-fs r-cran-sass
R -e "packageVersion('shiny')"
```


---

## Setup Guide

### 1. Clone the Repository

1. Open your WSL terminal and navigate to your Windows downloads folder: 
   ```bash
   cd /mnt/c/Users/YOUR_WINDOWS_USERNAME/Downloads/
   ```
2. Clone the repository: 
   ```bash
   git clone git@github.com:kpoudyal06/Accessibility-Needs-Project.git
   ```
   *(Note: You may need to set up an SSH key with GitHub to do this.)*

3. **Cluster Note:** DO NOT run `git clone` directly on the UMBC cluster. We are working in a shared directory (`/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/`), so just run `git pull` if you need to update the cluster's version of the repo.

### 2. Set Up Environment Variables (Update Your Credentials)

The app dynamically generates WinSCP scripts so you no longer need to hardcode passwords into text files. Instead, you need a local `.Renviron` file.

1. Navigate to the `frontend` folder inside the cloned repo.
2. Create a new file named exactly **`.Renviron`**.
3. Add the following lines, replacing the placeholder text with your actual information:

```text
WIN_USER="your_windows_username"
CLUSTER_USER="your_umbc_hpc_username"
CLUSTER_PWD="your_umbc_hpc_password"
```

4. Save the file. The `app.R` script will automatically pull these variables to set up your local paths and establish the cluster connection.

## How to Run

1. **Connect to the VPN:** Ensure you are connected to the UMBC Global Protect VPN (`gpvpn.umbc.edu`).

2. **Launch the App:** Open your WSL terminal, navigate to the `frontend` folder, and run:
   ```bash
   R -e "shiny::runApp('app.R', port=1234, host='0.0.0.0')"
   ```

3. You should see messages indicating the app is starting, followed by `Listening on http://0.0.0.0:1234`.

4. Open your Windows web browser and navigate to **http://localhost:1234**.

### Confirm Database Connection

The database now lives on the **HPC cluster**, not in your local frontend directory.

1. SSH into the cluster:
   ```bash
   ssh your_username@chip.rs.umbc.edu
   ```

2. Navigate to the backend directory:
   ```bash
   cd /umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend
   ```

3. Enter the database:
   ```bash
   sqlite3 accessibility.db
   ```

4. Ensure the tables have been created:
   ```sqlite
   .tables
   ```
   You should see `Users`, `Submissions`, and `HPCJob` listed.

5. Check that submission variables are being properly stored:
   ```sqlite
   SELECT * FROM Users;
   SELECT * FROM Submissions;
   SELECT * FROM HPCJob;
   ```

6. Exit sqlite:
   ```sqlite
   .quit
   ```

---

## Testing the Pipeline

1. **Start the Watcher:** Open a separate terminal connected via SSH to the UMBC cluster. Navigate to `/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/` and run the watcher script: 
   ```bash
   ./watcher.sh
   ```

2. **Monitor the Logs:** Open another SSH terminal and run:
   ```bash
   tail -f watcher.log
   ```
   This will show incoming files in real-time.

3. **Upload a File:** Use the web app interface to:
   - Enter a UMBC email
   - Enter a Student ID
   - Upload a PDF file
   
   *Note: The app is currently configured to accept files up to 30MB.*

4. **Verify the Flow:**
   - The file will be saved to your local `websitePDFs` folder
   - WinSCP will instantly push it to the UMBC cluster
   - Database records will be created on the cluster via remote commands
   - Your watcher script will detect the new file

---

## Troubleshooting

### Connection Issues
- If the background WinSCP connection fails, check for a `winscp_log.txt` file in your frontend folder for connection errors.
- Ensure you're connected to the UMBC VPN before running the app.

### Database Issues
- If you see "Database Error" messages in the app, SSH into the cluster and verify:
  - Database file exists: `/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/accessibility.db`
  - Scripts are executable: `ls -l /umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/db_scripts/`
  - Check script output manually: `bash /path/to/script.sh args`

### Script Permissions
- If you get "Permission denied" errors, ensure all `.sh` files have execute permissions:
  ```bash
  chmod +x /umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/db_scripts/*.sh
  ```

---

## Project Structure

```
Accessibility-Needs-Project
├── README.md                           # Full project overview and guide
├── backend                            
│   ├── clearBackend.sh                 # Just clears the .db and JOB_XYZ files in the backend
│   ├── createDB.sql                    # Creates the initial database
│   ├── db_scripts                      
│   │   ├── db_init.sh                  # Initializes database
│   │   ├── db_insert_job.sh            
│   │   ├── db_insert_submission.sh
│   │   ├── db_insert_user.sh
│   │   ├── db_query_job.sh
│   │   └── db_update_job_status.sh
│   ├── marker_env_backup.yml           # Lists all the dependencies of our conda environment, in case we need to remake it
│   ├── scripts
│   │   ├── convertDoc.py               # Converts MarkerLLM output to html/pdf
│   │   ├── process_job.slurm           
│   │   └── submit_pdfRemediation.sh    # Submits a directory to the cluster for remediation
│   ├── watcher.log                     # Log of watcher script
│   └── watcher.sh                      # Runs on a loop through the database, updating it. Runs the backend
└── frontend
    ├── README.md                       # README, information, and guide to the frontend
    ├── WebsitePDFs                     # Local pdf upload location
    ├── app.R                           
    ├── server.R                        # Manages database calls and upload/download mechanics
    ├── ui.R                            # Holds UI elements for the website
    ├── winscp_log.txt                  
    └── winscp_sync_generated.txt       
```
To run: 
```
tree -I 'conda|sampleOutputs|examplePDFs|downloads'
```

---

## Contributing

When contributing to this project:
1. Always work in a feature branch
2. Test locally before pushing to the cluster
3. Use `git pull` on the cluster (never `git clone`)
4. Never commit `.Renviron` or passwords to version control
