////////////////////////////////////////////////////////////////////////////////
//
// 					   Title: THE GC WEALTH PROJECT  
// 					Purpose: Put INHE dashboard together 
//
////////////////////////////////////////////////////////////////////////////////

//general settings 
clear all 

run "code/mainstream/auxiliar/all_paths.do"

//report and save start time 
local start_t "($S_TIME)"
di as result "Started running everything working at `start_t'"
pwd


////////////////////////////////////////////////////////////////////////////////
// The Dashboard appends :
*	all data produced by code/dashboards/inhe/SOURCE.do 
*	and stored in raw_data/inhe/SOURCE/final_table/SOURCE.csv
////////////////////////////////////////////////////////////////////////////////

// Step 1 list all sources 

local folders : dir "raw_data/inhe" dirs "*"

	
// Step 2 - Run all Sources to be included
********************************************************************************
foreach f of local folders {
	
	di as result "${inhe_code}/`f'.do"
	run "${inhe_code}/`f'.do" 
	
	// Locally Store the produced dataset
	tempfile x`f'
	qui save `x`f'' , replace
	
} 

// Append all final csv files
clear
foreach f of local folders {
	di "`f'"
	append using `x`f''
} 
qui drop if missing(value)

qui export delimited area year value percentile varcode source ///
	using "raw_data/inhe/inhe_ready.csv", replace 

