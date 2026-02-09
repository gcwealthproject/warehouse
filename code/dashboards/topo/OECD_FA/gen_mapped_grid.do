

** Set paths here
*run "code/Stata/auxiliar/all_paths.do"
global origin "${topo_dir_raw}/OECD_FA/raw data"
global aux "${topo_dir_raw}/OECD_FA/auxiliary files"
global destination "${topo_dir_raw}/OECD_FA/intermediate"

*import delimited "${origin}/QASA_7HH_10102022094726458.csv", varnames(1) delimiter(comma) clear // June 2023
*import delimited "${origin}/QASA_7HH_29082023202120134.csv", varnames(1) delimiter(comma) clear // August 2023
*import delimited "${origin}/QASA_7HH.csv", varnames(1) delimiter(comma) clear 
import delimited "${origin}/OECD_2025.csv", varnames(1) delimiter(comma) clear 


*drop if tixxme == "2023" // Auust 2023
		
*** part 1 (same for translate)
* the original dataset does not contain reference of the financial position
* we add the financial position based on the full_name_oecd files
* and 
rename financialinstrumentsandnonfinanc v4


gen finpos="ASS" if accounting_entry=="A"
replace finpos="LIAB" if accounting_entry=="L"

order finpos, before(transaction)

***

rename time_period year


*drop flagcodes measure v8 adjustment v10 time periodfrequency unit ///
	unitcode referenceperiodcode referenceperiod powercode powercodecode ///
	country sector
keep ref_area finpos transaction v4 instr_asset  obs_value year  sector
	
rename obs_value value
rename v4 varname_source
rename instr_asset source_code
rename ref_area location



// Rename sectors
replace sector = "hn" if sector == "S1M"
replace sector = "hs" if sector == "S14"


// gen na_code from source_code for matching
gen na_code = source_code
*replace na_code = substr(na_code, 2, .)
replace na_code = substr(na_code, 2, .) if substr(source_code, 2, 1) == "E"

// Loans
replace na_code = substr(na_code, 1, 2) if substr(source_code, 4, 1) == "T"
// Short term loans
replace na_code = substr(na_code, 1, 2)+"1" if substr(source_code, 5, 3) == "SLI"
// Long term loans
replace na_code = substr(na_code, 1, 2)+"2" if substr(source_code, 5, 3) == "LLI"


replace na_code = "A"+na_code
replace na_code = "A_"+na_code if finpos == "ASS" 
replace na_code = "L_"+na_code if finpos == "LIAB" 

replace source_code = source_code+" ("+finpos+")"
drop finpos

replace na_code="XAF42LM" if na_code=="L_AF4B"

cap rename location geo3
cap rename ïlocatio geo3

tempfile temp
save `temp'
***

qui import excel "${aux}/geo_translator.xlsx", firstrow case(lower) clear 
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

		// Chunk added in August 2023 to ensure the 1:1 matching after
			sort na_code
			by na_code:  gen dup = cond(_N==1,0,_n)
			drop if dup>1
			drop dup
			//
			
			tempfile temp_sec_area
			save `temp_sec_area'		

			qui import excel "${aux}/grid_empty.xlsx", ///
				sheet("grid_empty") firstrow clear 
				
			drop varname_source source_code
			merge 1:1 na_code using "`temp_sec_area'", update 
		
			drop if source_code == ""
			drop if nacode_label == ""
			drop _merge 

		qui export excel "${destination}/grid", sheet("`a'_`s'", replace) ///
			firstrow(variables)

	}
}

