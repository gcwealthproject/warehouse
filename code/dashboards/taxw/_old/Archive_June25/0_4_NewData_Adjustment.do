***************************
*** EIGT data: add new data 
***************************

// Last update: July 2025
// Input: excel files from various sources (handmade); eigt_currency.xlsx; raw_data/wid/supvars_wide_$supvarver.csv
// Output: data_longformat for each country and source; eigt_countries_newdata_transformed 	
	
	//---------------------------	
	// 1) Verify each source file	
	//---------------------------
	
	run "$dofile/eigt_verify.ado" // run the ado file

	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	log using "$sources/Final_Data/logfile_Finald_Data", replace
	levelsof GEO, local(levels)
    foreach country of local levels {
		if "`country'" != "US" {
			
		local filepath "$sources/Final_Data/`country'"
			
			if fileexists("`filepath'/Final_`country'.xlsx") {
			display as result "Verifying `country'..."
			if "`country'" != "US" eigt_verify Final_Data `country'
			else eigt_verify Final_Data `country', value(exemption) dummy(taxcredit)		
			}
		}
	}
	log close 
	
	//------------------------------------------
	// 2) Import and transform each complete dta	
	//------------------------------------------
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		
	// Import data 
		local filepath "$sources/Final_Data/`country'"
		if fileexists("`filepath'/data_longformat.dta") {
			display as result "Appending `country'..."
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
			sort GEO year applies_to tax bracket dupl
			egen group = group(GEO applies_to tax year)
			replace applies_to = applies_to1 if dupl == 0		
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies_to`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies_to`i' != ""
			}	
			drop applies_to1-applies_to`k' expans dupl group
			keep GEO GEO_long year applies_to tax bracket adjlbo adjubo adjmrt currency status typtax firsty exempt toprat toplbo homexe bssexe taxablevalue different_tax AggSource Legend Source Link note
			tempfile `country'
			save "``country''", replace
			}
		}
	}
	clear
    foreach country of local levels {
		if fileexists("``country''") {
			qui append using "``country''"
		}
	}
	
	qui compress
	sort GEO year tax applies_to bracket
	
	// Currency checks and conversion

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
		import delimited "$dir/raw_data/wid/supvars_wide_$supvarver.csv", clear
		egen countr = group(country)
		xtset countr year
		xfill lcu_wid
		rename lcu_wid LCU_wid
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
	tab GEO if _m == 3 & taxsch_curre != wid_currency & br == 0 // 17 countries
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
		keep GEO year tax applies_to taxsch_curre wid_currency toupdate
		qui duplicates drop 
		qui merge m:1 GEO taxsch_curren wid_currency using "`conversion'" , keep(master matched)
		qui: count if toupdate == 1 & _m == 1 
		if (`r(N)' != 0) {
			display in red "`r(N)' cases of currencies unmatched, check"
			tab GEO if toupdate == 1 & _m == 1
			tab GEO taxsch_curre if toupdate == 1 & _m == 1			
		}	
		tempfile converted
		qui save "`converted'", replace
	restore

	qui merge m:1 GEO year tax applies_to taxsch_curre wid_currency using "`converted'", nogen
	
// Set conversion rate to 1 in case no conversion is needed 
	qui replace conv_rate = 1 if !toupdate
	ereplace conv_rate = min(conv_rate), by(GEO year applies_to tax)
	
// DIVIDE the monetary variables by conv_rate to convert currency

	foreach var in exempt adjlbo adjubo toplbo {
		replace `var' = `var' / conv_rate if (`var' != 0 & `var' != -999 &  `var' != -998 & `var' != -997)
	}

	drop toupdate conv_rate fixed_rate _merge taxsch_curre avg_UTA
	rename wid_currency curren 
	qui compress
	replace curren = "" if br != 0
		
// Save
	sort GEO year tax appl br
	drop if year < firsty & firsty != . // Norway, Yale reports a tax which was actually under Danish law before independence in 1814
	qui save "$intfile/eigt_countries_newdata_transformed.dta", replace
	