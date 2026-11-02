** Set paths here
run "code/mainstream/auxiliar/all_paths.do"
tempfile all

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
	

* generate grid
*preserve
	keep varname_source na_code
	tempfile temp_grid
	save `temp_grid'
	
	qui import excel "${aux}/grid_empty.xlsx", sheet("grid_empty") firstrow clear 
	drop varname_source
	
	foreach var of varlist source_code  {
		tostring `var', gen(str_`var')
		drop `var'
		rename str_`var' `var' 
}
	drop if na_code == ""
	
	merge 1:m na_code using `temp_grid'
	
	drop _merge

	drop if varname_source == ""
	replace source_code = ""
	
	export excel using "${intermediate}/grid.xls", firstrow(variables) replace
*restore	
	
