library(shiny)

# --- WINSCP AUTOMATION ---
winscp_exe <- "/mnt/c/Program Files (x86)/WinSCP/WinSCP.com"
winscp_script <- "/mnt/c/Users/theya/Downloads/winscp_sync.txt"

# Launch WinSCP in the background when the app starts
if(file.exists(winscp_exe)) {
  # Added shQuote() to handle the spaces in Windows file paths!
  system2(shQuote(winscp_exe), args = c(paste0("/script=", shQuote(winscp_script))), wait = FALSE)
  message("Background WinSCP sync initiated.")
} else {
  message("Warning: winscp.com not found at ", winscp_exe)
}

# --- SHINY APP ---
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
