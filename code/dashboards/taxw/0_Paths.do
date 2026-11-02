/// Main paths for running TAXW Warehouse, metadata, and Website /// 

	clear

// Working directory and paths
/*
	*** automatized user paths
	global username "`c(username)'"
	
	dis "$username" // Displays your user name on your computer
		
	* Francesca
	if "$username" == "fsubioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	if "$username" == "Francesca Subioli" | "$username" == "Francesca" | "$username" == "franc" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	* Luca 
	if "$username" == "lgiangregorio" | "$username" == "lucagiangregorio" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}
*/	
	global dofile "code/dashboards/taxw" 
	global dofile_us "code/dashboards/taxw/USstates"
	global intfile "raw_data/taxw/intermediary_files"
	global hmade "handmade_tables"
	global supvars "output/databases/supplementary_variables"
	global sources "raw_data/taxw/sources"
	global output "raw_data/taxw"
	global website "output/databases/website"

	global supvarver 24Jun2026
	global oecdver 26august2026
