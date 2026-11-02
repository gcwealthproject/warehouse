

** Set paths here
*run "code/Stata/auxiliar/all_paths.do"
global origin "${topo_dir_raw}/Est/raw data"
global aux "${topo_dir_raw}/Est/auxiliary files"
global destination "${topo_dir_raw}/Est/intermediate"


*** part 1

import excel "${aux}/nasa_10_f_bs__custom_3529306_page_by_spreadsheet.xlsx", ///
			sheet("Data") cellrange(A13:AQ104) clear

rename A na_item
rename B varname_source
rename C finpos
rename D finpos_extended

drop in 1
drop if na_item == ""
drop if na_item == "Special value"

// gen na_code from na_item for matching
gen na_code = na_item
replace na_code = "A"+na_code if na_code != "BF90"
replace na_code = "A_"+na_code if finpos == "ASS" & na_code != "BF90"
replace na_code = "L_"+na_code if finpos == "LIAB" & na_code != "BF90"

// gen source_code
gen source_code = na_item+" ("+finpos+")"

gen nacode_label = ""

keep na_code source_code	nacode_label varname_source

drop in L
replace source_code = "BF90" if na_code == "BF90"

tempfile temp_1
save `temp_1'

qui import excel "${aux}/grid_empty.xlsx", sheet("grid_empty") firstrow clear 

drop varname_source source_code
merge 1:1 na_code using "`temp_1'", update 
drop _merge
drop if varname_source == ""
drop if nacode_label == ""

tempfile temp_2
save `temp_2'



*** end of part 1

*** part 2


// Import
* import delimited "${origin}/nasa_10_f_bs__custom_3518312_linear.csv",  varnames(1) delimiter(";") clear // June 2023 Version
*import delimited "${origin}/nasa_10_f_bs__custom_7119296_linear.csv",  varnames(1) clear // August 2023 Version
*import delimited "${origin}/nasa_10_f_bs__custom_11875082_linear.csv",  varnames(1) clear // Juni 2024 Version			
*import delimited "${origin}/nasa_10_f_bs__custom_18259401_linear.csv",  varnames(1) clear // October 2025 Version			
import delimited "${origin}/nasa_10_f_bs__custom_20747415_linear.csv",  varnames(1) clear // March 2026 Version	


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

//drop if area == "EU27_2020"
//drop if area == "EA20" 
replace area = "EU27" if area == "EU27_2020"
replace sector = "S1M" if sector == "S14_S15"

// keep only sector, na_code and area (old: for which there are data in 2019)
*duplicates drop sector na_code area, force 

keep if year==2019
replace obs_value = . if obs_value == 0
drop if obs_value == .
drop year obs_value

replace sector = "hn" if sector == "S1M"
replace sector = "hs" if sector == "S14"
replace sector = "np" if sector == "S15"

levelsof sector, local(loc_sector)
quietly levelsof area, local(areas) clean
local n : word count `areas'

tempfile temp_sector
save `temp_sector'

* 1) ensure a clean workbook for this run
cap erase "${destination}/grid.xlsx"

foreach s of local loc_sector {

    use `temp_sector', clear
    keep if sector == "`s'"

    tempfile temp_area
    save `temp_area'

    * get list of areas for this sector
    levelsof area, local(loc_area) clean
    di as res "Areas to export for sector `s': `loc_area'"

    foreach a of local loc_area {

        use `temp_area', clear
        keep if area == "`a'"

        * merge additional info (assumes `temp_2' exists with key na_code)
        merge 1:1 na_code using "`temp_2'", update

        * tidy up
        drop if sector == ""
        drop _merge sector area
        drop if source_code == ""

        * 2) write/update the sheet for this area×sector
        export excel using "${destination}/grid.xlsx", ///
            sheet("`a'_`s'") firstrow(variables) sheetreplace
    }
}

 

