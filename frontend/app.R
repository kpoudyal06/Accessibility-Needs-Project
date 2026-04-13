library(shiny)
library(bslib)

# --- WINSCP AUTOMATION (From app(1).R) ---
winscp_exe <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"

# The script path formatted as a Windows path
winscp_script_win <- "C:\\Users\\theya\\Downloads\\Accessibility-Needs-Project\\frontend\\winscp_sync.txt"

# Launch WinSCP in the background when the app starts
if(file.exists(winscp_exe)) {
  # Build the exact command string with double quotes around the paths
  cmd <- sprintf('"%s" /log="C:\\Users\\theya\\Downloads\\Accessibility-Needs-Project\\frontend\\winscp_log.txt" /script="%s"', winscp_exe, winscp_script_win) 
  
  # Run it! wait = FALSE keeps it in the background
  system(cmd, wait = FALSE)
  message("Background WinSCP sync initiated.")
} else {
  message("Warning: WinSCP.com not found at ", winscp_exe)
}

# --- SHINY APP UI ---
ui <- page_navbar(
  title = "File Remediation Tool",
  id = "tabs",
  navbar_options = navbar_options(
    position = "fixed-top",
    bg = "#306ed9",
    theme = "dark",       
    underline = TRUE,
    collapsible = TRUE
  ),
  
  # 1. Upload File Page (Dynamic UI & PDF preview)
  nav_panel(title = "Upload File", 
            value = "upld_tab",
            page_fillable(
              uiOutput("dynamic_upload_ui")
            )
  ),
  
  # 2. Tracking Page
  nav_panel(title = "Track Progress", 
            value = "track_tab",
            page_fluid(
              card(
                absolutePanel(
                  top = 50, right = 15,
                  img(src = "UMBC-primary-logo-RGB.png", width = "150px")
                ),
                div(
                  class = "d-flex flex-column justify-content-center align-items-center h-100",
                  style = "gap: 30px; padding-top: 60px; padding-bottom: 60px;",
                  titlePanel("Job Tracking"),
                  
                  p("Please enter Job Tracking ID below. It can be found in the email sent to confirm the file successfully uploaded and the remediation was in progress.", class = "text-center text-muted"),
                  numericInput("job", "Enter Valid Job ID", value = NA),
                  br(),
                  
                  textOutput("job_status"),
                  br(),
                  actionButton("retr_btn", "Go To Completed File", class = "btn-primary")
                )
              )
            )
  ),
  
  # 3. Retrieval Page
  nav_panel(title = "Retrieve File", 
            value = "retr_tab",
            page_fluid(
              card(
                absolutePanel(
                  top = 50, right = 15,
                  img(src = "UMBC-primary-logo-RGB.png", width = "150px")
                ),
                div(
                  class = "d-flex flex-column justify-content-center align-items-center h-100",
                  style = "gap: 30px; padding-top: 60px; padding-bottom: 60px;",
                  titlePanel("File Remediation Complete"),
                  
                  p("Below is a completed screen-readable version of your file."),
                  p("Access the file here:"),
                  
                  downloadButton("download_pdf", "Download as PDF file.", class = "btn-success"),
                  br(),
                  p("Please tell us about your experience! "),
                  tags$a(
                    "Feedback Form",
                    href = "",
                    target = "_blank",
                    class = "btn btn-primary"
                  ),
                  p("Check on the progress of your other files: "),
                  actionButton("prog_btn", "Go To Progress Tracking", class = "btn-primary")
                )
              )
            )
  ),
  
  # 4. Cluster Command Page (Merged from app(1).R)
  nav_panel(title = "Cluster Command", 
            value = "cmd_tab",
            page_fluid(
              card(
                div(
                  class = "d-flex flex-column align-items-center",
                  style = "gap: 20px; padding-top: 40px; padding-bottom: 40px;",
                  h3("Cluster Command Execution"),
                  p("Administrative tools for cluster testing and synchronization.", class = "text-muted"),
                  actionButton("run_cmd", "Run Remote 'ls' Command", class = "btn-warning w-25"),
                  verbatimTextOutput("cmd_output") # Displays the terminal output
                )
              )
            )
  )
)

# --- SHINY APP SERVER ---
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
  
  # Handle File Submit (Merged Path from app(1).R)
  observeEvent(input$submit, {
    req(input$file1, input$email, input$student_id)
    
    # Updated destination from app(1).R
    destination <- "/mnt/c/Users/theya/Downloads/Accessibility-Needs-Project/frontend/websitePDFs/"
    
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
  
  # --- Handle Remote Command Execution (From app(1).R) ---
  observeEvent(input$run_cmd, {
    # Path to your NEW command script
    cmd_script_win <- "C:\\Users\\theya\\Downloads\\Accessibility-Needs-Project\\frontend\\winscp_runcmd.txt"
    
    # Show a loading message while it connects
    output$cmd_output <- renderText({ "Connecting to cluster and running command..." })
    
    # Build the command. We don't use wait=FALSE here because we NEED to wait for the output.
    cmd <- sprintf('"%s" /script="%s"', winscp_exe, cmd_script_win)
    
    # Run WinSCP and capture the standard output (intern = TRUE does this!)
    tryCatch({
      raw_output <- system(cmd, intern = TRUE)
      
      # Find the line numbers where "Session started." appears
      session_start_idx <- grep("Session started\\.", raw_output)
      
      if (length(session_start_idx) > 0) {
        # Get the very last time it appears (from the 'call' command's sub-session)
        last_start <- tail(session_start_idx, 1)
        
        # Check if there is actually output after the session started
        if (last_start < length(raw_output)) {
          clean_output <- raw_output[(last_start + 1):length(raw_output)]
        } else {
          clean_output <- "Command executed successfully, but returned no output."
        }
      } else {
        # Fallback just in case WinSCP changes its output format
        clean_output <- raw_output 
      }
      
      # Display the cleaned output
      output$cmd_output <- renderText({ paste(clean_output, collapse = "\n") })
      
    }, error = function(e) {
      output$cmd_output <- renderText({ paste("Error executing command:", e$message) })
    })
  })
}

shinyApp(ui = ui, server = server)