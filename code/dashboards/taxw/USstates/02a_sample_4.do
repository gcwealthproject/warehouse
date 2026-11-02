	
	sort GeoReg year Statutory_Class_I_Lower_Bound
	
	replace Adjusted_Class_I_Lower_Bound = . if year == 2021 & GeoReg == "WA"
	replace Adjusted_Class_I_Upper_Bound = . if year == 2021 & GeoReg == "WA"
	replace Adjusted_Class_I_Statutory_Margi = . if year == 2021 & GeoReg == "WA"

		expand 2 if GeoReg == "WA" & year == 2017 & Statutory_Class_I_Lower_Bound == 0, gen(marker)
			replace Statutory_Class_I_Upper_Bound = . if marker == 1
			replace Statutory_Class_I_Lower_Bound = . if marker == 1
			drop marker
			
			drop if year == 2021 & GeoReg == "WA" & Statutory_Class_I_Lower_Bound == . & Federal_Effective_Class_I_Upper_ == .
	
	sort GeoReg year Statutory_Class_I_Lower_Bound
	replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound + Child_Exemption if GeoReg == "WA"
	replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound + Child_Exemption if GeoReg == "WA"
	

	
	replace Adjusted_Class_I_Upper_Bound = Child_Exemption if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Upper_Bound == . & Statutory_Class_I_Lower_Bound == . & Statutory_Class_I_Upper_Bound == . & GeoReg == "WA"
	replace Adjusted_Class_I_Lower_Bound = 0 if Adjusted_Class_I_Upper_Bound == Child_Exemption & Adjusted_Class_I_Lower_Bound == . & GeoReg == "WA"
	replace Adjusted_Class_I_Statutory_Margi = 0 if Adjusted_Class_I_Upper_Bound == Child_Exemption & GeoReg == "WA"
	
	sort GeoReg year Adjusted_Class_I_Lower_Bound
	
	
	expand 2 if GeoReg == "WA" & year != year[_n-1] & Adjusted_Class_I_Lower_Bound == Child_Exemption & year != 2021 , gen(temp_tag)
	replace Adjusted_Class_I_Upper_Bound = Adjusted_Class_I_Lower_Bound if temp_tag == 1	
	replace Adjusted_Class_I_Lower_Bound = 0 if temp_tag == 1
	replace Adjusted_Class_I_Statutory_Margi = 0 if temp_tag == 1
	
	drop temp_tag
	sort GeoReg year Adjusted_Class_I_Lower_Bound

	*** fix 2009 input which is already using exemption
	replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound if year == 2009 & GeoReg == "WA"
	replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound if year == 2009 & GeoReg == "WA"	
	replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if year == 2009 & GeoReg == "WA"
	
	
	*** now add federal brackets
	global states "WA" 
	
	foreach state in $states {
	
	cap drop federal_marker

	*** generate a tag where bracket adjustment is needed
	gen federal_marker = 1 if (Federal_Effective_Exemption > Adjusted_Class_I_Lower_Bound) & (Federal_Effective_Exemption < Adjusted_Class_I_Upper_Bound) & EIG_Status == "Y" & GeoReg == "`state'"
	
	*** expand where extra bracket is needed
	expand 2 if federal_marker == 1 & GeoReg == "`state'"
	sort GeoReg year Adjusted_Class_I_Lower_Bound

	
	*** replace upper bound with federal threshold in first tagged bracket
	replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound[_n-1] < Federal_Effective_Exemption & (GeoReg == GeoReg[_n-1] & year == year[_n-1]) & federal_marker == 1 & GeoReg == "`state'"

	*** replace lower bound with federal threshold in second tagged bracket
	replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound > Federal_Effective_Exemption & federal_marker == 1 & GeoReg == "`state'"
	
	*** now add federal tax rate to adjusted rate 
	replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi == . & GeoReg == "`state'"
	replace Adjusted_Class_I_Statutory_Margi = Adjusted_Class_I_Statutory_Margi + Federal_Effective_Class_I_Statut if Federal_Effective_Exemption <= Adjusted_Class_I_Lower_Bound & Statutory_Class_I_Statutory_Marg != . & EIG_Status== "Y" & GeoReg == "`state'"
	}
	
	