DROP TABLE IF EXISTS Users, Submissions, HPCJob CASCADE;

CREATE TABLE Users (
	User_ID SERIAL PRIMARY KEY,
	Student_ID TEXT,
	Email TEXT
);

CREATE TABLE Submissions(
	PDF_Submission_ID SERIAL PRIMARY KEY,
	Upload_Timestamp TIMESTAMP,
	User_ID INT NOT NULL,
	File_Name TEXT,
	FOREIGN KEY (User_ID) REFERENCES Users(User_ID)
);

CREATE TABLE HPCJob(
	Cluster_Slurm_ID TEXT PRIMARY KEY,
	PDF_Submission_ID INT NOT NULL,
	Current_Status TEXT,
	GPU_Model TEXT,
	Cores_Used INT,
	Nodes_Used INT,
	Total_Runtime_Seconds FLOAT,
	Total_Pages_Remediated INT,
	Original_File_Size_KB INT,
	Final_File_Size_KB INT,
	Math_Density_Per_Page FLOAT,
	Final_Outcome TEXT,
	FOREIGN KEY (PDF_Submission_ID) REFERENCES Submissions(PDF_Submission_ID)
);
