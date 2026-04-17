win_user     <- Sys.getenv("WIN_USER")
cluster_user <- Sys.getenv("CLUSTER_USER")
cluster_pwd  <- Sys.getenv("CLUSTER_PWD")
winscp_exe   <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"

server <- function(input, output, session) {
  
  # Reactive values for upload tracking
  submitted <- reactiveVal(FALSE)
  pdf_uploaded <- reactiveVal(NULL)
  
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
          fileInput("file1", "Choose PDF", accept = ".pdf"),
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
          h2("Upload Successful!", class = "title"),
          p("Thank you for your submission."),
          p("Next steps:"),
          tags$ul(
            tags$li("Check your email for a confirmation"),
            tags$li("The email will include a Tracking ID and a link to track your documents."),
            tags$li("Please wait up to 24 hours to receive confirmation of your returned documents.")
          ),
          actionButton("back", "Return to Submission Page", class = "btn-secondary")
        )
      )
    }
  })
  
  # Track currently uploaded PDF for preview
  observeEvent(input$file1, {
    pdf_uploaded(input$file1)
  })
  
  # --- PDF Preview Rendering ---
  output$pdf_preview <- renderUI({
    pdf <- pdf_uploaded()
    
    if(submitted() || is.null(pdf)) {
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
    
    # Updated WSL destination path to use the variable
    destination <- file.path("/mnt/c", "Users", win_user, "Downloads", "Accessibility-Needs-Project", "frontend", "websitePDFs", "")    
    
    # Ensure directory exists
    dir.create(destination, showWarnings = FALSE, recursive = TRUE)
    
    # Apply naming convention from app.R
    file_name <- paste0(input$student_id, "_", input$file1$name)
    file.copy(input$file1$datapath, paste0(destination, file_name))
    
    # Switch UI to confirmation screen
    submitted(TRUE)
  })
  
  # Handle "Return to Submission" button
  observeEvent(input$back, {
    submitted(FALSE)
    clear_preview()
    pdf_uploaded(NULL)
  })
  
  # --- Job Validation ---
  output$job_status <- renderText({
    jobId <- input$job
    if (is.na(jobId)){
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
      # Note: 'final_file_path' needs to be defined based on the returned file
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
    
    # 3. Create the temporary file DIRECTLY in the Windows folder via WSL
    wsl_frontend_dir <- file.path("/mnt/c", "Users", win_user, "Downloads", "Accessibility-Needs-Project", "frontend")
    
    # tempfile() will now generate the file inside your project folder instead of /tmp
    winscp_script_path_wsl <- tempfile(pattern = "winscp_run_", tmpdir = wsl_frontend_dir, fileext = ".txt")
    
    # 4. Dynamically build the script lines
    script_lines <- c(
      "option batch abort",
      "option confirm off",
      sprintf("open sftp://%s:%s@chip.rs.umbc.edu", cluster_user, cluster_pwd),
      "call echo 'Successfully connected and ran dynamic script!'", 
      "exit"
    )
    
    # 5. Write the lines to the temporary file
    writeLines(script_lines, winscp_script_path_wsl)
    
    # 6. Extract just the filename to build a clean Windows path
    script_filename <- basename(winscp_script_path_wsl)
    winscp_script_path_win <- sprintf("C:\\Users\\%s\\Downloads\\Accessibility-Needs-Project\\frontend\\%s", win_user, script_filename)
    
    # 7. Build the execution command pointing to the clean Windows path
    cmd <- sprintf('"%s" /script="%s"', winscp_exe, winscp_script_path_win)
    
    # 8. Execute, capture output, and SECURELY CLEAN UP
    tryCatch({
      raw_output <- system(cmd, intern = TRUE)
      
      # Parse the output
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
      # 9. SECURITY: Always delete the script file after running using the WSL path.
      if (file.exists(winscp_script_path_wsl)) {
        unlink(winscp_script_path_wsl)
      }
    })
  })
}