********************************
*** EIGT revenue data downloader
********************************

global oecd_ver 22mar2024

display "OECD Revenue download, version $oecd_ver"

// Author: Twisha and Francesca
// Last update: March 2024

	clear
	
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
	if "$username" == "fsubioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	if "$username" == "Francesca Subioli" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	* Luca 
	if "$username" == "lgiangregorio"  { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}
	
	global dofile "$dir\code\dashboards\eigt"
	global intfile "$dir\raw_data\eigt\intermediary_files"
	global hmade "$dir\handmade_tables"
	global supvars "$dir\output\databases\supplementary_variables"
	
// Content: take OECD Revenue data from the web
// and save separately the data about revenues and the currency files

**** 4000 (Property tax Revenues) **********
**** 4110 (household recurrent taxes on immovable property Revenues) **********
**** 4210 (individual recurrent taxes on net wealth Revenues) **********
**** 4300 (EIG Revenues) **********
**** 4310 (EI Revenues) **********
**** 4320 (G Revenues) **********
 
// Package required, automatic check 
	cap which sdmxuse
	if _rc ssc install sdmxuse	
	
	foreach group in members nonmembers {

		if ("`group'" == "members") sdmxuse data OECD, dataset(REV) dimensions(.4000+4110+4210+4300+4310+4320.) attributes clear
		else sdmxuse data OECD, dataset(RS_GBL) dimensions(..4000+4110+4210+4300+4310+4320.) attributes clear
		compress
			
		/// Clean 
		destring time, replace
		drop if cou=="OAVG"  | cou == "AVG_FEDERAL" | cou == "AVG_UNITARY"
		if ("`group'" == "nonmembers") drop if cou == "ASIAP" | cou == "AFRIC" | cou == "419"

		drop if gov == "SOCSEC" | gov == "SUPRA"
		keep if var!="TAXUSD"

		************************* Adjust powercode/units **************************

		destring powercode,replace

			* Step 1: Find all the unique values of powercode
			levelsof powercode, local(values)

			* Step 2: Loop over these values and perform an arithmetic operation
			foreach p of local values {
				 replace value = value*(10^`p') if powercode==`p'
			}

		drop time_format powercode	

		************************* Reshape  ****************************************

		replace var = "revenu" if var == "TAXNAT"
		replace var = "prorev" if var == "TAXPER"
		replace var = "revgdp" if var == "TAXGDP"
		
		replace gov = "fed" if gov == "FED"
		replace gov = "loc" if gov == "LOCAL"
		replace gov = "gen" if gov == "NES"
		replace gov = "reg" if gov == "STATE"

		// Replace currency with national currency for reshaping	
		replace unit = "" if unit == "PC"
		egen id = group(cou)
		xfill unit, i(id)
		drop id

		gen group = var + "_" + gov
		drop gov var
		reshape wide value, i(cou time tax) j(group) string

		replace tax = "property & net wealth" if tax == "4000"
		replace tax = "immovable property" if tax == "4110" // households, recurrent
		replace tax = "net wealth" if tax == "4210" // individual, recurrent
		
		replace tax = "estate, inheritance & gift" if tax == "4300"
		replace tax = "estate & inheritance" if tax == "4310"
		replace tax = "gift" if tax == "4320"
		
		
		rename value* *
		tempfile `group'
		save "``group''", replace					
	}
		
// If a country is both in "members" and "non-members", use the first as prevalent
	use "`nonmembers'", clear
	cap drop _m
	merge 1:1 tax cou time using "`members'", update replace 

	drop _m
	rename cou GEO3
	
// Attach 2-digit country codes and country names 

	preserve 
		qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
		rename Country GEO_long
		duplicates drop
		tempfile ccodes 
		save "`ccodes'", replace
	restore	
	qui: merge m:1 GEO3 using "`ccodes'", keep(master matched)
	qui: count if _m == 1
	if (`r(N)' != 0) {
		display in red "`r(N)' unmatched countries in dictionary, dropped"
		tab GEO3 if _m == 1
		drop if _m == 1
		drop _m
	}
	else {
		display "All country codes matched in dictionary"
		drop _m
	} 
	drop GEO3

	rename (unit time) (curren year)
	order GEO GEO_long year tax curren revenu* prorev* revgdp*
	
// Check ranges 
	ds prorev* revgdp*
		foreach var in `r(varlist)' {
			qui: sum `var'
			if (`r(max)' > 100) display "WARNING: `var' > 100"
		}

// Impute missing info 
	encode tax, gen(tax2)
	tab tax2
	tab tax2, nol
	drop tax
	reshape wide revenu* prorev* revgdp*, i(GEO year) j(tax2)

	foreach sec in fed loc reg gen {
		replace revenu_`sec'3 = 0 if round(revenu_`sec'2) == round(revenu_`sec'1) & revenu_`sec'1 != . & revenu_`sec'3 == .
		replace revenu_`sec'1 = 0 if round(revenu_`sec'2) == round(revenu_`sec'3) & revenu_`sec'3 != . & revenu_`sec'1 == .
		replace revenu_`sec'1 = revenu_`sec'2 if revenu_`sec'3 == 0 & revenu_`sec'2 != .
		replace revenu_`sec'3 = revenu_`sec'2 if revenu_`sec'1 == 0 & revenu_`sec'2 != .
		replace revenu_`sec'2 = 0 if revenu_`sec'1 == 0 & revenu_`sec'3 == 0	
		replace revenu_`sec'1 = 0 if revenu_`sec'6 == 0 & revenu_`sec'1 == .
		replace revenu_`sec'2 = 0 if revenu_`sec'6 == 0 & revenu_`sec'2 == .
		replace revenu_`sec'3 = 0 if revenu_`sec'6 == 0 & revenu_`sec'3 == .
		replace revenu_`sec'4 = 0 if revenu_`sec'6 == 0 & revenu_`sec'4 == .
		replace revenu_`sec'5 = 0 if revenu_`sec'6 == 0 & revenu_`sec'5 == .
	}

	reshape long revenu_fed revenu_loc revenu_reg revenu_gen prorev_fed prorev_loc ///
		prorev_reg prorev_gen revgdp_fed revgdp_loc revgdp_reg revgdp_gen, i(GEO year) j(tax)
	decode tax, gen(t)
	drop tax 
	rename t tax

	order GEO GEO_long year tax curren revenu* prorev* revgdp*
		
	sort GEO year tax

// Drop if all missing 
	drop if revenu_fed == . & revenu_loc == . & revenu_reg == . & revenu_gen == . ///
			& prorev_fed == . & prorev_loc == . & prorev_reg == . & prorev_gen == . ///
			& revgdp_fed  == . & revgdp_loc  == . & revgdp_reg  == . & revgdp_gen == . 
			
// Set to zero federal, regional and local if general is missing 
	foreach var in revenu prorev revgdp {
		foreach lev in fed reg loc {
			replace `var'_`lev' = 0 if `var'_gen == 0 & `var'_`lev' == .
		}
	}
	
// Set to -999 the missing	
	ds revenu* prorev* revgdp* 
	foreach var in `r(varlist)' {
		qui: count if `var' == -999 
		if (`r(N)' == 0) replace `var' = -999 if `var' == .
		else display in red "There are -999 values for `var', cannot replace"
	}	

// Labels 

// Package required, automatic check 
	cap which labvars
	if _rc ssc install labvars	

	labvars revenu_fed revenu_loc revenu_reg revenu_gen prorev_fed prorev_loc ///
		prorev_reg prorev_gen revgdp_fed revgdp_loc revgdp_reg revgdp_gen ///
		"Tax Revenue Federal Level" "Tax Revenue Local Level" "Tax Revenue Regional Level" "Tax Revenue General Level" ///
		"Tax Revenue % of Total Tax Revenues, Federal Level" "Tax Revenue % of Total Tax Revenue, Local Level" ///
		"Tax Revenue % of Total Tax Revenue, Regional Level" "Tax Revenue % of Total Tax Revenue, General Level" ///
		"Tax Revenue % of GDP, Federal Level" "Tax Revenue % of GDP, Local Level" ///
		"Tax Revenue % of GDP, Regional Level" "Tax Revenue % of GDP, General Level" ///

// Separate currency
	qui: count if curren == ""
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' missing Currency"
		tab GEO_long if curren == ""
	}
	preserve 
		keep GEO year curren
		duplicates drop 
		save "$intfile/eigt_oecdrev_currency_$oecd_ver.dta", replace
	restore 		
	drop curren
	save "$intfile/eigt_oecdrev_data_$oecd_ver.dta", replace




