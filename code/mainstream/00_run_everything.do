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
//ssc install egenmore sxpose findname labmask renvarlab ereplace xfill (type net from https://www.sealedenvelope.com/) labmask (http://www.stata-journal.com/software/sj8-2/ - gr0034.pkg)

//general settings 
macro drop _all 
clear all 
run "code/mainstream/auxiliar/version_control.do"

//list codes 
**********************************************************
global do_codes1 " "01a" "01b" "01c" " 
global do_codes2 " "02a" "02b" "
global do_codes3 " "03b" "03c" "03a" " 

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
forvalues n = 1/3 {
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
			if `x' == 3 di as result "{hline 70}"	
		}
	}
}

global run_everything " "" "

