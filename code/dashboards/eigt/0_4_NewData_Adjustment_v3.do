***************************
*** EIGT data: add new data 
***************************

// Last update: 18 June 2025

// Change working directory and paths (restored at the end)

	// Automatized user paths
	global username "`c(username)'"
	
	dis "$username" // Displays your user name on your computer
	
	* Francesca
	if "$username" == "fsubioli" { 
		global dir2  "/Users/$username/Dropbox/gcwealth/handmade_tables/taxsched_input" 
	}
	if "$username" == "Francesca Subioli" | "$username" == "Francesca" | "$username" == "franc" { 
		global dir2  "C:/Users/`c(username)'/Dropbox/gcwealth/handmade_tables/taxsched_input" 
	}
	
	* Luca
	if "$username" == "lgiangregorio" {
		global dir2  "/Users/$username/Dropbox/gcwealth/handmade_tables/taxsched_input" 
	} 	

	log using "$hmade\sources_coverage.txt", text replace
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
	
	foreach source in EY_EIG_Guide EY_Personal_Tax_Guide Yale_Inheritance_Data Government_legislation Academic_research TIDData Government_research {
	   foreach country of local levels {

	  // Construct the file path
   
		if "`source'" == "EY_EIG_Guide" global name EYb_`country'
		if "`source'" == "Yale_Inheritance_Data" global name Yale_`country'		
		if "`source'" == "EY_Personal_Tax_Guide" global name EYa_`country'
		if "`source'" == "Government_legislation" global name Lex_`country'		
		if "`source'" == "Academic_research" global name Academic_`country'
		if "`source'" == "TIDData" global name TIDD_`country'
		if "`source'" == "Government_research" global name GR_`country'		
		
		local filepath "`source'/`country'"
		
		if fileexists("`filepath'/$name.xlsx") {
			
		disp "`source': `country'"
			if "`country'" != "US" qui eigt_verify `source' `country'
			else qui eigt_verify `source' `country', value(exemption) dummy(taxcredit)

		// Import data 
			local filepath "`source'/`country'"
			qui use "`filepath'/data_longformat.dta", clear
			drop subnationallevel 
			
		// Replicate for years 
			qui {
				gen expans = year_to - year_from + 1
				expand expans, gen(dupl)
				gen year = year_from
				egen group = group(GEO applies_to tax year_from year_to bracket)
				sort group year bracket dupl
				replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
				drop dupl year_* expans group
				order GEO* year appl tax 
				sort GEO* year appl tax br
				
			// Replicate for kinship
				qui split(applies_to), parse(,)
				gen expans = `r(k_new)'
				local k = `r(k_new)'
				local k = `r(k_new)'
				forvalues i = `k'(-1)1 {
					replace expans = expans - 1 if applies_to`i' == "" 
				}			
				expand expans, gen(dupl)
				sort GEO year applies_to tax bracket dupl

				egen group = group(GEO applies_to tax year)
				replace applies_to = applies_to1 if dupl == 0		
				forvalues i = 2/`k' {
					local j = `i' -1
					replace applies_to = applies_to`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies_to`i' != ""
				}	
				drop applies_to1-applies_to`k' expans dupl group
				*tempfile `source'`country'
				save "source_country_dta/`source'_`country'", replace
			}
			tab year
			}
		}
	}
	log close
	
	
	
	
	
	
	
	// Append data
	clear

	foreach source in EY_Personal_Tax_Guide {	
		foreach country of local levels {
			if fileexists("``source'`country''") qui append using "``source'`country''"
		}
	}
	
	/*
	foreach source in EY_EIG_Guide EY_Personal_Tax_Guide Government_legislation Academic_research {

		foreach country in Australia Austria ///
						   Belgium Brazil Bulgaria ///
						   Canada Chile China Cyprus Czechia ///
						   Denmark Finland France Germany Gibraltar Greece ///
						   India Indonesia Ireland Italy Japan Malta Mexico Monaco ///
						   Netherlands New_Zealand Norway ///
						   Peru Philippines Poland Portugal ///
						   Singapore Slovenia South_Korea Spain Sweden Switzerland ////
						   Thailand Turkey Ukraine United_Kingdom United_States  {
			if fileexists("``source'`country''") qui append using "``source'`country''"
		}
	}
	qui compress
	sort GEO year applies_to tax bracket

	// For Chile, if monetary variables are reported in ATU, convert to CLP
	preserve 
		keep if GEO == "CL"
		keep GEO year applies_to tax currency
		drop if currency == ""
		gen toconvert = 1 if currency == "ATU" | currency == "UTA"
		drop currency
		duplicates drop 
		tempfile tempor 
		save "`tempor'", replace
	restore
	merge m:1 GEO year applies_to tax using "`tempor'", nogen 
	preserve 
		qui import excel "$hmade/eigt_currency.xlsx", sheet("Chile") firstrow clear		
		keep year avg_UTA 
		gen GEO = "CL"
		duplicates drop
		tempfile tempor 
		save "`tempor'", replace		
	restore
	merge m:1 year GEO using "`tempor'", keep(master matched) nogen
	foreach var in adjlbo adjubo exempt toplbo {
		replace `var' = `var'*avg_UTA if toconvert == 1 & GEO == "CL" & `var' > 0 
	}
	replace currency = "CLP" if currency == "ATU" | currency == "UTA" 
	drop toconvert 
	
// Check currency is the LCU in WID 

// Prepare WID currency
	preserve 
		use "$supvars/supplementary_var_$supvarver", clear
		xfill LCU_wid
		keep country LCU_wid
		rename country GEO
		duplicates drop
		drop if LCU == "" | substr(GEO, 3, 1) != ""
		tempfile widcurren
		qui save "`widcurren'", replace
	restore 
	
// Attach WID data currencies 
	qui merge m:1 GEO using "`widcurren'" , keep(master matched) // all matched
	rename curren taxsch_curren 
	rename LCU_wid wid_currency

	egen id = group(GEO year applies_to tax)
	xtset id
	xfill taxsch_curren, i(id)
	drop id
	
// Check observations for which tax schedule currency != wid_currency	
	display "Countries for which tax schedule currency != wid_currency"
	tab GEO if _m == 3 & taxsch_curre != wid_currency & br == 0 // IT and GI
	qui gen toupdate = (_m == 3 & taxsch_curre != wid_currency) // flag those cases
	drop _m

// Attach conversion rates to those cases
	preserve 
		qui import excel "$hmade/eigt_currency.xlsx", sheet("conversion") firstrow clear
		rename curren taxsch_curren
		rename nat_currency wid_currency
		tempfile conversion
		qui save "`conversion'", replace
	restore

	preserve 
		qui keep if br == 0
		keep GEO year tax applies_to taxsch_curre wid_currency
		qui duplicates drop 
		qui merge m:1 GEO taxsch_curren wid_currency using "`conversion'" , keep(master matched)
		tempfile converted
		qui save "`converted'", replace
	restore

	qui merge m:1 GEO year tax applies_to taxsch_curre wid_currency using "`converted'", nogen
	
// Set conversion rate to 1 in case no conversion is needed 
	qui replace conv_rate = 1 if !toupdate
	
// DIVIDE the monetary variables by conv_rate to convert currency
// Not needed in this case because the only case has a 1 rate conversion

	foreach var in exempt adjlbo adjubo toplbo {
		replace `var' = `var' / conv_rate if (`var' != 0 & `var' != -999 &  `var' != -998 & `var' != -997)
	}

	drop toupdate conv_rate fixed_rate _merge taxsch_curre
	rename wid_currency curren 
	qui compress
	replace curren = "" if br != 0

// Make currency numeric 
	preserve 
		qui import excel "$hmade\eigt_currency.xlsx", sheet("codes") firstrow clear
		tempfile codes
		qui save "`codes'", replace
	restore

	qui merge m:1 curren using "`codes'" , keep(master matched)
	qui: count if _m == 1 & br == 0
	if (`r(N)' != 0) {
		display in red "`r(N)' cases of currency numeric code not found, check"
		tab GEO if _m == 1 & br == 0
		continue, break
	}		
	rename numericcode curre
	qui labmask curre, values(curren)
	drop curren _m
	rename curre curren

// Drop variable not included in v1_2
	drop homexe bssexe taxabl different_tax

// Restore the main working directory
	cd "$dir"
		
// Save
	sort GEO year tax appl br
	drop if year < firsty & firsty != .
	qui save "$intfile/eigt_countries_newdata_transformed.dta", replace
	