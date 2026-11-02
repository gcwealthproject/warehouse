*net install readhtml, from(https://ssc.wisc.edu/sscc/stata/)
*ssc install wid
*cd "C:\Users\Max-p\Dropbox\gc_wealth_q (1)\"
*cd "C:\Users\mlongmuir\Dropbox (Graduate Center)\gc_wealth_q (1)\"
//settings
clear all
run "code/mainstream/auxiliar/all_paths.do"


// Imputations

import excel "${topo_dir_raw}/WID_topo/auxiliary files/wt_imputations_final.xlsx", sheet("imputation_wt") firstrow clear
tempfile imputation_wt
save `imputation_wt'



 //1. Copy code table from web (to get list of wealth variables)

//copy and read table  
local web "https://wid.world/codes-dictionary"
readhtmltable `web', varnames

//delete what we dont need 
qui keep t*c*
forvalues x = 1/68 {
	if !inrange(`x', 69, 75) {
		cap drop t`x'c*
	}
}

//reshape 
tempfile appender
forvalues x = 69/75 {
	preserve 
		qui keep t`x'*
		qui rename (t`x'c1 t`x'c2) (code description)
		qui drop if missing(code)
		if `x' > 69 qui append using `appender'
		qui save `appender', replace 
		di as result `x'
		levelsof code 
	restore 
}
qui use `appender', clear 

qui levelsof code, local(wcodes) clean 
foreach c in `wcodes' {
	//dont include govt variables 
	if substr("`c'", 1, 1) == "g" continue 
	//add a prefix (or not)
	if "`c'" != "icwtoq" {
		local wcodes2 `wcodes2' m`c'
	}
	else {
		local wcodes2 `wcodes2' `c'
	}
}
di as result "List of wealth codes: `wcodes2'"

//download data 
wid, indicators(`wcodes2') clear /* metadata */ 
rename value realvalue
merge m:1 countryname using `imputation_wt' // Block to drop imputed files
keep if _merge==3
drop _merge
keep if wt_imputation == 0 | wt_imputation == 1
drop wt_imputation
qui save "${topo_dir_raw}/WID_topo/raw data/raw_data.dta", replace 

//save 
qui collapse (firstnm) realvalue, by(variable shortname)
qui drop realvalue 
qui export excel "${topo_dir_raw}/WID_topo/auxiliary files/var_description", ///
	replace sheet("Sheet1") firstrow(variables)


//download data 
wid, indicators(inyixx) clear /* metadata */ 
rename value priceindex
merge m:1 countryname using `imputation_wt' // Block to drop imputed files
keep if _merge==3
drop _merge
keep if wt_imputation == 0 | wt_imputation == 1
drop wt_imputation
keep country year priceindex
qui save "${topo_dir_raw}/WID_topo/raw data/raw_prices.dta", replace 
