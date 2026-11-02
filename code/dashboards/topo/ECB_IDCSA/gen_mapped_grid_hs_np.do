** Set paths here
run "code/mainstream/auxiliar/all_paths.do"
tempfile big map

* Folders
global aux          "${topo_dir_raw}/ECB_IDCSA/auxiliary files"
global destination  "${topo_dir_raw}/ECB_IDCSA/intermediate"
global raw          "${topo_dir_raw}/ECB_IDCSA/raw data"

* ---- 1) Read the NEW single big file ONCE ----
* (Update the filename if needed)
use "${raw}/hh_IDCSA.dta",  clear


* Keep the columns we need; adjust names if your header differs
keep ref_area ref_sector accounting_entry instr_asset maturity key time_period obs_value comment_ts

* Normalize fields used downstream (build na_code like the old per-country code did)
gen str2  _AL = cond(trim(accounting_entry)=="A","A_","L_")
gen str12 _AF = subinstr(instr_asset,"F","AF",.)   // e.g. F4 -> AF4, F51M -> AF51M
gen str1  _mat = ""
replace _mat = "1" if maturity=="S"
replace _mat = "2" if maturity=="L"
gen str20 na_code = _AL + _AF + _mat

* Parse time_period (take latest non-missing per slice)
gen str20 _tp = lower(time_period)
replace _tp = subinstr(_tp,"-","",.)
gen tq = quarterly(_tp,"YQ")
format tq %tq

save `big', replace

* 1) Split comment_ts into hyphen-delimited chunks
split comment_ts, parse(" - ") gen(seg) trim    // creates seg1 seg2 seg3 seg4 ...

* 2) Extract asset type and maturity text
gen strL asset_type    = strtrim(seg3)
gen strL maturity_text = strtrim(seg4)

* 3) Normalize maturity label (keep nice phrasing even if seg4 varies)
* Default
generate strL maturity_std = "All original maturities"

* If seg4 contains "short"
replace maturity_std = "Short-term original maturity (up to 1 year)" ///
    if regexm(lower(maturity_text), "short")

* If seg4 contains "long"
replace maturity_std = "Long-term original maturity (over 1 year or no stated maturity)" ///
    if regexm(lower(maturity_text), "long")

* 4) Label for A/L from accounting_entry
gen strL al_label = cond(accounting_entry=="A", ///
    "Assets (Net Acquisition of)", "Liabilities (Net Incurrence of)")
	
gen strL varname_source =  al_label + ", " + asset_type + ", " + maturity_std
gen strL nacode_label =  asset_type + ", " + maturity_std

tempfile big
save `big', replace

drop seg* asset_type maturity_text maturity_std al_label 
tempfile big
save `big', replace

* ---- 2) Country code map for your IDCSA list ----
local countries australia brazil canada chile colombia  gb iceland israel  japan korea mexico norway northmacedonia newzealand ///
                russia turkey usa switzerland

capture program drop _area_of
program define _area_of
    syntax , Country(name)
    if      "`country'"=="canada"          local area "CA"
	else if "`country'"=="australia"	   local area "AU"
	else if "`country'"=="brazil"   	   local area "BR"
	else if "`country'"=="chile"           local area "CL"
    else if "`country'"=="colombia"        local area "CO"
    else if "`country'"=="iceland"         local area "IS"
    else if "`country'"=="israel"          local area "IL"
	else if "`country'"=="india"           local area "IN"
    else if "`country'"=="japan"           local area "JP"
	else if "`country'"=="korea"           local area "KR"
    else if "`country'"=="mexico"          local area "MX"
    else if "`country'"=="newzealand"      local area "NZ"
    else if "`country'"=="northmacedonia"  local area "MK"
    else if "`country'"=="norway"          local area "NO"
	else if "`country'"=="russia"          local area "RU"
    else if "`country'"=="switzerland"     local area "CH"
    else if "`country'"=="turkey"          local area "TR"
    else if "`country'"=="gb"              local area "GB"
	else if "`country'"=="usa"   		   local area "US"
    else                                   local area ""
    c_local area "`area'"
end


* ---- 3) Build the grid workbook (one sheet per country × sector) ----
local workbook "${destination}/grid_hs_np.xlsx"
display as txt "Writing workbook to: `workbook'"

foreach s in S14 S15 {
    foreach c of local countries {
		quietly {
        use `big', clear
        _area_of, country(`c')

        * Slice the big file by country & sector
        keep if ref_area  == "`area'"
        keep if ref_sector == "`s'"

        count
        local sliceN = r(N)

        * If slice is empty, write EMPTY sheet and continue to next combo
        if `sliceN'==0 {
						* --- EMPTY SLICE: write an empty (one-blank-row) sheet and continue ---
			import excel "${aux}/grid_empty.xlsx", sheet("grid_empty") firstrow clear
			keep in 1                         // keep 1 row to satisfy export
			foreach v of varlist _all {       // blank out that row
				capture confirm string variable `v'
				if _rc==0 replace `v'=""
				capture confirm numeric variable `v'
				if _rc==0 replace `v'=.
			}
			export excel using "`workbook'", sheet("`c'_`s'") firstrow(variables) sheetreplace
			continue
        }
		}
        * Keep only needed columns
        keep na_code varname_source tq obs_value

        * Latest non-missing per na_code
        bysort na_code (tq): keep if _n==_N
        keep if obs_value < .
        drop tq obs_value
        duplicates drop na_code, force

        count
        local afterN = r(N)

        tempfile map
        save `map', replace emptyok

        * Merge with template and export
        import excel "${aux}/grid_empty.xlsx", sheet("grid_empty") firstrow clear
        capture drop varname_source   // avoid type clash from template
        merge m:1 na_code using `map', keep(1 3) nogen

        count
        local mergedN = r(N)

        * Optional pruning
        drop if varname_source==""
        capture drop source_code
        drop if nacode_label==""

        count
        local finalN = r(N)

        * If pruning killed everything, still write an EMPTY sheet
       if `finalN'==0 {
			import excel "${aux}/grid_empty.xlsx", sheet("grid_empty") firstrow clear
			keep in 1
			foreach v of varlist _all {
				capture confirm string variable `v'
				if _rc==0 replace `v'=""
				capture confirm numeric variable `v'
				if _rc==0 replace `v'=.
			}
			export excel using "`workbook'", sheet("`c'_`s'") firstrow(variables) sheetreplace
			continue
		}

        export excel using "`workbook'", sheet("`c'_`s'") firstrow(variables) sheetreplace
    }
}

