** Alvaredo 2016
********************************************************************************
clear all

local source Li2008


** Working Directories Local
********************************************************************************
*global path	"`:env USERPROFILE'/OneDrive - Universita degli Studi Roma Tre\Research\GC - Update"
*cd "$path"

global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"
	local rawdata "`sourcef'/raw data/Cartel1.csv"
	local pt2 "`sourcef'/raw data/Cartel1.xlsx"
	local results "`sourcef'/final_table/`source'"
	
	
		
********************************************************************************
** Load
********************************************************************************
import delimited "`rawdata'" ,  clear 

gen value1995=v2
gen value2002=v3


gen source="`source'"
gen area="CN"

// Gini
gen percentile="p0p100" if v1=="Gini"
gen varcode="t-hs-gin-netwea-ia"  if v1=="Gini"
preserve 
	keep if varcode=="t-hs-gin-netwea-ia"
	drop v1 v2 v3
	reshape long value, i(source area percentile varcode) j(year)
	tempfile gini
	save `gini'
restore
drop if varcode=="t-hs-gin-netwea-ia"



// DSH
replace v1="1" if v1=="1bottom"
drop if _n==1
drop if v1=="10top"
*drop v1

forvalues v=1(1)9 {
	local x=`v'-1
	replace percentile="p`x'0p`v'0" if v1=="`v'"
	replace varcode="t-hs-dsh-netwea-ia" if v1=="`v'"
}


replace value1995=value1995[_n]-v2[_n-1] if _n>1 
replace value2002=value2002[_n]-v3[_n-1] if _n>1 

drop v1 v2 v3

** Extra Varialbes
reshape long value, i(source area percentile varcode) j(year)
reshape wide value, i(source area varcode year) j(percentile) string

egen valuep90p100=rowtotal(valuep00p10 valuep10p20 valuep20p30 valuep30p40 valuep40p50 valuep50p60 valuep60p70 valuep70p80 valuep80p90)
	replace valuep90p100=100-valuep90p100
egen valuep0p50=rowtotal(valuep00p10 valuep10p20 valuep20p30 valuep30p40 valuep40p50)
egen valuep50p90=rowtotal(valuep50p60 valuep60p70 valuep70p80 valuep80p90)
egen valuep80p100=rowtotal(valuep80p90 valuep90p100)

reshape long value, i(source area varcode year) j(percentile) string

** Save
append using `gini'
order area year value percentile varcode source
qui export delimited "`results'", replace 	
