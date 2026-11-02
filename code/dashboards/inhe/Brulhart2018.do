//settings
clear all

local source Brulhart2018
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/tab1_brulhart2018.xlsx"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import excel "`rawdata'",  cellrange(D5) firstrow clear
rename (bytinFig6) (b_ef)
keep year b_ef
drop if year==.
isid year

replace b_ef=b_ef/100

//clean
gen percentile="p0p100"
gen area="CH"

//generate code variables
keep year area percentile b_ef
rename (b_ef) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "rto"
gen concept = "etnweg" 
gen specific = "ef"

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
