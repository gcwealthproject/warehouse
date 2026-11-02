********************************************************************************
*** EIG data: automated error finder
********************************************************************************
*** 1. Currency conversion
*** 2. revenue update and check
*** 3. EIG status errors
*** 4. zero top rate errors
*** 5. revenue errors
*** 6. Inconsistent sources

// Last update: September 2023
// rows 128-133 and 217'220 to be removed when currency in suppl vars is updated

// Input: handmade_tables/eigt_transcribed.xlsx
//		  handmade_tables/national_currencies_2023.xlsx
//        handmade_tables/currency_conversion.xlsx
//        output/databases/supplementary_var.xlsx
//        ${intfile}/OECDrev_data.dta

// Output: raw_data/eigt/intermediary_files/eigt_fixed_errs.dta

// Run this before if there has been a new release of OECD revenue data.
// It generates OECDrev_data.dta
	*run "$db\gcwealth\code\dashboards\eigt\secondary\OECD_Pulls\01_OECD_revdata.do" 
	
*qui {
	clear all
	global intfile raw_data/eigt/intermediary_files

			
*IF NEEDED:
*run "code/mainstream/auxiliar/all_paths.do"
	
	
**** USE OLD ONE FOR NOW BCS REVENUE DELETED IN NEW ONE	
	import excel "handmade_tables/old/eigt_transcribed copy.xlsx", firstrow  clear
	compress 
			
	drop if country == "" // need to solve this directly in excel
	duplicates drop 
			
	save "raw_data/eigt/intermediary_files/eigt_transcribed.dta", replace

	gen N = _n
			
*** 0. 09'23 LAUNCH
		
* fill up missing child exemption information if written into adjusted exemption class 1
	replace Child_Exemption = Adjusted_Exemption if (Child_Exemption == "." | Child_Exemption == "_na" | Child_Exemption == "") & (Adjusted_Exemption != "." & Adjusted_Exemption != "_na" & Adjusted_Exemption != "" & Adjusted_Exemption != "_and_over")
		
	replace Child_Exemption = "." if Child_Exemption == "_and_over"
		
*drop Adjusted_Exemption
		
* code inheritance relation based information into a dummy indicator
	replace Inheritance_Tax_Relation_Based = "Y" if Inheritance_Tax_Relation_Based == "B" | Inheritance_Tax_Relation_Based == "E"
		
************************ 1. Fixing Top Rate Lower Bound *******************
	
	// Valid upper bound values
	gen valid_ad1ubo = 1 if Adjusted_Class_I_Upper_Bound != "." & ///
							Adjusted_Class_I_Upper_Bound != "_and_over" & ///
							Adjusted_Class_I_Upper_Bound != "_na" & ///
							Adjusted_Class_I_Upper_Bound != "" 
		
		sort Geo GeoReg year N
		
		// Highest bracket among valid upper bound values
		by Geo GeoReg year: egen max_valid_ad1ubo_bracket = max(N) if /// 
															valid_ad1ubo==1
															
		// Get adjusted upper bound for highest valid bracket
		by Geo GeoReg year: gen top_rate_lower_bound =  ///
									Adjusted_Class_I_Upper_Bound if ///
									max_valid_ad1ubo_bracket == N
			// Check
			*distinct top_rate_lower_bound Geo GeoReg year, joint
									
		// Apply derived value to all observations within group
		by Geo GeoReg year: egen topratc1adlb = mode(top_rate_lower_bound)
		
			// Do the same process for statutory upper bound to check validity
				/*
				gen valid_staubo = 1 if Statutory_Class_I_Upper_Bound != "." & ///
								Statutory_Class_I_Upper_Bound != "_and_over" & ///
								Statutory_Class_I_Upper_Bound != "_na" & ///
								Statutory_Class_I_Upper_Bound != "" 
				sort Geo GeoReg year N
				by Geo GeoReg year: egen max_valid_staubo_bracket = max(N) if /// 
																valid_staubo==1
				by Geo GeoReg year: gen sta_top_rate_lower_bound =  ///
											Statutory_Class_I_Upper_Bound if ///
											max_valid_staubo_bracket == N
				by Geo GeoReg year: egen topratc1stlb = ///
								mode(sta_top_rate_lower_bound)
				*/
			
			// Check for outright errors
				/*
				tab Geo year if topratc1adlb != Top_Rate_Class_I_Lower_Bound & ///
							topratc1stlb != Top_Rate_Class_I_Lower_Bound & ///
							max_valid_ad1ubo_bracket == N & ///
							Top_Rate_Class_I_Lower_Bound !="." & GeoReg=="_n"
				*/
			
	// Replace with fixed values
	replace Top_Rate_Class_I_Lower_Bound = topratc1adlb if  ///
			Top_Rate_Class_I_Lower_Bound != topratc1adlb & ///
			topratc1adlb!=""

		drop valid_ad1ubo-topratc1adlb
		
************************ 2. CURRENCY CONVERSION *******************************	
	
///////////////////////////////////////////////////////////////////////////////
// List monetary variables for which the currency check is needed
	global montax Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound ///
			Child_Exemption Top_Rate_Class_I_Lower_Bound 
	global revdata Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev 
	global revpopdata Tot_Prop_Rev Fed_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP 
///////////////////////////////////////////////////////////////////////////////
	
	count if Currency == "." // 21
	
/// Check whether the currency in eigt_transcribed is the current national one
	preserve 
		import excel "handmade_tables/currencies/national_currencies_2023.xlsx", firstrow clear
		keep geo3 nat_
		tempfile currenc
		save "`currenc'", replace
	restore
		
	merge m:1 geo3 using "`currenc'", keep(master matched) nogen
	sort country year n
	count if Currency != nat_currency & Currency != "." // 4442 cases
	tab country if Currency != nat_currency & Currency != "."

/// Check whether the currency in transcribed is either the current one or recorded in currency_conversion.xlsx for the conversion
	
	preserve 
		import excel "handmade_tables/currencies/currency_conversion.xlsx", firstrow clear
		tempfile currenc
		save "`currenc'", replace
	restore
		
	merge m:1 geo3 Currency using "`currenc'", keep(master matched) 	
	replace Currency = "MRU" if Geo == "MR" // MRO wrong name
	replace Currency = "XAF" if Geo == "GQ" // XOF wrong because it's in Center Africa, but equivalent
	count if _m == 1 & Currency != nat_currency & Currency != "." 
					// is != 0, need to add 
					// the country manually to currency_conversion.xlsx
					// tab country if _m == 1 & Currency != nat_currency & Currency != "."
*}
	display "There are `r(N)' cases in which we did not find a correspondance in currency_conversion.xlsx (line 96)"

*qui {
/// Correct using currency_conversion if needed
		
	preserve 
		import excel "handmade_tables/currencies/currency_conversion.xlsx", firstrow clear
		tempfile currenc
		save "`currenc'", replace
	restore
		
	merge m:1 geo3 Currency using "`currenc'", keep(master matched) nogen 
// 15 countries with historical currencies (fixed_rate = 1)
// Cases in which the market exchange rate is needed: Uzbekistan, Chile,
// and Zimbabwe (fixed_rate = 0)

	replace conv_rate = 1 if conv_rate == . & fixed_rate != 0 // right currency, no need to convert
	preserve
		import excel "output\databases\supplementary_variables\supplementary_var_28sep2023.xlsx", firstrow clear
		keep country year xlcusx // WID: Market exchange rate with USD
		rename country Geo
		tempfile convert
		save "`convert'", replace
	restore
	merge m:1 Geo year using "`convert'", keep(master match) nogen
	replace conv_rate = xlcusx if Geo == "ZW" & Currency == "ZWL" // ZWL -> USD
	replace conv_rate = 1/xlcusx if Geo == "CL" & Currency == "USD" // USD -> CLP
	replace conv_rate = 1/xlcusx if Geo == "UZ" & Currency == "USD" // USD -> UZS
	count if conv_rate == . // Chile 2023
	
	replace conv_rate = 1 if Geo == "HR" // to be removed once supplementary_var is updated
	replace nat_currency = "HRK" if Geo == "HR" // to be removed once supplementary_var is updated	
	replace nat_currency = "VEF" if Geo == "VE" // to be removed once supplementary_var is updated
	replace conv_rate = 1 if Geo == "VE" & Currency == "VEF" // to be removed once supplementary_var is updated
	replace conv_rate = 1000 if Geo == "VE" & Currency == "VEB" // to be removed once supplementary_var is updated
	replace conv_rate = 1/100000 if Geo == "VE" & Currency == "VES" // to be removed once supplementary_var is updated

*}
	display "There are `r(N)' cases in which we did not find a proper conversion rate (line 137)"

*qui {	
// DIVIDE the monetary variables by conv_rate to get the right currency

// Make manual revenue data numeric and correct the currency 
	foreach var of global revdata {
		destring `var', replace force // force to make "_na" missing
		replace `var' = `var' / conv_rate // correct currency
	}
// Make manual proportional revenue data numeric 
	foreach var of global revpopdata {
		destring `var', replace force // force to make "_na" missing
	}
	
// tax schedule variables are strings: move to numbers preserving info on _na, 
// then correct the currency and go back to string
	
	foreach var of global montax {
		// go to numeric
		count if `var' == "1"
		if (`r(N)' != 0) {
			display "Cannot use 1 for _na"
			continue, break
		}
		replace `var' = "1" if `var' == "_na" 
		count if `var' == "11"
		if (`r(N)' != 0) {
			display "Cannot use 11 for _and_over"
			continue, break
		}
		replace `var' = "11" if `var' == "_and_over"
		count if `var' == "111"
		if (`r(N)' != 0) {
			display "Cannot use 111 for missing"
			continue, break
		}
		replace `var' = "111" if `var' == "."
		destring `var', replace 
		replace `var' = `var' / conv_rate if (`var' != 1 &  `var' != 11 & `var' != 111) // correct currency ######### MANUEL ADDED if `var' != XXX 3.10.23
		// back to string
		tostring `var', replace force // preserve the decimals ######### FRANCESCA MODIFIED THE FORMAT 4.10.23
		replace `var' = "_na" if `var' == "1" 
		replace `var' = "_and_over" if `var' == "11"
		replace `var' = "." if `var' == "111"
	}

	replace Currency = nat_currency if Currency != nat_currency & Currency != "."
	drop xlcusx nat_currency fixed_rate conv_rate _m
	compress
	
	
	
*************************** 3. REVENUE UPDATE AND CHECK ************************	
	
	merge m:1 geo3 year using "${intfile}/OECDrev_data_17oct2023.dta", update replace	///
			 keepusing( $revdata $revpopdata )
	drop if _m==2
	
/*// Round and format revenue data
	foreach var in Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev {
		replace `var' = round(`var', 1)
	}
	foreach var in Tot_Prop_Rev Fed_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP {
		replace `var' = round(`var', 0.001)
	}*/
	format Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev %20.0f
	format Tot_Prop_Rev Fed_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP %9.3f
		
// Add the source 
	cap drop x
	gen x = (Source_1 == "OECD_Rev" | Source_2 == "OECD_Rev" ///
			| Source_3 == "OECD_Rev" | Source_4 == "OECD_Rev" | ///
			Source_5 == "OECD_Rev" | Source_6 == "OECD_Rev" | ///
			Source_7 == "OECD_Rev")
	forvalues i = 1/7 {
		replace Source_`i' = "." if Source_`i' == ""
		count if _m != 1 & x == 0
		if (`r(N)' == 0) continue, break
		replace Source_`i' = "OECD_Rev" if Source_`i' == "." & _m != 1
		replace x = 1 if Source_`i' == "OECD_Rev"
	}
	drop x _m
	
	foreach var of global revdata {
		replace `var' = `var' * 7.5345 if Geo == "HR" // to be removed once supplementary_var is updated, this is moving Croatia back to the currency before Euros
		replace `var' = `var' * 100000 if Geo == "VE" // to be removed once supplementary_var is updated, this is moving Venezuela back to the currency before VES
	}
	
	*** check if total revenue is same as previous year	
		gen err_rev_1 = 1 if Tot_Rev==Tot_Rev[_n-1] & Geo==Geo[_n-1] & ///
			year!=year[_n-1] & GeoReg==GeoReg[_n-1] & Tot_Rev!=. & ///
			Tot_Rev!=0 & Tot_Rev!= 1

	*** check if revenue proportion is same as previous year
		gen err_rev_2 = 1 if Tot_Prop_Rev==Tot_Prop_Rev[_n-1] & Geo==Geo[_n-1] ///
			& year!=year[_n-1] & GeoReg==GeoReg[_n-1] & Tot_Prop_Rev!=. & ///
			Tot_Prop_Rev!=0 & Tot_Prop_Rev!= 1

	*** check if revenue information is positive although tax info says there is no eig tax
		gen err_rev_3  = 1 if EIG_Status == "N" & (Tot_EI_Rev != 0 | ///
			Tot_Gift_Rev != 0) & (Tot_EI_Rev != . | Tot_Gift_Rev != .) ///
			& (Tot_EI_Rev != 1 | Tot_Gift_Rev != 1) & GeoReg == "_na"
		
			*** additionally check third category error: flag if revenue is not decreasing over time (e.g. Canada after 2008)
			gen err_rev_3a = 1 if err_rev_3 == 1 & (Tot_EI_Rev > Tot_EI_Rev[_n+1] ///
				| Tot_Gift_Rev > Tot_Gift_Rev[_n+1])
			
			*** note: all err_rev_3 data manually checked is ok --> except Slovakia 2007, 2019
	

	* browse all revenue errors
	*br geo3 Tot_Rev Tot_Prop_Rev year GeoReg err_* if err_rev_1 ==1 | ///
	*	err_rev_2 == 1 | err_rev_3 == 1
	* browse same revenue as previous year error only
	*br geo3 Tot_Rev year err_rev_1 if err_rev_1 ==1 
	

*************************** 4. EIG STATUS. ERRORS ****************************
 
	*** Flag if first eig is incorrectly entered: ### in this case replace  
	// First_EIG = "_na" if First_EIG == . & feig_flag == 1 /// 
	//basically flagging those where we dont know when first year, 
	//bcs missing in those cases, but _na if we know its in previous year somewhere
	
		gen feig_flag=1 if EIG_Status=="N" & First_EIG!="_na"

		
	*** Flag if first eig status is incorrectly entered --> only affecting US states
		
		gen eigsta_flag = .
		replace eigsta_flag=1 if (Estate_Tax=="Y"| Gift_Tax=="Y"| ///
									Inheritance_Tax=="Y") & (EIG_Status=="."| ///
																EIG_Status=="N")
	*** correct if eig status is incorrectly entered 															
		replace EIG_Status="Y" if Estate_Tax=="Y"| Gift_Tax=="Y"| Inheritance_Tax=="Y"
		replace EIG_Status="N" if Estate_Tax=="N" & Gift_Tax=="N" & Inheritance_Tax=="N"
												
														
		replace EIG_Status="Y" if Estate_Tax=="Y"| Gift_Tax=="Y"| Inheritance_Tax=="Y"
		replace EIG_Status="N" if Estate_Tax=="N" & Gift_Tax=="N" & Inheritance_Tax=="N"
		replace EIG_Status = "Y" if EIG_Status=="Y "

	
*************************** 5. ZERO TOP RATE ERRORS	 **************************
		
// Flag zero toprate without previous data
		
// Flag leading zeroes without previous data		
	cap drop zero_flag
	gen zero_flag = .

	levelsof geo3, local(Geolist) // country list

	save "raw_data/eigt/intermediary_files/eigt_transcribed.dta", replace
					
// Replace top rate with 0 if no EIG
	local tr Top_Rate Estate_Top_Rate Inheritance_Top_Rate Gift_Top_Rate
			
	foreach var in `tr' {
		replace `var' = "0" if (`var'=="" |`var'=="_na"| ///
					`var'==".") & (EIG_Status=="N") 
	}
			
		
*************************** 6. REVENUE TO ZERO FOR EIG="N" COUNTRIES **********	
											
	foreach var of global revdata {
		replace `var' = 0 if EIG_Status=="N" & `var' == .
	}
	foreach var of global revpopdata {
		replace `var' = 0 if EIG_Status=="N" & `var' == .
	}

*************************** 7. SOURCE INCONSISTENCIES ************************
		
	sort Geo GeoReg year N
	cap drop source_flag
	gen source_flag = 0
	forvalues sn = 1/7{
		replace source_flag = 1 if Geo == Geo[_n-1] & GeoReg == GeoReg[_n-1] & ///
						year == year[_n-1] & Source_`sn'!= Source_`sn'[_n-1]
	}
	

	
// Only keep identifying info and error flags
	preserve
	
		keep country Geo geo3 GeoReg year N err_rev_1 err_rev_2 err_rev_3 ///
			err_rev_3a zero_flag feig_flag eigsta_flag 

		
		save "raw_data/eigt/intermediary_files/EIG_errors.dta", replace
		
	restore
	
		
// Reset file to original for cleaning
	drop n
	drop err_rev_1-source_flag

	save "raw_data/eigt/intermediary_files/eigt_fixed_errs.dta", replace 
*}		
			
