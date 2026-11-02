      
** Set paths here
run "code/mainstream/auxiliar/all_paths.do"
*tempfile all


// Check the following lines always before running the code
local general_source = "LWS_topo" // The source does not change across the do-file
qui local sector_list S14
qui local country_list AT AU CA CL DE EE ES FI GR IT JP LU NO SE SI SK UK US ZA	FR DK IN KR // MX	
	
		
* Origin folder: it contains the excel files to import
global bycountry "${topo_dir_raw}/LWS_topo/intermediate/"
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



qui ds code label description extended_composition1 d5_dboard_specific, not 
qui local comp `r(varlist)'
qui local ncomp = wordcount("`comp'")
qui display "`comp'"

qui levelsof code, local(codes) clean
qui local ncodes = wordcount("`codes'")
qui display "`codes'"

foreach c in `codes' {
  levelsof label if code == "`c'", local(lab_`c') clean   
  di as text " `lab_`c' '"
}

di as result "There are `ncomp' different compositions available " ///
	"for `ncodes' codes"

//save each composition's list of variables in memory 	
foreach cod in `codes' {
	di as result "`cod': "
	qui local iter = 1 
	foreach com in `comp' {
		di as text "  -`com' includes: "
		levelsof `com' if code == "`cod'", local(`cod'`iter') clean 
		levelsof `com' if code == "`cod'", local(`cod'`iter'_dirty) clean 
		levelsof extended_composition1 if code == "`cod'", ///
			local(`cod'_ext_comp) clean   
			  
		di as text "     dirty composition: ``cod'`iter''"
		*if not empty ...
		if "``cod'`iter''" != "" {
			foreach char in "+" "-" "(" ")" {
				local `cod'`iter' = ///
					subinstr("``cod'`iter''", "`char'", "", .)
			}
			di as text "     clean composition: ``cod'`iter''"
			* qui macro list _`cod'`iter'_dirty
			* qui macro list _`cod'`iter'
		}
		else {
			*di as error "empty"
		}
		local iter = `iter' + 1
	}
}	 



** Crate metadata by country-sector-concept triple

//now open country by country and check lists one by one 


	foreach ctry in `country_list' {
	
	*qui import excel using "${bycountry}", clear firstrow sheet("`ctry'")
	qui import delimited "${bycountry}/`ctry'", clear varnames(1) 

	// source specific
	drop na_code
	rename source_code na_code

	levelsof na_code, local(cod_`ctry') clean
	levelsof varname_source, local(varnamesource_`ctry') clean
	levelsof nacode_label, local(nacodelabel_`ctry') clean

	di as result upper("`ctry'") _continue
	di as text " has these na_codes available `cod_`ctry''"

	foreach cod in `codes' { // Loop over concepts

		// Skip fadepo for countries where the relevant deposit variable includes cash:
		// KR, NO: hafc includes cash; US: hafct (and hence hafc) includes cash; MX: hafcs includes cash
		if "`cod'" == "fadepo" {
			if "`ctry'" == "KR" | "`ctry'" == "NO" | "`ctry'" == "US" | "`ctry'" == "MX" {
				di as text "  Skipping `cod' for `ctry': deposit variable includes cash"
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
						
					// Append (progressively) the var source names
					levelsof varname_source if na_code == "`x'", ///
						local(vnsource_`x') clean 
					local vnsource `vnsource' `vnsource_`x''
					local vnsource "`vnsource';"
					
					*qui local vnsource : subinstr local vnsource " " ", ", all
						
					// Append (progressively) the na_label and na_code source names
					levelsof nacode_label if na_code == "`x'", ///
						local(nacode_label_`x') clean 
					local nalabelcode `nalabelcode' `nacode_label_`x''
					local nalabel_code "`nalabelcode' (`x');"
					local nalabelcode "`nalabelcode';"
						
					di as result " found it." 
					qui di as text "`vnsource'"
					qui di as text "`nalabelcode'"
					qui di as text "`nalabelcode' (`x')"
						
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
					local outcome "composition can be computed"
					di as text "`outcome'"

					// Display metadata
					di as result "  Metadata : " _continue
					
					di as text `"Following the SNA terminology, the category "`lab_`cod''" is derived using the following formula: ``cod'_ext_comp' which is equivalent to: ``cod'1_dirty'. In practice, given data availability for this specific source and the original variable codes, we use the following formula: ``cod'`iter'_dirty'. Using the original variable names, we use the following variables from the source: `vnsource'."'						
										
					qui gen metadata = ""
					
					// Create metadata
					
					qui replace metadata = `"Following the SNA terminology, the category "`lab_`cod''" is derived using the following formula: ``cod'_ext_comp' which is equivalent to: ``cod'1_dirty'. In practice, given data availability for this specific source and the original variable codes, we use the following formula: ``cod'`iter'_dirty'. Using the original variable names, we use the following original variables from the source: `vnsource'."'
		
					// Old metadata
					*qui replace metadata = `"Following the SNA terminology, the category "`lab_`cod''" is derived using the following formula: ``cod'_ext_comp' which is equivalent to: ``cod'1_dirty'. In practice, using the original variable names and the data availability for this specific source, we use the following original variables from the source: `vnsource'."'
				
					preserve
						qui keep metadata
						qui replace metadata = subinstr(metadata, ";.", ".", .) 
						qui qui gen source = "`general_source'"
	
						qui gen sector = "hs" 
						qui local sector_short = sector

						qui gen area = "`ctry'"
							   
						qui gen concept = "`cod'"
						qui gen label = "`lab_`cod''"
	
						* Output
						* area | source | sector | concept | label | metadata
						order area source sector concept label metadata
						keep if _n==1
	
						*tempfile `ctry'_`cod'

						qui save "${intermediate}/meta/meta_`ctry'_`sector_short'_`cod'", replace
							
						qui drop area source sector concept label metadata
					restore	 
					qui drop metadata
						
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


drop _all
//put all the metadata together 
clear
local files : dir "${intermediate}/meta" files "meta_*.dta" ,  respectcase 
global files `files' 
local iter = 1 
tempfile ap 
foreach f in "$files" {
	qui use "${intermediate}/meta/`f'", clear 
	if `iter' != 1 qui append using `ap'
	qui save `ap', replace 
	local iter = 0 
	qui erase "${intermediate}/meta/`f'"
}


** Temporary code (May 22, by Giacomo)
gen pos = strpos(metadata,"In practice") if concept == "netwea"
replace metadata = substr(metadata,1,pos-1) if concept == "netwea"
replace metadata = metadata+" In practice, given data availability for this specific source, we use the following formula: (Financial Assets & Fixed Capital of Personal Businesses) + (Housing & Land) - (Debt)." if concept == "netwea"
**

run "code/mainstream/auxiliar/all_paths.do"
global output "${topo_dir_raw}/LWS_topo/final table"
save "${output}/LWS_topo_metadata.dta", replace


