/////////////////////////
/// Main do file for EIGT warehouse building
/////////////////////////

/// Last update: July 2025
/// Author: Francesca
/// Data input: $intfile/eigt_countries_v1_ready; $intfile/eigt_countries_new_ready; $intfile/eigt_USstates_v1_ready 
/// Data output: $output/eigt_ready; $intfile/eigt_data_coverage; $dir/output/metadata/metadata_eigt


////////////////////////////////////////////////////////////////////////////////
/// STEP 0: General setting

	clear

// Working directory and paths
/*
	global dofile "code/dashboards/eigt"
	global intfile "raw_data/eigt/intermediary_files"
	global hmade "handmade_tables"
	global supvars "output/databases/supplementary_variables"
	global output "raw_data/eigt"	
*/ 

	
////////////////////////////////////////////////////////////////////////////////
/// STEP 1.1: Building country-level warehouse

	display as result "Building warehouse for countries..."
	run "$dofile/1_1_Countries_Warehouse.do"

////////////////////////////////////////////////////////////////////////////////
/// STEP 2: Adding new data

	display as result "Adding new data for countries..."
	run "$dofile/1_2_NewData_Warehouse.do"
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 3: Building regional-level warehouse

	display as result "Building warehouse for regions..."
	run "$dofile/1_3_Regions_Warehouse.do"
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 4: Append, check consistency and save 

	display as result "Merging all together..."

qui {
	use "$intfile/eigt_countries_v1_ready.dta", clear
	// For Italy, we directly want the new data, more updated and correct
	drop if GEO == "IT" & substr(varcode, 3, 2) != "tg" & substr(varcode, 3, 2) != "gg"

	// Add new information from EY EIG reports 
	rename (value source source_legend longname note) (value_og source_og source_legend_og longname_og note_og)
	merge 1:1 GEO year varcode using "$intfile/eigt_countries_new_ready.dta"

	sort GEO year varcode
	
	gen sector = substr(varcode, 4, 1)	
	gen tax = substr(varcode, 3, 1)
	gen concept = substr(varcode, 10, 6)
	
	// Correct wrong sector in the original data 
	
	gen sector2 = sector if inlist(sector, "c", "e", "u")
	egen nvals = nvals(sector2), by(GEO_long year tax concept)
	tab nv // nvals = 2 if children are reported as c and e depending on the source: we keep only the new source

	preserve 
		// Keep cases of double varcode with different sector in original and new data 
		keep if nv == 2 
		keep GEO GEO_l year varcode _m 
		// Keep the right (new) sector for those observations 
		keep if _m == 2
		keep GEO year varcode 
		gen pippo = substr(varcode, 3, 1) + "-" + substr(varcode, 6, .)
		rename varcode varcode2
		tempfile data2 
		save "`data2'", replace
	restore
	// Keep cases of double varcode with different sector in original and new data and keep the wrong version
	keep if nv == 2 
	keep if _m == 1
	keep GEO GEO_l year varcode
	gen pippo = substr(varcode, 3, 1) + "-" + substr(varcode, 6, .)
	rename varcode varcode1

	// Attach the right (new) sector 
	merge 1:1 GEO year pippo using "`data2'", keep(matched) nogen
	replace varcode1 = varcode2 
	drop varcode2
	rename varcode1 varcode 
	tempfile datacorrect 
	save "`datacorrect'", replace

	// Now ready to attach to the original data the right sector
	use "$intfile/eigt_countries_v1_ready.dta", clear	
	// For Italy, we directly want the new data, more updated and correct
	drop if GEO == "IT" & substr(varcode, 3, 2) != "tg" & substr(varcode, 3, 2) != "gg"
	
	gen pippo = substr(varcode, 3, 1) + "-" + substr(varcode, 6, .)
	rename varcode varcode_og
	merge 1:1 GEO year pippo using "`datacorrect'"
	replace varcode_og = varcode if _m == 3 
	drop varcode
	rename varcode_og varcode 
	drop _m

	rename (value source source_legend longname note) (value_og source_og source_legend_og longname_og note_og)
	merge 1:1 GEO year varcode using "$intfile/eigt_countries_new_ready.dta"	

	// Still there are cases of double sector for same varcode: in this case it happens because we have inconsistent information on the brackets so some brackets are missing in the old/new data
	gen sector = substr(varcode, 4, 1)	
	gen tax = substr(varcode, 3, 1)
	gen concept = substr(varcode, 10, 6)
	
	// Correct wrong sector in the original data 
		
	gen sector2 = sector if inlist(sector, "c", "e", "u")
	egen nvals = nvals(sector2), by(GEO_long year tax concept)
	// If nvals == 2, check, because it means we have inconsistent information between old (transcribed) and new data
		
	// Correct again for the difference in sectors between old and new data
	sort GEO year varcode
	
	drop sector tax concept sector2 nvals
	
	/// Now look at inconsistencies between old and new data (_merge = 3 but different values)
	tab GEO_l if _m == 3 & round(value, 0.01) != round(value_og, 0.01)
	*bro if _m == 3 & round(value, 0.01) != round(value_og, 0.01) 
		
	// Chile has slightly different values due to different ATU->CLP conversion
	
	/// Adjust the two data versions (v1 vs v1_2)	
	foreach var in value source longname source_legend note {
		if "`var'" == "value" gen `var'_f = . 	
			else gen `var'_f = ""
		
		replace `var'_f = `var'_og if _m == 1 
		replace `var'_f = `var'    if _m == 2 
		replace `var'_f = `var'	   if _m == 3 
		replace `var'_f = `var'_og if GEO == "PL" & year > 2005 & _m ==1 & inlist(substr(varcode, 10, 6), "revenu", "prorev", "revgdp")
		replace `var'_f = `var' if GEO == "PL" & year > 2005 & _m ==1 & !inlist(substr(varcode, 10, 6), "revenu", "prorev", "revgdp")
			
			foreach c in CY CZ {
				replace `var'_f = `var'_og if _m == 3 & GEO == "`c'"
			}
		} 

		drop *_og value source longname source_legend note
		rename *_f *
		drop _m 
		drop if value == .
	
///// Prepare intermediate version for data check including gift tax
	keep GEO GEO_long year value percentile varcode source longname note
	
	// We need to get rid of years before the first one
	gen tax = substr(varcode, 3, 1)
	gen variable = substr(varcode, 10, 6)

	bys GEO tax variable: egen max = max(value)
	sort GEO year varcode
	gen maxfirst = max if variable == "firsty" 
	bys GEO tax: ereplace maxfirst = min(maxfirst)
	sort GEO year varcode
	drop if year < maxfirst & maxfirst != .
	drop maxfirst tax variable max
	
	qui save "$intfile/eigt_data_coverage.dta", replace
	
********************************************************************************			
// Append regional warehouse 
	
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
	
	*label define labels -999 "Missing" -998 "_na" -997 "_and_over"
	label values value labels, nofix
	
	drop if substr(varcode, 10, 6) == "curren" // not needed anymore, in supplementary

	// Check non-ascii characters // 
	gen nonascii_chars = ustrregexra(note, "[\u0020-\u007E]", "")

	* Replace non-ascii with ascii-equivalent 
	replace note = subinstr(note, "€", "EUR", .) 
	replace note = subinstr(note, "–", "-", .)
	replace note = subinstr(note, "——", "-", .)
	replace note = subinstr(note, "…", ".", .)

	gen nonascii_chars2 = ustrregexra(note, "[\u0020-\u007E]", "")

	// For residual cases of non-ascii symbols, we drop them (mostly quotes "")
	replace note = ustrregexra(note, "[^\u0020-\u007E]", "")
	gen nonascii_chars3 = ustrregexra(note, "[\u0020-\u007E]", "")
	drop nonascii*
	
	// Export
	qui save "$output/eigt_ready.dta", replace
	qui export delimited using "$output/eigt_ready.csv", replace nolabel
	
	
** Create the metadata EIG 
	keep varcode percentile longname //allow only one varcode-percentile-metadata association 
	rename longname metadata 
	duplicates drop  
	duplicates tag varcode percentile, gen(dup) 
	bysort varcode percentile: gen sumdup = sum(dup)
	qui keep if sumdup == 0 | sumdup == 1 
	qui drop dup sumdup 
	
	order varcode percentile metadata 

	qui export delimited using "$dir/output/metadata/metadata_eigt.csv", nolabel replace  
}
