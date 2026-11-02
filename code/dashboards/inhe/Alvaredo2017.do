//settings
clear all

local source Alvaredo2017
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/AlvaredoGarbintiPiketty2017TablesFigures.xlsx"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import excel "`rawdata'", sheet("DetailsComputUS10") cellrange(A9) clear
rename (A B C D E) (year wealth_income_ratio_AGP mortality_AGP mu_AGP inherit_share_net_wealth_AGP)
keep year wealth_income_ratio_AGP mortality_AGP mu_AGP inherit_share_net_wealth_AGP
replace inherit_share_net_wealth_AGP=inherit_share_net_wealth_AGP*100


//clean
gen percentile="p0p100"
gen area="US"

//generate code variables
keep year area inherit_share_net_wealth_AGP percentile
rename (inherit_share_net_wealth_AGP) (value)
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
