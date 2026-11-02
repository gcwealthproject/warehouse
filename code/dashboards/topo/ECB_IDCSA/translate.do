 
** Set paths here
tempfile all2

* Origin folder: it contains the excel files to import
global origin "${topo_dir_raw}/ECB_IDCSA/raw data" 

* Annual datasets (then erased)
global annual "${topo_dir_raw}/ECB_IDCSA/raw data/dta files/Annual"

* Grid folder
global grid "${topo_dir_raw}/ECB_IDCSA/auxiliary files"

* Grid-annual datasets (then erased)
global grid_annual "${topo_dir_raw}/ECB_IDCSA/raw data/dta files/Annual, grid"

* Destination folder
global destination "${topo_dir_raw}/ECB_IDCSA/intermediate"

local counter = 1

use  "${origin}/hh_IDCSA", replace

*unit_mult==6 -> multiplu obs value with 1000000



gen instr_asset2="A"+instr_asset 

replace instr_asset2="A_"+instr_asset2 if accounting_entry=="A"
replace instr_asset2="L_"+instr_asset2 if accounting_entry=="L"

keep ref_area  instr_asset2 time_period  obs_value  ref_sector

sort ref_area ref_sector time_period instr_asset2

* Collapse to resolve non-unique values (this is only relevant for maturity of the Liability assets. The collapse command basically drops out short term maturities if information is double)
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

replace time_period = time_period + "-Q4" if !strpos(time_period,"-Q")
keep if substr(time_period, -2, 2) == "Q4"


qui rename time_period fulldate
qui replace fulldate=subinstr(fulldate,"-","", .)
qui gen year_q = quarterly(fulldate, "YQ")
qui format year_q %tq
qui split fulldate, p("Q")
qui encode fulldate1, gen(year)
qui encode fulldate2, gen(quarter)
qui drop fulldate fulldate1 fulldate2
qui order year_q, first
qui order year, after(year_q)
*** THiS fixes some issues with some vars, that show suddenly "." instead of "0" from 2015 
// Get distinct levels of ref_area into the local macro `ctry`
levelsof ref_area, local(ctry)

// Loop over each country/area
foreach c of local ctry {
    // Loop over the specific range of variables between A_AF and L_AF89
    foreach var of varlist A_AF-L_AF89 {
        // Count the number of missing values for the variable in the specific country/area
        count if missing(`var') & ref_area == "`c'"
        local missing_obs = r(N)

        // Count the number of zero values for the variable in the specific country/area
        count if `var' == 0 & ref_area == "`c'"
        local zero_obs = r(N)
        
        // Replace missing values with 0 if there are fewer than 10 missing observations
        // AND at least one zero value is present
        if (`missing_obs' < 10) & (`zero_obs' > 0) {
            replace `var' = 0 if missing(`var') & ref_area == "`c'"
        }
    }
}

qui rename ref_area area 

qui order area, first

* Generate Financial net worth
qui gen BF90 = A_AF - L_AF


* Recast all variables as double 
foreach var of varlist A_AF- BF90{
   qui recast double `var'
}
*drop obs_value
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


		qui gen source = "ECB_IDCSA"
		qui order source, after(sector)

		*qui sort  title
		
			* Create and qui save annual dataset	
*		qui keep if quarter == 4
		qui replace quarter = 0
		qui save "${topo_dir_raw}/all_a.dta", replace	

		qui use "${grid}/grid_a_stock.dta", clear 

		qui merge 1:m year_q using "${topo_dir_raw}/all_a.dta", update 
		
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

preserve
keep if sector=="hn"
save "${destination}/populated_grid_hn.dta", replace
restore


drop if sector=="hn"
save "${destination}/populated_grid_hs_np.dta", replace


/*
cd "${grid_annual}"
local list : dir . files "*_grid*.dta" 
foreach f of local list {
    erase "`f'"  // erase the file to save memory
}
*/




