	 merge m:1 geo3 using "${intfile}/OECD_members.dta", update gen(_merge4) replace 
	 
	 
	 
	 local revs Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev ///
				Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev ///
				Tot_Rev_GDP Fed_Rev_GDP Reg_Rev_GDP
	
	foreach var of local revs{
		replace `var' = `var'_backup if `var'=="." & _merge==5
		gen `var'_round = subinstr(`var', "0", "",.) if `var'_backup!=""
		gen `var'_round_backup = subinstr(`var'_backup, "0", "",.) if `var'_backup!=""
		destring `var'_round, replace
		destring `var'_round_backup, replace
		
		forvalues p=1/9{
			replace `var'_round = `var'_round/(10^`p') if `var'_round>(10^`p') & `var'_round<((10^`p')*10) & ///
															mem==1
			replace `var'_round_backup = `var'_round_backup/(10^`p') if `var'_round_backup>(10^`p') & ///
																	`var'_round_backup<((10^`p')*10)& ///
																	mem==1
		}
			replace `var'_round = `var'_round/(1000000000) if `var'_round>(1000000000) & mem==1
			replace `var'_round_backup = `var'_round_backup/(1000000000) if `var'_round_backup>(1000000000) & mem==1
			
			tempvar `var'_round1 `var'_round2 `var'_round3 `var'_round4 `var'_round_backup1 ///
					`var'_round_backup2 `var'_round_backup3 `var'_round_backup4 
			
			gen ``var'_round1' = round(`var'_round, 0.001)
			gen ``var'_round_backup1' = round(`var'_round_backup, 0.001)
			
			gen ``var'_round2' = round(`var'_round, 0.01)
			gen ``var'_round_backup2' = round(`var'_round_backup, 0.01)
			
			gen ``var'_round3' = round(`var'_round, 0.1)
			gen ``var'_round_backup3' = round(`var'_round_backup, 0.1)
			
			gen ``var'_round4' = round(`var'_round, 1)
			gen ``var'_round_backup4' = round(`var'_round_backup, 1)

			if ``var'_round1' == ``var'_round_backup1' {
				replace `var' = `var'_backup if mem==1
			} 
			else if ``var'_round2' == ``var'_round_backup2' {
				replace `var' = `var'_backup if mem==1
			}
			else if ``var'_round3' == ``var'_round_backup3' {
				replace `var' = `var'_backup if mem==1
			}
			else if ``var'_round4' == ``var'_round_backup4' {
				replace `var' = `var'_backup if mem==1
			}
					

			
		gen diff_`var' = `var'_round - `var'_round_backup if `var'_round_backup!=. & `var' != `var'_backup
		
	}
	
	local revs Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev ///
				Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev ///
				Tot_Rev_GDP Fed_Rev_GDP Reg_Rev_GDP
				
			foreach var of local revs{
				tab geo3 if `var'=="" & `var'_backup!=""
			}
			
	local revs Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev ///
				Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev ///
				Tot_Rev_GDP Fed_Rev_GDP Reg_Rev_GDP
				
			foreach var of local revs{
				tab geo3 if `var'=="" & country==""
			}
			
	drop if geo3=="OAVG"
	
	drop Tot_Rev_backup-diff_Reg_Rev_GDP
