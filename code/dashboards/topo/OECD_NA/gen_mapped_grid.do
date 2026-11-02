
clear all

** Set paths here
*run "code/Stata/auxiliar/all_paths.do"
global origin "${topo_dir_raw}/OECD_NA/raw data"
global aux "${topo_dir_raw}/OECD_NA/auxiliary files"
global destination "${topo_dir_raw}/OECD_NA/intermediate"


import delimited "${origin}/OECD_NA_2026.csv", clear



*** part 1 (same for translate)
* the original dataset does not contain reference of the financial position
* we add the financial position based on the full_name_oecd files
* and 
gen finpos="ASS" if accounting_entry=="A"
replace finpos="LIAB" if accounting_entry=="L"

replace transaction = substr(transaction, 9, .) if substr(transaction, 1, 8) == "Of which"

rename financialinstrumentsandnonfinanc v4


order finpos, before(transaction)

***
rename time_period year
sort year

keep ref_area finpos transaction v4 instr_asset  obs_value year  sector
	
rename v4 varname_source
rename instr_asset source_code
rename ref_area location
rename obs_value value


// Rename sectors
replace sector = "hn" if sector == "S1M"
replace sector = "hs" if sector == "S14"
replace sector = "np" if sector == "S15"


// gen na_code from source_code for matching
gen na_code = source_code
replace na_code = substr(na_code, 2, strlen(na_code)-2)
replace na_code = substr(na_code, 2, .) if substr(source_code, 2, 1) == "E"



replace na_code = "AN"+na_code



replace source_code = source_code+" ("+finpos+")"
drop finpos

cap rename location geo3
cap rename ïlocatio geo3

tempfile temp
save `temp'
***


import delimited "${aux}/geo_translator.csv", varnames(1)  clear
drop country

merge 1:m geo3 using "`temp'", update 

keep if _merge == 3
sort geo
drop geo3 _merge
rename geo area

tempfile temp1
save `temp1'



*** part 2 (only for the creation of the grid)

keep if year == 2019
drop year value

tempfile temp2
save `temp2'



levelsof sector, local(loc_sector)

tempfile temp_sector
save `temp_sector'

foreach s of local loc_sector {

	use `temp_sector', clear
	
	keep if sector ==  "`s'" 

	tempfile temp_area
	save `temp_area'

	levelsof area, local(loc_area)

	foreach a of local loc_area {

		use `temp_area', clear

		keep if area ==  "`a'" 
			
			drop area sector
			
			tempfile temp_sec_area
			save `temp_sec_area'		

			import delimited "${aux}/grid_empty.csv", clear 
			drop varname_source source_code
			merge 1:1 na_code using "`temp_sec_area'", update 
			
			drop if source_code == ""
			drop if nacode_label == ""
			drop _merge 

		qui export excel "${destination}/grid", sheet("`a'_`s'", replace) firstrow(variables) 


}
}

