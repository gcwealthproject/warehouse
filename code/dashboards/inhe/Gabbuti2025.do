//settings
clear all

local source Gabbuti2025
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/Data_GM_ROIW.xlsx"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import excel "`rawdata'", sheet("successioni - flussi") cellrange(A9:AN210) firstrow clear

gen percentile="p0p100"
gen area="IT"

keep area percentile AG Thispaper
rename (AG Thispaper) (year value)

keep year area value percentile
gen dashboard = "i"
gen sector = "hs"
gen vartype = "rto"
gen concept = "etnweg"
gen specific = "ff"

drop if value==.

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
