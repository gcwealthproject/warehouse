///////////////////////
/// US states schedules
///////////////////////

/// Last update: 25 July 2024
/// Author: Manuel 

/// Aim: load the statutory schedules and transform them into adjusted schedules

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
	if "$username" == "fsubioli" | "$username" == "Francesca Subioli" | "$username" == "Francesca"  { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}
	cd $dir // Set Dropbox/gcwealth as working directory
	global dofile "$dir\code\dashboards\eigt\"
	global intfile "$dir\raw_data\eigt\intermediary_files"
	global hmade "$dir\handmade_tables"
	global supvars "$dir\output\databases\supplementary_variables"

*******************************
*** Load SCHEDULE HANDMADE DATA
*******************************
	
	clear all
	
	import excel "handmade_tables/regional_eigt_transcribed.xlsx", firstrow clear
	compress 	
	replace Notes = "" if Notes == "."
	
	keep if Geo == "US" // US only
	keep if year > 2005 // after 2005 only	or including 2005?
	keep Geo GeoReg year Currency EIG_Status Adjusted* Federal* Statutory* Child_Exemption n Estate_Tax Gift_Tax Inheritance_Tax Source* Notes
	drop Statutory_Class_I_Tax_on_Lower_B Federal_Effective_Class_I_Tax_on Adjusted_Class_I_Tax_on_Lower_Bo

	
	tab GeoReg EIG_Status
	* No state EIG tax throughout 27 states: AK, AL, AR, AZ, CA, CO, FL, GA, ID, LA, MI, MO, MS, MT, ND, NH, NM, NV, OK, SC, SD, TX, UT, VA, WI, WV, WY	
	
*** Prepare EIG Statuses

	* TN
	replace EIG_Status = "N" if GeoReg == "TN" & year > 2015
	* NC
	replace EIG_Status = "N" if GeoReg == "NC" & EIG_Status == "Y" & year > 2012
	
	
	
// 1) Simple case in which EIG_Status = N: the adjusted schedule is the federal one

	foreach var in Exemption Class_I_Lower Class_I_Upper Class_I_Stat {
		replace Adjusted_`var' = Federal_Effective_`var' if EIG_Status == "N"
	}
	drop if Adjusted_Class_I_Lower == "_na" & Adjusted_Class_I_Upper == "_na" & Adjusted_Class_I_Stat == "_na" & EIG_Status == "N"
	replace n = 1 if GeoReg != GeoReg[_n-1] | (GeoReg == GeoReg[_n-1] & year != year[_n-1])
	replace n = n[_n-1] +1 if n != 1
	
	
	
	*** destring these variables to codify federal-adjusted integration
	global variables = "Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound Adjusted_Class_I_Statutory_Margi Federal_Effective_Class_I_Statut Federal_Effective_Exemption Child_Exemption Adjusted_Exemption Statutory_Class_I_Lower_Bound Statutory_Class_I_Upper_Bound Statutory_Class_I_Statutory_Marg Federal_Effective_Class_I_Upper_ Federal_Effective_Class_I_Lower_"
	
	foreach var in $variables {
		replace `var' = "." if `var' == "_na"
		replace `var' = "." if `var' == "_and_over"
		destring `var' , replace
	}
	
		
	*** get federal marginal rate constant across brackets (is flat rate after 2005 anyway)
	bys GeoReg year: ereplace Federal_Effective_Class_I_Statut = max(Federal_Effective_Class_I_Statut)
	*** get federal exemption constant across brackets within year
	bys GeoReg year: ereplace Federal_Effective_Exemption = max(Federal_Effective_Exemption)
	sort GeoReg year n
	
	gen federal_marker = .	
	
		
	* temporary save
	*save "/Users/manuelstone/Dropbox/_eig_us_states" , replace
	
***********************************	
	*use "/Users/manuelstone/Dropbox/_eig_us_states" , clear
	
	
	tab GeoReg EIG_Status 

*** unfinished adjusted schedules	
	*** ask about MD input -- 2021 second adjusted bracket threshold?
	*** ask about MN input -- adj rates 2012 and complicated to infer
	
	
	br GeoReg year EIG_Status Adjusted* Federal* Statutory* Child_Exemption federal_marker if GeoReg == "MN"
	
	
	*** do-files that integrate adjustment by rules
		
		do $dir/code/dashboards/eigt/USstates/02a_sample_1	
		do $dir/code/dashboards/eigt/USstates/02a_sample_2	
		do $dir/code/dashboards/eigt/USstates/02a_sample_3	
		do $dir/code/dashboards/eigt/USstates/02a_sample_4		
		do $dir/code/dashboards/eigt/USstates/02a_sample_5	
		do $dir/code/dashboards/eigt/USstates/02a_sample_or
		do $dir/code/dashboards/eigt/USstates/02a_sample_me		
		do $dir/code/dashboards/eigt/USstates/02a_sample_nj
		
		
		gen flag = (GeoReg == "IL" & year == 2010) | ///
				   (GeoReg == "ME" & year == 2020) | ///
				   (GeoReg == "OR" & year == 2021)
				   
		drop if Adjusted_Class_I_Lower_Bound == . & !flag
		drop if GeoR=="ME" & year == 2020 & n == 2
		drop if GeoR=="OR" & year == 2021 & n == 2		
		
		keep Geo GeoReg year Currency EIG_Status Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper Adjusted_Class_I_Statutory_Margi Estate_Tax Inheritance_Tax Gift_Tax Source* Note
		
		
		sort GeoReg year Adjusted_Class_I_Lower_Bound		
		
		
	save "$dir/raw_data/eigt/intermediary_files/USstates_adjusted", replace
		
		
	*** now merge with State Revenue information
	
		merge m:1 GeoReg year using "$dir/raw_data/eigt/intermediary_files/staterevfinal", keep(1 3)
		
		replace Source_2 = "GFS_data" if _merge == 3 & Source_2 == "."		
		replace Source_3 = "GFS_data" if _merge == 3 & Source_3 == "." & Source_2 != "GFS_data"
		replace Source_4 = "GFS_data" if _merge == 3 & Source_4 == "." & Source_3 != "GFS_data" & Source_2 != "GFS_data" 
		replace Source_5 = "GFS_data" if _merge == 3 & Source_5 == "." & Source_4 != "GFS_data" & Source_3 != "GFS_data" & Source_2 != "GFS_data" 
		replace Source_6 = "GFS_data" if _merge == 3 & Source_6 == "." & Source_5 != "GFS_data" & Source_4 != "GFS_data" & Source_3 != "GFS_data" & Source_2 != "GFS_data" 
		replace Source_7 = "GFS_data" if _merge == 3 & Source_7 == "." & Source_6 != "GFS_data" & Source_5 != "GFS_data" & Source_4 != "GFS_data" & Source_3 != "GFS_data" & Source_2 != "GFS_data" 
		
	save "$dir/raw_data/eigt/intermediary_files/USstates_final_oldstructure", replace
		