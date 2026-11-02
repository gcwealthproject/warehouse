

use "$intfile/eigt_revenue_all_transformed.dta", clear

keep if applies_to == "General Government"
keep GEO GEO_long year reve tax

// Generate duplicates for type of tax
gen copy = 2 if tax == "Transfer" 
expand copy, gen(dupl)
drop copy
replace tax = "Inheritance" if tax == "Transfer" & dupl == 0
replace tax = "Estate" if tax == "Transfer" & dupl == 1
drop dupl
gen copy = 2 if tax == "Estate" 
expand copy, gen(dupl)
drop copy
replace tax = "Gift" if dupl == 1
drop dupl
duplicates drop
		
gen copy = 2 if tax == "Estate & Inheritance" 
expand copy, gen(dupl)
drop copy
replace tax = "Inheritance" if tax == "Estate & Inheritance" & dupl == 0
replace tax = "Estate" if tax == "Estate & Inheritance" & dupl == 1
drop dupl

gen statu_imp = 0 if reve == 0
drop reven
duplicates drop
egen stat_imp = min(statu_imp), by(GEO year tax)
drop statu_imp
duplicates drop

tempfile notax
save "`notax'", replace

use "$intfile/eigt_taxsched_all_transformed.dta", clear
keep if br == 0
drop br 
merge m:1 GEO year tax using "`notax'"
bro if _m== 3 & statu != stat_imp & stat_imp == 0



	merge m:1 GEO year bracket tax applies_to using "$intfile/eigt_revenue_all_transformed.dta"

************** in progress ***********
** posso usare le informazioni dei revenue per assegnare lo status = 0 alle 
*** tasse interessate
	preserve
		keep if _m == 2 & reven == 0
		drop rev prrev regdp
		replace bracket = 1
		
		// Generate 0 bracket for bracket-invariant information 
		gen copy = 2 if bracket == 1
		expand copy, gen(dupl)
		drop copy
		replace bracket = 0 if dupl == 1
		drop dupl

		replace applies_to = "" if br == 1
		replace applies_to = "Everybody" if br == 0
		duplicates drop
		replace Source_1 = "" if br == 1

		replace statu = 0  if br == 0	
		replace typet = -998 if br == 0
		replace first = -999  if br == 0
		replace exemp = -998  if br == 0
		replace topra = 0 if br == 0
		replace toplb = 0 if br == 0
		replace adjlb = 0 if br == 1 
		replace adjub = -997 if br == 1 
		replace adjmr = 0 if br == 1 	
		sort GEO year tax br
		
		// Generate duplicates for type of tax
		gen copy = 2 if tax == "Transfer" 
		expand copy, gen(dupl)
		drop copy
		replace tax = "Inheritance" if tax == "Transfer" & dupl == 0
		replace tax = "Estate" if tax == "Transfer" & dupl == 1
		drop dupl
		gen copy = 2 if tax == "Estate" 
		expand copy, gen(dupl)
		drop copy
		replace tax = "Gift" if dupl == 1
		drop dupl	
		duplicates drop
		
		gen copy = 2 if tax == "Estate & Inheritance" 
		expand copy, gen(dupl)
		drop copy
		replace tax = "Inheritance" if tax == "Estate & Inheritance" & dupl == 0
		replace tax = "Estate" if tax == "Estate & Inheritance" & dupl == 1
		drop dupl
		duplicates drop
		drop _m 
		tempfile notax
		save "`notax'", replace
	restore 

	drop _m 
	merge m:1 GEO year tax applies_to using "`notax'"
	drop _m
	