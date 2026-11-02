***************************
*** EIGT data: merging data
***************************

// Author: Francesca
// Last update: March 2024

// Data used: $intfile/eigt_taxsched_all_transformed.dta, $intfile/eigt_revenue_all_transformed.dta,
// Output: $intfile/eigt_all_transformed.dta,

// Content: merge tax schedule data with revenue data, check consistency

// Reshape OECD revenue data in wide form
	use "$intfile/eigt_revenue_all_transformed.dta", clear
	drop br

	replace applies_to = "_eig_tot" if applies_to == "general government" & tax == "estate, inheritance & gift"
	replace applies_to = "_ei_tot" if applies_to == "general government" & tax == "estate & inheritance"
	replace applies_to = "_g_tot" if applies_to == "general government" & tax == "gift"

	replace applies_to = "_eig_fed" if applies_to == "federal/central government" & tax == "estate, inheritance & gift"
	replace applies_to = "_ei_fed" if applies_to == "federal/central government" & tax == "estate & inheritance"
	replace applies_to = "_g_fed" if applies_to == "federal/central government" & tax == "gift"
	drop tax
	reshape wide reven prrev regdp, i(GEO year) j(applies_to) string
	foreach var in reven_ei_tot prrev_ei_tot regdp_ei_tot reven_eig_fed prrev_eig_fed regdp_eig_fed reven_eig_tot prrev_eig_tot regdp_eig_tot reven_g_tot prrev_g_tot regdp_g_tot {
		replace `var' = -999 if `var' == .
	}
	
	tempfile revenues
	save "`revenues'", replace
	
// Load tax schedule data
	use "$intfile/eigt_taxsched_all_transformed.dta", clear

// Use revenue information to infer the tax status 
	merge m:1 GEO year using "`revenues'"
	
	// save this version
	preserve
		drop _m S*
		egen n_taxes = total(statu), by(GEO year)
		gen obs = (statu == 1 & tax == "gift")
		egen gift_yes = max(obs), by(GEO year)
		drop obs
		foreach var in curre statu typet homex {
			decode `var', gen(`var'2)
			drop `var'
			rename `var'2 `var'
		}
		drop prrev_g_tot regdp_g_tot prrev_ei_tot regdp_ei_tot
		order GEO GEO_long year tax applies_to bracket n_taxes gift_yes
		save "$intfile/eigt_wide_viz_v2.dta", replace
	restore
	
	keep if _m == 2 // no tax schedule information
	drop applies_to
	reshape long reven prrev regdp, i(GEO year) j(applies_to) string
	replace tax = substr(applies_to, 2, 3)
	replace tax = "estate, inheritance & gift" if tax == "eig"
	replace tax = "estate & inheritance" if tax == "ei_"
	replace tax = "gift" if tax == "g_t"

// Infer status
	egen maxrev = max(reven), by(GEO year tax)
	replace statu = 1 if maxrev > 0 
	replace statu = 0 if maxrev == 0
	
	drop if statu == .
	drop maxrev
	drop applies_to
	duplicates drop
	gen applies_to = "unknown"
	replace applies_to = "everybody" if statu == 0 // no tax
	
	replace adjlb = 0 if statu == 0
	replace adjlb = -999 if statu == 1
	replace adjub = -997 if statu == 0 // _and_over
	replace adjub = -999 if statu == 1
	replace adjmr = 0 if statu == 0
	replace adjmr = -999 if statu == 1
	replace exemp = -998 if statu == 0 // _na
	replace exemp = -999 if statu == 1
	replace toplb = 0 if statu == 0
	replace toplb = -999 if statu == 1
	replace topra = 0 if statu == 0
	replace topra = -999 if statu == 1		
	replace homex = -998 if statu == 0
	replace homex = -999 if statu == 1		
	replace first = -999		
	
// Generate 0 bracket for bracket-invariant information 
	replace bracket = 1
	gen copy = 2 if bracket == 1
	expand copy, gen(dupl)
	drop copy
	replace bracket = 0 if dupl == 1
	drop dupl
	sort GEO year tax bracket
		
// Generate new variable type of tax
	replace typet = -999
	replace typet = -998 if statu == 0
		
	foreach var in adjlb adjub adjmr {
		replace `var' = . if bracket == 0
	}
	foreach var in curre statu typet first exemp topra toplb homex {
		replace `var' = . if bracket != 0
	}

	compress
		
	replace Source_1 = Source 
	replace taxnote = "Inferred from OECD_Rev" if Source_1 == "OECD_Rev"
	replace taxnote = "Inferred from Historical_Rev" if Source_1 == "Historical_Rev"
	
	drop Source_2 Source_3 Source_4 Source_5 Source_6 reven prrev regdp Source _merge
	foreach var in taxnote Source_1 {
		replace `var' = "" if bracket != 0
	}		
	duplicates drop

	tempfile inferred
	save "`inferred'", replace

// Attach inferred information	
	use "$intfile/eigt_taxsched_all_transformed.dta", clear
	merge m:1 GEO year tax bracket applies_to using "`inferred'", nogen

	forvalues i =1/6 {
		label var Source_`i' ""
	}

// Merge with revenue data	
	merge 1:1 GEO year tax bracket applies_to using "$intfile/eigt_revenue_all_transformed.dta", nogen
	replace Source_1 = Source if Source_1 == "" & Source != ""
	drop Source
	sort GEO year tax br applies_to
	order GEO GEO_l year tax appl br adjlb adjub adjmr curre statu typet first exemp topra toplb homex reven prrev regdp

// Export in excel
	save "$intfile/eigt_v1_transformed.dta", replace
	export excel using "$intfile/eigt_v1_transformed.xlsx", sheet(data_final, replace) firstrow(variables)
	
	