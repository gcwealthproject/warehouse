

** Set paths here
*run "Code/Stata/auxiliar/all_paths.do"
*tempfile all


// Check the following lines always before running the code
local general_source = "ECB_DWA_topo" // The source does not change across the do-file
qui local sector_list S14
qui local country_list AT BE CY DE EE ES FI FR GR HU IE IT LT LU LV MT NL PT SI SK
	
* Origin folder: it contains the excel files to import
global bycountry "${topo_dir_raw}/ECB_DWA_topo/intermediate"
global bycountry_data "${topo_dir_raw}/ECB_DWA_topo/intermediate/populated_grid"
global cmappings "${topo_dir_raw}/ECB_DWA_topo/auxiliary files"
global intermediate "${topo_dir_raw}/ECB_DWA_topo/intermediate to erase"
global output "${topo_dir_raw}/ECB_DWA_topo/output"		
		
		

//list compositions and codes in memory 
qui import excel using "${cmappings}/composition table DWA.xlsx", sheet("composition table") clear firstrow

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
	
	qui import excel using "${bycountry}/grid.xlsx", clear firstrow sheet("`ctry'_`s'")
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
				qui di as result " `cod' nº`iter' needs " ///
					wordcount("``cod'`iter''") " items: ``cod'`iter''"
				qui local `cod'`iter'found = wordcount("``cod'`iter''")	

				*loop over each code-composition's item  
				qui local vnsource
				qui local nalabelcode
				
				foreach x in ``cod'`iter'' {
					
					qui di as text "  - `x'" _continue 
					cap assert strpos(" `cod_`ctry'' ", " `x' ") 
					if _rc == 0 {
						
						qui di as result " found it." 
						*qui di as text "`vnsource'"
						
					}
					*subtract to list if not found 
					else {
						*qui di as error " didnt't find"
						qui local `cod'`iter'found = ``cod'`iter'found' - 1
					}
					
				} //close foreach x
				
				*check how many where found 
				qui di as result "  conclusion: " _continue
			
				if ``cod'`iter'found' == wordcount("``cod'`iter''")	{

					*di ``cod'`iter'found'
					qui local outcome ///
						"composition can be computed using : ``cod'`iter'_dirty'"
					qui di as text "`outcome'"
		
					// Save country in local 
					qui local area_short =  "`ctry'"

					qui di as text "`sector_short'" // and print it

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
					qui di as text "composition cannot be computed"
				}
				
			
			} // close if wordcount("``cod'`iter''") != 0 
			
			local iter = `iter' + 1
		} // close foreach com in `comp'
		
	
	}
		
	}
	

	
}	


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


decode year, gen(yyear)
destring yyear, gen(yyyear)
drop year yyear 
rename yyyear year
order year, first

// convert EUR to Forint, using latest rate when year > max(rate year)
* 1) Bring in rates and capture the latest HU year & rate
preserve
    import delimited ///
        "${supvar_wid_dwld}/supvars_wide_18Jul2025.csv", ///
        varnames(1) stringcols(_all) clear
    keep country year xlceux
    keep if country == "HU"
    rename country area
    destring year xlceux, replace ignore(" ,")
    duplicates drop area year, force
    * Record latest available year and corresponding rate for HU
    quietly summarize year, meanonly
    local hu_last_year = r(max)
    quietly summarize xlceux if year == `hu_last_year', meanonly
    local hu_last_rate = r(mean)
    tempfile hurates
    save `hurates'
restore
* 2) Merge the year-specific rates where available
merge m:1 area year using `hurates', keep(master match) nogen
* 3) Convert: EUR -> HUF
*    - If we have a year-specific rate, use it
*    - If the observation's year is after the last rate year and xlceux is missing, use the latest available rate
gen value_huf = value
replace value_huf = value * xlceux if area == "HU" & !missing(xlceux)
* use last known HU rate for years beyond the rate sheet
replace value_huf = value * `hu_last_rate' if area == "HU" & missing(xlceux) & year > `hu_last_year'
replace value = value_huf if area == "HU"
drop value_huf xlceux

run "code/mainstream/auxiliar/all_paths.do"
global output "${topo_dir_raw}/ECB_DWA_topo/final table"
save "${output}/ECB_DWA_topo_warehouse.dta", replace
export delimited using "${output}/ECB_DWA_topo_warehouse.csv", replace
