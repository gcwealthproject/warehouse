
*** Need to make sure Sup Vars .dta file is up to date. Done manually for EIG section as of 8/29/23. ***

	clear all
	
		************************ Save file EIG Transcribed file ***********************

			global seccod code/dashboards/eigt/secondary
			global intfile raw_data/eigt/intermediary_files
			import excel "handmade_tables/eigt_transcribed.xlsx", firstrow  clear
			
			gen N = _n
			
		************************ Save file EIG states file ***********************
		
			preserve
				keep if GeoReg!="_na"
				save "${intfile}/reg_eigt_transcribed.dta", replace
			restore
		
		***************** Drop regional observations and clean *******************
			drop if GeoReg!="_na"

			cap drop DQ-FQ
			duplicates drop

			sort geo3 year

			tostring year, replace
					
			save "${intfile}/OECDeigt_transcribed.dta", replace
			
		
// Want to start with non-OECD member countries and then overwrite when the country is an OECD member.	
			
************************************
**** Non-OECD Member Countries *****
************************************

// These commands will pull the 4300, 4310, and 4320 tax indicators for all countries in the data.	
	
**** 4300 (EIG Revenues) **********
		
		use "${intfile}/OECDeigt_transcribed.dta", clear

		merge m:1 geo3 year using "${intfile}/01_OECDa_nonmember4300.dta", update replace	
		
	
**** 4310 (EI Revenues) **********

		merge m:1 geo3 year using "${intfile}/01_OECDa_nonmember4310.dta", update gen(_merge2) replace 
		
**** 4310 (G Revenues) **********

		merge m:1 geo3 year using "${intfile}/01_OECDa_nonmember4320.dta", update gen(_merge3) replace 	

		do "${seccod}/01b_Clean_OECDa_nonmember.do"		
		
		save "${intfile}/OECDeigt_transcribed2.dta", replace
		
************************************
******* OECD Member Countries ******
************************************		

**** 4300 (EIG Revenues) **********

		merge m:1 geo3 year using "${intfile}/01_OECDa_member4300.dta", update		
		
**** 4310 (EI Revenues) **********

		merge m:1 geo3 year using "${intfile}/01_OECDa_member4310.dta", update gen(_merge2)			

**** 4320 (G Revenues) **********

		merge m:1 geo3 year using "${intfile}/01_OECDa_member4320.dta", update gen(_merge3)			

		do "${seccod}/01b_Clean_OECDa_member.do"		
		
		save "${intfile}/OECDeigt_transcribed3.dta", replace
		
		cap drop _merge*
		
			kountry geo3, from(iso3c) to(iso2c)
				replace Geo = _ISO2C_ if Geo==""
			kountry geo3, from(iso3c)
				replace country = NAMES_STD if country==""

		drop _ISO2C_ NAMES_STD
		cap drop _merge*
		
		destring year, replace
		gen negyr = -year
		
		sort Geo negyr N
		
		drop negyr
		
		

		save "${intfile}/OECDeigt_transcribed_final.dta", replace 
		
		*** Re-Add Regional Info if desired ***


*tostring Tot_Rev, replace
*tostring Tot_Rev_GDP, replace
*tostring Tot_Prop_Rev, replace
