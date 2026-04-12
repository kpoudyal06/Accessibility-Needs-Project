library(shiny)

# --- WINSCP AUTOMATION ---
# Call the Windows WinSCP executable from WSL using the script file
winscp_exe <- "C:\Program Files (x86)\WinSCP\winscp.com"
winscp_script <- "C:\Users\theya\downloads\winscp_sync.txt"

# Launch WinSCP in the background when the app starts
if(file.exists(winscp_exe)) {
  # wait = FALSE is critical here, otherwise Shiny will freeze waiting for WinSCP to finish
  system2(winscp_exe, args = c(paste0("/script=", winscp_script)), wait = FALSE)
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
    
    destination <- "C:\Users\theya\downloads\testPDFs"
    
    file.copy(input$file1$datapath, paste0(destination, input$file1$name))
    output$status <- renderText({ paste("Uploaded:", input$file1$name) })
  })
}

shinyApp(ui = ui, server = server)
