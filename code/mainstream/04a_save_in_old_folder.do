//general settings 
clear all 
run "code/mainstream/auxiliar/all_paths.do"
run "code/mainstream/auxiliar/version_control.do"

if ("${supvar_ver}" == "") {
	di as error "You need to specify a supvar_ver version to run this " ///
	"do-file either in a global or in 03b"
} 	

//define what to move from "gcwealth"
local tomove ///
	warehouse_viz.csv supplementary_var_${supvar_ver}.csv ///
	warehouse_description.csv methodological_table.xlsx ///
	taxw_wide_viz.csv 
	

//define destination folder 
local cd `c(pwd)'
local dest = subinstr("`cd'", "gcwealth", "", .)
local dest `dest'THE_GC_WEALTH_PROJECT_website/
local taxw EIG Taxes/data_output/ 

//loop over files  	
foreach f in `tomove' {
	
	*define case-specific paths 
	if strpos("`f'", ".csv") {
		local source_path output/databases/
		if strpos("`f'", "description") {
			local source_path documentation/
		}
		if strpos("`f'", "taxw") {
			local d `taxw'
		}
		else local d 
	}
	if strpos("`f'", "code_desc") {
		local source_path output/metadata/
		local d `taxw'
	}
	if strpos("`f'", "methodological") {
		local source_path documentation/methodological_tables/
		local d 
	}
	if strpos("`f'", "supplementary") {
		local source_path output/databases/supplementary_variables/
		local d 
	}
	if strpos("`f'", "taxw_wide_viz.csv") {
		local source_path output/databases/website/
	}
	
	*copy in new folder 
	di as result "copying `source_path'`f'" 
	di as text "  - to `dest'`d'`f' "  
	qui copy "`source_path'`f'" "`dest'`d'`f'", public replace 
	di as text "  - and `dest'forTableau/`f'"
	qui copy "`source_path'`f'" "`dest'forTableau/`f'", public replace 
}	

di as result "... done"
