// Aim: create the regional US states data // 

// Last update: July 2025 


*******************************
*** Load SCHEDULE HANDMADE DATA
*******************************
	
	clear all
	
	import excel "$sources/regional_eigt_transcribed.xlsx", firstrow clear
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
	
	
	*** do-files that integrate adjustment by rules
		
		do $dofile_us/02a_sample_1	
		do $dofile_us/02a_sample_2	
		do $dofile_us/02a_sample_3	
		do $dofile_us/02a_sample_4		
		do $dofile_us/02a_sample_5	
		do $dofile_us/02a_sample_or
		do $dofile_us/02a_sample_me		
		do $dofile_us/02a_sample_nj
		
			
		gen flag = (GeoReg == "IL" & year == 2010) | ///
				   (GeoReg == "ME" & year == 2020) | ///
				   (GeoReg == "OR" & year == 2021)
				   
		drop if Adjusted_Class_I_Lower_Bound == . & !flag
		drop if GeoR=="ME" & year == 2020 & n == 2
		drop if GeoR=="OR" & year == 2021 & n == 2		
		
		keep Geo GeoReg year Currency EIG_Status Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper Adjusted_Class_I_Statutory_Margi Estate_Tax Inheritance_Tax Gift_Tax Source* Note
		
		
		sort GeoReg year Adjusted_Class_I_Lower_Bound		
	
		save "$intfile/USstates_adjusted.dta", replace
	
/// Import revenue data /// 

	********************************************************************************	
	*** get state gdp data from correlates of state policy project: https://ippsr.msu.edu/public-policy/correlates-state-policy
********************************************************************************
	
	*** prepare state gdp

	clear all 
	import delimited "$sources/TheGovernmentFinanceDatabase_StateData/correlates2-6.csv", varnames(1) 
		
		keep gsp_naics_ann gsp_sic_ann gsptotal year state_fips state
		drop if gsptotal == ""
		destring state_fips year, replace
			
		drop if year < 1963
			
		keep state_fips year gsptotal
		
		replace gsptotal = "." if gsptotal == "NA"
		
		*** state GDP is in millions of nominal dollars
		destring gsptotal , replace
		
		rename state_fips fips_code_state
		
		tempfile stategdp
		save "`stategdp'", replace 
		
	
********************************************************************************	
	*** get state tax revenue data from Government Finance Database: https://willamette.edu/mba/research-impact/public-datasets/index.html
********************************************************************************

	*** prepare revenue data

	clear all
	import delimited "$sources/TheGovernmentFinanceDatabase_StateData/StateData.csv", varnames(1) 

		rename year4 year
		
		keep fips_code_state year total_taxes death_and_gift_tax
		
		
			*** total regional revenue in thousands of nominal dollars
			rename death_and_gift_tax refrev

			*** regional revenue as share of total regional taxes
			gen rprrev = refrev / total_taxes
			
			
			
		merge m:1 fips_code_state using "$sources/TheGovernmentFinanceDatabase_StateData/stateabr.dta"	
			keep if _merge == 3
			drop _merge total_taxes 
			
			
		drop if year < 1977	
		
		
		
	*** merge with state gdp data
	
		merge 1:1 fips_code_state year using  "`stategdp'"
			keep if _merge == 3
			drop _merge 
			
			
	
		*** generate state level revenue as share of state gdp (gdp is in millions and revenue in thousands, so have to adjust)	
		gen rrvgdp = refrev / (gsptotal*1000)
			
		drop fips_code_state gsptotal	
			
			
	save "$intfile/US_states_revenues_final.dta", replace	
			

*** now merge with State Revenue information
	use "$intfile/USstates_adjusted.dta", clear 
	
	merge m:1 GeoReg year using "$intfile/US_states_revenues_final", keep(1 3)
		
		replace Source_2 = "GFS_data" if _merge == 3 & Source_2 == "."		
		replace Source_3 = "GFS_data" if _merge == 3 & Source_3 == "." & Source_2 != "GFS_data"
		replace Source_4 = "GFS_data" if _merge == 3 & Source_4 == "." & Source_3 != "GFS_data" & Source_2 != "GFS_data" 
		replace Source_5 = "GFS_data" if _merge == 3 & Source_5 == "." & Source_4 != "GFS_data" & Source_3 != "GFS_data" & Source_2 != "GFS_data" 
		replace Source_6 = "GFS_data" if _merge == 3 & Source_6 == "." & Source_5 != "GFS_data" & Source_4 != "GFS_data" & Source_3 != "GFS_data" & Source_2 != "GFS_data" 
		replace Source_7 = "GFS_data" if _merge == 3 & Source_7 == "." & Source_6 != "GFS_data" & Source_5 != "GFS_data" & Source_4 != "GFS_data" & Source_3 != "GFS_data" & Source_2 != "GFS_data" 
		
	save "$intfile/USstates_final_oldstructure.dta", replace



