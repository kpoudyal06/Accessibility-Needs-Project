library(shiny)

# Locating the Winscp file
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

# Frontend
ui <- fluidPage(
  titlePanel("Cluster Test Upload & Command"),
  
  # Upload section
  fileInput("file1", "Choose PDF", accept = ".pdf"),
  textOutput("status"),
  
  hr(), # Horizontal line for visual separation
  
  # Command Execution section
  h3("Cluster Command Execution"),
  actionButton("run_cmd", "Run Remote 'ls' Command"),
  verbatimTextOutput("cmd_output") # Displays the terminal output
)

server <- function(input, output) {
  
  # Handle File Uploads
  observe({
    req(input$file1)
    destination <- "/mnt/c/Users/theya/Downloads/Accessibility-Needs-Project/frontend/websitePDFs/"
    file.copy(input$file1$datapath, paste0(destination, input$file1$name))
    output$status <- renderText({ paste("Uploaded:", input$file1$name) })
  })
  
  # Handle Remote Command Execution
  observeEvent(input$run_cmd, {
    # Path to your NEW command script
    cmd_script_win <- "C:\\Users\\theya\\Downloads\\Accessibility-Needs-Project\\frontend\\winscp_runcmd.txt"
    
    # Show a loading message while it connects
    output$cmd_output <- renderText({ "Connecting to cluster and running command..." })
    
    # Build the command. We don't use wait=FALSE here because we NEED to wait for the output.
    cmd <- sprintf('"%s" /script="%s"', winscp_exe, cmd_script_win)
    
    # Run WinSCP and capture the standard output (intern = TRUE does this!)
    # Note: Running this will temporarily freeze the Shiny app for a second while it connects
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
