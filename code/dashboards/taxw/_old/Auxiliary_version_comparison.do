// Compare old and new versions 
// Scatterplot with country (y axis) and time (x axis) coverage of the data
// Inheritance and Estate Tax

	clear

// Working directory and paths

	*** automatized user paths
	global username "`c(username)'"
	
	dis "$username" // Displays your user name on your computer
		
	* Manuel
	if "$username" == "manuelstone" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}

	* Francesca
	if "$username" == "fsubioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	if "$username" == "Francesca Subioli" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	* Luca 
	if "$username" == "lgiangregorio"  { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}

	global inputs "$dir/output/databases/dashboards"	
	global intfile "$dir/raw_data/eigt/intermediary_files"
	global supvars "$dir/output/databases/supplementary_variables"
	                   
	cd "$dir"
	
////////////////////////////////////////////////////////////////////////////////
// 1. v1 version 
		
// Add continent to EIG data
	use "$intfile\world_stata", clear
	drop if GEO == "-99" | name == "Ashmore and Cartier Is." | name == "Indian Ocean Ter."
	tempfile continents
	save "`continents'", replace
	
	use "$inputs\eigt_warehouse_v1.dta", clear	
	merge m:1 GEO using "`continents'", keep(1 3)
	drop name
	
	keep if substr(varcode, -2, 2) == "00"
	
// Estate tax 

	gen estate = 1 if substr(varcode, 10, 6) == "esttax" & value_str == "Y"
	replace estate = 0 if substr(varcode, 10, 6) == "esttax" & value_str == "N"

	gen first_e = year if substr(varcode, 10, 6) == "eigfir" & value == 1
			
	gen exempt_e = value if substr(varcode, 10, 6) == "chiexe" & value_str == "_and_over"
	
// Inheritance tax 

	gen inheritance = 1 if substr(varcode, 10, 6) == "inhtax" & value_str == "Y"
	replace inheritance = 0 if substr(varcode, 10, 6) == "inhtax" & value_str == "N"

	gen first_i = year if substr(varcode, 10, 6) == "eigfir" & value == 1

	gen exempt_i = value if substr(varcode, 10, 6) == "chiexe" & value_str == "_and_over"
			
// Generic EIG 			
						
	gen ei = 1 if substr(varcode, 10, 6) == "eigsta" & value_str == "Y"
	replace ei = 0 if substr(varcode, 10, 6) == "eigsta" & value_str == "N"

	gen first_ei = year if substr(varcode, 10, 6) == "eigfir" & value == 1	

	gen exempt_ei = value if substr(varcode, 10, 6) == "chiexe" & value_str == "_and_over"
	
global opt legend(order(1 "First EI Tax" 2 "EI Tax" 3 "No EI Tax" 4 "No EI Tax (full exemption)") rows(1) pos(6) size(small) bmar(zero) region(lcolor(white))) plotreg(lcol(black) lpatt(solid) lalig(outside))
		   
foreach cont in europe asiaoceania america africa {
	
	preserve
			keep if substr(GEO, 1, 3) != "US,"
			if ("`cont'" == "europe") {
				keep if continent == "Europe"
				replace GEO_l = "Bosnia and Herz." if GEO_l == "Bosnia and Herzegovina"		
			}
			else if ("`cont'" == "asiaoceania") {
				keep if continent == "Asia" | continent == "Oceania"
			}
			else if ("`cont'" == "america") {
				keep if continent == "North America" | continent == "South America"
				replace GEO_l = "Ant. and Barb." if GEO_l == "Antigua and Barbuda"
				replace GEO_l = "Trin. and Tobago." if GEO_l == "Trinidad and Tobago"		
			} 
			else {
				keep if continent == "Africa"
				replace GEO_l = "Equat. Guinea" if GEO_l == "Equatorial Guinea"
			}
		
		keep GEO_l year estate inheritance ei first* exempt*
		collapse (min) estate inheritance ei first* exempt*, by(GEO_l year)
		encode GEO_l, gen(country_id)

		tsset country_id year
		fillin country_id year
		xfill GEO_l
		
		egen max = rowtotal(estate inheritance ei)
		egen first = rowmin(first_e first_i first_ei)		
		egen exempt = rowmin(exempt_e exempt_i exempt_ei)		
		
		gen yes = 1 if max >= 1
		replace yes = 0 if max == 0
		replace yes = . if estate == . & inh == . & ei == .

		if ("`cont'" == "europe") {
			tw (scatter country_id year if year == first, msy(dh) msize(medium) col(purple)) ///
			   (scatter country_id year if yes == 1, msy(o) msize(vsmall) col(purple)) ///
			   (scatter country_id year if yes == 0 & exempt != -997, msy(oh) msize(vsmall) mlw(vthin) col(teal)) ///
			   (scatter country_id year if yes == 0 & exempt == -997, msy(o) msize(vsmall) mlw(vthin) col(teal)), ///
			   xtick(1758(5)2023, grid glpattern(solid)) ///
			   ylab(1(1)44, valuelabel labsize(tiny) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) xscale(noextend) ysize(30) xsize(50) xtitle("") ytitle("") ///
			   xlabel(1758(5)2023, angle(90) nogrid labsize(tiny)) $opt ///
			   name(`cont', replace) xline(1800, lcol(gray%70*0.7)) ///
			   xline(1900, lcol(gray%70*0.7)) xline(2000, lcol(gray%70*0.7)) ///
			   text(0.4 1804 "1800", size(tiny) col(gray)) ///
			   text(0.4 1904 "1900", size(tiny) col(gray)) ///
			   text(0.4 2004 "2000", size(tiny) col(gray)) 
		}
		else if ("`cont'" == "asiaoceania") {
			tw (scatter country_id year if year == first, msy(dh) msize(medium) col(purple)) ///
			   (scatter country_id year if yes == 1, msy(o) msize(vsmall) col(purple)) ///
			   (scatter country_id year if yes == 0 & exempt != -997, msy(oh) msize(vsmall) mlw(vthin) col(teal)) ///
			   (scatter country_id year if yes == 0 & exempt == -997, msy(o) msize(vsmall) mlw(vthin) col(teal)), ///
			   xtick(1863(2)2023, grid glpattern(solid)) ///
			   ylab(1(1)49, valuelabel labsize(tiny) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) xscale(noextend) ysize(30) xsize(50) xtitle("") ytitle("") ///
			   xlabel(1863(4)2023, angle(90) nogrid labsize(tiny)) $opt ///
			   name(`cont', replace)  xline(1900, lcol(gray%70*0.7)) ///
			   xline(2000, lcol(gray%70*0.7)) ///
			   text(0.2 1902.5 "1900", size(tiny) col(gray)) ///
			   text(0.2 2002.5 "2000", size(tiny) col(gray)) 			   
		}
		else if ("`cont'" == "america") {
			tw (scatter country_id year if year == first, msy(dh) msize(medium) col(purple)) ///
			   (scatter country_id year if yes == 1, msy(o) msize(vsmall) col(purple)) ///
			   (scatter country_id year if yes == 0 & exempt != -997, msy(oh) msize(vsmall) mlw(vthin) col(teal)) ///
			   (scatter country_id year if yes == 0 & exempt == -997, msy(o) msize(vsmall) mlw(vthin) col(teal)), ///
			   xtick(1793(5)2023, grid glpattern(solid)) ///
			   ylab(1(1)36, valuelabel labsize(tiny) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) xscale(noextend) ysize(30) xsize(50) xtitle("") ytitle("") ///
			   xlabel(1793(5)2023, angle(90) nogrid labsize(tiny)) $opt ///
			   name(`cont', replace) xline(1800, lcol(gray%70*0.7)) ///
			   xline(1900, lcol(gray%70*0.7) ) xline(2000, lcol(gray%70*0.7)) ///
			   text(0.4 1804 "1800", size(tiny) col(gray)) ///
			   text(0.4 1904 "1900", size(tiny) col(gray)) ///
			   text(0.4 2004 "2000", size(tiny) col(gray)) 			   
		} 
		else {
			tw (scatter country_id year if year == first, msy(dh) msize(medium) col(purple)) ///
			   (scatter country_id year if yes == 1, msy(o) msize(vsmall) col(purple)) ///
			   (scatter country_id year if yes == 0 & exempt != -997, msy(oh) msize(vsmall) mlw(vthin) col(teal)) ///
			   (scatter country_id year if yes == 0 & exempt == -997, msy(o) msize(vsmall) mlw(vthin) col(teal)), ///
			   xtick(1929(1)2023, grid glpattern(solid)) ///
			   ylab(1(1)32, valuelabel labsize(tiny) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) xscale(noextend) ysize(30) xsize(50) xtitle("") ytitle("") ///
			   xlabel(1929(2)2023, angle(90) nogrid labsize(tiny)) $opt ///
			   name(`cont', replace) xline(2000, lcol(gray%70*0.7)) ///
			   text(0.4 2001.5 "2000", size(tiny) col(gray)) 		
		}
		
		graph export "$intfile\statusscatter_`cont'_v1.pdf", as(pdf) name("`cont'") replace
	restore 
}	

////////////////////////////////////////////////////////////////////////////////
// 2. v2 version 

// Add continent to EIG data
	use "$intfile\world_stata", clear
	drop if GEO == "-99" | name == "Ashmore and Cartier Is." | name == "Indian Ocean Ter."
	tempfile continents
	save "`continents'", replace
	
	use "raw_data\eigt\eigt_ready.dta", clear	
	merge m:1 GEO using "`continents'", keep(1 3)
	tab GEO_l if _m == 1 // Gibraltar and Tokelau
	replace continent = "Europe" if GEO_l == "Gibraltar"
	replace continent = "Oceania" if GEO_l == "Tokelau"	
	drop name
	
	keep if substr(varcode, -2, 2) == "00"
	
// Estate tax 

	gen estate = 1 if substr(varcode, 3, 1) == "e" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "status" & value == 1
			
	replace estate = 0 if substr(varcode, 3, 1) == "e" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "status" & value == 0
	
	gen first_e = value if substr(varcode, 3, 1) == "e" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "firsty"
			
	gen exempt_e = value if substr(varcode, 3, 1) == "e" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "exempt" & value == -997
	
// Inheritance tax 

	gen inheritance = 1 if substr(varcode, 3, 1) == "i" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "status" & value == 1
			
	replace inheritance = 0 if substr(varcode, 3, 1) == "i" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "status" & value == 0

	gen first_i = value if substr(varcode, 3, 1) == "i" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "firsty"

	gen exempt_i = value if substr(varcode, 3, 1) == "i" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "exempt" & value == -997
			
// Generic EIG 			
						
	gen eig = 1 if substr(varcode, 3, 1) == "t" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "status" & value == 1
			
	replace eig = 0 if substr(varcode, 3, 1) == "t" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "status" & value == 0

	gen first_ei = value if substr(varcode, 3, 1) == "t" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "firsty"

	gen exempt_ei = value if substr(varcode, 3, 1) == "t" & ///
			inlist(substr(varcode, 4, 1), "e", "c", "u") & ///
			substr(varcode, 10, 6) == "exempt" & value == -997		
			
global opt legend(order(1 "First EI Tax" 2 "EI Tax" 3 "No EI Tax" 4 "No EI Tax (full exemption)") rows(1) pos(6) size(small) bmar(zero) region(lcolor(white))) plotreg(lcol(black) lpatt(solid) lalig(outside))
		   
foreach cont in europe asiaoceania america africa USstates {
	
	preserve
		if ("`cont'" == "USstates") {
			keep if substr(GEO, 1, 3) == "US,"
			replace GEO_l = substr(GEO_l, 16, .)
			replace GEO_l = "D.C." if GEO_l == "District of Columbia"				
		} 
		else {
			keep if substr(GEO, 1, 3) != "US,"
			if ("`cont'" == "europe") {
				keep if continent == "Europe"
				replace GEO_l = "Bosnia and Herz." if GEO_l == "Bosnia and Herzegovina"		
			}
			else if ("`cont'" == "asiaoceania") {
				keep if continent == "Asia" | continent == "Oceania"
			}
			else if ("`cont'" == "america") {
				keep if continent == "North America" | continent == "South America"
				replace GEO_l = "Ant. and Barb." if GEO_l == "Antigua and Barbuda"
				replace GEO_l = "Trin. and Tobago." if GEO_l == "Trinidad and Tobago"		
			} 
			else {
				keep if continent == "Africa"
				replace GEO_l = "Equat. Guinea" if GEO_l == "Equatorial Guinea"
			}
		}
		
		keep GEO_l year estate inheritance eig first* exempt*
		collapse (min) estate inheritance eig first* exempt*, by(GEO_l year)
		encode GEO_l, gen(country_id)

		tsset country_id year
		fillin country_id year
		xfill GEO_l
		
		egen max = rowtotal(estate inheritance eig)
		egen first = rowmin(first_e first_i first_ei)		
		egen exempt = rowmin(exempt_e exempt_i exempt_ei)		
		
		gen yes = 1 if max >= 1
		replace yes = 0 if max == 0
		replace yes = . if estate == . & inh == . & eig == .

		if ("`cont'" == "USstates") {
			tw (scatter country_id year if yes == 1, msy(o) msize(medlarge) col(purple)) ///
			   (scatter country_id year if yes == 0, msy(oh) msize(medium) col(teal)), ///
			   xtick(2006(1)2021, grid glpattern(solid)) ytick(1(1)51, grid) ///
			   ylab(1(1)51, valuelabel  labsize(small) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) ysize(10) xsize(6) xtitle("") ytitle("") ///
			   xlabel(2006(1)2021, angle(90) nogrid labsize(small)) ///
			   legend(order(1 "EI Tax" 2 "No EI Tax") ///
			   rows(1) pos(6) size(small) bmar(zero) region(lcolor(white))) ///
			   plotreg(lcol(black) lpatt(solid) lalig(outside)) ///
			   name(`cont', replace) 
		} 
		else if ("`cont'" == "europe") {
			tw (scatter country_id year if year == first, msy(dh) msize(medium) col(purple)) ///
			   (scatter country_id year if yes == 1, msy(o) msize(vsmall) col(purple)) ///
			   (scatter country_id year if yes == 0 & exempt != -997, msy(oh) msize(vsmall) mlw(vthin) col(teal)) ///
			   (scatter country_id year if yes == 0 & exempt == -997, msy(o) msize(vsmall) mlw(vthin) col(teal)), ///
			   xtick(1758(5)2023, grid glpattern(solid)) ///
			   ylab(1(1)45, valuelabel labsize(tiny) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) xscale(noextend) ysize(30) xsize(50) xtitle("") ytitle("") ///
			   xlabel(1758(5)2023, angle(90) nogrid labsize(tiny)) $opt ///
			   name(`cont', replace) xline(1800, lcol(gray%70*0.7)) ///
			   xline(1900, lcol(gray%70*0.7)) xline(2000, lcol(gray%70*0.7)) ///
			   text(0.4 1804 "1800", size(tiny) col(gray)) ///
			   text(0.4 1904 "1900", size(tiny) col(gray)) ///
			   text(0.4 2004 "2000", size(tiny) col(gray)) 
		}
		else if ("`cont'" == "asiaoceania") {
			tw (scatter country_id year if year == first, msy(dh) msize(medium) col(purple)) ///
			   (scatter country_id year if yes == 1, msy(o) msize(vsmall) col(purple)) ///
			   (scatter country_id year if yes == 0 & exempt != -997, msy(oh) msize(vsmall) mlw(vthin) col(teal)) ///
			   (scatter country_id year if yes == 0 & exempt == -997, msy(o) msize(vsmall) mlw(vthin) col(teal)), ///
			   xtick(1863(2)2023, grid glpattern(solid)) ///
			   ylab(1(1)54, valuelabel labsize(tiny) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) xscale(noextend) ysize(30) xsize(50) xtitle("") ytitle("") ///
			   xlabel(1863(4)2023, angle(90) nogrid labsize(tiny)) $opt ///
			   name(`cont', replace)  xline(1900, lcol(gray%70*0.7)) ///
			   xline(2000, lcol(gray%70*0.7)) ///
			   text(0.2 1902.5 "1900", size(tiny) col(gray)) ///
			   text(0.2 2002.5 "2000", size(tiny) col(gray)) 			   
		}
		else if ("`cont'" == "america") {
			tw (scatter country_id year if year == first, msy(dh) msize(medium) col(purple)) ///
			   (scatter country_id year if yes == 1, msy(o) msize(vsmall) col(purple)) ///
			   (scatter country_id year if yes == 0 & exempt != -997, msy(oh) msize(vsmall) mlw(vthin) col(teal)) ///
			   (scatter country_id year if yes == 0 & exempt == -997, msy(o) msize(vsmall) mlw(vthin) col(teal)), ///
			   xtick(1793(5)2023, grid glpattern(solid)) ///
			   ylab(1(1)37, valuelabel labsize(tiny) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) xscale(noextend) ysize(30) xsize(50) xtitle("") ytitle("") ///
			   xlabel(1793(5)2023, angle(90) nogrid labsize(tiny)) $opt ///
			   name(`cont', replace) xline(1800, lcol(gray%70*0.7)) ///
			   xline(1900, lcol(gray%70*0.7) ) xline(2000, lcol(gray%70*0.7)) ///
			   text(0.4 1804 "1800", size(tiny) col(gray)) ///
			   text(0.4 1904 "1900", size(tiny) col(gray)) ///
			   text(0.4 2004 "2000", size(tiny) col(gray)) 			   
		} 
		else {
			tw (scatter country_id year if year == first, msy(dh) msize(medium) col(purple)) ///
			   (scatter country_id year if yes == 1, msy(o) msize(vsmall) col(purple)) ///
			   (scatter country_id year if yes == 0 & exempt != -997, msy(oh) msize(vsmall) mlw(vthin) col(teal)) ///
			   (scatter country_id year if yes == 0 & exempt == -997, msy(o) msize(vsmall) mlw(vthin) col(teal)), ///
			   xtick(1929(1)2023, grid glpattern(solid)) ///
			   ylab(1(1)37, valuelabel labsize(tiny) grid glpattern(solid)) ysc(reverse) ///
			   yscale(noextend) xscale(noextend) ysize(30) xsize(50) xtitle("") ytitle("") ///
			   xlabel(1929(2)2023, angle(90) nogrid labsize(tiny)) $opt ///
			   name(`cont', replace) xline(2000, lcol(gray%70*0.7)) ///
			   text(0.4 2001.5 "2000", size(tiny) col(gray)) 		
		}
		
		graph export "$intfile\statusscatter_`cont'_v2.pdf", as(pdf) name("`cont'") replace
	restore 
}	


