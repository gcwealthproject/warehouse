**************************
*** EIGT translation code
**************************

// Author: Francesca
// Last update: February 2024

// Data used: $intfile/eigt_oecdrev_data_02feb2024_correct.dta, $intfile/eigt_histrev_data_correct.dta
// Output: $intfile/eigt_taxsched_data_transformed.dta, $intfile/eigt_histrev_data_transformed.dta

// Content: move the v1 released eigt data into a long format for the new structure for v2 release


********** 1. PREPARE OECD REVENUE *********************************************

// Load data 
	use "$intfile/eigt_oecdrev_data_02feb2024_correct.dta", clear

// Checks 
	count if totrev == -999 & eitrev != -999 & gifrev != -999
	count if totrev == 0 & eitrev != -999 & eitrev != 0
	count if totrev == 0 & gifrev != -999 & gifrev != 0
	count if trvgdp == -999 & totrev != -999
	
*********************************************
*** 1.1 EIG revenue, all levels of government
*********************************************

	preserve
		keep GEO GEO_long year totrev tprrev trvgdp curre 
		duplicates drop
		drop if totrev == -999 & tprrev == -999 & trvgdp == -999
		gen tax = "estate, inheritance & gift"
		gen bracket = 0
		rename totrev reven
		rename tprrev prrev
		rename trvgdp regdp
		gen applies_to = "general government"
		rename curren curre 
		
		sort GEO year		
		compress
		order GEO GEO_long year tax	bracket	curre reven prrev regdp applies_to
				
		compress
		tempfile all
		save "`all'", replace
	restore	

**************************************************
*** 1.2 EIG revenue, Federal or central government
**************************************************

	preserve
		keep GEO GEO_long year fedrev fprrev frvgdp curre 
		duplicates drop
		drop if fedrev == -999 & fprrev == -999 & frvgdp == -999
		gen tax = "estate, inheritance & gift"
		gen bracket = 0
		rename fedrev reven
		rename fprrev prrev 
		rename frvgdp regdp
		gen applies_to = "federal/central government"
		rename curren curre 
		
		sort GEO year		
		compress
		order GEO GEO_long year tax	bracket	curre reven prrev regdp applies_to
				
		compress
		tempfile fed
		save "`fed'", replace
	restore	

********************************************
*** 1.3 EI revenue, all levels of government
********************************************

	preserve
		keep GEO GEO_long year eitrev curre 
		duplicates drop
		drop if eitrev == -999
		gen tax = "estate & inheritance"
		gen bracket = 0
		rename eitrev reven
		gen applies_to = "general government"
		rename curren curre 
		
		sort GEO year		
		compress
		order GEO GEO_long year tax bracket	curre reven applies_to
				
		compress
		tempfile ei
		save "`ei'", replace
	restore	

**********************************************
*** 1.4 Gift revenue, all levels of government
**********************************************

	preserve
		keep GEO GEO_long year gifrev curre 
		duplicates drop
		drop if gifrev == -999
		gen tax = "gift" 
		gen bracket = 0
		rename gifrev reven
		gen applies_to = "general government"
		rename curren curre 
		
		sort GEO year		
		compress
		order GEO GEO_long year tax	bracket	curre reven applies_to
				
		compress
		tempfile gift
		save "`gift'", replace
	restore	

********** 2. PREPARE HISTORICAL REVENUE ***************************************

// Load data 
	use "$intfile/eigt_histrev_data_correct.dta", clear
	
*********************************************
*** 2.1 EIG revenue, all levels of government
*********************************************

	preserve
		keep GEO GEO_long year hist_totrev curre 
		duplicates drop
		drop if hist_totrev == -999 
		gen tax = "estate, inheritance & gift"
		gen bracket = 0
		rename hist_totrev reven
		gen applies_to = "general government"
		rename curren curre 
		
		sort GEO year		
		compress
		order GEO GEO_long year tax	bracket	curre reven applies_to
				
		compress
		tempfile allh
		save "`allh'", replace
	restore	

	
********************************************
*** 2.2 EI revenue, all levels of government
********************************************

	preserve
		keep GEO GEO_long year hist_eitrev curre 
		duplicates drop
		drop if hist_eitrev == -999
		gen tax = "estate & inheritance" // Inheritance, Estate
		gen bracket = 0
		rename hist_eitrev reven
		gen applies_to = "general government"
		rename curren curre 
		
		sort GEO year		
		compress
		order GEO GEO_long year tax	bracket	curre reven applies_to
				
		compress
		tempfile eih
		save "`eih'", replace
	restore	

********** 2. APPEND REVENUE ***************************************************

	use "`all'", clear
	append using "`fed'"
	append using "`ei'"
	append using "`gift'"
	gen Source = "OECD_Rev"
	append using "`allh'"
	append using "`eih'"
	replace Source = "Historical_Rev"

	replace prrev = -999 if prrev == .
	replace regdp = -999 if regdp == .

	order GEO GEO_l year tax appl

// Format variables 
	format reven %20.0f
	format prrev regdp %5.2f
		
// Define labels 
	label var curre "Currency ISO4217"
	label var applies_to "Sector"
	label var tax "Tax" 
	label var reven "Total Revenue from Tax"
	label var prrev "Total Revenue from Tax as % of Total Tax Revenue"
	label var regdp "Total Revenue from Tax as % of Gross Domestic Product"

	label define labels -999 "Missing"
	foreach var in reven prrev regdp {
		label values `var' labels, nofix
	}	
	
	compress
	
// Save 
	sort GEO year tax applies_to
	save "$intfile/eigt_revenue_all_transformed.dta", replace
