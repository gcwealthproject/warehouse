///--------------///
///  By country  ///
///--------------///

// Scatterplot by country with info (y axis) and time (x axis) coverage of the data
// Estate, Inheritance and Gift Tax

// Last update: May 2026

	*** automatized user paths
	global username "`c(username)'"
	
	dis "$username" // Displays your user name on your computer
		
	* Francesca
	if "$username" == "fsubioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	if "$username" == "Francesca Subioli" | "$username" == "Francesca" | "$username" == "franc" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	* Luca 
	if "$username" == "lgiangregorio" | "$username" == "lucagiangregorio" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}
	
	use "$intfile\taxw_countries_new_ready.dta", clear // Open warehouse data (no regional)

	qui {
	replace GEO_l = strtrim(GEO_l)
	
	foreach tax in e i g t {			
		gen source_rev_imp_`tax' = 1 if substr(varcode, 3, 1) == "`tax'" & source == "Own estimates using OECD_Rev"
		gen source_imp_`tax' = 1 if substr(varcode, 3, 1) == "`tax'" & source ==  "Imputed data"	
		ereplace source_rev_imp_`tax' = max(source_rev_imp_`tax'), by(GEO year)
		ereplace source_imp_`tax' = max(source_imp_`tax'), by(GEO year)		
	}

	drop source percentile longname note

	gen info_spouse = (substr(varcode, 4, 1) == "s" | substr(varcode, 4, 1) == "e") & substr(varcode, 10, 6) == "status" & value == 1
	gen info_siblings = (substr(varcode, 4, 1) == "l" | substr(varcode, 4, 1) == "e") & substr(varcode, 10, 6) == "status" & value == 1
	gen info_othrel = (substr(varcode, 4, 1) == "r" | substr(varcode, 4, 1) == "e")	& substr(varcode, 10, 6) == "status" & value == 1
	gen info_nonrel = (substr(varcode, 4, 1) == "n" | substr(varcode, 4, 1) == "e") & substr(varcode, 10, 6) == "status" & value == 1
	ereplace info_spouse = max(info_spouse), by(GEO year)
	ereplace info_siblings = max(info_siblings), by(GEO year)
	ereplace info_othrel = max(info_othrel), by(GEO year)
	ereplace info_nonrel = max(info_nonrel), by(GEO year)
	
	keep if inlist(substr(varcode, 4, 1), "e", "c", "u") | inlist(substr(varcode, 10, 6), "revenu")	
	
	preserve 
		gen concept = substr(varcode, 10,6)	 
		* Generate the brackets for the reshape
		gen bracket = substr(varcode, -2, 2)		
		replace varcode = substr(varcode, 3,1) 
		
		* Reshapes 
		reshape wide value, i(GEO year concept bracket info*) j(varcode) string
		reshape wide value*, i(GEO year bracket info*) j(concept) string 
		reshape wide value*, i(GEO year info*) j(bracket) string 		

		* Rename the variables 
		rename value* * 
		
		foreach var in e i g t {
			rename `var'* *_`var'
		}
		rename nfo_*_i info_*
		
		* Select the full schedules 	
		foreach var in e i g t {
			gen full_schedule_`var' = (adjmrt01_`var' != . & exempt00_`var' != .) 
			replace full_schedule_`var' = 0 if (adjmrt01_`var' == 0 & adjubo01_`var' < 0)
			replace full_schedule_`var' = 1 if exempt00_`var' == -998 // full-exemption as knowing the exemption 
		}
		keep GEO* year full_schedule* info* source*
		duplicates drop 
		tempfile sched 
		save "`sched'", replace
	restore
	
	foreach tax in e i g t {

		gen status_`tax' = 1 if substr(varcode, 3, 1) == "`tax'" & ///
				substr(varcode, 10, 6) == "status" & value == 1
				
		replace status_`tax' = 0 if substr(varcode, 3, 1) == "`tax'" & ///
				substr(varcode, 10, 6) == "status" & value == 0
		
		gen first_`tax' = value if substr(varcode, 3, 1) == "`tax'" & ///
				substr(varcode, 10, 6) == "firsty"
				
		gen exempt_`tax' = value if substr(varcode, 3, 1) == "`tax'" & ///
				substr(varcode, 10, 6) == "exempt" & value == -997
		
		gen diftax_`tax' = 1 if substr(varcode, 3, 1) == "`tax'" ///
			& substr(varcode, 10, 6) == "diftax" & value == 1	
			
		gen whether_exempt_`tax' = 1 if substr(varcode, 3, 1) == "`tax'" & ///
				substr(varcode, 10, 6) == "exempt"	

		gen whether_toprat_`tax' = 1 if substr(varcode, 3, 1) == "`tax'" & ///
				substr(varcode, 10, 6) == "toprat"	
		gen status_revenue_`tax' = 1 if substr(varcode, 3, 1) == "`tax'" & ///
				substr(varcode, 10, 6) == "revenu" & value > 0 & value < .
		replace status_revenue_`tax' = 0 if substr(varcode, 3, 1) == "`tax'" & ///
				substr(varcode, 10, 6) == "revenu" & value == 0
	}		
	merge m:1 GEO year using "`sched'", nogen 
	
	keep GEO* year *_i *_e *_g *_t info* 
	duplicates drop 
	collapse (min) *_i *_e *_g *_t info*, by(GEO* year)
	sort GEO year		   

	foreach tax in e i g t {
		replace whether_exempt_`tax' = . if status_`tax' == 0
		replace whether_toprat_`tax' = . if status_`tax' == 0
		replace full_schedule_`tax' = . if status_`tax' == 0
}

	* Reshape
	reshape long status whether_exempt whether_toprat full_schedule status_revenue, i(GEO* year) j(tax) string 
	replace tax = substr(tax, 2, 1)
	
	foreach tax in e i g t {
		foreach var in status whether_exempt whether_toprat full_schedule status_revenue {
			preserve
				keep GEO* year tax `var' diftax_`tax' exempt_`tax' first_`tax' info* source*_`tax'
				keep if tax == "`tax'"
				gen variable = "`tax'_`var'"
				rename `var' value
				tempfile `tax'_`var'
				save "``tax'_`var''", replace
			restore
		}
	}
	clear 
	foreach tax in e i g t {
		foreach var in status whether_exempt whether_toprat full_schedule status_revenue {
			append using "``tax'_`var''"
		}
	}
	sort GEO year tax
	
	foreach var in spouse siblings othrel nonrel {
	preserve 
		keep GEO* year info* 
		duplicates drop
		gen variable = "info_`var'"
		rename info_`var' value
		keep GEO* year variable value 
		tempfile `var' 
		save "``var''", replace 
	restore
	}
	
	gen vars = 1 if variable == "i_status"
	replace vars = 2 if variable == "i_whether_exempt"
	replace vars = 3 if variable == "i_whether_toprat"
	replace vars = 4 if variable == "i_full_schedule"
	replace vars = 5 if variable == "e_status"
	replace vars = 6 if variable == "e_whether_exempt"
	replace vars = 7 if variable == "e_whether_toprat"
	replace vars = 8 if variable == "e_full_schedule"
	replace vars = 9 if variable == "g_status"
	replace vars = 10 if variable == "g_whether_exempt"
	replace vars = 11 if variable == "g_whether_toprat"
	replace vars = 12 if variable == "g_full_schedule"
	replace vars = 13 if variable == "t_status_revenue"
	
	foreach var in spouse siblings othrel nonrel {
		append using "``var''"
	}
	gen variable_code = variable
	
	replace vars = 14 if variable == "info_spouse"	
	replace vars = 15 if variable == "info_siblings"	
	replace vars = 16 if variable == "info_othrel"	
	replace vars = 17 if variable == "info_nonrel"		
	
	replace variable = "Inheritance Tax Status" if variable == "i_status"
	replace variable = "Inheritance Tax Exemption Threshold" if variable == "i_whether_exempt"
	replace variable = "Inheritance Tax Top Rate" if variable == "i_whether_toprat"
	replace variable = "Inheritance Tax Schedule" if variable == "i_full_schedule"
	replace variable = "Estate Tax Status" if variable == "e_status"
	replace variable = "Estate Tax Exemption Threshold" if variable == "e_whether_exempt"
	replace variable = "Estate Tax Top Rate" if variable == "e_whether_toprat"
	replace variable = "Estate Tax Schedule" if variable == "e_full_schedule"
	replace variable = "Gift Tax Status" if variable == "g_status"
	replace variable = "Gift Tax Exemption Threshold" if variable == "g_whether_exempt"
	replace variable = "Gift Tax Top Rate" if variable == "g_whether_toprat"
	replace variable = "Gift Tax Schedule" if variable == "g_full_schedule"
	replace variable = "EIG Tax Revenues" if variable == "t_status_revenue"	
	replace variable = "Tax details (Spouse)" if variable == "info_spouse"	
	replace variable = "Tax details (Siblings)" if variable == "info_siblings"	
	replace variable = "Tax details (Other Relatives)" if variable == "info_othrel"	
	replace variable = "Tax details (Non Relatives)" if variable == "info_nonrel"	
	
	labmask vars, values(variable)

	keep if substr(GEO, 3, 1) != ","
	sort GEO_l year

	gen label = "✓"
	}

	qui levelsof GEO_l, local(levels)

	foreach l of local levels {
		preserve
			qui keep if GEO_l == "`l'"
			
			display "`l'"
			
			qui {
			* Safe version of the name for exporting
			local safe = "`l'"
			local safe : subinstr local safe " " "_" , all
			local safe : subinstr local safe "," "" , all
			local safe : subinstr local safe "." "" , all
			local safe : subinstr local safe "(" "" , all
			local safe : subinstr local safe ")" "" , all
			local safe : subinstr local safe "'" "" , all
			local safe : subinstr local safe "/" "_" , all
			local safe : subinstr local safe "\" "_" , all

			qui levelsof year, local(years)
			local n : word count `years'
			if (`n' > 50) local n = 50

			qui count if variable_code == "i_status" & value < .
			local has_i = r(N) > 0

			qui count if variable_code == "e_status" & value < .
			local has_e = r(N) > 0

			qui count if variable_code == "g_status" & value < .
			local has_g = r(N) > 0

			gen any_status = 1 if (inlist(variable_code, "i_status", "e_status", "g_status") & value == 1)
			replace any_status = 0 if variable_code == "i_status" & value == 0 | variable_code == "e_status" & value == 0 | variable_code == "g_status" & value == 0
			replace any_status = 1 if exempt_i == -997 | exempt_e == -997 | exempt_g == -997
						
			bys year: ereplace any_status = max(any_status)
					
			gen status_specific = .
			replace status_specific = value if variable_code == "i_status"
			replace status_specific = value if variable_code == "e_status"
			replace status_specific = value if variable_code == "g_status"

			bys year: ereplace status_specific = max(status_specific)

			gen status_i = value if variable_code == "i_status"
			gen status_e = value if variable_code == "e_status"
			gen status_g = value if variable_code == "g_status"

			bys year: ereplace status_i = max(status_i)
			bys year: ereplace status_e = max(status_e)
			bys year: ereplace status_g = max(status_g)

			gen vars_plot = .

			replace vars_plot = 1  if variable_code == "i_status"
			replace vars_plot = 2  if variable_code == "i_whether_exempt"
			replace vars_plot = 3  if variable_code == "i_whether_toprat"
			replace vars_plot = 4  if variable_code == "i_full_schedule"
			replace vars_plot = 5  if variable_code == "e_status"
			replace vars_plot = 6  if variable_code == "e_whether_exempt"
			replace vars_plot = 7  if variable_code == "e_whether_toprat"
			replace vars_plot = 8  if variable_code == "e_full_schedule"
			replace vars_plot = 9  if variable_code == "g_status"
			replace vars_plot = 10 if variable_code == "g_whether_exempt"
			replace vars_plot = 11 if variable_code == "g_whether_toprat"
			replace vars_plot = 12 if variable_code == "g_full_schedule"
			replace vars_plot = 13 if variable_code == "t_status_revenue"
			replace vars_plot = 14 if variable_code == "info_spouse"
			replace vars_plot = 15 if variable_code == "info_siblings"
			replace vars_plot = 16 if variable_code == "info_othrel"
			replace vars_plot = 17 if variable_code == "info_nonrel"

			keep if vars_plot < .
			labmask vars_plot, values(variable)

			local dotstyle    msymbol(i)  mlabel(label) mlabposition(0) mlabsize(tiny) mlabcolor(black)
			local emptystyle  msymbol(oh) msize(small) mlwidth(vthin) color(teal)
			local fullstyle   msymbol(o)  msize(small) col(purple)
			local firststyle  msymbol(dh) msize(medium) col(purple)
			local diffstyle msymbol(X) msize(medium) col(teal)
			local revimpstyle  msymbol(Sh)  msize(small) col(orange)
			local impstyle     msymbol(Sh)  msize(small) col(orange)

			global opt legend(order(2 "Yes (Tax exists/Positive revenues)" 3 "No (No tax/Zero revenues)" 4 "Yes - fully exempted children" 5 "No - different tax applicable"  1 "Introduction" 8 "✓ Information available" 6 "Implied/Imputed data") rows(2) pos(12) colfirst size(vsmall) region(lcolor(white))) plotreg(lcol(black) lpatt(solid) lalig(outside))
			
			twoway ///
				(scatter vars_plot year if vars_plot == 1 & year == first_i, `firststyle') ///
				(scatter vars_plot year if vars_plot == 1 & value == 1, `fullstyle') ///
				(scatter vars_plot year if vars_plot == 1 & value == 0 & exempt_i != -997, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 1 & value == 0 & exempt_i == -997, msymbol(o) msize(small) mlw(vthin) col(teal)) ///
				(scatter vars_plot year if vars_plot == 1 & value == 0 & diftax_i == 1, `diffstyle') ///								
				(scatter vars_plot year if vars_plot == 1 & source_rev_imp_i == 1, `revimpstyle') ///
				(scatter vars_plot year if vars_plot == 1 & source_imp_i == 1, `impstyle') ///				
				(scatter vars_plot year if vars_plot == 2 & value == 1 & status_i == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 2 & status_i == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 3 & value == 1 & status_i == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 3 & status_i == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 4 & value == 1 & status_i == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 4 & status_i == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 5 & year == first_e, `firststyle') ///
				(scatter vars_plot year if vars_plot == 5 & value == 1, `fullstyle') ///
				(scatter vars_plot year if vars_plot == 5 & value == 0 & exempt_e != -997, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 5 & value == 0 & exempt_e == -997, msymbol(o) msize(small) mlw(vthin) col(teal)) ///
				(scatter vars_plot year if vars_plot == 5 & value == 0 & diftax_e == 1, `diffstyle') ///	
				(scatter vars_plot year if vars_plot == 5 & source_rev_imp_e == 1, `revimpstyle') ///
				(scatter vars_plot year if vars_plot == 5 & source_imp_e == 1, `impstyle') ///								
				(scatter vars_plot year if vars_plot == 6 & value == 1 & status_e == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 6 & status_e == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 7 & value == 1 & status_e == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 7 & status_e == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 8 & value == 1 & status_e == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 8 & status_e == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 9 & year == first_g, `firststyle') ///
				(scatter vars_plot year if vars_plot == 9 & value == 1, `fullstyle') ///
				(scatter vars_plot year if vars_plot == 9 & value == 0 & exempt_g != -997, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 9 & value == 0 & exempt_g == -997, msymbol(o) msize(small) mlw(vthin) col(teal)) ///
				(scatter vars_plot year if vars_plot == 9 & value == 0 & diftax_g == 1, `diffstyle') ///	
				(scatter vars_plot year if vars_plot == 9 & source_rev_imp_g == 1, `revimpstyle') ///
				(scatter vars_plot year if vars_plot == 9 & source_imp_g == 1, `impstyle') ///								
				(scatter vars_plot year if vars_plot == 10 & value == 1 & status_g == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 10 & status_g == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 11 & value == 1 & status_g == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 11 & status_g == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 12 & value == 1 & status_g == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 12 & status_g == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 13 & value == 1, `fullstyle') ///
				(scatter vars_plot year if vars_plot == 13 & value == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 14 & value == 1 & any_status == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 14 & any_status == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 15 & value == 1 & any_status == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 15 & any_status == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 16 & value == 1 & any_status == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 16 & any_status == 0, `emptystyle') ///
				(scatter vars_plot year if vars_plot == 17 & value == 1 & any_status == 1, `dotstyle') ///
				(scatter vars_plot year if vars_plot == 17 & any_status == 0, `emptystyle') ///
			, xtick(#`n', grid glpattern(solid)) ///
			  ylab(1(1)17, valuelabel labsize(tiny) grid glpattern(solid)) ///
			  ysc(reverse) ///
			  yscale(noextend) ///
			  xscale(noextend) ///
			  ysize(26) ///
			  xsize(50) ///
			  xtitle("") ///
			  ytitle("") ///
			  xlabel(#`n', angle(90) nogrid labsize(tiny)) ///
			  $opt ///
			  title("", size(small)) ///
			  yline(4.5,  lpatt(solid)) ///
			  yline(8.5,  lpatt(solid)) ///
			  yline(12.5, lpatt(solid)) ///
			  yline(13.5, lpatt(solid))
			  
			cap mkdir "$dir/raw_data/taxw/country_sheets/data_coverage/`l'"
			qui graph export "$dir/raw_data/taxw/country_sheets/data_coverage/`l'/coverage_`l'.pdf", as(pdf) replace
		}
		restore		
	}