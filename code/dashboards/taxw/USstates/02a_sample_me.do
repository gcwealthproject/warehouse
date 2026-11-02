
		sort GeoReg year n
		
		
		*** rule after 2013
		global me "year > 2013 & year < 2020 & GeoReg == "ME" "
		
		replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound if Adjusted_Class_I_Lower_Bound == . & $me
		replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound if Adjusted_Class_I_Upper_Bound == . & $me
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi == . & $me
		
		*** rule before 2011
		global me "year < 2012 & GeoReg == "ME" "
		
		replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound if Adjusted_Class_I_Lower_Bound == . & Statutory_Class_I_Lower_Bound >= Child_Exemption & $me
		replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound if Adjusted_Class_I_Upper_Bound == . & Statutory_Class_I_Upper_Bound >= Child_Exemption & $me
		
		replace Adjusted_Class_I_Lower_Bound = Child_Exemption if Adjusted_Class_I_Lower_Bound == . & Adjusted_Class_I_Upper_Bound > Child_Exemption & Adjusted_Class_I_Upper_Bound != . & $me
		replace Adjusted_Class_I_Lower_Bound = 0 if Adjusted_Class_I_Lower_Bound[_n+1]==Child_Exemption & $me
		replace Adjusted_Class_I_Upper_Bound = Child_Exemption if Adjusted_Class_I_Lower_Bound == 0 & $me
		
		replace Adjusted_Class_I_Statutory_Margi = 0 if Adjusted_Class_I_Lower_Bound == 0 & Adjusted_Class_I_Statutory_Margi == . & $me
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi == . & Adjusted_Class_I_Lower_Bound != . & $me
		
		
	*** now add federal schedule
		cap drop federal_marker

		*** generate a tag where bracket adjustment is needed
		gen federal_marker = 1 if (Federal_Effective_Exemption > Adjusted_Class_I_Lower_Bound) & (Federal_Effective_Exemption < Adjusted_Class_I_Upper_Bound) & EIG_Status == "Y" & GeoReg == "ME" & (year != 2012 & year != 2013 & year != 2020 & year != 2021)
	
		*** expand where extra bracket is needed
		expand 2 if federal_marker == 1 & GeoReg == "ME"
		sort GeoReg year Adjusted_Class_I_Lower_Bound
		
		*** replace upper bound with federal threshold in first tagged bracket
		replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound[_n-1] < Federal_Effective_Exemption & (GeoReg == GeoReg[_n-1] & year == year[_n-1]) & federal_marker == 1 & GeoReg == "ME"

		*** replace lower bound with federal threshold in second tagged bracket
		replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound > Federal_Effective_Exemption & federal_marker == 1 & GeoReg == "ME"
		
		*** now add federal tax rate to adjusted rate 
		replace Adjusted_Class_I_Statutory_Margi = Adjusted_Class_I_Statutory_Margi + Federal_Effective_Class_I_Statut if Federal_Effective_Exemption <= Adjusted_Class_I_Lower_Bound & EIG_Status== "Y" & GeoReg == "ME" & (year != 2012 & year != 2013 & year != 2020 & year != 2021)
