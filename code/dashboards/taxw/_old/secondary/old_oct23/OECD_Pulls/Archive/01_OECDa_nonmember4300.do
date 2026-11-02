clear all

sdmxuse data OECD, dataset(RS_GBL) dimensions(..4300.) attributes

rename cou geo3
rename time year

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

drop tax time_format unit inyixx xlceup xlceux xlcusp xlcusx xlcyup xlcyux _merge
drop if geo3=="ASIAP"|geo3=="419"

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

	drop if geo3=="OAVG"

save "raw_data/eigt/intermediary_files/01_OECDa_nonmember4300.dta", replace

	/* JOSH'S DISCARDED CODE
	
		// EDIT -TA:

	*replace powercode="1" if powercode=="0" // COMMENTED OUT (STRAIGHTFORWARD MATH IS BETTER) -TA
		
		*egen govvar=group(gov var),label(mylabel)
		egen govvar2=group(gov var)
		gen grouping=""
		
		replace grouping = "FEDTAXGDP" if govvar2==1
		replace grouping = "FEDTAXNAT" if govvar2==2
		replace grouping = "FEDTAXPER" if govvar2==3
		replace grouping = "LOCALTAXGDP" if govvar2==4
		replace grouping = "LOCALTAXNAT" if govvar2==5
		replace grouping = "LOCALTAXPER" if govvar2==6
		replace grouping = "NESTAXGDP" if govvar2==7
		replace grouping = "NESTAXNAT" if govvar2==8
		replace grouping = "NESTAXPER" if govvar2==9
		replace grouping = "SOCSECTAXGDP" if govvar2==10
		replace grouping = "SOCSECTAXNAT" if govvar2==11
		replace grouping = "SOCSECTAXPER" if govvar2==12
		replace grouping = "STATETAXGDP" if govvar2==13
		replace grouping = "STATETAXNAT" if govvar2==14
		replace grouping = "STATETAXPER" if govvar2==15
		replace grouping = "SUPRATAXGDP" if govvar2==16
		replace grouping = "SUPRATAXNAT" if govvar2==17
		replace grouping = "SUPRATAXPER" if govvar2==18
		
		*drop govvar
		drop govvar2
		
		rename valueFEDTAXGDP Fed_Rev_GDP
		rename valueFEDTAXNAT Fed_Rev
		rename valueFEDTAXPER Fed_Prop_Rev
		rename valueLOCALTAXGDP Loc_Rev_GDP
		rename valueLOCALTAXNAT Loc_Rev
		rename valueLOCALTAXPER Loc_Prop_Rev
		rename valueNESTAXGDP Tot_Rev_GDP
		rename valueNESTAXNAT Tot_Rev
		rename valueNESTAXPER Tot_Prop_Rev
		rename valueSTATETAXGDP Reg_Rev_GDP
		rename valueSTATETAXNAT Reg_Rev
		rename valueSTATETAXPER Reg_Prop_Rev
		*rename valueSUPRATAXGDP Tot_Rev
		*rename valueSUPRATAXNAT Tot_Rev_GDP
		*rename valueSUPRATAXPER Tot_Prop_Rev
		*rename valueSOCSECTAXGDP Tot_Rev
		*rename valueSOCSECTAXNAT Tot_Rev_GDP
		*rename valueSOCSECTAXPER Tot_Prop_Rev

		*format Tot_Rev %30.0000g
		*format("%30.0000f")
		
		drop Tot_Rev
		drop Fed_Rev
		drop Loc_Rev
		drop Reg_Rev

		rename Tot_Rev2 Tot_Rev
		rename Fed_Rev2 Fed_Rev
		rename Loc_Rev2 Loc_Rev
		rename Reg_Rev2 Reg_Rev
		
		*tostring Tot_Rev, replace 
		tostring Tot_Rev_GDP, replace 
		tostring Tot_Prop_Rev, replace 
		*tostring Fed_Rev, replace 
		tostring Fed_Rev_GDP, replace 
		tostring Fed_Prop_Rev, replace 
		*tostring Loc_Rev, replace 
		tostring Loc_Rev_GDP, replace 
		tostring Loc_Prop_Rev, replace 
		*tostring Reg_Rev, replace 
		tostring Reg_Rev_GDP, replace 
		tostring Reg_Prop_Rev, replace 
	*/
