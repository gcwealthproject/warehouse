//settings
clear all
*global path 	"`:env USERPROFILE'/Dropbox/gcwealth"
*cd "$path"

local source Assouad2021
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${ineq_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/Assouad2017MainFiguresTables.xlsx"
local results "`sourcef'/final_table/`source'"

//import - wealth shares - quarters averages
qui import excel "`rawdata'", ///
	sheet("Assouad2021") firstrow clear
//clean
qui rename (Middle40 Bottom50) (Top940 Top950)
drop Peradultpersonalwealthcurre
//drop missing
drop if missing(year)
//reshape
reshape long Top, i(year) j(percentiles)

//rename correctly
gen percentile = ""
qui replace percentile = "p99p100" if percentiles==1
qui replace percentile = "p90p100" if percentiles==10
qui replace percentile = "p50p90" if percentiles==940
qui replace percentile = "p0p50" if percentiles==950
drop percentiles
//gen value
rename Top value
//drop missing
drop if missing(value)
qui replace value = value * 100

//generate code variables
gen dashboard = "t"
gen sector = "hs"
gen vartype = "dsh"
gen concept = "netwea"
gen specific = "ia"

egen varcode = concat(dashboard sector vartype concept specific), ///
	punct ("-")  

drop dashboard sector vartype concept specific

//gen warehouse variables	
gen area = "LB"
gen source = "`source'"

//gen method of estimation - data_type - survey adjusted
//qui gen data_type = "sa" 

//generate longname 1-2 
//run $fill_longname 

//export
qui export delimited "`results'", replace 
