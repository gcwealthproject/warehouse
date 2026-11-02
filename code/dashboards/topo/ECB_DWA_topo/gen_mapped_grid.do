
** Set paths here
run "code/mainstream/auxiliar/all_paths.do"
tempfile all

	
* Origin folder: it contains the excel files to import
global origin "${topo_dir_raw}/ECB_DWA_topo/raw data/" 

* Auxiliary folder
global aux "${topo_dir_raw}/ECB_DWA_topo/auxiliary files" 

* Intermediate to erase
global intermediate "${topo_dir_raw}/ECB_DWA_topo/intermediate to erase" 

* Destination folder
global destination "${topo_dir_raw}/ECB_DWA_topo/intermediate" 

qui use "${origin}/hh_dwa", clear


qui rename key source_code

qui rename title varname_source

qui rename ref_area area

qui keep if time_period == "2023-Q4"

qui gen na_code= account_entry + "_A" + instr_asset
drop if area=="I9"
replace na_code="NWA" if na_code=="N_ANWA"
replace na_code="ANUB" if na_code=="A_ANUB"
replace na_code="ANUN" if na_code=="A_ANUN" 
replace na_code="XAF42LM" if na_code=="L_AF4B"

/* check
local nacode2 A_F2M A_F3 L_F4B L_F4X A_F511 A_F51M A_F52 A_F62 L_F_NNA A_F_NNA A_NUB A_NUN NWA
qui local country_list AT BE CY DE EE ES FI FR GR HU IE IT LT LU LV MT NL PT SI SK
foreach c in `country_list' {
di "`c'"
foreach v of local na_code2 {

di "`v'"
sum obs_value if na_code=="`v'" & area=="`c'"

}
}
xxxx*/
qui keep area na_code	source_code	varname_source
qui order na_code 	source_code	varname_source area 

qui levelsof area,  local(ctr)

// Define the nacode_label variable and assign labels based on na_code
gen nacode_label = ""
replace nacode_label = "Deposits" if na_code == "A_AF2M"
replace nacode_label = "Debt securities" if na_code == "A_AF3"
replace nacode_label = "Loans for house purchasing" if na_code == "XAF42LM"
replace nacode_label = "Loans other than for house purchasing" if na_code == "L_AF4X"
replace nacode_label = "Listed shares" if na_code == "A_AF511"
replace nacode_label = "Unlisted shares and other equity" if na_code == "A_AF51M"
replace nacode_label = "Investment fund shares/units" if na_code == "A_AF52"
replace nacode_label = "Life insurance and annuity entitlements" if na_code == "A_AF62"
replace nacode_label = "Adjusted total liabilities (financial and net non-financial)" if na_code == "L_AF_NNA"
replace nacode_label = "Adjusted total assets (financial and net non-financial)" if na_code == "A_AF_NNA"
replace nacode_label = "Non-financial business wealth" if na_code == "ANUB"
replace nacode_label = "Housing wealth (net)" if na_code == "ANUN"
replace nacode_label = "Adjusted wealth (net)" if na_code == "NWA"



tempfile grid_c
qui save `grid_c' 
qui save "${intermediate}/mapping.dta", replace

foreach c of local ctr {
use `grid_c', clear
qui keep if area == "`c'"
drop area

qui export excel "${destination}/grid", sheet("`c'_S14", replace) firstrow(variables) 	
}

