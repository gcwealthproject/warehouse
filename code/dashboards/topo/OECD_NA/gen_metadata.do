      
** Set paths here
*run "Code/Stata/auxiliar/all_paths.do"
*tempfile all


global bycountry "${topo_dir_raw}/OECD_NA/intermediate/grid"
global pop "${topo_dir_raw}/OECD_NA/intermediate"
global cmappings "${topo_dir_raw}/OECD_NA/auxiliary files"
global intermediate "${topo_dir_raw}/OECD_NA/intermediate to erase"
global output "${topo_dir_raw}/OECD_NA/final table"

use "${pop}/populated_grid.dta", clear
// Check the following lines always before running the code
local general_source = "OECD_NA" // The source does not change across the do-file
levelsof sector, local(sector_list)
levelsof area, local(country_list)


//list compositions and codes in memory 
qui import excel using "${cmappings}/composition table NA.xlsx" , sheet("composition table") clear firstrow

qui ds code label description extended_composition1 d5_dboard_specific, not 
qui local comp `r(varlist)'
qui local ncomp = wordcount("`comp'")
qui display "`comp'"

qui levelsof code, local(codes) clean
qui local ncodes = wordcount("`codes'")
qui display "`codes'"

foreach c in `codes' {
  qui levelsof label if code == "`c'", local(lab_`c') clean   
  qui di as text " `lab_`c' '"
}

qui di as result "There are `ncomp' different compositions available " ///
	"for `ncodes' codes"

//save each composition's list of variables in memory 	
foreach cod in `codes' {
	qui di as result "`cod': "
	qui local iter = 1 
	foreach com in `comp' {
		qui di as text "  -`com' includes: "
		qui levelsof `com' if code == "`cod'", local(`cod'`iter') clean 
		qui levelsof `com' if code == "`cod'", local(`cod'`iter'_dirty) clean 
		qui levelsof extended_composition1 if code == "`cod'", ///
			local(`cod'_ext_comp) clean   
			  
		qui di as text "     dirty composition: ``cod'`iter''"
		*if not empty ...
		if "``cod'`iter''" != "" {
			foreach char in "+" "-" "(" ")" {
				local `cod'`iter' = ///
					subinstr("``cod'`iter''", "`char'", "", .)
			}
			qui di as text "     clean composition: ``cod'`iter''"
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

foreach s in `sector_list'{

	foreach ctry in `country_list' {
	
	capture import excel using "${bycountry}", clear firstrow sheet("`ctry'_`s'")
	display _rc
	if _rc == 0 {
	
	
	qui levelsof na_code, local(cod_`ctry') clean 
	qui levelsof varname_source, local(varnamesource_`ctry') clean 
	qui levelsof nacode_label, local(nacodelabel_`ctry') clean 

	di as result upper("`ctry'") _continue
	di as text " has these na_codes available `cod_`ctry''"  

	foreach cod in `codes' { // Loop over concepts
	
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
					qui levelsof varname_source if na_code == "`x'", ///
						local(vnsource_`x') clean 
					qui local vnsource `vnsource' `vnsource_`x''
					qui local vnsource "`vnsource';"
					
					*qui local vnsource : subinstr local vnsource " " ", ", all
						
					// Append (progressively) the na_label and na_code source names
					qui levelsof nacode_label if na_code == "`x'", ///
						local(nacode_label_`x') clean 
					qui local nalabelcode `nalabelcode' `nacode_label_`x''
					qui local nalabel_code "`nalabelcode' (`x');"
					qui local nalabelcode "`nalabelcode';"
						
					di as result " found it." 
					qui di as text "`vnsource'"
					qui di as text "`nalabelcode'"
					qui di as text "`nalabelcode' (`x')"
						
					}
					*subtract to list if not found 
					else {
						*di as error " didnt't find"
						qui local `cod'`iter'found = ``cod'`iter'found' - 1
					} 					
				} //close foreach x
				
				*check how many where found 
				di as result "  conclusion: " _continue
			
				if ``cod'`iter'found' == wordcount("``cod'`iter''")	{
				
					*di ``cod'`iter'found'
					qui local outcome "composition can be computed"
					di as text "`outcome'"

					// Display metadata
					qui di as result "  Metadata : " _continue
					
					 di as text `"Following the SNA terminology, the category "`lab_`cod''" is derived using the following formula: ``cod'_ext_comp' which is equivalent to: ``cod'1_dirty'. In practice, given data availability for this specific source, we use the following formula: ``cod'`iter'_dirty'. Using the original variable names, we use the following variables from the source: `vnsource'."'						
										
					qui gen metadata = ""
					
					// Create metadata
					
					qui replace metadata = `"Following the SNA terminology, the category "`lab_`cod''" is derived using the following formula: ``cod'_ext_comp' which is equivalent to: ``cod'1_dirty'. In practice, given data availability for this specific source, we use the following formula: ``cod'`iter'_dirty'. Using the original variable names, we use the following original variables from the source: `vnsource'."'
		
					// Old metadata
					*qui replace metadata = `"Following the SNA terminology, the category "`lab_`cod''" is derived using the following formula: ``cod'_ext_comp' which is equivalent to: ``cod'1_dirty'. In practice, using the original variable names and the data availability for this specific source, we use the following original variables from the source: `vnsource'."'
				
					preserve
						qui keep metadata
						qui replace metadata = subinstr(metadata, ";.", ".", .) 
						qui qui gen source = "`general_source'"
	
						qui gen sector = "`s'"
						qui gen area = "`ctry'"
						
						
						qui gen concept = "`cod'"
						qui gen label = "`lab_`cod''"
	
						* Output
						* area | source | sector | concept | label | metadata
						order area source sector concept label metadata
						keep if _n==1
	
						*tempfile `ctry'_`cod'

						qui save "${intermediate}/meta/meta_`ctry'_`s'_`cod'", ///
							replace
							
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


run "code/mainstream/auxiliar/all_paths.do"
global output "${topo_dir_raw}/OECD_NA/final table"
save "${output}/OECD_NA_metadata.dta", replace

