
** Set paths here
run "code/mainstream/auxiliar/all_paths.do"
tempfile all
* Origin folder: it contains the excel files to import
global origin "${topo_dir_raw}/ECB_QSA/raw data/csv files" 
* Auxiliary folder
global aux "${topo_dir_raw}/ECB_QSA/auxiliary files" 
* Intermediate to erase
global intermediate "${topo_dir_raw}/ECB_QSA/intermediate to erase" 
* Destination folder
global destination "${topo_dir_raw}/ECB_QSA/intermediate" 
global raw "${topo_dir_raw}/ECB_QSA/raw data" 

* 1) Read the NEW single big file ONCE
use "${raw}/hh_qsa_25.dta",  clear
* Keep the columns we need; rename to short names if necessary
* (adjust names to your actual header spelling)

*keep ref_area ref_sector accounting_entry instr_asset maturity title key time_period 
keep ref_area ref_sector accounting_entry instr_asset maturity title key time_period obs_value


* Build normalized fields used downstream
gen str6 sector_for_grid = ref_sector

* A/L prefix (correct)
gen str2 _AL = cond(trim(accounting_entry)=="A","A_","L_")

* AF code
gen str8 _AF = subinstr(instr_asset,"F","AF",.)

* maturity suffix: short->1, long->2, else ""
gen str1 _mat = ""
replace _mat = "1" if maturity=="S"
replace _mat = "2" if maturity=="L"

* final code now matches grid: A_AF… or L_AF… (+1/2 when present)
gen str20 na_code = _AL + _AF + _mat

* Source and label columns to match your old merge
gen strL source_code    = key
gen strL varname_source = title

* drop year 
gen str20 _tp = lower(time_period)
replace _tp = subinstr(_tp, "-", "", .)
gen tq = quarterly(_tp, "YQ")
format tq %tq

tempfile big
save `big', replace


* 2) Country code map (same idea as before)
local countries austria belgium bulgaria croatia cyprus czechrep denmark ///
    estonia finland france germany greece hungary ireland italy latvia ///
    lithuania luxembourg malta netherlands poland portugal ///
    romania slovakia slovenia spain sweden gb

* helper: map long country name -> 2-letter ref_area code
capture program drop _area_of
program define _area_of
    syntax , Country(name)

    if      "`country'"=="austria"      local area "AT"
    else if "`country'"=="belgium"      local area "BE"
    else if "`country'"=="bulgaria"     local area "BG"
    else if "`country'"=="croatia"      local area "HR"
    else if "`country'"=="cyprus"       local area "CY"
    else if "`country'"=="czechrep"     local area "CZ"
    else if "`country'"=="denmark"      local area "DK"
    else if "`country'"=="estonia"      local area "EE"
    else if "`country'"=="finland"      local area "FI"
    else if "`country'"=="france"       local area "FR"
    else if "`country'"=="germany"      local area "DE"
    else if "`country'"=="greece"       local area "GR"
    else if "`country'"=="hungary"      local area "HU"
    else if "`country'"=="ireland"      local area "IE"
    else if "`country'"=="italy"        local area "IT"
    else if "`country'"=="latvia"       local area "LV"
    else if "`country'"=="lithuania"    local area "LT"
    else if "`country'"=="luxembourg"   local area "LU"
    else if "`country'"=="malta"        local area "MT"
    else if "`country'"=="netherlands"  local area "NL"
    else if "`country'"=="poland"       local area "PL"
    else if "`country'"=="portugal"     local area "PT"
    else if "`country'"=="romania"      local area "RO"
    else if "`country'"=="slovakia"     local area "SK"
    else if "`country'"=="slovenia"     local area "SI"
    else if "`country'"=="spain"        local area "ES"
    else if "`country'"=="sweden"       local area "SE"
    else if "`country'"=="gb"           local area "GB"
    else                                local area ""

    c_local area "`area'"
end


* 3) Build the grid workbook, one sheet per sector×country
foreach s in S1M S14 S15 {
    foreach c of local countries {
        quietly {
            use `big', clear
            _area_of, country(`c')
            keep if ref_area == "`area'"

            if "`s'"=="S14"     keep if ref_sector == "S14"
            else if "`s'"=="S15" keep if ref_sector == "S15"
            else if "`s'"=="S1M" keep if ref_sector == "S1M"

            * pick the most recent observation per na_code (within this slice)
            keep na_code source_code varname_source tq obs_value
			bysort na_code (tq): gen byte _keep = (_n==_N) & (obs_value < .)
			keep if _keep
			drop tq obs_value _keep
			duplicates drop na_code, force

      tempfile map
      save `map', replace
        }

        import excel "${aux}/grid_empty.xlsx", sheet("grid_empty") firstrow clear
        drop source_code varname_source
        merge m:1 na_code using `map'
        drop _merge
        drop if na_code=="" & nacode_label=="" & source_code=="" & varname_source==""
        drop if source_code=="" & varname_source==""
        drop source_code
        drop if nacode_label==""

        export excel "${destination}/grid", sheet("`c'_`s'", replace) firstrow(variables)
    }
	display as result "Workbook written to: " as text "`workbook'"
}
