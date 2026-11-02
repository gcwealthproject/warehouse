
global origin "${topo_dir_raw}/HFCS_topo/tables/topography/"
global output1 "${topo_dir_raw}/HFCS_topo/warehouse/final table"
global output2 "${topo_dir_raw}/HFCS_topo/final table"
global cmappings "${topo_dir_raw}/HFCS_topo/warehouse/auxiliary files"
global intermediate "${topo_dir_raw}/HFCS_topo/warehouse/intermediate to erase"


local general_source = "HFCS_topo" 

use "${origin}/aggregates_ho.dta", clear

// The next is common to gen_topography
*qui drop n_group_size
qui gen longname = ""
qui drop label 

qui replace source = "HFCS_topo"

qui gen sector = substr(varcode, 3, 2) // gen sector


qui order area source sector year percentile varcode value longname

qui replace varcode = substr(varcode, 1, 16)
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "netwea"
qui replace varcode = varcode+"ga" if substr(varcode, 10, 6) == "nnhass"
qui replace varcode = varcode+"lb" if substr(varcode, 10, 6) == "fliabi"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "facdbl"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "fadepo"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "faeqfd"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "falipe"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "nfabus"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "nfadur"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "offsho"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "nfahou"
qui replace varcode = varcode+"lb" if substr(varcode, 10, 6) == "fliabm"

*qui destring year, gen(yearr)
*qui drop year
*qui rename yearr year
// end part common to qui 

qui levelsof sector, local(sector_list)
qui levelsof area, local(country_list)


qui tempfile temp1
qui save `temp1'

foreach c of local country_list {
	
	qui use `temp1', clear
	qui keep if area == "`c'"
	qui duplicates drop varcode, force
	qui gen concept = substr(varcode, 10, 6) 
	qui drop year longname percentile value year varcode
	qui tempfile 
	qui tempfile topo_`c'
	qui save `topo_`c''
}



qui drop _all	
// append all country-level dataset 
foreach c of local country_list {
	qui append using `topo_`c''
}

qui drop sector source

qui tempfile fulltopo
qui save `fulltopo'


//list compositions and codes in memory 
qui import excel using "${cmappings}/composition table HFCS.xlsx" , sheet("composition table") clear firstrow

qui drop if code == "offsho"

qui ds code label description extended_composition1 d5_dboard_specific source_composition, not 
qui local comp `r(varlist)'
qui local ncomp = wordcount("`comp'")
qui display "`comp'"

qui qui levelsof code, local(codes) clean
qui qui local ncodes = wordcount("`codes'")
qui qui display "`codes'"

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
	qui foreach com in `comp' {
		qui di as text "  -`com' includes: "
		qui levelsof `com' if code == "`cod'", local(`cod'`iter') clean 
		qui levelsof `com' if code == "`cod'", local(`cod'`iter'_dirty) clean 
		qui levelsof extended_composition1 if code == "`cod'", ///
			local(`cod'_ext_comp) clean   
		qui levelsof source_composition if code == "`cod'", ///
			local(`cod'_varnamesource) clean   		
			  
		qui di as text "     dirty composition: ``cod'`iter''"
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

qui use `fulltopo', clear
qui levelsof area, local(country_list)

foreach c of local country_list {

qui use `fulltopo', clear

qui keep if area == "`c'"

qui gen metadata = ""

	foreach cod in `codes' { // Loop over concepts
	
	qui  di as text `"Following the SNA terminology, the category "`lab_`cod''" is derived using the following formula: ``cod'_ext_comp' which is equivalent to: ``cod'1_dirty'. In practice, given data availability for this specific source and the original variable codes, we use the following formula: ``cod'2_dirty'. Using the original variable names, we use the following variables from the source: ``cod'_varnamesource'."'	 
	
	// Create metadata			
	qui replace metadata = `"Following the SNA terminology, the category "`lab_`cod''" is derived using the following formula: ``cod'_ext_comp' which is equivalent to: ``cod'1_dirty'. In practice, given data availability for this specific source and the original variable codes, we use the following formula: ``cod'2_dirty'. Using the original variable names, we use the following variables from the source: ``cod'_varnamesource'."'
					
	preserve
		qui keep metadata
		qui replace metadata = subinstr(metadata, ";.", ".", .) 
		qui qui gen source = "`general_source'"
		qui gen sector = "hs" 
		qui local sector_short = sector
		qui gen area = "`c'"			   
		qui gen concept = "`cod'"
		qui gen label = "`lab_`cod''"
	
		* Output
		* area | source | sector | concept | label | metadata
		qui order area source sector concept label metadata
		qui keep if _n==1
		*tempfile `ctry'_`cod'

		qui save "${intermediate}/meta/meta_`c'_`sector_short'_`cod'", replace
			
		qui drop area source sector concept label metadata
	restore	 
					
					
	}
}


	
	
	

qui drop _all

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
global output "${topo_dir_raw}/HFCS_topo/warehouse/final table"
save "${output1}/HFCS_topo_metadata.dta", replace
save "${output2}/HFCS_topo_metadata.dta", replace


