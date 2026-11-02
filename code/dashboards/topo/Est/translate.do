
** Set paths here
*run "Code/Stata/auxiliar/all_paths.do"
tempfile all
	
* Origin folder: it contains the excel files to import
global origin "${topo_dir_raw}/Est/raw data" 

* Grid folder
global grid "${topo_dir_raw}/Est/auxiliary files"

* Intermediate to erase folder
global intermediate_to_erase "${topo_dir_raw}/Est/intermediate to erase"

* Intermediate folder
global intermediate "${topo_dir_raw}/Est/intermediate"


// Import

*import delimited "${origin}/nasa_10_f_bs__custom_3518312_linear.csv",  varnames(1) delimiter(";") clear // June 2023 Version
*import delimited "${origin}/nasa_10_f_bs__custom_7119296_linear.csv",  varnames(1) clear // August 2023 Version
*import delimited "${origin}/nasa_10_f_bs__custom_11875082_linear.csv",  varnames(1) clear // Juni 2024 Version
*import delimited "${origin}/nasa_10_f_bs__custom_18259401_linear.csv",  varnames(1) clear // October 2025 Version			
import delimited "${origin}/nasa_10_f_bs__custom_20747415_linear.csv",  varnames(1) clear // October 2025 Version			


// drop vars we don't need
drop dataflow lastupdate freq obs_flag

rename time_period year

drop co_nco // we always work with non consolidated data

levelsof unit // millions of national currency
replace obs_value = obs_value*1000000
drop unit


// Transform na_item in na_code
drop if na_item == "BF90" // drop financial net worth (we generate it after)
replace na_item = "A"+na_item

replace na_item = "A_"+na_item if finpos == "ASS"
replace na_item = "L_"+na_item if finpos == "LIAB"

rename na_item na_code //done!

rename geo area // Rename area

drop finpos // finpos already included in na_code

replace area = "EU27" if area == "EU27_2020"

replace sector = "S1M" if sector == "S14_S15"
****
// tranpose


levelsof sector, local(loc_sector)

tempfile temp_1
save `temp_1'

foreach s of local loc_sector {

    use `temp_1', clear
    keep if sector=="`s'"

    levelsof area, local(loc_area)

    foreach a of local loc_area {

        * 1) Filter to this country/sector
        use `temp_1', clear
        keep if sector=="`s'" & area=="`a'"
        count
        if r(N)==0 continue    // nothing to do

        * 2) Build wide table: one column per na_code
        keep year na_code obs_value
        * If there are accidental duplicates: uncomment the next line
        * duplicates drop year na_code, force

        reshape wide obs_value, i(year) j(na_code) string

        * 3) Make clean variable names: obs_valueA_AF62 -> A_AF62, etc.
        ds obs_value*
        foreach v of varlist `r(varlist)' {
            local new = subinstr("`v'","obs_value","",1)
            rename `v' `new'
        }

        * 4) Add identifiers
        gen area   = "`a'"
        gen sector = cond("`s'"=="S1M","hn",cond("`s'"=="S14","hs","np"))
        order year area sector

        tempfile _wide
        save `_wide'

        * 5) Merge onto your year grid template so all expected columns exist
        use "${grid}/grid_a_stock.dta", clear
        merge 1:1 year using `_wide', update
        drop _merge

        * 6) Compute BF90 if the aggregates exist; otherwise leave missing
        capture confirm variable A_AF
        if !_rc capture confirm variable L_AF
        if !_rc {
            capture drop BF90
            gen double BF90 = A_AF - L_AF
        }

        * 7) Source + final ordering
        gen source = "Est"
        replace sector = cond("`s'"=="S1M","hn",cond("`s'"=="S14","hs","np"))
        replace area   = "`a'"
        order year area sector source

        * 8) Save exactly like your original naming
        save "${intermediate_to_erase}/pop_grid_`a'_`s'.dta", replace
    }
}
 
 
drop _all

//put all the metadata together 
clear
local files : dir "${intermediate_to_erase}/" files "pop_grid_*.dta",  respectcase 
global files `files' 
local iter = 1 
tempfile ap 
foreach f in "$files" {
	qui use "${intermediate_to_erase}/`f'", clear 
	if `iter' != 1 qui append using `ap'
	qui save `ap', replace 
	local iter = 0 
	qui erase "${intermediate_to_erase}/`f'"
}

save "${topo_dir_raw}/Est/intermediate/populated_grid.dta", replace
 