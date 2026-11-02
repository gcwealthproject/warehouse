

//general settings 
clear all 
run "code/mainstream/auxiliar/all_paths.do"

//report and save start time 
local start_t "($S_TIME)"
di as result "Started filling metadata at `start_t'"
pwd

//2. 1 TOPOGRAPHY SECTION ----------------------------------------------------

//list all folders in directory
local folds : dir "${topo_dir_raw}/." dirs "*"
global folds `folds'

//list folders with metadata 
local iter = 1 
foreach f in `folds' { 
	if `iter' == 1 {
		di as result "{hline 90}"
		di as result "Topography: looking for metadata files " ///
			"within sub-folders at $S_TIME" 
		di as text "${topo_dir_raw}/"
		di as result "{hline 90}"
	}	
	di as text "`f'" _continue 
	cap confirm file "${topo_dir_raw}/`f'/final table/`f'_metadata.dta"
	if _rc == 0 {
		di as result " found it!"
		*update list if found 
		local found_fs `found_fs' "`f'"
	}
	else {
		di as error " nope"
	}
	local iter = `iter' + 1
}

//append them all 
tempfile af 
local iter = 1 
foreach f in `found_fs' {
	if `iter' == 1 di as result "appending in pogress at $S_TIME ..."
	di as text "   -`fm' " _continue
	qui use "${topo_dir_raw}/`f'/final table/`f'_metadata.dta", clear 
	if `iter' != 1 qui append using `af' 
	qui save `af', replace 
	local iter = 0 
	di as result "done"
}

//fill labels d1, d2, d4  
qui use `af', clear 
qui gen _1_dasboard = "${code1_p}"
local dics d2_sector d4_concept 
foreach d in `dics' {
	di as result "`d'"
	local d2 = substr("`d'", 4, .)
	local n2 = substr("`d'", 2, 1)
	qui gen _`n2'_`d2'_lab = ""
	local cods ${codes`n2'}
	foreach c in `cods' {
		di as result "`c' `d2'"
		qui replace _`n2'_`d2'_lab = "${code`n2'_`c'}" if `d2' == "`c'"
	}
	qui drop `d2'
} 

//harmonize country names 
qui rename area GEO
global checkvars GEO 
run $check_nonmissings 
run $harmonize_ctries 
qui rename GEO area 

//order 
run $harmonize_source_aliases
qui sort source area _2_sector_lab
qui order source area _2_sector_lab _4_concept_lab metadata label 
qui export excel "output/metadata/metadata_topo.xlsx", ///
	sheet("meta", replace) firstrow(variables)	
	
//2. INEQ ----------------------------------------------------------------------

shell Rscript "code/dashboards/ineq/metadata/create_ineq_metadata.R"

//3. TAXW SECTION --------------------------------------------------------------

/*
TAXW metadata are already generated in the code: 1_0_TAXW_Warehouse in gcwealth\code\dashboards\taxw and saved in 
file "output/metadata/metadata_taxw.csv"
*/

//4. INHE (pending)
