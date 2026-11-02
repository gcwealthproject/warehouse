//settings
clear all

local source Atkinson2012
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/Atkinson_tab.xlsx"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import excel "`rawdata'", sheet("Foglio1") cellrange(B4) firstrow clear

keep year asnationalincome Pluscorrectionforexemptasset Plusgiftsintervivosasnati Totalreportedwealthofdeceden
gen inherit_w=Pluscorrectionforexemptasset*Totalreportedwealthofdeceden/asnationalincome
gen inherit_w_gift=Plusgiftsintervivosasnati*Totalreportedwealthofdeceden/asnationalincome

foreach v of varlist inherit_w inherit_w_gift {
replace `v'=`v'*1000000		//bring in pounds instead of millions of pounds	
}

//clean
gen percentile="p0p100"
gen area="UK"

//generate code variables
preserve
keep year area inherit_w inherit_w_gift percentile
reshape long inherit_@, i(year area percentile) j(concept) string
rename (inherit_) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "agg"
replace concept = "etnwea" if concept=="w"
replace concept = "etnweg" if concept=="w_gift"
gen specific = "ff"
tempfile agg
save `agg'
restore

keep year area Pluscorrectionforexemptasset Plusgiftsintervivosasnati percentile
rename (Pluscorrectionforexemptasset Plusgiftsintervivosasnati) (inherit_w_ni inherit_w_gift_ni)
reshape long inherit_@, i(year area percentile) j(concept) string
rename (inherit_) (value)

gen dashboard = "i"
gen sector = "hs"
gen vartype = "rto"
replace concept = "etnwea" if concept=="w_ni"
replace concept = "etnweg" if concept=="w_gift_ni"
gen specific = "ff"
replace value=value/100

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
