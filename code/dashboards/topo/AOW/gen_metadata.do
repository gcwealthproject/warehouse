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
keep year varcode value source sector percentile longname area country

merge 1:1 year area using `widcur', nogen keep(1 3)
*impute for UM
replace cur =1 if area=="UM"
* drop those which are not available in WID
drop if cur==.

* transform value into local cur and adjust the billion
replace value=value*cur*1000000000
drop cur
 sort area       
 quietly by area:  gen dup = cond(_N==1,0,_n) 
 drop if dup>1
 
 *need concept label metadata 
gen concept="offsho"
gen label="Offshore Financial Wealth"
gen metadata=`"The category "Offshore Financial Wealth" is derived using the following an extended SNA terminology formula: (Offshore Financial Wealth) which is equivalent to: (A_AXF). In practice, given data availability for this specific source, we use the following formula: (OFFSHO). Using the original variable names, we use the following original variables from the source: Total offshore wealth."'

*gen legend="Atlas of the Offshore World - Financial Accounts"
*gen source_type="Cross-national academic research"

 keep area source sector concept label metadata 
global output "${topo_dir_raw}/AOW/final table"
save "${output}/AOW_metadata.dta", replace






