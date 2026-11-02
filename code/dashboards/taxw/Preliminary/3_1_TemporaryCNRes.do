
	
	// Integrate Yale, TID and IBFD (selected countries) together in a unique YaleTid_country.xlsx file	
	
	macro drop _all
	
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
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		foreach source in TIDData YaleInheritanceData IBFD_EIG {
			
			if "`source'" == "TIDData" global name TIDD_`country'				
			if "`source'" == "YaleInheritanceData" global name Yale_`country'
			if "`source'" == "IBFD_EIG" global name IBFD_`country'
			
			local filepath "Sources/`source'/`country'"
			if fileexists("`filepath'/$name.xlsx") {

			    qui import excel "`filepath'/$name.xlsx", sheet(Data) allstring firstrow clear
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
		foreach source in TIDData YaleInheritanceData IBFD_EIG {
	   	
			if "`source'" == "TIDData" global name TIDD_`country'				
			if "`source'" == "YaleInheritanceData" global name Yale_`country'
			if "`source'" == "IBFD_EIG" global name IBFD_`country'
		
		local filepath "Sources/`source'/`country'"
		if fileexists("`filepath'/$name.xlsx") {
			qui append using "`$name'"
		}
	}
		if fileexists("`TIDD_`country''") | fileexists("`Yale_`country''") | fileexists("`IBFD_`country''") {
			cap mkdir "Sources/Cross_national_academic_research/`country'"
			qui export excel using "Sources/Cross_national_academic_research/`country'/YaleTid_`country'.xlsx", firstrow(variables) sheet(Data) replace 
		}
		if (fileexists("`TIDD_`country''") & fileexists("`Yale_`country''")) | (fileexists("`TIDD_`country''") & fileexists("`IBFD_`country''")) | (fileexists("`Yale_`country''") & fileexists("`IBFD_`country''")) {
			display "`country'"
			global listtocheck $listtocheck `country'
		}
	}
	
	clear
	display "$listtocheck"
	
	set obs 100
	gen country = ""
	local c = 1
	foreach i of global listtocheck {
		replace country = "`i'" in `c'
		local c = `c'+1
	}
	drop if country == ""
	
	save "countries_tocheck2.dta", replace 
	
	// In countries_tocheck2 we have countries with both TID and Yale; check which ones have overlapping information
	
	foreach country of global listtocheck {
		display "`country'"
		local filepath "Sources/Cross_national_academic_research/`country'"
		if fileexists("`filepath'/YaleTid_`country'.xlsx") {
			qui import excel "`filepath'/YaleTid_`country'.xlsx", sheet(Data) allstring firstrow clear

		qui {			
			qui drop if subnat == "1"
			gsort -GEO year_from year_to subnationallevel tax applies_to Source
			duplicates tag GEO_l year_from year_to tax applies_to subnationallevel, gen(dupl)
			tab dupl
			if `r(r)' == 2 continue, break
			drop dupl
			preserve
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
				tab dupl
				if `r(r)' == 2 continue, break
				tab year Source if dupl
				tab year tax if dupl
				tab year applies_to if dupl		
			restore		
		}
		}	
	}	
	
	break here:
	// !! After modifying each single case, run again only 72-132 to move to the subsequent country
	
	// Case 1 Australia: estate in 1980 is overlapping. We keep TIDD for longer span after abolishment
	import excel "Sources/Cross_national_academic_research/AU/YaleTid_AU.xlsx", sheet(Data) allstring firstrow clear
	drop if tax == "estate" & year_from == "1980" & year_to == "1980" & Source == "YaleInheritanceData"
	qui export excel using "Sources/Cross_national_academic_research/AU/YaleTid_AU.xlsx", firstrow(variables) sheet(Data) replace 
	
	// Case 2 Belgium, children inheritance. We keep Yale, more complete
	import excel "Sources/Cross_national_academic_research/BE/YaleTid_BE.xlsx", sheet(Data) allstring firstrow clear
	drop if strtrim(Source) == "TIDData"
	qui export excel using "Sources/Cross_national_academic_research/BE/YaleTid_BE.xlsx", firstrow(variables) sheet(Data) replace 

	// Case 3 Germany, children inheritance. We keep Yale, more reliable, but report the note of TID
	import excel "Sources/Cross_national_academic_research/DE/YaleTid_DE.xlsx", sheet(Data) allstring firstrow clear
	replace note = "Firstly levied with the imperial law of June 3d, 1906, wich imposed an imperial inheritance at rates between 4% and 10%, depending on degree of relation. The inheritance tax had made its appearance in various parts of Germany prior to the adoption in 1906 of an Imperial inheritance tax, eduring the seventeenth century in  the city of Hamburg and the principality of Brunswick-Luneburg wich imposed the tax as early as 1624." if Source == "YaleInheritanceData" & year_from == "1906" & tax == "inheritance"
	drop if Source == "TIDData"
	qui export excel using "Sources/Cross_national_academic_research/DE/YaleTid_DE.xlsx", firstrow(variables) sheet(Data) replace
	
	// Case 4 Denmark, children inheritance. We keep Yale, more complete
	import excel "Sources/Cross_national_academic_research/DK/YaleTid_DK.xlsx", sheet(Data) allstring firstrow clear
	replace applies_to = "spouse" if applies_to == "children, spouse" & Source == "TIDData"
	qui export excel using "Sources/Cross_national_academic_research/DK/YaleTid_DK.xlsx", firstrow(variables) sheet(Data) replace 	
	
	// Case 5 France, children inheritance. We keep Yale, more complete
	import excel "Sources/Cross_national_academic_research/FR/YaleTid_FR.xlsx", sheet(Data) allstring firstrow clear
	replace applies_to = "spouse, siblings" if applies_to == "children, spouse, siblings"
	qui export excel using "Sources/Cross_national_academic_research/FR/YaleTid_FR.xlsx", firstrow(variables) sheet(Data) replace 		
	
	// Case 6 Norway, children inheritance. Yale is more complete and we keep it.
	import excel "Sources/Cross_national_academic_research/NO/YaleTid_NO.xlsx", sheet(Data) allstring firstrow clear	
	drop if tax == "inheritance" & applies_to == "children" & Source == "TIDData" & year_from == "1814" & year_to == "1815"
	drop if tax == "inheritance" & applies_to == "children" & Source == "TIDData" & year_from == "1816" & year_to == "1836"	
	drop if tax == "inheritance" & applies_to == "children" & Source == "TIDData" & year_from == "1837" & year_to == "1902"
	drop if tax == "inheritance" & applies_to == "children" & Source == "TIDData" & year_from == "1903" & year_to == "1925"	
	drop if tax == "inheritance" & applies_to == "children" & Source == "TIDData" & year_from == "1905" & year_to == "1925"
	drop if tax == "inheritance" & applies_to == "children" & Source == "TIDData" & year_from == "1926" & year_to == "1939"
	drop if tax == "inheritance" & applies_to == "children" & Source == "TIDData" & year_from == "1940" & year_to == "1940"	
	qui export excel using "Sources/Cross_national_academic_research/NO/YaleTid_NO.xlsx", firstrow(variables) sheet(Data) replace 			

	// Case 7 Viet Nam, overlapping TID (unknown) and IBFD, complete, we keep the latter.
	import excel "Sources/Cross_national_academic_research/VN/YaleTid_VN.xlsx", sheet(Data) allstring firstrow clear	
	drop if Source == "TIDData"
	qui export excel using "Sources/Cross_national_academic_research/VN/YaleTid_VN.xlsx", firstrow(variables) sheet(Data) replace 			
	
	// Rename all excel files 
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
    foreach country of local levels {
			
		local filepath "Sources/Cross_national_academic_research/`country'"
		
		if fileexists("`filepath'/YaleTid_`country'.xlsx") {
			qui import excel "`filepath'/YaleTid_`country'.xlsx", sheet(Data) allstring firstrow clear
			qui drop if GEO == " " | GEO == ""
			qui export excel using "`filepath'/CNRes_`country'.xlsx", firstrow(variables) sheet(Data) replace 
			qui erase "`filepath'/YaleTid_`country'.xlsx"
		}
	}	
	erase "countries_tocheck2.dta" 
