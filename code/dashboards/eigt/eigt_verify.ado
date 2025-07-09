**************************************************************
*** Tax schedule data: input verification file background code
**************************************************************

// Author: Francesca
// Last update: July 2025
// Aim: take the content of the Data sheet in the Excel of each source and 
		// 1) check the validity and the consistency of the data
		// 2) Fill the missing information when possible
		// 3) Save data in .dta format
		
cap program drop eigt_verify
	program eigt_verify, nclass 
		version 16
		syntax anything(name=arguments), ///
		[VALUEcr(string) DUMMYcr(string)]

        tokenize `arguments'
        local source `1'
        local country `2'
		
		
		clear all
		cap log close
		if "`source'" != "Final_Data" qui log using "$sources/`source'/`country'/verification_logfile.txt", text replace
		else qui log using "$sources/`source'/`country'/verification_logfile.txt", text replace
		display ""
		display ""

		display "Stata version required: at least 16"
		
	// Display the received arguments for verification
		display "Source: `source'" 
		display "Country: `country'" 
		display ""
	
	// Check if the arguments are received correctly
		if "`source'" == "" {
			display as error "Error: Source argument is missing."
			exit 198
		}

		if "`country'" == "" {
			display as error "Error: Country argument is missing."
			exit 198
		}
	
	// valuecr() can be empty, "exemption" or a positive number
		if "`valuecr'" == "" display as result "Tax credit: none"
		else {
			if "`dummycr'" == "" {
				display as error "Credit indicator variable not found, specify option dummycr()"
				exit
			}
			if "`valuecr'" == "exemption" display as result "Tax credit for selected tax and group: exemption column"
			else {
				display as result "Tax credit for selected tax and group: `valuecr'"
				if `valuecr' < 0 {
					display as error "Negative tax credit not allowed"
					exit 198
				}
			}			
		}
		
	 // Construct the file path
		if "`source'" == "EY_EIG_Guide" global name EYb_`country'
		if "`source'" == "TIDData" global name TIDD_`country'				
		if "`source'" == "EY_Personal_Tax_Guide" global name EYa_`country'
		if "`source'" == "Government_legislation" global name Lex_`country'
		if "`source'" == "Academic_research" global name Academic_`country'
		if "`source'" == "Government_research" global name GR_`country'
		if "`source'" == "Cross_national_corporate_research" global name CorpRes_`country'		
		if "`source'" == "Cross_national_academic_research" global name CNRes_`country'
		if "`source'" == "Final_Data" global name Final_`country'		
		
		if "`source'" != "Final_Data" local filepath "$sources/`source'/`country'/$name.xlsx"
		else local filepath "$sources/`source'/`country'/$name.xlsx"
		display as result "Loaded file: `filepath'"

		qui import excel "`filepath'", sheet(Data) allstring firstrow
		
	// Remove the regional information i.e. keep subnational == 0 	
		qui count if subnationallevel != "0" & subnationallevel != "1"
		if `r(N)' != 0 {
			disp as error "WARNING: `r(N)' subnational level missing"
		}
		qui count if subnationallevel == "1"
		if `r(N)' != 0 {
			disp as error "WARNING: `r(N)' subnational observations deleted"
			qui keep if subnationallevel == "0" 	
		}
		
	// Remove lead and last blank spaces 
		qui ds 
		foreach var in `r(varlist)' {
			qui replace `var' = strtrim(`var')
		}
	
	// Set the _and_over to -997 and _na to -998 
		qui replace exemption = "-997" if exemption == "_and_over"
		qui replace exemption = "-998" if exemption == "_na"
		
	// Set current year	
		global current_year = substr(c(current_date), -4, 4)


	////////////////////////////
	////// VALIDITY CHECKS /////
	////////////////////////////
	display "1. Validity checks..."

	// Missing mandatory variables
	
		local general GEO GEO_long currency // Mandatory general information
		local taxn year_from year_to subnationallevel status // Mandatory numeric tax-related information
		local taxs tax applies_to // Mandatory string tax-related information
		local sourceinfo AggSource Legend Source Link // Mandatory source-related information
		
		foreach var of local general {
			qui count if `var' == ""
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' missing `var'"
				exit 198
			}
		} 
		foreach var of local taxn {
			qui destring `var', replace
			qui count if `var' == .
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' missing `var'"	
				exit 198
			}
		} 
		foreach var of local taxs {
			qui count if `var' == ""
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' missing `var'"	
				exit 198
			}
		} 	
		foreach var of local sourceinfo {
			if (`var' == "") {
				display as error "ERROR: Missing `var'"
				exit 198
			}
		} 

		
		qui count if trim(marginalrates) == "" & schedulelowerbounds != ""
		if `r(N)' != 0 {
			display as error "ERROR: missing marginal rates with full tax schedule"
			tab year_from year_to if trim(marginalrates) == "" & schedulelowerbounds != ""
			exit 198 
		} 
		
		
	// Duplicates 	
	
		qui duplicates report
		local dupl = r(N) - r(unique_value)
		if (`dupl' != 0) {
			qui: duplicates tag, gen(dupl)
			display as error "ERROR: `dupl' duplicated observations" 
			tab year_from year_to if dupl != 0
			drop dupl
			exit 198
		}

	//////////////////////////////////////////////	
	// Inadmissible entries in mandatory variables
	//////////////////////////////////////////////
	 display "2. Inadmissible entries in mandatory variables..."
		
		// Unmatched GEO or GEO_longdisplay "Missing mandatory variables..."
			preserve 
				qui import excel "$hmade/dictionary.xlsx", sheet("GEO") firstrow cellrange(A1:B500) clear 
				drop if Country == ""
				rename Country GEO_long
				qui replace GEO_long = strtrim(GEO_long)
				qui drop if GEO == ""
				tempfile names 
				qui save "`names'", replace
			restore 
			qui merge m:1 GEO_long GEO using "`names'", keep(master matched) 
			qui count if _m == 1
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' unmatched country codes or naming"
				tab GEO_long GEO if _m == 1
				exit 198
			}
			qui drop _m

		// Unmatched currency 
			preserve 
				qui import excel "$hmade/eigt_currency.xlsx", sheet("LCU2023") firstrow clear
				drop GEO_long
				rename nat_currency currency
				qui drop if GEO == ""
				tempfile curren 
				qui save "`curren'", replace
			restore 
			qui merge m:1 GEO currency using "`curren'", keep(master matched) 
			qui count if _m == 1
			if (`r(N)' != 0) {
				display as error "WARNING: `r(N)' unmatched currency codes. Historical currency?"
				tab currency GEO if _m == 1
			}	
			qui drop _m
			
		// Errors in year_from, year_to
			qui count if year_from > year_to
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' cases of year_from > year_to"
				tab year_from year_to if year_from > year_to
				exit 198
			}
			qui count if year_from > $current_year | year_to > $current_year
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' years in the future"
				tab year_from year_to if year_from > $current_year | year_to > $current_year
				exit 198
			}
			qui count if year_from < 1600 | year_to < 1600
			if (`r(N)' != 0) {
				display as error "WARNING: `r(N)' years < 1600, check"
				tab year_from year_to if year_from < 1600 | year_to < 1600
				exit 198
			}
			
		// Errors in tax
			qui count if tax != "inheritance" & tax != "estate" & tax != "gift" ///
						 & tax != "net wealth" & tax != "immovable property"
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' inadmissible entries for tax"
				tab tax if tax != "inheritance" & tax != "estate" & tax != "gift" ///
							  & tax != "net wealth" & tax != "immovable property"
				exit 198
			}
			
		// Errors in applies_to
			qui split(applies_to), parse(,)
						
			forvalues i = 1/`r(nvars)' {
					qui replace applies_to`i' = strtrim(applies_to`i')
					qui count if applies_to`i' != "children" & applies_to`i' != "spouse" & ///
								 applies_to`i' != "siblings" & applies_to`i' != "other relatives" & ///
								 applies_to`i' != "non relatives" & applies_to`i' != "everybody" & ///
								 applies_to`i' != "net financial wealth" & applies_to`i' != "net total wealth" & ///
								 applies_to`i' != "real estate" & ///
								 applies_to`i' != "unknown" & applies_to`i' != ""
					if (`r(N)' != 0) {
						display as error "ERROR: `r(N)' inadmissible entries for applies_to"
						tab applies_to`i' if applies_to`i' != "children" & applies_to`i' != "spouse" & ///
								 applies_to`i' != "siblings" & applies_to`i' != "other relatives" & ///
								 applies_to`i' != "non relatives" & applies_to`i' != "everybody" & ///
								 applies_to`i' != "net financial wealth" & applies_to`i' != "net total wealth" & ///
								 applies_to`i' != "real estate" & ///
								 applies_to`i' != "unknown" & applies_to`i' != ""
								 exit 198
					}
				cap drop applies_to`i'
			}		

		// Errors in status
			qui count if status != 0 & status != 1
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' inadmissible entries for status"
				tab status if status != 0 & status != 1
				exit 198
			}
		
		// Errors in subnational level
			qui count if subnationallevel != 0 & subnationallevel != 1
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' inadmissible entries for subnational level"
				tab subnationallevel if subnationallevel != 0 & subnationallevel != 1
				cexit 198
			}
			
		qui destring different_tax, replace
		// Errors in different_tax
			qui count if status == 1 & different_tax != 0 & different_tax != 1
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' inadmissible entries for different_tax"
				tab different_tax if status == 1 & different_tax != 0 & different_tax != 1
				exit 198
			}		
			qui count if status == 0 & different_tax != 0 & different_tax != 1 & different_tax != .
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' inadmissible entries for different_tax"
				tab different_tax if status == 0 & different_tax != 0 & different_tax != 1 & different_tax != .
				exit 198
			}	
			
	/////////////////////////////////////////////	
	// Inadmissible entries in optional variables
	/////////////////////////////////////////////	
	display "3. Inadmissible entries in optional variables..."

		qui destring typetax firstyear exemption toprate toplowerbound fhome_exemp fbusiness_exemp taxablevalue, replace

		// Errors in firstyear
			qui count if firstyear > $current_year & firstyear < .
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' years in the future"
				tab firstyear if firstyear > $current_year & firstyear < .
				exit 198
			}
			qui count if firstyear < 1600
			if (`r(N)' != 0) {
				display as error "WARNING: `r(N)' firstyear < 1600, check"
				tab firstyear if firstyear < 1600
			}
			
		// Errors in exemption
			qui count if exemption < 0 & exemption != -997 & exemption != -998 
			if (`r(N)' != 0) {
				display as error "WARNING: `r(N)' negative exemption"
				tab exemption if exemption < 0 
				exit 198
			}	

		// Errors in family home exempt
			qui count if fhome_exemp != 0 & fhome_exemp != 1 & fhome_exemp != .
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' inadmissible entries for fhome_exemp"
				tab fhome_exemp if fhome_exemp != 0 & fhome_exemp != 1 & fhome_exemp != .
				exit 198
			}
			
		// Errors in family business exempt
			qui count if fbusiness_exemp != 0 & fbusiness_exemp != 1 & fbusiness_exemp != .
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' inadmissible entries for fbusiness_exemp"
				tab fbusiness_exemp if fbusiness_exemp != 0 & fbusiness_exemp != 1 & fbusiness_exemp != .
				exit 198
			}		
		
		// Errors in taxable value
			qui count if taxablevalue != 1 & taxablevalue != 2 & taxablevalue != 3 & taxablevalue != .
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' inadmissible entries for taxablevalue"
				tab taxablevalue if taxablevalue != 1 & taxablevalue != 2 & taxablevalue != 3 & taxablevalue != .
				exit 198
			}	
		
		// Errors in the tax credit indicator
		if "`valuecr'" != "" {
			destring `dummycr', replace
			if (`dummycr' != 0 & `dummycr' != 1 & `dummycr' != .) {
				display as error "ERROR: `r(N)' inadmissible entries for `dummycr'"
				qui tab `dummycr' if `dummycr' != 0 & `dummycr' != 1 & `dummycr' != .
				exit 198
			}
		}
		
	/////////////////////////////////////////////	
	// Automatic fill if no tax or full exemption 
	/////////////////////////////////////////////
	display "Automatic fill if no tax or full exemption..."

		// Not applicable (-998)
		local na typetax exemption toprate toplowerbound fhome_exemp fbusiness_exemp taxablevalue
		
		foreach var of local na {
			qui replace `var' = -998 if status == 0
		} 
		qui replace typetax = -998 if exemption == -997
		
		// Tax brackets
		qui replace schedulelowerbounds = "0" if status == 0 | exemption == -997
		qui replace scheduleupperbounds = "-997" if status == 0 | exemption == -997
		qui replace marginalrates = "0" if status == 0 | exemption == -997
		qui replace toprate = 0 if status == 0 | exemption == -997
		qui replace toplowerbound = 0 if status == 0 | exemption == -997
					
		// Errors in lower bounds
		
		qui count if schedulelowerbounds != "" & marginalrates != "0" & marginalrates != ""
		if (`r(N)' != 0) { 
			
			qui split(schedulelowerbounds), parse(,)
						
			local nlb = `r(nvars)'
			forvalues i = 1/`nlb' {
				qui replace schedulelowerbounds`i' = strtrim(schedulelowerbounds`i')
				qui destring schedulelowerbounds`i', replace 
				recast double schedulelowerbounds`i'
				format schedulelowerbounds`i' %50.0f			
			
		// Check if the destring was successful 
				qui sum schedulelowerbounds`i' 
				if `r(N)' == 0 {
					disp as error "ERROR: all schedulelowerbounds`i' missing or string"
					tab schedulelowerbounds`i'
					qui sum schedulelowerbounds`i' if schedulelowerbounds`i' != . 
					* If type mismatch is because schedulelowerbounds`i' is a string! i.e., destring in line 319 not successful
					exit 198
				}
			}		
				
		// Check if first lower bound is different from 0	
				qui replace schedulelowerbounds1 = 0 if schedulelowerbounds1 == 1		
				qui count if schedulelowerbounds1 != 0 & schedulelowerbounds1 != .
				if (`r(N)' != 0) {
					display as error "ERROR: `r(N)' cases of first lower bound not 0"
					tab schedulelowerbounds1 if schedulelowerbounds1 != 0 & schedulelowerbounds1 != .
					exit 198
				}			
				
				forvalues i = 1/`nlb' {
					qui count if schedulelowerbounds`i' < 0
					if (`r(N)' != 0) {
						display as error "ERROR: `r(N)' negative schedule lower bounds"
						tab schedulelowerbounds`i' if schedulelowerbounds`i' < 0
						exit 198
					}	
				}
				
			forvalues i = 1/`nlb' {
				local j = `i' + 1
				if (`i' != `nlb') {
					qui count if schedulelowerbounds`i' >= schedulelowerbounds`j' &  schedulelowerbounds`i' != . & typetax != 3
					if (`r(N)' != 0) {
						display as error "WARNING: schedule lower bounds <= of the preceding one"
						tab schedulelowerbounds`i' if schedulelowerbounds`i' >= schedulelowerbounds`j' &  schedulelowerbounds`i' != . & typetax != 3
					}							
				}
				qui count if schedulelowerbounds`i' != 0 & schedulelowerbounds`i' != . & typetax == 3
					if (`r(N)' != 0) {
						display as error "WARNING: non-zero lower bounds but typetax == 3"
						tab schedulelowerbounds`i' if schedulelowerbounds`i' != 0 & schedulelowerbounds`i' != . & typetax == 3
				}
			}
		drop schedulelowerbounds
		}	
		else {
			rename schedulelowerbounds schedulelowerbounds1
			qui destring schedulelowerbounds1, replace
		}	
		
		// Errors in upper bounds
			qui count if scheduleupperbounds != "" & scheduleupperbounds != "-997"
			if (`r(N)' != 0) { 
				
				qui split(scheduleupperbounds), parse(,)
				
				local nub = `r(nvars)'
				forvalues i = 1/`nub' {
					qui replace scheduleupperbounds`i' = strtrim(scheduleupperbounds`i')				
					qui replace scheduleupperbounds`i' = "-997" if scheduleupperbounds`i' == "_and_over"
					qui destring scheduleupperbounds`i', replace
					recast double scheduleupperbounds`i'
					format scheduleupperbounds`i' %50.0f
				
				// Check if the destring was successful 
					qui sum scheduleupperbounds`i' 
					if `r(N)' == 0 {
						disp as error "WARNING: all scheduleupperbounds`i' missing or string"
						tab scheduleupperbounds`i'
						qui sum scheduleupperbounds`i' if scheduleupperbounds`i' != . 
						* If type mismatch is because scheduleupperbounds`i' is a string! i.e., destring in line 354 not successful
					}				
				qui count if scheduleupperbounds`i' < 0 & scheduleupperbounds`i' != -997 
				if (`r(N)' != 0) {				
					display as error "ERROR: `r(N)' negative schedule upper bounds"
					tab scheduleupperbounds`i' if scheduleupperbounds`i' < 0 & scheduleupperbounds`i' != -997
					exit 198
				}
				}

				forvalues i = 1/`nub' {		
					local j = `i' + 1
					if (`i' != `nub') {
						qui count if scheduleupperbounds`i' >= scheduleupperbounds`j' & scheduleupperbounds`j' != -997  & scheduleupperbounds`i' != .
						if (`r(N)' != 0) {
							display as error "WARNING: schedule upper bounds <= of the preceding one"
							tab scheduleupperbounds`i' if scheduleupperbounds`i' >= scheduleupperbounds`j' & scheduleupperbounds`j' != -997 /// 
							& scheduleupperbounds`i' != .
						}											
					}
				}
				drop scheduleupperbounds
			}	
			else {
				rename scheduleupperbounds scheduleupperbounds1
				qui destring scheduleupperbounds1, replace
			}
			
		// Errors in marginal rates
			qui count if marginalrates != "" & marginalrates != "0"
			if (`r(N)' != 0) { 
		
				qui split(marginalrates), parse(,)
				
				local nmr = `r(nvars)'
				forvalues i = 1/`nmr' {
					local j = `i'+1
					qui replace marginalrates`i' = strtrim(marginalrates`i')
					if (`i' != `nmr') qui replace marginalrates`i' = "-99" if marginalrates`i' == "." & marginalrates`j' != ""
					qui destring marginalrates`i', replace
				
					qui replace marginalrates`i' = . if marginalrates`i' == -99
				
				// Check if the destring was successful 
					qui sum marginalrates`i' 
					if `r(N)' == 0 {
						disp as error "WARNING: all marginalrates`i' missing or string"
						tab marginalrates`i'
						qui sum marginalrates`i' if marginalrates`i' != . 
						* If type mismatch is because marginalrates`i' is a string! i.e., destring in line 389 not successful
					}
					qui count if marginalrates`i' < 0 
					if (`r(N)' != 0) {
						display as error "ERROR: `r(N)' negative marginal rate"
						tab marginalrates`i' if marginalrates`i' < 0 
						exit 198
					}
					qui count if marginalrates`i' > 100 & marginalrates`i' < . 			
					if (`r(N)' != 0) {
						display as error "ERROR: `r(N)' marginal rate > 100"
						tab marginalrates`i' if marginalrates`i' > 100 & marginalrates`i' < . 	
						exit 198
					}
				}
			forvalues i = 1/`nmr' {				
				local j = `i' + 1
				if (`i' != `nmr') {
					qui count if marginalrates`i' > marginalrates`j' & ( marginalrates`i' != . )
					if (`r(N)' != 0) {
						display as error "WARNING: marginal rate < of the preceding one"
						tab marginalrates`i' if marginalrates`i' > marginalrates`j' & ( marginalrates`i' != . )
					}					
				}
			}  
			
			forvalues i = 1/`nmr' {				
				local j = `i' + 1
				if (`i' != `nmr') {
					qui count if marginalrates`i' == marginalrates`j' & ( marginalrates`i' != . )
					if (`r(N)' != 0) {
						display as error "WARNING: marginal rate = to the preceding one, the brackets will be unified"
						tab marginalrates`i' if marginalrates`i' == marginalrates`j' & ( marginalrates`i' != . )
					}					
				}
			}						
			drop marginalrates
			}
			else {
				rename marginalrates marginalrates1
				qui destring marginalrates1, replace
			}		
			
		// Check that lower bounds, upper bounds and marginal rates have the same 
		// number of entries
		qui count if marginalrates1 != . & marginalrates1 != 0
		if (`r(N)' != 0) { 		
			if (`nlb' != `nub') | (`nlb' != `nmr') | (`nub' != `nmr') {
				display as error "ERROR: n. lower bound != n. upper bounds != n. marginal rates"
				exit 198
			}
		}

		/*
		// Set the lowest lower bound to zero if it coincides with the exemption and the first marginal rate is positive
			qui replace schedulelowerbounds1 = 0 if schedulelowerbounds1 != . & ///
			            (schedulelowerbounds1 == exemption | schedulelowerbounds1 == (exemption + 1)) ///
						& marginalrates1 != 0 & marginalrates1 != .
	    */
	/////////////////////////////////////////	
	// Automatic fill if schedule is reported 
	/////////////////////////////////////////	
	display "Automatic fill if schedule is reported..."

		// Set the exemption to zero if it is a tax credit
			if "`valuecr'" == "exemption" {
				display as error "Tax credit applied to:"
				tab applies_to if `dummycr' == 1
				tab tax if `dummycr' == 1
				tab year_from year_to if `dummycr' == 1
				qui gen credit = exemption if `dummycr' == 1
				qui replace exemption = 0 if `dummycr' == 1
			}
		
		qui count if marginalrates1 != . & marginalrates1 != 0
		if (`r(N)' != 0) {
			
			// Correct the exemption if the first bracket includes it 
			qui replace exemption = exemption + scheduleupperbounds1 if status == 1 & exemption != . & exemption != -997 & schedulelowerbounds1 <= 1 & marginalrates1 == 0
			 
			 gen flag = (status == 1 & exemption != . & exemption != -997 & schedulelowerbounds1 <= 1 & marginalrates1 == 0)		
			
			// Address the schedules for special exemption cases (flag == 1, e.g., Philippines 2017) 
			forvalues i = `nlb'(-1)2 {
				qui replace scheduleupperbounds`i'= scheduleupperbounds`i' + (exemption) if flag == 1 & scheduleupperbounds`i' > 0
			} 			 
			forvalues i = `nlb'(-1)3 {
				qui replace schedulelowerbounds`i'= schedulelowerbounds`i' + (exemption) if flag == 1  
			}
			capture confirm variable schedulelowerbounds2, exact
			if !_rc {
				qui replace schedulelowerbounds2= schedulelowerbounds2 + (exemption - scheduleupperbounds1) if flag == 1  
			}
			qui replace scheduleupperbounds1= scheduleupperbounds1 + (exemption - scheduleupperbounds1) if flag == 1 & scheduleupperbounds1 > 0
					 
			// Lower bounds
			qui replace schedulelowerbounds1 = . if status == 1 & exemption != . & exemption != -997 & schedulelowerbounds1 <=1 & marginalrates1 == 0
			qui egen schedulelowerbounds = concat(schedulelowerbounds*), punct(",") 
			qui replace schedulelowerbounds = subinstr(schedulelowerbounds, ".,", "", .) 
			drop schedulelowerbounds1-schedulelowerbounds`nlb'
				
			qui split(schedulelowerbounds), parse(,)
		
			local nlb = `r(nvars)'
			forvalues i = 1/`nlb' {
				qui replace schedulelowerbounds`i' = strtrim(schedulelowerbounds`i')							
				qui destring schedulelowerbounds`i', replace
			}
			drop schedulelowerbounds

			// Upper bounds
			qui replace scheduleupperbounds1 = . if status == 1 & exemption != . & exemption != -997 & marginalrates1 == 0
			qui egen scheduleupperbounds = concat(scheduleupperbounds*), punct(",") 
			qui replace scheduleupperbounds = subinstr(scheduleupperbounds, ".,", "", .) 
			drop scheduleupperbounds1-scheduleupperbounds`nub'

			qui split(scheduleupperbounds), parse(,)

			local nub = `r(nvars)'
			forvalues i = 1/`nub' {

				qui replace scheduleupperbounds`i' = strtrim(scheduleupperbounds`i')										
				qui destring scheduleupperbounds`i', replace
			}
			drop scheduleupperbounds	
		
			qui gen pos = .
			forvalues i = 1/`nmr' {
				local j = `i'+1
				if (`i' != `nmr') {
					qui gen pippo`i' = (marginalrates`i' == . & marginalrates`j' != .)
					qui replace pos = 2*`i' if pippo`i' == 1			
				}
			}
			qui replace pos = 0 if pos == .	
			
			// Marginal rates
			qui replace marginalrates1 = . if status == 1 & exemption != . & exemption != -997 & marginalrates1 == 0
			qui egen marginalrates = concat(marginalrates*), punct(",") 

			qui gen marginalrates_v2 = ""
			forvalues n = 1(1)`=_N' {
				qui sum pos in `n'	
				local pos = `r(mean)'
				qui replace marginalrates_v2 = substr(marginalrates, 1, `pos') if pos == `pos' & pos != 0
			}
			
			qui replace marginalrates = subinstr(marginalrates, ".,", "", .)
			qui ereplace marginalrates = concat(marginalrates_v2 marginalrates) if pos > 0
			drop marginalrates_v2 
			cap drop pippo*
			
			drop marginalrates1-marginalrates`nmr'		
			qui split(marginalrates), parse(,)
						
			local nmr = `r(nvars)'
			
			forvalues i = 1/`nmr' {
				qui replace marginalrates`i' = strtrim(marginalrates`i')										
				qui destring marginalrates`i', replace
			}
			drop marginalrates		
		}
		
		// Additional filling
		qui bys GEO year* applies_to tax: egen first = min(firstyear)
		qui replace firstyear = first 
		qui replace firstyear = -999 if firstyear == .
		drop first
		
		qui replace fhome_exemp = -999 if fhome_exemp == .
		qui replace fbusiness_exemp = -999 if fbusiness_exemp == .
		qui replace taxablevalue = -999 if taxablevalue == .
		qui replace exemption = -999 if exemption == .
		qui replace different_tax = 0 if status == 1 & different_tax == .

		qui count if marginalrates1 != . & marginalrates1 != 0
		if (`r(N)' != 0) {		
			forvalues i = 1/`nlb' {
				qui replace schedulelowerbounds`i' = -999 if schedulelowerbounds1 == .	
				qui replace scheduleupperbounds`i' = -999 if scheduleupperbounds1 == .	
				qui replace marginalrates`i' = -999 if marginalrates1 == . & pos == 0
				qui replace marginalrates`i' = -998 if marginalrates`i' == . & pos > 0			
			}		
		drop pos
		}
		else {
			qui replace schedulelowerbounds1 = -999 if schedulelowerbounds1 == .	
			qui replace scheduleupperbounds1 = -999 if scheduleupperbounds1 == .	
			qui replace marginalrates1 = -999 if marginalrates1 == .		
		}
			
		
	////////////////////	
	// Additional checks 
	////////////////////		
	display "Additional checks..."
	
	// Check source is constant within GEO-year_from-year_to
		foreach var of local sourceinfo {
			qui egen mistake = nvals(`var'), by(GEO year_from year_to)
			qui count if mistake != 1 & mistake != .
			if (`r(N)' != 0) {
				display as error "ERROR: `var' not constant within GEO-year_from-year_to cells"
				tab `var' if mistake != 1 & mistake != .
			}	
			drop mistake
		}

	// Check notes are constant within GEO-year_from-year_to-applies_to-tax groups
		qui egen mistake = nvals(note), by(GEO year_from year_to applies_to tax)
		qui count if mistake != 1 & mistake != .
		if (`r(N)' != 0) {
			display as error "ERROR: note not constant within GEO-year_from-year_to-applies_to-tax groups"
			tab note if mistake != 1 & mistake != .
		}	
		drop mistake
		
	// Check currency is constant within GEO-year_from-year_to-applies_to-tax groups
		qui egen mistake = nvals(curren), by(GEO year_from year_to applies_to tax)
		qui count if mistake != 1 & mistake != .
		if (`r(N)' != 0) {
			display as error "ERROR: currency not constant within GEO-year_from-year_to-applies_to-tax groups"
			tab note if mistake != 1 & mistake != .
		}	
		drop mistake	

		
	/////////////////////////////////
	////// COMPATIBILITY CHECKS /////
	/////////////////////////////////
	display "Compatibility checks..."
	
		// First year must be lower or equal to year_from 
		qui count if firstyear > year_from & status == 1
		if (`r(N)' != 0) {
			display as error "ERROR: firstyear > year_from"
			tab firstyear year_from if firstyear > year_from & status == 1
		}		
		
		
	/////////////////////
	///	MANIPULATIONS ///
	/////////////////////
	display "Manipulations..."

	qui {
	count if schedulelowerbounds1 != -999 & schedulelowerbounds1 != 0
	if (`r(N)' != 0) { 
			
	// Merging brackets with same marginal rates 
	preserve		
		reshape long schedulelowerbounds scheduleupperbounds marginalrates, i(GEO year* applies_to tax) j(bracket)
		drop if schedulelowerbounds == . & bracket != 0
		
		gen i = _n
		replace marginalrates = marginalrates - i if marginalrates < 0
		
		collapse (min) schedulelowerbounds (max) scheduleupperbounds (min) bracket (mean) i, by(GEO year_from year_to applies_to tax marginalrates)
		replace marginalrates = marginalrates + i if marginalrates < 0
		drop i
		
		bys GEO year* applies_to tax (bracket) : gen bracket2 = _n
		drop bracket 
		rename bracket2 bracket
		sum bracket 
		local nbr = `r(max)'
		reshape wide schedulelowerbounds scheduleupperbounds marginalrates, i(GEO year* applies_to tax) j(bracket)

		tempfile collapsed 
		save "`collapsed'", replace 
	restore 

		drop schedulelowerbounds* scheduleupperbounds*  marginalrates*
		merge 1:1 GEO year_from year_to applies_to tax  using "`collapsed'", keep(3) nogen 

		// Schedule adjustment to a positive exemption threshold 
		gen schedulelowerbounds0 = 0 if exemption > 0 & marginalrates1 != 0 & schedulelowerbounds1 != . & schedulelowerbounds1 != -999 
		gen marginalrates0 = 0 if exemption > 0 & marginalrates1 != 0 & marginalrates1 != . & marginalrates1 != -999 
		gen scheduleupperbounds0 = exemption if exemption > 0 & marginalrates1 != 0 & marginalrates1 != . & marginalrates1 != -999 
		
		forvalues i = 1/`nbr' {
			replace schedulelowerbounds`i' = schedulelowerbounds`i' + exemption if schedulelowerbounds0 == 0 & flag == 0 
			replace scheduleupperbounds`i' = scheduleupperbounds`i' + exemption if schedulelowerbounds0 == 0 & scheduleupperbounds`i' != -997 & scheduleupperbounds`i' != . & flag == 0 	
		}
		
		replace schedulelowerbounds0 = schedulelowerbounds1 if schedulelowerbounds0 == . 
		replace scheduleupperbounds0 = scheduleupperbounds1 if scheduleupperbounds0 == . 
		replace marginalrates0 = marginalrates1 if marginalrates0 == . 

		forvalues i = 1(1)`nbr' {
			local k = `i' + 1		
			local j = `i' - 1
				if `i' != `nbr' {	
					replace schedulelowerbounds`i' = schedulelowerbounds`k' if round(schedulelowerbounds`i', .01) == round(schedulelowerbounds`j', .01) & schedulelowerbounds`i' != 1 & schedulelowerbounds`i' != 1 + exemption & marginalrates`i' != -998 & typetax != 3
					replace scheduleupperbounds`i' = scheduleupperbounds`k' if round(scheduleupperbounds`i', .01) == round(scheduleupperbounds`j', .01) & marginalrates`i' != -998 & typetax != 3
					replace marginalrates`i' = marginalrates`k' if round(marginalrates`i', .01) == round(marginalrates`j', .01) & marginalrates`i' != -998 & typetax != 3
				}
				else {
					replace schedulelowerbounds`i' = . if round(schedulelowerbounds`i', .01) == round(schedulelowerbounds`j', .01) & typetax != 3
					replace scheduleupperbounds`i' = . if round(scheduleupperbounds`i', .01) == round(scheduleupperbounds`j', .01) & typetax != 3
					replace marginalrates`i' = . if round(marginalrates`i', .01) == round(marginalrates`j', .01) & typetax != 3
				}
		}	
		forvalues i = `nbr'(-1)0 {
			local j = `i' + 1
			rename schedulelowerbounds`i' schedulelowerbounds`j'
			rename scheduleupperbounds`i' scheduleupperbounds`j'
			rename marginalrates`i' marginalrates`j'
		}	
		
		replace schedulelowerbounds2 = . if round(schedulelowerbounds2, .01) == round(schedulelowerbounds1, .01) & marginalrates2 != -998 
		replace scheduleupperbounds2 = . if round(scheduleupperbounds2, .01) == round(scheduleupperbounds1, .01) & marginalrates2 != -998	
		replace marginalrates2 = . if round(marginalrates2, .01) == round(marginalrates1, .01) & marginalrates2 != -998	
		cap drop schedulelowerbounds0 scheduleupperbounds0 marginalrates0 
	    }

		// Prepare to reshape the brackets
		gen schedulelowerbounds0 = .
		gen scheduleupperbounds0 = .
		gen marginalrates0 = .

		// Top Rate 
		count if schedulelowerbounds1 != -999
		if (`r(N)' != 0) { 
		
		local mr = `nbr' +1
		replace toprate = marginalrates`mr' if toprate == .

		forvalues i = 1/`mr' {
			if `i' != `mr' local j = `i'+1 
			else local j = `i'
			replace toprate = marginalrates`i' if toprate == . & marginalrates`j' == .
		}
		}
		replace toprate = -999 if toprate == .

		reshape long schedulelowerbounds scheduleupperbounds marginalrates schedule, i(GEO year* applies_to tax) j(bracket)
		drop if schedulelowerbounds == . & bracket != 0		

		gen pippo = 2 if schedulelowerbounds != 0 & bracket == 1 & marginalrates>0 &  schedulelowerbounds != -999

		expand pippo, gen(dupl) 
		gsort GEO year_from year_to applies_to tax bracket -dupl 
		
		replace marginalrates = 0 if dupl == 1 
		replace schedulelowerbounds = 0 if dupl == 1 
		replace scheduleupperbounds = schedulelowerbounds[_n+1] if dupl == 1 
		replace exemption = scheduleupperbounds if dupl == 1 
		bysort year_from year_to applies_to tax : egen max_exempt = max(exemption)
		replace exemption = max_exempt if exemption != max_exempt
		drop max_exempt
		replace scheduleupperbounds = scheduleupperbounds + schedule if year_from == year_from[_n+1] & year_to == year_to[_n+1] & tax == tax[_n+1] & applies_to == applies_to[_n+1] & schedulelowerbounds == 0 & (schedulelowerbounds[_n+1] - scheduleupperbounds >= schedule) & status == 1 
		replace exemption = scheduleupperbounds if year_from == year_from[_n+1] & year_to == year_to[_n+1] & tax == tax[_n+1] & applies_to == applies_to[_n+1] & schedulelowerbounds==0 & marginalrates == 0 & status == 1
		replace exemption = exemption[_n-1] if year_from == year_from[_n+1] & year_to == year_to[_n+1] & tax == tax[_n+1] & applies_to == applies_to[_n+1] & exemption != exemption[_n-1] & bracket > 1 
		replace exemption = exemption[_n+1] if year_from == year_from[_n+1] & year_to == year_to[_n+1] & tax == tax[_n+1] & applies_to == applies_to[_n+1] & exemption != exemption[_n+1] & bracket == 0 
		
		gsort GEO year_from year_to applies_to tax bracket -dupl 
		
		bysort GEO year_from year_to applies_to tax (bracket) : gen prova = _n-1 
		drop bracket dupl pippo
		rename prova bracket 

		local nums subnationallevel status typetax firstyear exemption toprate toplowerbound fhome_exemp fbusiness_exemp taxablevalue different_tax
		local strin currency AggSource Legend Source Link note
		foreach var of local nums {
			replace `var' = . if bracket != 0
		}
		foreach var of local strin {
			replace `var' = "" if bracket != 0
		}

	// Adjust the lower bounds to be 1 unit more than preceding upper bound
		recast double schedulelower
		recast double scheduleupper	
		format scheduleupper %50.0f
		format schedulelower %50.0f
		qui bys year* applies_to tax: egen typet = min(typetax)
		qui bys year* applies_to tax (bracket): replace schedulelowerbounds = schedulelowerbounds + 1 if schedulelowerbounds == scheduleupperbounds[_n-1] & bracket > 1 & typet != 3
		qui bys year* applies_to tax (bracket): replace schedulelowerbounds = schedulelowerbounds + 1 if bracket > 1 & typet == 3 // Progressive: all lower bounds are equal
		drop typet
			
		if "`valuecr'" == "exemption" {
	// Restore the exemption if it is a tax credit
			capture confirm variable flag
			if !_rc qui replace exemption = credit if `dummycr' == 1 & exemption == 0 & flag != 1
			else qui replace exemption = credit if `dummycr' == 1 & exemption == 0
	// Apply the tax credit (cut the tax schedule there)
			qui drop if scheduleupperbounds < credit +1 & scheduleupperbounds > 0 & `dummycr' == 1
			qui replace schedulelowerbounds = credit +1 if schedulelowerbounds < credit + 1 & (scheduleupperbounds > credit | scheduleupperbounds == -997) & `dummycr' == 1
			qui bys year* applies_to tax (bracket): replace bracket = bracket[_n-1] + 1 if bracket[_n-1] != .
			qui gen exp = 2 if `dummycr' == 1 & bracket == 1 & schedulelowerbounds == credit +1
			qui expand exp, gen(dupl)
			qui replace marginalrates = 0 if dupl 
			qui replace schedulelowerbounds = 0 if dupl 	
			qui replace scheduleupperbounds = credit if dupl
			gsort tax applies_to year* bracket -dupl
			qui replace dupl = (!dupl)
			qui bys year* tax applies_to (bracket dupl): replace bracket = bracket[_n-1] + 1 if bracket[_n-1] !=	.
			drop dupl exp
		}
		
		cap drop flag 
		cap drop schedule
		cap drop `dummycr'
		cap drop credit
		cap drop exemption_bp		

	// Type of tax
		replace typetax = -999 if typetax == .
		replace typetax = -998 if status == 0
		egen nlb = nvals(schedulelowerbounds) if marginalrates > 0, by(GEO year* applies_to tax)	
		egen nmr = nvals(marginalrates) if marginalrates > 0, by(GEO year* applies_to tax)
		qui egen minnmr = min(nmr), by(GEO year* applies_to tax)
		qui egen minnlb = min(nlb), by(GEO year* applies_to tax)		
		replace typetax = 2 if status==1 & minnmr == 1 // Flat
		replace typetax = 3 if status==1 & minnmr > 1 & minnmr < . & minnlb == 1 // Progressive
		replace typetax = 4 if status==1 & minnmr > 1 & minnmr < . & minnlb > 1 & minnlb < . // Progressive by brackets	
		drop *nmr *nlb	
		replace typetax = . if bracket != 0
		
	// Fill the Top Rate Lower Bound 
		qui bys year* applies_to tax (bracket): replace toplowerbound = schedulelowerbounds[_N] if bracket == 0
		replace toplowerbound = -999 if toplowerbound == . & bracket == 0
				
		sort GEO tax applies_to year_f year_t br
		order GEO GEO_long year_f year_t applies_to tax bracket schedulelowerbounds scheduleupperbounds marginalrates ///
				curre status typetax firstyear exemption toprate toplowerbound ///
				fhome_exemp fbusiness_exemp subnationallevel taxablevalue different_tax AggSource ///
				Legend Source Link note  
		compress

	// Fill the first year if present
	qui ereplace firsty = max(firsty), by(tax bracket)
	qui ereplace firsty = min(firsty), by(tax)

	// Drop if information is before the first year
	qui drop if year_to < firsty
	qui replace firsty = . if bracket != 0
		
	// Rename variables for publication (5 digit)
		rename schedulelowerbounds adjlbo
		rename scheduleupperbounds adjubo
		rename marginalrates adjmrt
		rename status status
		rename typetax typtax
		rename firstyear firsty
		rename exemption exempt
		rename toprate toprat
		rename toplowerbound toplbo 
		rename fhome_exemp homexe
		rename fbusiness_exemp bssexe	

	// Format variables 
		format adjlbo adjubo exempt toplbo %20.0f
		format adjmrt toprat %5.2f
		
	// The other variables will go in the metadata: subnationallevel taxablevalue
		
	// Define labels 
		label var curren "Currency from the source"
		label var applies_to "Sector"
		label var tax "Tax" 
		label var bracket "Number of bracket in tax schedule"
		label var status "Tax Indicator"
		label var firsty "First Year for Tax"
		label var typtax "Type of Effective Tax (1 Lump-sum, 2 Flat, 3 Progressive, 4 Progressive by brackets)"
		label var exempt "Exemption Threshold"
		label var adjlbo "Lower Bound for Exemption-adjusted Tax Bracket"
		label var adjubo "Upper Bound for Exemption-adjusted Tax Bracket"
		label var adjmrt "Tax Marginal Rate for Exemption-adjusted Tax Bracket"
		label var toprat "Top Marginal Rate"
		label var toplbo "Top Marginal Rate Applicable From"
		label var homexe "Whether Family Home is Exempt"
		label var bssexe "Whether Family Business is Exempt"	
		label var subnationallevel "Whether the information applies to subnational units"
		label var taxablevalue "Method of evaluation of the assets for the tax base (1 Purchase cost, 2 FMV, 3 Notional)"
		label var different_tax "Whether the tax is levied through another type of tax"

		label define labels -999 "Missing" -998 "_na" -997 "_and_over"
		foreach var in exempt toprat toplbo adjlbo adjubo adjmrt firsty {
			label values `var' labels, nofix
		}	
		
		label define indicator 0 "No" 1 "Yes" -999 "Missing" -998 "_na"
		foreach var in status homexe bssexe subnational different_tax {
			label values `var' labels, nofix
		}	
		
		label define typtax 1 "Lump-sum" 2 "Flat" 3 "Progressive" 4 "Progressive by brackets" -999 "Missing" -998 "_na"
		label values typtax typtax 

		label define value 1 "Purchase cost" 2 "Fair market value" 3 "Notional value" -999 "Missing" -998 "_na"
		label values taxablevalue value 
		
		compress
		sort GEO year* tax appl br
		cap drop C
		if "`source'" != "Final_Data" save "$sources/`source'/`country'/data_longformat.dta", replace
		else save "$sources/`source'/`country'/data_longformat.dta", replace
		}
		display ""
		display as result "Verified and saved as data_longformat.dta" 
		display ""
		display ""

		qui log close
	end
	
	
/* Code to generate the help file
clear all

net install github, from("https://haghish.github.io/github/")
github install haghish/markdoc, stable

cd "$dir"	
markdoc eigt_verify.ado, mini export(sthlp) replace
*/

///////////////////////
////   HELP FILE   ////
///////////////////////

/***
Verification and adjustment code for EIGT
=========================================

Syntax
------

> __eigt_verify__ _source_name_ _country_name_ [, _options_]


Description
-----------

__eigt_verify__ ...  describe here the adjustment  


The source
----------

_source_name_ depends on the source of the data and can be: 

	. "EY_EIG_Guide" for Worldwide Estate and Inheritance Tax Guide. 
	The program will import the excel file called "__EYb_Country__" plus the country name from the folder "EY_EIG_Guide/Country", and save there __verification_logfile.txt__ and __data_longformat.dta__.  
	
	. "EY_Personal_Tax_Guide" for Worldwide Personal Tax and Immigration Guide.
	The program will import the excel file called "__EYa_Country__" plus the country name from the folder "EY_Personal_Tax_Guide/Country", and save there "__verification_logfile.txt__" and "__data_longformat.dta__".  
	
	. "Government_legislation" for national legislation.
	The program will import the excel file called "__Lex_Country__" plus the country name from the folder "Government_legislation/Country", and save there "__verification_logfile.txt__" and "__data_longformat.dta__".  

		
The country
-----------

_country_name_ should have the first capital letter and coincide with the name of the folder from which the data should be uploaded.  


Options
-------

| _Options_                |Description                                                                                                |
|:------------------------ |:----------------------------------------------------------------------------------------------------------|  
| Tax credit options       |                                                                                                           |  
|__**value**cr(_string_)__ |Either _exemption_ or a positive number. If absent, no tax credit is applied.                              |
|__**dummy**cr(_string_)__ |Name of the variable indicating whether the tax credit applies. Required if __**value**cr()__ is specified.|  

__valuecr(_string_)__ allows to state through _exemption_ that the exemption column contains a tax credit; it also allows for a 
positive number as entry to directly specify the amount of tax credit if it does not coincide with the exemption.  
It works in combination with __dummycr(_string_)__ (see below).  

__dummycr(_string_)__ takes the name of the indicator variable in the input file
which assumes value 1 for the combinations of _year_from_, _year_to_, _tax_, and _applies_to_ to which the indication in option __value_cr(_string_)__ applies.
It is required if option __valuecr(_string_)__ is specified.  

Remarks
-------

...  

Examples
--------

	. __eigt_verify EY_EIG_Guide United_States, valuecr(exemption) dummycr(taxcredit)__  
	
	. __eigt_verify EY_EIG_Guide Philippines__  

Version
-------

This version: 4 December 2024  

***/
	
		