


	sort GeoReg year n
	*** get rid of exemplary schedule
	replace Adjusted_Class_I_Statutory_Margi = . if year == 2021 & GeoReg == "IL"
	replace Adjusted_Class_I_Lower_Bound = . if year == 2021 & GeoReg == "IL"
	replace Adjusted_Class_I_Upper_Bound = . if year == 2021 & GeoReg == "IL"

	replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound if Statutory_Class_I_Lower_Bound > Child_Exemption & GeoReg == "IL"
	replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound if Statutory_Class_I_Upper_Bound > Child_Exemption & GeoReg == "IL"
	
	
	replace Adjusted_Class_I_Lower_Bound = 0 if Adjusted_Class_I_Upper_Bound != . & Adjusted_Class_I_Lower_Bound == . & GeoReg == "IL"
	
	replace Adjusted_Class_I_Statutory_Margi = 0 if Adjusted_Class_I_Lower_Bound == 0 & GeoReg == "IL"
	replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Lower_Bound != 0 & Adjusted_Class_I_Lower_Bound != . & GeoReg == "IL"
	
	*** generate a tag where bracket adjustment is needed
	replace federal_marker = 1 if (Federal_Effective_Exemption > Adjusted_Class_I_Lower_Bound) & (Federal_Effective_Exemption < Adjusted_Class_I_Upper_Bound) & EIG_Status == "Y" & GeoReg == "IL"
	
	*** expand where extra bracket is needed
	expand 2 if federal_marker == 1 & GeoReg == "IL"
	sort GeoReg year n	
	
	
	*** take care of brackets when federal kicks in first
	replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Statutory_Margi == 0 & Adjusted_Class_I_Statutory_Margi[_n+1] == 0 & federal_marker == 1 & GeoReg == "IL"
	replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Lower_Bound[_n-1] == 0 & federal_marker == 1 & GeoReg == "IL"
	
	
	
	
	
	replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound[_n-1] < Federal_Effective_Exemption & (GeoReg == GeoReg[_n-1] & year == year[_n-1]) & federal_marker == 1 & GeoReg == "IL"
	replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound > Federal_Effective_Exemption & federal_marker == 1 & GeoReg == "IL"
	replace Adjusted_Class_I_Statutory_Margi = Adjusted_Class_I_Statutory_Margi + Federal_Effective_Class_I_Statut if Federal_Effective_Exemption <= Adjusted_Class_I_Lower_Bound & Adjusted_Class_I_Statutory_Margi != . & GeoReg == "IL"
	
	
	
	