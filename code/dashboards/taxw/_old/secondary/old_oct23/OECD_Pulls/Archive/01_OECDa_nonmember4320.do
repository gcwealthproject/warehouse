clear all


sdmxuse data OECD, dataset(RS_GBL) dimensions(..4320.) attributes 

rename cou geo3
rename time year
format value %20.9f

******* Extract Currency *******
		duplicates drop
		merge m:1 geo3 year using "${intfile}/OECDeigt_currency.dta", update // replace	
		drop if value ==.
		tab Currency unit if Currency!=unit & var!="TAXUSD"
		
		* 1 Convert VES to VEF: VES = 100,000 VEF / https://www.xe.com/currencyconverter/convert/?Amount=1&From=VEF&To=VES
		* 2 OECD data for Bolivia is in Venezuelan Bolívares. Therefore:
			* Use data in USD, then use WID sup vars to convert USD to BOB (Currency in EIG data)
			
****** Correct Currency ********

	replace value = value/100000 if unit == "VES" & Currency =="VEF" 
	replace unit = "VEF" if unit == "VES" & Currency =="VEF"

	destring year, replace
	cap drop _*
	merge m:1 geo3 year using "${intfile}/supvars.dta"
	drop if value ==.


	replace value = value/xlcusx if geo3 == "BOL" & unit =="USD" // WID: Market exchange rate
	replace unit = "BOB" if geo3 == "BOL" & unit =="USD"
	replace var = "TAXNAT" if geo3 == "BOL" & unit == "BOB"

	drop if unit == "VEB" & geo3=="BOL"

keep if var=="TAXNAT"
keep if gov == "NES"

// Update currency values when missing
replace Currency=unit if Currency==""
	
	preserve
		tostring year, replace
		keep if var=="TAXNAT"
		keep geo3 year Currency
		append using "${intfile}/OECDeigt_currency.dta"
		duplicates drop
		drop if Currency==""
		save "${intfile}/OECDeigt_currency.dta", replace
	restore

destring powercode,replace

*************** Adjust powercode/units ***************
	* Step 1: Find all the unique values of powercode
	levelsof powercode, local(values)

	* Step 2: Loop over these values and perform an arithmetic operation
	foreach p of local values {
		 replace value = value*(10^`p') if powercode==`p'
	}

drop tax time_format inyixx xlceup xlceux xlcusp xlcusx xlcyup xlcyux _merge
drop if geo3=="ASIAP"|geo3=="419"

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
	drop _merge
	merge m:1 Geo using "${intfile}/OECD_WID_ISO.dta"
	drop if _merge==2
	drop _merge
	drop if value ==.
	
	format value %20.0f
	gen Tot_Gift_Rev =string(value, "%20.9f")
	
	gen Tot_Gift_Rev_backup = Tot_Gift_Rev
	
	drop value


save "${intfile}/01_OECDa_nonmember4320.dta", replace
