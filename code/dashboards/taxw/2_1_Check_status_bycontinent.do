
// Last update: May 2026

	*** automatized user paths
	global username "`c(username)'"
	
	dis "$username" // Displays your user name on your computer
		
	* Francesca
	if "$username" == "fsubioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	if "$username" == "Francesca Subioli" | "$username" == "Francesca" | "$username" == "franc" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	* Luca 
	if "$username" == "lgiangregorio" | "$username" == "lucagiangregorio" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}
	
// Scatterplot by concept with country (y axis) and time (x axis) coverage of the data
// Estate, Inheritance and Gift Tax

// Add continent to EIG data
	use "$dir/raw_data/taxw/country_sheets/data_coverage/world_stata", clear
	drop if GEO == "-99" | name == "Ashmore and Cartier Is." | name == "Indian Ocean Ter."
	tempfile continents
	save "`continents'", replace
	
	use "$intfile\taxw_countries_new_ready.dta", clear // Open warehouse data (no regional)
	merge m:1 GEO using "`continents'", keep(1 3)
	tab GEO_l if _m == 1 // Gibraltar
	replace continent = "Europe" if GEO_l == "Gibraltar"
	replace continent = "South_America" if continent == "South America"
	replace continent = "North_America" if continent == "North America"
	replace continent = "Asia" if GEO_l == "Maldives"
	replace continent = "Africa" if GEO_l == "Mauritius"
	replace continent = "Africa" if GEO_l == "Seychelles"

*============================================*
* PREPARAZIONE DATI - SOLO STATUS            *
*============================================*


replace GEO_l = strtrim(GEO_l)

*----------------------------------*
* FLAG SORGENTI (come nel codice 2)*
*----------------------------------*
foreach tax in e i g {
    gen source_rev_imp_`tax' = 1 if substr(varcode,3,1)=="`tax'" & source=="Own estimates using OECD_Rev"
    gen source_imp_`tax'     = 1 if substr(varcode,3,1)=="`tax'" & source=="Imputed data"
    
    ereplace source_rev_imp_`tax' = max(source_rev_imp_`tax'), by(GEO year)
    ereplace source_imp_`tax'     = max(source_imp_`tax'),     by(GEO year)
}

drop source percentile longname note

*----------------------------------*
* KEEP SOLO VARIABILI UTILI        *
*----------------------------------*
keep if substr(varcode,10,6) == "status" ///
     | substr(varcode,10,6) == "firsty" ///
     | substr(varcode,10,6) == "exempt" ///
     | substr(varcode,10,6) == "diftax"

*----------------------------------*
* GENERAZIONE VARIABILI            *
*----------------------------------*
foreach tax in e i g {

    gen status_`tax' = .
    replace status_`tax' = 1 if substr(varcode,3,1)=="`tax'" & substr(varcode,10,6)=="status" & value==1
    replace status_`tax' = 0 if substr(varcode,3,1)=="`tax'" & substr(varcode,10,6)=="status" & value==0

    gen first_`tax' = value if substr(varcode,3,1)=="`tax'" & substr(varcode,10,6)=="firsty"

    gen exempt_`tax' = value if substr(varcode,3,1)=="`tax'" & substr(varcode,10,6)=="exempt" & value==-997

    gen diftax_`tax' = 1 if substr(varcode,3,1)=="`tax'" & substr(varcode,10,6)=="diftax" & value==1
}

*----------------------------------*
* COLLAPSE PER PAESE-ANNO          *
*----------------------------------*
keep GEO GEO_l year continent status_* first_* exempt_* diftax_* source_*

duplicates drop

collapse (max) status_* diftax_* source_* ///
         (min) first_* exempt_*, ///
         by(GEO GEO_l year continent)

*----------------------------------*
* RESHAPE LONG                     *
*----------------------------------*
reshape long status first exempt diftax source_rev_imp source_imp, ///
    i(GEO GEO_l year continent) j(tax) string

	
*============================================*
* GRAFICI STATUS PER CONTINENTE              *
*============================================*

foreach cont in Africa Asia Europe North_America Oceania South_America {

    foreach tax in e i g {
		replace tax = "`tax'" if tax == "_`tax'"

        if "`tax'" == "i" local taxlab "Inheritance Tax"
        if "`tax'" == "e" local taxlab "Estate Tax"
        if "`tax'" == "g" local taxlab "Gift Tax"

        preserve
            keep if continent=="`cont'" & tax=="`tax'"

            count
            if r(N)==0 {
                restore
                continue
            }

            egen geo_y = group(GEO_l), label
            sort geo_y year

            levelsof year, local(years)
            local nyrs : word count `years'
            if (`nyrs'>40) local nyrs=40

            levelsof geo_y, local(gy)
            local nctry : word count `gy'

            local h = `nctry'*0.22
            if `h'<8 local h=8

            *--------------------------*
            * STILI (dal codice 2)
            *--------------------------*
            local yesstyle   msymbol(o)  msize(vsmall) color(purple)
            local nostyle    msymbol(oh) msize(small)  mlwidth(vthin) color(teal)
            local fullstyle  msymbol(o)  msize(vsmall) mlwidth(vthin) color(teal)
            local firststyle msymbol(dh) msize(medium) color(purple)
            local diffstyle  msymbol(X)  msize(medium) color(teal)
            local revstyle   msymbol(Sh) msize(small)  color(orange)
            local impstyle   msymbol(Sh) msize(small)  color(orange)

            twoway ///
                (scatter geo_y year if year==first, `firststyle') ///
                (scatter geo_y year if status==1, `yesstyle') ///
                (scatter geo_y year if status==0 & exempt != -997, `nostyle') ///
                (scatter geo_y year if status==0 & exempt == -997, `fullstyle') ///
                (scatter geo_y year if status==0 & diftax==1, `diffstyle') ///
                (scatter geo_y year if source_rev_imp==1, `revstyle') ///
                (scatter geo_y year if source_imp==1, `impstyle') ///
            , ///
                ylabel(1(1)`nctry', valuelabel labsize(tiny)) ///
                yscale(reverse noextend) ///
                xlabel(#`nyrs', angle(90) labsize(tiny) grid) ///
                xtick(#`nyrs', grid) ///
                ysize(`h') xsize(20) ///
                xtitle("") ytitle("") ///
                title("`cont' - `taxlab' - Status", size(vsmall)) ///
                legend(order(2 "Yes (Tax exists/Positive revenues)" ///
				             3 "No (No tax/Zero revenues)" ///
							 4 "Yes - fully exempted children" ///
							 5 "No - different tax applicable"  ///
							 1 "Introduction" ///
							 8 "✓ Information available" ///
							 6 "Implied/Imputed data") ///
                       rows(2) size(vsmall) pos(12) region(lcolor(white)))

            cap mkdir "$dir/raw_data/taxw/country_sheets/continents/`cont'"
            graph export "$dir/raw_data/taxw/country_sheets/continents/`cont'/`cont'_`tax'_status.pdf", replace

        restore
    }
}