*************************************
*** EIGT data: automated error finder
*************************************

// Last update: July 2025

// Data used: $sources/eigt_transcribed.xlsx,  $hmade/dictionary.xlsx
// Output: $intfile/eigt_taxsched_data.dta, $intfile/eigt_taxsched_sources.dta, $intfile/eigt_taxsched_currency.dta

// Content: check validity and consistency of each variable in eigt_transcribed.xlsx.
// After the check, transform the variables in their final (and numeric) format, 
// and save separately the data about schedule, the sources and the currency files

	clear all
	// Import raw data on tax schedules
	qui import excel "$sources/eigt_transcribed.xlsx", sheet(Detailed) firstrow clear
	qui compress 	

************************* 0. General checks ************************************
// Check for duplicates

	qui: count if country == ""
	display "`r(N)' missing country deleted"
	qui: drop if country == ""

	qui: duplicates report
	local dupl = r(N) - r(unique_value)
	if (`dupl' != 0) {
		qui: duplicates tag, gen(dupl)
		display as error "`dupl' duplicates dropped, verify in excel" 
		tab country if dupl != 0
		qui: duplicates drop 
		drop dupl
	}
	else display "No duplicates found"

// Select and rename relevant variables	
    
	keep country Geo geo3 year Currency ///
		EIG_Status First_EIG Estate_Tax Gift_Tax Inheritance_Tax ///
		Inheritance_Tax_Relation_Based	Inheritance_Estate_Exemption ///
		Child_Exemption Adjusted_Class_I_Lower ///
		Adjusted_Class_I_Upper Adjusted_Class_I_Statutory_Marg ///
		Source* *Top_Rate* n
	qui duplicates drop 
	
	qui drop if Adjusted_Class_I_Lower == "_na" & Adjusted_Class_I_Upper == "_na"
	sort country year n	
	
// Brackets must be ordered and sequential
	qui: count if country == country[_n-1] & year == year[_n-1] & n != n[_n-1]+1
	if (`r(N)' != 0) {
		display as error "`r(N)' non consecutive brackets"
		tab country if country == country[_n-1] & year == year[_n-1] & n != n[_n-1]+1
	}	
	
// Brackets must start from 1
	qui egen minbr = min(n), by(country year)
	qui: count if minbr != 1
	if (`r(N)' != 0) {
		display as error "Schedules not starting from 1"
		tab country if minbr != 1
	}	
	drop minbr
	qui gen N = _n

************************* 1. Country codes *************************************

	rename Geo GEO
	preserve 
		qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
		rename Country GEO_long
		drop GEO3
		qui duplicates drop
		tempfile ccodes 
		save "`ccodes'", replace
	restore	
	drop country
	qui: merge m:1 GEO using "`ccodes'", keep(master matched)
	qui: count if _m == 1
	if (`r(N)' != 0) {
		display as error "`r(N)' unmatched observations in dictionary, countries dropped"
		tab GEO if _m == 1
		drop if _m == 1
		drop _m
	}
	else {
		display "All country codes matched in dictionary"
		drop _m
	} 
	rename GEO Geo
	
************************* 2. Tax Status ****************************************
// Tax status can be Y/N/missing
// Inadmissible entries check
	foreach var in EIG_Status Estate_Tax Gift_Tax Inheritance_Tax {
		qui: replace `var' = "" if `var' == "." 
		qui: count if `var' != "Y" & `var' != "N" & `var' != ""
		if (`r(N)' != 0) {
			display "`r(N)' wrong entry in `var'"
			tab `var', miss
			tab GEO_long if `var' != "Y" & `var' != "N" & `var' != ""
		}
	}
	
// Incompatible entries check
	qui: count if EIG_Status != "Y" & (Estate_Tax=="Y" | Gift_Tax=="Y" | Inheritance_Tax=="Y")
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' cases of EIG_Status not Y when there is a tax"
		tab GEO_long if EIG_Status != "Y" & Estate_Tax=="Y" | Gift_Tax=="Y" | Inheritance_Tax=="Y"
		replace EIG_Status = "Y" if Estate_Tax=="Y" | Gift_Tax=="Y" | Inheritance_Tax=="Y"
	}	
	qui: count if EIG_Status != "N" & Estate_Tax=="N" & Gift_Tax=="N" & Inheritance_Tax=="N"
	if (`r(N)' != 0) {
		tab GEO_long if EIG_Status != "N" & Estate_Tax=="N" & Gift_Tax=="N" & Inheritance_Tax=="N"
		display as error "WARNING: `r(N)' cases of EIG_Status !N when there is no tax"
		replace EIG_Status = "N" if Estate_Tax=="N" & Gift_Tax=="N" & Inheritance_Tax=="N"
	}	

	qui: count if EIG_Status == "N" & (Estate_Tax!="N" | Gift_Tax!="N" | Inheritance_Tax!="N")
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' cases of single tax not N when EIG_Status == N"
		tab GEO_long if EIG_Status == "N" & (Estate_Tax!="N" | Gift_Tax!="N" | Inheritance_Tax!="N")
		replace Estate_Tax = "N" if EIG_Status == "N"
		replace Gift_Tax = "N" if EIG_Status == "N"
		replace Inheritance_Tax = "N" if EIG_Status == "N"		
	}		

************************* 3. First year of tax *********************************
// First EIGT year can be 0/1/""/_na
// Inadmissible entries check
	qui: replace First_EIG = "" if First_EIG == "." 
	qui: count if First_EIG != "0" & First_EIG != "1" & First_EIG != "" & First_EIG != "_na"
	if (`r(N)' != 0) {
		display "`r(N)' inadmissible entries in First_EIG"
		tab First_EIG, miss
		tab GEO_long if First_EIG != "0" & First_EIG != "1" & First_EIG != "" & First_EIG != "_na"
	}
// Incompatible entries check		
	qui: count if First_EIG != "_na" & EIG_Status=="N"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: First_EIG != _na but no tax"
		tab GEO_long if First_EIG != "_na" & EIG_Status=="N"
		replace First_EIG = "_na" if EIG_Status=="N"
	}	
	qui: count if First_EIG != "" & EIG_Status==""
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: First_EIG != . but missing tax"
		tab GEO_long if First_EIG != "" & EIG_Status==""
		replace First_EIG = "" if EIG_Status==""
	}	
	qui: count if First_EIG == "_na" & EIG_Status != "N"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: First_EIG == _na but tax not N"
		tab GEO_long if First_EIG == "_na" & EIG_Status != "N"
		replace First_EIG = "" if First_EIG == "_na" & EIG_Status != "N"
	}	
	
	qui replace First_EIG = "" if EIG_Status=="" & First_EIG != ""	
	
	qui gen first_y = year if First_EIG == "1"	
	qui: bys GEO_long: egen first = min(first_y)
	drop first_y
	qui: count if First_EIG == "1" & year > first
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: First_EIG == 1 in different years"
		tab GEO_long if First_EIG == "1" & year > first
		replace First_EIG = "0" if First_EIG == "1" & year > first
	}	
	qui: count if EIG_Status == "Y" & year < first & first != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: EIG_Status == Y but year < first year"
		tab GEO_long if EIG_Status == "Y" & year < first & first != .
		*replace EIG_Status = "" if First_EIG == "_na" & EIG_Status != "N"
	}

	*** replace all future years with a zero when there is a one in the past ***	
	qui replace First_EIG = "0" if First_EIG == "" & year > first


************************* 4. Inheritance_Tax_Relation_Based ******************** 

// Can be Y/N/""/_na
// Inadmissible entries check
	qui: replace Inheritance_Tax_Relation_Based = "" if Inheritance_Tax_Relation_Based == "." 
	qui: count if Inheritance_Tax_Relation_Based != "N" & Inheritance_Tax_Relation_Based != "Y" & Inheritance_Tax_Relation_Based != "" & Inheritance_Tax_Relation_Based != "_na"
	if (`r(N)' != 0) {
		display "`r(N)' inadmissible entries in Inheritance_Tax_Relation_Based"
		tab Inheritance_Tax_Relation_Based, miss
		tab GEO_long if Inheritance_Tax_Relation_Based != "N" & Inheritance_Tax_Relation_Based != "Y" & Inheritance_Tax_Relation_Based != "" & Inheritance_Tax_Relation_Based != "_na"
	}
	qui replace Inheritance_Tax_Relation_Based = "Y" if Inheritance_Tax_Relation_Based == "B" | Inheritance_Tax_Relation_Based == "E" // "both" and "exemption"
	
// Incompatible entries check
	qui: count if Inheritance_Tax_Relation_Based != "_na" & Inheritance_Tax=="N"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Inheritance_Tax_Relation_Based != _na but no tax"
		tab GEO_long if Inheritance_Tax_Relation_Based != "_na" & Inheritance_Tax=="N"
		tab Inheritance_Tax_Relation_Based if Inheritance_Tax_Relation_Based != "_na" & Inheritance_Tax=="N"
		replace Inheritance_Tax_Relation_Based = "_na" if Inheritance_Tax=="N"
	}	
	qui: count if Inheritance_Tax_Relation_Based != "" & Inheritance_Tax==""
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Inheritance_Tax_Relation_Based != . but missing inheritance tax, possible but need to check"
		tab GEO_long if Inheritance_Tax_Relation_Based != "" & Inheritance_Tax==""
		replace Inheritance_Tax_Relation_Based = "" if Inheritance_Tax==""
	}	
	qui: count if Inheritance_Tax_Relation_Based == "_na" & Inheritance_Tax != "N"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Inheritance_Tax_Relation_Based == _na but inheritance tax not N"
		tab GEO_long if Inheritance_Tax_Relation_Based == "_na" & Inheritance_Tax != "N"
		replace Inheritance_Tax_Relation_Based = "" if Inheritance_Tax_Relation_Based == "_na" & Inheritance_Tax != "N"
	}		


************************* 5. Inheritance_Estate_Exemption **********************	

// Can be Y/N/""/_na
// Inadmissible entries check
	qui: replace Inheritance_Estate_Exemption = "" if Inheritance_Estate_Exemption == "." 
	qui: count if Inheritance_Estate_Exemption != "N" & Inheritance_Estate_Exemption != "Y" & Inheritance_Estate_Exemption != "" & Inheritance_Estate_Exemption != "_na"
	if (`r(N)' != 0) {
		display "`r(N)' inadmissible entries in Inheritance_Estate_Exemption"
		tab Inheritance_Estate_Exemption, miss
		tab GEO_long if Inheritance_Estate_Exemption != "N" & Inheritance_Estate_Exemption != "Y" & Inheritance_Estate_Exemption != "" & Inheritance_Estate_Exemption != "_na"
	}

// Incompatible entries check
	** neither inheritance nor estate tax apply
	qui: count if Inheritance_Estate_Exemption != "_na" & Inheritance_Tax=="N" & Estate_Tax=="N"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Inheritance_Estate_Exemption != _na but no tax"
		tab GEO_long if Inheritance_Estate_Exemption != "_na" & Inheritance_Tax=="N" & Estate_Tax=="N"
		tab Inheritance_Estate_Exemption if Inheritance_Estate_Exemption != "_na" & Inheritance_Tax=="N" & Estate_Tax=="N"
		replace Inheritance_Estate_Exemption = "_na" if Inheritance_Tax=="N" & Estate_Tax=="N"
	}	
	** inheritance or estate tax apply, but there is no exemption
	qui: count if Inheritance_Estate_Exemption != "_na" & Child_Exemption=="0"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Inheritance_Estate_Exemption != _na but no exemption"
		tab GEO_long if Inheritance_Estate_Exemption != "_na" & Child_Exemption=="0"
		tab Inheritance_Estate_Exemption if Inheritance_Estate_Exemption != "_na" & Child_Exemption=="0"
		replace Inheritance_Estate_Exemption = "_na" if Inheritance_Estate_Exemption != "_na" & Child_Exemption=="0"
	}	
	** inheritance or estate tax apply but Inheritance_Estate_Exemption is _na
	qui: count if Inheritance_Estate_Exemption == "_na" & Inheritance_Tax=="Y" & Child_Exemption != "0"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Inheritance_Estate_Exemption == _na but an inheritance tax applies"
		tab GEO_long if Inheritance_Estate_Exemption == "_na" & Inheritance_Tax=="Y" & Child_Exemption != "0"
		replace Inheritance_Estate_Exemption = "" if Inheritance_Estate_Exemption == "_na" & Inheritance_Tax=="Y" & Child_Exemption != "0"
	}	
	qui: count if Inheritance_Estate_Exemption != "" & Inheritance_Tax=="" & Estate_Tax==""
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Inheritance_Estate_Exemption != . but missing inheritance and estate tax, possible but need to check"
		tab GEO_long if Inheritance_Estate_Exemption != "" & Inheritance_Tax=="" & Estate_Tax==""
		replace Inheritance_Estate_Exemption = "" if Inheritance_Tax=="" & Estate_Tax==""
	}	
	// Denmark 14 cases checked, okay

************************* 6. Child Exemption *********************************** 

// Can be 0, a positive number, _na, missing, _and_over
	qui: replace Child = "" if Child == "." 

// Inadmissible entries check	
	qui: replace Child = "-998" if Child == "_na"
	qui: replace Child = "-997" if Child == "_and_over"
	destring Child, replace // if no error, okay 
	qui: count if Child < 0 & Child != -998 & Child  != -997
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' negative values for Child_Exemption"
	}
	
// Incompatible entries check
	qui: count if Child_Exemption != -998 & Inheritance_Tax=="N" & Estate_Tax=="N"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Child_Exemption != _na but no tax"
		tab GEO_long if Child_Exemption != -998 & Inheritance_Tax=="N" & Estate_Tax=="N"
		tab Child_Exemption if Child_Exemption != -998 & Inheritance_Tax=="N" & Estate_Tax=="N"
		replace Child_Exemption = -998 if Inheritance_Tax=="N" & Estate_Tax=="N"
	}	
	qui: count if Child_Exemption != . & EIG_Status==""
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Child_Exemption != . but missing tax"
		tab GEO_long if Child_Exemption != "" & EIG_Status==""
		replace Child_Exemption = "" if EIG_Status==""
	}	
	qui: count if Child_Exemption == -998 & (Inheritance_Tax == "Y" | Estate_Tax == "Y")
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' incompatible entries: Child_Exemption == _na but tax Y"
		tab GEO_long if Child_Exemption == -998 & (Inheritance_Tax == "Y" | Estate_Tax == "Y")
		replace Child_Exemption = "" if Child_Exemption == -998 & (Inheritance_Tax == "Y" | Estate_Tax == "Y")
	}

************************* 7. Adjusted lower bound ******************************	

// Can be 0, a positive number, missing
	qui: replace Adjusted_Class_I_Lower_Bound = "" if Adjusted_Class_I_Lower_Bound == "." 

// Inadmissible entries check	
	qui: count if Adjusted_Class_I_Lower_Bound == "_na"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Lower_Bound == _na"
		tab GEO_long if Adjusted_Class_I_Lower_Bound == "_na"
	}	

	qui destring Adjusted_Class_I_Lower_Bound, replace // if no error, okay 
	qui: count if Adjusted_Class_I_Lower_Bound < 0 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' negative values for Adjusted_Class_I_Lower_Bound"
	}

// The first one must be 0
	qui: count if n == 1 & Adjusted_Class_I_Lower_Bound != 0 & Adjusted_Class_I_Lower_Bound != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Lower_Bound != 0 in bracket 1"
		tab GEO_long if n == 1 & Adjusted_Class_I_Lower_Bound != 0 & Adjusted_Class_I_Lower_Bound != .
	}	

// Incompatible entries check

// There is a schedule but there is no tax
	qui: count if Adjusted_Class_I_Lower_Bound != . & Inheritance_Tax == "" & Estate_Tax == ""
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Lower_Bound != . but missing tax, possible but need to check"
		tab GEO_long if Adjusted_Class_I_Lower_Bound != . & Inheritance_Tax == "" & Estate_Tax == ""
	}	
	// 116 cases Denmark checked

************************* 8. Adjusted upper bound ******************************	

// Can be a positive number, missing, _and_over
	qui: replace Adjusted_Class_I_Upper_Bound = "" if Adjusted_Class_I_Upper_Bound == "." 

// Inadmissible entries check	
	qui: count if Adjusted_Class_I_Upper_Bound == "_na"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Upper_Bound == _na"
		tab GEO_long if Adjusted_Class_I_Upper_Bound == "_na"
	}	

	qui replace Adjusted_Class_I_Upper_Bound = "-997" if Adjusted_Class_I_Upper_Bound == "_and_over"
	qui destring Adjusted_Class_I_Upper_Bound, replace // if no error, okay 
	qui: count if Adjusted_Class_I_Upper_Bound < 0 & Adjusted_Class_I_Upper_Bound != -997 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' negative values for Adjusted_Class_I_Upper_Bound"
	}

// The last one must be _and_over
	sort GEO_long year n
	qui: count if (year != year[_n+1] | GEO_long != GEO_long[_n+1]) & Adjusted_Class_I_Upper_Bound != -997 & Adjusted_Class_I_Lower_Bound != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Upper_Bound != _and_over in last bracket"
		tab GEO_long if (year != year[_n+1] | GEO_long != GEO_long[_n+1]) & Adjusted_Class_I_Upper_Bound != -997 & Adjusted_Class_I_Lower_Bound != .
	}

// Incompatible entries check

// The first one must be _and_over if there is no tax
	sort GEO_long year n
	qui: count if n == 1 & Inheritance_Tax == "N" & Estate_Tax == "N" & Adjusted_Class_I_Upper_Bound != -997
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Upper_Bound != _and_over but no tax"
		tab GEO_long if n == 1 & Inheritance_Tax == "N" & Estate_Tax == "N" & Adjusted_Class_I_Upper_Bound != -997
	}

// Missing if the lower bound is missing 
	qui: count if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Upper_Bound != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' missing lower but upper non missing"
		tab GEO_long if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Upper_Bound != .
	}	
	
// Non Missing if the lower bound is non missing 
	qui: count if Adjusted_Class_I_Lower_Bound != . & Adjusted_Class_I_Upper_Bound == .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' non missing lower but upper missing"
		tab GEO_long if Adjusted_Class_I_Lower_Bound != . & Adjusted_Class_I_Upper_Bound == .
	}
	
// Check that the lower bound of a bracket is the upper bound of the preceeding bracket 
	qui: count if GEO_long == GEO_long[_n-1] & year == year[_n-1] & (round(Adjusted_Class_I_Lower_Bound) != round(Adjusted_Class_I_Upper_Bound[_n-1])) & (Adjusted_Class_I_Lower_Bound != Adjusted_Class_I_Upper_Bound[_n-1]+1)
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' lower bound of a bracket is not upper bound of the preceeding one"
		tab GEO_long if GEO_long == GEO_long[_n-1] & year == year[_n-1] & (round(Adjusted_Class_I_Lower_Bound) != round(Adjusted_Class_I_Upper_Bound[_n-1])) & (Adjusted_Class_I_Lower_Bound != Adjusted_Class_I_Upper_Bound[_n-1]+1)
	}
	
************************* 9. Adjusted marginal rate ****************************	

// Can be 0, a positive number, missing
	qui: replace Adjusted_Class_I_Statutory_Margi = "" if Adjusted_Class_I_Statutory_Margi == "." 

// Inadmissible entries check	
	qui: count if Adjusted_Class_I_Statutory_Margi == "_na"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Adjusted_Class_I_Statutory_Margi == _na"
		tab GEO_long if Adjusted_Class_I_Statutory_Margi == "_na"
	}	

	qui destring Adjusted_Class_I_Statutory_Margi, replace // if no error, okay 
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
		tab GEO_long if n == 1 & Inheritance_Tax == "N" & Estate_Tax == "N" & Adjusted_Class_I_Statutory_Margi != 0
	}	

// The first must be 0 if there is an exemption
	qui: count if n == 1 & Child_Exemption > 0 & Child_Exemption < . & Adjusted_Class_I_Statutory_Margi != 0 & Adjusted_Class_I_Statutory_Margi != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' exemption but marginal rate in first bracket is not zero"
		tab GEO_long if n == 1 & Child_Exemption > 0 & Child_Exemption < . & Adjusted_Class_I_Statutory_Margi != 0 & Adjusted_Class_I_Statutory_Margi != .
	}	
	
// The first one should not be 0 if there is no exemption
	qui: count if n == 1 & Child_Exemption == 0 & Adjusted_Class_I_Statutory_Margi == 0
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' no exemption but marginal rate in first bracket is zero"
		tab GEO_long if n == 1 & Child_Exemption == 0 & Adjusted_Class_I_Statutory_Margi == 0
	}
	
// The first and only one should not be 0 if there is missing exemption
	qui egen maxbr = max(n), by(GEO_long year)
	qui: count if maxbr == 1 & Child_Exemption == . & Adjusted_Class_I_Statutory_Margi == 0
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' missing exemption but marginal rate in the only bracket is zero"
		tab GEO_long if maxbr == 1 & Child_Exemption == . & Adjusted_Class_I_Statutory_Margi == 0
	}

// Missing if the schedule is missing 
	qui: count if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Statutory_Margi != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' missing schedule but marginal rate non missing"
		tab GEO_long if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Statutory_Margi != .
	}	
	
// Non Missing if the schedule is non missing 
	qui: count if Adjusted_Class_I_Lower_Bound != . & Adjusted_Class_I_Statutory_Margi == .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' non missing schedule but marginal rate missing"
		tab GEO_long if Adjusted_Class_I_Lower_Bound != . & Adjusted_Class_I_Statutory_Margi == .
	}	
	
// The marginal rate cannot be decreasing 
	qui: count if n < n[_n+1] & Adjusted_Class_I_Statutory_Margi > Adjusted_Class_I_Statutory_Margi[_n+1] 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' decreasing marginal rates"
		display as error "NOTE: 19 cases are a Sweden exception"
		tab GEO_long if n < n[_n+1] & Adjusted_Class_I_Statutory_Margi > Adjusted_Class_I_Statutory_Margi[_n+1] 
	}	
	
************************* 10. Top Rates ****************************************

foreach var in Gift Estate Inheritance {
	
	// Can be 0, a positive number, missing
		qui: replace `var'_Top_Rate = "" if `var'_Top_Rate == "." 

	// Inadmissible entries check	
		qui: count if `var'_Top_Rate == "_na"
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' `var'_Top_Rate == _na"
			tab GEO_long if `var'_Top_Rate == "_na"
		}	

		qui destring `var'_Top_Rate, replace // if no error, okay 
		qui: count if `var'_Top_Rate < 0 
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' negative values for `var'_Top_Rate"
		}
		qui: count if `var'_Top_Rate > 100 & `var'_Top_Rate < .
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' values for `var'_Top_Rate > 1"
		}

	// Incompatible entries check	
		
	// It must be 0 if there is no tax
		qui: count if `var'_Tax == "N" & `var'_Top_Rate != 0
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' no `var' tax but  `var' top rate is not zero"
			tab GEO_long if `var'_Tax == "N" & `var'_Top_Rate != 0
		}	

	// It must be missing if the information on the tax is missing
		qui: count if `var'_Tax == "" & `var'_Top_Rate != .
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' missing `var' tax but  `var' top rate is not missing"
			tab GEO_long if `var'_Tax == "" & `var'_Top_Rate != .
		}	
}

// (only for inheritance) It must be 0 if there is full exemption
	qui: count if Child_Exemption == -997 & Inheritance_Top_Rate != 0
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' full exemption for inh tax but inh top rate is not zero"
		tab GEO_long if Child_Exemption == -997 & Inheritance_Top_Rate != 0
	}
	
	qui: count if Inheritance_Tax != "Y" & Estate_Tax == "Y" & Child_Exemption == -997 & Inheritance_Top_Rate != 0
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' full exemption for est tax but est top rate is not zero, possible but to check"
		tab GEO_long if Inheritance_Tax != "Y" & Estate_Tax == "Y" & Child_Exemption == -997 & Inheritance_Top_Rate != 0
	}
	// 116 cases Denmark checked
		

// In case of inheritance or estate tax, the top rate must be the marginal rate of the last bracket
	
	qui gen top = Adjusted_Class_I_Statutory_Margi if (GEO_long == GEO_long[_n+1] & year != year[_n+1]) | (GEO_long != GEO_long[_n+1])
	qui egen topr = min(top), by(GEO_long year)
	qui: count if Inheritance_Tax == "Y" & round(Inheritance_Top_Rate, topr) != round(topr) & topr != . 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Inh top rate different from marginal rate on the last bracket"
		tab GEO_long if Inheritance_Tax == "Y" & round(Inheritance_Top_Rate, topr) != topr & topr != . 
	}
	qui gen estate_flag = Inheritance_Tax == "Y" & round(Inheritance_Top_Rate, topr) != topr & topr != .
	display as error "149 cases checked, the adj. schedules wrongly refer to the estate tax, see dummy estate_flag"
	
	qui: count if Inheritance_Tax != "Y" & Estate_Tax == "Y" & round(Estate_Top_Rate, topr) != topr & topr != . 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Est. top rate different from marginal rate on the last bracket"
		tab GEO_long if Inheritance_Tax != "Y" & Estate_Tax == "Y" & round(Estate_Top_Rate, topr) != topr & topr != . 
	}
	drop topr top

************************* 11. Top_Rate *****************************************

// Can be 0, a positive number, missing
	qui: replace Top_Rate = "" if Top_Rate == "." 
	
// Inadmissible entries check	
	qui: count if Top_Rate == "_na"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Top_Rate == _na"
		tab GEO_long if Top_Rate == "_na"
	}	

	qui destring Top_Rate, replace // if no error, okay 
	qui: count if Top_Rate < 0 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' negative values for Top_Rate"
	}
	qui: count if Top_Rate > 100 & Top_Rate < .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' values for Top_Rate > 1"
	}
	
// Incompatible entries check	
	// It must be 0 if there is no est or inh tax
	qui: count if Inheritance_Tax == "N" & Estate_Tax == "N" & Top_Rate != 0
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' no tax but top rate is not zero"
		tab GEO_long if Inheritance_Tax == "N" & Estate_Tax == "N" & Top_Rate != 0
	}
		
	// It must be missing if the information on the tax is missing
	qui: count if Inheritance_Tax == "" & Estate_Tax == "" & EIG_Status != "Y" & Top_Rate != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' missing  tax but  top rate is not missing"
		tab GEO_long if Inheritance_Tax == "" & Estate_Tax == "" & EIG_Status != "Y" & Top_Rate != .
	}	

	// It must be the highest between the estate and the inheritance top rates
	qui: count if Inheritance_Top_Rate > Estate_Top_Rate & Inheritance_Top_Rate != . & Top_Rate != Inheritance_Top_Rate
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Inh top rate higher but top rate is is the estate rate"
		tab GEO_long if Inheritance_Top_Rate > Estate_Top_Rate & Inheritance_Top_Rate != . & Top_Rate != Inheritance_Top_Rate
	}		
	qui: count if Inheritance_Top_Rate < Estate_Top_Rate & Estate_Top_Rate != . & Top_Rate != Estate_Top_Rate
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' est top rate higher but top rate is is the estate rate"
		tab GEO_long if Inheritance_Top_Rate < Estate_Top_Rate & Estate_Top_Rate != . & Top_Rate != Estate_Top_Rate
	}		
	qui: count if Top_Rate != Inheritance_Top_Rate & Top_Rate != Estate_Top_Rate & (Inheritance_Top_Rate != . | Estate_Top_Rate != .)
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' top rate different from the other rates"
		tab GEO_long if Top_Rate != Inheritance_Top_Rate & Top_Rate != Estate_Top_Rate & (Inheritance_Top_Rate != . | Estate_Top_Rate != .)
	}		

	
************************* 12. Top Rate Lower Bound *****************************

// Can be 0, a positive number, missing
	qui: replace Top_Rate_Class_I_Lower_Bound = "" if Top_Rate_Class_I_Lower_Bound == "." 

// Inadmissible entries check	
	qui: count if Top_Rate_Class_I_Lower_Bound == "_na"
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Top_Rate_Class_I_Lower_Bound == _na"
		tab GEO_long if Top_Rate_Class_I_Lower_Bound == "_na"
	}	

	qui destring Top_Rate_Class_I_Lower_Bound, replace // if no error, okay 
	qui: count if Top_Rate_Class_I_Lower_Bound < 0 
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' negative values for Top_Rate_Class_I_Lower_Bound"
	}
	
// Incompatible entries check		

	// Must be equal to the lower limit of the last bracket 
	sort GEO_long year n
	qui gen lastlb = Adjusted_Class_I_Lower_Bound if year != year[_n+1]
	qui egen last = min(lastlb), by(GEO_long year)
	qui: count if round(Top_Rate_Class_I_Lower_Bound, last) != last & last != .
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' Top_Rate_Class_I_Lower_Bound different from lower bound of last bracket"
		tab GEO_long if round(Top_Rate_Class_I_Lower_Bound, last) != last & last != .
	}


************************* 13. Sources ******************************************
// Check for duplicates and save sources in a separate file
preserve 
	keep Geo year Source*
	qui duplicates drop 
	qui reshape long Source_, i(Geo year) j(nsource)
	drop nsource
	qui duplicates drop
	qui drop if Source_ == ""
	qui drop if Source_ == "."
	qui drop if Source == "OECD_Rev" // for revenues we add it later
	sort Geo year Source_
	qui: bys Geo year: gen n = _n
	qui egen id = group(Geo year)
	qui xtset id n
	qui tsfill, full
	qui xfill Geo year, i(id)
	/// to install xfill 
	// net from https://www.sealedenvelope.com/
	// select xfill
	qui reshape wide Source_, i(Geo year) j(n)
	drop id
	rename Geo GEO
	qui save "$intfile/eigt_taxsched_sources.dta", replace
restore 

// Drop manually inferred data (if OECD_Rev is the ONLY source)
	forvalues i=1/7 {
		replace Source_`i' = "" if Source_`i' == "."
	}
	egen source = concat(Source*)
	drop if strpos(source, "OECD_Rev") & strlen(source) == 8 // 8 characters "OECD_Rev"
	drop source
	

************************* 14. Currency *****************************************

	qui replace Currency = "" if Currency == "."
	qui: count if Currency == ""
	if (`r(N)' != 0) {
		display as error "WARNING: `r(N)' missing Currency"
		tab GEO_long if Currency == ""
	}
preserve 
	keep Geo year Currency 
	duplicates drop 
	rename Currency curren
	rename Geo GEO
	qui save "$intfile/eigt_taxsched_currency.dta", replace
restore 

*** Clean

	keep GEO_long Geo year EIG_Status First_EIG Estate_Tax Gift_Tax Inheritance_Tax Inheritance_Tax_Relation_Based Inheritance_Estate_Exemption Child_Exemption Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound Adjusted_Class_I_Statutory_Margi Gift_Top_Rate Top_Rate Estate_Top_Rate Inheritance_Top_Rate Top_Rate_Class_I_Lower_Bound n first estate_flag

*** Rename and make numeric

	rename (Geo GEO_long first) (GEO GEO_long eigfir)

qui {
	gen eigsta = (EIG_Status == "Y")
	replace eigsta = -999 if EIG_Status == ""
	drop EIG_Status

	replace eigfir = -999 if eigfir == .
	drop First_EIG

	gen esttax = (Estate_Tax == "Y")
	replace esttax = -999 if Estate_Tax == ""
	drop Estate_Tax

	gen giftax = (Gift_Tax == "Y")
	replace giftax = -999 if Gift_Tax == ""
	drop Gift_Tax

	gen inhtax = (Inheritance_Tax == "Y")
	replace inhtax = -999 if Inheritance_Tax == ""
	drop Inheritance_Tax

	gen itaxre = (Inheritance_Tax_Relation_Based == "Y")
	replace itaxre = -999 if Inheritance_Tax_Relation_Based == ""
	replace itaxre = -998 if Inheritance_Tax_Relation_Based == "_na"
	drop Inheritance_Tax_Relation_Based

	gen ieexem = (Inheritance_Estate_Exemption == "Y")
	replace ieexem = -999 if Inheritance_Estate_Exemption == ""
	replace ieexem = -998 if Inheritance_Estate_Exemption == "_na"
	drop Inheritance_Estate_Exemption

	rename (Child_Exemption Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound ///
		Adjusted_Class_I_Statutory_Margi Gift_Top_Rate Top_Rate Estate_Top_Rate ///
		Inheritance_Top_Rate Top_Rate_Class_I_Lower_Bound) ///
		(chiexe ad1lbo ad1ubo ad1smr gtopra toprat etopra itopra torac1)

	foreach var in chiexe ad1lbo ad1ubo ad1smr gtopra toprat etopra itopra torac1 {
		replace `var' = -999 if `var' == .
	} 
}
	rename n bracket
	order GEO GEO_long year eigsta eigfir esttax giftax inhtax itaxre ieexem chiexe ad1lbo ad1ubo ad1smr gtopra toprat etopra itopra torac1 bracket estate_flag

*** Labels 

// Package required, automatic check 
	cap which labvars
	if _rc ssc install labvars	
	
	labvars GEO GEO_long year eigsta eigfir esttax giftax inhtax itaxre ///
			ieexem chiexe ad1lbo ad1ubo ad1smr gtopra toprat etopra itopra torac1 ///
			bracket "Geo" "GEO_long" "year" "EIG_Status" "First_EIG" "Estate_Tax" ///
			"Gift_Tax" "Inheritance_Tax" "Inheritance_Tax_Relation_Based" ///
			"Inheritance_Estate_Exemption" "Child_Exemption" "Adjusted_Class_I_Lower_Bound" ///
			"Adjusted_Class_I_Upper_Bound" "Adjusted_Class_I_Statutory_Marginal_Rate" ///
			"Gift_Top_Rate" "Top_Rate" "Estate_Top_Rate" "Inheritance_Top_Rate" ///
			"Top_Rate_Class_I_Lower_Bound" "n"
		
qui compress
qui save "$intfile/eigt_taxsched_data.dta", replace













