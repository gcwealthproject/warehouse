

//load descriptions in memory 
*qui import excel "handmade_tables/eigt_concept_notes.xlsx", ///
*	sheet("Metadata_0") clear firstrow	
qui import excel "handmade_tables/dictionary.xlsx", ///
	sheet("d4_concept") clear firstrow	
qui levelsof code, local(concepts) clean 
foreach c in `concepts' {
	di as result "`c': " _continue 
	qui levelsof description if code == "`c'", local(des_`c') clean 
	*local des_`c' = subinstr("`des_`c''", ",","", .)
	local des_`c' = subinstr("`des_`c''", ";","", .)
	local des_`c' = subinstr("`des_`c''", `"""',  "", .)
	local des_`c' = subinstr("`des_`c''", char(10),  "", .)
	local des_`c' = subinstr("`des_`c''", char(13),  "", .)
	di as text "`des_`c''" 
}

qui use varcode using ///
	"raw_data/eigt/eigt_ready.dta", clear 
qui keep if substr(varcode, 1, 1) == "x"
duplicates drop 

qui gen description = ""
foreach c in `concepts' {
	qui replace description = "`des_`c''" if strpos(varcode, "`c'")
}

// keep only one per bracket
qui export excel "output/metadata/code_desc_viz.xlsx", ///
	sheet("long_version", replace) firstrow(variables) 
replace varcode = substr(varcode, 1, 15)
bys varcode: keep if _n == 1

//reshape 
qui replace varcode = subinstr(varcode, "-", "_", .)
qui gen id = 1
qui reshape wide description, i(id) j(varcode) string 
qui rename (description*) (*)

//export 
qui export excel "output/metadata/code_desc_viz.xlsx", ///
	sheet("Sheet1", replace) firstrow(variables) 
