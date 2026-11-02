////////////////////////////////////////////////////////////////////////////////
//
// 					   Title: THE GC WEALTH PROJECT  
// 					Purpose: Put IBNEQ dashboard together 
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
*	all data produced by code/dashboards/ineq/SOURCE.do 
*	and stored in raw_data/ineq/SOURCE/final_table/SOURCE.csv


// Note that Not all SOURCE.csv have a Methodolocail table Ready
*	Tables are stored in: 
*		/documentation/methodological_tables/Source_Sheets
* 	Code: code/methodological_tables/mt_table_ofall_mt_tables.do produces the 
* 		met tables file!
////////////////////////////////////////////////////////////////////////////////


// Step 1 -  Select Sources to Include, and Spot what is still missing
********************************************************************************

	** Run .do file to Check Inclusion in Wharehouse
	// This file is produced with: gcwealth/code/methodological_tables/MT_status_ineq
	// Note: if running the code with MAC, the dir command might generate problems
	// 		 if serached resources have accents or special carachters
	//       Tip: serach for MartinzToledano2022
	do "./code/methodological_tables/MT_status_ineq.do"
	use "./documentation/workflow/ineq/status_ineq_NEW.dta", clear
	
	** Spot what is Missing and Why
	list Source STATUS_DATA STATUS_MT Comments if Inclusion_in_Warehouse=="", c	
	
	
	** To Include
	levelsof  Source if Inclusion_in_Warehouse=="Yes", c 
	local include=r(levels)
				
	
	
// Step 2 - Run all Sources to be included
********************************************************************************
	foreach f of local include {
		
		di as result "${ineq_code}/`f'.do"
		run "${ineq_code}/`f'.do" 
		
		// Locally Store the produced dataset
		tempfile x`f'
		qui save `x`f'' , replace
		
	} 

	// Append all final csv files
	clear
	foreach f of local include {
		di "`f'"
		append using `x`f''
	} 
	
	qui replace percentile = subinstr(percentile, "_", ".", .)
	
	qui export delimited area year value percentile varcode source ///
		using "raw_data/ineq/ineq_ready.csv", replace 
	
	

// Step 3 - Report Missings
********************************************************************************
** Run MT_status_ineq.do file to Check Inclusion in Wharehouse
	use "./documentation/workflow/ineq/status_ineq_NEW.dta" , clear
	
	** Spot what is Missing and Why
	list Source STATUS_DATA STATUS_MT Comments if Inclusion_in_Warehouse=="", c	
	
	** Save: handmade_tables/exclude_sources_ineq --> used in appendix of Documntation
	preserve
		keep if Inclusion_in_Warehouse==""
		keep Source
		insobs 1, before(1)
		replace Source="Excluded" if Source==""
		list
		export excel using  ///
		"handmade_tables/exclude_sources_ineq.xlsx", ///
		sheet("Sources_Exclusion") replace
	restore	
	
	

// Step 4 - Checks on Data
********************************************************************************	
*do "./code/other/warehouse_testing/checking_functions.do"

// Step 5 - Create Uniue file with Meth. Tables
**********************************************************
do "./code/methodological_tables/mt_table_ofall_mt_tables.do"
