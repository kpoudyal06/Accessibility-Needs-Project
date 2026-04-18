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
  nav_panel(title = "Job Actions", 
            value = "job_actions_tab",
            page_fluid(
              card(
                div(
                  class = "d-flex flex-column align-items-center",
                  style = "gap: 20px; padding-top: 40px; padding-bottom: 40px;",
                  h3("Manage Cluster Jobs"),
                  p("Check progress or download completed files for a specific Job ID.", class = "text-muted"),
                  
                  textInput("action_job_id", "Enter Job ID:", placeholder = "JOB_YYYYMMDD_HHMMSS_XXXX"),
                  
                  actionButton("check_progress_btn", "Check Progress", class = "btn-info w-25"),
                  verbatimTextOutput("real_progress_output"),
                  
                  downloadButton("retrieve_files_btn", "Download Output (.zip)", class = "btn-success w-25")
                )
              )
            )
  )
)
