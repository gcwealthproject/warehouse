
// Set Path
clear 

local source HFCS_ineq

** Working Directories Local
********************************************************************************

global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"

//define internal paths 
	local sourcef "${ineq_dir_raw}/`source'"

** Inequ Series
local rawdata1 "`sourcef'/raw data/ineq_wave1_hfcs.dta"
local rawdata2 "`sourcef'/raw data/ineq_wave2_hfcs.dta"
local rawdata3 "`sourcef'/raw data/ineq_wave3_hfcs.dta"
local rawdata4 "`sourcef'/raw data/ineq_wave4_hfcs.dta"
** Ownership Series
local orawdata1 "`sourcef'/raw data/ineq_own_ratio_wave1_hfcs.dta"
local orawdata2 "`sourcef'/raw data/ineq_own_ratio_wave2_hfcs.dta"
local orawdata3 "`sourcef'/raw data/ineq_own_ratio_wave3_hfcs.dta"
local orawdata4 "`sourcef'/raw data/ineq_own_ratio_wave4_hfcs.dta"
local results "`sourcef'/final_table/`source'"



clear
forvalues v=1(1)4{
	append using "`rawdata`v''"
}
forvalues v=1(1)4{
	append using "`orawdata`v''"
}

drop value_* 
gen source = "HFCS_ineq"


// 
replace value=value*100 if varcode=="t-hs-dsh-netwea-ho"
replace value=value*100 if varcode=="t-hs-gin-netwea-ho"
split varcode , p(-)
replace value=value*100 if varcode3=="owr"
drop varcode1 varcode2 varcode3 varcode4 varcode5

drop if area=="E1"

//export
qui export delimited "`results'", replace
