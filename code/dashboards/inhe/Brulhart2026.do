//settings
clear all

local source Brulhart2026
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/tab_switzerland.xlsx"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import excel "`rawdata'",  cellrange(B4) firstrow clear
rename (B K L M) (year i_ff g_ff b_ff)
keep year i_ff g_ff b_ff
destring i_ff g_ff b_ff, replace
destring year, replace force
drop if year==.
isid year

foreach v of varlist i_ff b_ff g_ff {
	replace `v'=`v'*1000000000  //bring it in CHF and not in billions of CHF
}


//clean
gen percentile="p0p100"
gen area="CH"

//generate code variables
keep year area percentile i_ff b_ff
reshape long b_@ i_@, i(year area percentile) j(specific) string
reshape long @_ , i(year area percentile specific) j(concept) string
rename (_) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "agg"
replace concept = "etnweg" if concept == "b"
replace concept = "etnwea" if concept == "i"
// gen specific = "ff"


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
