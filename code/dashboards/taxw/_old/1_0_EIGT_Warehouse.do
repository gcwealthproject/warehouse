/////////////////////////
/// Main do file for EIGT warehouse building
/////////////////////////

/// Last update: 21 May 2024
/// Author: Francesca

////////////////////////////////////////////////////////////////////////////////
/// STEP 0: General setting

	clear

// Working directory and paths

	global dofile "code/dashboards/eigt"
	global intfile "raw_data/eigt/intermediary_files"
	global hmade "handmade_tables"
	global supvars "output/databases/supplementary_variables"
	global output "raw_data/eigt"	
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 1: Building country-level warehouse

	display as result "building warehouse for countries..."
	run "$dofile/1_1_Countries_Warehouse.do"
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 2: Building regional-level warehouse

	display as result "building warehouse for regions..."
	run "$dofile/1_2_Regions_Warehouse.do"
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 3: Append and save 
	
	use "$intfile/eigt_countries_v1_ready.dta", clear
	append using "$intfile/eigt_USstates_v1_ready.dta"
	drop if substr(varcode, 10, 6) == "homexe"
	
	// Adjust the GEO naming 
	order GEO GeoReg_long
	sort GEO GeoReg_long year varcode
	replace GeoReg_long = ", " + GeoReg_long if GeoReg_long != ""
	replace GEO_long = GEO_long + GeoReg_long
	replace GeoReg = ", " + GeoReg if GeoReg != ""
	replace GEO = GEO + GeoReg 

	keep GEO GEO_long year value percentile varcode source longname note
	compress
	order GEO GEO_long year percentile varcode value source longname note
	
	qui save "$output/eigt_ready.dta", replace
	qui export delimited using "$output/eigt_ready.csv", replace nolabel 

	
** Create the metadata EIG 
	keep varcode percentile longname note
	rename longname metadata 
	duplicates drop  
	order varcode percentile metadata note
	
	qui export delimited using "output/metadata/metadata_eigt.csv", replace  
	
