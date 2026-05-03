ui <- page_navbar(
  title = "File Remediation Tool",
  id = "tabs",
  navbar_options = navbar_options(
    position = "fixed-top",
    bg = "#fdb515",
    theme = "dark",       
    underline = TRUE,
    collapsible = TRUE
  ),
  header = tags$head(
    tags$style(HTML("
    /* The main button style */
    .btn-nav-umbc {
      background-color: transparent; 
      color: #000000; 
      border: 2px solid transparent; /* Invisible border keeps size consistent */
      font-weight: 700; /* Extra bold text */
      text-transform: uppercase; /* UMBC uses a lot of all-caps for nav */
      transition: all 0.2s ease;
    }
    .btn-nav-umbc:hover { 
      background-color: #000000; 
      color: #ffffff; 
    }
    
    /* 2. Functional Buttons (For standard app interactions) */
    .btn-func-umbc {
      background-color: #000000; 
      color: #ffffff; 
      border: none; 
      font-weight: bold;
      border-radius: 0px; /* UMBC's site uses sharp, square corners! */
      padding: 10px 20px;
      transition: background-color 0.2s ease;
    }
    .btn-func-umbc:hover { 
      background-color: #333333; /* Softens slightly so you know it's clicked */
      color: #ffffff; 
    }
    
    /* 3. Download Button (The Primary Call to Action) */
    .btn-dl-umbc {
      background-color: #e21833; 
      color: #ffffff; 
      border: none; 
      font-weight: bold;
      font-size: 16px;
      border-radius: 0px; /* Keeping the sharp corners */
      padding: 12px 24px;
      box-shadow: 0 4px 0 #a31125; /* A blocky, solid drop shadow */
      transition: all 0.1s ease;
    }
    .btn-dl-umbc:hover { 
      background-color: #c0142b; 
      color: #ffffff;
      transform: translateY(2px);
      box-shadow: 0 2px 0 #a31125; 
    }
  ")),
    tags$script(HTML("
      $(document).on('click', function (e) {
        // 1. Check if the mobile menu is currently open
        var menu_is_open = $('.navbar-collapse').hasClass('in') || $('.navbar-collapse').hasClass('show');
        
        // 2. Check if the user's click was OUTSIDE the navigation bar entirely
        var click_is_outside = $(e.target).closest('.navbar').length === 0;
        
        // 3. If the menu is open and they clicked away, simulate a click on the hamburger to close it
        if (menu_is_open && click_is_outside) {
          $('.navbar-toggle, .navbar-toggler').click();
        }
      });
    "))
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
                  textInput("action_job_id", "Enter Job ID:", placeholder = "JOB_YYYYMMDD_HHMMSS_XXXX"),
                  actionButton("check_progress_btn", "Check Progress", class = "btn-func-umbc"),
                  br(),
                  verbatimTextOutput("real_progress_output"),
                  uiOutput("bespoke_progress_bar"),
                  actionButton("retr_btn", "Go To Completed File", class = "btn-nav-umbc")
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
                
                    textInput("retrieve_job_id", "Enter Job ID:", placeholder = "JOB_YYYYMMDD_HHMMSS_XXXX"),
                  actionButton("check_status_btn", "Check Job Status", class = "btn-func-umbc"),
                  verbatimTextOutput("job_status"),
                  
                  downloadButton("retrieve_files_btn", "Download Output (.zip)", class = "btn-dl-umbc"),
                  br(),
                  p("Please tell us about your experience! "),
                  tags$a(
                    "Feedback Form",
                    href = "",
                    target = "_blank",
                    class = "btn-func-umbc"
                  ),
                  p("Check on the progress of your other files: "),
                  actionButton("prog_btn", "Go To Progress Tracking", class = "btn-nav-umbc")
                )
              )
            )
  )
)
