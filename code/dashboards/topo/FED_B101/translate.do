* paths 
global origin "${topo_dir_raw}/FED_B101/raw data"
global aux "${topo_dir_raw}/FED_B101/auxiliary files"
global intermediate_to_erase "${topo_dir_raw}/FED_B101/intermediate to erase"
global intermediate "${topo_dir_raw}/FED_B101/intermediate"

* Import dates
import delimited "${origin}/b101.csv", delimiter(comma) varnames(1) stringcols(_all) clear
keep if substr(date, -2, 2) == "Q4"
ds
foreach v of varlist `r(varlist)' {
    rename `v' `=upper("`v'")'
}
gen year = real(substr(DATE, 1, 4))
drop DATE
rename (*Q) (*A)

* Aggregate morgtage debt FL153165005.A = FL153165105.A + FL163165505.A (https://www.federalreserve.gov/apps/fof/SeriesAnalyzer.aspx?s=FL153165005&t=S.6.A&bc=S.6.A:FL154123005&suf=A)
* Destring the variables
destring FL153165105A, replace
destring FL163165505A, replace
gen FL153165005A = FL153165105A + FL163165505A
tostring FL153165005A, replace

preserve

	import excel "${aux}/matched_grid_b101.xls", firstrow clear
	keep varname_source source_code na_code nacode_label 

	keep source_code na_code
	replace source_code = subinstr(source_code, ".", "", .)
	sxpose, clear

*	drop _var10 _var20 _var30 _var36 _var39 // duplicate

	foreach var of varlist * {
		rename `var' `=`var'[1]'
	}
	drop in 1
	gen year = 1
	order year, first
	 
	tempfile code_translator
	save `code_translator'
	
restore

append using `code_translator', force


sort year

findname, all(missing(@[1]))
drop `r(varlist)'

ds year, not 
foreach v of var `r(varlist)' {
		rename `v' `=`v'[1]'
}

drop in 1

destring , replace
	
// from millions to units	
ds year, not 
foreach v of var `r(varlist)'{
	
	replace `v' = `v'*1000000
	
}



	
tempfile pre_pop
save `pre_pop'
	
	
	
use "${aux}/grid_a_stock.dta", clear 

* merge 

merge 1:1 year using `pre_pop', update 	

drop _merge

gen area = "US"
gen sector = "hn"
gen source = "FED_B101"

order area sector source, after(year)

* save
save "${intermediate}/populated_grid.dta", replace





