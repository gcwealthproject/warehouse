//settings
clear all

local source Schinke2012
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/data_table_10.xlsx"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import excel "`rawdata'", cellrange(B4) firstrow clear

replace inherit_share_schinke=inherit_share_schinke*100

//clean
gen percentile="p0p100"
gen area="DE"

//generate code variables

keep year area inherit_share_schinke percentile
rename (inherit_share_schinke) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "rto"
gen concept = "etnweg"
gen specific = "ef"
replace value=value/100

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
