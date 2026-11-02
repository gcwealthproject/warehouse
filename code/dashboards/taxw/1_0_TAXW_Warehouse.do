///---------------------------------///
/// Main do file for TAXW data 2026 ///
///---------------------------------///

/// Last update: August 2026

	
////////////////////////////////////////////////////////////////////////////////
/// STEP 1: Country-level data

	display as result "Uploading the updated data..."
	do "$dofile/1_1_Countries_Data.do"
	
	display as result "Merging tax schedule and revenue info..."
	do "$dofile/1_2_Countries_Revenue_Inference.do"		
		
////////////////////////////////////////////////////////////////////////////////
/// STEP 2: Regional-level data	

	display as result "Checking tax schedule data for US states..."
	do "$dofile/1_3_Regions_Taxsch_Check.do"
	
	display as result "Checking revenue data for US states..."
	do "$dofile/1_4_Regions_Revenues_Check.do"
	
	display as result "Translating US states into the correct structure..."
	do "$dofile/1_5_Regions_Translation.do"

////////////////////////////////////////////////////////////////////////////////
/// STEP 3: Warehouse

	display as result "Building warehouse for countries..."
	run "$dofile/1_6_Countries_Warehouse.do"
	
	display as result "Building warehouse for regions..."
	run "$dofile/1_7_Regions_Warehouse.do"
	
	display as result "Merging all together..."
	
	use "$intfile/taxw_countries_new_ready.dta", clear
	
// Final transformation: all IBFD sources cannot be country specific because they cannot be accessed without premium access. Therefore, we set a unique source IBFD https://research.ibfd.org/
	replace source = "IBFD" if substr(source, 1, 4) == "IBFD"
	
// Sources 
// Import legend entries from dictionary - MERGE THE SOURCES FROM DICTIONARY	
	preserve
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("Sources") firstrow case(lower) allstring clear
				keep if section == "Taxes on Wealth" 
			keep legend source citekey
			duplicates drop
			drop if leg == ""
		tempfile sources 
		save "`sources'", replace
	restore
		
	qui merge m:1 source using "`sources'", keep(master matched) 
	tab source if _m == 1 // ALL THE SOURCES THAT WE NEED TO INSERT IN DICTIONARY. Do not need to do it if the only output is "Imputed data" and "Own estimates using OECD_Rev"
		
	// Export the sources-geo that we need to check and add to the dictionary
	preserve 
		keep if _m == 1 
		keep GEO source
		duplicates drop 
		sort GEO 
		save "$intfile/sources_to_add_to_dictionary.dta", replace 
	restore 
			
	drop _m	

	append using "$intfile/taxw_USstates_ready.dta"
	
	compress
	
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
	
// Check non-ascii characters // 
	gen nonascii_chars = ustrregexra(note, "[\u0020-\u007E]", "")

// Replace non-ascii with ascii-equivalent 
	replace note = subinstr(note, "–", "-", .)
	replace note = subinstr(note, "£", "POUND", .)
 	replace note = subinstr(note, "Õ", "O", .)
 	replace note = subinstr(note, "é", "e'", .)
 	replace note = subinstr(note, "è", "e'", .)	
 	replace note = subinstr(note, "ò", "o", .)
 	replace note = subinstr(note, "ô", "o", .)
 	replace note = subinstr(note, "õ", "o", .)
 	replace note = subinstr(note, "ã", "a", .)
 	replace note = subinstr(note, "ç", "c", .)
 	replace note = subinstr(note, "ú", "u", .)
 	replace note = subinstr(note, "ó", "o", .)
 	replace note = subinstr(note, "≤", "<=", .)
 	replace note = subinstr(note, "—", "-", .)
 	replace note = subinstr(note, "——", "-", .)
 	replace note = subinstr(note, "÷", "/", .)
 	replace note = subinstr(note, "×", "x", .)
 	replace note = subinstr(note, "‑", " ", .)
	
// For residual cases of non-ascii symbols, we drop them (mostly quotes "")
	replace note = ustrregexra(note, "[^\u0020-\u007E]", "")
	drop nonascii*
	
	gen first_year = value if substr(varcode, 10, 6) == "firsty"
	gen tax = substr(varcode, 3, 1)
	
	bys GEO tax: ereplace first_year = min(first_year)
	drop if year < first_year & first_year != .
	drop tax first_year
			
// Export
    replace GEO_l = strtrim(GEO_l)
	compress
	qui save "$output/taxw_ready.dta", replace
	qui export delimited using "$output/taxw_ready.csv", replace nolabel	
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 4: Metadata
	
// Create the metadata TAXW 
	keep varcode percentile longname //allow only one varcode-percentile-metadata association 
	rename longname metadata 
	duplicates drop  
	duplicates tag varcode percentile, gen(dup) 
	bysort varcode percentile: gen sumdup = sum(dup)
	qui keep if sumdup == 0 | sumdup == 1 
	qui drop dup sumdup 
	order varcode percentile metadata 

	// Problem in exporting, solve this way for the moment
	set obs 1724
	replace varcode = "varcode" in 1724
	replace percentile = "percentile" in 1724
	replace metadata = "metadata" in 1724
	gen n = _n
	gsort -n
	drop n
	qui export delimited using "output/metadata/metadata_taxw.csv", novarnames nolabel replace  	
		
	
