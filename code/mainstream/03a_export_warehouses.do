//general settings 
clear all 
run "code/mainstream/auxiliar/version_control.do"		
run "code/mainstream/auxiliar/all_paths.do"		
if ("${vctr}" == "" | "${old_vctr}" == "") {
	di as error "You need to specify a current and old version " ///
		"to run this do-file. either in a global or in " ///
		"auxiliar/version_control.do"
} 				

*store variable format in memory (_viz, _meta)
foreach w in viz meta {
	local fnam warehouse_`w'
	di _newline 
	di as result "storing formats from warehouse_`w'" 
	if "`w'" == "meta" {
		qui import delimited ///
			"output/databases/warehouse/`fnam'${old_vctr}.csv", clear 
	} 
	else {
		qui import delimited "output/databases/`fnam'.csv", clear 
	}
	cap drop 
	*qui use "output/databases/`fnam'.dta", clear 
	global wht `w'
	run "code/mainstream/auxiliar/describe_warehouse.do"
	foreach v of global whvars_`w' {
		di as result "`v': " _continue 
		foreach u in typ for pos isn {
			di as text "`u'(${`v'_`u'_`w'}) " _continue 
		}
	}
	if ("`w'" == "vix") exit 1  
}

*load source-specific metadata to memory 
qui import excel "handmade_tables/dictionary.xlsx", ///
	sheet("Sources") firstrow clear case(lower)
qui keep section aggsource legend source link ref_link citekey ///
	inclusion_in_warehouse 

//tag dashboards in sources 
qui gen _1_dashboard = "" 
qui replace _1_dashboard = "i" if section == "Inheritance Trends"
qui replace _1_dashboard = "p" if section == "Wealth Topography"
qui replace _1_dashboard = "t" if section == "Wealth Inequality"
qui replace _1_dashboard = "x" if section == "Taxes on Wealth"
qui drop if missing(source)

*get rid of duplicates 
duplicates tag source _1_dashboard, gen(dup)
bysort source dup: gen counter = sum(dup)
qui drop if counter == 2 
qui drop dup counter
drop section 
tempfile tfmeta 
qui save `tfmeta' 

*load topo metadata to memory 
qui import excel "output/metadata/metadata_topo.xlsx", ///
	sheet("meta") firstrow clear case(lower)
qui rename _1_dasboard _1_dashboard_lab	
cap rename (area metadata) (geo metadata_topo) 
run $harmonize_source_aliases
tempfile tf_topo 
qui save `tf_topo'
di as result "topo metadata variables: " _continue
qui format %1300s metadata 
qui format * 

//load ineq metadata here 
qui import delimited "output/metadata/metadata_ineq.csv", clear varnames(1)
qui keep varcode percentile metadata 
tempfile tf_ineq 
qui save `tf_ineq' 
di as result "topo metadata variables: " _continue 
qui  format %1300s metadata 
qui  format * 

// load taxw metadata here 
qui import delimited "output/metadata/metadata_taxw.csv", clear varnames(1) 
tempfile tf_taxw 
qui save `tf_taxw' 
di as result "taxw metadata variables: " _continue 
qui format %1300s metadata 
qui  format * 

*save percentile labels in memory 
qui import excel ///
	"handmade_tables/dictionary.xlsx", sheet("percentiles") firstrow clear
qui replace percentile = subinstr(percentile, ".", "_", .)
qui levelsof percentile, local(pctls) clean 
foreach p in `pctls' {
	qui levelsof label_percentile if percentile == "`p'", ///
		local(lab_`p') clean
}

*bring warehouse candidate 
qui import delimited ///
	"raw_data/taxw/intermediary_files/warehouse_ar.csv", varnames(1) clear 
qui replace varcode = subinstr(varcode, "_", "-", .) 
run $harmonize_source_aliases

*fill longname 
preserve 
	run $memorize_labels
restore 
cap drop area 
qui gen area = geo
run $fill_longname 
assert !missing(longname) 
qui drop area 

*merge warehouse to ineq metadata
qui merge m:1 varcode percentile using `tf_ineq', keep(1 3) gen(ineq_match)
qui format %1300s metadata  
qui  format * 

*check if observations match  
qui levelsof ineq_match if substr(varcode, 1, 1) == "t", local(mmm) ///
	clean 
cap assert "`mmm'" == "3"
if _rc != 0 {
	qui levelsof source ///
		if ineq_match != 3 & substr(varcode, 1, 1) == "t", ///
		local(miss) clean
	di as error "some observations in the warehouse don't match " ///
	"output/metadata/metadata_ineq.csv. Sources: `miss'" 
	exit 123
}
qui drop ineq_match 

*prepare warehouse to merge topo metadata 
qui gen _1_dashboard_lab = substr(varcode, 1, 1)
qui gen _2_sector_lab    = substr(varcode, 3, 2)
qui gen _4_concept_lab   = substr(varcode, 10,6)
foreach n in _1_dashboard_lab _2_sector_lab _4_concept_lab {
	local n2 = substr("`n'", 2, 1)
	di as result "`n': `n2' : ${codes`n2'}"
	foreach c in ${codes`n2'} {
		di as text "`c'"
		qui replace `n' = "${code`n2'_`c'}" if `n' == "`c'" 
	}
}

//recast format of source (note: no strL allowed in merge)
tempvar tv1 
egen `tv1' = max(strlen(source))
local ml = `tv1'[1]
recast str`ml' source

//merge 
format %1300s metadata 
merge m:1 geo source _1_dashboard_lab _2_sector_lab _4_concept_lab ///
	using `tf_topo', keep(1 3) gen(topo_match) 
format *	
	
*check all metadata is matching with 
qui levelsof topo_match if substr(varcode, 1, 1) == "p", local(mmm) clean 
cap assert "`mmm'" == "3"
if _rc != 0 {
	qui levelsof source ///
		if topo_match != 3 & substr(varcode, 1, 1) == "p", ///
		local(miss) clean
	di as error "some observations in the warehouse don't match " ///
	"output/metadata/metadata_topo. Sources: `miss'" 
	*exit 123
}

qui replace metadata = metadata_topo if substr(varcode, 1, 1) == "p"
qui drop metadata_topo topo_match

*fill percentile labels 
qui replace percentile = subinstr(percentile, ".", "_", .) 
foreach v in percentile_label WhichDistrib {
	cap drop `v' 
	qui gen `v' = ""
}

local iter = 1 
foreach p in `pctls' {
	if `iter' == 1 di as result "Displaying WhichDistrib associations: "
	qui replace percentile_label = "`lab_`p''" if percentile == "`p'" 
	local wdbx: word 1 of `lab_`p'' 
	if "`wdbx'" == "All" local wdbx Overall 
	if "`wdbx'" == "Next" local wdbx Top 
	qui replace WhichDistrib = "`wdbx'" if percentile == "`p'" 
	di as text " `wdbx' <-- `p'"
	local iter = 0
}
qui replace percentile = subinstr(percentile, "_", ".", .) 

*parse varcode in warehouse 
qui split varcode, parse("-") gen(d)

*print labels 
forvalues d = 1/5 {
	qui gen d`d'_lab = ""
	qui gen d`d'_des = ""
	foreach c in ${codes`d'} {
		qui replace d`d'_lab = "${code`d'_`c'}" if d`d' == "`c'"
		qui replace d`d'_des = "${desc`d'_`c'}" if d`d' == "`c'"
	}
	cap drop _`d'_${d`d'} 
	cap drop _`d'_${d`d'}_lab
	qui rename (d`d' d`d'_lab) (_`d'_${d`d'} _`d'_${d`d'}_lab)
}

*fill indicator label 
qui egen indicator_label = ///
	concat(percentile_label _3_vartype_lab) ///
	if substr(varcode, 1, 1) == "t", punct(", ")
di as result "Indicator labels created, list of possible values:"	
qui levelsof indicator_label, local(all_il)
foreach il in `all_il' {
	di as text "`il'."
}

*merge with source-metadata 
merge m:1 source _1_dashboard using `tfmeta', nogen keep(3 1)


*fill source type variable whenever missing due to multiple sources (EIG)
replace aggsource = "Multiple source types" ///
	if strpos(source, "/") > 0 & aggsource == ""	
	
*check renold and rennew have same lenght 
cap assert  wordcount("`renold'") == wordcount("`rennew'") 
if _rc != 0 {
	di as error "You tried to rename " wordcount("`renold'") " sources " ///
		"with " wordcount("`rennew'") " names
}
if _rc == 0 {
	local nsources = wordcount("`renold'") 
	forvalues n = 1/`nsources' {
		local old: word `n' of `renold'
		local new: word `n' of `rennew'
		if `n' == 1 di as result "renaming sources..."
		di as text "`old' --> "  _continue 
		di as result "`new'" 
		replace source = "`new'" if source == "`old'"
	}
	replace source = "Iacono2021" if strpos(source, "¿Iacono2021")
}

*clean 
cap confirm str variable label, exact 
if _rc == 0 {
	qui drop label 
}

qui rename (geo geo_long) (GEO GEO_long)
cap drop __*
qui order *_des, last

global checkvars ///
	percentile varcode longname GEO GEO_long source iso3 ///
	metadata percentile_label WhichDistrib _1_dashboard _2_sector ///
	_3_vartype _4_concept _5_dboard_specific _1_dashboard_lab ///
	_2_sector_lab _3_vartype_lab _4_concept_lab _5_dboard_specific_lab ///
	aggsource legend ref_link citekey ///
	d1_des d2_des d3_des d4_des d5_des year 
*run $check_nonmissings

//replace double quotes if any
qui ds, has(type string)
foreach var of varlist `r(varlist)' {
    qui replace `var' = subinstr(`var', `""', "'", .)
}
qui duplicates drop 

*check consistency with older versions of warehouse_viz 
//describe new  
global wht new
preserve 
	qui drop if substr(varcode, 1, 1) == "x"
	run "code/mainstream/auxiliar/describe_warehouse.do"
restore 

//compare old vs new 
foreach v in $whvars_viz {
	foreach u in /*typ for pos*/ isn {
		cap assert "${`v'_`u'_viz}" == "${`v'_`u'_new}" 
		if _rc != 0 {
			if "`u'" == "isn" local u2 is_numeric 
			if !inlist("`v'", "vgeo", "vgeolong", "vvaluestr", ///
				"vwhichdistrib", "vinclusioninwarehouse", "vgeoreg", ///
				"vlastupdate", "vccitekey", "vnote") {
				local vardes_problems_viz `vardes_problems_viz' ///
				`v'-`u2': viz(${`v'_`u'_viz})/new(${`v'_`u'_new});
			}
		}			
	}
}

//report problems 
if "`vardes_problems_viz'" != "" {
	di as error "mismatch found in the following variables:" _continue
		di as error "`vardes_problems_viz'"
	exit 1	
}

//report good news
else {
	di as result ///
	"all variables match the old warehouse's format (viz), " _continue 
	di as result "variable type (numeric or not). Variables containing vgeo, vgeolong, vvaluestr, vwhichdistrib, vinclusioninwarehouse, and vgeoreg where ignored"
}

*MERGE WITH TAXW METADATA 
qui rename metadata metadata_original
qui format %1300s metadata_original
qui merge m:1 varcode percentile ///
	using `tf_taxw', keep(1 3) gen(taxw_match) 
qui replace metadata_original = metadata if taxw_match == 3 
qui drop metadata taxw_match
qui rename metadata_original metadata 
qui format *

*export viz
preserve 
	cap drop c_citekey
	qui drop if substr(varcode, 1, 1) == "x"
	qui export delimited "output/databases/warehouse_viz.csv", replace
restore 

//export warehouse and warehouse_meta 
qui rename _#_* d#_*
local keeper GEO GEO_long year percentile ///
	varcode value /*value_str*/ source aggsource legend ///
	longname metadata ref_link link citekey note ///
	d1_* d2_* d3_* d4_* d5_*
qui keep `keeper'	
qui order `keeper'
qui duplicates drop 

qui rename (d1_des d2_des d3_des d4_des d5_des aggsource) ///
	(d1_dashboard_des d2_sector_des d3_vartype_des d4_concept_des ///
	d5_dboard_specific_des source_type)

foreach z in "_meta" "_norm" {
	local ext `z'
	if "`z'" == "_norm" {
		local ext ""
		qui drop metadata ref_link d1_* d2_* d3_* d4_* d5_* ///
			source_type legend ref_link link citekey	
	}
	if "`z'" == "_meta" {
		
		//describe new warehouse 
		global wht new
		preserve 
			run "code/mainstream/auxiliar/describe_warehouse.do"
		restore 
		
		//compare old vs new 
		foreach v in $whvars_meta {
			foreach u in /*typ for  pos*/ isn {
				cap assert "${`v'_`u'_meta}" == "${`v'_`u'_new}" 
				if _rc != 0 {
					if "`u'" == "isn" local u2 is_numeric 
					if "`u'" == "" local u2 rank
					if !inlist("`v'", "vgeo", "vgeolong", ///
						"vlastupdate", "vvaluestr") {
						local vardes_problems_meta `vardes_problems_meta' ///
						`v'-`u2': meta(${`v'_`u'_meta})/new(${`v'_`u'_new});
					}
				}			
			}
		}
		//report problems 
		if "`vardes_problems_meta'" != "" {
			di as error "mismatch found in the following variables:"
				di as error "`vardes_problems_meta'"
			exit 1	
		}
		//report all's good 
		else {
			di as result ///
			"all variables match the old warehouse's format (meta), " _continue 
			di as result "variable type (numeric or not). Variables containing 'geo' where ignored"
		}
	}
	
	//add version control 
	cap drop last_update
	qui gen last_update = "$S_TIME - $S_DATE" in 1
	
	//save 
	di as result "saving warehouse`ext'..." _continue 
	qui export delimited ///
		"output/databases/warehouse/warehouse`ext'${vctr}.csv", replace 
	*qui export excel ///
	*	"output/databases/warehouse/warehouse`ext'${vctr}.xlsx", ///
	*	replace firstrow(variables)
	*qui save ///
	*	"output/databases/warehouse/warehouse`ext'${vctr}.dta", replace
	di as result " (done)"
	tempfile tff
	qui save `tff', replace 
	
	/*
	//export individual dashboards too 
	foreach d in ineq topo taxw inhe {
		preserve 
			di as result "saving `d'_warehouse`ext' ..." _continue 
			if "`d'" == "ineq" local pf t
			if "`d'" == "topo" local pf p
			if "`d'" == "taxw" local pf x
			if "`d'" == "inhe" local pf i
			qui use `tff', clear 
			//save 
			qui keep if substr(varcode, 1, 1) == "`pf'"
			qui export delimited ///
				"output/databases/dashboards/`d'_warehouse`ext'${vctr}.csv", ///
				replace 
			*qui export excel ///
			*	"output/databases/dashboards/`d'_warehouse`ext'${vctr}.xlsx", ///
			*	replace firstrow(variables)
			qui save ///
				"output/databases/dashboards/`d'_warehouse`ext'${vctr}.dta", ///
				replace 
			di as result " (done)"	
		restore 	
	}
	*/
}		




