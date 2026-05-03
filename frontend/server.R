library(shiny)
library(bslib)

win_user     <- Sys.getenv("WIN_USER")
cluster_user <- Sys.getenv("CLUSTER_USER")
cluster_pwd  <- Sys.getenv("CLUSTER_PWD")
winscp_exe   <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"

# Remote paths
cluster_base_path <- "/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/fileUploadLocation"
cluster_db_scripts <- "/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/db_scripts"

# ============================================================================
# HELPER: Execute Remote Database Command via WinSCP
# ============================================================================
execute_remote_db_command <- function(script_name, args = c()) {
  wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", 
                                 "Accessibility-Needs-Project", "frontend")
  winscp_script_wsl <- tempfile(pattern = "db_cmd_", tmpdir = wsl_frontend_dir, 
                                 fileext = ".txt")
  script_filename <- basename(winscp_script_wsl)
  winscp_script_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", 
                               win_user, script_filename)
  
  # Build the call command with arguments
  remote_script <- file.path(cluster_db_scripts, script_name)
  call_cmd <- sprintf("call bash %s %s", remote_script, paste(args, collapse = " "))
  
  script_lines <- c(
    "option batch abort",
    "option confirm off",
    sprintf("open sftp://%s:%s@chip.rs.umbc.edu", cluster_user, cluster_pwd),
    call_cmd,
    "exit"
  )
  
  writeLines(script_lines, winscp_script_wsl)
  cmd <- sprintf('"%s" /script="%s"', winscp_exe, winscp_script_win)
  
  result <- tryCatch({
    raw_output <- system(cmd, intern = TRUE)
    
    # Clean output (remove WinSCP headers)
    session_start_idx <- grep("Session started\\.", raw_output)
    if (length(session_start_idx) > 0) {
      last_start <- tail(session_start_idx, 1)
      clean_output <- raw_output[(last_start + 1):length(raw_output)]
    } else {
      clean_output <- raw_output
    }
    
    # Remove empty lines and WinSCP messages
    clean_output <- clean_output[!grepl("^(winscp>|exit)", clean_output)]
    clean_output <- trimws(clean_output[nchar(trimws(clean_output)) > 0])
    
    clean_output
  }, error = function(e) {
    paste("ERROR:", e$message)
  }, finally = {
    if (file.exists(winscp_script_wsl)) unlink(winscp_script_wsl)
  })
  
  return(result)
}

# ============================================================================
# HELPER: Parse Database Command Output
# ============================================================================
parse_db_result <- function(output, key) {
  # Look for pattern like "USER_ID:123" or "JOB_STATUS:QUEUED"
  matches <- grep(paste0("^", key, ":"), output, value = TRUE)
  if (length(matches) > 0) {
    return(sub(paste0("^", key, ":"), "", matches[1]))
  }
  return(NULL)
}

# ============================================================================
# HELPER: Validate User Input for Email
# ============================================================================
is_valid_umbc_email <- function(email) {
  grepl("^[A-Za-z0-9._%+-]+@umbc\\.edu$", email)
}
# ============================================================================
# HELPER: Validate User Input for Student ID
# ============================================================================
is_valid_student_id <- function(id) {
  grepl("^[A-Za-z]{2}[0-9]{5}$", id)
}
# ============================================================================
# HELPER: Validate User Input for PDF File
# ============================================================================
is_valid_pdf <- function(file) {
  if (is.null(file)) return (FALSE)
  all(tolower(tools::file_ext(file$name)) == "pdf")
}


server <- function(input, output, session) {
  
  # Initialize database on cluster (run once at startup)
  execute_remote_db_command("db_init.sh")
  
  # Reactive values for upload tracking
  submitted <- reactiveVal(FALSE)
  pdf_uploaded <- reactiveVal(NULL)
  job_id_val <- reactiveVal("")
  
  # --- Set up folder for PDF previews ---
  www_dir <- file.path(tempdir(), "www")
  dir.create(www_dir, showWarnings = FALSE)
  addResourcePath("preview", www_dir)
  
  clear_preview <- function() {
    if(dir.exists(www_dir)) {
      files <- list.files(www_dir, full.names = TRUE)
      if(length(files) > 0) file.remove(files)
    }
  }
  
  # Render Dynamic UI for Upload Tab
  output$dynamic_upload_ui <- renderUI({
    if(!submitted()) {
      card(
        absolutePanel(
          top = 50, right = 15,
          img(src = "UMBC-primary-logo-RGB.png", width = "150px")
        ),
        div(
          class = "d-flex flex-column justify-content-center align-items-center h-100",
          style = "padding-top: 60px; padding-bottom: 60px;",
          titlePanel("File Upload"),
          p("Welcome to the PDF Remediation Tool!"),
          p("To get started, fill out your info and select a file to remediate."),
          br(),
          textInput("email", "UMBC Email"),
          textInput("student_id", "Student ID"),
          fileInput("file1", "Choose PDF", accept = ".pdf", multiple = TRUE),
          uiOutput("pdf_preview"),
          br(),
          actionButton("submit", "Upload File", class = "btn-dl-umbc")
        )
      )
    } else {
      card(
        absolutePanel(
          top = 50, right = 15,
          img(src = "UMBC-primary-logo-RGB.png", width = "150px")
        ),
        div(
          class = "d-flex flex-column justify-content-center align-items-center h-100",
          style = "gap: 20px; padding-top: 40px; padding-bottom: 40px;",
          h2("Upload Successful!", class = "title text-success"),
          p("Thank you for your submission."),
          div(
            class = "alert alert-info text-center w-50",
            h4("Your Job ID:"),
            h3(strong(job_id_val()))
          ),
          p("Next steps:"),
          tags$ul(
            tags$li("Check your email for a confirmation"),
            tags$li("Please wait up to 24 hours to receive confirmation of your returned documents.")
          ),
          actionButton("back", "Submit Another File", class = "btn-nav-umbc")
        )
      )
    }
  })
  
  # Track currently uploaded PDF for preview
  observeEvent(input$file1, {
    pdf_uploaded(input$file1[1, ])
  })
  
  # --- PDF Preview Rendering ---
  output$pdf_preview <- renderUI({
    pdf <- pdf_uploaded()
    
    if(submitted() || is.null(pdf) || nrow(pdf) == 0) {
      return(NULL)
    }
    
    dest_file <- file.path(www_dir, pdf$name)
    file.copy(pdf$datapath, dest_file, overwrite = TRUE)
    
    tags$iframe(
      src = paste0("preview/", pdf$name),
      type = "application/pdf",
      width = "80%",
      height = "600px",
      style = "border: 1px solid #ddd; border-radius: 8px; margin-top: 20px;"
    )
  })
  
  # ============================================================================
  # FILE UPLOAD, DATABASE INSERTION (REMOTE), & INITIAL EMAIL SENT
  # ============================================================================
  observeEvent(input$submit, {
    # Input Validation
    if (is.null(input$email) || input$email == "") {
      showNotification("Email is required", type = "error")
      return()
    }
    if (!is_valid_umbc_email(input$email)) {
      showNotification("Please enter a valid UMBC email (@umbc.edu)", type = "error")
      return()
    }
    if (is.null(input$student_id) || input$student_id == "") {
      showNotification("Student ID is required", type = "error")
      return()
    }
    if (!is_valid_student_id(input$student_id)) {
      showNotification("Please enter a valid UMBC Student ID", type = "error")
      return()
    }
    if (is.null(input$file1) || nrow(input$file1) == 0) {
      showNotification("Please upload a PDF file", type = "error")
      return()
    }
    if (!is_valid_pdf(input$file1)) {
      showNotification("Only PDF files may be uploaded", type = "error")
      return()
    }
    
    req(input$file1, input$email, input$student_id)
    
    # 1. Generate Unique Job ID
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    random_str <- paste0(sample(LETTERS, 4, replace = TRUE), collapse = "")
    new_job_id <- paste0("JOB_", timestamp, "_", random_str)
    
    # 2. Insert User into Remote Database
    user_output <- execute_remote_db_command("db_insert_user.sh", 
                                             c(input$student_id, input$email))
    user_id <- parse_db_result(user_output, "USER_ID")
    
    if (is.null(user_id)) {
      showNotification("Database Error: Could not insert user", type = "error")
      return()
    }
    
    # 3. Insert Submission into Remote Database
    submission_output <- execute_remote_db_command("db_insert_submission.sh", 
                                                   c(user_id, input$file1$name[1]))
    submission_id <- parse_db_result(submission_output, "SUBMISSION_ID")
    
    if (is.null(submission_id)) {
      showNotification("Database Error: Could not insert submission", type = "error")
      return()
    }
    
    
    # 5. Upload Files AND Send Email via Cluster
    wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", 
                                  "Accessibility-Needs-Project", "frontend")
    base_destination <- file.path(wsl_frontend_dir, "websitePDFs")    
    job_directory <- file.path(base_destination, new_job_id)
    win_job_directory <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\websitePDFs\\%s", 
                                 win_user, new_job_id)
    
    dir.create(job_directory, showWarnings = FALSE, recursive = TRUE)
   
     # --- ADD THIS LINE ---
    # Save the numeric ID to a text file so the Watcher can read it later
    writeLines(as.character(submission_id), file.path(job_directory, "submission_id.txt"))
    # ---------------------
    
    
    # Copy files to local job directory
    for (i in 1:nrow(input$file1)) {
      file_name <- paste0(input$student_id, "_", input$file1$name[i])
      file.copy(input$file1$datapath[i], file.path(job_directory, file_name))
    }
    
    # Generate WinSCP upload script
    winscp_script_wsl <- tempfile(pattern = "upload_clean_", 
                                  tmpdir = wsl_frontend_dir, fileext = ".txt")
    script_filename <- basename(winscp_script_wsl)
    winscp_script_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", 
                                 win_user, script_filename)
    
    remote_dest <- sprintf("%s/%s/", cluster_base_path, new_job_id)
    
    # --- PREPARE THE PYTHON EMAIL SCRIPT ---
    # We build the python string here in R
    email_body <- sprintf("Hello,\\n\\nYour file has been successfully uploaded for remediation.\\nYour Job ID is: %s\\n\\nPlease save this ID to check your job status on the PDF Remediation site.\\n\\nThank you,\\nUMBC PDF Remediator", new_job_id)
    email_subject <- sprintf("Upload Successful - Job %s", new_job_id)
    
    py_code <- sprintf(
      'import smtplib; from email.message import EmailMessage; msg = EmailMessage(); msg.set_content("%s"); msg["Subject"] = "%s"; msg["From"] = "pdf-remediator@umbc.edu"; msg["To"] = "%s"; s = smtplib.SMTP("smtp.umbc.edu"); s.send_message(msg); s.quit()',
      email_body, email_subject, input$email
    )
    # ---------------------------------------
    
    script_lines <- c(
      "option batch abort",
      "option confirm off",
      sprintf("open sftp://%s:%s@chip.rs.umbc.edu", cluster_user, cluster_pwd),
      sprintf("mkdir \"%s\"", remote_dest),
      sprintf("put -delete \"%s\\*\" \"%s\"", win_job_directory, remote_dest),
      # Tell WinSCP to execute the python script on the cluster!
      sprintf("call python3 -c '%s'", py_code), 
      "exit"
    )
    
    writeLines(script_lines, winscp_script_wsl)
    cmd <- sprintf('"%s" /script="%s"', winscp_exe, winscp_script_win)
    
    # Execute WinSCP
    system(cmd, wait = TRUE)
    
    if (file.exists(winscp_script_wsl)) unlink(winscp_script_wsl)
    unlink(job_directory, recursive = TRUE)
    
    # 6. Save Job ID and show success UI
    job_id_val(new_job_id)
    submitted(TRUE)
  })
  
  # ============================================================================
  # NAVIGATION BUTTONS
  # ============================================================================
  observeEvent(input$retr_btn, {
    nav_select("tabs", selected = "retr_tab")
  })
  
  observeEvent(input$prog_btn, {
    nav_select("tabs", selected = "track_tab")
  })
  
  observeEvent(input$back, {
    submitted(FALSE)
    pdf_uploaded(NULL)
    job_id_val("")
    clear_preview()
  })
  
  # ============================================================================
  # CHECK PROGRESS & PROGRESS BAR
  # ============================================================================
  observeEvent(input$check_progress_btn, {
    req(input$action_job_id)
    job_id <- input$action_job_id
    
    # 1. Setup the WinSCP paths
    wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", 
                                  "Accessibility-Needs-Project", "frontend")
    winscp_script_wsl <- tempfile(pattern = "check_prog_", 
                                  tmpdir = wsl_frontend_dir, fileext = ".txt")
    
    script_filename <- basename(winscp_script_wsl)
    winscp_script_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", 
                                 win_user, script_filename)
    
    remote_job_dir <- sprintf("%s/%s", cluster_base_path, job_id)
    
    # 2. Build the script
    script_lines <- c(
      "option batch abort",
      "option confirm off",
      sprintf("open sftp://%s:%s@chip.rs.umbc.edu", cluster_user, cluster_pwd),
      sprintf("call cat %s/*.err", remote_job_dir),
      "exit"
    )
    
    writeLines(script_lines, winscp_script_wsl)
    cmd <- sprintf('"%s" /script="%s"', winscp_exe, winscp_script_win)
    
    tryCatch({
      # 3. Execute system call
      raw_output <- suppressWarnings(system(cmd, intern = TRUE))
      
      # Check if we actually got content back from the cat command
      # If the directory doesn't exist, WinSCP usually returns an error message in the output
      if (any(grepl("No such file or directory", raw_output)) && !any(grepl("Processing PDFs", raw_output))) {
        stop("Job directory not found") 
      }
      
      # If we got this far, the ID is valid
      output$real_progress_output <- renderText({ "Job Found.\nProgress Status Below: " })
      
      # 4. Extract percentage
      session_start_idx <- grep("Session started\\.", raw_output)
      clean_output <- if (length(session_start_idx) > 0) {
        tail(raw_output, -(tail(session_start_idx, 1)))
      } else {
        raw_output 
      }
      
      progress_lines <- clean_output[grepl("Processing PDFs.*%", clean_output)]
      percent_num <- 0
      
      if (length(progress_lines) > 0) {
        latest_line <- tail(progress_lines, 1)
        reg_match <- regexpr("([0-9]{1,3})%", latest_line)
        if (reg_match != -1) {
          match_val <- regmatches(latest_line, reg_match)
          percent_num <- as.numeric(gsub("%", "", match_val))
        }
      }
      
      # 5. Render the Bar (since job was found)
      output$bespoke_progress_bar <- renderUI({
        bar_width <- if(!is.na(percent_num) && percent_num > 0) percent_num else 1
        HTML(sprintf('
          <div style="font-family: sans-serif; width: 100%%; padding: 10px; background: #f8f9fa; border-radius: 5px; border: 1px solid #ddd; margin-top: 10px;">
            <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
              <span style="font-weight: bold; color: #333;">Processing Status:</span>
              <span style="color: #007bff; font-weight: bold;">%d%%</span>
            </div>
            <div style="width: 100%%; background-color: #e9ecef; border-radius: 10px; height: 12px; overflow: hidden;">
              <div style="width: %d%%; background-color: #007bff; height: 100%%; transition: width 0.5s ease-in-out;"></div>
            </div>
          </div>
        ', percent_num, bar_width))
      })
      
    }, error = function(e) {
      # On Error: Set text to "Error" and HIDE the progress bar
      output$real_progress_output <- renderText({ "Error" })
      output$bespoke_progress_bar <- renderUI({ NULL }) 
      
    }, finally = {
      if (file.exists(winscp_script_wsl)) unlink(winscp_script_wsl)
    })
  })
  
  # ============================================================================
  # JOB STATUS For Retrieval
  # ============================================================================
  # 1. This block waits for the button click, then runs the database check
  observeEvent(input$check_status_btn, {
    req(input$retrieve_job_id)
    job_id <- input$retrieve_job_id
    
    # Show initial loading text
    output$job_status <- renderText({ "Fetching..." })
    
    wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", 
                                  "Accessibility-Needs-Project", "frontend")
    winscp_script_wsl <- tempfile(pattern = "check_prog_", 
                                  tmpdir = wsl_frontend_dir, fileext = ".txt")
    script_filename <- basename(winscp_script_wsl)
    winscp_script_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", 
                                 win_user, script_filename)
    
    remote_job_dir <- sprintf("%s/%s", cluster_base_path, job_id)
    
    script_lines <- c(
      "option batch abort",
      "option confirm off",
      sprintf("open sftp://%s:%s@chip.rs.umbc.edu", cluster_user, cluster_pwd),
      sprintf("call cat %s/*.err", remote_job_dir),
      "exit"
    )
    
    writeLines(script_lines, winscp_script_wsl)
    cmd <- sprintf('"%s" /script="%s"', winscp_exe, winscp_script_win)
    
    tryCatch({
      # Execute system call
      raw_output <- suppressWarnings(system(cmd, intern = TRUE))
      
      # 1. Validation Check: Does the folder/file even exist?
      if (any(grepl("No such file or directory", raw_output)) && !any(grepl("Processing PDFs", raw_output))) {
        stop("Job directory not found") 
      }
      
      # 2. Extract the percentage to check if it's done
      progress_lines <- raw_output[grepl("Processing PDFs.*%", raw_output)]
      percent_num <- 0
      
      if (length(progress_lines) > 0) {
        latest_line <- tail(progress_lines, 1)
        reg_match <- regexpr("([0-9]{1,3})%", latest_line)
        if (reg_match != -1) {
          match_val <- regmatches(latest_line, reg_match)
          percent_num <- as.numeric(gsub("%", "", match_val))
        }
      }
      
      # 3. Output the exact text based on the progress number
      if (!is.na(percent_num) && percent_num == 100) {
        output$job_status <- renderText({ "Complete Remediated File(s) Found.\nAccess the File(s) Below: " })
      } else {
        output$job_status <- renderText({ "Job Still in Progress.\nNo File(s) to Download at This Time." })
      }
      
    }, error = function(e) {
      # On Error: output exactly "Error"
      output$job_status <- renderText({ "Error" })
      
    }, finally = {
      if (file.exists(winscp_script_wsl)) unlink(winscp_script_wsl)
    })
  })
  
  # ============================================================================
  # RETRIEVE PROCESSED FILES
  # ============================================================================
  output$retrieve_files_btn <- downloadHandler(
    filename = function() {
      job_id <- input$action_job_id
      if(is.null(job_id) || job_id == "") job_id <- "UnknownJob"
      paste0(job_id, "_processed_files.zip")
    },
    content = function(file) {
      req(input$retrieve_job_id)
      job_id <- input$retrieve_job_id
      
      wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", 
                                    "Accessibility-Needs-Project", "frontend")
      wsl_dl_dir <- file.path(wsl_frontend_dir, "downloads", job_id)
      
      dir.create(wsl_dl_dir, recursive = TRUE, showWarnings = FALSE)
      do.call(file.remove, list(list.files(wsl_dl_dir, full.names = TRUE)))
      
      win_dl_dir <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\downloads\\%s\\", 
                           win_user, job_id)
      remote_out_dir <- sprintf("%s/%s/final_results", cluster_base_path, job_id)
      
      winscp_script_wsl <- tempfile(pattern = "get_files_", 
                                    tmpdir = wsl_frontend_dir, fileext = ".txt")
      script_filename <- basename(winscp_script_wsl)
      winscp_script_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", 
                                  win_user, script_filename)
      
      script_lines <- c(
        "option batch continue",
        "option confirm off",
        sprintf("open sftp://%s:%s@chip.rs.umbc.edu", cluster_user, cluster_pwd),
        sprintf("get %s/*.pdf \"%s\"", remote_out_dir, win_dl_dir),
        sprintf("get %s/*.html \"%s\"", remote_out_dir, win_dl_dir),
        "exit"
      )
      
      writeLines(script_lines, winscp_script_wsl)
      cmd <- sprintf('"%s" /script="%s"', winscp_exe, winscp_script_win)
      system(cmd, wait = TRUE)
      
      if (file.exists(winscp_script_wsl)) unlink(winscp_script_wsl)
      
      downloaded_files <- list.files(wsl_dl_dir, full.names = TRUE)
      
      if (length(downloaded_files) > 0) {
        zip(zipfile = file, files = downloaded_files, flags = "-j")
      } else {
        dummy_file <- file.path(wsl_dl_dir, "NO_FILES_FOUND.txt")
        writeLines("No .pdf or .html files were found in the output directory on the cluster.", 
                  dummy_file)
        zip(zipfile = file, files = dummy_file, flags = "-j")
      }
      
      unlink(wsl_dl_dir, recursive = TRUE)
    }
  )
}

