DROP TABLE IF EXISTS Users, Submissionso, HPCJob Cascade;

CREATE TABLE Users (
	User_ID SERIAL PRIMARY KEY,
	Student_ID TEXT,
	Email TEXT
);

CREATE TABLE Submissions(
	PDF_Submission_ID SERIAL PRIMARY KEY,
	Upload_Timestamp TIMESTAMP,
	File_Name TEXT,
	FOREIGN KEY (User_ID) REFERENCES Users(User_ID)
);

CREATE TABLE HPCJob(
	Cluster_Slurm_ID TEXT PRIMARY KEY,
	Current_Status TEXT,
	GPU_Model TEXT,
	Cores_Used INT NOT NULL,
	Nodes_Used INT NOT NULL,
	Total_Runtime_Seconds FLOAT NOT NULL,
	Total_Pages_Remediated INT NOT NULL,
	Original_File_Size_KB INT NOT NULL,
	Final_File_Size_KB INT NOT NULL,
	Math_Density_Per_Page FLOAT,
	Final_Outcome TEXT,
	FOREIGN KEY (PDF_Submission_ID) REFERENCES Documents(PDF_Submission_ID)
);
