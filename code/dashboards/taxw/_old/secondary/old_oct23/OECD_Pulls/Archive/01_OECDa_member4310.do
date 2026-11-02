clear all

sdmxuse data OECD, dataset(REV) dimensions(.4310.) attributes 

rename cou geo3
rename time year
format value %20.9f

******* Extract Currency *******
		duplicates drop
		merge m:1 geo3 year using "${intfile}/OECDeigt_currency.dta", update // replace	
		drop if value ==.
		tab Currency unit if Currency!=unit & var=="TAXNAT"
		
		* Currencies OK
			
****** Correct Currency ********

	destring year, replace
	cap drop _*
	merge m:1 geo3 year using "${intfile}/supvars.dta"
	drop if value ==.

keep if var=="TAXNAT"
keep if gov == "NES"

destring powercode,replace

*************** Adjust powercode/units ***************
	* Step 1: Find all the unique values of powercode
	levelsof powercode, local(values)

	* Step 2: Loop over these values and perform an arithmetic operation
	foreach p of local values {
		 replace value = value*(10^`p') if powercode==`p'
	}

drop tax time_format inyixx xlceup xlceux xlcusp xlcusx xlcyup xlcyux _merge
drop if geo3=="OAVG"

**************** Rename, reshape, clean **************

drop gov var

merge m:1 geo3 using "${intfile}/OECD_WID_ISO.dta"
drop if value ==.
replace Currency=unit if Currency==""
drop _merge powercode unit
		
****** Add info to add revenue values to main dataset ******
	gen GeoReg = "_na"
	tostring year, replace
	merge m:1 geo3 year using "${intfile}/OECDeigt_currency.dta"
	drop if _merge==2
	drop if value==.
	drop _merge
	merge m:1 Geo using "${intfile}/OECD_WID_ISO.dta"
	drop if _merge==2
	drop if value==.
	drop _merge
	
	format value %20.0f
	gen Tot_EI_Rev =string(value, "%20.9f")
	
	gen Tot_EI_Rev_backup = Tot_EI_Rev
	
	drop value

save "raw_data/eigt/intermediary_files/01_OECDa_member4310.dta", replace
