//settings
clear all

local source Acciari2021
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/inheritance_share_data_acciari_morelli.xls"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import excel "`rawdata'", sheet("inheritance data") firstrow clear
keep year inherit_gift_under gift_under inherit_under
rename (inherit_gift_under gift_under inherit_under) (inherit_gift_corrected_AM gift_corrected_AM inherit_corrected_AM)
foreach v of varlist inherit_gift_corrected_AM gift_corrected_AM inherit_corrected_AM {
	replace `v'=`v'*1000000000
}

preserve
import excel "`rawdata'", sheet("National Income") firstrow clear cellrange(A2)
keep year NI 
foreach v of varlist NI {
	replace `v'=`v'*1000000000
}
tempfile ni
save `ni'
restore

merge 1:1 year using `ni', nogen assert(match)

//clean
gen percentile="p0p100"
gen area="IT"

//generate code variables
preserve
keep year area inherit_corrected_AM inherit_gift_corrected_AM percentile
reshape long @_corrected_AM, i(year area percentile) j(concept) string
rename (_corrected_AM) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "agg"
replace concept = "etnweg" if concept=="inherit_gift"
replace concept = "etnwea" if concept=="inherit"
gen specific = "ff"
tempfile agg
save `agg'
restore

foreach v of varlist inherit_corrected_AM inherit_gift_corrected_AM {
	gen `v'_y_rto=`v'/NI
}

keep year area inherit_corrected_AM_y_rto inherit_gift_corrected_AM_y_rto percentile
reshape long @_corrected_AM_y_rto, i(year area percentile) j(concept) string
rename (_corrected_AM_y_rto) (value)

gen dashboard = "i"
gen sector = "hs"
gen vartype = "rto"
replace concept = "etnweg" if concept=="inherit_gift"
replace concept = "etnwea" if concept=="inherit"
gen specific = "ff"

append using `agg'

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
