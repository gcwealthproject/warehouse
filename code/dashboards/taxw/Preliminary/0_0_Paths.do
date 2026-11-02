
// Working directory and paths

	*** automatized user paths
	global username "`c(username)'"
			
	* Francesca
	if "$username" == "fsubioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
		global dir2  "/Users/$username/Dropbox/gcwealth/raw_data/taxw/sources/taxsched_input"
	}	
	if "$username" == "Francesca Subioli" | "$username" == "Francesca" | "$username" == "franc" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth" 
		global dir2  "C:/Users/`c(username)'/Dropbox/gcwealth/raw_data/taxw/sources/taxsched_input" 
	}	
	* Luca 
	if "$username" == "lgiangregorio" | "$username" == "lucagiangregorio" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
		global dir2  "/Users/$username/Dropbox/gcwealth/raw_data/taxw/sources/taxsched_input"
	}
	
	global dofile "$dir/code/dashboards/taxw"
	global intfile "$dir/raw_data/taxw/intermediary_files"
	global hmade "$dir/handmade_tables"
	global supvars "$dir/output/databases/supplementary_variables"
	global sources "$dir/raw_data/taxw/sources"
	                   
	cd "$dir2"
	
	global supvarver 24Jun2026
	global oecdver 26august2026