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
ui <- page_navbar(
  #Navigation Bar Details
  title = "File Remediation Tool",
  id = "tabs",
  navbar_options = navbar_options(
    position = "fixed-top",
    bg = "#306ed9",
    theme = "dark",       
    underline = TRUE,
    collapsible = TRUE,
  ),
  #Placeholder for Upload File Page
  nav_panel(title = "Upload File", 
            value = "upld_tab",
            page_fillable(
              card(
                
                #UMBC Logo
                absolutePanel(
                  top = 50, right = 15,
                  img(src = "UMBC-primary-logo-RGB.png", width = "150px")
                ),
                
                div(
                  class = "d-flex flex-column justify-content-center align-items-center h-100",
                  titlePanel("Cluster Test Upload"),
                  
                  #Description
                  p("Welcome to the PDF Remediation Tool!"),
                  p("To get started, select Browse to pick a file to remediate."),
                  br(),
                  fileInput("file1", "Choose PDF", accept = ".pdf"),
                  textOutput("status")
                  )
                )
            )
            ),
  #Tracking Page
  nav_panel(title = "Track Progress", 
            value = "track_tab",
            page_fluid(
               card(
                #UMBC Logo
                absolutePanel(
                  top = 50, right = 15,
                  img(src = "UMBC-primary-logo-RGB.png", width = "150px")
                ),
                
                div(
                  class = "d-flex flex-column justify-content-center align-items-center h-100",
                  style = "gap: 30px; padding-top: 60px; padding-bottom: 60px;",
                  titlePanel("Job Tracking"),
                  
                  #Description
                  p("Please enter Job Tracking ID below. It can be found in the email sent to confirm the file sucessfully uploaded and the remediation was in progress.", class = "text-center text-muted"),
                  numericInput("job", "Enter Valid Job ID", value = NA),
                  br(),
                  
                  textOutput("job_status"),
                  br(),
                  #uiOutput("cond_button"),
                  actionButton("retr_btn", "Go To Completed File", class = "btn-primary")
                
                  
                  ))
              )
            ),
  #Retrieval Page
  nav_panel(title = "Retrieve File", 
            value = "retr_tab",
            page_fluid(
              card(
                #UMBC Logo
                absolutePanel(
                  top = 50, right = 15,
                  img(src = "UMBC-primary-logo-RGB.png", width = "150px")
                ),
                
                div(
                  class = "d-flex flex-column justify-content-center align-items-center h-100",
                  style = "gap: 30px; padding-top: 60px; padding-bottom: 60px;",
                  titlePanel("File Remediation Complete"),
      
                  #Description
                  p("Below is a completed screen-readable version of your file."),
                  p("Access the file here:"),
                  
                  downloadButton("download_pdf", "Download as PDF file."),
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
)
  


server <- function(input, output, session) {
  observe({
    req(input$file1)
    
    destination <- "/mnt/c/Users/theya/Downloads/testPDFs/"
    
    file.copy(input$file1$datapath, paste0(destination, input$file1$name))
    output$status <- renderText({ paste("Uploaded:", input$file1$name) })

    #Validate Job ID (not working yet)
    output$job_status <- renderText({
      jobId <- input$job
      #check if input is empty
      if (is.na(jobId)){
        return("Please enter a valid Job ID.")
      }
      
      #convert input to string (for the sake of example)
      job_string <- as.character(jobId)
      if (job_string %in% names(status_database)){
        curr_stat <- status_database[[job_string]]
        return(paste("Job ", jobId, " found. Your file is: ", curr_stat))
      } else {
        return(paste("Error. Job ID does not exist in the system."))
      }
     
    })

    #I was testing out dynamic UI here, don't have to worry about this yet
    #output$cond_button <- renderUI({
   #   jobId <- input$job
      #check if input is empty
   #   if (is.na(jobId)){
    #    return(NULL)
     # }
      
      #convert input to string (for the sake of example)
      #job_string <- as.character(jobId)
      
      #if (job_string %in% names(status_database) && status_database[[job_string]] == "Complete"){
      #  actionButton("retr_pg_btn", "See My Completed File")
  #    } else {
  #      return(NULL)
   #   }
   # })
    
    #File Download Button
    output$download_pdf <-downloadHandler(
      filename = function(){
        "remediated_file.pdf"
      },
      content = function(file){
        final_file_path
      }      
    )   
  })

  #Button From tracking page to retrieval page
  observeEvent(input$retr_btn, {
    nav_select("tabs", selected = "retr_tab")
  })

  #Button From retrieval page to tracking page
  observeEvent(input$prog_btn, {
    nav_select("tabs", selected = "track_tab")
  })
}

shinyApp(ui = ui, server = server)
