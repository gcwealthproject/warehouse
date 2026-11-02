********************************************************************************
*** EIG data: automated error finder
********************************************************************************
*** 1. revenue errors
*** 2. EIG status errors
*** 3. zero top rate errors
*** 4. revenue errors
*** 5. Inconsistent sources


	clear all
	
		
		*IF NEEDED:
		*run "code/mainstream/auxiliar/all_paths.do"
		
		import excel "handmade_tables/eigt_transcribed.xlsx", firstrow  clear

		cap drop DQ-FQ
		duplicates drop
		
		save "raw_data/eigt/intermediary_files/eigt_transcribed.dta", replace

		gen N = _n
		
	*** 0. Fix Source Inconsistencies
		
		preserve
		
			* Import dictionary
			import excel "handmade_tables/dictionary.xlsx", firstrow ///
				sheet("Sources") clear
				
				*keep if Section == "Estate, Inheritance, and Gift Taxes"
				duplicates drop
				
				drop if Source == Old_Source
				drop if Old_Source == "" 
				drop if Source == ""
				
				forvalues n = 1/7{
					gen Source_`n' = Old_Source
				}
		
			* Rename the imported dataset for merging
				
				export excel using "/Users/twishaasher/Dropbox (Hunter College)/sources.xlsx", firstrow(var) replace
					keep Source Old_Source Source_1 Source_2 Source_3 Source_4 Source_5 ///
					Source_6 Source_7
					tempfile dictionary
					save `dictionary', replace
		restore
		
		* Step 2: Loop through each of the source columns
			foreach var in Source_1 Source_2 Source_3 Source_4 Source_5 ///
					Source_6 Source_7 {

				* Step 3: Merge on the 'Source' column first
					merge m:1 `var' using `dictionary'

				* Step 4: Replace values in the source columns where they match the Old_Source
					replace `var' = Source if `var' == Old_Source & _merge == 3

				* Drop the variables created by the merge
					drop _merge Source Old_Source
			}

		* OPTIONAl Step 5: Clean up - You have the updated dataset in memory, you can now save it
			*save "raw_data/eigt/intermediary_files/eigt_transcribed.dta", replace
		
	*** 1. REVENUE ERRORS	

	*** All Flag Vars: 
	/*
			err_rev_1 err_rev_2 err_rev_3 err_rev_3a zero_flag 
			fy_EIG_Status fy_Estate_Tax fy_Gift_Tax 
			fy_Inheritance_Tax eig_EIG_Status eigsta_flag source_flag
	*/
	
		*gen no_brac = 1 if v121 ==.
		local rev Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev ///
				Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev ///
				Tot_Rev_GDP Fed_Rev_GDP Reg_Rev_GDP
				
		foreach var in `rev'{
			replace `var' = "." if `var' == "_na"
			generate num_`var' = real(`var')
		}
		
	*** check if total revenue is same as previous year	
		gen err_rev_1 = 1 if Tot_Rev==Tot_Rev[_n-1] & Geo==Geo[_n-1] & ///
			year!=year[_n-1] & GeoReg==GeoReg[_n-1] & Tot_Rev!="." & ///
			Tot_Rev!="0" & Tot_Rev!= ""

	*** check if revenue proportion is same as previous year
		gen err_rev_2 = 1 if Tot_Prop_Rev==Tot_Prop_Rev[_n-1] & Geo==Geo[_n-1] ///
			& year!=year[_n-1] & GeoReg==GeoReg[_n-1] & Tot_Prop_Rev!="." & ///
			Tot_Prop_Rev!="0" & Tot_Prop_Rev!= ""

	*** check if revenue information is positive although tax info says there is no eig tax
		gen err_rev_3  = 1 if EIG_Status == "N" & (Tot_EI_Rev != "0" | ///
			Tot_Gift_Rev != "0") & (Tot_EI_Rev != "." | Tot_Gift_Rev != ".") ///
			& (Tot_EI_Rev != "" | Tot_Gift_Rev != "") & GeoReg == "_na"
		
			*** additionally check third category error: flag if revenue is not decreasing over time (e.g. Canada after 2008)
			gen err_rev_3a = 1 if err_rev_3 == 1 & (Tot_EI_Rev > Tot_EI_Rev[_n+1] ///
				| Tot_Gift_Rev > Tot_Gift_Rev[_n+1])
			
			*** note: all err_rev_3 data manually checked is ok --> except Slovakia 2007, 2019
	

	* browse all revenue errors
	*br geo3 Tot_Rev Tot_Prop_Rev year GeoReg err_* if err_rev_1 ==1 | ///
	*	err_rev_2 == 1 | err_rev_3 == 1
	* browse same revenue as previous year error only
	*br geo3 Tot_Rev year err_rev_1 if err_rev_1 ==1 
	
	
	*** 2. EIG STATUS. ERRORS
	*** Flag if first eig is incorrectly entered: ### in this case replace  First_EIG = "_na" if First_EIG == . & feig_flag == 1 /// basically flagging those where we dont know when first year, bcs missing in those cases, but _na if we know its in previous year somewhere
	
		gen feig_flag=1 if EIG_Status=="N" & First_EIG!="_na"

		
	*** Flag if first eig status is incorrectly entered --> only affecting US states
		
		gen eigsta_flag = .
		replace eigsta_flag=1 if (Estate_Tax=="Y"| Gift_Tax=="Y"| ///
									Inheritance_Tax=="Y") & (EIG_Status=="."| ///
																EIG_Status=="N")
	*** correct if eig status is incorrectly entered 															
		replace EIG_Status="Y" if Estate_Tax=="Y"| Gift_Tax=="Y"| Inheritance_Tax=="Y"
		replace EIG_Status="N" if Estate_Tax=="N" & Gift_Tax=="N" & Inheritance_Tax=="N"
												
														
		replace EIG_Status="Y" if Estate_Tax=="Y"| Gift_Tax=="Y"| Inheritance_Tax=="Y"
		replace EIG_Status="N" if Estate_Tax=="N" & Gift_Tax=="N" & Inheritance_Tax=="N"
		replace EIG_Status = "Y" if EIG_Status=="Y "
		
		
			*br year geo3 Top_Rate EIG_Status First_EIG eigsta_flag zero_flag ///
			*	if zero_flag == 1 & GeoReg == "_na"	
	
	
	*** 3. ZERO TOP RATE ERRORS	
		
	*** Flag zero toprate without previous data
		
		* Flag leading zeroes without previous data		
			cap drop zero_flag
			gen zero_flag = .

			levelsof geo3, local(Geolist) // country list
			*local eig EIG_Status Estate_Tax Gift_Tax Inheritance_Tax // var status list
		
		* Find all EIG statuses associated with each geo3 // FIND FASTER ALTERNATIVE (EIG status only also takes a long time)
				/*
				cap drop eig_EIG_Status
				qui gen eig_EIG_Status = ""
				
					qui foreach c in `Geolist'{
						levelsof EIG_Status if geo3 == "`c'" & GeoReg== "_na", ///
													clean sep(,) local(sta)			
						qui replace eig_EIG_Status  = "`sta'" if geo3 == "`c'" & ///
																GeoReg== "_na"
					}
				

		* flag if no EIG, EIG status only missing, or missing and no EIG_Status
			replace zero_flag = 1 if Top_Rate == "0" & (EIG_Status=="N") | ///
													(EIG_Status==".") 

				
				
				
		* gen var for first year with EIG; flag if observation year before first year and top rate = 0

			

			cap drop fy_*
			sort Geo GeoReg year N
			
				gen yr_eig = year if EIG_Status=="Y"
				bys Geo (GeoReg): egen fy_eig= min(yr_eig)
				
				

			
			
			cap drop fy_
			egen fy_ = rowmin(fy_*)
**# Bookmark #6
			replace zero_flag=1 if Top_Rate=="0" & year<fy_  & fy_!=.	/// 
			
			*/
			
			save "raw_data/eigt/intermediary_files/eigt_transcribed.dta", replace
			
			
			
		* Replace top rate with 0 if no EIG
			local tr Top_Rate Estate_Top_Rate Inheritance_Top_Rate Gift_Top_Rate
			
			foreach var in `tr' {
				replace `var' = "0" if (`var'=="" |`var'=="_na"| ///
													`var'==".") & ///
													(EIG_Status=="N") 
			}
			
		
	
												
	*** 4. REVENUE TO ZERO FOR EIG="N" COUNTRIES
		/*
		tempvar eig_sta_num eig_ever
		
		gen `eig_sta_num' = 1 if EIG_Status == "Y"
		replace `eig_sta_num' = 0 if EIG_Status == "N"
		
		sort Geo GeoReg year N
		
		egen `eig_ever' = max(`eig_sta_num'), by(Geo GeoReg)
		cap drop N_yrs
		egen N_yrs = nvals(year), by(Geo GeoReg)
		*/
		
		local rev Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev ///
			Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev Tot_Rev_GDP ///
			Fed_Rev_GDP Reg_Rev_GDP
			
			gen no_rev = 0
				
			foreach var in `rev'{
				replace no_rev = 1 if num_`var'>0 & num_`var'!=.
			}
			
			foreach v in `rev'{
				replace `v' = "0" if EIG_Status=="N" & `v' == "." & no_rev==1
			}
			
	*** 5. Source Inconsistencies
		
		sort Geo GeoReg year N
		cap drop source_flag
		gen source_flag = 0
		forvalues sn = 1/7{
			replace source_flag = 1 if Geo == Geo[_n-1] & GeoReg == GeoReg[_n-1] & ///
								year == year[_n-1] & Source_`sn'!= Source_`sn'[_n-1]
		}


												
	*** Only keep identifying info and error flags
	preserve
	
		keep country Geo geo3 GeoReg year N err_rev_1 err_rev_2 err_rev_3 ///
			err_rev_3a zero_flag feig_flag eigsta_flag 

		
		save "raw_data/eigt/intermediary_files/EIG_errors.dta", replace
		
	restore
															
													
*import excel "$dir/EIG Taxes/data_inputs/EIGtax_mergeable.xlsx", sheet("Detailed") firstrow clear 
*		gen N = _n	
*	merge 1:1 country Geo geo3 GeoReg year N using "$dir/EIG Taxes/data_inputs/EIG_errors.dta"
*save "$dir/EIG Taxes/data_inputs/EIGtax_mergeable_wErrorFlags.dta"

		
		
	*** Reset file to original for cleaning
	
	drop num_Tot_Rev-source_flag
		*__000000 	__000001 
		
	save "raw_data/eigt/intermediary_files/eigt_fixed_errs.dta", replace 
	
			