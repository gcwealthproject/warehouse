***********************************
*** EIGT data: adjust for warehouse
***********************************

// Author: Francesca
// Last update: July 2025
// Data used: $intfile/eigt_USstates_v1_transformed.dta ; $hmade/dictionary.xlsx 
// Data output: $intfile/eigt_USstates_v1_ready





	use "$intfile/eigt_USstates_v1_transformed.dta", clear

// d2 sector 1st digit for tax  
	
	gen d1_a = "t" if tax == "estate, inheritance & gift"
	replace d1_a  = "i" if tax == "inheritance"
	replace d1_a  = "e" if tax == "estate"
	replace d1_a  = "g" if tax == "gift"
	
// d2_sector 2nd digit for "applies_to"
	
	gen d1_b = applies_to
	replace d1_b  = "g" if applies_to == "general"
	replace d1_b  = "c" if applies_to == "children"
	replace d1_b = "e" if applies_to == "everybody"
	replace d1_b = "u" if applies_to == "unknown"

	gen d2 = d1_a + d1_b
	qui drop d1_* 
	
// Save metadata
	preserve 
		keep if br == 0
		keep GeoReg year d2 Source* taxnote
		duplicates drop
		tempfile metadata 
		save "`metadata'", replace
	restore	
	drop Source* applies_to tax taxnote
	
// Remove labels 
	label drop _all

	qui sum bracket
	local max `r(max)'
	reshape wide adjlbo adjubo adjmrt curren status exempt toprat toplbo revenu prorev revgdp typtax, i(GeoReg year d2) j(bracket)

	foreach var in adjlbo adjubo adjmrt curren status exempt toprat toplbo revenu prorev revgdp typtax {
		forvalues i = 0/`max' {
			local vars`var'`i' `var'`i'
			*disp "`vars`var'`i''"
			rename `vars`var'`i'' value`vars`var'`i''
		}
	}

	compress
	ds value*
	foreach var in `r(varlist)' {
		count if `var' != .
		if (`r(N)' == 0) drop `var'
	}
	
// Attach metadata 
	merge 1:1 d2 GeoReg year using "`metadata'", nogen
	
	reshape long value, i(GeoReg year d2) j(concept) string
	format value %30.2f
	drop if value == . 
	sort GeoReg year d2 concept
	
	label define labels -999 "Missing" -998 "_na" -997 "_and_over"
	label values value labels, nofix

// d3_vartype
	
	gen d3 = "cat" if substr(concept, 1, 6) == "curren" | substr(concept, 1, 6) == "status"  ///
					| substr(concept, 1,6) == "typtax"
	replace d3 = "rat" if substr(concept, 1, 6) == "adjmrt" | substr(concept, 1, 6) == "toprat"				
	replace d3 = "thr" if substr(concept, 1, 6) == "adjlbo" | substr(concept, 1, 6) == "adjubo" ///
					| substr(concept, 1, 6) == "toplbo" | substr(concept, 1, 6) == "exempt" 					
	replace d3 = "rto" if substr(concept, 1, 6) == "prorev" | substr(concept, 1, 6) == "revgdp"
	replace d3 = "tot" if substr(concept, 1, 6) == "revenu" 

	
	replace concept = substr(concept, 1, 6) + "0" + substr(concept, 7, .) if strlen(substr(concept, 7, .)) == 1
	replace concept = substr(concept, 1, 6) + "-" + substr(concept, 7, 2)

	gen varcode = "x-" + d2 + "-" + d3 + "-" + concept

	gen percentile = "p0p100"
	sort GeoReg GeoReg_long GEO GEO_long year varcode 
	keep GeoReg GeoReg_long GEO GEO_long year perc varcode value Source* taxnote
	order GeoReg GeoReg_long GEO GEO_long year perc varcode value
	drop if value == -999	

// Sources and notes
	replace varcode = substr(varcode, 3, .)
	
// Import legend entries from dictionary 
	preserve
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("Sources") firstrow case(lower) allstring clear
			keep if section == "Estate, Inheritance, and Gift Taxes" 
			keep legend source citekey
			duplicates drop
			drop if leg == ""
		tempfile sources 
		save "`sources'", replace
	restore
	
	forvalues n=1/5 {
		rename Source_`n' source 
		qui merge m:1 source using "`sources'", keep(master matched) 
		qui count if _m==1 & source != "" 
		if (`r(N)' != 0) {
			display in red "WARNING: `r(N)' cases of sources not found in dictionary"
			tab source if _m==1 & source != "" 
		}
		qui count if _m==3 &  legend == ""
		if (`r(N)' != 0) {
			display in red "WARNING: `r(N)' cases of missing legend in dictionary"
			tab source if _m==3  & legend == ""
		}
		qui count if _m==3 &  citekey == ""
		if (`r(N)' != 0) {
			display in red "WARNING: `r(N)' cases of missing citekey in dictionary"
			tab source if _m==3  & citekey == ""
		}		
		drop _m
		rename legend source_legend`n'
		rename citekey citekey`n'		
		rename source Source_`n'
	}

// Concatenate and clean citekey
	qui egen citekey_concat = concat(citekey*), punct(/)
	qui egen source_legend_concat = concat(source_legend*), punct(/)
	forvalues sn=1/5 {
		rename Source_`sn' sourcekey`sn'
	}
	qui egen source_concat = concat(sourcekey*), punct(/)
	
	foreach var in citekey_concat source_legend_concat source_concat {
		qui replace `var' = subinstr(`var', "////", "", .)
		qui replace `var' = subinstr(`var', "///", "", .)
		qui replace `var' = subinstr(`var', "//", "", .)
		qui replace `var' = subinstr(`var', "/", "", 1) if substr(`var', 1, 1) == "/"
		qui gen ck1 = strreverse(`var')
		qui replace ck1 = subinstr(ck1, "/", "", 1) if substr(ck1, 1, 1) == "/"
		qui replace `var' = strreverse(ck1)
		qui drop ck1		
	}
	qui rename citekey_concat c_citekey 
	qui drop citekey*		
	
	*** list new values of source 
	qui levelsof source_concat, clean local(new_srcs) 
	foreach ns in `new_srcs' {
		di as text " - `ns'"
	}
	*** drop excess sources 
	qui keep GeoReg GeoReg_long GEO GEO_long year percentile varcode value source_concat source_legend_concat c_citekey taxnote
	qui rename source_concat source
	qui rename source_legend_concat source_legend
	qui order GeoReg GeoReg_long GEO GEO_long year percentile varcode value source source_legend c_citekey 


// Generate vartype

	gen code = substr(varcode, 4,3)
	
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d3_vartype") firstrow case(lower) allstring clear
			keep code label
			rename label vartype
			drop if code == ""
		tempfile d3
		save "`d3'", replace	
	restore
	
	merge m:1 code using "`d3'", keep(master matched)
	qui count if _m==1 
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d3_vartype not found in dictionary"
		tab code if _m==1 
	}	
	drop code _m
			
// Generate varname 

	// Concept
	
	gen code = substr(varcode, 8, 6)
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d4_concept") firstrow case(lower) allstring clear
			keep code label
			rename label varname
			drop if code == ""
		tempfile d4
		save "`d4'", replace	
	restore
	
	merge m:1 code using "`d4'", keep(master matched)
	qui count if _m==1 
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d4_concept not found in dictionary"
		tab code if _m==1 
	}	
	drop code _m

	
	// Sector

	gen code = substr(varcode, 1, 2)
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d2_sector") firstrow case(lower) allstring clear
			keep code label
			duplicates drop 
			rename label sector
			drop if code == ""
		tempfile d2
		save "`d2'", replace	
	restore
	
	merge m:1 code using "`d2'", keep(master matched)
	qui count if _m==1 
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d4_concept not found in dictionary"
		tab code if _m==1 
	}	
	drop code _m

// Generate longname
	
	// bracket
	gen brac = substr(varcode, -2,2)
			destring brac, replace
			tostring brac, replace

	forvalues i = 1/30 {
		qui replace brac="`i'th Bracket" if brac=="`i'"
	}
		
	qui replace brac = subinstr(brac,"1th","1st",.)
	qui replace brac = subinstr(brac,"2th","2nd",.)
	qui replace brac = subinstr(brac,"3th","3rd",.)
	qui replace brac = subinstr(brac,"11st","11th",.)
	qui replace brac = subinstr(brac,"12nd","12th",.)
	qui replace brac = subinstr(brac,"13rd","13th",.)
	qui replace brac = "Not Bracket-Specific" if brac=="0"

	gen longname = vartype + "; " +  varname + " applicable to " + sector + "; " + "(" + brac + ")"
	
	* drop sector
		
	sort GeoReg year varcode
		
// Save and export 
	replace varcode = "x-" + varcode

// Check the currency is once per state-year
	preserve 
		keep if substr(varcode, 10, 6) == "curren"
		keep GEO* GeoReg* year varcode value
		replace varcode = "x-tg-cat-curren-00"
		duplicates drop 
		gen source = "ISO4217"
		gen source_legend = "ISO 4217 Currency codes"	
		gen longname = "Categorical Variable; Currency applicable to EIG Tax; (Not Bracket-Specific)"
		gen percentile = "p0p100"
		tempfile curr 
		save "`curr'", replace
	restore
	drop if substr(varcode, 10, 6) == "curren"
	append using "`curr'"
	sort GeoReg year varcode
	
	rename taxnote note
	keep GeoReg* GEO* year value percentile varcode source source_legend longname note
	qui save "$intfile/eigt_USstates_v1_ready.dta", replace


	
	
	
	







