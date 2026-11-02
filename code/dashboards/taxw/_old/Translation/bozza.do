
// Revenue data, transfer tax, adding variables for bracket 0
	use "$intfile/eigt_taxsched_all_transformed.dta", clear
	keep if bracket == 0
	keep GEO GEO_long year tax statu topra toplb first
	reshape wide statu topra toplb first, i(GEO GEO_long year) j(tax) string
	
	gen statu = max(statuEstate, statuGift, statuInheritance)

	replace firstEstate = 3000 if firstEstate == -999
	replace firstGift = 3000 if firstGift == -999
	replace firstInheritance = 3000 if firstInheritance == -999
	gen first = min(firstEstate, firstGift, firstInheritance)
	replace first = -999 if first == 3000
	
	gen topra = max(topraEstate, topraGift, topraInheritance)

	gen toplb = -999
	replace toplb = toplbEstate if topra == topraEstate
	replace toplb = topraGift if topra == topraGift
	replace toplb = topraInheritance if topra == topraInheritance
	
	drop *Estate *Inher* *Gift
	
	gen typet = -998 // not applicable
	gen exemp = -998 // not applicable
	gen bracket = 0
	gen tax = "Transfer"
	tempfile transf
	save "`transf'", replace 

// Revenue data, Estate & Inheritance tax, adding variables for bracket 0
	use "$intfile/eigt_taxsched_all_transformed.dta", clear
	keep if bracket == 0
	keep if tax != "Gift"
	keep GEO GEO_long year tax statu topra toplb first
	reshape wide statu topra toplb first, i(GEO GEO_long year) j(tax) string
	
	gen statu = max(statuEstate, statuInheritance)

	replace firstEstate = 3000 if firstEstate == -999
	replace firstInheritance = 3000 if firstInheritance == -999
	gen first = min(firstEstate, firstInheritance)
	replace first = -999 if first == 3000
	
	gen topra = max(topraEstate, topraInheritance)

	gen toplb = -999
	replace toplb = toplbEstate if topra == topraEstate
	replace toplb = topraInheritance if topra == topraInheritance
	
	drop *Estate *Inher*
	
	gen typet = -998 // not applicable 
	gen exemp = -998 // not applicable 
	gen bracket = 0
	gen tax = "Estate & Inheritance"
	tempfile EI
	save "`EI'", replace 

// Revenue data, Gift tax, adding variables for bracket 0
	use "$intfile/eigt_taxsched_all_transformed.dta", clear
	keep if bracket == 0
	keep if tax == "Gift"
	keep GEO GEO_long year br tax statu topra toplb first
	
	gen typet = -998 // not applicable 
	gen exemp = -998 // not applicable 
	tempfile gift
	save "`gift'", replace 
	
// Revenue data
	use "$intfile/eigt_revenue_all_transformed.dta", clear
	merge m:1 GEO year tax bracket using "`transf'", keep(master matched)