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