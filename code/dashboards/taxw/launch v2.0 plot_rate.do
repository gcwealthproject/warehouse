**********************************************************************
* AVERAGE TAX RATE FOR A $2M INHERITANCE
**********************************************************************

	graph set window fontface "Arial Bold"

**********************************************************************
* BUILD DATASET
**********************************************************************

	use "C:\Users\franc\Dropbox\gcwealth\raw_data\taxw\taxw_ready.dta", clear
	drop if GEO=="GW" // Only top rate available
	
	drop if substr(GEO,1,3)=="US,"
	keep if year==2023

	gen tax      = substr(varcode,3,1)
	gen kinship  = substr(varcode,4,1)
	gen concept  = substr(varcode,10,6)
	gen bracket  = substr(varcode,17,2)

	keep if inlist(tax,"i","e")
//	keep if inlist(kin,"e","c", "s", "l")

	destring br, replace

	keep GEO* year tax kin br concept value

	reshape wide value, i(GEO year tax kin br) j(concept) string

	keep GEO year tax kin br ///
		 valueadjlbo valueadjmr valueadjubo ///
		 valueexemp valuestatus valuetyptax valuetoprat ///
		 GEO_long

*--------------------------------------------------------------------
* USD PPP conversion
*--------------------------------------------------------------------

	rename GEO country

	merge m:1 country year ///
		using "C:\Users\franc\Dropbox\gcwealth\output\databases\supplementary_variables\supplementary_var_24Jun2026.dta", ///
		keep(1 3) keepusing(xlcusp)

	foreach var in valueadjlbo valueadjubo valueexemp {
		replace `var' = `var'/xlcusp if `var' > 0
	}

	rename country GEO

*--------------------------------------------------------------------
* Estate value
*--------------------------------------------------------------------

	gen estate = 2000000

	gen target = br if ///
		estate <= valueadjubo & ///
		estate >= valueadjlbo & ///
		valueadjubo != .

	ereplace valuetyptax = min(valuetyptax), by(GEO year tax kin)

	replace target = br if ///
		valueadjubo == -997 & ///
		estate >= valueadjlbo & ///
		valuetyptax != 3

	ereplace target = min(target), by(GEO year tax kin)

*--------------------------------------------------------------------
* Tax due
*--------------------------------------------------------------------

	gen topay = 0 if valueexemp == -997

	replace topay = 0 if valuestatus == 0

	replace topay = ///
		(valueadjubo-valueadjlbo)*(valueadjmr/100) ///
		if br < target

	replace topay = ///
		topay + topay[_n-1] ///
		if br < target ///
		& GEO==GEO[_n-1] ///
		& year==year[_n-1] ///
		& tax==tax[_n-1] ///
		& kin==kin[_n-1] ///
		& topay[_n-1] != .

	replace topay = ///
		topay[_n-1] + ///
		(estate-valueadjlbo)*(valueadjmr/100) ///
		if br == target ///
		& GEO==GEO[_n-1] ///
		& year==year[_n-1] ///
		& tax==tax[_n-1] ///
		& kin==kin[_n-1] ///
		& topay[_n-1] != .

	replace topay = ///
		(estate-valueadjlbo)*(valueadjmr/100) ///
		if target == 1

	replace topay = 0 if topay <= 0

	replace topay = ///
		(estate-valueadjlbo)*(valueadjmr/100) ///
		if br <= target & valuetyptax == 3

	rename valuetoprat toprat		
	collapse (max) topay toprat, by(GEO* year tax kin)

	reshape wide topay toprat, i(GEO* year tax) j(kin) string

	collapse (max) topay* toprat*, by(GEO* year)

*--------------------------------------------------------------------
* Fill from everybody where needed
*--------------------------------------------------------------------

	replace topayc = topaye if missing(topayc) & topaye < .
	replace topays = topaye if missing(topays) & topaye < .
	replace topayl = topaye if missing(topayl) & topaye < .
	replace topayn = topaye if missing(topayn) & topaye < .
	
	replace topratc = toprate if missing(topratc) & toprate < .
	replace toprats = toprate if missing(toprats) & toprate < .
	replace topratl = toprate if missing(topratl) & toprate < .
	replace topratn = toprate if missing(topratn) & toprate < .
	

	// Check numbers
	foreach p in c s l n {
		replace topay`p' = topay`p'/2000000*100	
	}

	list GEO_long topayc topays topayl topayn, noobs sep(0)
	count if topayn !=0 // 37
	count if topayn ==0 // 125
	gen diff=topayn-topayc if topayn !=0 & topayn!=topayc
	tabstat diff if topayc!= 0, by(GEO_)
	sum diff if topayc!= 0, det
	
	tempfile taxpay
	save `taxpay'

**********************************************************************
* GRAPH 1: CHILD VS SPOUSE
**********************************************************************

	use `taxpay', clear

	gen label = GEO_long

	replace label = "" ///
		if (topays < 5 & topays != 0 & topayc < 5) ///
		| (topayc < 5)

		gen obs  = 0 in 1
		replace obs = 33 in 2

		gen obs2 = 0 in 1
		replace obs2 = 33 in 2

		twoway ///
		(line obs2 obs, lpatt(shortdash) lcol(gray%50)) ///
		(scatter topayc topays ///
			if !inlist(GEO,"TW","IT","US","ZW","PH") ///
			& !inlist(GEO,"DO","SN","TR","DE","TN","ST"), ///
			msymbol(Dh) ///
			mcolor("46 117 182") ///
			mlabel(label) ///
			mlabcol("46 117 182"%70) ///
			mlabsize(vsmall) ///
			mlabpos(3)) ///
		(scatter topayc topays if GEO=="IT", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(12)) ///
		(scatter topayc topays if GEO=="TW", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(12)) ///
		(scatter topayc topays if GEO=="SN", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(11)) ///
		(scatter topayc topays if GEO=="PH", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(12)) ///
		(scatter topayc topays if GEO=="ZW", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(10)) ///
		(scatter topayc topays if GEO=="TR", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(5)) ///
		(scatter topayc topays if GEO=="DE", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(9)) ///
		(scatter topayc topays if GEO=="TN", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(5)) ///
		(scatter topayc topays if GEO=="US", msymbol(+) mcolor(cranberry) mlabel(GEO_long) mlabcol(cranberry) mlabsize(vsmall) mlabpos(3)), xline(0, lpatt(shortdash) lcol(gray%50)) yline(0, lpatt(shortdash) lcol(gray%50)) ///
		ylab(0(3)33, nogrid labsize(small) format(%3.0fc)) ///
		yscale(range(-1 31) noextend) ///
		xlab(0(5)50, nogrid labsize(small) format(%3.0fc)) ///
		xscale(range(-0.5 50) noextend) ///
		xtitle("SPOUSE", margin(vsmall) color(white) box bexpand bcolor("46 117 182")) ///
		ytitle("CHILD", margin(vsmall) color(white) box bexpand bcolor("46 117 182")) ///
		legend(off) ///
		name(spouse, replace)

**********************************************************************
* GRAPH 2: CHILD VS SIBLING
**********************************************************************

	use `taxpay', clear

	gen label = GEO_long

	replace label = "" ///
		if (topayl < 5 & topayl != 0 & topayc < 5) ///
		| (topayc < 5 & topayl < 10)

		gen obs  = 0 in 1
		replace obs = 33 in 2

		gen obs2 = 0 in 1
		replace obs2 = 33 in 2		

	twoway ///
	(line obs2 obs, lpatt(shortdash) lcol(gray%50)) ///
	(scatter topayc topayl ///
		if !inlist(GEO,"TW","IT","US","ZW","PH") ///
		& !inlist(GEO,"DO","SN","TR","ES","GR","MC","ST","AO"), ///
		msymbol(Dh) ///
		mcolor("46 117 182") ///
		mlabel(label) ///
		mlabcol("46 117 182"%70) ///
		mlabsize(vsmall) ///
		mlabpos(3)) ///
	(scatter topayc topayl if GEO=="IT", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(3)) ///
	(scatter topayc topayl if GEO=="TW", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(12)) ///
	(scatter topayc topayl if GEO=="SN", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(10)) ///
	(scatter topayc topayl if GEO=="PH", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(12)) ///
	(scatter topayc topayl if GEO=="ZW", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(10)) ///
	(scatter topayc topayl if GEO=="TR", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(6)) ///
	(scatter topayc topayl if GEO=="ES", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(10)) ///
	(scatter topayc topayl if GEO=="GR", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(5)) ///
	(scatter topayc topayl if GEO=="MC", msymbol(Dh) mcolor("46 117 182") mlabel(GEO_long) mlabcol("46 117 182"%70) mlabsize(vsmall) mlabpos(6)) ///
	(scatter topayc topayl if GEO=="US", msymbol(+) mcolor(cranberry) mlabel(GEO_long) mlabcol(cranberry) mlabsize(vsmall) mlabpos(6)), xline(0, lpatt(shortdash) lcol(gray%50)) yline(0, lpatt(shortdash) lcol(gray%50)) ///
		ylab(0(3)33, nogrid labsize(small) format(%3.0fc)) ///
		yscale(range(-1 31) noextend) ///
		xlab(0(5)50, nogrid labsize(small) format(%3.0fc)) ///
		xscale(range(-0.5 50) noextend) ///
	xtitle("SIBLING", margin(vsmall) box color(white) bexpand bcolor("46 117 182")) ///
	ytitle("CHILD", margin(vsmall) box color(white) bexpand bcolor("46 117 182")) ///
	legend(off) ///
	name(sibling, replace)

**********************************************************************
* COMBINED FIGURE
**********************************************************************

	graph combine spouse sibling, rows(1) ///
		title("Average Tax Rate (%) in 2023 for a $2,000,000 inheritance", ///
		size(small) box lcolor(black) margin(small)) ///
		subtitle(" ") ///
		imargins(2 2 2 2)
		
graph export "C:\Users\franc\Dropbox\gcwealth\raw_data\taxw\country_sheets\taxw_content_rate.png", as(png) name("Graph") replace
