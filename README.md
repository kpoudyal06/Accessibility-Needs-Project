# Automated Web-to-Cluster File Pipeline (Backend Prototype)

This project uses a Shiny web app running in WSL to accept PDF uploads. Since our UMBC cluster is protected by DUO, we use WinSCP and the Global Protect VPN (connect to gpvpn.umbc.edu) running in the background to automatically bridge the gap and sync the files directly to the cluster without constant 2FA prompts.

WinSCP Download: https://winscp.net/eng/download.php
Global Protect VPN: https://umbc.atlassian.net/wiki/x/rEXVAQ
WSL Download: https://learn.microsoft.com/en-us/windows/wsl/install
R and Shiny: Use sudo commands (Use an LLM to help you out here, they are well known packages)

This guide will walk you through setting up the exact environment on your local Windows machine so you can test the backend and start building out the frontend UI.

---

## Prerequisites

Before you start, make sure you have the following installed on your machine:
1. **Windows Subsystem for Linux (WSL):** Specifically, Ubuntu. 
2. **R and the Shiny Package:** Installed *inside* your WSL environment.
Use these commands to install shiny and R
```
sudo apt install r-base-core
sudo apt update
sudo apt install libcurl4-openssl-dev libssl-dev libxml2-dev
sudo R -e "install.packages('shiny', repos='https://cran.rstudio.com/')"
```
4. **WinSCP:** You must install the Windows version of WinSCP.

---

## Step-by-Step Setup Guide

### Step 1: Set Up Your Local Directories
The pipeline needs a specific local folder to temporarily hold the PDFs before WinSCP sends them away to the cluster.
1. Open your Windows File Explorer.
2. Go to your `Downloads` folder.
3. Create a new folder inside it called exactly: `testPDFs`
4. Make note of your exact Windows username (you will need it in the next steps).

### Step 2: Configure the WinSCP Sync Script
In this repository, you will find a file named `winscp_sync.txt`. This is the script that tells WinSCP how to connect to the cluster.

1. Open `winscp_sync.txt`.
2. Find the line that starts with `open sftp://...`
3. **IMPORTANT:** You need to update the login credentials to use your HPC account so you can test the cluster connection. Replace the `open` line with your login info. 
   * *Format: `open sftp://YOURUMBCUSERNAME:YOURPASSWORD@chip.rs.umbc.edu/ -hostkey="..."`*
4. Find the line that starts with `keepuptodate`.
5. Change `theya` to **your actual Windows username**:
   `keepuptodate C:\Users\YOUR_WINDOWS_USERNAME\Downloads\testPDFs <REMOTE_CLUSTER_PATH>`
6. Save the file.

### Step 3: Configure the Shiny App (`app.R`)
Because R is running in WSL (Linux) but communicating with your Windows file system, the file paths in the script need to match your specific laptop.

1. Open `app.R` in your code editor.
2. Find the `# --- WINSCP AUTOMATION ---` section.
3. Update the `winscp_script_win` path to use **your Windows username**:
   ```R
   winscp_script_win <- "C:\\Users\\YOUR_WINDOWS_USERNAME\\Downloads\\winscp_sync.txt"
   ```
4. Find the `server` block near the bottom of the script.
5. Update the `destination` variable to use **your Windows username**:
   ```R
   destination <- "/mnt/c/Users/YOUR_WINDOWS_USERNAME/Downloads/testPDFs/"
   ```
6. Save the file.

---

## How to Run

1. Open your WSL (Ubuntu) terminal.
2. Navigate to the folder where you cloned this repository.
3. Launch the Shiny app by running:
   ```bash
   R -e "shiny::runApp('app.R', port=1234, host='0.0.0.0')"
   ```
4. You should see a message saying `Background WinSCP sync initiated` followed by `Listening on http://0.0.0.0:1234`.
5. Open your web browser (in Windows) and go to **http://localhost:1234**.
6. Run the watcher script at /umbc/class/cmsc447sp26/common, by running: ./watcher.sh
7. Open up another terminal connected to the cluster to run cat watcher.log to make sure that it recognizes the uploaded files
8. Upload a PDF using the browse button. If everything is set up correctly, the file will be saved to your local `testPDFs` folder, and WinSCP will instantly push it to the UMBC cluster!

*(Note: If the background WinSCP connection fails, it will generate a `winscp_log.txt` file in your Downloads folder. Check there for troubleshooting!)*

---

## For the Frontend
Your main workspace is the `ui` block inside `app.R`. 

Currently, it looks like this:
```R
ui <- fluidPage(
  titlePanel("Cluster Test Upload"),
  fileInput("file1", "Choose PDF", accept = ".pdf"),
  textOutput("status")
)
```

