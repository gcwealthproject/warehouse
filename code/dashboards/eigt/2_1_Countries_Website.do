*********************************
*** EIGT data: adjust for website
*********************************

// Author: Francesca
// Last update: July 2025

// Data used: output/eigt_ready.dta
// Output: output/databases/dashboards/eigt_countries_wide_viz.dta for the website

// Prepare data in partially wide form 
	use "$output/eigt_ready.dta", clear
	drop if substr(GEO, 1, 3) == "US,"

	keep GEO year varcode value source* note 
	gen tax = substr(varcode, 3,1)
	gen bracket = substr(varcode, -2, 2)
	destring bracket, replace
	keep if  substr(varcode, 3, 2) == "ec" |  substr(varcode, 3, 2) == "ee" | ///
			 substr(varcode, 3, 2) == "ic" |  substr(varcode, 3, 2) == "ie" | ///
			 substr(varcode, 3, 2) == "gc" |  substr(varcode, 3, 2) == "ge" | ///
			 substr(varcode, 3, 2) == "te" |  substr(varcode, 3, 2) == "tu" | ///
			 substr(varcode, 3, 2) == "tg"
	
	replace varcode = substr(varcode, 10, 6)
	
// Concatenate sources by GEO year to allow the reshape
	preserve 
		keep GEO year source 
		duplicates drop 
		bys GEO year: gen nsources = _n
		reshape wide source, i(GEO year) j(nsources)
		gen source = source1 + "/" + source2
		replace source = substr(source, 1, length(source) - 1) if substr(source, -1, 1) == "/"		
		replace source = substr(source, 1, length(source) - 1) if substr(source, -1, 1) == "/"		
		drop *1 *2 
		tempfile tempor
		save "`tempor'", replace
	restore
	
	drop source*
	merge m:1 GEO year using "`tempor'", nogen

// Concatenate notes by GEO year to allow the reshape
	preserve 
		keep GEO year note 
		duplicates drop 
		bys GEO year: gen nnotes = _n
		reshape wide note, i(GEO year) j(nnotes)
		gen note = note1 + "/" + note2 + "/" + note3 if note1 != ""
		replace note = substr(note, 1, length(note) - 1) if substr(note, -1, 1) == "/"		
		replace note = substr(note, 1, length(note) - 1) if substr(note, -1, 1) == "/"		  
		replace note = substr(note, 1, length(note) - 1) if substr(note, -1, 1) == "/"		
		drop *1 *2 *3
		tempfile tempor1
		save "`tempor1'", replace
	restore
	
	drop source* note*
	merge m:1 GEO year using "`tempor'", nogen
	merge m:1 GEO year using "`tempor1'", nogen
	
// Make note invariant 
	sort GEO year bracket tax
	replace note = note[_n-1] if GEO == GEO[_n-1] & year == year[_n-1] & bracket == bracket[_n-1] & tax == tax[_n-1]

// Reshape
	qui reshape wide value, i(GEO year bracket tax) j(varcode) string
	qui rename (value*) (*)

	egen id = group(GEO year tax)
	xtset id 
	xfill exempt firsty status toplbo toprat typtax source note revenu prorev revgdp, i(id)
	drop id
	
	ds status typtax firsty 
	foreach var in `r(varlist)' {
		format `var' %4.0f
	}
		
	foreach var in adjlbo adjmrt adjubo exempt firsty status toplbo toprat typtax revenu prorev revgdp {
		replace `var' = . if `var' == -999 | `var' == -998 | `var' == -997
	}

	order GEO year tax brac adjlbo adjubo adjmrt exempt firsty status toplbo toprat typtax  revenu prorev revgdp source note
	sort GEO year tax bra
	replace tax = "Estate Tax" if tax == "e"
	replace tax = "Gift Tax" if tax == "g"
	replace tax = "Inheritance Tax" if tax == "i"
	replace tax = "EIG Tax" if tax == "t"
	
qui export delimited "$intfile/eigt_countries_wide_viz.csv", replace  
save "$intfile/eigt_countries_wide_viz.dta", replace
	
	