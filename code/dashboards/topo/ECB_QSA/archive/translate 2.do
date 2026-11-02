
** Set paths here
tempfile all
	
* Origin folder: it contains the excel files to import
global origin "${topo_dir_raw}/ECB_QSA/raw data" 

* Annual datasets (then erased)
global annual "${topo_dir_raw}/ECB_QSA/raw data/dta files/Annual"

* Grid folder
global grid "${topo_dir_raw}/ECB_QSA/auxiliary files"

* Grid-annual datasets (then erased)
global grid_annual "${topo_dir_raw}/ECB_QSA/rawdata/dta files/Annual/Annual, grid"

* Destination folder
global destination "${topo_dir_raw}/ECB_QSA/intermediate"

local counter = 1 

use  "${origin}/hh_qsa_24", replace

*unit_mult==6 -> multiplu obs value with 1000000


gen instr_asset2="A"+instr_asset 

replace instr_asset2="A_"+instr_asset2 if accounting_entry=="A"
replace instr_asset2="L_"+instr_asset2 if accounting_entry=="L"


keep ref_area  instr_asset2 time_period  obs_value  ref_sector

sort ref_area ref_sector time_period instr_asset2

* Collapse to resolve non-unique values (this is only relevant for maturit)
collapse (max) obs_value, by(ref_area ref_sector time_period instr_asset2)



* Reshape the dataset to wide format so that each instr_asset2 becomes a new variable
reshape wide obs_value, i(ref_area ref_sector time_period) j(instr_asset2) string
rename obs_value* *

*** Transpose data
*levelsof instr_asset2, local(varnames)

*foreach var of local varnames {
	*gen `var'=.
	*replace `var'=obs_value if instr_asset2=="`var'"
*}

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
drop if ref_area=="I7"
drop if ref_area=="I8"
drop if ref_area=="I9"

qui rename ref_area area 

qui order area, first

* Generate Financial net worth
qui gen BF90 = A_AF - L_AF


* Recast all variables as double 
foreach var of varlist A_AF- BF90{
   qui recast double `var'
}

	* Adjust dataset organization

		qui label var year_q "Year-quarter"
		qui label var year ""
		qui label var quarter "Quarter" 

		qui order area, first

		qui gen sector = ""
		qui order sector, after(area)
		replace sector="hn" if ref_sector=="S1M"
		replace sector="hs" if ref_sector=="S14"		
		replace sector="np" if ref_sector=="S15"	


		qui gen source = "ECB_QSA"
		qui order source, after(sector)

		*qui sort  title
		
			* Create and qui save annual dataset	
		qui keep if quarter == 4
		qui replace quarter = 0
		
		
		
		qui  save "${annual}/all_a.dta", replace	
		qui sleep 1000
		levelsof area, local(countries)

		foreach c in `countries' {
			foreach s in hn hs np {
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
			foreach s in hn hs np {
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
			qui replace `var' = `var'*1000000
		}
		qui replace BF90 = BF90*1000000
		
			* Re-order
		qui order area sector source, after(quarter)

		qui drop if missing(area) 
		
				foreach v of varlist _all {
			if strpos(`"`:var label `v''"', "XDC") {
				qui drop `v'
			}
		}
		
		
drop ref_sector 

qui save "${destination}/populated_grid.dta", replace

