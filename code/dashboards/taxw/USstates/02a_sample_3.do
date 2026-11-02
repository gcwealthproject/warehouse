*br GeoReg year EIG_Status Adjusted* Federal* Statutory* Child_Exemption federal_marker if GeoReg == "VT"


	sort GeoReg year n
	*** set states to adjust I: fill adjusted from statutory information before accounting for federal schedule 
	global states_1  "MA NY RI VT" // MN might work here too

	*** empty examplary schedule 
	replace Adjusted_Class_I_Lower_Bound = . if year >= 2020 & (GeoReg == "NY" | GeoReg == "RI")
	replace Adjusted_Class_I_Upper_Bound = . if year >= 2020 & (GeoReg == "NY" | GeoReg == "RI")
	replace Adjusted_Class_I_Statutory_Margi = . if year >= 2020 & (GeoReg == "NY" | GeoReg == "RI")
	
	replace Adjusted_Class_I_Lower_Bound = . if (year == 2015 | year == 2021) & GeoReg == "VT"
	replace Adjusted_Class_I_Upper_Bound = . if (year == 2015 | year == 2021) & GeoReg == "VT"
	replace Adjusted_Class_I_Statutory_Margi = . if (year == 2015 | year == 2021) & GeoReg == "VT"
	
	sort GeoReg year Statutory_Class_I_Lower_Bound
	
	foreach state in $states_1 {
		
		cap drop temp_marker 
		cap drop federal_marker 
		
		replace Adjusted_Exemption = Child_Exemption if Adjusted_Exemption == . & Child_Exemption != . & GeoReg == "`state'"
		replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound if Adjusted_Class_I_Lower_Bound == . & Statutory_Class_I_Lower_Bound != . & GeoReg == "`state'"
		replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound if Adjusted_Class_I_Upper_Bound == . & Statutory_Class_I_Upper_Bound != . & GeoReg == "`state'"
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi == . & Statutory_Class_I_Statutory_Marg != . & GeoReg == "`state'"
		
gen federal_marker = 1 if (Federal_Effective_Exemption > Adjusted_Class_I_Lower_Bound) & (Federal_Effective_Exemption < Adjusted_Class_I_Upper_Bound) & EIG_Status == "Y" & GeoReg == "`state'"

	*** expand where extra bracket is needed
	expand 2 if federal_marker == 1 & GeoReg == "`state'"
	sort GeoReg year Statutory_Class_I_Lower_Bound
	
		
	*** replace upper bound with federal threshold in first tagged bracket
	replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound[_n-1] < Federal_Effective_Exemption & (GeoReg == GeoReg[_n-1] & year == year[_n-1]) & federal_marker == 1 & GeoReg == "`state'"

	
	*** replace lower bound with federal threshold in second tagged bracket
	replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound > Federal_Effective_Exemption & federal_marker == 1 & GeoReg == "`state'"

	*** get rid of exemplary manual coded top rate
	replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi > Federal_Effective_Class_I_Statut & Statutory_Class_I_Statutory_Marg != . & GeoReg == "`state'"	
		
	
	*** now add federal tax rate to adjusted rate 
	replace Adjusted_Class_I_Statutory_Margi = Adjusted_Class_I_Statutory_Margi + Federal_Effective_Class_I_Statut if Federal_Effective_Exemption <= Adjusted_Class_I_Lower_Bound & Statutory_Class_I_Statutory_Marg != . & EIG_Status== "Y" & GeoReg == "`state'"
	
	
	*** set values below state exemption to missing
	gen temp_marker = 1 if Adjusted_Class_I_Upper_Bound > Child_Exemption & Adjusted_Class_I_Lower_Bound < Child_Exemption
	
	replace Adjusted_Class_I_Statutory_Margi = . if Adjusted_Class_I_Upper_Bound < Child_Exemption & GeoReg == "`state'"
	replace Adjusted_Class_I_Lower_Bound = . if Adjusted_Class_I_Upper_Bound < Child_Exemption & GeoReg == "`state'"
	replace Adjusted_Class_I_Upper_Bound = . if Adjusted_Class_I_Upper_Bound < Child_Exemption & GeoReg == "`state'"
	
	replace Adjusted_Class_I_Lower_Bound = Child_Exemption if temp_marker == 1 & GeoReg == "`state'"
	replace Adjusted_Class_I_Lower_Bound = 0 if Adjusted_Class_I_Lower_Bound[_n+1] == Child_Exemption & GeoReg == "`state'"
	replace Adjusted_Class_I_Upper_Bound = Child_Exemption if Adjusted_Class_I_Lower_Bound == 0 & GeoReg == "`state'"
	replace Adjusted_Class_I_Statutory_Margi = 0 if Adjusted_Class_I_Upper_Bound == Child_Exemption & GeoReg == "`state'"
	
	}
		
		
		
		
	