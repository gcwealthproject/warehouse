//settings
clear all

local source Findex_ineq

** Working Directories Local
********************************************************************************
*cd "/Users/ire.toma/Dropbox/gcwealth"


global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"
	local rawdata "`sourcef'/raw data/GlobalFindexDatabase2025.dta"
	local results "`sourcef'/final_table/`source'"

	
********************************************************************************
import excel "./handmade_tables/dictionary.xlsx", sheet("GEO") clear firstrow
keep GEO GEO3 
duplicates drop GEO3, force
tempfile asd
save `asd', replace


clear	
use "`rawdata'" 
rename codewb GEO3

merge m:1  GEO3 using `asd', keep(3) nogen
rename GEO area
drop GEO3

*replace area = "XK" if countrynewwb == "Kosovo"


keep if group2 == "all" // total population


	gen percentile = "p0p100"
	gen varcode = "t-hs-owr-fadepo-ia"
	gen value = .
	gen source = "`source'"
	
	replace value = account_t_d * 100

	
keep area year percentile varcode value source
order area year percentile varcode value source
sort area year
	
qui export delimited "`results'", replace
	

	
