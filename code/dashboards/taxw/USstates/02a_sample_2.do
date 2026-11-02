	
	
	
	sort GeoReg year n

	*** now set all states ready to adjust
	global states "HI" // ask about HI 2020, 2021 example top bracket? also: did 2010 manually
	
	gen add_marker = .
	
	foreach state in $states {
	
	forvalues x= 2018/2019 {
	
		replace Adjusted_Class_I_Lower_Bound = Child_Exemption + Statutory_Class_I_Lower_Bound if year == `x' & GeoReg == "`state'"
		replace Adjusted_Class_I_Upper_Bound = Child_Exemption + Statutory_Class_I_Upper_Bound if year == `x' & GeoReg == "`state'"

	replace add_marker = 1 if year == `x' & year[_n-1] == `x'-1 & GeoReg == "`state'"
	expand 2 if add_marker == 1
	sort GeoReg year n
	
		replace Adjusted_Class_I_Lower_Bound = 0 				if add_marker == 1 & year == `x' & year[_n-1] == `x'-1
		replace Adjusted_Class_I_Upper_Bound = Child_Exemption 	if add_marker == 1 & year == `x' & year[_n-1] == `x'-1
		replace Adjusted_Class_I_Statutory_Margi = 0 			if add_marker == 1 & year == `x' & year[_n-1] == `x'-1
		
		replace Adjusted_Class_I_Upper_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Lower_Bound == (Child_Exemption + Statutory_Class_I_Lower_Bound) & Adjusted_Class_I_Upper_Bound == . & Adjusted_Class_I_Lower_Bound != . & year == `x' & GeoReg == "`state'"
		
		replace Adjusted_Class_I_Lower_Bound = Federal_Effective_Exemption if Adjusted_Class_I_Upper_Bound[_n-1] == Federal_Effective_Exemption & year == `x' & GeoReg == "`state'"
		
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg if Statutory_Class_I_Statutory_Marg != . & Adjusted_Class_I_Statutory_Margi == . & year == `x' & GeoReg == "`state'"
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg + Federal_Effective_Class_I_Statut if Adjusted_Class_I_Statutory_Margi == . & Adjusted_Class_I_Upper_Bound== Federal_Effective_Exemption & year == `x' & GeoReg == "`state'"
		replace Adjusted_Class_I_Statutory_Margi = Federal_Effective_Class_I_Statut + Adjusted_Class_I_Statutory_Margi[_n-1] if Adjusted_Class_I_Lower_Bound == Federal_Effective_Exemption & Adjusted_Class_I_Statutory_Margi == . &  year == `x' & GeoReg == "`state'"
		
		replace add_marker = .
		
	}
	}
	
	
	foreach state in $states {
	
	forvalues x= 2012/2017 {
	
		replace Adjusted_Class_I_Lower_Bound = Child_Exemption + Statutory_Class_I_Lower_Bound if Statutory_Class_I_Lower_Bound != . & year == `x' & GeoReg == "`state'"
		replace Adjusted_Class_I_Upper_Bound = Child_Exemption + Statutory_Class_I_Upper_Bound if Statutory_Class_I_Upper_Bound != . & year == `x' & GeoReg == "`state'"

		replace add_marker = 1 if year == `x' & year[_n-1] == `x'-1 & GeoReg == "`state'"
		expand 2 if add_marker == 1
		sort GeoReg year n
		
		replace Adjusted_Class_I_Lower_Bound = 0 				if add_marker == 1 & year == `x' & year[_n-1] == `x'-1
		replace Adjusted_Class_I_Upper_Bound = Child_Exemption 	if add_marker == 1 & year == `x' & year[_n-1] == `x'-1
		replace Adjusted_Class_I_Statutory_Margi = 0 			if add_marker == 1 & year == `x' & year[_n-1] == `x'-1
		
		replace Adjusted_Class_I_Statutory_Margi = Statutory_Class_I_Statutory_Marg + Federal_Effective_Class_I_Statut if Adjusted_Class_I_Statutory_Margi == . & year == `x' & GeoReg == "`state'"
		replace Adjusted_Class_I_Statutory_Margi = Federal_Effective_Class_I_Statut + Adjusted_Class_I_Statutory_Margi[_n-1] if Adjusted_Class_I_Lower_Bound == Federal_Effective_Exemption & Adjusted_Class_I_Statutory_Margi == . &  year == `x' & GeoReg == "`state'"
		
		replace add_marker = .
		
	}
	}
	
	sort GeoReg year Adjusted_Class_I_Lower_Bound
	
	