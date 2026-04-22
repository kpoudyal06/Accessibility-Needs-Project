library(shiny)
library(bslib)

# Increase max upload size to 30MB
options(shiny.maxRequestSize = 30 * 1024^2)

# 1. Environment Variable Retrieval ---------------------------------------
win_user     <- Sys.getenv("WIN_USER")
cluster_user <- Sys.getenv("CLUSTER_USER")
cluster_pwd  <- Sys.getenv("CLUSTER_PWD")

if (win_user == "" || cluster_user == "" || cluster_pwd == "") {
  stop("Missing environment variables. Check your .Renviron file!")
}

# 2. Path Definitions -----------------------------------------------------
winscp_exe        <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"
local_project_dir <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend", win_user)


# 3. Helper Function for Upload & Cleanup ---------------------------------
# This function will be called by server.R when a file is uploaded
sync_and_clean_pdf <- function(local_pdf_path, original_filename) {
  
  script_path_wsl <- "winscp_sync_generated.txt"
  script_path_win <- sprintf("%s\\winscp_sync_generated.txt", local_project_dir)
  log_path_win    <- sprintf("%s\\winscp_log.txt", local_project_dir)
  
  # Ensure the local path is formatted for Windows/WinSCP
  # We assume the file is temporarily saved in the websitePDFs folder
  local_file_win <- sprintf("%s\\websitePDFs\\%s", local_project_dir, original_filename)
  
  winscp_commands <- c(
    "option batch abort",
    "option confirm off",
    sprintf("open sftp://%s:%s@chip.rs.umbc.edu/ -hostkey=\"ssh-ed25519 255 KssMZdd+0v72I1Rd3H/zj161sMEr8mVON/Ylg27wHNk\"", 
            cluster_user, cluster_pwd),
    # The 'put -delete' command is the magic here: it uploads, then deletes the local file
    sprintf("put -delete \"%s\" /umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/fileUploadLocation/", 
            local_file_win),
    "exit"
  )
  
  writeLines(winscp_commands, con = script_path_wsl)
  
  if(file.exists(winscp_exe)) {
    cmd <- sprintf('"%s" /log="%s" /script="%s"', winscp_exe, log_path_win, script_path_win) 
    
    # wait = TRUE ensures Shiny doesn't proceed until the upload and deletion are completely finished
    system(cmd, wait = TRUE)
    message(sprintf("Successfully uploaded and cleaned up: %s", original_filename))
    
    # Clean up the generated WinSCP script file itself so it doesn't linger either
    if(file.exists(script_path_wsl)) file.remove(script_path_wsl)
    
  } else {
    message("Warning: WinSCP.com not found at ", winscp_exe)
  }
}

# 4. App Launch -----------------------------------------------------------
source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)