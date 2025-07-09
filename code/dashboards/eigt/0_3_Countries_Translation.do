**************************
*** EIGT translation code
**************************


// Last update: July 2025

// Data used: $intfile/eigt_taxsched_data_correct.dta, "$intfile/eigt_taxsched_sources.dta", "$intfile/eigt_oecdrev_data_14april25_correct.dta"
// Output: $intfile/eigt_revenue_all_transformed; $intfile/eigt_taxsched_all_transformed.dta; "$intfile/eigt_countries_v1_transformed.dta"

// Content: move the v1 released eigt data into a long format for the new structure for v2 release


********************************************************************************
*** TAX SCHEDULE DATA
*********************

// Load data 
	qui use "$intfile/eigt_taxsched_data_correct.dta", clear

********** 1. TAX-INVARIANT INFORMATION *******************************************

// EIG STATUS

// The eig status and the first year are tax-independent, but we neeed to apply 
// them to a tax: we assume path-dependency
// we apply them to the first tax we observe thereafter

	qui count if eigsta != -999 & inhtax == -999 & esttax == -999 & giftax == -999 // 884
	tab GEO if eigsta != -999 & inhtax == -999 & esttax == -999 & giftax == -999 
	sort GEO year bracket		
	
// 1. Case not recoverable: we only have eigsta and/or first year, but we don't 
//	 have any tax thereafter (AG, AR, BS, CN, IQ, NZ)

// 2. Cases recoverable
qui {
	replace inhtax = 1 if GEO == "AO" & year == 1931
	replace giftax = 1 if GEO == "AO" & year == 1931
	replace esttax = 0 if GEO == "AO" & year == 1931
	
	replace inhtax = 1 if GEO == "CZ" & (year > 1991 & year < 2006)
	replace giftax = 1 if GEO == "CZ" & (year > 1991 & year < 2006)
	replace esttax = 0 if GEO == "CZ" & (year > 1991 & year < 2006)
	
	replace esttax = 1 if GEO == "DK" & (year < 2006 & eigsta == 1)
	replace inhtax = 0 if GEO == "DK" & (year < 2006 & eigsta == 1)
	
	replace inhtax = 1 if GEO == "DZ" & year == 1998
	replace giftax = 1 if GEO == "DZ" & year == 1998
	replace esttax = 0 if GEO == "DZ" & year == 1998
	
	replace inhtax = 1 if GEO == "IT" & year == 1900
	replace inhtax = 1 if GEO == "IT" & year == 1901
	
	replace inhtax = 1 if GEO == "JP" & year < 2006
	replace inhtax = 1 if GEO == "LU" & year == 2008
	replace inhtax = 1 if GEO == "MX" & year == 1842

	replace inhtax = 1 if GEO == "SE" & year > 1829 & year < 1886
	replace esttax = 1 if GEO == "SE" & year > 1829 & year < 1886

}
	qui count if eigsta != -999 & inhtax == -999 & esttax == -999 & giftax == -999 
	qui tab GEO if eigsta != -999 & inhtax == -999 & esttax == -999 & giftax == -999 
	
// FIRST YEAR 
// also for the first year, we assume that it is attributable to the tax in force in that year
// very few case though
	foreach var in inh est gif {
		qui gen first_`var' = year if (year == eigfir & `var'tax == 1)
		qui egen `var'fir = min(first_`var'), by(GEO)
		drop first_`var'
		qui replace `var'fir = -999 if `var'fir == .		
	}

qui {
	preserve 
		keep if eigsta != -999 & inhtax == -999 & esttax == -999 & giftax == -999
		keep GEO GEO_long year eigsta eigfir curren
		gen tax = "estate, inheritance & gift"
		gen bracket = 1
		rename eigsta status
		gen first_eig = year if (year == eigfir & status == 1)
		egen firsty = min(first_eig), by(GEO)
		drop first_eig
		replace firsty = -999 if firsty == .
		drop eigfir
		
		gen applies_to = "unknown"
		replace applies_to = "everybody" if status == 0 // no tax

		gen adjlbo = 0 if status == 0
		replace adjlbo = -999 if status == 1
		gen adjubo = -997 if status == 0 // _and_over
		replace adjubo = -999 if status == 1
		gen adjmrt = 0 if status == 0
		replace adjmrt = -999 if status == 1
		gen exempt = -998 if status == 0 // _na
		replace exempt = -999 if status == 1
		gen toplbo = 0 if status == 0
		replace toplbo = -999 if status == 1
		gen toprat = 0 if status == 0
		replace toprat = -999 if status == 1		
		gen homexe = -998 if status == 0
		replace homexe = -999 if status == 1		
		
		// Generate 0 bracket for bracket-invariant information 
		gen copy = 2 if bracket == 1
		expand copy, gen(dupl)
		drop copy
		replace bracket = 0 if dupl == 1
		drop dupl
		sort GEO year bracket
		
		foreach var in adjlbo adjubo adjmrt {
			replace `var' = . if bracket == 0
		}
		foreach var in curre status firsty exempt toprat toplbo homexe {
			replace `var' = . if bracket != 0
		}
		
		compress
		order GEO GEO_long year tax	applies_to bracket	adjlbo adjubo adjmrt curre status firsty exempt	toprat toplbo homexe
			
		
		compress
		tempfile eigtax
		save "`eigtax'", replace
	restore
	drop if eigsta != -999 & inhtax == -999 & esttax == -999 & giftax == -999
	drop eigsta
	drop eigfir

********** 2. TAX VARYNG INFORMATION *******************************************
	
****************
*** 2.1 Gift tax
**************** 

	preserve
		keep GEO GEO_long year giftax gtopra giffir curre 
		duplicates drop
		drop if giftax == -999
		drop if gtopra == -999 & giffir == -999		
		gen tax = "gift"
		gen bracket = 1
		rename giftax status
		rename giffir firsty 
		rename gtopra toprat
		gen applies_to = "non relatives"
		replace applies_to = "everybody" if status == 0 // no tax

		gen adjlbo = 0 if status == 0
		replace adjlbo = -999 if status == 1
		gen adjubo = -997 if status == 0 // _and_over
		replace adjubo = -999 if status == 1
		gen adjmrt = 0 if status == 0
		replace adjmrt = -999 if status == 1
		gen exempt = -998 if status == 0 // _na
		replace exempt = -999 if status == 1
		gen torac1 = 0 if status == 0 // _na
		replace torac1 = -999 if status == 1
		gen homexe = -998 if status == 0
		replace homexe = -999 if status == 1				
		rename torac1 toplbo 
		
		// Generate 0 bracket for bracket-invariant information 
		gen copy = 2 if bracket == 1
		expand copy, gen(dupl)
		drop copy
		replace bracket = 0 if dupl == 1
		drop dupl
		sort GEO year bracket

		
		foreach var in adjlbo adjubo adjmrt {
			replace `var' = . if bracket == 0
		}
		
		foreach var in adjlbo adjmrt toplbo toprat {
			replace `var' = 0 if status == 0 & bracket == 1 
		}
		
		replace adjubo = -997 if status == 0 & bracket == 1
		
		foreach var in status firsty exempt toprat toplbo curre homexe {
			replace `var' = . if bracket != 0
		}

		compress
		order GEO GEO_long year tax	applies_to bracket	adjlbo adjubo adjmrt curre status firsty exempt	toprat toplbo  homexe
					
		compress
		tempfile giftax
		save "`giftax'", replace
	restore	

***********************
*** 2.2 Inheritance tax
*********************** 

	preserve
		keep GEO GEO_long year esttax inhtax itaxre ieexem chiexe ad1lbo ad1ubo ad1smr itopra torac1 bracket estate_flag curren inhfir
		duplicates drop
		drop if inhtax == -999
		gen tax = "inheritance"
		rename inhtax status
		rename inhfir firsty 
		rename itopra toprat
		gen applies_to = "children"
		// WARNING: Class_I variable is not validated. We know for sure data on Inheritance and Estate apply to Child, while we know data for Gift apply to Everybody. Notes are not validated too.
		rename chiexe exempt 
		replace applies_to = "everybody" if status == 0 // no tax
		
		// Correct cases where the schedule refers to estate tax: no inheritance tax or  
		// with estate_flag (the schedule refers to the estate tax even if inhtax==1)
		replace exempt = -999 if (status != 1 & esttax == 1) | (estate_flag == 1 & esttax == 1)
		replace ad1lbo = -999 if (status != 1 & esttax == 1) | (estate_flag == 1 & esttax == 1)
		replace ad1ubo = -999 if (status != 1 & esttax == 1) | (estate_flag == 1 & esttax == 1)
		replace ad1smr = -999 if (status != 1 & esttax == 1) | (estate_flag == 1 & esttax == 1)
		replace torac1 = -999 if (status != 1 & esttax == 1) | (estate_flag == 1 & esttax == 1)
		drop estate_flag esttax 
		duplicates drop GEO GEO_long year status itaxre ieexem exempt ad1lbo ad1ubo ad1smr toprat torac1 curren firsty tax applies_to, force
		
		// Exploit info on ieexem
		gen taxnote = ""
		replace taxnote = "The exemption threshold applies to the overall estate as opposed to any individual recipient's share" if ieexem == 1
		drop ieexem
		
		// Exploit info on itaxre
		replace applies_to = "everybody" if itaxre == 0	
		drop itaxre
		
		rename (ad1lbo ad1ubo ad1smr torac1) ///
				(adjlbo adjubo adjmrt toplbo)	
				
		// Generate 0 bracket for bracket-invariant information 
		gen copy = 2 if bracket == 1
		expand copy, gen(dupl)
		drop copy
		replace bracket = 0 if dupl == 1
		drop dupl
		sort GEO year bracket

		// Home exemption
		gen homexe = -998 if status == 0
		replace homexe = -999 if status == 1						
				
		foreach var in adjlbo adjubo adjmrt {
			replace `var' = . if bracket == 0
		}
		
		foreach var in adjlbo adjmrt toplbo toprat {
			replace `var' = 0 if status == 0 & bracket == 1 
		}
		
		replace adjubo = -997 if status == 0 & bracket == 1
		
		foreach var in status firsty exempt toprat toplbo curre homexe {
			replace `var' = . if bracket != 0
		}
		foreach var in taxnote {
			replace `var' = "" if bracket != 0
		}
		
		compress
		order GEO GEO_long year tax	applies_to bracket	adjlbo adjubo adjmrt curre status firsty exempt	toprat toplbo  taxnote homexe

		tempfile inhtax
		save "`inhtax'", replace
	restore	

******************
*** 2.3 Estate tax
****************** 

	preserve
		keep GEO GEO_long year esttax inhtax ieexem chiexe ad1lbo ad1ubo ad1smr etopra torac1 bracket curren estfir estate_flag
		duplicates drop
		drop if esttax == -999
		gen tax = "estate"
		rename esttax status
		rename estfir firsty 
		rename etopra toprat
		rename chiexe exempt 
		gen applies_to = "children"
		replace applies_to = "everybody" if status == 0 // no tax
		
		// If only estate tax applies, ieexem indicates that the exemption 
		// varies by relationship  
		replace applies_to = "everybody" if status == 1 & inhtax == 0 & ieexem == 0
		drop ieexem
		
		// If there is an inheritance tax, the schedule refers to it
		replace exempt = -999 if inhtax == 1 & estate_flag == 0
		replace ad1lbo = -999 if inhtax == 1 & estate_flag == 0
		replace ad1ubo = -999 if inhtax == 1 & estate_flag == 0
		replace ad1smr = -999 if inhtax == 1 & estate_flag == 0
		replace torac1 = -999 if inhtax == 1 & estate_flag == 0
		drop estate_flag inhtax 
				
		rename (ad1lbo ad1ubo ad1smr torac1) ///
				(adjlbo adjubo adjmrt toplbo)	

		duplicates drop GEO GEO_long year status exempt adjlbo adjubo adjmrt toprat toplbo curre firsty tax applies_to, force
				
		// Generate 0 bracket for bracket-invariant information 
		gen copy = 2 if bracket == 1
		expand copy, gen(dupl)
		drop copy
		replace bracket = 0 if dupl == 1
		drop dupl
		sort GEO year bracket

		// Home exemption
		gen homexe = -998 if status == 0
		replace homexe = -999 if status == 1	
		
		foreach var in adjlbo adjubo adjmrt {
			replace `var' = . if bracket == 0
		}
		
		foreach var in adjlbo adjmrt toplbo toprat {
			replace `var' = 0 if status == 0 & bracket == 1 
		}
		
		replace adjubo = -997 if status == 0 & bracket == 1		
		
		foreach var in status firsty exempt toprat toplbo curre homexe {
			replace `var' = . if bracket != 0
		}
		
		compress
		order GEO GEO_long year tax	applies_to bracket adjlbo adjubo adjmrt curren status firsty exempt toprat toplbo homexe
				
		compress
		tempfile esttax
		save "`esttax'", replace
	restore	
}
********** 3. APPEND TAXES *****************************************************

	qui use "`eigtax'", clear
	qui append using "`giftax'"
	qui append using "`esttax'"
	qui append using "`inhtax'"

// Correct cases of status 0 
	qui replace exempt = -998 if status == 0
	qui replace toprat = 0 if status == 0
	qui replace toplb = 0 if status == 0
	bys GEO year tax applies_to: egen stat = min(status)
	qui replace adjlbo = 0 if stat == 0 & br == 1
	qui replace adjubo = -997 if stat == 0 & br == 1
	qui replace adjmrt = 0 if stat == 0 & br == 1
	drop stat 

	sort GEO year tax appl br 
	
// Attach source 
	qui merge m:1 GEO year using "$intfile/eigt_taxsched_sources.dta", keep(master matched)  

	qui: count if Source_1 == ""
	if (`r(N)' != 0) {
		display in red "`r(N)' Observations without sources, check"
		tab GEO_long if Source_1 == "" & br == 0
	}
	qui gen no_source = (_m == 1)
	drop _merge 
	
	forvalues i=1/6  {
		qui replace Source_`i' = "" if bracket != 0
	}

// Format variables 
	format adjlbo adjubo exempt toplbo %20.0f
	format adjmrt toprat %5.2f
		
// Define labels 
	label var curren "Currency ISO4217"
	label var applies_to "Sector"
	label var tax "Tax" 
	label var bracket "Number of bracket in tax schedule"
	label var status "Tax Indicator"
	label var firsty "First Year for Tax"
	label var exempt "Exemption Threshold"
	label var adjlbo "Lower Bound for Exemption-adjusted Tax Bracket"
	label var adjubo "Upper Bound for Exemption-adjusted Tax Bracket"
	label var adjmrt "Tax Marginal Rate for Exemption-adjusted Tax Bracket"
	label var toprat "Top Marginal Rate"
	label var toplbo "Top Marginal Rate Applicable From"
	label var homexe "Whether Family Home is Exempt"

	label define labels -999 "Missing" -998 "_na" -997 "_and_over"
	foreach var in exempt toprat toplbo adjlbo adjubo adjmrt firsty {
		label values `var' labels, nofix
	}	
	
	label define indicator 0 "No" 1 "Yes" -999 "Missing" -998 "_na"
	foreach var in status homexe {
		label values `var' indicator, nofix
	}	
	
	qui compress
		
// Save 
	sort GEO year tax br
	qui save "$intfile/eigt_taxsched_all_transformed.dta", replace
	
	
********************************************************************************
*** OECD REVENUES
*****************

// Content: move the v1 released eigt data into a long format for the new structure for v2 release

********** 1. PREPARE OECD REVENUE *********************************************

// Load data 
	qui use "$intfile/eigt_oecdrev_data_$oecdver_correct.dta", clear
	keep if tax == "estate, inheritance & gift" | tax == "estate & inheritance" | tax == "gift"
	 
foreach var in revenu revusd prorev revgdp {
	rename `var'_sta `var'_reg
	rename `var'_cen `var'_fed
}
qui {
	format revenu* %40.0f
	
// Show cases in which general level is different from subnational levels
	drop if revenu_gen == . & revenu_fed == . & revenu_reg == . & revenu_loc == . 
	drop revusd*
	
	reshape long revenu prorev revgdp, i(GEO year tax) j(applies_to) string
	replace applies_to = "tg" if applies_to == "_gen" & tax == "estate, inheritance & gift"
	replace applies_to = "tf" if applies_to == "_fed" & tax == "estate, inheritance & gift"
	replace applies_to = "tr" if applies_to == "_reg" & tax == "estate, inheritance & gift"
	replace applies_to = "tl" if applies_to == "_loc" & tax == "estate, inheritance & gift"
	replace applies_to = "sg" if applies_to == "_gen" & tax == "estate & inheritance"
	replace applies_to = "sf" if applies_to == "_fed" & tax == "estate & inheritance"
	replace applies_to = "sr" if applies_to == "_reg" & tax == "estate & inheritance"
	replace applies_to = "sl" if applies_to == "_loc" & tax == "estate & inheritance"
	replace applies_to = "gg" if applies_to == "_gen" & tax == "gift"
	replace applies_to = "gf" if applies_to == "_fed" & tax == "gift"
	replace applies_to = "gr" if applies_to == "_reg" & tax == "gift"
	replace applies_to = "gl" if applies_to == "_loc" & tax == "gift"
	
	sort GEO year		
	gen Source = "OECD_Rev"

	order GEO GEO_l year appl curre reven prorev revg S

// Format variables 
	format revenu %20.0f
	format prorev revgdp %5.2f
	drop if revenu == . & prorev == . & revgdp == .
	
// Define labels 
	label var curren "Currency ISO4217"
	label var applies_to "Sector"
	label var reven "Total Revenue from Tax"
	label var prorev "Total Revenue from Tax as % of Total Tax Revenue"
	label var revgdp "Total Revenue from Tax as % of Gross Domestic Product"

	label define labels -999 "Missing"
	foreach var in revenu prorev revgdp {
		replace `var' = -999 if `var' == .
		label values `var' labels, nofix
	}	
	
	compress
	
// Save only for the general government
	keep if substr(applies_to, 2, 1) == "g"
	sort GEO year applies_to
	gen bracket = 0
	*gen tax = "estate, inheritance & gift"
	save "$intfile/eigt_revenue_all_transformed.dta", replace
}

********************************************************************************
*** EIGT data: merging data
***************************

// Content: merge tax schedule data with revenue data, check consistency

	qui use "$intfile/eigt_revenue_all_transformed.dta", clear
	
	drop if GEO == "CU" // Imputed using the 0 tax revenue from property taxes; however, not coherent with other sources (law!)

// To impute the 0 status using revenues, we can use the EIG category
	keep if applies_to == "tg"
	rename (revenu prorev revgdp) (revenu_tg prorev_tg revgdp_tg)	
	tempfile revenues
	qui save "`revenues'", replace

// Load tax schedule data

	use "$intfile/eigt_taxsched_all_transformed.dta", clear

// Use revenue information to infer the tax status 
	merge m:1 GEO year using "`revenues'"
	
	keep if _m == 2 // no tax schedule information
	drop applies_to
	replace tax = "estate, inheritance & gift"

// Infer status (we infer only no-tax status)
	egen maxrev = max(revenu_tg), by(GEO year)
*	replace status = 1 if maxrev > 0 
	drop if maxrev > 0 
	replace status = 0 if maxrev == 0
	
	drop maxrev
	gen applies_to = "unknown"
	replace applies_to = "everybody" if status == 0 // no tax
	
	replace adjlbo = 0 if statu == 0
*	replace adjlbo = -999 if statu == 1
	replace adjubo = -997 if statu == 0 // _and_over
*	replace adjubo = -999 if statu == 1
	replace adjmrt = 0 if statu == 0
*	replace adjmrt = -999 if statu == 1
	replace exempt = -998 if statu == 0 // _na
*	replace exempt = -999 if statu == 1
	replace toplbo = 0 if statu == 0
*	replace toplbo = -999 if statu == 1
	replace toprat = 0 if statu == 0
*	replace toprat = -999 if statu == 1		
	replace homexe = -998 if statu == 0
*	replace homexe = -999 if statu == 1		
	replace firsty = -999		
	
// Generate 0 bracket for bracket-invariant information 
	replace bracket = 1
	gen copy = 2 if bracket == 1
	expand copy, gen(dupl)
	drop copy
	replace bracket = 0 if dupl == 1
	drop dupl
	sort GEO year tax bracket
	
	foreach var in adjlbo adjubo adjmrt {
		replace `var' = . if bracket == 0
	}
	foreach var in curre statu first exemp topra toplb homex {
		replace `var' = . if bracket != 0
	}
	
	compress
		
	replace Source_1 = "Own estimates using OECD_Rev" if Source == "OECD_Rev"
	
	drop Source_2 Source_3 Source_4 Source_5 Source_6 revenu* prorev* revgdp* Source _merge
	foreach var in taxnote Source_1 {
		replace `var' = "" if bracket != 0
	}		

	replace tax = "estate" if tax == "estate, inheritance & gift" 
	tempfile inferred
	save "`inferred'", replace

	replace tax = "inheritance" 
	tempfile inferred2
	save "`inferred2'", replace

	replace tax = "gift"
	tempfile inferred3
	save "`inferred3'", replace
	

// Attach inferred information	
	use "$intfile/eigt_taxsched_all_transformed.dta", clear
	append using "`inferred'"
	append using "`inferred2'"
	append using "`inferred3'"
	
	sort GEO year tax applies_to bra
			
	forvalues i =1/6 {
		label var Source_`i' ""
	}
		
////////////////////////////////////////////////
// Repeat the procedure for estate & inheritance

	preserve 

// To impute the 0 status using revenues, now use the EI category
	qui use "$intfile/eigt_revenue_all_transformed.dta", clear
	
	drop if GEO == "CU" // Imputed using the 0 tax revenue from property taxes; however, not coherent with other sources (law!)
	keep if applies_to == "sg"
	rename (revenu prorev revgdp) (revenu_sg prorev_sg revgdp_sg)	
	tempfile revenues
	qui save "`revenues'", replace

// Load tax schedule data
	restore 
	preserve 
	
// Use revenue information to infer the tax status 
	merge m:1 GEO year using "`revenues'"
	
	keep if _m == 2 // no tax schedule information
	drop applies_to
	replace tax = "estate & inheritance"

// Infer status (we infer only no-tax status)
	egen maxrev = max(revenu_sg), by(GEO year)
*	replace status = 1 if maxrev > 0 
	drop if maxrev > 0 
	replace status = 0 if maxrev == 0
	
	drop maxrev
	gen applies_to = "unknown"
	replace applies_to = "everybody" if status == 0 // no tax
	
	replace adjlbo = 0 if statu == 0
*	replace adjlbo = -999 if statu == 1
	replace adjubo = -997 if statu == 0 // _and_over
*	replace adjubo = -999 if statu == 1
	replace adjmrt = 0 if statu == 0
*	replace adjmrt = -999 if statu == 1
	replace exempt = -998 if statu == 0 // _na
*	replace exempt = -999 if statu == 1
	replace toplbo = 0 if statu == 0
*	replace toplbo = -999 if statu == 1
	replace toprat = 0 if statu == 0
*	replace toprat = -999 if statu == 1		
	replace homexe = -998 if statu == 0
*	replace homexe = -999 if statu == 1		
	replace firsty = -999		
	
	keep if status == 1 
	
// Generate 0 bracket for bracket-invariant information 
	replace bracket = 1
	gen copy = 2 if bracket == 1
	expand copy, gen(dupl)
	drop copy
	replace bracket = 0 if dupl == 1
	drop dupl
	sort GEO year tax bracket
	
	foreach var in adjlbo adjubo adjmrt {
		replace `var' = . if bracket == 0
	}
	foreach var in curre statu first exemp topra toplb homex {
		replace `var' = . if bracket != 0
	}
	
	compress
		
	replace Source_1 = "Own estimates using OECD_Rev" if Source == "OECD_Rev"
	
	drop Source_2 Source_3 Source_4 Source_5 Source_6 revenu* prorev* revgdp* Source _merge
	foreach var in taxnote Source_1 {
		replace `var' = "" if bracket != 0
	}		

	replace tax = "estate" if tax == "estate & inheritance" 
	tempfile inferred
	save "`inferred'", replace

	replace tax = "inheritance" 
	tempfile inferred2
	save "`inferred2'", replace	

// Attach inferred information	
	restore
	append using "`inferred'"
	append using "`inferred2'"
	
	sort GEO year tax applies_to bra
			
	forvalues i =1/6 {
		label var Source_`i' ""
	}
	
////////////////////////////////////
// Repeat the procedure for gift tax

	preserve 

// To impute the 0 status using revenues, now use the gift category
	qui use "$intfile/eigt_revenue_all_transformed.dta", clear
	
	drop if GEO == "CU" // Imputed using the 0 tax revenue from property taxes; however, not coherent with other sources (law!)
	keep if applies_to == "gg"
	rename (revenu prorev revgdp) (revenu_gg prorev_gg revgdp_gg)	
	tempfile revenues
	qui save "`revenues'", replace

// Load tax schedule data
	restore 
	preserve 
	
// Use revenue information to infer the tax status 
	merge m:1 GEO year using "`revenues'"
	
	keep if _m == 2 // no tax schedule information
	drop applies_to
	replace tax = "gift"

// Infer status (we infer only no-tax status)
	egen maxrev = max(revenu_gg), by(GEO year)
*	replace status = 1 if maxrev > 0 
	drop if maxrev > 0 
	replace status = 0 if maxrev == 0
	
	drop maxrev
	gen applies_to = "unknown"
	replace applies_to = "everybody" if status == 0 // no tax
	
	replace adjlbo = 0 if statu == 0
*	replace adjlbo = -999 if statu == 1
	replace adjubo = -997 if statu == 0 // _and_over
*	replace adjubo = -999 if statu == 1
	replace adjmrt = 0 if statu == 0
*	replace adjmrt = -999 if statu == 1
	replace exempt = -998 if statu == 0 // _na
*	replace exempt = -999 if statu == 1
	replace toplbo = 0 if statu == 0
*	replace toplbo = -999 if statu == 1
	replace toprat = 0 if statu == 0
*	replace toprat = -999 if statu == 1		
	replace homexe = -998 if statu == 0
*	replace homexe = -999 if statu == 1		
	replace firsty = -999		
	
	keep if status == 0 
	
// Generate 0 bracket for bracket-invariant information 
	replace bracket = 1
	gen copy = 2 if bracket == 1
	expand copy, gen(dupl)
	drop copy
	replace bracket = 0 if dupl == 1
	drop dupl
	sort GEO year tax bracket
	
	foreach var in adjlbo adjubo adjmrt {
		replace `var' = . if bracket == 0
	}
	foreach var in curre statu first exemp topra toplb homex {
		replace `var' = . if bracket != 0
	}
	
	compress
		
	replace Source_1 = "Own estimates using OECD_Rev" if Source == "OECD_Rev"
	
	drop Source_2 Source_3 Source_4 Source_5 Source_6 revenu* prorev* revgdp* Source _merge
	foreach var in taxnote Source_1 {
		replace `var' = "" if bracket != 0
	}		

	replace tax = "gift" if tax == "gift"
	tempfile inferred
	save "`inferred'", replace

// Attach inferred information	
	restore
	append using "`inferred'"
	
	sort GEO year tax applies_to bra
			
	forvalues i =1/6 {
		label var Source_`i' ""
	}
		
	
///////////////////////////////////////////////////////////////////////////////
// Attach revenue data	
	append using "$intfile/eigt_revenue_all_transformed.dta"
	replace Source_1 = Source if Source_1 == "" & Source != ""
	drop Source
	sort GEO year tax br applies_to

	drop if applies_to == "sg"
	drop if tax == "estate & inheritance"
	replace applies_to = "general" if applies_to == "tg" | applies_to == "gg" 
	
// Generate new variable type of tax
	gen typtax = -999 if applies_to != "general"
	replace typtax = -998 if status == 0
	qui egen maxbr = max(bracket), by(GEO year applies_to tax)		
	qui egen nlbo = nvals(adjlbo), by(GEO year applies_to tax)
	qui egen minnlbo = min(nlbo), by(GEO year applies_to tax)	
	replace typtax = 2 if (maxbr == 2 & status==1 & minnlbo != .) | (maxbr == 1 & exempt == 0) // Flat
	replace typtax = 3 if maxbr > 2 & nlbo == 2 & status==1  // Progressive
	replace typtax = 4 if maxbr > 2 & nlbo > 2 & status==1 & minnlbo != . // Progressive by brackets	
	drop maxbr *nlbo no_source
	replace typtax = . if bracket != 0 | applies_to == "general"

	order GEO GEO_l year tax appl br adjlb adjub adjmr curre statu first typtax exemp topra toplb homex revenu prorev revgdp
	
// 	Update taxnote for Brazil 
	replace taxnote = "Single state levies inheritance and real estate gifts" if GEO == "BR" & year<1966 & bracket == 0 & (tax == "inheritance" | tax == "gift")
	replace taxnote = "Single state levies inheritance and gift taxes, but federal top rate at 2%" if GEO == "BR" & year>=1966 & year<1988 & bracket == 0 & (tax == "inheritance" | tax == "gift")
	replace taxnote =  "Single state levies inheritance and gift taxes, but federal top rate at 8%" if GEO == "BR" & year>=1988 & bracket == 0 & (tax == "inheritance" | tax == "gift")

// Update taxnote for Bulgaria	
	replace taxnote =  "Inheritance and gift taxes are levied at municipal level in Bulgaria since 1998 (Law 117 December 10, 1997)" if GEO == "BG" & year>=1998 & bracket == 0 & (tax == "inheritance" | tax == "gift")
	
// Update taxnote for US 
	replace taxnote =  "The EGTRRA of 2001 specified that the federal rules for estate and gift taxes would have been in force until 2009. Therefore, in absence of any amendment or new laws, the tax rules expired in 2009 and no federal tax was applied in 2010" if GEO == "US" & year==2010 & bracket == 0 & (tax == "estate" | tax == "gift")	

// Update taxnote for UK
	replace taxnote = "The UK tax is called an inheritance tax, but is de facto an estate tax" if GEO == "UK" & status == 1 & bracket == 0 & (tax == "estate" | tax == "inheritance")	
	
	label var typtax "Type of Tax (1 Lump-sum, 2 Flat, 3 Progressive, 4 Progressive by brackets)"	
	label define typtax 1 "Lump-sum" 2 "Flat" 3 "Progressive" 4 "Progressive by brackets" -999 "Missing" -998 "_na"
	label values typtax typtax 
	
	sort GEO year tax appl br

	qui save "$intfile/eigt_countries_v1_transformed.dta", replace
