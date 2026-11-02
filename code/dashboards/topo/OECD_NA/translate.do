
** Set paths here
*run "Code/Stata/auxiliar/all_paths.do"
tempfile all
	
* Origin folder: it contains the excel files to import
global origin "${topo_dir_raw}/OECD_NA/raw data" 

* Grid folder
global grid "${topo_dir_raw}/OECD_NA/auxiliary files"

* Intermediate to erase folder
global intermediate_to_erase "${topo_dir_raw}/OECD_NA/intermediate to erase"

* Intermediate folder
global intermediate "${topo_dir_raw}/OECD_NA/intermediate"

****



import delimited "${origin}/OECD_NA_2026.csv", clear



*** part 1 (same for translate)
* the original dataset does not contain reference of the financial position
* we add the financial position based on the full_name_oecd files
* and 


gen finpos="ASS" if accounting_entry=="A"
replace finpos="LIAB" if accounting_entry=="L"

order finpos, before(transaction)

***
rename financialinstrumentsandnonfinanc v4
rename time_period year
label var year ""

keep ref_area finpos transaction v4 instr_asset institutionalsector obs_value year  sector


rename v4 varname_source
rename instr_asset source_code


// Rename sectors
replace sector = "hn" if sector == "S1M"
replace sector = "hs" if sector == "S14"
replace sector = "np" if sector == "S15"


// gen na_code from source_code for matching
gen na_code = source_code
replace na_code = substr(na_code, 2, strlen(na_code)-2)
replace na_code = substr(na_code, 2, .) if substr(source_code, 2, 1) == "E"


replace na_code = "AN"+na_code
*replace na_code = "A_"+na_code if finpos == "ASS" 
*replace na_code = "L_"+na_code if finpos == "LIAB" 



replace source_code = source_code+" ("+finpos+")"
drop finpos

cap rename ref_area geo3

drop source_code varname_source institutionalsector transaction

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


tempfile temp_1
save `temp_1'



levelsof sector, local(loc_sector)

foreach s of local loc_sector {

	use `temp_1'
	
	keep if sector ==  "`s'" 

	tempfile temp_2
	save `temp_2'

		levelsof area, local(loc_area)

		foreach a of local loc_area {

			use `temp_2'

			keep if area ==  "`a'" 

			levelsof na_code, local(loc_na_code)

			foreach cod of local loc_na_code {
	
				gen `cod' = .
				replace `cod' = obs_value if "`cod'" == na_code
			}

			drop na_code
			drop obs_value

			drop sector area 
			
			ds _all
			local first = word("`r(varlist)'", 2) // first variable
			ds _all
			local nwords :  word count `r(varlist)'
			local last = word("`r(varlist)'", `nwords') // last variable

			
			collapse `first'-`last', by(year)


			// sector


			tempfile temp_3
			save `temp_3'
			
			use "${grid}/grid_a_stock.dta", clear

			merge 1:1 year using "`temp_3'", update 

			drop _merge
						
			sort year 
			
			gen source = "OECD_NA"
			gen sector = "`s'"
			gen area = "`a'"
		
			order area sector source, after(year)

			
			qui save "${intermediate_to_erase}/pop_grid_`a'_`s'.dta", replace
			
}


}


drop _all

//put all the metadata together 
clear
local files : dir "${intermediate_to_erase}/" files "pop_grid_*.dta",  respectcase 
global files `files' 
local iter = 1 
tempfile ap 
foreach f in "$files" {
	qui use "${intermediate_to_erase}/`f'", clear 
	if `iter' != 1 qui append using `ap'
	qui save `ap', replace 
	local iter = 0 
	qui erase "${intermediate_to_erase}/`f'"
}

save "${topo_dir_raw}/OECD_NA/intermediate/populated_grid.dta", replace







