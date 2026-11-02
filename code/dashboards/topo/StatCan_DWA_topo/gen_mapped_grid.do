

// Gen grid

global intermediate "${topo_dir_raw}/StatCan_DWA_topo/intermediate"
global origin "${topo_dir_raw}/StatCan_DWA_topo/raw data"


//import lissy output 
qui import delimited using ///
	"${origin}/3610066001_databaseLoadingData", varnames(1) delimiter(comma) case(lower) clear

// strip BOM from first variable name (file has UTF-8 BOM)
 ds
  local vars `r(varlist)'
  local firstvar : word 1 of `vars'
  if "`firstvar'" != "ref_date" rename `firstvar' ref_date
  
keep geo ref_date wealth value coordinate
	
rename geo area


levelsof area, local(loc_area)


preserve

	// Clean and reshape data
	replace value = . if value == 0
	drop if value == .
	* drop if variable == "hpopwgt"
	
	drop /*ref_date*/ value area
	duplicates drop

	rename  coordinate source_code 
	rename wealth varname_source
	gen na_code = ""
	gen nacode_label = ""
	order na_code source_code nacode_label varname_source

	// Export
	qui export delimited "${intermediate}/grid", replace

restore
	
	
	
	
 

   	
