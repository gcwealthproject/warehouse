
********************************************************************************
*** OECD REVENUES
*****************

// Last update: August 2026
// Content: move the v1 released taxw data into a long format for the new structure for v2 release

********** 1. PREPARE OECD REVENUE *********************************************
/* Select the EIG revenues at different levels and tax combinations to infer the tax status if revenues are 0.  
*/ 


// Load data 
	qui use "$intfile/taxw_oecdrev_data_$oecdver_correct.dta", clear
	keep if tax == "estate, inheritance & gift" | tax == "gift"
	 
foreach var in revenu revusd prorev revgdp {
	rename `var'_sta `var'_reg
	rename `var'_cen `var'_fed
}
qui {
	format revenu* %40.0f
	
// Show cases in which general level is different from subnational levels
	drop if revenu_gen == . & revenu_fed == . & revenu_reg == . & revenu_loc == . 
	drop revusd*
	
		// Check the coherence across taxes & keep only general government level!  
			drop *_fed *_loc *_reg 
			encode tax, gen(ttax)
			drop tax 
			reshape wide *_gen, i(GEO GEO_long year) j(ttax) 
			
			// Count for all taxes (estate, inheritance, gift) and one of the other not 0
			count if revenu_gen1 == 0 & revenu_gen2 != 0 
			
			* Impute the 0 to the other tax-combinatios reporting missing information 
			foreach var in revenu prorev revgdp {
				replace `var'_gen2 = 0 if `var'_gen1 == 0 & `var'_gen2 == . 
			}
		
			reshape long 
			
			gen tax = "estate, inheritance & gift" if ttax == 1
			replace tax = "gift" if ttax == 2
			drop ttax 
	
	gen applies_to = "tg" if tax == "estate, inheritance & gift" 
	replace applies_to = "gg" if tax == "gift"
	
	rename *_gen * 
	
	sort GEO year		
	gen Source = "OECD_Rev"

	order GEO GEO_l year appl curre reven prorev revg S

// Format variables 
	format revenu %20.0f
	format prorev revgdp %5.2f
	drop if revenu == . & prorev == . & revgdp == .
	
// Define labels 
	label var curren "Currency"
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
	sort GEO year applies_to
	gen bracket = 0
	save "$intfile/taxw_revenue_all_transformed.dta", replace
}

********************************************************************************
*** taxw data: merging data
*** Infer the status by revenues, using the taxw_revenue_all_transformed and taxw_countries_newdata_transformed 
***************************

// Content: merge tax schedule data with revenue data, check consistency

	qui use "$intfile/taxw_revenue_all_transformed.dta", clear
	
// Reshape for merging with new data structure
	encode tax, gen(ttax)
	drop tax applies_to
	reshape wide revenu prorev revgdp, i(GEO GEO_long year curren) j(ttax) 

// To impute the 0 status using revenues, we can use the EIG category
	tempfile revenues
	qui save "`revenues'", replace

// Load tax schedule data

	use "$intfile/taxw_countries_newdata_transformed.dta", clear

// Use revenue information to infer the tax status 
	merge m:1 GEO year bracket using "`revenues'"
	
	keep if _m == 2 // no tax schedule information
	drop applies_to

// We impute status 0 if revenues are coherently 0 in the specific category
			
	gen status1 = . // EIG
	gen status2 = . // Gift
	gen status3 = . // EI
			
	replace status1 = 0 if revenu1 == 0
	replace status2 = 0 if revenu1 == 0 | revenu1 == 0
	replace status3 = 0 if (revenu1-revenu2) == 0 | revenu1 == 0

// Adjustments needed for schedule merge 			
	keep GEO GEO_l year status* curren
	drop status
	reshape long status, i(GEO GEO_l year curren) j(ttax)
	
	gen tax = "estate" if ttax == 1
	replace tax = "gift" if ttax == 2	
	replace tax = "inheritance" if ttax == 3
	
	drop if status == .
	gen applies_to = "everybody"
	
// Create the variables required for the merge 
	gen adjlbo = 0
	gen adjubo = -997 // _and_over
	gen adjmrt = 0 
	gen exempt = -998 // _na
	gen toplbo = 0
	gen toprat = 0 
	gen homexe = -998
	gen firsty = -999
	gen different_tax = -999
	gen bssexe = -999
	gen taxablevalue = -999 
	gen typtax = -998 
	
// Generate 0 bracket for bracket-invariant information 
	gen bracket = 1
	gen copy = 2 if bracket == 1
	expand copy, gen(dupl)
	drop copy
	replace bracket = 0 if dupl == 1
	drop dupl
	sort GEO year tax bracket
	
	foreach var in adjlbo adjubo adjmrt {
		replace `var' = . if bracket == 0
	}
	foreach var in statu first exemp topra toplb homex bssexe different_tax taxablevalue typtax {
		replace `var' = . if bracket != 0
	}
	replace curren = "" if bracket != 0
	compress
		
	gen Source = "Own estimates using OECD_Rev" 
	drop ttax 
	
	tempfile inferred
	save "`inferred'", replace
	

// Attach inferred information to the new EIG data 
	use "$intfile/taxw_countries_newdata_transformed.dta", clear
	append using "`inferred'"
	
	replace Source = "" if bracket>0 
	
	
	sort GEO GEO_l year tax applies_to bra
			
	
//-----------------	
// MERGE TAX SCHEDULE (WITH INFERRED INFO) AND REVENUE DATA 
//-----------------	
// Input: "$intfile/taxw_countries_newdata_transformed.dta" ; "$intfile/taxw_revenue_all_transformed.dta" 
// Output: "$intfile/taxw_countries_transformed"

///////////////////////////////////////////////////////////////////////////////
// Attach revenue data	
	append using "$intfile/taxw_revenue_all_transformed.dta"

	sort GEO year tax br applies_to

	replace applies_to = "general" if applies_to == "tg" | applies_to == "gg" 

	order GEO GEO_l year tax appl br adjlb adjub adjmr curre statu first typtax exemp topra toplb different_tax homex bssexe taxablevalue revenu prorev revgdp
	
	qui save "$intfile/taxw_countries_transformed.dta", replace
	
	