DROP TABLE IF EXISTS HPCJob;
DROP TABLE IF EXISTS Submissions;
DROP TABLE IF EXISTS Users;

CREATE TABLE Users (
	User_ID INTEGER PRIMARY KEY AUTOINCREMENT,
	Student_ID TEXT,
	Email TEXT
);

CREATE TABLE Submissions(
	PDF_Submission_ID INTEGER PRIMARY KEY AUTOINCREMENT,
	Upload_Timestamp TEXT,
	User_ID INTEGER,
	File_Name TEXT,
	FOREIGN KEY (User_ID) REFERENCES Users(User_ID)
);

CREATE TABLE HPCJob(
	Cluster_Slurm_ID TEXT PRIMARY KEY,
	PDF_Submission_ID INTEGER,
	Current_Status TEXT,
	GPU_Model TEXT,
	Cores_Used INTEGER,
	Nodes_Used INTEGER,
	Total_Runtime_Seconds REAL,
	Total_Pages_Remediated INTEGER,
	Original_File_Size_KB INTEGER,
	Final_File_Size_KB INTEGER,
	Math_Density_Per_Page REAL,
	Final_Outcome TEXT,
	FOREIGN KEY (PDF_Submission_ID) REFERENCES Submissions(PDF_Submission_ID)
);
