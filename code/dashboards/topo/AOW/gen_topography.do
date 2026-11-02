
** Set paths here
global path "${topo_dir_raw}/AOW/auxiliary files"
global origin "${topo_dir_raw}/AOW/raw data"
global intermediate "${topo_dir_raw}/AOW/intermediate"
global aux "${topo_dir_raw}/AOW/auxiliary files"


* We need to translate USD in Local Cur
clear
wid, indicators(xlcusx)
keep year value country
rename value cur
rename country area 
tempfile widcur
save  `widcur'


* Import dates
*import excel "${origin}/AOW_FW.xls", replace

*qui import excel "${origin}\AOW_FW", clear firstrow
qui import excel "${origin}\Offshore financial wealth database march 2026", clear firstrow

****

*keep total offshore abroad only
 keep if indicator=="total" 

*translate varcode   into year varcode value source sector percentile longname area
gen varcode="p-hs-agg-offsho-ga"

gen source="AOW"
gen sector="hs"
gen percentile="p0p100"
kountry iso3, from(iso3c) to(iso2c)
rename _ISO2C_ area
gen longname=""
drop if value==0

replace area="UM" if iso3=="UMI"
keep year varcode value source sector percentile longname area 

merge 1:1 year area using `widcur', nogen keep(1 3)
*impute for UM
replace cur =1 if area=="UM"
* drop those which are not available in WID
drop if cur==.

* transform value into local cur and adjust the billion
replace value=value*cur*1000000000
drop cur

*export
global output "${topo_dir_raw}/AOW/final table"
save "${output}/AOW_warehouse.dta", replace
export delimited using "${output}/AOW_warehouse.csv", replace





