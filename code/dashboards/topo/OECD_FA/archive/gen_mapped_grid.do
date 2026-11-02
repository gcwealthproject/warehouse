

** Set paths here
*run "code/Stata/auxiliar/all_paths.do"
global origin "${topo_dir_raw}/OECD_FA/raw data"
global aux "${topo_dir_raw}/OECD_FA/auxiliary files"
global destination "${topo_dir_raw}/OECD_FA/intermediate"

*import delimited "${origin}/QASA_7HH_10102022094726458.csv", varnames(1) delimiter(comma) clear // June 2023
import delimited "${origin}/QASA_7HH_29082023202120134.csv", varnames(1) delimiter(comma) clear // August 2023
drop if time == "2023"	
//data infrastructure since 2023. There is a code that transforms the data into our structure. 
append using "${origin}/OECD_2023_update"

				
*** part 1 (same for translate)
* the original dataset does not contain reference of the financial position
* we add the financial position based on the full_name_oecd files
* and 

gen finpos = ""
replace finpos = "ASS" if v4 == "Investment fund shares"
replace finpos = "ASS" if v4 == "Money market fund shares"
replace finpos = "ASS" if v4 == "Non-MMF investment fund shares"
replace finpos = "ASS" if v4 == "Real estate fund shares"
replace finpos = "ASS" if v4 == "Bond fund shares"
replace finpos = "ASS" if v4 == "Mixed fund shares"
replace finpos = "ASS" if v4 == "Equity fund shares"
replace finpos = "ASS" if v4 == "Other fund shares"
replace finpos = "ASS" if v4 == "Life insurance and annuity entitlements"
replace finpos = "ASS" if v4 == "Life insurance and annuity entitlements, of which unit linked"
replace finpos = "ASS" if v4 == "Life insurance and annuity entitlements, of which non-unit-linked"
replace finpos = "ASS" if v4 == "Pension entitlements"
replace finpos = "ASS" if v4 == "Pension entitlements, managed by autonomous pension funds"
replace finpos = "ASS" if v4 == "Defined contribution plans (DC)"
replace finpos = "ASS" if v4 == "Defined benefit plans (DB)"
replace finpos = "ASS" if v4 == "Hybrid plans"
replace finpos = "ASS" if v4 == "Pension entitlements, managed by non-autonomous pension funds"
replace finpos = "ASS" if v4 == "Pension entitlements, managed by insurers"
replace finpos = "ASS" if v4 == "Other pension plans, incl. unfunded pension plans"

replace finpos = "LIAB" if v4 == "Loans"
replace finpos = "LIAB" if v4 == "Short-term loans (up to one year)"
replace finpos = "LIAB" if v4 == "Consumer credit (up to one year)"
replace finpos = "LIAB" if v4 == "Revolving credit (up to one year)"
replace finpos = "LIAB" if v4 == "Non-revolving credit (up to one year)"
replace finpos = "LIAB" if v4 == "Short-term loans for other purposes"
replace finpos = "LIAB" if v4 == "Long-term loans (more than one year)"
replace finpos = "LIAB" if v4 == "Consumer credit (more than one year)"
replace finpos = "LIAB" if v4 == "Loans for house purchasing"
replace finpos = "LIAB" if v4 == "Long-term loans for other purposes"

order finpos, before(transaction)

***

drop if strpos(time, "Q")
duplicates drop
sort time
destring time, gen(year)
label var year ""

drop flags flagcodes measure v8 adjustment v10 time periodfrequency unit ///
	unitcode referenceperiodcode referenceperiod powercode powercodecode ///
	country sector

	
rename v6 sector 
rename v4 varname_source
rename transaction source_code


// Rename sectors
replace sector = "hn" if sector == "Households and NPISHs"
replace sector = "hs" if sector == "Households"
replace sector = "np" if sector == "S15"


// gen na_code from source_code for matching
gen na_code = source_code
replace na_code = substr(na_code, 2, .)
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

