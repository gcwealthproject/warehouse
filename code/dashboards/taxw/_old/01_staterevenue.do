///////////////////////
/// US states revenue
///////////////////////

*******************
*** General setting
*******************
	clear all
	
	set maxvar 32767 
	
// Version of data release
	global release v1
	global oecd_ver 17oct2023
	global supvar_ver 28sep2023
	
// Working directory and paths

	*** automatized user paths
	global username "`c(username)'"
	
	dis "$username" // Displays your user name on your computer
		
	* Manuel
	if "$username" == "manuelstone" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}
		
	* Twisha
	if "$username" == "twishaasher" { 
		global dir  "/Users/`c(username)'/Dropbox (Hunter College)/gcwealth" 
	}

	* Francesca
	if "$username" == "fsubioli" | "$username" == "Francesca Subioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}
	cd $dir // Set Dropbox/gcwealth as working directory
	global dofile "$dir\code\dashboards\eigt\"
	global intfile "$dir\raw_data\eigt\intermediary_files"
	global hmade "$dir\handmade_tables"
	global supvars "$dir\output\databases\supplementary_variables"

	
	*** set working directory
	cd "$dir/code/dashboards/eigt/USstates/TheGovernmentFinanceDatabase_StateData"

********************************************************************************	
	*** get state gdp data from correlates of state policy project: https://ippsr.msu.edu/public-policy/correlates-state-policy
********************************************************************************
	
	*** prepare state gdp

	clear all 
	import delimited "correlates2-6.csv", varnames(1) 
		
		keep gsp_naics_ann gsp_sic_ann gsptotal year state_fips state
		drop if gsptotal == ""
		destring state_fips year, replace
			
		drop if year < 1963
			
		keep state_fips year gsptotal
		
		replace gsptotal = "." if gsptotal == "NA"
		
		*** state GDP is in millions of nominal dollars
		destring gsptotal , replace
		
		rename state_fips fips_code_state
		
		save "stategdp", replace

		
	
********************************************************************************	
	*** get state tax revenue data from Government Finance Database: https://willamette.edu/mba/research-impact/public-datasets/index.html
********************************************************************************

	*** prepare revenue data

	clear all
	import delimited "StateData.csv", varnames(1) 

		rename year4 year
		
		keep fips_code_state year total_taxes death_and_gift_tax
		
		
			*** total regional revenue in thousands of nominal dollars
			rename death_and_gift_tax refrev

			*** regional revenue as share of total regional taxes
			gen rprrev = refrev / total_taxes
			
			
			
		merge m:1 fips_code_state using "stateabr"	
			keep if _merge == 3
			drop _merge total_taxes 
			
			
		drop if year < 1977	
		
		
		
	*** merge with state gdp data
	
		merge 1:1 fips_code_state year using "stategdp"
			keep if _merge == 3
			drop _merge 
			
			
	
		*** generate state level revenue as share of state gdp (gdp is in millions and revenue in thousands, so have to adjust)	
		gen rrvgdp = refrev / (gsptotal*1000)
			
		drop fips_code_state gsptotal	
			
			
	save "staterevfinal", replace	
			
			
