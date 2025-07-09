***********************************
*** EIGT US states translation code
***********************************

// Author: Francesca
// Last update: July 2025

// Data used: $intfile/eigt_USstates_taxsched_data.dta; $intfile/eigt_USstates_sources; eigt_USstates_revenue_data
// Output: $intfile/eigt_USstates_taxsched_data_transformed.dta; $intfile/eigt_USstates_revenue_transformed; /// 
// 		   $intfile/eigt_USstates_v1_transformed 

// Load data 
	qui use "$intfile/eigt_USstates_taxsched_data.dta", clear
	compress
********************************************************************************
*** TAX SCHEDULE
****************
	
********** 1. TAX-INVARIANT INFORMATION *******************************************
	qui count if eigsta == 1 & esttax != 1 & inhtax != 1 & giftax != 1 // no cases, can drop eigsta
	drop eigsta

********** 2. TAX VARYNG INFORMATION *******************************************

// Specify the tax information is estate in case esttax == 1, inheritance otherwise 

	rename esttax status_e 
	rename inhtax status_i
	rename giftax status_g
	
	foreach var in chiexe ad1lbo ad1ubo ad1smr toprat torac1 {
		gen `var'_e = .
		replace `var'_e = `var' if status_e == 1 | (status_e == 0 & status_i == 0) // either estate in the state or no EI tax in the state but estate federal tax
		gen `var'_i = .
		replace `var'_i = `var' if status_i == 1 & status_e != 1
	}

	gen taxnote_e = ""
	replace taxnote_e = taxnote if status_e == 1 | (status_e == 0 & status_i == 0)
	gen taxnote_i = ""
	replace taxnote_i = taxnote if status_i == 1 & status_e != 1

	drop chiexe ad1lbo ad1ubo ad1smr toprat torac1 taxnote

	reshape long status_@ chiexe_@ ad1lbo_@ ad1ubo_@ ad1smr_@ toprat_@ torac1_@ taxnote_@, string i(GEO GEO_long GeoReg GeoReg_long year bracket) j(tax)
	
	rename *_ *
	gen applies_to = "children"
	replace applies_to = "everybody" if status == 0 
	replace tax = "estate" if tax == "e"
	replace tax = "inheritance" if tax == "i"
	replace tax = "gift" if tax == "g"

	rename chiexe exempt
								
	rename (ad1lbo ad1ubo ad1smr torac1) ///
			(adjlbo adjubo adjmrt toplbo)	
	
	// Generate 0 bracket for bracket-invariant information 
	gen copy = 2 if bracket == 1
	expand copy, gen(dupl)
	drop copy
	replace bracket = 0 if dupl == 1
	drop dupl
	sort GeoReg year bracket
	
	foreach var in adjlbo adjubo adjmrt {
		replace `var' = . if bracket == 0
	}
	foreach var in status  exempt toprat  toplbo {
		replace `var' = . if bracket != 0
	}
		
	drop if adjlbo == . & adjubo == . & adjmrt == . & status == .

	compress
	order GeoReg GeoReg_long  year tax	applies_to bracket adjlbo adjubo adjmrt  status  exempt toprat toplbo 
	sort GeoReg year tax applies_to bracket

// Attach source 
	qui merge m:1 GeoReg year using "$intfile/eigt_USstates_sources.dta", keep(master matched)
	qui: count if _m != 3
	if (`r(N)' != 0) {
		display in red "`r(N)' Unmatched sources, check"
		tab GeoReg_long if _m != 3 & br == 0
	}

	drop _m
	qui: count if Source_1 == ""
	if (`r(N)' != 0) {
		display in red "`r(N)' Observations without sources, check"
		tab GeoReg_long if Source_1 == "" & br == 0
	}

	forvalues i=1/5  {
		qui replace Source_`i' = "" if bracket != 0
	}

// Format variables 
	format adjlbo adjubo exempt toplbo %20.0f
	format adjmrt toprat %5.2f
		
// Define labels 
	qui gen curren = 840 // USD
	
	label var curren "Currency ISO4217"
	label var applies_to "Sector"
	label var tax "Tax" 
	label var bracket "Number of bracket in tax schedule"
	label var status "Tax Indicator"
	label var exempt "Exemption Threshold"
	label var adjlbo "Lower Bound for Exemption-adjusted Tax Bracket"
	label var adjubo "Upper Bound for Exemption-adjusted Tax Bracket"
	label var adjmrt "Tax Marginal Rate for Exemption-adjusted Tax Bracket"
	label var toprat "Top Marginal Rate"
	label var toplbo "Top Marginal Rate Applicable From"

	label define labels -999 "Missing" -998 "_na" -997 "_and_over"
	foreach var in exempt toprat toplbo adjlbo adjubo adjmrt {
		label values `var' labels, nofix
	}	
	
	label define indicator 0 "No" 1 "Yes" -999 "Missing" -998 "_na"
	foreach var in status  {
		label values `var' indicator, nofix
	}	
		
	qui compress
	
// Save 
	sort GeoReg year tax br
	qui save "$intfile/eigt_USstates_taxsched_transformed.dta", replace
	
	
	
	
********************************************************************************
*** REVENUES
************

// Load data 
	use "$intfile/eigt_USstates_revenue_data.dta", clear
			
   drop tax
	gen applies_to = "general"
	sort GeoReg year		
	order GeoReg  year appl reven prorev revg
	drop gov 
	
// Format variables 
	format revenu %20.0f
	format prorev revgdp %5.2f
		
// Define labels 
	label var applies_to "Sector"
	label var reven "Total Revenue from Tax"
	label var prorev "Total Revenue from Tax as % of Total Tax Revenue"
	label var revgdp "Total Revenue from Tax as % of Gross Domestic Product"

	label define labels -999 "Missing"
	foreach var in revenu prorev revgdp {
		label values `var' labels, nofix
	}	
	
	compress
	
// Save 
	sort GeoReg year applies_to
	gen bracket = 0
	gen tax = "estate, inheritance & gift"
	
// Attach source 
	merge m:1 GeoReg year using "$intfile/eigt_USstates_sources.dta", keep(master matched)
	qui: count if _m != 3
	if (`r(N)' != 0) {
		display in red "`r(N)' Unmatched sources, check"
		tab GeoReg if _m != 3 & br == 0
	}

	drop _m
	qui: count if Source_1 == ""
	if (`r(N)' != 0) {
		display in red "`r(N)' Observations without sources, check"
		tab GeoReg if Source_1 == "" & br == 0
	}
	gen curren = 840
	
	save "$intfile/eigt_USstates_revenue_transformed.dta", replace

********************************************************************************
*** EIGT data: append data
***************************

// Load tax schedule data
	qui use "$intfile/eigt_USstates_taxsched_transformed.dta", clear
	
	forvalues i =1/5 {
		label var Source_`i' ""
	}

// Attach revenue data	
	qui append using "$intfile/eigt_USstates_revenue_transformed.dta"
	sort GeoReg year tax br applies_to
	order GEO* GeoReg* year tax appl br adjlb adjub adjmr curre statu exemp topra toplb revenu prorev revgdp

// Generate new variable type of tax
	gen typtax = -999 if applies_to != "general"
	replace typtax = -998 if status == 0
	qui egen maxbr = max(bracket), by(GeoReg year applies_to tax)		
	qui egen nlbo = nvals(adjlbo), by(GeoReg year applies_to tax)
	qui egen minnlbo = min(nlbo), by(GeoReg year applies_to tax)	
	replace typtax = 2 if maxbr == 2 & minnlbo != . // Flat 
	replace typtax = 3 if maxbr > 2 & nlbo == 2 // Progressive
	replace typtax = 4 if maxbr > 2 & nlbo > 2 & minnlbo != . // Progressive by brackets	
	drop maxbr *nlbo 
	replace typtax = . if bracket != 0 | applies_to == "general"

	order GEO GEO_long GeoReg GeoReg_long year tax applies_to bracket adjlbo adjubo adjmrt curren status typtax 
	
	gen note2 =  "The EGTRRA of 2001 specified that the federal rules for estate and gift taxes would have been in force until 2009. Therefore, in absence of any amendment or new laws, the tax rules expired in 2009 and no federal tax was applied in 2010." if GEO == "US" & year==2010 & bracket == 0 & (tax == "estate" | tax == "gift")	& applies_to != "general"
	gen note3 = "The exemption and the other tax schedule data are a combination of state and federal taxes."  if bracket == 0 & applies_to != "general"
	replace taxnote = "" if bracket != 0 | applies_to == "general"
	replace taxnote = taxnote + " " + note3 + " " + note2
	replace taxnote = trim(taxnote)
	drop note2 note3
	
	label var typtax "Type of Tax (1 Lump-sum, 2 Flat, 3 Progressive, 4 Progressive by brackets)"	
	label define typtax 1 "Lump-sum" 2 "Flat" 3 "Progressive" 4 "Progressive by brackets" -999 "Missing" -998 "_na"
	label values typtax typtax 
	
	sort GeoReg year tax appl br
	save "$intfile/eigt_USstates_v1_transformed.dta", replace
	
