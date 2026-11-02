********************************************************************************
*** EIG data: automated country documentation 
********************************************************************************


	clear all
	
	set maxvar 32000
	
	*** automatized user paths
	global username "`c(username)'"
	
		dis "$username" // Displays your user name on your computer

		
		* Manuel
		if "$username" == "manuelstone" { 
			global dir  "/Users/manuelstone/Dropbox/THE_GC_WEALTH_PROJECT_website" 
		}
		
		* Twisha
		if "$username" == "twishaasher" { 
			global dir  "/Users/twishaasher/Dropbox (Hunter College)/THE_GC_WEALTH_PROJECT_website" 
		}

	   
	*** use long data file
	use "$dir/EIG Taxes/data_output/EIGtax_long.dta", clear
	*** set up data 
		
		*** download country codes
		preserve
			
		import excel "$dir/metadata_and_sources.xlsx", sheet("GEO") cellrange(A1:C251) firstrow case(lower) clear
			
			qui rename geo area
				
		save "$dir/EIG Taxes/data_inputs/country_codes.dta", replace
				
		restore
		
		merge m:1 area using "$dir/EIG Taxes/data_inputs/country_codes.dta"
		
		
	*** prepare data 
	
		*** Drop state observations
			qui drop if _merge!=3
			qui drop _merge
				
		*** get numeric country identifier
			encode geo3, gen(geoid)
		
		*** retrieve bracket numbers
			qui gen bracket = substr(varcode, -2,2)
	

	*** get summary statistics for documentation output
		
		*** first country year in data
			bys geoid: egen firstyear 	= min(year)
		
		*** last country year in data
			bys geoid: egen lastyear  	= max(year)
			
		*** total number of country-years
			egen N_yrs = nvals(year), by(geoid)
		
		*** indicator for multiple sources
			*qui gen multi_source = 1 if source2 != "."
			
			*bys geoid: egen multi_source_geo	= max(multi_source)
		
	
		*** document all sources by country 
		
			qui gen sources = ""
		
			levelsof country, local(geolist)
		
				qui foreach c in `geolist' {
				
				qui forvalues i = 1/7 {
					
					levelsof source`i' if country == "`c'" & source`i' != "." , clean sep(,) local(s`i')
				}
				
				local s_all "`s1' `s2' `s3' `s4' `s5' `s6' `s7'"
				local s_all : list uniq s_all
				
				qui replace sources  = `"`s_all'"' if country == "`c'"
				
			}
		
				qui replace sources = subinstr(sources, ".", "", .)
	
	
	
		*** list years where we report there is a EIG tax
			
			qui gen eigstayears = ""
			
			*levelsof country, local(geolist)
		
			qui foreach c in `geolist' {
				
					levelsof year if country == "`c'" & varcode == "x-hs-cat-eigsta-00" & value_string == "Y" , clean sep(,) local(eigst)
			
				local e_all "`eigst'"
				local e_all : list uniq e_all
			
				qui replace eigstayears = `"`e_all'"' if country == "`c'"
			
			
			}	

					 
		*** list years where we report a positive top rate
			
			qui gen topratyears = ""
			
			*levelsof country, local(geolist)
		
			qui foreach c in `geolist' {
				
					levelsof year if country == "`c'" & varcode == "x-hs-rat-toprat-00" & value_string != "0" , clean sep(,) local(toprat)
			
				local t_all "`toprat'"
				local t_all : list uniq t_all
			
				qui replace topratyears = `"`t_all'"' if country == "`c'"
			
			
			}			 	


		
	*** LOOP over outcomes is not working *** all countries filled with first info 
	
		********** Make Tables *****************************************
		****** Create full country list with legal characters only *****
		** Legal characters
			qui replace country = subinstr(country, ",", " ", .)
			qui replace country = subinstr(country, ".", " ", .)
		
		** Full list
		levelsof country, local(geolist)

		
		****** Create Tables by Country *****
			local outvars firstyear lastyear N_yrs eigstayears topratyears sources
			local outlabs " "First Year of Data" "Last Year of Data" "Number of Years of Data" "Years with EIG tax" "Years with positive top rate" "Sources" "		
	
	
	
	
	qui foreach c in `geolist' {
		
		qui putexcel set "$dir/EIG Taxes/data_output/countries.xlsx", sheet(`c') modify
		
		qui putexcel A1 = "Country"
			sleep 10
			
		qui putexcel B1 = "`c'"
			sleep 10
			
		qui putexcel A2 = "First Year"
			sleep 10
		qui levelsof firstyear if country=="`c'", local(fyr)
		qui putexcel B2 = `fyr'
			sleep 10
			
		qui putexcel A3 = "Last Year"
			sleep 10
		qui levelsof lastyear if country=="`c'", local(lyr)
		qui putexcel B3 = `lyr'
			sleep 10
			
		qui putexcel A4 = "Number of Years"
			sleep 10
		qui levelsof N_yrs if country=="`c'", local(nyr)
		qui putexcel B4 = `nyr'
			sleep 10
			
		qui putexcel A5 = "Years with EIG tax"
			sleep 10
		qui levelsof eigstayears if country=="`c'", clean sep(, ) local(eyr)
		qui putexcel B5 = `"`eyr'"'
			sleep 10
			
			
		qui putexcel A6 = "Years with positive top rate"
			sleep 10
		qui levelsof topratyears if country=="`c'", clean sep(, ) local(tyr)
		qui putexcel B6 = `"`tyr'"'
			sleep 10	
			
			
		putexcel A7 = "Sources"
			sleep 10
		levelsof source1 if country=="`c'", clean sep(, ) local(s1)
		putexcel B7 = `"`s1'"'
			sleep 10
			
		qui putexcel save
			sleep 10
			
		qui putexcel clear
	}
			
			
			
		*************************************
		******************************************************



