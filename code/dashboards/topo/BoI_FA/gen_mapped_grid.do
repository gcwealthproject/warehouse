** Set paths here
*run "Code/Stata/auxiliar/all_paths.do"
tempfile all

global origin "${topo_dir_raw}/BoI_FA/raw data"
global aux "${topo_dir_raw}/BoI_FA/auxiliary files"
global intermediate_to_erase "${topo_dir_raw}/BoI_FA/intermediate to erase"
global intermediate "${topo_dir_raw}/BoI_FA/intermediate"

* import delimited "${origin}/export_1667306562203/20221101_134241_REPORT.csv", delimiter(";") clear
*import delimited "${origin}/export_1691521458232/20230808_210417_REPORT.csv", delimiter(";") clear // update (August 2023)
*import delimited "${origin}/export_1718732915412/20240618_194833_REPORT.csv", delimiter(";") clear // update (May 2024)
*import delimited "${origin}/export_1751470006896/20250702_172646_REPORT.csv", delimiter(";") clear // update (July 2025)
import delimited "${origin}/export_1774471543900/20260325_214542_REPORT.csv", delimiter(";") clear // update (March 2026)

gen n = _n
order n, first
keep if n == 1 | n == 2 
drop n

sxpose, clear force

drop if _n == 1
rename _var1 source_code
rename _var2 varname_source

gen source_code_or = source_code
order source_code_or, first

// drop flows
drop if strpos(varname_source, "flows") != 0


// finpos
gen finpos = ""
replace finpos = "ASS" if strpos(source_code, ".111.") != 0
replace finpos = "LIAB" if strpos(source_code, ".112.") != 0

// location of counterpart
gen loc_counterpart = ""
replace loc_counterpart = "W0" if strpos(source_code, ".W0.11") != 0
replace loc_counterpart = "IT" if strpos(source_code, ".IT.11") != 0
replace loc_counterpart = "W1" if strpos(source_code, ".W1.11") != 0


gen source = ""
replace source = substr(source_code_or, 1, 6)
replace source_code = substr(source_code_or, 8, .)

// frequency
gen frequency = ""
replace frequency = substr(source_code_or, 7, 3)
replace frequency = "Q"
replace source_code = substr(source_code_or, 10, .)

// sector
gen sector = substr(source_code_or, 10, 3)
replace source_code = substr(source_code_or, 14, .)

// area
gen area = substr(source_code, 1, 2)
replace source_code = substr(source_code_or, 17, .)


// item
gen item = substr(source_code, 1, strpos(source_code, ".")-1)
order item, first
replace item = "A_A"+item if finpos == "ASS"
replace item = "L_A"+item if finpos == "LIAB"
rename item na_code


keep if loc_counterpart == "W0" | loc_counterpart == "W1"
keep if loc_counterpart == "W0"
sort finpos

keep na_code source_code_or varname_source 
rename source_code_or source_code

gen nacode_label = ""

replace varname_source = varname_source+" (F21+F22)" if na_code == "A_AF2BI2"

replace na_code = strtrim(na_code) // eliminate extra blanks in string

tempfile pregrid
save `pregrid'


preserve
	import excel "${aux}/grid_empty.xls", sheet("grid_empty") firstrow allstring clear
	tempfile grid
	save `grid'
restore

merge 1:1 na_code using `grid', update replace

drop if varname_source == ""
drop _merge

replace nacode_label = "Currency and transferable deposits" if na_code == "A_AF2BI2"


export excel using "${intermediate}/grid.xls", firstrow(variables) replace
	
	
	
** code translator

keep na_code source_code
replace source_code = subinstr(source_code, ".", "", .) 
sxpose, clear force

ds
local allvar `r(varlist)'

foreach var of local allvar {
	
	rename `var' `=`var'[2]'
	
}

drop if _n == 2

export excel using "${intermediate}/code_translator.xls", firstrow(variables) replace
