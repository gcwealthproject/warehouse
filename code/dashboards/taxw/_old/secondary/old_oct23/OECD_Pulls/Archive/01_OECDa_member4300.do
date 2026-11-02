clear all

sdmxuse data OECD, dataset(REV) dimensions(.4300.) attributes 

rename cou geo3

preserve
	keep geo3 
	duplicates drop
	gen mem = 1
	save "${intfile}/OECD_members.dta", replace
restore

rename time year
format value %20.9f

	destring year, replace
	cap drop _*
	merge m:1 geo3 year using "${intfile}/supvars.dta"
	drop if value ==.
	cap drop _*

******* Extract Currency *******
		duplicates drop
		tostring year, replace
		merge m:1 geo3 year using "${intfile}/OECDeigt_currency.dta" // replace	
		cap drop _*
		drop if value ==.
		tab Currency unit if Currency!=unit & var=="TAXNAT"
		tab geo3 year if unit == "CLP" & Currency =="USD" 
		*tab geo3 year if unit == "CLP" & Currency !="USD" 
		
		* 1 Convert EUR to ITL: 1 EUR = 1936.27 ITL / https://www.xe.com/currencycharts/?from=EUR&to=ITL&view=10Y
		* 2 EIG data for CHL is in USD (2006+): convert
			
****** Correct Currency ********

	destring year, replace

	replace value = value/1936.27 if unit == "EUR" & Currency =="ITL" 
	replace unit = "ITL" if unit == "EUR" & Currency =="ITL"

	replace value = value/xlcusx if geo3 == "CHL" & unit =="CLP" & year>=2006 // WID: Market exchange rate
	replace unit = "USD" if geo3 == "CHL" & unit =="CLP" & year>=2006


keep if var!="TAXUSD"
drop if gov == "SOCSEC"
drop if gov == "SUPRA"

// Update currency values when missing
replace Currency=unit if Currency==""
	
	preserve
		tostring year, replace
		keep if var=="TAXNAT"
		keep geo3 year Currency
		append using "${intfile}/OECDeigt_currency.dta"
		duplicates drop
		drop if Currency==""
		destring year, replace
		drop if geo3 == "CHL" & Currency =="CLP" & year>=2006
		tostring year, replace
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

drop tax time_format unit inyixx xlceup xlceux xlcusp xlcusx xlcyup xlcyux 
drop if geo3=="OAVG"

**************** Rename, reshape, clean **************

* Create the new variable "grouping" initialized with empty strings
	gen grouping = ""

		* Define local macros for the 'gov' variable and its corresponding prefixes
		local govvalues    FED LOCAL NES STATE
		local govprefixes  Fed_ Loc_ Tot_ Reg_

		* Define local macros for the 'var' variable and its corresponding suffixes
		local varvalues    TAXNAT TAXPER TAXGDP
		local varsuffixes  Rev Prop_Rev Rev_GDP

		* Loop over each value of 'gov' and 'var' to replace the values in 'grouping'
		forvalues g = 1/4 {
			local po: word `g' of `govvalues'
			local pn: word `g' of `govprefixes'
			
			forvalues v = 1/3{
				local so: word `v' of `varvalues'
				local sn: word `v' of `varsuffixes'
				
					* Replace the values in 'grouping' based on the current 'gov' and 'var' values
					replace grouping = "`pn'`sn'" if gov == "`po'" & var == "`so'"
			}
		}


drop gov
drop var

merge m:1 geo3 using "${intfile}/OECD_WID_ISO.dta"
drop if value ==.
drop _merge Currency powercode



reshape wide value, i(Geo geo3 year) j(grouping) string

		rename value* *
		
		drop Loc_Rev_GDP

		local rev Tot_Rev Fed_Rev Loc_Rev Reg_Rev
		foreach var of local rev {
			gen `var'_backup=string(`var', "%20.0f")
			drop `var'
			gen `var' = `var'_backup
		}
		
		local prev Tot_Rev_GDP Tot_Prop_Rev Fed_Rev_GDP Fed_Prop_Rev Loc_Prop_Rev ///
					Reg_Rev_GDP Reg_Prop_Rev
		foreach var of local prev {
			tostring `var', replace 
			gen `var'_backup = `var'
		}

****** Add info to add revenue values to main dataset ******
	gen GeoReg = "_na"
	tostring year, replace
	merge m:1 geo3 year using "${intfile}/OECDeigt_currency.dta"
	drop if _merge==2
	drop _merge
	merge m:1 Geo using "${intfile}/OECD_WID_ISO.dta"
	drop if _merge==2
	drop _merge

save "raw_data/eigt/intermediary_files/01_OECDa_member4300.dta", replace
