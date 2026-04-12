library(shiny)

# --- WINSCP AUTOMATION ---
winscp_exe <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"

# The script path formatted as a Windows path, since WinSCP is a Windows program!
winscp_script_win <- "C:\\Users\\theya\\Downloads\\winscp_sync.txt"

# Launch WinSCP in the background when the app starts
if(file.exists(winscp_exe)) {
  # Build the exact command string with double quotes around the paths
  cmd <- sprintf('"%s" /log="C:\\Users\\theya\\Downloads\\winscp_log.txt" /script="%s"', winscp_exe, winscp_script_win) 
 
  # Run it! wait = FALSE keeps it in the background
  system(cmd, wait = FALSE)
  message("Background WinSCP sync initiated.")
} else {
  message("Warning: WinSCP.com not found at ", winscp_exe)
}

# --- SHINY APP --- TEAMMATES WORK HERE
ui <- fluidPage(
  titlePanel("Cluster Test Upload"),
  fileInput("file1", "Choose PDF", accept = ".pdf"),
  textOutput("status")
)

server <- function(input, output) {
  observe({
    req(input$file1)
    
    destination <- "/mnt/c/Users/theya/Downloads/testPDFs/"
    
    file.copy(input$file1$datapath, paste0(destination, input$file1$name))
    output$status <- renderText({ paste("Uploaded:", input$file1$name) })
  })
}

shinyApp(ui = ui, server = server)
