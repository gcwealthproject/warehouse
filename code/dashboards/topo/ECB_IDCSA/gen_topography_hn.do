

** Set paths here
*run "code/mainstream/auxiliar/all_paths.do"
*tempfile all


// Check the following lines always before running the code
local general_source = "ECB_IDCSA" // The source does not change across the do-file
qui local sector_list S1M
qui local country_list albania australia brazil canada chile colombia iceland israel india ///
		japan korea mexico newzealand northmacedonia norway russia ///
		switzerland turkey gb usa
		
	
* Origin folder: it contains the excel files to import
global bycountry "${topo_dir_raw}/ECB_IDCSA/intermediate/grid_hn"
global bycountry_data "${topo_dir_raw}/ECB_IDCSA/intermediate/populated_grid_hn"
global cmappings "${topo_dir_raw}/ECB_IDCSA/auxiliary files"
global intermediate "${topo_dir_raw}/ECB_IDCSA/intermediate to erase"
global output "${topo_dir_raw}/ECB_IDCSA/final table"		
		

//list compositions and codes in memory 
qui import excel using "${cmappings}/composition table NA.xlsx" , sheet("composition table") clear firstrow

qui ds code label description extended_composition1 d5_dboard_specific, not 
qui local comp `r(varlist)'
qui local ncomp = wordcount("`comp'")
qui display "`comp'"

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
		qui di as text "  -`com' includes: "
		qui levelsof `com' if code == "`cod'", local(`cod'`iter') clean 
		qui levelsof `com' if code == "`cod'", local(`cod'`iter'_dirty) clean 
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
	
	qui import excel using "${bycountry}", clear firstrow sheet("`ctry'_`s'")
	qui levelsof na_code, local(cod_`ctry') clean 
	qui levelsof varname_source, local(varnamesource_`ctry') clean 
	qui levelsof nacode_label, local(nacodelabel_`ctry') clean 

	qui di as result upper("`ctry'") _continue
	qui di as text " has these na_codes available `cod_`ctry''"  

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
						"composition can be computed using : ``cod'`iter'_dirty'"
					di as text "`outcome'"
		
					local area_short ""   // default empty

						if      "`ctry'" == "albania"         local area_short "AL"
						else if "`ctry'" == "australia"       local area_short "AU"
						else if "`ctry'" == "bulgaria"        local area_short "BG"
						else if "`ctry'" == "brazil"          local area_short "BR"
						else if "`ctry'" == "canada"          local area_short "CA"
						else if "`ctry'" == "chile"           local area_short "CL"
						else if "`ctry'" == "colombia"        local area_short "CO"
						else if "`ctry'" == "iceland"         local area_short "IS"
						else if "`ctry'" == "israel"          local area_short "IL"
						else if "`ctry'" == "india"           local area_short "IN"
						else if "`ctry'" == "japan"           local area_short "JP"
						else if "`ctry'" == "korea"           local area_short "KR"
						else if "`ctry'" == "mexico"          local area_short "MX"
						else if "`ctry'" == "newzealand"      local area_short "NZ"
						else if "`ctry'" == "northmacedonia"  local area_short "MK"
						else if "`ctry'" == "norway"          local area_short "NO"
						else if "`ctry'" == "russia"          local area_short "RU"
						else if "`ctry'" == "switzerland"     local area_short "CH"
						else if "`ctry'" == "turkey"          local area_short "TR"
						else if "`ctry'" == "gb"              local area_short "GB"
						else if "`ctry'" == "usa"             local area_short "US"

						di as text "`area_short'"
					
					// Save sector in local 
					if "`s'" == "S1M" {
						qui local sector_short =  "hn" 
					}
					if "`s'" == "S14" {
						qui local sector_short =  "hs" 
					}
					if "`s'" == "S15" {
						qui local sector_short =  "np" 
					}
					qui di as text "`sector_short'" // and print it

					
					// Create topography concept
					preserve
						use "${bycountry_data}", clear
						qui keep if area == "`area_short'"
						qui keep if sector == "`sector_short'"
						
						qui gen percentile = "p0p100"						
						qui gen d1 = "p" // Dashboard: Wealth topography
						qui gen d2 = sector // Sector
						qui gen d3 = "agn"  // 	Vartype: Aggregate (Non-consolidated)
						qui gen d4 = "`cod'" // Concept
						qui gen d5 = "`d5_`cod''" // Dashboard specific
	
						qui gen varcode = d1+"-"+d2+"-"+d3+"-"+d4+"-"+d5						
						
						qui gen value = ``cod'`iter'_dirty' // it works! 
						qui di value
						qui gen longname = ""
					
						* Output
						* area | year | source | percentile | varcode | value | longname (empty)
						qui keep area year source percentile varcode sector value longname
						qui drop if value == . // clean
						
						save "${intermediate}/topo/topo_`ctry'_`sector_short'_`cod'", replace
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

