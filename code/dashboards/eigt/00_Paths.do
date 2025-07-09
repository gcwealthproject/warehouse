/// Main paths for running EIGT Warehouse, metadata, and Website /// 

	clear

// Working directory and paths

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
	
	global dofile "$dir/code/dashboards/eigt"
	global dofile_us "$dir/code/dashboards/eigt/USstates"
	global intfile "$dir/raw_data/eigt/intermediary_files"
	global hmade "$dir/handmade_tables"
	global supvars "$dir/output/databases/supplementary_variables"
	global sources "$dir/raw_data/eigt/sources"
	global output "$dir/raw_data/eigt"
	global website "$dir/output/databases/website"

	
	global supvarver 16Jul2024
	global oecdver 14april2025