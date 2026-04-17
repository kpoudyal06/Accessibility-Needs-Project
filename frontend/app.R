library(shiny)
library(bslib)

# Increase max upload size to 30MB
options(shiny.maxRequestSize = 30 * 1024^2)

# 1. Environment Variable Retrieval ---------------------------------------
# Rename the .Renviron.example file to .Renviron, and update with your credentials. 
# The .Renviron file will NOT get pushed to Github, so you don't have to worry about accidentally pushing sensitive info
win_user     <- Sys.getenv("WIN_USER")
cluster_user <- Sys.getenv("CLUSTER_USER")
cluster_pwd  <- Sys.getenv("CLUSTER_PWD")

if (win_user == "" || cluster_user == "" || cluster_pwd == "") {
  stop("Missing environment variables. Check your .Renviron file!")
}

# 2. Path Definitions -----------------------------------------------------
# Note: WSL uses /mnt/c/... while WinSCP (Windows) needs C:\...
winscp_exe        <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"
local_project_dir <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend", win_user)
script_path_wsl   <- "winscp_sync_generated.txt" # Temporary file in app directory
log_path_win      <- sprintf("%s\\winscp_log.txt", local_project_dir)
script_path_win   <- sprintf("%s\\winscp_sync_generated.txt", local_project_dir)

# 3. Create Dynamic WinSCP Script -----------------------------------------
# This replaces your separate .txt file
winscp_commands <- c(
  "option batch abort",
  "option confirm off",
  sprintf("open sftp://%s:%s@chip.rs.umbc.edu/ -hostkey=\"ssh-ed25519 255 KssMZdd+0v72I1Rd3H/zj161sMEr8mVON/Ylg27wHNkMD5\"", 
          cluster_user, cluster_pwd),
  sprintf("keepuptodate \"%s\\websitePDFs\" /umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/fileUploadLocation", 
          local_project_dir),
  "exit"
)

writeLines(winscp_commands, con = script_path_wsl)

# 4. Launch WinSCP --------------------------------------------------------
if(file.exists(winscp_exe)) {
  # We pass the Windows-style path to the script to WinSCP
  cmd <- sprintf('"%s" /log="%s" /script="%s"', winscp_exe, log_path_win, script_path_win) 
  
  system(cmd, wait = FALSE)
  message("Background WinSCP sync initiated using dynamic script.")
} else {
  message("Warning: WinSCP.com not found at ", winscp_exe)
}

# 5. App Launch -----------------------------------------------------------
# Sourcing the UI and server code from the other files
source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)