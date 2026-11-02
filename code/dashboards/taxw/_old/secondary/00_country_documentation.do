********************************************************************************
*** EIG data: automated country documentation 
********************************************************************************


	clear all
	
	set maxvar 32000
	
	****************************************************************************
	*** automatized user paths
	global username "`c(username)'"
	
		dis "$username" // Displays your user name on your computer

		
		* Manuel
			if "$username" == "manuelstone" { 
				global db  "/Users/manuelstone/Dropbox" 
			}
		
		* Manuel office
			if "$username" == "mschechtl" { 
				global db  "/Users/mschechtl/Dropbox" 
			}
		
		* Twisha
			if "$username" == "twishaasher" { 
				global db  "/Users/twishaasher/Dropbox (Hunter College)" 
			}
			
		* Francesca
			if "$username" == "Francesca Subioli" { 
				global db  "/Users/Francesca Subioli/Dropbox" 
			}

		* Francesca office
			if "$username" == "fsubioli" { 
				global db  "/Users/fsubioli/Dropbox" 
			}
			
		** New Folder:
			global nf "$db/gcwealth"
			
			** Intermediate Tables
				global it "$nf/raw_data/eigt/intermediary_files"
				
			** Handmade Tables
				global ht "$nf/handmade_tables"
				
		** Old folder: 
			global of "$db/THE_GC_WEALTH_PROJECT_website"
			
			** Old EIG: 
				global oeig "$of/EIG Taxes"
				
			** Doc output folder
				global fin "$oeig/03_data_output/01_warehouse"
	
	   
	****************************************************************************
	
	*** use wide visualization file
		import delimited "$it/EIGtax_wide_visualization.dta", clear 
	
	
	*** set up data 
		*** download country codes
			preserve
			
				import excel "$ht/dictionary.xlsx", sheet("GEO") ///
							cellrange(A1:C251) firstrow case(lower) clear
					qui rename geo area
				save "$it/country_codes.dta", replace
			restore
		
			merge m:1 area using "$it/country_codes.dta"
			
			
		*** Merge source legend and key	
			
			preserve
			
				forvalues s=1/7{
					import excel "$ht/dictionary.xlsx", sheet("Sources") ///
							cellrange(C1:H545) firstrow case(lower) clear
						qui rename  source source`s'
						qui rename  legend legend`s'
					save "$it/source`s'_codes.dta", replace
				}
				
					
			restore
			
		
			forvalues s=1/7{
				cap drop _merge
				merge m:1 source`s' using "$it/source`s'_codes.dta"
				*drop if _merge==2
			}

		
		
	*** prepare data 
	
		*** Drop missing & state observations
			qui drop if area==""
			
			qui gen state = substr(area, -2,2)
			qui drop if state!=area
			

				
		*** retrieve bracket numbers
			qui gen bracket = substr(varcode, -2,2)
	

	*** get summary statistics
		
		*** WITHOUT EIG
			*** YEARS
				levelsof country, local(geolist)
				cap drop yrsnoeig
				qui gen yrsnoeig=""
				
					qui foreach c in `geolist' {
						levelsof year if country == "`c'" & ///
										varcode == "x-hs-cat-eigsta-00" & ///
										value_string == "N", /// 
											clean sep(,) local(noeigst)
			
						local ne_all "`noeigst'"
						local ne_all : list uniq ne_all
			
						qui replace yrsnoeig = `"`ne_all'"' if country == "`c'"
					}	
			
				qui replace yrsnoeig = subinstr(yrsnoeig, " ", ",", .)
				qui replace yrsnoeig = subinstr(yrsnoeig, ",", ", ", .)

			


		*** SOURCES
			qui gen leg_sources = ""
		
			levelsof country, local(geolist)
		
				qui foreach c in `geolist' { // countries
					qui forvalues i = 1/7 { // source1-7
						levelsof legend`i' if country == "`c'" & ///
												source`i' != "." & ///
												source`i' != "", ///
													clean sep(,) local(s`i')
					}
					* Local list for all unique sources
						local s_all "`s1' `s2' `s3' `s4' `s5' `s6' `s7'"
						*local s_all : list uniq s_all
					
					* Replace blank variable with 
						qui replace leg_sources  = `"`s_all'"' if country == "`c'"
				}
				
				qui replace leg_sources = subinstr(leg_sources, ",", ", ", .)
				
				*qui replace sources = "\@" + sources
				*qui replace sources = "" + sources + "'"
	

	
		*** YEARS WITH EIG
			
			qui gen eigstayears = ""

			
			sort country year bracket
		
				qui foreach c in `geolist' {
					levelsof year if country == "`c'" & ///
									varcode == "x-hs-cat-eigsta-00" & ///
									value_string == "Y" , ///
										clean sep(,) local(eigst)
			
				local e_all "`eigst'"
				local e_all : list uniq e_all
			
				qui replace eigstayears = `"`e_all'"' if country == "`c'"
			}	
			
			qui replace eigstayears = subinstr(eigstayears, ",", ", ", .)

					 
		*** YEARS WITH TOP RATE>0
			
			qui gen topratyears = ""
			
			*levelsof country, local(geolist)
			qui foreach c in `geolist' {
				levelsof year if country == "`c'" & ///
									varcode == "x-hs-rat-toprat-00" & ///
									value_string != "0" , ///
										clean sep(,) local(toprat)
			
				local t_all "`toprat'"
				local t_all : list uniq t_all
			
				qui replace topratyears = `"`t_all'"' if country == "`c'"
			}			 	
			
			qui replace topratyears = subinstr(topratyears, ",", ", ", .)
			
			


		*** YEARS WITH CHILD EXEMPTION	
			levelsof country, local(geolist)
			cap drop childex
			qui gen childex = ""
			
			qui foreach c in `geolist' {
				levelsof year if country == "`c'" & ///
								varcode == "x-hs-thr-chiexe-00" & ///
								value_string !="_na" & value_string !=".", ///
									clean sep(,) local(chiex)
					
				local chiex_all "`chiex'"
				local chiex_all : list uniq chiex_all
				
				qui replace childex = `"`chiex_all'"' if country == "`c'"
			}
			
			qui replace childex = subinstr(childex, ",", ", ", .)
			
					
					

		*** YEARS WITH CLASS I EXEMPTION	
		
			*encode value_string if varcode == "x-hs-thr-cl1exe-00", generate(cl1exemption)
			levelsof country, local(geolist)
			cap drop cl1ex
			qui gen cl1ex = ""
			
			qui foreach c in `geolist' {
				levelsof year if country == "`c'" & ///
								varcode == "x-hs-thr-cl1exe-00" & ///
								value_string !="_na", ///
									clean sep(,) local(cl1ex)
					
				local cl1ex_all "`cl1ex'"
				local cl1ex_all : list uniq cl1ex_all
				
				qui replace cl1ex = `"`cl1ex_all'"' if country == "`c'"
			}
			
			qui replace cl1ex = subinstr(cl1ex, ",", ", ", .)


		*** YEARS WITH STAT SCHEDULE	
			cap drop statsched			
			qui gen statsched = ""

			levelsof country, local(geolist)
			 foreach c in `geolist' {
				levelsof year if country == "`c'" & ///
								((varcode == "x-hs-rat-se1tsm-01" & ///
										value_string != "0")| ///
								(varcode == "x-hs-rat-se1tsm-02" & ///
										value_string != "0")), ///
									clean sep(,) local(stsch)
					
				local stsch_all "`stsch'"
				local stsch_all : list uniq stsch_all
				
				qui replace statsched = `"`stsch_all'"' if country == "`c'"
			}
			
			qui replace statsched = subinstr(statsched, ",", ", ", .)
									

		*** YEARS WITH ADJUSTED SCHEDULE	
			cap drop scheduleinfo
			qui gen scheduleinfo = ""
			
			levelsof country, local(geolist)
			
			qui foreach c in `geolist' {
				levelsof year if country == "`c'" & ///
								varcode == "x-hs-rat-ad1smr-02" & ///
								value_string != "0", ///
									clean sep(,) local(schedul)
					
				local s_all "`schedul'"
				local s_all : list uniq s_all
				
				qui replace scheduleinfo = `"`s_all'"' if country == "`c'"
			}
			
			qui replace scheduleinfo = subinstr(scheduleinfo, ",", ", ", .)
						

			
			
	
		********** Make Tables *****************************************
		****** Create full country list with legal characters only *****
		** Legal characters
			qui replace country = subinstr(country, ",", " ", .)
			qui replace country = subinstr(country, ".", " ", .)
		
		** Full list
*		qui replace country = "### " + country
		levelsof country, local(geolist)

		
****** Create Tables by Country *****	
	
	 qui foreach c in `geolist' {
		
		 putexcel set "$fin/countries.xlsx", sheet(`c') modify
		
		 cap putexcel A1 = "Variable"
			
		 cap putexcel B1 = "Value"
			
		 cap putexcel A2 = "Country"
			
		 cap putexcel B2 = "`c'"
			
/*
		 cap putexcel A3 = "First Year"
		 levelsof firstyear if country=="`c'", local(fyr)
		 cap putexcel B3 = `fyr'
			
		 cap putexcel A4 = "Last Year"
		 levelsof lastyear if country=="`c'", local(lyr)
		 cap putexcel B4 = `lyr'
			
			
		 cap putexcel A5 = "Number of Years"
		 levelsof N_yrs if country=="`c'", local(nyr)
		 cap putexcel B5 = `nyr'
*/
			
		 cap putexcel A3 = "Years with EIG tax"
		 levelsof eigstayears if country=="`c'", clean local(eyr)
		 cap putexcel B3 = `"`eyr'"'
		 
		 cap putexcel A4 = "Years without EIG tax"
		 levelsof eigstayears if country=="`c'", clean local(eyr)
		 cap putexcel B4 = `"`eyr'"'
			
	
		 cap putexcel A5 = "Years with Positive Top Rate"
		 levelsof topratyears if country=="`c'", clean local(tyr)
		 cap putexcel B5 = `"`tyr'"'
				
		 cap putexcel A6 = "Years with Child Exemption"
		 levelsof childex if country=="`c'", clean local(che)
		 cap putexcel B6 = `"`che'"'
		 
		 cap putexcel A7 = "Years with Class 1 Exemption"
		 levelsof cl1ex if country=="`c'", clean local(c1e)
		 cap putexcel B7 = `"`c1e'"'
		 
		 cap putexcel A8 = "Years with Statutory Schedule"
		 levelsof statsched if country=="`c'", clean local(ssyr)
		 cap putexcel B8 = `"`ssyr'"'
		 
		 cap putexcel A9 = "Years with Adjusted Schedule"
		 levelsof scheduleinfo if country=="`c'", clean local(asyr)
		 cap putexcel B9 = `"`asyr'"'
		 

		/*
		 cap putexcel A8 = "Years with exemption information"
		 levelsof scheduleinfo if country=="`c'", clean sep(, ) local(syr)
		 cap putexcel B8 = `"`syr'"'
		*/	
			
		cap putexcel A10 = "Sources"
		levelsof leg_sources if country=="`c'", clean local(s1)
		cap putexcel B10 = `"`s1'"'
			
			
		 cap putexcel save
			
		 cap putexcel clear
	}
			
			
		*************************************
		******************************************************



