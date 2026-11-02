	
	
	*** New Jersey
		* inheritance tax not on close relatives 
		* estate tax repealed 2018 and onwards
		
		
	*** unclear about exemption integration with tax spike in second bracket

		sort GeoReg year n
			
			
		replace Adjusted_Class_I_Upper_Bound = Statutory_Class_I_Upper_Bound if Adjusted_Class_I_Upper_Bound == . & GeoReg == "NJ" & year < 2017
		replace Adjusted_Class_I_Lower_Bound = Statutory_Class_I_Lower_Bound if Adjusted_Class_I_Lower_Bound == . & GeoReg == "NJ" & year < 2017
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Adjusted_Class_I_Statutory_Margi == . & GeoReg == "NJ" & year < 2017
		
		
	*** now add federal schedule
		cap drop federal_marker

		*** generate a tag where bracket adjustment is needed
		gen federal_marker = 1 if (Federal_Effective_Exemption > Adjusted_Class_I_Lower_Bound) & (Federal_Effective_Exemption < Adjusted_Class_I_Upper_Bound) & EIG_Status == "Y" & GeoReg == "NJ" & year < 2017
	
		*** expand where extra bracket is needed
		expand 2 if federal_marker == 1 & GeoReg == "NJ"
		sort GeoReg year Adjusted_Class_I_Lower_Bound
		
		*** replace upper bound with federal threshold in first tagged bracket
		replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound[_n-1] < Federal_Effective_Exemption & (GeoReg == GeoReg[_n-1] & year == year[_n-1]) & federal_marker == 1 & GeoReg == "NJ"

		*** replace lower bound with federal threshold in second tagged bracket
		replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound > Federal_Effective_Exemption & federal_marker == 1 & GeoReg == "NJ"
		
		*** now add federal tax rate to adjusted rate 
		replace Adjusted_Class_I_Statutory_Margi = Adjusted_Class_I_Statutory_Margi + Federal_Effective_Class_I_Statut if Federal_Effective_Exemption <= Adjusted_Class_I_Lower_Bound & EIG_Status== "Y" & GeoReg == "NJ" & year < 2017
