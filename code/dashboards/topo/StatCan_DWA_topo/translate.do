 // translate

** Set paths here
global aux "${topo_dir_raw}/StatCan_DWA_topo/auxiliary files"
global intermediate "${topo_dir_raw}/StatCan_DWA_topo/intermediate"
global origin "${topo_dir_raw}/StatCan_DWA_topo/raw data"

// load variable abbreviations 
use "${aux}/grid_a_stock", clear 
tempname map
postfile `map' str32 wealth_abbr str80 wealth_full using "${intermediate}/temp_grid_a_stock.dta", replace

// Step 3: Loop through variables and collect names/labels
foreach var of varlist * {
    local lbl : variable label `var'
    post `map' ("`var'") ("`lbl'")
}

// Step 4: Finalize the file and clear
postclose `map'
use "${intermediate}/temp_grid_a_stock.dta", clear
drop if missing(wealth_abbr) | missing(wealth_full)
rename wealth_full wealth
rename wealth_abbr abbr
save "${intermediate}/temp_grid_a_stock.dta", replace

// Step 3: Load main dataset and merge abbreviations 
qui import delimited using ///
	"${origin}/3610066001_databaseLoadingData", varnames(1) delimiter(comma) case(lower) clear

// strip BOM from first variable name (file has UTF-8 BOM)
 ds
  local vars `r(varlist)'
  local firstvar : word 1 of `vars'
  if "`firstvar'" != "ref_date" rename `firstvar' ref_date
	describe
	merge m:1 wealth using "${intermediate}/temp_grid_a_stock.dta"
	
// Step 4: clean and rename
drop  _merge
rename geo area
rename ref_date year 
keep area year abbr value 

// Step 5: wide format 
levelsof abbr, local(loc_var)
foreach n of local loc_var {
    gen `n' = .
    replace `n' = value if abbr == "`n'"
}
drop abbr value
collapse (mean) `loc_var', by(area year)
order area year
sort area year
drop area
gen area = "CA"
order area, first

// Step 6: replace 0 with missing
foreach v of varlist AN-NWA {
	replace `v' = . if `v' == 0
}

// Step 7: filter quarters and fix dates 
keep if substr(year, -2, .) == "10"
replace year = substr(year, 1, 4)

// Step 8: save
save "${intermediate}/populated_grid.dta", replace

	
	
	
	
	
	
	
	
	
	


