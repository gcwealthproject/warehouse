*cd "C:\Users\mlongmuir\Graduate Center Dropbox\Maximilian Longmuir\gc_wealth_q (1)\raw_data\topo\WID_topo\wid_2024"
*global topo_dir_raw "C:\Users\mlongmuir\Graduate Center Dropbox\Maximilian Longmuir\gc_wealth_q (1)\"
*import excel "C:\Users\mlongmuir\Graduate Center Dropbox\Maximilian Longmuir\gc_wealth_q (1)\raw_data\topo\WID_topo\auxiliary files/wt_imputations_final.xlsx", sheet("imputation_wt") firstrow clear

cd "C:\Users\srapp\Graduate Center Dropbox\Severin Rapp\gc_wealth_q\raw_data\topo\WID_topo\wid_2026"
global topo_dir_raw "C:\Users\srapp\Graduate Center Dropbox\Severin Rapp\gc_wealth_q\"
import excel "C:\Users\srapp\Graduate Center Dropbox\Severin Rapp\gc_wealth_q\raw_data\topo\WID_topo\auxiliary files\wt_imputations_final.xlsx", sheet("imputation_wt") firstrow clear


kountry countryname, from(other) stuck
rename _ISO3N_ country
kountry country, from(iso3n) to(iso2c)
drop country
rename _ISO2C_ country

drop if country == ""
levelsof country, local(ctry)
tempfile imputation_wt
save `imputation_wt'


/*
import delimited "wid_all_data\WID_countries.csv", clear
rename v1 country
rename v2 titlename
rename v3 shortname
rename v4 region
rename v5 region2

drop if _n==1

save "out\WID_countries.dta", replace
*/
levelsof country, local(ctry)

foreach c of local ctry {

capture confirm file "wid_all_data\WID_metadata_`c'.csv"
if _rc != 0 {
	di as text "Skipping `c': metadata file not found"
	continue
}

import delimited "wid_all_data\WID_metadata_`c'.csv",  clear


save "out\WID_meta_`c'.dta", replace



import delimited "wid_all_data\WID_data_`c'.csv",  clear

keep if percentile=="p0p100"




keep if inlist(var, "icwtoqi999", "mcwagri999", "mcwboli999", "mcwbooi999", "mcwbusi999", "mcwcudi999", "mcwdebi999", "mcwdeqi999", "mcwdwei999") | ///
          inlist(var, "mcweqii999", "mcwequi999", "mcwfiei999", "mcwfini999", "mcwhoui999", "mcwlani999", "mcwnati999", "mcwnfai999", "mcwodki999") | ///
          inlist(var, "mcwpenei999", "mcwresi999", "mhwagri999", "mhwboli999", "mhwbusi999", "mhwcudi999", "mhwdebi999", "mhwdwei999", "mhweali999") | ///
          inlist(var, "mhweqii999", "mhwequi999", "mhwfiei999", "mhwfini999", "mhwhoui999", "mhwlani999", "mhwnati999", "mhwnfai999", "mhwodki999") | ///
          inlist(var, "mhwoffi999", "mhwpeni999", "miwagri999", "miwboli999", "miwbusi999", "miwcudi999", "miwdebi999", "miwdwei999", "miweali999") | ///
          inlist(var, "miweqii999", "miwequi999", "miwfiei999", "miwfini999", "miwhoui999", "miwlani999", "miwnati999", "miwnfai999", "miwodki999") | ///
          inlist(var, "miwpenei999", "mnwagri999", "mnwbooi999", "mnwbusi999", "mnwdwei999", "mnweali999", "mnwgxai999", "mnwgxdi999", "mnwhoui999") | ///
          inlist(var, "mnwlani999", "mnwnati999", "mnwnfai999", "mnwnxai999", "mnwodki999", "mpwagri999", "mpwboli999", "mpwbusi999", "mpwcudi999") | ///
          inlist(var, "mpwdebi999", "mpwdwei999", "mpweali999", "mpweqii999", "mpwequi999", "mpwfiei999", "mpwfini999", "mpwhoui999", "mpwlani999") | ///
          inlist(var, "mpwnati999", "mpwnfai999", "mpwodki999", "mpwoffi999", "mpwpenei999", "inyixxi999")

if _N == 0 {
	save "out\WID_`c'.dta", replace
	continue
}

merge m:1 country variable using "out\WID_meta_`c'.dta", nogen keep(3)

replace variable = subinstr(variable, "i999", "999i", .)

drop extrapolation data_points 
save "out\WID_`c'.dta", replace
	

} 

clear 

foreach c of local ctry {
	append using "out\WID_`c'.dta"
}

merge m:1 country using `imputation_wt', keep(3) nogen

keep if wt_imputation == 0 | wt_imputation == 1
drop wt_imputation

preserve
keep if variable=="inyixx999i"
rename value priceindex
keep country year priceindex
qui save "out/raw_prices.dta", replace 
restore

rename value realvalue
drop if variable=="inyixx999i"
save "out\raw_data.dta", replace

//save 
qui collapse (firstnm) realvalue, by(variable country)
qui drop realvalue 
qui export excel "out/var_description", ///
	replace sheet("Sheet1") firstrow(variables)



use "out\raw_data.dta", clear
