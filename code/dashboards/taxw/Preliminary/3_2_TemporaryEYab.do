	
	// Integrate EYa and EYb together in a unique EYab_country.xlsx file	
	
	// Take the list of countries from the dictionary

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
	
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		
		// For Germany, France, and US CorpRes_country is already manually generated merging EYa, EYb and IBFD! //  
		if "`country'" != "DE" & "`country'" != "FR" & "`country'" != "US" {
		foreach source in EY_EIG_Guide EY_Personal_Tax_Guide {
			
			if "`source'" == "EY_EIG_Guide" global name EYb_`country'				
			if "`source'" == "EY_Personal_Tax_Guide" global name EYa_`country'
			
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
	foreach source in EY_EIG_Guide EY_Personal_Tax_Guide {
	   	
		if "`source'" == "EY_EIG_Guide" global name EYb_`country'				
		if "`source'" == "EY_Personal_Tax_Guide" global name EYa_`country'
		
		local filepath "Sources/`source'/`country'"
		if fileexists("`filepath'/$name.xlsx") {
			qui append using "`$name'"
		}
	}
		if fileexists("`EYb_`country''") | fileexists("`EYa_`country''") {
			cap mkdir "Sources/Cross_national_corporate_research/`country'"
			qui export excel using "Sources/Cross_national_corporate_research/`country'/EYab_`country'.xlsx", firstrow(variables) sheet(Data) replace 
		}
		if fileexists("`EYb_`country''") & fileexists("`EYa_`country''") {
			display "`country'"
			global listtocheck $listtocheck `country'
		}
	}
	}
	clear
	display "$listtocheck"
	
	set obs 100
	gen country = ""
	local c = 1
	foreach i of global listtocheck {
		qui replace country = "`i'" in `c'
		local c = `c'+1
	}
	drop if country == ""
	
	save "countries_tocheck.dta", replace 
	
	// In countries_tocheck we have countries with both EYa and EYb; check which ones have overlapping information
	
	foreach country of global listtocheck {
		display "`country'"
		local filepath "Sources/Cross_national_corporate_research/`country'"
		if fileexists("`filepath'/EYab_`country'.xlsx") {
			qui import excel "`filepath'/EYab_`country'.xlsx", sheet(Data) allstring firstrow clear

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
			egen group = group(GEO applies_to tax year_from year_to)
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

			egen group = group(GEO applies_to tax year)
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
	// !! After modifying each single case, run again only 101-137 to move to the subsequent country
	// Rename all excel files 
	
	// Case 1 Chile, we corrected EY with legislative information, so we rely on the 2000-2024 information
	import excel "Sources/Cross_national_corporate_research/CL/EYab_CL.xlsx", sheet(Data) allstring firstrow clear
	drop if year_from != "2000" | year_to != "2024"
	qui export excel using "Sources/Cross_national_corporate_research/CL/EYab_CL.xlsx", firstrow(variables) sheet(Data) replace 

	// Case 2 Greece - overlapping in 2020, we keep EYb as it has detailed schedules
	import excel "Sources/Cross_national_corporate_research/GR/EYab_GR.xlsx", sheet(Data) allstring firstrow clear
	drop if Source == "EY2020a"
	qui export excel using "Sources/Cross_national_corporate_research/GR/EYab_GR.xlsx", firstrow(variables) sheet(Data) replace 	

	// Case 3 India - overlapping in 2006-2012 EYa and EYb, same information (no tax)
	import excel "Sources/Cross_national_corporate_research/IN/EYab_IN.xlsx", sheet(Data) allstring firstrow clear
	drop if substr(Source, 7,1) == "a" & inlist(year_from, "2006", "2007", "2008", "2009", "2010", "2011", "2012")
	qui export excel using "Sources/Cross_national_corporate_research/IN/EYab_IN.xlsx", firstrow(variables) sheet(Data) replace
	
	// Case 4 Malta - we keep EYb in years 2014/15 and 2020/23 as it has details in Note
	import excel "Sources/Cross_national_corporate_research/MT/EYab_MT.xlsx", sheet(Data) allstring firstrow clear
	drop if inlist(Source, "EY2014a", "EY2015a", "EY2020a", "EY2021a", "EY2022a", "EY2023a") 
	qui export excel using "Sources/Cross_national_corporate_research/MT/EYab_MT.xlsx", firstrow(variables) sheet(Data) replace 
	
	// Case 5 Netherlands 2011, everybody estate. We keep EYb
	import excel "Sources/Cross_national_corporate_research/NL/EYab_NL.xlsx", sheet(Data) allstring firstrow clear
	drop if year_from == "2011" & year_to == "2011" & Source == "EY2011a" & tax == "estate" & applies_to == "everybody"
	qui export excel using "Sources/Cross_national_corporate_research/NL/EYab_NL.xlsx", firstrow(variables) sheet(Data) replace 
	
	// Case 6 New Zealand 2006-2011, everybody estate. We keep EYb
	import excel "Sources/Cross_national_corporate_research/NZ/EYab_NZ.xlsx", sheet(Data) allstring firstrow clear	
	forvalues i=2006/2011 {
		drop if year_from == "`i'" & year_to == "`i'" & Source == "EY`i'a" & tax == "estate" & applies_to == "everybody"
		drop if year_from == "`i'" & year_to == "`i'" & Source == "EY`i'a" & tax == "inheritance" & applies_to == "everybody"	
	}
	drop if year_from == "2011" & year_to == "2011" & Source == "EY2011a" & tax == "gift" & applies_to == "everybody"		
	qui export excel using "Sources/Cross_national_corporate_research/NZ/EYab_NZ.xlsx", firstrow(variables) sheet(Data) replace 	

	// Case 7 Portugal
	import excel "Sources/Cross_national_corporate_research/PT/EYab_PT.xlsx", sheet(Data) allstring firstrow clear
	forvalues i=2006/2011 {
		drop if year_from == "`i'" & year_to == "`i'" & Source == "EY`i'a"
	}	
	forvalues i=2004/2024 {
		replace note = "Inheritance and gift taxes were abolished effective January 1, 2004. A stamp duty of 10% applies to individual beneficiaries, except for spouses, ascendants, and descendants who are exempt." if year_from == "`i'" & year_to == "`i'" & tax != "estate"
	}
	qui export excel using "Sources/Cross_national_corporate_research/PT/EYab_PT.xlsx", firstrow(variables) sheet(Data) replace 		
	
	// Case 8 Sweden, EYa reports abolition in 2006, while it is in 2004. We keep EYb
	import excel "Sources/Cross_national_corporate_research/SE/EYab_SE.xlsx", sheet(Data) allstring firstrow clear
	drop if substr(Source, -1, 1) == "a"
	qui export excel using "Sources/Cross_national_corporate_research/SE/EYab_SE.xlsx", firstrow(variables) sheet(Data) replace 		
	
	// Case 9 Singapore, 2007 different information for exemption. We keep the EYa information and leave the exemptions in the notes
	import excel "Sources/Cross_national_corporate_research/SG/EYab_SG.xlsx", sheet(Data) allstring firstrow clear
	drop if year_from == "2007" & year_to == "2007" & Source == "EY2023b" & tax == "estate" & applies_to == "everybody"
	replace note = "There are few exemptions allowed such as: residential properties up to an aggregate value of S$9 million; Taxable property up to the greater of S$600,000 in property value or the deceased's balance in the CPF account." if ((year_from == "2007" & year_to == "2007") | (year_from == "2006" & year_to == "2006")) & tax == "estate"	
	
	forvalues i=2008/2011 {
		drop if year_from == "`i'" & year_to == "`i'" & Source == "EY`i'a" & tax == "estate" & applies_to == "everybody"
	}
	
	replace note = "Estate duty has been eliminated from Singapore tax regime for deaths occurring on or after 15 feb 2008." if tax == "estate" & applies_to == "everybody" & (Source == "EY2023b" | Source == "EY2024b")

	qui export excel using "Sources/Cross_national_corporate_research/SG/EYab_SG.xlsx", firstrow(variables) sheet(Data) replace 			
	
	// Case 10 Turkey, 2011 estate tax replicates. We keep the EYb
	import excel "Sources/Cross_national_corporate_research/TR/EYab_TR.xlsx", sheet(Data) allstring firstrow clear
	drop if year_from == "2011" & year_to == "2011" & Source == "EY2011a" & tax == "estate" & applies_to == "everybody"	
	qui export excel using "Sources/Cross_national_corporate_research/TR/EYab_TR.xlsx", firstrow(variables) sheet(Data) replace 

	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		if "`country'" != "FR" & "`country'" != "US" & "`country'" != "DE" {
		local filepath "Sources/Cross_national_corporate_research/`country'"
		if fileexists("`filepath'/EYab_`country'.xlsx") {
			qui import excel "`filepath'/EYab_`country'.xlsx", sheet(Data) allstring firstrow clear
			qui export excel using "`filepath'/CorpRes_`country'.xlsx", firstrow(variables) sheet(Data) replace 
			qui erase "`filepath'/EYab_`country'.xlsx"
		}
	}
	}
	erase "countries_tocheck.dta"
	// REMEMBER: for France, US, Germany, we don't use the EY files since the CorpRes_country already exists integrating EYa, EYb, and IBFD (manual compilation)