//settings
clear all

local source Guzzardi2026
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/data_for_gcwealth_project.dta"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
use "`rawdata'", clear

preserve
import excel "`sourcef'\raw data\geo_code.xlsx", sheet("Foglio1") firstrow clear
rename GEO3 iso
tempfile iso
save `iso'
restore

merge m:1 iso using `iso', keep(master match)
assert (_merge==3)
drop _merge

drop iso 
//clean
gen percentile="p0p100"

rename GEO area

//generate code variables
preserve
keep year area inherit_net_wealth_mu_ipo_avg percentile
rename (inherit_net_wealth_mu_ipo_avg) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "agg"
gen concept = "etnweg"
gen specific = "ef"
tempfile agg
save `agg'
restore

preserve
keep year area inherit_ni_ratio percentile
rename (inherit_ni_ratio) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "rto"
gen concept = "etnweg"
gen specific = "ef"
replace value=value/100
tempfile rto
save `rto'
restore

keep year area tax_rate_inherit percentile
rename (tax_rate_inherit) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "rat"
gen concept = "averat"
gen specific = "ef"
replace value=value/100

append using `agg'
append using `rto'

egen varcode = concat(dashboard sector vartype concept specific), ///
	punct ("-")  

drop dashboard sector vartype concept specific

isid area year varcode


//gen warehouse variables	
// gen area = GEO3
gen source = "`source'"
//order
order area year value percentile varcode
sort area year value
//export
qui export delimited "`results'", replace 
