//settings
clear all

local source Piketty2011
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${inhe_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/piketty_data.xlsx"
local results "`sourcef'/final_table/`source'"
cap mkdir "`sourcef'/final_table"
 
//import and clean  
import excel "`rawdata'", sheet("annual") cellrange(E5) firstrow clear
rename time year
drop if year==.
isid year

keep year y w i_ff b_ff gift_ff b_ef i_ef g_ef
foreach v of varlist y w i_ff b_ff gift_ff b_ef i_ef g_ef {
	replace `v'=`v'*1000000000  //bring it in euros and not in billions of euros
	replace `v'=. if `v'==0
}


//clean
gen percentile="p0p100"
gen area="FR"

//generate code variables
preserve
keep year area percentile b_ff b_ef i_ff i_ef
reshape long b_@ i_@, i(year area percentile) j(specific) string
reshape long @_ , i(year area percentile specific) j(concept) string
rename (_) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "agg"
replace concept = "etnweg" if concept == "b"
replace concept = "etnwea" if concept == "i"
// gen specific = "ff"
tempfile agg
save `agg'
restore

foreach v of varlist i_ff b_ff b_ef i_ef {
	replace `v'=`v'/y //make the income ratio
}
keep year area percentile b_ff b_ef i_ff i_ef
reshape long b_@ i_@, i(year area percentile) j(specific) string
reshape long @_ , i(year area percentile specific) j(concept) string
rename (_) (value)
gen dashboard = "i"
gen sector = "hs"
gen vartype = "rto"
replace concept = "etnweg" if concept == "b"
replace concept = "etnwea" if concept == "i"
// gen specific = "ff"


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
