
global origin "${topo_dir_raw}/BoI_NA/raw data"
global aux "${topo_dir_raw}/BoI_NA/auxiliary files"
global intermediate_to_erase "${topo_dir_raw}/BoI_NA/intermediate to erase"
global intermediate "${topo_dir_raw}/BoI_NA/intermediate"


* Data are in millions of euros
import excel "${origin}/data.xlsx", sheet("data")  cellrange(A1:W42)  clear
	
	
drop A // Drop varname_source in Italian

// Destring and create years as variables
foreach var of varlist D-S {
	destring `var', generate(item_`var')
	drop `var'
	local temp = item_`var'[_n]
	rename item_`var' _`temp' 
}

replace B = "varname_source" if B == "Assets/Liabilities" 

// Create varname_source and na_code
foreach var of varlist B-C {
rename `var' `=`var'[1]'
}

drop in 1 // drop first obs

drop if na_code == "" // drop unmatched

* Clean varname_source
replace varname_source = "Research and development" ///
	if varname_source == "of which: Research and development"
replace varname_source = "Computer software and databases" ///
	if varname_source == "of which: Computer software and databases"
replace varname_source = "Financial assets" ///
	if varname_source == "Financial assets (b)"
replace varname_source = "Financial liabilities" ///
	if varname_source == "Financial liabilities (c)"
		

drop varname_source	

sxpose, clear force  firstnames destring



foreach var of varlist * {
	replace `var' = `var'*1000000
}

gen year = _n + 2004

order year, first

	
tempfile pre_pop
save `pre_pop'
	
	
use "${aux}/grid_a_stock.dta", clear 

* merge 

merge 1:1 year using `pre_pop', update 	

drop _merge

gen area = "IT"
gen sector = "hn"
gen source = "BoI_NA"

order area sector source, after(year)

* save
save "${intermediate}/populated_grid.dta", replace





