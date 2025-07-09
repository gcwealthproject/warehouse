******************************************************
*** USstates tax schedule data: automated error finder
******************************************************

// Author: Francesca
// Last update: July 2025

// Data used: $intfile/USstates_final_oldstructure.dta; $hdmade/dictionary.xlsx
// Output: $intfile/eigt_USstates_taxsched_data.dta; eigt_USstates_sources.dta 

// Content: check validity and consistency of each variable in USstates_final_oldstructure.dta
// After the check, transform the variables in their final (and numeric) format

	clear all
	// Import raw data on tax schedules
	qui use "$intfile/USstates_final_oldstructure.dta", clear
	qui compress 	
	drop Curren 
	rename Note taxnote
	replace taxnote = "" if taxnote == "."
	sort GeoReg year Adjusted_Class_I_Lower_Bound
	qui: bys GeoReg year: gen n = _n

** Infer zero revenues when status == 0
	qui replace refrev = 0 if EIG_Status == "N"
	qui replace rprrev = 0 if EIG_Status == "N"
	qui replace rrvgdp = 0 if EIG_Status == "N"
	
************************* 0. General checks ************************************
// Check for duplicates

	qui: count if Geo == ""
	display "`r(N)' missing country deleted"
	qui: drop if Geo == ""

	qui: count if GeoReg == ""
	display "`r(N)' missing GeoReg_long deleted"
	qui: drop if GeoReg == ""
	
	qui: duplicates report
	local dupl = r(N) - r(unique_value)
	if (`dupl' != 0) {
		qui: duplicates tag, gen(dupl)
		display as error "`dupl' duplicates dropped, verify" 
		tab GeoReg if dupl != 0
		qui: duplicates drop 
		drop dupl
	}
	else display "No duplicates found"

// Select and rename relevant variables	
    
	keep Geo* year  EIG_Status Estate_Tax Gift_Tax ///
	Inheritance_Tax Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound ///
	Adjusted_Class_I_Statutory_Margi Source_1 Source_2 Source_3 Source_4 ///
	Source_5 Source_6 Source_7 n taxnote
	qui duplicates drop 
	rename Geo GEO
	
************************* 1. Regions codes *************************************
	preserve 
		qui qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
		rename Country GEO_long
		drop GEO3
		qui duplicates drop
		tempfile ccodes 
		save "`ccodes'", replace
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
	
************************* 2. Tax Status ****************************************
// Tax status can be Y/N/missing
// Inadmissible entries check
	foreach var in EIG_Status Estate_Tax Gift_Tax Inheritance_Tax {
		qui: replace `var' = "" if `var' == "." 
		qui: count if `var' != "Y" & `var' != "N" & `var' != ""
		if (`r(N)' != 0) {
			display "`r(N)' wrong entry in `var'"
			tab `var', miss
			tab GeoReg_long if `var' != "Y" & `var' != "N" & `var' != ""
		}
	}	

************************* 3. Adjusted lower bound ******************************	

// Can be 0, a positive number, missing

// Inadmissible entries check	
	qui: count if Adjusted_Class_I_Lower_Bound < 0 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' negative values for Adjusted_Class_I_Lower_Bound"
	}

// The first one must be 0
	qui: count if n == 1 & Adjusted_Class_I_Lower_Bound != 0 & Adjusted_Class_I_Lower_Bound != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Lower_Bound != 0 in bracket 1"
		tab GeoReg_long if n == 1 & Adjusted_Class_I_Lower_Bound != 0 & Adjusted_Class_I_Lower_Bound != .
	}	

// Incompatible entries check

// There is a schedule but there is no tax
	qui: count if Adjusted_Class_I_Lower_Bound != . & Inheritance_Tax == "" & Estate_Tax == ""
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Lower_Bound != . but missing tax"
		tab GeoReg_long if Adjusted_Class_I_Lower_Bound != . & Inheritance_Tax == "" & Estate_Tax == ""
	}	

************************* 4. Adjusted upper bound ******************************	

// Can be a positive number, missing, _and_over

// Inadmissible entries check	

	qui replace Adjusted_Class_I_Upper_Bound = -997 if Adjusted_Class_I_Upper_Bound == . & Adjusted_Class_I_Lower_Bound != . & (year != year[_n+1] | GeoReg_long != GeoReg_long[_n+1])
	qui: count if Adjusted_Class_I_Upper_Bound < 0 & Adjusted_Class_I_Upper_Bound != -997 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' negative values for Adjusted_Class_I_Upper_Bound"
	}

// The last one must be _and_over
	qui: count if (year != year[_n+1] | GeoReg_long != GeoReg_long[_n+1]) & Adjusted_Class_I_Upper_Bound != -997 & Adjusted_Class_I_Lower_Bound != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Upper_Bound != _and_over in last bracket"
		tab GeoReg_long if (year != year[_n+1] | GeoReg_long != GeoReg_long[_n+1]) & Adjusted_Class_I_Upper_Bound != -997 & Adjusted_Class_I_Lower_Bound != .
	}

// Incompatible entries check

// Missing if the lower bound is missing 
	qui: count if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Upper_Bound != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' missing lower but upper non missing"
		tab GeoReg_long if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Upper_Bound != .
	}	
	
// Non Missing if the lower bound is non missing 
	qui: count if Adjusted_Class_I_Lower_Bound != . & Adjusted_Class_I_Upper_Bound == .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' non missing lower but upper missing"
		tab GeoReg_long if Adjusted_Class_I_Lower_Bound != . & Adjusted_Class_I_Upper_Bound == .
	}
	
// Check that the lower bound of a bracket is the upper bound of the preceeding bracket 
	qui: count if GeoReg_long == GeoReg_long[_n-1] & year == year[_n-1] & round(Adjusted_Class_I_Lower_Bound) != round(Adjusted_Class_I_Upper_Bound[_n-1])
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' lower bound of a bracket is not upper bound of the preceeding one"
		tab GeoReg_long if GeoReg_long == GeoReg_long[_n-1] & year == year[_n-1] & Adjusted_Class_I_Lower_Bound != Adjusted_Class_I_Upper_Bound[_n-1]
	}
	
************************* 5. Adjusted marginal rate ****************************	

// Can be 0, a positive number, missing

// Inadmissible entries check	
	qui: count if Adjusted_Class_I_Statutory_Margi < 0 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' negative values for Adjusted_Class_I_Statutory_Margi"
	}
	qui: count if Adjusted_Class_I_Statutory_Margi > 100 & Adjusted_Class_I_Statutory_Margi < .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' values for Adjusted_Class_I_Statutory_Margi > 1"
	}

// Incompatible entries check	
	
// The first must be 0 if there is no tax
	qui: count if n == 1 & Inheritance_Tax == "N" & Estate_Tax == "N" & Adjusted_Class_I_Statutory_Margi != 0
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' no tax but marginal rate in first bracket is zero"
		tab GeoReg_long if n == 1 & Inheritance_Tax == "N" & Estate_Tax == "N" & Adjusted_Class_I_Statutory_Margi != 0
	}	

// Missing if the schedule is missing 
	qui: count if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Statutory_Margi != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' missing schedule but marginal rate non missing"
		tab GeoReg_long if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Statutory_Margi != .
	}	
	
// Non Missing if the schedule is non missing 
	qui: count if Adjusted_Class_I_Lower_Bound != . & Adjusted_Class_I_Statutory_Margi == .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' non missing schedule but marginal rate missing"
		tab GeoReg_long if Adjusted_Class_I_Lower_Bound != . & Adjusted_Class_I_Statutory_Margi == .
	}	
	
// The marginal rate cannot be decreasing 
	qui: count if n < n[_n+1] & Adjusted_Class_I_Statutory_Margi > Adjusted_Class_I_Statutory_Margi[_n+1] 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' decreasing marginal rates"
		tab GeoReg_long year if n < n[_n+1] & Adjusted_Class_I_Statutory_Margi > Adjusted_Class_I_Statutory_Margi[_n+1] 		
		tab GeoReg if n < n[_n+1] & Adjusted_Class_I_Statutory_Margi > Adjusted_Class_I_Statutory_Margi[_n+1] 
	}	

************************* 6. Adjusted exemption ******************************
qui {	
	gen adjusted_exemp =  Adjusted_Class_I_Upper_Bound if Adjusted_Class_I_Statutory_Margi == 0
	bys GeoReg year: egen adj_exemp = min(adjusted_exemp)
	replace adj_exemp = 0 if adj_exemp == .
	drop adjusted_exemp
	
************************* 7. Top Rate ****************************************

// Generate top rate as the marginal rate of the last bracket
	gen top = Adjusted_Class_I_Statutory_Margi if (GeoReg == GeoReg[_n+1] & year != year[_n+1]) | (GeoReg != GeoReg[_n+1])
	egen Top_Rate = min(top), by(GeoReg year)

************************* 8. Top Rate Lower Bound *****************************
	
	// Must be equal to the lower limit of the last bracket 
	gen lastlb = Adjusted_Class_I_Lower_Bound if (year != year[_n+1] | GeoReg_long != GeoReg_long[_n+1])
	egen Top_Rate_Class_I_Lower_Bound = min(lastlb), by(GeoReg_long year)
	drop lastlb
	format Top_Rate_Class_I_Lower_Bound %12.1f
	
************************* 13. Sources ******************************************
// Check for duplicates and save sources in a separate file
	preserve 
		keep GeoReg year Source*
		duplicates drop 
		reshape long Source_, i(Geo year) j(nsource)
		drop nsource
		duplicates drop
		drop if Source_ == ""
		drop if Source_ == "."
		sort Geo year Source_
		bys Geo year: gen n = _n
		egen id = group(Geo year)
		xtset id n
		tsfill, full
		xfill Geo year, i(id)
		reshape wide Source_, i(Geo year) j(n)
		drop id
		save "$intfile/eigt_USstates_sources.dta", replace
	restore 

*** Clean

	keep GEO* GeoReg* year EIG_Status Inheritance_Tax Estate_Tax Gift_Tax Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound Adjusted_Class_I_Statutory_Margi Top_Rate Top_Rate_Class_I_Lower_Bound n adj_exemp taxnote


*** Rename and make numeric

	gen eigsta = (EIG_Status == "Y")
	replace eigsta = -999 if EIG_Status == ""
	drop EIG_Status

	gen esttax = (Estate_Tax == "Y")
	replace esttax = -999 if Estate_Tax == ""
	drop Estate_Tax

	gen giftax = (Gift_Tax == "Y")
	replace giftax = -999 if Gift_Tax == ""
	drop Gift_Tax

	gen inhtax = (Inheritance_Tax == "Y")
	replace inhtax = -999 if Inheritance_Tax == ""
	drop Inheritance_Tax

	rename (adj_exemp Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound ///
		Adjusted_Class_I_Statutory_Margi Top_Rate ///
		Top_Rate_Class_I_Lower_Bound) ///
		(chiexe ad1lbo ad1ubo ad1smr toprat torac1)
	foreach var in ad1lbo ad1ubo ad1smr toprat torac1 chiexe {
		replace `var' = -999 if `var' == .
	} 

	rename n bracket
	order GEO* Geo* year eigsta esttax giftax inh chiexe ad1lbo ad1ubo ad1smr  toprat torac1 bracket

*** Labels 

// Package required, automatic check 
	cap which labvars
	if _rc ssc install labvars	
	
labvars year eigsta esttax giftax inhtax chiexe ///
		 ad1lbo ad1ubo ad1smr toprat  torac1 ///
		bracket "year" "EIG_Status"  "Estate_Tax" ///
		"Gift_Tax"  "Inheritance_Tax" "Child_Exemption" "Adjusted_Class_I_Lower_Bound" ///
		"Adjusted_Class_I_Upper_Bound" "Adjusted_Class_I_Statutory_Marginal_Rate" ///
		"Top_Rate"  ///
		"Top_Rate_Class_I_Lower_Bound" "n"		
		
compress
save "$intfile/eigt_USstates_taxsched_data.dta", replace
}












