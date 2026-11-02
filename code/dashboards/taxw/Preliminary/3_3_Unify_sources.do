
// Select the country, loop over sources, and generate a unique excel file with verified data, with a warning if there are overlapping dates for the same tax

	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop

	//---------------------------	
	// 1) Verify each source file	
	//---------------------------
	
	run "$dofile/Preliminary/taxw_verify_intermediate.ado" // run the ado file
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		foreach source in Academic_research ///
						  Cross_national_corporate_research ///
						  Cross_national_academic_research ///
						  Government_legislation ///
						  Government_research ///
						  Corporate_research {	
						  	
		 // Construct the file path
			if "`source'" == "Academic_research" global name Academic_`country'
			if "`source'" == "Cross_national_corporate_research" global name CorpRes_`country'
			if "`source'" == "Cross_national_academic_research" global name CNRes_`country'
			if "`source'" == "Government_legislation" global name Lex_`country'
			if "`source'" == "Government_research" global name GR_`country'
			if "`source'" == "Corporate_research" global name CR_`country'
			
			local filepath "Sources/`source'/`country'"
			
			if fileexists("`filepath'/$name.xlsx") {
			display as result "`country'"	
			disp as result "`source'"
			if "`country'" != "US" taxw_verify_intermediate `source' `country'
			else taxw_verify_intermediate `source' `country', value(exemption) dummy(taxcredit)		
			}
		}
	}

	//---------------------------------------------
	// 2) Append all source files in a unique Excel
	//--------------------------------------------- 

	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		display as result "`country'"
					
		foreach source in Academic_research ///
						  Cross_national_corporate_research ///
						  Cross_national_academic_research ///
						  Government_legislation ///
						  Government_research /// 
						  Corporate_research {

			if "`source'" == "Academic_research" global name Academic_`country'
			if "`source'" == "Cross_national_corporate_research" global name CorpRes_`country'
			if "`source'" == "Cross_national_academic_research" global name CNRes_`country'
			if "`source'" == "Government_legislation" global name Lex_`country'
			if "`source'" == "Government_research" global name GR_`country'
			if "`source'" == "Corporate_research" global name CR_`country'
			
			local filepath "Sources/`source'/`country'"
			if fileexists("`filepath'/$name.xlsx") {
				*disp as result "`source'"
				clear
				qui import excel "`filepath'/$name.xlsx", sheet(Data) allstring firstrow 
				// Remove lead and last blank spaces 
				qui ds 
				foreach var in `r(varlist)' {
					qui replace `var' = strtrim(`var')
				}
				tempfile $name
				qui save "`$name'", replace
			}
		}
	
	clear
	foreach source in Academic_research ///
					  Cross_national_corporate_research ///
					  Cross_national_academic_research ///
					  Government_legislation ///
					  Government_research /// 
					  Corporate_research {
					  					  	
		if "`source'" == "Academic_research" global name Academic_`country'
		if "`source'" == "Cross_national_corporate_research" global name CorpRes_`country'
		if "`source'" == "Cross_national_academic_research" global name CNRes_`country'
		if "`source'" == "Government_legislation" global name Lex_`country'
		if "`source'" == "Government_research" global name GR_`country'	
		if "`source'" == "Corporate_research" global name CR_`country'
			
		local filepath "Sources/`source'/`country'"
		if fileexists("`$name'") qui append using "`$name'"
	}
	qui count
	if `r(N)' != 0 {
		qui drop if GEO == "" & GEO_long == "" 
		tempfile appended_`country'
		qui save "`appended_`country''", replace
		*display as result "Data for `country' appended..."
	}	
	
	//-------------------------------------
	// 3) Verify the overlapping and choose
	//-------------------------------------
	
	// 3.1 Check for the overlapping of the SAME applies to and tax

	if fileexists("`appended_`country''") {
		qui drop if subnat == "1"
		gsort -GEO year_from year_to tax applies_to
		qui duplicates tag GEO_l year_from year_to tax applies_to, gen(dupl)
		qui tab dupl
		if `r(r)' != 1  {
			display as error "Check `country' for simple overlapping!"
			cap mkdir "$sources/Final_Data/`country'"
			qui use "`appended_`country''", clear
			qui save "$sources/Final_Data/`country'/appended_`country'", replace
			*continue, break		
		}
		cap drop dupl
		preserve
			qui {
			// Replicate for years 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
						
			// Replicate for kinship
			qui split(applies_to), parse(,)
			
			forvalues i = 1/`r(k_new)' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `r(k_new)'
			local k = `r(k_new)'
			local k = `r(k_new)'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			sort GEO year applies_to tax dupl

			egen group = group(GEO applies_to tax year Source)
			replace applies_to = applies_to1 if dupl == 0		
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies_to`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies_to`i' != ""
			}	
			drop applies_to1-applies_to`k' expans dupl group
		
			duplicates tag GEO_l year tax applies_to, gen(dupl)
			}
			qui tab dupl
			if `r(r)' != 1 {
				display as error "Check `country' for simple overlapping2!"
				cap mkdir "$sources/Final_Data/`country'"
				qui use "`appended_`country''", clear
				qui save "$sources/Final_Data/`country'/appended_`country'", replace				
				*continue, break		
			}
		restore		
		
	// 3.2 Check for overlapping between children(others) and everybody
		preserve
			qui {
			// Replicate for years 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
						
			// Replicate for kinship
			qui split(applies_to), parse(,)
			
			forvalues i = 1/`r(k_new)' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `r(k_new)'
			local k = `r(k_new)'
			local k = `r(k_new)'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			forvalues i = `k'(-1)1 {
				rename applies_to`i' applies`i'
				replace applies`i' = "children" if applies`i' == "everybody"
			}			
			sort GEO year applies_to tax dupl

			egen group = group(GEO applies_to tax year Source)
			replace applies_to = applies1 if dupl == 0
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies`i' != ""
			}	
			drop applies1-applies`k' expans dupl group
		
			duplicates tag GEO_l year tax applies_to, gen(dupl)
			}
			qui tab dupl
			if `r(r)' != 1 {
				display as error "Check `country' for overlapping with everybody!"
				cap mkdir "$sources/Final_Data/`country'"
				qui use "`appended_`country''", clear
				qui save "$sources/Final_Data/`country'/appended_`country'", replace				
				*continue, break		
			}
		restore
		
	// 3.3 Check for overlapping between children(others) and unkown
		preserve
			qui {
			// Replicate for years 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
						
			// Replicate for kinship
			qui split(applies_to), parse(,)
			
			forvalues i = 1/`r(k_new)' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `r(k_new)'
			local k = `r(k_new)'
			local k = `r(k_new)'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			forvalues i = `k'(-1)1 {
				rename applies_to`i' applies`i'
				replace applies`i' = "children" if applies`i' == "unknown"
			}			
			sort GEO year applies_to tax dupl

			egen group = group(GEO applies_to tax year Source)
			replace applies_to = applies1 if dupl == 0
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies`i' != ""
			}	
			drop applies1-applies`k' expans dupl group
		
			duplicates tag GEO_l year tax applies_to, gen(dupl)
			}
			qui tab dupl
			if `r(r)' != 1 {
				display as error "Check `country' for overlapping with everybody!"
				cap mkdir "$sources/Final_Data/`country'"
				qui use "`appended_`country''", clear
				qui save "$sources/Final_Data/`country'/appended_`country'", replace				
				*continue, break		
			}
		restore
		
	// 3.4 Check for overlapping between unknown and everybody
		preserve
			qui {
			// Replicate for years 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
						
			// Replicate for kinship
			qui split(applies_to), parse(,)
			
			forvalues i = 1/`r(k_new)' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `r(k_new)'
			local k = `r(k_new)'
			local k = `r(k_new)'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			forvalues i = `k'(-1)1 {
				rename applies_to`i' applies`i'
				replace applies`i' = "everybody" if applies`i' == "unknown"
			}			
			sort GEO year applies_to tax dupl

			egen group = group(GEO applies_to tax year Source)
			replace applies_to = applies1 if dupl == 0
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies`i' != ""
			}	
			drop applies1-applies`k' expans dupl group
		
			duplicates tag GEO_l year tax applies_to, gen(dupl)
			}
			qui tab dupl
			if `r(r)' != 1 {
				display as error "Check `country' for overlapping everybody&unknown!"
				cap mkdir "$sources/Final_Data/`country'"
				qui use "`appended_`country''", clear
				qui save "$sources/Final_Data/`country'/appended_`country'", replace				
				*continue, break		
			}
		restore			
		
		//------------------------
		// 4) Save matched version 
		//------------------------
		
		cap mkdir "$sources/Final_Data/`country'"
		qui export excel using "$sources/Final_Data/`country'/Final_`country'.xlsx", firstrow(variables) sheet(Data) replace
	}
	}
	
	break here
	
	///----------------------------------
	// Manually check each single country, then run the harmonization do files
	///----------------------------------
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	levelsof GEO, local(levels)
    foreach country of local levels {
			if fileexists("$dofile/Preliminary/harmonization/harmonization_`country'.do") {
				display "Harmonizing `country'..."
				run "$dofile/Preliminary/harmonization/harmonization_`country'.do"
			}
	}
	
	//------------------ END ------------------//
