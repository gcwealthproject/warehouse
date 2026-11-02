********************************
*** EIGT revenue data downloader
********************************

global oecd_ver 02feb2024

display "OECD Revenue download, version $oecd_ver"

// Author: Twisha and Francesca
// Last update: February 2024

// Data used: $hmade/eigt_transcribed.xlsx, $intfile/country_codes.dta
// Output: $intfile/eigt_taxsched.dta

// Content: take OECD Revenue data from the web
// and save separately the data about revenues and the currency files

**** 4000 (Property tax Revenues) **********
**** 4110 (household recurrent taxes on immovable property Revenues) **********
**** 4210 (individual recurrent taxes on net wealth Revenues) **********
**** 4300 (EIG Revenues) **********
**** 4310 (EI Revenues) **********
**** 4320 (G Revenues) **********
 
// Package required, automatic check 
	cap which sdmxuse
	if _rc ssc install sdmxuse	
	
foreach group in members nonmembers {
	foreach i in 4000 4110 4210 4300 4310 4320 {

		qui {
		if ("`group'" == "members") sdmxuse data OECD, dataset(REV) dimensions(.`i'.) attributes clear
		else sdmxuse data OECD, dataset(RS_GBL) dimensions(..`i'.) attributes clear
		compress
		
		/// Clean 
		rename (cou unit time) (geo3 curren year)
		
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
			drop gov var
			// Replace currency with national currency for reshaping
			replace curren = "" if curren == "PC"
			egen id = group(geo3)
			xfill curren, i(id)
			drop id
			
			cap drop _m
			reshape wide value, i(geo3 year) j(grouping) string

			rename value* *
					
			drop Loc_Rev_GDP
		}
		
		************************* Rename  *******************************

		if (`i' != 4300 & `i' != 4000 )  {
			drop gov var
			if (`i' == 4310) rename value Tot_EI_Rev	
			if (`i' == 4320) rename value Tot_Gift_Rev		
			if (`i' == 4110) rename value Tot_IP_Rev	
			if (`i' == 4210) rename value Tot_NW_Rev		
		}
		cap drop _m
		tempfile `group'`i'
		save "``group'`i''", replace
		}
	}
	qui {
	use "``group'4300'", clear
	merge 1:1 geo3 year using "``group'4000'", nogen	
	merge 1:1 geo3 year using "``group'4110'", nogen
	merge 1:1 geo3 year using "``group'4210'", nogen
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

// Attach 2-digit country codes and country names 
qui: merge m:1 geo3 using "$intfile/country_codes.dta", keep(master matched) keepusing(Geo country)
qui: count if _m == 1
if (`r(N)' != 0) {
	display in red "`r(N)' unmatched countries, check"
	tab country if _m == 1
	drop _m
}
else {
	drop _m
} 

drop geo3 Loc* Reg*
rename (country Geo) (GEO_long GEO)
order GEO GEO_long year curren Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev  ///
	Tot_Prop_Rev Fed_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP
	
rename (Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Tot_Prop_Rev Fed_Prop_Rev ///
		Tot_Rev_GDP Fed_Rev_GDP) (totrev eitrev gifrev fedrev tprrev fprrev trvgdp frvgdp)

// Check ranges 
	foreach var in tprrev fprrev trvgdp frvgdp {
		qui: sum `var'
		if (`r(max)' > 100) display "WARNING: `var' > 100"
	}
	
replace gifrev = 0 if totrev == eitrev & eitrev != .
replace eitrev = 0 if totrev == gifrev & gifrev != .
	
sort GEO year
			
// Set to -999 the missing	
	foreach var in totrev eitrev gifrev fedrev tprrev fprrev trvgdp frvgdp {
		qui: count if `var' == -999 
		if (`r(N)' == 0) replace `var' = -999 if `var' == .
		else display in red "There are -999 values for `var', cannot replace"
	}

// Labels 

// Package required, automatic check 
	cap which labvars
	if _rc ssc install labvars	

labvars GEO GEO_long totrev eitrev gifrev fedrev tprrev fprrev trvgdp frvgdp ///
		"Geo" "country" "Tot_Rev" "Tot_EI_Rev" "Tot_Gift_Rev" "Fed_Rev" ///
		"Tot_Prop_Rev" "Fed_Prop_Rev" "Tot_Rev_GDP" "Fed_Rev_GDP"

// Separate currency
	qui: count if curren == ""
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' missing Currency"
		tab GEO_long if curren == ""
	}
preserve 
	keep GEO year curren
	duplicates drop 
	save "$intfile/eigt_oecdrev_currency_$oecd_ver.dta", replace
restore 		
drop curren
save "$intfile/eigt_oecdrev_data_$oecd_ver.dta", replace




