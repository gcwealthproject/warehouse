**********************************
*** EIGT US states revenue cleaner
**********************************

// Author: Francesca
// Last update: July 2025

// Data used: $intfile/USstates_final_oldstructure.dta; $hdmade/dictionary.xlsx
// Output: $intfile/eigt_USstates_revenue_data.dta
 
 	clear all
// Import raw data on revenues
	qui use "$intfile/USstates_final_oldstructure.dta", clear
	qui compress 	
	
	keep Geo* year refrev rprrev rrvgdp
	qui duplicates drop
	rename Geo GEO

************************* 1. Regions codes *************************************
	preserve 
		qui qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
		rename Country GEO_long
		drop GEO3
		qui duplicates drop
		tempfile ccodes 
		qui save "`ccodes'", replace
	restore	
	qui: merge m:1 GEO using "`ccodes'", keep(master matched)
	qui: count if _m == 1
	if (`r(N)' != 0) {
		display as error "`r(N)' unmatched states"
		tab GEO if _m == 1
		drop _m
	}
	else {
		display "All country codes matched"
		drop _m
	} 

	preserve 
		qui import excel "$hmade\dictionary.xlsx", sheet("GEOReg") cellrange(A1:C1000) firstrow clear
		rename Country GEO 
		rename Region GeoReg
		rename Meaning GeoReg_long
		qui drop if GeoReg == "_na" | GeoReg == ""
		qui duplicates drop
		tempfile rcodes 
		qui save "`rcodes'", replace
	restore	
	qui: merge m:1 GeoReg using "`rcodes'", keep(master matched)
	qui: count if _m == 1
	if (`r(N)' != 0) {
		display as error "`r(N)' unmatched states"
		tab GeoReg if _m == 1
		drop _m
	}
	else {
		display "All states codes matched"
		drop _m
	} 
	order GEO GEO_long GeoReg*
	
/// Clean 
	qui gen gov = "tg"
	rename (refrev rprrev rrvgdp) (revenu prorev revgdp)
	
	qui gen tax = "estate, inheritance & gift"
 
	order GEO* Geo* year tax  revenu prorev revgdp
	
// Check ranges 
	foreach var in prorev revgdp {
		qui: sum `var'
		if (`r(max)' > 100) display "WARNING: `var' > 100"
	}
	qui replace revenu = revenu*1000
	sort GeoReg year

// Drop if all missing 
	qui replace revgdp = 0 if revenu == 0
	qui drop if revenu == . & prorev == . & revgdp == .
	
// Set to -999 the missing	
	foreach var in revenu prorev revgdp  {
		qui: count if `var' == -999 
		if (`r(N)' == 0) replace `var' = -999 if `var' == .
		else display in red "There are -999 values for `var', cannot replace"
	}	

// Labels 
// Package required, automatic check 
	cap which labvars
	if _rc ssc install labvars	

	labvars revenu prorev revgdp ///
		"Tax Revenue at Regional Level" "Tax Revenue % of Total Tax Revenues, at Regional Level" ///
		"Tax Revenue % of GDP, at Regional Level"

	qui save "$intfile/eigt_USstates_revenue_data.dta", replace




