win_user     <- Sys.getenv("WIN_USER")
cluster_user <- Sys.getenv("CLUSTER_USER")
cluster_pwd  <- Sys.getenv("CLUSTER_PWD")
winscp_exe   <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"

# The remote path where jobs are stored on the cluster
cluster_base_path <- "/umbc/class/cmsc447sp26/common/Accessibility-Needs-Project/backend/fileUploadLocation"

server <- function(input, output, session) {
  
  # Reactive values for upload tracking
  submitted <- reactiveVal(FALSE)
  pdf_uploaded <- reactiveVal(NULL)
  job_id_val <- reactiveVal("") # NEW: Store the generated Job ID
  
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
  
  # Render Dynamic UI for Upload Tab (Upload Form vs Success Screen)
  output$dynamic_upload_ui <- renderUI({
    if(!submitted()) {
      card(
        absolutePanel(
          top = 50, right = 15,
          img(src = "UMBC-primary-logo-RGB.png", width = "150px")
        ),
        div(
          class = "d-flex flex-column justify-content-center align-items-center h-100",
          titlePanel("File Upload"),
          p("Welcome to the PDF Remediation Tool!"),
          p("To get started, fill out your info and select a file to remediate."),
          br(),
          textInput("email", "UMBC Email"),
          textInput("student_id", "Student ID"),
          fileInput("file1", "Choose PDF", accept = ".pdf", multiple = TRUE), # Note: multiple=TRUE added for batches
          uiOutput("pdf_preview"),
          br(),
          actionButton("submit", "Upload File", class = "btn-primary w-25")
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
          style = "gap: 20px;",
          h2("Upload Successful!", class = "title text-success"),
          p("Thank you for your submission."),
          
          # NEW: Display the Job ID to the user in a prominent box
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
          actionButton("back", "Submit Another File", class = "btn-secondary")
        )
      )
    }
  })
  
  # Track currently uploaded PDF for preview
  observeEvent(input$file1, {
    # If multiple files are uploaded, preview only the first one
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
  
  observeEvent(input$submit, {
    req(input$file1, input$email, input$student_id)
    
    # 1. Generate a Unique Job ID (Format: JOB_YYYYMMDD_HHMMSS_RANDOM)
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    random_str <- paste0(sample(LETTERS, 4, replace = TRUE), collapse = "")
    new_job_id <- paste0("JOB_", timestamp, "_", random_str)
    
    # 2. Define path for the new JOB-SPECIFIC directory
    base_destination <- file.path("/mnt/c", "Users", win_user, "Downloads", "Accessibility-Needs-Project", "frontend", "websitePDFs")    
    job_directory <- file.path(base_destination, new_job_id)
    
    # Ensure directory exists
    dir.create(job_directory, showWarnings = FALSE, recursive = TRUE)
    
    # 3. Loop through and copy all uploaded files into the unique Job directory
    for (i in 1:nrow(input$file1)) {
      # Apply naming convention
      file_name <- paste0(input$student_id, "_", input$file1$name[i])
      file.copy(input$file1$datapath[i], file.path(job_directory, file_name))
    }
    
    # 4. Save the Job ID to reactiveVal and switch UI to confirmation screen
    job_id_val(new_job_id)
    submitted(TRUE)
  })
  
  # Handle "Return to Submission" button
  observeEvent(input$back, {
    submitted(FALSE)
    clear_preview()
    pdf_uploaded(NULL)
    job_id_val("")
  })
  
  # --- Job Validation ---
  output$job_status <- renderText({
    jobId <- input$job
    if (is.na(jobId) || jobId == ""){
      return("Please enter a valid Job ID.")
    }
    
    job_string <- as.character(jobId)
    # Note: 'status_database' needs to be defined somewhere in your actual app scope!
    if (exists("status_database") && job_string %in% names(status_database)){
      curr_stat <- status_database[[job_string]]
      return(paste("Job ", jobId, " found. Your file is: ", curr_stat))
    } else {
      return(paste("Error. Job ID does not exist in the system."))
    }
  })
  
  # --- File Download ---
  output$download_pdf <- downloadHandler(
    filename = function(){
      "remediated_file.pdf"
    },
    content = function(file){
      if(exists("final_file_path")) {
        file.copy(final_file_path, file)
      }
    }      
  )   
  
  # --- Cross-page Navigation Buttons ---
  observeEvent(input$retr_btn, {
    nav_select("tabs", selected = "retr_tab")
  })
  
  observeEvent(input$prog_btn, {
    nav_select("tabs", selected = "track_tab")
  })
  
  # Run Command Button
  observeEvent(input$run_cmd, {
    output$cmd_output <- renderText({ "Connecting to cluster and running command..." })
    
    wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", "Accessibility-Needs-Project", "frontend")
    winscp_script_path_wsl <- tempfile(pattern = "winscp_run_", tmpdir = wsl_frontend_dir, fileext = ".txt")
    
    script_lines <- c(
      "option batch abort",
      "option confirm off",
      sprintf("open sftp://%s:%s@chip.rs.umbc.edu", cluster_user, cluster_pwd),
      "call echo 'Successfully connected and ran dynamic script!'", 
      "exit"
    )
    
    writeLines(script_lines, winscp_script_path_wsl)
    
    script_filename <- basename(winscp_script_path_wsl)
    winscp_script_path_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", win_user, script_filename)
    
    cmd <- sprintf('"%s" /script="%s"', winscp_exe, winscp_script_path_win)
    
    tryCatch({
      raw_output <- system(cmd, intern = TRUE)
      session_start_idx <- grep("Session started\\.", raw_output)
      
      if (length(session_start_idx) > 0) {
        last_start <- tail(session_start_idx, 1)
        if (last_start < length(raw_output)) {
          clean_output <- raw_output[(last_start + 1):length(raw_output)]
        } else {
          clean_output <- "Command executed successfully, but returned no output."
        }
      } else {
        clean_output <- raw_output 
      }
      
      output$cmd_output <- renderText({ paste(clean_output, collapse = "\n") })
      
    }, error = function(e) {
      output$cmd_output <- renderText({ paste("Error executing command:", e$message) })
      
    }, finally = {
      if (file.exists(winscp_script_path_wsl)) {
        unlink(winscp_script_path_wsl)
      }
    })
  })
  
  # =========================================================================
  # LOGIC: CHECK PROGRESS (cat *.out)
  # =========================================================================
  observeEvent(input$check_progress_btn, {
    req(input$action_job_id)
    job_id <- input$action_job_id
    output$real_progress_output <- renderText({ "Fetching progress from cluster..." })
    
    wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", "Accessibility-Needs-Project", "frontend")
    winscp_script_wsl <- tempfile(pattern = "check_prog_", tmpdir = wsl_frontend_dir, fileext = ".txt")
    script_filename <- basename(winscp_script_wsl)
    winscp_script_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", win_user, script_filename)
    
    remote_job_dir <- sprintf("%s/%s", cluster_base_path, job_id)
    
    script_lines <- c(
      "option batch abort",
      "option confirm off",
      sprintf("open sftp://%s:%s@chip.rs.umbc.edu", cluster_user, cluster_pwd),
      sprintf("call cat %s/*.out", remote_job_dir),
      "exit"
    )
    
    writeLines(script_lines, winscp_script_wsl)
    cmd <- sprintf('"%s" /script="%s"', winscp_exe, winscp_script_win)
    
    tryCatch({
      raw_output <- system(cmd, intern = TRUE)
      session_start_idx <- grep("Session started\\.", raw_output)
      if (length(session_start_idx) > 0) {
        last_start <- tail(session_start_idx, 1)
        clean_output <- raw_output[(last_start + 1):length(raw_output)]
      } else {
        clean_output <- raw_output 
      }
      output$real_progress_output <- renderText({ paste(clean_output, collapse = "\n") })
    }, error = function(e) {
      output$real_progress_output <- renderText({ paste("Error fetching progress:", e$message) })
    }, finally = {
      if (file.exists(winscp_script_wsl)) unlink(winscp_script_wsl)
    })
  })
  
  # =========================================================================
  # LOGIC: RETRIEVE PROCESSED FILES (.html & .pdf)
  # =========================================================================
  output$retrieve_files_btn <- downloadHandler(
    filename = function() {
      job_id <- input$action_job_id
      if(is.null(job_id) || job_id == "") job_id <- "UnknownJob"
      paste0(job_id, "_processed_files.zip")
    },
    content = function(file) {
      req(input$action_job_id)
      job_id <- input$action_job_id
      
      wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", "Accessibility-Needs-Project", "frontend")
      wsl_dl_dir <- file.path(wsl_frontend_dir, "downloads", job_id)
      
      dir.create(wsl_dl_dir, recursive = TRUE, showWarnings = FALSE)
      do.call(file.remove, list(list.files(wsl_dl_dir, full.names = TRUE))) 
      
      win_dl_dir <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\downloads\\%s\\", win_user, job_id)
      remote_out_dir <- sprintf("%s/%s/output", cluster_base_path, job_id)
      
      winscp_script_wsl <- tempfile(pattern = "get_files_", tmpdir = wsl_frontend_dir, fileext = ".txt")
      script_filename <- basename(winscp_script_wsl)
      winscp_script_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", win_user, script_filename)
      
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
        writeLines("No .pdf or .html files were found in the output directory on the cluster.", dummy_file)
        zip(zipfile = file, files = dummy_file, flags = "-j")
      }
      
      unlink(wsl_dl_dir, recursive = TRUE)
    }
  )
}