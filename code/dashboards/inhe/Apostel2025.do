//settings
clear all

local source Apostel2025
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/Belgium_wealth_transfer_flows_Arthur.csv"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import delimited "`rawdata'",  clear
cap rename ïyear year

keep year gift_flow inh_flow 
gen inherit_gift_Apostel=inh_flow+gift_flow

//clean
gen percentile="p0p100"
gen area="BE"

//generate code variables
preserve
keep year area inherit_gift_Apostel percentile
rename (inherit_gift_Apostel) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "agg"
gen concept = "etnweg"
gen specific = "ff"
tempfile agg
save `agg'
restore

keep year area inh_flow percentile
rename (inh_flow) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "agg"
gen concept = "etnwea"
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
