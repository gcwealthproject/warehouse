

// Check the following lines always before running the code
local general_source = "LWS_topo" // The source does not change across the do-file
qui local sector_list S14
qui local country_list AT AU CA CL DE EE ES FI GR IT JP LU NO SE SI SK UK US ZA FR DK IN KR // MX
	
global bycountry "${topo_dir_raw}/LWS_topo/intermediate"
global bycountry_data "${topo_dir_raw}/LWS_topo/intermediate/populated_grid"
global cmappings "${topo_dir_raw}/LWS_topo/auxiliary files"
global intermediate "${topo_dir_raw}/LWS_topo/intermediate to erase"
global output "${topo_dir_raw}/LWS_topo/final table"


		
//list compositions and codes in memory 
qui import excel using "${cmappings}/composition table LWS.xlsx" , sheet("composition table") clear firstrow


gen composition2full = composition2
gen composition3full = composition3
gen composition4full = composition4
gen composition5full = composition5
gen composition6full = composition6



replace composition2 = "(haf) + (hasi) + (hannb)" if composition2 == "(haf) + (hasi) + (hannb02)"
replace composition3 = "(haf) + (has) + (hannb)" if composition3 == "(haf) + (has) + (hannb02)"
replace composition3 = "(hafis) + (hafii) + (hannb)" if composition3 == "(hafis) + (hafii) + (hannb08)"
replace composition3= "(hannb)" if composition3 == "(hannb02)"


replace composition4 = "(haf) + (has) + (hanncd) + (hannb)" if composition4 == "(haf) + (has) + (hanncd) + (hannb02)"
replace composition4 = "(hannb) + (hanncd)" if composition4 == "(hannb02) + (hanncd)"

replace composition5 = "(haf) + (hannb)" if composition4 == "(haf) + (hannb02)"

replace composition6 = "(haf) + (hanncd) + (hannb)" if composition4 == "(haf) + (hanncd) + (hannb02)"


ds code label description extended_composition1 d5_dboard_specific, not 
local comp `r(varlist)'
local ncomp = wordcount("`comp'")
display "`comp'"

qui levelsof code, local(codes) clean
qui local ncodes = wordcount("`codes'")
qui di "`codes'"

foreach c in `codes' {
	
  qui levelsof label if code == "`c'", local(lab_`c') clean   
  qui di as text " `lab_`c' '"
  
  qui levelsof d5_dboard_specific if code == "`c'", local(d5_`c') clean
  qui di as text " `d5_`c' '"
}

qui di as result "There are `ncomp' different compositions available " ///
	"for `ncodes' codes"


//save each composition's list of variables in memory 	
foreach cod in `codes' {
	qui di as result "`cod': "
	qui local iter = 1 
	
	foreach com in `comp' {
		di as text "  -`com' includes: "
		levelsof `com' if code == "`cod'", local(`cod'`iter') clean 
		levelsof `com' if code == "`cod'", local(`cod'`iter'_dirty) clean 
		levelsof `com' if code == "`cod'", local(`cod'`iter'_dirtyfull) clean 
		
		
		qui levelsof extended_composition1 if code == "`cod'", ///
			local(`cod'_ext_comp) clean   		
			  
		qui di as text "     dirty composition: ``cod'`iter''"
		*if not empty ...
		if "``cod'`iter''" != "" {
			foreach char in "+" "-" "(" ")" {
				qui local `cod'`iter' = ///
					subinstr("``cod'`iter''", "`char'", "", .)
			}
			qui di as text "     clean composition: ``cod'`iter''"
			* qui macro list _`cod'`iter'_dirty
			* qui macro list _`cod'`iter'
		}
		else {
			*di as error "empty"
		}
		qui local iter = `iter' + 1
	}	
}	 


** Crate topography by country-sector-concept triple

foreach s in `sector_list'{

	foreach ctry in `country_list' {
	
	*qui import excel using "${bycountry}", clear firstrow sheet("`ctry'")
	qui import delimited "${bycountry}/`ctry'", clear varnames(1) 
	// source specific
	drop na_code
	rename source_code na_code
	
	qui levelsof na_code, local(cod_`ctry') clean
	qui levelsof varname_source, local(varnamesource_`ctry') clean
	qui levelsof nacode_label, local(nacodelabel_`ctry') clean

	qui di as result upper("`ctry'") _continue
	qui di as text " has these na_codes available `cod_`ctry''"

	foreach cod in `codes' { // Loop over concepts

		// Skip fadepo for countries where the relevant deposit variable includes cash:
		// KR, NO: hafc includes cash; US: hafct (and hence hafc) includes cash; MX: hafcs includes cash
		if "`cod'" == "fadepo" {
			if "`ctry'" == "KR" | "`ctry'" == "NO" | "`ctry'" == "US" | "`ctry'" == "MX" {
				qui di as text "  Skipping `cod' for `ctry': deposit variable includes cash"
				continue
			}
		}

		qui local iter = 1
	
		foreach com in `comp' { // Loop over composition for a given concept
		*go only if not empty  
			if wordcount("``cod'`iter''") != 0 {
				di as result " `cod' nº`iter' needs " ///
					wordcount("``cod'`iter''") " items: ``cod'`iter''"
				qui local `cod'`iter'found = wordcount("``cod'`iter''")	

				*loop over each code-composition's item  
				qui local vnsource
				qui local nalabelcode
				
				foreach x in ``cod'`iter'' {
					
					di as text "  - `x'" _continue 
					cap assert strpos(" `cod_`ctry'' ", " `x' ") 
					if _rc == 0 {
						
						di as result " found it." 
						*qui di as text "`vnsource'"
						
					}
					*subtract to list if not found 
					else {
						
						*qui di as error " didnt't find"
						qui local `cod'`iter'found = ``cod'`iter'found' - 1
					}
					
				} //close foreach x
				
				*check how many where found 
				di as result "  conclusion: " _continue
			
				if ``cod'`iter'found' == wordcount("``cod'`iter''")	{

					*di ``cod'`iter'found'
					qui local outcome ///
						"composition can be computed using : ``cod'`iter'_dirtyfull'"
					di as text "`outcome'"

					qui local area_short =  "`ctry'"

					qui di as text "`area_short'" // and print it
					
					
					// Create topography concept
					preserve
						use "${bycountry_data}", clear
						qui keep if area == "`area_short'"
						qui gen sector = "hs" 
						qui gen source = "`general_source'"   
						
						qui gen percentile = "p0p100"						
						qui gen d1 = "p" // Dashboard: Wealth topography
						qui gen d2 = sector // Sector
						qui gen d3 = "agn"  // 	Vartype: Aggregate (Non-consolidated)
						qui gen d4 = "`cod'" // Concept
						qui gen d5 = "`d5_`cod''" // Dashboard specific
	
						qui gen varcode = d1+"-"+d2+"-"+d3+"-"+d4+"-"+d5						
											
						*qui gen value = ``cod'`iter'_dirty' 	// it works!
						qui gen value = ``cod'`iter'_dirtyfull' // it works! 
						di as text value

						qui gen longname = ""
					
						* Output
						* area | year | source | percentile | varcode | value | longname (empty)
						qui keep area year source percentile varcode sector value longname
						qui drop if value == . // clean
						
						save "${intermediate}/topo/topo_`ctry'_`cod'", replace
						drop area year source percentile varcode sector value
					restore	 
						
					// Exit the loop over each code-composition's item 
					continue, break
				}
				else {
					di as text "composition cannot be computed"
				}
				
			
			} // close if wordcount("``cod'`iter''") != 0 
			
			local iter = `iter' + 1
		} // close foreach com in `comp'
		
	
	}
		
	}
	

	
}	

drop _all

//put all together 
clear
local files : dir "${intermediate}/topo" files "topo_*.dta" ,  respectcase 
global files `files' 
local iter = 1 
tempfile ap 
foreach f in "$files" {
	qui use "${intermediate}/topo/`f'", clear 
	if `iter' != 1 qui append using `ap'
	qui save `ap', replace 
	local iter = 0 
	qui erase "${intermediate}/topo/`f'"
}




** Temporary code (May 22, by Giacomo)

* Finland, nnhass, 2009 and 2016
drop if area == "FI" & varcode == "p-hs-agn-nnhass-ga" & year == 2009
drop if area == "FI" & varcode == "p-hs-agn-nnhass-ga" & year == 2016

drop if varcode == "p-hs-agn-netwea-na"

tempfile inputfile
save `inputfile'

levelsof area, local(area_list)

foreach ctry in `country_list'{

	use `inputfile', clear
	
	keep if area == "`ctry'"

	keep if varcode == "p-hs-agn-nnhass-ga" | varcode == "p-hs-agn-nfahou-ga" | varcode == "p-hs-agn-fliabi-lb"

	save "${intermediate}/topo/country", replace

	* Financial asset side
	use "${intermediate}/topo/country", clear
	keep if varcode == "p-hs-agn-nnhass-ga"
	rename value nnhass
	save "${intermediate}/topo/nnhass", replace

	* Housing asset side
	use "${intermediate}/topo/country", clear
	keep if varcode == "p-hs-agn-nfahou-ga"
	rename value nfahou
	save "${intermediate}/topo/nfahou", replace

	* Liabilities side
	use "${intermediate}/topo/country", clear
	keep if varcode == "p-hs-agn-fliabi-lb"
	rename value fliabi
	save "${intermediate}/topo/fliabi", replace

	merge 1:m year using "${intermediate}/topo/nfahou"
	drop _merge

	merge 1:m year using "${intermediate}/topo/nnhass"

	gen netwea = nnhass + nfahou -  fliabi
	rename netwea value
	replace varcode = "p-hs-agn-netwea-na"

	drop _merge nfahou nnhass fliabi

	order area year sector source percentile varcode value longname
	

	save "${intermediate}/topo/`ctry'_netwea", replace

}



clear
local files : dir "${intermediate}/topo" files "*_netwea.dta" ,  respectcase 
global files `files' 
local iter = 1 
tempfile ap 
foreach f in "$files" {
	qui use "${intermediate}/topo/`f'", clear 
	if `iter' != 1 qui append using `ap'
	qui save `ap', replace 
	local iter = 0 
	qui erase "${intermediate}/topo/`f'"
}

append using `inputfile'

drop if value == 0
drop if value == .

drop if varcode == "p-hs-agn-netwea-na" & area == "CL"
drop if varcode == "p-hs-agn-netwea-na" & area == "JP"
drop if varcode == "p-hs-agn-netwea-na" & area == "SE"

**


run "code/mainstream/auxiliar/all_paths.do"
global output "${topo_dir_raw}/LWS_topo/final table"
save "${output}/LWS_topo_warehouse.dta", replace
export delimited using "${output}/LWS_topo_warehouse.csv", replace
