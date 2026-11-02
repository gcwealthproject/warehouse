

** Set paths here
global path "${topo_dir_raw}/BoI_FA/auxiliary files"
global origin "${topo_dir_raw}/BoI_FA/raw data"
global intermediate "${topo_dir_raw}/BoI_FA/intermediate"
global aux "${topo_dir_raw}/BoI_FA/auxiliary files"


* Import dates
*import delimited "${origin}/export_1667306562203/20221101_134241_REPORT.csv", delimiter(";") clear // update (June 2023)
*import delimited "${origin}/export_1691521458232/20230808_210417_REPORT.csv", delimiter(";") clear // update (August 2023)
*import delimited "${origin}/export_1718732915412/20240618_194833_REPORT.csv", delimiter(";") clear // update (May 2024)
*import delimited "${origin}/export_1751470006896/20250702_172646_REPORT.csv", delimiter(";") clear // update (July 2025)
import delimited "${origin}/export_1774471543900/20260325_214542_REPORT.csv", delimiter(";") clear // update (March 2026)


ds
local allvar `r(varlist)'
foreach var of local allvar {
	
	replace `var' = subinstr(`var', ".", "", .) if _n == 1
	rename `var' `=`var'[1]'

	
}

drop if _n == 1
drop if _n == 1

tempfile temp1
save `temp1'



import excel "${intermediate}/code_translator.xls", firstrow clear

append using `temp1'

replace DATA_OSS = "year" if _n == 1
label var DATA_OSS "year" 

// delete not appended vars
ds, not(varlabel)
drop `r(varlist)'

// translate
ds
local allvar `r(varlist)'
foreach var of local allvar {
	rename `var' `=`var'[1]'	
}

drop if _n == 1

gen n = _n
order n, first

gen yearr 	= substr(year,1,4)
gen quarter = substr(year,6,2)

replace quarter = "1" if quarter == "03"
replace quarter = "2" if quarter == "06"
replace quarter = "3" if quarter == "09"
replace quarter = "4" if quarter == "12"



order year year quarter, first
drop year
destring yearr, gen(year)
sort year

drop n yearr

order year, first

keep if quarter == "4"
drop quarter


ds year, not 	
// from millions to units	
foreach v of var `r(varlist)'{
	destring , replace
	replace `v' = `v'*1000000
}


tempfile pre_pop
save `pre_pop'
	
	
use "${aux}/grid_a_stock.dta", clear 

* merge 

merge 1:1 year using `pre_pop', update 	

drop _merge

gen area = "IT"
gen sector = "hn"
gen source = "BoI_FA"

order area sector source, after(year)

* save
save "${intermediate}/populated_grid.dta", replace













