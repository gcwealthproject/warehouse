////////////////////////////////////////////////////////////////////////////////
//
// 		Title: THE GC WEALTH PROJECT  
// 		Purpose: Compile data warehouse from scratch
//
// Note: remember to change directory to the "gcwealth" folder before 
// running these files, either collectively of individually 
//
////////////////////////////////////////////////////////////////////////////////

****Required packages********
//ssc install sxpose findname renvarlab

//general settings 
macro drop _all 
clear all 
run "code/mainstream/auxiliar/version_control.do"

//list codes 
**********************************************************
global do_codes1 " "01c" "01d" " //"01a" "01b"
global do_codes2 " "02a" "02b" "
global do_codes3 " "03a" "03b" "03c" " 
*global do_codes4 " "04a" " 
**********************************************************

//report and save start time 
global run_everything " "ON" "
local start_t "($S_TIME)"
di as result "Started running everything working at `start_t'"

//prepare list of do-files 
forvalues n = 1/4 {
	//get do-files' name 
	foreach docode in ${do_codes`n'} { 
		local do_name : dir "code/mainstream/." files "`docode'*.do"
		local do_name = subinstr(`do_name', char(34), "", .)	
		global doname_`docode' `do_name'
	}
}

//loop over all files  
forvalues n = 1/4 {
	foreach docode in ${do_codes`n'} {
		
		*********************
		do code/mainstream/${doname_`docode'}
		*********************
		
		//record time
		global do_endtime_`docode' " - ended at ($S_TIME)"
		
		//remember work plan
		di as result "{hline 70}" 
		di as result "list of files to run, started at `start_t'"
		di as result "{hline 70}"
		forvalues x = 1/4 {
			di as result "Stage nº`x'"
			foreach docode2 in ${do_codes`x'} {
				di as text "  * " "${doname_`docode2'}" _continue
				di as text " ${do_endtime_`docode2'}"
			}
			if `x' == 4 di as result "{hline 70}"	
		}
	}
}

global run_everything " "" "

