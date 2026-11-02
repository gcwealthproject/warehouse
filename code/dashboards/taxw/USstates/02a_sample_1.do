	
	
	
	
	
	
	
	cap drop federal_marker
	gen federal_marker = .	
	sort GeoReg year n
	
	*** empty exemplary schedule
	replace Adjusted_Class_I_Lower_Bound = . if year == 2017 & GeoReg == "DE"
	replace Adjusted_Class_I_Upper_Bound = . if year == 2017 & GeoReg == "DE"
	replace Adjusted_Class_I_Statutory_Margi = . if year == 2017 & GeoReg == "DE"
	
	global states "DE NC"
	
	foreach state in $states {
		
		*** fill up adjusted info with statutory info
		replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound if Adjusted_Class_I_Upper_Bound == . & GeoReg == "`state'"
		replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound if Adjusted_Class_I_Lower_Bound == . & GeoReg == "`state'"
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi == . & GeoReg == "`state'"
		
		*** generate a tag where bracket adjustment is needed
		replace federal_marker = 1 if (Federal_Effective_Exemption > Adjusted_Class_I_Lower_Bound) & (Federal_Effective_Exemption < Adjusted_Class_I_Upper_Bound) & EIG_Status == "Y" & GeoReg == "`state'"
		
		*** get rid of exemplary manual coded top rate
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi > Federal_Effective_Class_I_Statut & GeoReg == "`state'"	
		
		*** integrate federal schedule, all brackets below federal exemption are exempted
		replace Adjusted_Class_I_Lower_Bound = 0 if federal_marker[_n+1] == 1 & (GeoReg == GeoReg[_n+1] & year == year[_n+1]) & GeoReg == "`state'"
		replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if federal_marker[_n+1] == 1 & (GeoReg == GeoReg[_n+1] & year == year[_n+1]) & GeoReg == "`state'"
		replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if federal_marker == 1 & (GeoReg == GeoReg[_n+1] & year == year[_n+1]) & GeoReg == "`state'"
		replace Adjusted_Class_I_Statutory_Margi = Federal_Effective_Class_I_Statut + Adjusted_Class_I_Statutory_Margi if Adjusted_Class_I_Upper_Bound > Federal_Effective_Exemption & GeoReg == "`state'" & EIG_Status == "Y" 
		replace Adjusted_Class_I_Statutory_Margi = 0 if federal_marker[_n+1] == 1 & (GeoReg == GeoReg[_n+1] & year == year[_n+1]) & GeoReg == "`state'"
		replace Adjusted_Class_I_Lower_Bound = . if Adjusted_Class_I_Upper_Bound < Federal_Effective_Exemption & GeoReg == "`state'"
		replace Adjusted_Class_I_Statutory_Margi = . if Adjusted_Class_I_Upper_Bound < Federal_Effective_Exemption & GeoReg == "`state'"	
		replace Adjusted_Class_I_Upper_Bound = . if Adjusted_Class_I_Upper_Bound < Federal_Effective_Exemption & GeoReg == "`state'"
	
	
	*** get rid of empty reduced brackets	
	drop if Adjusted_Class_I_Statutory_Margi == . & GeoReg == "`state'"
	}
	
	
	
	
	sort GeoReg year n
	
	*** KY and IA exempt direct heirs
	foreach var in Exemption Class_I_Lower Class_I_Upper Class_I_Stat {
		replace Adjusted_`var' = Federal_Effective_`var' if GeoReg == "KY" | GeoReg == "IA"
		replace Adjusted_Class_I_Statutory_Margi = 0 if Adjusted_Class_I_Lower_Bound == 0 & (GeoReg == "KY" | GeoReg == "IA")
	}
	
	sort GeoReg year n	
	
	*** set states to adjust I: fill adjusted from statutory information before accounting for federal schedule 
	global states_1  "CT DC IN TN OH"
	
	foreach state in $states_1 {
		
		replace Adjusted_Exemption = Child_Exemption if Adjusted_Exemption == . & Child_Exemption != . & GeoReg == "`state'"
		replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound if Adjusted_Class_I_Lower_Bound == . & Statutory_Class_I_Lower_Bound != . & GeoReg == "`state'"
		replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound if Adjusted_Class_I_Upper_Bound == . & Statutory_Class_I_Upper_Bound != . & GeoReg == "`state'"
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi == . & Statutory_Class_I_Statutory_Marg != . & GeoReg == "`state'"

	}
	
	
	cap drop federal_marker
	gen federal_marker = .	

	sort GeoReg year n
	*** now set all states ready to adjust
	global states "CT DC IN TN OH" /// also ME?
	
	foreach state in $states {

	*** generate a tag where bracket adjustment is needed
	replace federal_marker = 1 if (Federal_Effective_Exemption > Adjusted_Class_I_Lower_Bound) & (Federal_Effective_Exemption < Adjusted_Class_I_Upper_Bound) & EIG_Status == "Y" & GeoReg == "`state'"
	
	*** expand where extra bracket is needed
	expand 2 if federal_marker == 1 & GeoReg == "`state'"
	sort GeoReg year n
	
	
	*** replace upper bound with federal threshold in first tagged bracket
	replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound[_n-1] < Federal_Effective_Exemption & (GeoReg == GeoReg[_n-1] & year == year[_n-1]) & federal_marker == 1 & GeoReg == "`state'"

	
	*** replace lower bound with federal threshold in second tagged bracket
	replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound > Federal_Effective_Exemption & federal_marker == 1 & GeoReg == "`state'"

	*** get rid of exemplary manual coded top rate
	replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi > Federal_Effective_Class_I_Statut & Statutory_Class_I_Statutory_Marg != . & GeoReg == "`state'"	
		
	
	*** now add federal tax rate to adjusted rate 
	replace Adjusted_Class_I_Statutory_Margi = Adjusted_Class_I_Statutory_Margi + Federal_Effective_Class_I_Statut if Federal_Effective_Exemption <= Adjusted_Class_I_Lower_Bound & Statutory_Class_I_Statutory_Marg != . & EIG_Status== "Y" & GeoReg == "`state'"
	}
	
	
	
	
	