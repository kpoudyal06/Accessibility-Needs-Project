# Accessibility Needs Project

This project uses a Shiny web app running in WSL to accept PDF uploads. Since our UMBC cluster is protected by DUO, we use WinSCP and the Global Protect VPN (connect to `gpvpn.umbc.edu`) running in the background to automatically bridge the gap and sync the files directly to the cluster without constant 2FA prompts.

**Important Links:**
* **WinSCP Download:** [https://winscp.net/eng/download.php](https://winscp.net/eng/download.php)
* **Global Protect VPN:** [https://umbc.atlassian.net/wiki/x/rEXVAQ](https://umbc.atlassian.net/wiki/x/rEXVAQ)
* **WSL Download:** [https://learn.microsoft.com/en-us/windows/wsl/install](https://learn.microsoft.com/en-us/windows/wsl/install)

This guide will walk you through setting up the environment on your local Windows machine so you can test the backend and interact with the UI.

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

### Clone the Repository
1. Open your WSL terminal and navigate to your Windows downloads folder: `cd /mnt/c/Users/YOUR_WINDOWS_USERNAME/Downloads/`
2. Clone the repository: `git clone git@github.com:kpoudyal06/Accessibility-Needs-Project.git` *(Note: You may need to set up an SSH key with GitHub to do this).*
3. **Cluster Note:** DO NOT run `git clone` directly on the UMBC cluster. We are working in a shared directory (`/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/`), so just run `git pull` if you need to update the cluster's version of the repo.

### Set Up Environment Variables (Update Your Credentials)
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
3. You should see a message saying `Background WinSCP sync initiated using dynamic script.` followed by `Listening on http://0.0.0.0:1234`.
4. Open your Windows web browser and navigate to **http://localhost:1234**.

### Testing the Pipeline

1. **Start the Watcher:** Open a separate terminal connected via SSH to the UMBC cluster. Navigate to `/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/` and run the watcher script: 
   ```bash
   ./watcher.sh
   ```
2. **Monitor the Logs:** Open another SSH terminal and run `tail -f watcher.log` to watch for incoming files in real-time.
3. **Upload a File:** Use the web app interface to enter a UMBC email, Student ID, and upload a PDF. 
   * *Note: The app is currently configured to accept files up to 30MB.*
4. If everything is set up correctly, the file will be saved to your local `websitePDFs` folder, WinSCP will instantly push it to the UMBC cluster, and your watcher script will detect it!

*(Troubleshooting: If the background WinSCP connection fails, it will generate a `winscp_log.txt` file in your frontend folder. Check there for connection errors.)*
