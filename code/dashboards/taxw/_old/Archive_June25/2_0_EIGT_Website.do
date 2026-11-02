/////////////////////////
/// Main do file for EIGT website
/////////////////////////

/// Last update: 5 November 2024
	clear 
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 1: Building country-level wide viz

	display as result "building wide vizualization for countries..."
	run "$dofile/2_1_Countries_Website.do"

////////////////////////////////////////////////////////////////////////////////
/// STEP 2: Building regional-level warehouse

	display as result "building wide vizualization for regions..."
	run "$dofile/2_2_Regions_Website.do"
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 3: Append and save with currency from supplementary_variables

	use "$intfile/eigt_countries_wide_viz.dta", clear

	append using "$intfile/eigt_USstates_wide_viz.dta"
	order GEO* year  
	sort GEO year tax br

	preserve
		use "$supvars/supplementary_var_$supvarver.dta", clear
		keep country LCU_wid
		duplicates drop
		egen pippo = group(country)
		xtset pippo
		xfill LCU_wid
		drop pippo
		duplicates drop		
		rename country GEO
		rename LCU_wid currency
		tempfile curren 
		save "`curren'", replace
	restore 
	
	merge m:1 GEO using "`curren'", keep(1 3) nogen
	replace curren = "USD" if substr(GEO, 1, 3) == "US,"
	
	// Cases not covered by WID (CHECK!) 
	replace curren = "NZD" if GEO== "TK"
	replace curren = "GBP" if GEO== "JE"
	replace curren = "GBP" if GEO== "GG"

	// Drop all gift tax information 
	drop if tax == "Gift Tax"
	
	qui export delimited using "$website/eigt_wide_viz.csv", replace nolabel

	compress

	qui save "$website/eigt_wide_viz.dta", replace




 
