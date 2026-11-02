//settings
clear all

local source DHS_ineq

** Working Directories Local
********************************************************************************
*cd "`:env USERPROFILE'/Dropbox/gcwealth"


global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"
	local rawdata "`sourcef'/raw data/Final_raw_data_DHS.dta"
	local results "`sourcef'/final_table/`source'"
	
	
********************************************************************************

use "`rawdata'"

	drop lowerbound upperbound warehouse
	
	replace value = value*100
	
	replace source = "`source'"
	
qui export delimited "`results'", replace
	
