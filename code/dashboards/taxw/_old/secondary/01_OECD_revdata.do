// Aim: take OECD Revenue data from the web

**** 4300 (EIG Revenues) **********
**** 4310 (EI Revenues) **********
**** 4320 (G Revenues) **********
 
// Package required, automatic check 
	cap which sdmxuse
	if _rc ssc install sdmxuse	
	
foreach group in members nonmembers {
	foreach i in 4300 4310 4320 {

		qui {
		if ("`group'" == "members") sdmxuse data OECD, dataset(REV) dimensions(.`i'.) attributes clear
		else sdmxuse data OECD, dataset(RS_GBL) dimensions(..`i'.) attributes clear
		compress
		
		/// Clean 
		rename (cou unit time) (geo3 Currency year)
		
		destring year, replace
		drop if geo3=="OAVG" 
		if ("`group'" == "nonmembers") drop if geo3 == "ASIAP" | geo3 == "419"

		if (`i' == 4300) {
			drop if gov == "SOCSEC" | gov == "SUPRA"
			keep if var!="TAXUSD"
		}
		else {
			keep if gov == "NES"
			keep if var=="TAXNAT"
		}

		************************* Adjust powercode/units **************************

		destring powercode,replace

			* Step 1: Find all the unique values of powercode
			levelsof powercode, local(values)

			* Step 2: Loop over these values and perform an arithmetic operation
			foreach p of local values {
				 replace value = value*(10^`p') if powercode==`p'
			}

		drop tax time_format powercode	
		
		******* Check Currency *********

		preserve
			import excel "$hmade\national_currencies_2023.xlsx", ///
					cellrange(B1:D169) firstrow clear
			tempfile natcurr
			save "`natcurr'", replace
		restore 

		merge m:1 geo3 using "`natcurr'", keep(master match)
		count if Currency!= nat_currency & var=="TAXNAT" & _m == 3
		}
		if (`r(N)' == 0) display "No currency problem for OECD `group' `i'"
		else {
			display "Currency adjustment for OECD `group' `i':"
			tab geo3 if Currency!= nat_currency & var=="TAXNAT" & _m == 3 // BOL GUY
			
			qui {
			// 1) Bolivia: OECD data for Bolivia are in Venezuelan Bolívares (VEB). 
			* Therefore: convert in USD, then use WID sup vars to convert USD to BOB 
			* (Currency in EIG data and current national currency)
			cap drop _m
			preserve
				import excel "$supvars\supplementary_var_$supvar_ver.xlsx", firstrow clear
				keep country year xlcusx // WID: Market exchange rate with USD
				keep if country == "VE" // Venezuela
				replace country = "BO" if country == "VE" // for merging
				rename country Geo
				tempfile convert
				save "`convert'", replace
			restore
			merge m:1 Geo year using "`convert'", keep(master match) nogen
			replace value = value/100000000 if geo3 == "BOL" & Currency =="VEB" // VEB -> VES 
			replace value = value/xlcusx if geo3 == "BOL" & Currency =="VEB" // VES -> USD
			replace Currency = "USD" if geo3 == "BOL" & Currency =="VEB"
			// USD -> BOB
			drop xlcusx
			cap drop _m
			preserve
				import excel "$supvars\supplementary_var_$supvar_ver.xlsx", firstrow clear
				keep country year xlcusx 
				keep if country == "BO" // Bolivia
				rename country Geo
				tempfile convert
				save "`convert'", replace
			restore	
			merge m:1 Geo year using "`convert'", keep(master match) nogen
			replace value = value*xlcusx if geo3 == "BOL" & Currency =="USD" // USD -> BOB
			replace Currency = "BOB" if geo3 == "BOL" & Currency =="USD"
				 
			// 2) Guyana: OECD data for Guyana are in VEF, need to be in GYD. 
				* Therefore: convert in USD, then use WID sup vars to convert USD to GYD 
				* (Currency in EIG data and current national currency)
				* conversion 
			cap drop _m
			preserve
				import excel "$supvars\supplementary_var_$supvar_ver.xlsx", firstrow clear
				keep country year xlcusx // WID: Market exchange rate with USD
				keep if country == "VE" // Venezuela
				replace country = "GY" if country == "VE" // for merging
				rename country Geo
				tempfile convert
				save "`convert'", replace
			restore
			merge m:1 Geo year using "`convert'", keep(master match) nogen
			replace value = value/100000 if geo3 == "GUY" & Currency =="VEF" // VEF -> VES 
			replace value = value/xlcusx if geo3 == "GUY" & Currency =="VEF" // VEF -> USD
			replace Currency = "USD" if geo3 == "GUY" & Currency =="VEF"
			// USD -> GYD
			drop xlcusx
			preserve
				import excel "$supvars\supplementary_var_$supvar_ver.xlsx", firstrow clear
				keep country year xlcusx 
				keep if country == "GY" // Guyana
				rename country Geo
				tempfile convert
				save "`convert'", replace
			restore	
			merge m:1 Geo year using "`convert'", keep(master match) nogen
			replace value = value*xlcusx if geo3 == "GUY" & Currency =="USD" // USD -> GYD
			replace Currency = "GYD" if geo3 == "GUY" & Currency =="USD"		
			drop xlcusx
			}
		}
		qui {
		egen id = group(geo3)
		xfill Currency, i(id)
		drop id	

		if (`i' == 4300) {
		************************* Reshape  ****************************************

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
			drop gov var nat_currency
			// Replace currency with national currency for reshaping
			replace Currency = "" if Currency == "PC"
			egen id = group(geo3)
			xfill Currency, i(id)
			drop id
			label var Currency "National currency for TAXNAT data"
			
			cap drop _m
			reshape wide value, i(geo3 year) j(grouping) string

			rename value* *
					
			drop Loc_Rev_GDP
		}
		
		************************* Rename and format *******************************
		
		if (`i' == 4300) {
			local prev Tot_Rev_GDP Tot_Prop_Rev Fed_Rev_GDP Fed_Prop_Rev Loc_Prop_Rev ///
						Reg_Rev_GDP Reg_Prop_Rev
			foreach var of local prev {
				format `var' %6.4f
			}

			local rev Tot_Rev Fed_Rev Loc_Rev Reg_Rev
			foreach var of local rev {
				format `var' %20.4f
			}
		}
		else {
			drop gov var nat_currency
			format value %20.4f
			if (`i' == 4310) rename value Tot_EI_Rev	
			if (`i' == 4320) rename value Tot_Gift_Rev			
		}
		cap drop _m
		tempfile `group'`i'
		save "``group'`i''", replace
		}
	}
	qui {
	use "``group'4300'", clear
	merge 1:1 geo3 year using "``group'4310'", nogen
	merge 1:1 geo3 year using "``group'4320'", nogen
	compress
	tempfile `group'
	save "``group''", replace
	}
}

// If a country is both in "members" and "non-members", use the first as prevalent
use "`nonmembers'", clear
cap drop _m
merge 1:1 geo3 year using "`members'", update replace 
preserve 
	keep if _m == 2 // only in members
	drop _m
	tempfile onlym
	save "`onlym'", replace
restore
drop if _m == 2
drop _m

append using "`onlym'"
gen GeoReg = "_na"
replace Geo = "VN" if geo3 == "VNM"
order Geo geo3 year Cur GeoReg
sort geo3 year

save "$intfile/OECDrev_data_$oecd_ver.dta", replace




