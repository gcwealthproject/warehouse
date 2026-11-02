
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
			
		******************** Extract Currency by Year ***************************
			preserve
				keep geo3 Currency year 
				destring year, replace
				keep if year>1960
				tostring year, replace
				duplicates drop
				drop if Currency==""
				save "${intfile}/OECDeigt_currency.dta", replace
			restore
			
		******************** Two Letter ISO codes for WID ************************
			preserve
				keep Geo geo3
				duplicates drop
				save "${intfile}/OECD_WID_ISO.dta", replace
			restore
		
		
		**************** Import supplementary data for currency adjustment *****************
			global sup "raw_data/wid"
			import excel "${sup}/supvars_wide_4Nov2022.xlsx", firstrow sheet("data") clear
				drop mgdpro mnninc mpweal ntaxma percentile nomgdp nomnni npopem npopul_adu npopul
				rename country Geo
				replace Geo = "UK" if Geo == "GB"
				merge m:1 Geo using "${intfile}/OECD_WID_ISO.dta" // For geo3
				drop if geo3==""
				drop _*
				save "${intfile}/supvars.dta", replace
		
// Want to start with non-OECD member countries and then overwrite when the country is an OECD member.	
			
************************************
**** Non-OECD Member Countries *****
************************************

// These commands will pull the 4300, 4310, and 4320 tax indicators for all countries in the data.	
	
**** 4300 (EIG Revenues) **********
preserve
	do "${seccod}/JEM Codes OECD/01_OECDa_nonmember4300.do"		
restore
		
		use "${intfile}/OECDeigt_transcribed.dta", clear

		merge m:1 geo3 year using "${intfile}/01_OECDa_nonmember4300.dta", update replace	
		
	
**** 4310 (EI Revenues) **********
preserve
	do "${seccod}/JEM Codes OECD/01_OECDa_nonmember4310.do"		
restore

		merge m:1 geo3 year using "${intfile}/01_OECDa_nonmember4310.dta", update gen(_merge2) replace 
		
**** 4310 (G Revenues) **********
preserve
	do "code/dashboards/eigt/secondary/JEM Codes OECD/01_OECDa_nonmember4320.do"
restore	

		merge m:1 geo3 year using "${intfile}/01_OECDa_nonmember4320.dta", update gen(_merge3) replace 	

		do "${seccod}/01b_Clean_OECDa_nonmember.do"		
		
		save "${intfile}/OECDeigt_transcribed2.dta", replace
		
************************************
******* OECD Member Countries ******
************************************		

**** 4300 (EIG Revenues) **********
preserve
	do "${seccod}/JEM Codes OECD/01_OECDa_member4300.do"
restore

		merge m:1 geo3 year using "${intfile}/01_OECDa_member4300.dta", update		
		
**** 4310 (EI Revenues) **********
preserve
	do "${seccod}/JEM Codes OECD/01_OECDa_member4310.do"
restore

		merge m:1 geo3 year using "${intfile}/01_OECDa_member4310.dta", update gen(_merge2)			

**** 4320 (G Revenues) **********
preserve
	do "${seccod}/JEM Codes OECD/01_OECDa_member4320.do"
restore

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
		



*tostring Tot_Rev, replace
*tostring Tot_Rev_GDP, replace
*tostring Tot_Prop_Rev, replace
