//settings
clear all
run "code/mainstream/auxiliar/all_paths.do"

//memorize relevant info 
run $memorize_labels 
run $memorize_ctry_names 

*save percentile labels in memory 
qui import excel ///
	"handmade_tables/dictionary.xlsx", sheet("percentiles") firstrow clear
qui replace percentile = subinstr(percentile, ".", "_", .)
qui levelsof percentile, local(pctls) clean 
foreach p in `pctls' {
	qui levelsof label_percentile if percentile == "`p'", ///
		local(lab_`p') clean
}

//combine all dashboards 
tempfile x 
local iter = 1 
foreach d in ineq taxw topo inhe {
	di as result "appending `d' warehouse..."
	//import and fill longname 
	
	qui import delimited "raw_data/`d'/`d'_ready.csv", clear varnames(1) 
	cap drop metadata
	if "`d'" != "taxw" {
		di as text " filling longname..."
		run $fill_longname
	} 
	else {
		qui replace geo = subinstr(geo, ", ", "_", .)
		qui rename geo area 
		qui order area year value percentile varcode 
	}
	ds 
	
	//append and save
	if `iter' != 1 qui append using `x'
	local iter = 0
	qui save `x', replace 
}

*canonicalize source aliases without dropping extensionless source names
run $harmonize_source_aliases
qui rename area GEO 

//run checks and harmonize 
global checkvars GEO longname 
run $check_nonmissings 
run $harmonize_ctries 

//fill GEO_long 
qui gen GEO_long = ""
qui gen iso3 = ""
foreach g in $geos {
	qui replace GEO_long = "${lab_`g'}" if GEO == "`g'"
	qui replace iso3 = "${iso3_`g'}" if GEO == "`g'"
}
qui drop if missing(GEO_long)

*filter non-matching percentiles out 
qui qui gen percentile2 = subinstr(percentile, ".", "_", .) 
qui gen percentile_label = ""
foreach p in `pctls' {
	qui replace percentile_label = "`lab_`p''" ///
		if percentile2 == "`p'" 
}
qui drop if missing(percentile_label)
qui drop percentile2 percentile_label

*filter out missing varcodes 
qui gen varcode_length = length(varcode)

///////remove cap and drop 
cap assert varcode_length == 18
qui drop if varcode_length != 18
///////
qui drop varcode_length

foreach v in geo_long {
	cap drop `v'
}

//tidy up 
qui order GEO* year percentile varcode value 
qui sort  GEO* year percentile varcode value 

//save temporary file 
qui export delimited ///
	"raw_data/taxw/intermediary_files/warehouse_ar.csv", replace 
