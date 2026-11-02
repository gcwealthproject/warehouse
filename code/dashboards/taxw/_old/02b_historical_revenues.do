****************************
*** EIGT historical revenues
****************************

// Author: Francesca
// Last update: February 2024

// Data used: $hmade/eigt_historical_revenues.xlsx, $intfile/country_codes.dta
// Output: $intfile/eigt_histrev_data.dta, $intfile/eigt_histrev_currency.dta

// Content: take historical revenue data from the manual excel file
// and save separately the data about revenues and the currency files


// Import raw data
	import excel "$hmade/eigt_historical_revenues.xlsx", firstrow clear
	compress 
	
// Check country codes	
	qui: merge m:1 Geo using "$intfile/country_codes.dta", keep(master matched) keepusing(Geo)
	qui: count if _m == 1
	if (`r(N)' != 0) {
		display in red "`r(N)' unmatched countries"
		tab country if _m == 1
		drop _m
	}
	else {
		display "All country codes matched"
		drop _m
	} 
	
	drop geo3 Loc* Reg* 
	rename (country Geo Currency) (GEO_long GEO curren)
	rename (Tot_Rev Fed_Rev Tot_Prop_Rev Fed_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP) ///
			(revenu_gen1 revenu_fed1 prorev_gen1 prorev_fed1 revgdp_gen1 revgdp_fed1)
	rename (Tot_EI_Rev Tot_Gift_Rev) (revenu_gen2 revenu_gen3)

	reshape long revenu_gen revenu_fed prorev_gen prorev_fed revgdp_gen revgdp_fed, i(GEO year) j(tax)
	gen tax2 = "estate, inheritance & gift" if tax == 1
	replace tax2 = "estate & inheritance" if tax == 2
	replace tax2 = "gift" if tax == 3
	drop tax 
	rename tax2 tax 
	
	order GEO GEO_long year tax curren
		
// Labels 

// Package required, automatic check 
	cap which labvars
	if _rc ssc install labvars	

	labvars revenu_fed revenu_gen prorev_fed ///
	 prorev_gen revgdp_fed revgdp_gen ///
		"Tax Revenue Federal Level"  "Tax Revenue General Level" ///
		"Tax Revenue % of Total Tax Revenues, Federal Level"  "Tax Revenue % of Total Tax Revenue, General Level" ///
		"Tax Revenue % of GDP, Federal Level"  "Tax Revenue % of GDP, General Level" ///
	
	foreach var in revenu_gen revenu_fed prorev_gen prorev_fed revgdp_gen revgdp_fed {
		destring `var', replace
		sum `var'
		if (`r(N)' == 0) drop `var'
		else {
			qui: count if `var' == -999 
			if (`r(N)' == 0) replace `var' = -999 if `var' == .
			else display "There are -999 values for `var', cannot replace"
		}
	}
	drop if revenu_gen == -999
	
// Separate currency
		qui: count if curren == ""
		if (`r(N)' != 0) {
			display in red "WARNING: `r(N)' missing Currency"
			tab GEO_long if curren == ""
		}
	preserve 
		keep GEO year curren
		duplicates drop 
		save "$intfile/eigt_histrev_currency.dta", replace
	restore 		
	drop curren	
	compress
	save "$intfile/eigt_histrev_data.dta", replace

