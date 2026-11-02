
** Set paths here
tempfile all
	
* Origin folder: it contains the excel files to import
global origin "${topo_dir_raw}/ECB_DWA_topo/raw data" 

* Annual datasets (then erased)
global annual "${topo_dir_raw}/ECB_DWA_topo/raw data/dta files/Annual"

* Grid folder
global grid "${topo_dir_raw}/ECB_DWA_topo/auxiliary files"

* Grid-annual datasets (then erased)
global grid_annual "${topo_dir_raw}/ECB_DWA_topo/rawdata/dta files/Annual/Annual, grid"

* Destination folder
global destination "${topo_dir_raw}/ECB_DWA_topo/intermediate"

local counter = 1 


qui use "${origin}/hh_dwa", clear

qui rename key source_code

qui rename title varname_source

qui rename ref_area area

qui gen na_code= account_entry + "_A" + instr_asset
replace na_code="NWA" if na_code=="N_ANWA"
replace na_code="ANUB" if na_code=="A_ANUB"
replace na_code="ANUN" if na_code=="A_ANUN" 
replace na_code="XAF42LM" if na_code=="L_AF4B" 


** Dates column
qui rename time_period fulldate
replace fulldate=subinstr(fulldate,"-","", .)
qui gen year_q = quarterly(fulldate, "YQ")
qui format year_q %tq

qui split fulldate, p("Q")
qui encode fulldate1, gen(year)
qui encode fulldate2, gen(quarter)
qui drop fulldate fulldate1 fulldate2
qui order year_q, first
qui order year, after(year_q)
qui order quarter, after(year)

*harmonize country names (iso2c)
drop if area=="I9"

qui order area, first

levelsof  na_code, local(vars)

qui gen id = _n
foreach v of local vars {

qui gen `v' = obs_value if na_code== "`v'"

* reduce dataset to one year-country observation
qui gen  `v'_var = .
qui replace  `v'_var =  `v'  if !missing(`v')
local vars2 "`vars2' `v'_var"
}

qui collapse (max) `vars2', by(area year_q year quarter)

foreach v of local vars {
qui rename `v'_var `v'
qui recast double `v'
}

 
* Adjust dataset organization

qui label var year_q "Year-quarter"
qui label var year ""
qui label var quarter "Quarter" 

qui order area, first

qui gen sector = "hs"
qui order sector, after(area)


qui gen source = "ECB_DWA_topo"
qui order source, after(sector)

		

		*qui sort  title
		
	* Create and qui save annual dataset	
qui keep if quarter == 4
qui replace quarter = 0



qui  save "${annual}/all_a.dta", replace	
qui sleep 1000
levelsof area, local(countries)

foreach c in `countries' {
	foreach s in hs {
		qui use "${annual}/all_a.dta", clear
		qui keep if area=="`c'"
		keep if sector=="`s'"
		qui save "${annual}/`c'_a_`s'.dta", replace	
		qui use "${grid}/grid_a_stock.dta", clear 
		qui merge 1:1 year_q using "${annual}/`c'_a_`s'.dta", update 
		qui drop _merge
		qui save "${annual}/`c'_a_`s'_merged.dta", replace	
	}
		*qui merge 1:m year_q  using "${topo_dir_raw}/all_a.dta", update 
}
qui sleep 1000
clear

foreach c in `countries' {
	foreach s in hs {
		qui append using "${annual}/`c'_a_`s'_merged.dta"

		qui erase "${annual}/`c'_a_`s'.dta"
		qui erase "${annual}/`c'_a_`s'_merged.dta"
	}
	
}

	* Transform variables in units
foreach var of varlist A_* {
	qui replace `var' = `var'*1000000
}
foreach var of varlist L_* {
	qui replace `var' = `var'*1000000*(-1)
}
qui replace NWA  = NWA *1000000
qui replace ANUN  = ANUN *1000000
qui replace ANUB  = ANUB *1000000
qui replace XAF42LM = XAF42LM *1000000*(-1)

	* Re-order
qui order area sector source, after(quarter)

qui drop if missing(area) 



qui save "${destination}/populated_grid.dta", replace
