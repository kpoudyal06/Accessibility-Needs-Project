library(shiny)

# --- WINSCP AUTOMATION ---
winscp_exe <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"

# The script path formatted as a Windows path, since WinSCP is a Windows program!
winscp_script_win <- "C:\\Users\\kylep\\Downloads\\winscp_sync.txt"

# Launch WinSCP in the background when the app starts
if(file.exists(winscp_exe)) {
  # Build the exact command string with double quotes around the paths
  cmd <- sprintf('"%s" /log="C:\\Users\\kylep\\Downloads\\winscp_log.txt" /script="%s"', winscp_exe, winscp_script_win) 
 
  # Run it! wait = FALSE keeps it in the background
  system(cmd, wait = FALSE)
  message("Background WinSCP sync initiated.")
} else {
  message("Warning: WinSCP.com not found at ", winscp_exe)
}

# --- SHINY APP --- TEAMMATES WORK HERE
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background-color: #f0f2f5;
        font-family: Arial, sans-serif;
      }
      .center-box {
        max-width: 900px;
        margin: 50px auto;
        padding: 50px;
        border: 1px solid #ccc;
        border-radius: 12px;
        box-shadow: 3px 3px 15px rgba(0,0,0,0.1);
        background-color: #ffffff;
      }
      .title {
        text-align: center;
        font-size: 28px;
        margin-bottom: 30px;
      }
      .shiny-input-container {
        margin-bottom: 25px;
      }
      .btn-primary {
        width: 100%;
        font-size: 20px;
        padding: 15px 0;
      }
      iframe {
        border: 1px solid #ddd;
        margin-bottom: 20px;
        width: 100%;
        height: 800px;
      }
    "))
  ),
  
  uiOutput("main_ui")
)

server <- function(input, output, session) {
  
  # Track submission
  submitted <- reactiveVal(FALSE)

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
  
  # Main UI vs Confirmation UI
  output$main_ui <- renderUI({
    if(!submitted()) {
      div(class = "center-box",
          h2("Cluster Test Upload", class = "title"),
          textInput("email", "UMBC Email"),
          textInput("student_id", "Student ID"),
          fileInput("file1", "Choose PDF", accept = ".pdf"),
          uiOutput("pdf_preview"),
          actionButton("submit", "Upload", class = "btn-primary")
      )
    } else {
      div(class = "center-box",
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
    }
  })
  
  # Track currently uploaded PDF
  pdf_uploaded <- reactiveVal(NULL)

  observeEvent(input$file1, {
    pdf_uploaded(input$file1)
  })

  # --- PDF preview ---
output$pdf_preview <- renderUI({
  pdf <- pdf_uploaded()
  
  # Only show preview if a PDF exists and we're on the submission page
  if(submitted() || is.null(pdf)) {
    return(NULL)
  }

  # Creates temp name for WSL to locate easily (for preview only)
  dest_file <- file.path(www_dir, pdf$name)
  file.copy(pdf$datapath, dest_file, overwrite = TRUE)
  
  tags$iframe(
    src = paste0("preview/", pdf$name),
    type = "application/pdf",
    width = "100%",
    height = "800px"
  )
})
  
  # Handle upload
  observeEvent(input$submit, {
    req(input$file1, input$email, input$student_id)
    
    destination <- "/mnt/c/Users/kylep/Downloads/testPDFs/"
    file_name <- paste0(input$student_id, "_", input$file1$name)
    file.copy(input$file1$datapath, paste0(destination, file_name))
    
    # Switch to confirmation screen
    submitted(TRUE)
  })

  observeEvent(input$back, {
    submitted(FALSE)
    clear_preview()
    pdf_uploaded(NULL)
  })
}

shinyApp(ui = ui, server = server)
