
// Last update: August 2026

**** 4110 (household recurrent taxes on immovable property Revenues) **********
**** 4210 (individual recurrent taxes on net wealth Revenues) **********
**** 4300 (EIG Revenues) **********
**** 4320 (G Revenues) **********

	clear

/*--	Global Revenue Statistics - Comparative tax revenues, 1990-2024, all countries
	Last updated: June 29, 2026 at 9:23:22 PM

https://data-explorer.oecd.org/vis?fs[0]=Topic,1%7CTaxation%23TAX%23%7CGlobal%20tax%20revenues%23TAX_GTR%23&pg=0&fc=Topic&bp=true&snb=150&df[ds]=dsDisseminateFinalDMZ&df[id]=DSD_REV_COMP_GLOBAL%40DF_RSGLOBAL&df[ag]=OECD.CTP.TPS&dq=AUS%2BAUT%2BBEL%2BCAN%2BCHL%2BCOL%2BCRI%2BCZE%2BDNK%2BEST%2BFIN%2BFRA%2BDEU%2BGRC%2BHUN%2BISL%2BIRL%2BISR%2BITA%2BJPN%2BKOR%2BLVA%2BLTU%2BLUX%2BMEX%2BNLD%2BNZL%2BNOR%2BPOL%2BPRT%2BSVK%2BSVN%2BESP%2BSWE%2BCHE%2BTUR%2BGBR%2BUSA%2BATG%2BARG%2BARM%2BAZE%2BBHS%2BBGD%2BBRB%2BBLZ%2BBTN%2BBOL%2BBWA%2BBRA%2BBGR%2BBFA%2BCPV%2BKHM%2BCMR%2BTCD%2BCHN%2BCOG%2BCOK%2BCIV%2BHRV%2BCUB%2BCOD%2BDOM%2BECU%2BEGY%2BSLV%2BGNQ%2BSWZ%2BFJI%2BGAB%2BGMB%2BGEO%2BGHA%2BGRD%2BGTM%2BGIN%2BGUY%2BHND%2BHKG%2BIDN%2BJAM%2BKAZ%2BKEN%2BKIR%2BKGZ%2BLAO%2BLSO%2BLBR%2BLIE%2BMDG%2BMWI%2BMYS%2BMDV%2BMLI%2BMLT%2BMHL%2BMRT%2BMUS%2BMDA%2BMNG%2BMAR%2BMOZ%2BNAM%2BNRU%2BNIC%2BNER%2BNGA%2BNIU%2BPAK%2BPAN%2BPNG%2BPRY%2BPER%2BPHL%2BROU%2BRWA%2BLCA%2BWSM%2BSEN%2BSYC%2BSLE%2BSGP%2BSLB%2BSOM%2BZAF%2BLKA%2BSUR%2BTHA%2BTLS%2BTGO%2BTKL%2BTON%2BTTO%2BTUN%2BUGA%2BUKR%2BURY%2BVUT%2BVEN%2BVNM%2BZMB..S1311%2BS1312%2BS1313%2BS13._T%2BT_4110%2BT_4210%2BT_4300%2BT_4320..USD%2BXDC%2BPT_B1GQ.A&to[TIME_PERIOD]=false&pd=1990,2024

//-- Revenue Statistics in OECD member countries - Comparative tax revenues (1965-2023)

// Link for the right filters for the download from the website: https://data-explorer.oecd.org/vis?fs[0]=Topic,1%7CTaxation%23TAX%23%7CGlobal%20tax%20revenues%23TAX_GTR%23&pg=0&fc=Topic&bp=true&snb=153&isAvailabilityDisabled=false&df[ds]=dsDisseminateFinalDMZ&df[id]=DSD_REV_COMP_OECD%40DF_RSOECD&df[ag]=OECD.CTP.TPS&df[vs]=1.1&dq=GBR%2BUSA%2BTUR%2BCHE%2BSWE%2BESP%2BSVK%2BSVN%2BPRT%2BNOR%2BPOL%2BNZL%2BMEX%2BNLD%2BLUX%2BLTU%2BKOR%2BLVA%2BJPN%2BITA%2BISR%2BISL%2BIRL%2BHUN%2BGRC%2BDEU%2BFRA%2BFIN%2BEST%2BDNK%2BCZE%2BCOL%2BCRI%2BCHL%2BCAN%2BBEL%2BAUS%2BAUT..S1313%2BS1312%2BS1311%2BS13.T_4110%2BT_4320%2BT_4300%2BT_4210..PT_OTR_REV_CAT%2BXDC%2BUSD%2BPT_B1GQ.A&pd=1965,&to[TIME_PERIOD]=false&vw=ov
// Last updated: November 05, 2025 at 3:37:48 PM

*/

foreach dataset in all oecd {
	
	*--- Import ---*
		
		if "`dataset'" == "all" import delimited "$intfile\OECD_sourcefiles\OECD_taxrev_1990_2024_$oecdver.csv", clear
		else import delimited "$intfile\OECD_sourcefiles\OECD_taxrev_oecd_1965_2023_$oecdver.csv", clear
		
		drop structure* action measure v8 ctry_specific_revenue countryspecificrevenuecategory unit_measure freq frequencyofobservation timeperiod observationvalue obs_status observationstatus revenuecode standard_revenue v30 decimals sector revenue_code

		replace currency = "" if currency == "_Z" // not applicable

		gen double value = obs_value*(10^unit_mult)
		drop obs
		drop unit_ unitm

	*--- Reshape ---*

		gen var = "revenu" if unitofmeasure == "National currency"
		replace var = "revgdp" if unitofmeasure == "Percentage of GDP"
		replace var = "revusd" if unitofmeasure == "US dollar"
		drop unit 

		gen gov = "gen" if institutionalsector == "General government"	
		replace gov = "cen" if institutionalsector == "Central government" // The central government sub-sector includes all governmental departments, offices, establishments and other bodies which are agencies or instruments of the central authority whose competence extends over the whole territory, with the exception of the administration of social security funds. 
		replace gov = "sta" if institutionalsector == "State government" // This sub-sector consists of intermediate units of government exercising a competence at a level below that of central government. At present, federal countries comprise the majority of cases where revenues attributed to intermediate units of government are identified separately. Colombia and Spain are the only two unitary countries in this position. In the remaining unitary countries, regional revenues are included with those of local governments.	
		replace gov = "loc" if institutionalsector == "Local government" // This sub-sector includes all other units of government exercising an independent competence in part of the territory of a country, with the exception of the administration of social security funds. It encompasses various urban and/or rural jurisdictions (e.g., local authorities, municipalities, cities, boroughs, districts). 
		drop institutionalsector
		
		// Replace currency when not applicable for reshaping	
		egen id = group(ref_area)
		replace v32 = "" if v32 =="Not applicable"
		xfill currency v32, i(id)
		drop id

		gen group = var + "_" + gov
		drop gov var
		reshape wide value, i(ref_area referencearea revenuecategory time_period) j(group) string

		gen tax = "immovable property" if revenuecategory == "Recurrent taxes on immovable property of households" // households, recurrent
		replace tax = "net wealth" if revenuecategory == "Recurrent taxes on net wealth of individuals" // individual, recurrent
		replace tax = "estate, inheritance & gift" if revenuecategory == "Estate, inheritance and gift taxes"
		replace tax = "gift" if revenuecategory == "Gift taxes"

		rename value* *
		rename v32 currency_name
		
		preserve 
			keep if revenuecategory == "Total tax revenue"
			keep ref_area time_period revenu*
			drop revenue
			rename revenu* tot*
			tempfile totalrev
			save "`totalrev'", replace
		restore 
		
		drop if revenuecategory == "Total tax revenue"
		merge m:1 ref_area time_period using "`totalrev'", keep(1 3)
		
		drop revenuecategory
		foreach var in cen gen loc sta {
			gen prorev_`var' = revenu_`var' / tot_`var' *100
		}
		drop tot* _merge			
					
	*--- Attach 2-digit country codes and country names ---*

		rename ref_area GEO3
		preserve 
			qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C300) firstrow clear
			rename Country GEO_long
			duplicates drop
			tempfile ccodes 
			save "`ccodes'", replace
		restore	
		qui: merge m:1 GEO3 using "`ccodes'", keep(master matched)
		qui: count if _m == 1
		if (`r(N)' != 0) {
			display as error "`r(N)' unmatched countries in dictionary, dropped"
			tab referencearea if _m == 1
			drop if _m == 1
			drop _m
		}
		else {
			display "All country codes matched in dictionary"
			drop _m
		} 
		drop GEO3 referencearea
		order GEO* time_period currency currency_name tax

		rename (currency time) (curren year)
		order GEO GEO_long year tax curren* revenu* revusd* prorev* revgdp*
		
	*--- Check and modify ---*

		ds prorev* revgdp*
		foreach var in `r(varlist)' {
			qui: sum `var'
			if (`r(max)' > 100) display as error "WARNING: `var' > 100"
			if (`r(min)' < 0) display as error "WARNING: `var' < 0"
			if (`r(max)' < 100 & `r(min)' > 0) display "All prorev and revgdp in range 0-100"
		}
		ds prorev* revgdp*
		foreach var in `r(varlist)' {
			replace `var' = . if `var' < 0
		}
		
		/* Set to -999 the missing	
			ds revenu* revusd* prorev* revgdp* 
			foreach var in `r(varlist)' {
				qui: count if `var' == -999 
				if (`r(N)' == 0) replace `var' = -999 if `var' == .
				else display as error "There are -999 values for `var', cannot replace"
			}*/			
			
		// Labels 

		// Package required, automatic check 
		cap which labvars
		if _rc ssc install labvars
		
		labvars revenu_gen revenu_cen revenu_sta revenu_loc ///
				"Tax Revenues (national currency), General Government level" ///
				"Tax Revenues (national currency), Central Government level" ///
				"Tax Revenues (national currency), State Government level" ///
				"Tax Revenues (national currency), Local Government level" ///
				
		labvars revusd_gen revusd_cen revusd_sta revusd_loc ///
				"Tax Revenues (USD), General Government level" ///
				"Tax Revenues (USD), Central Government level" ///
				"Tax Revenues (USD), State Government level" ///
				"Tax Revenues (USD), Local Government level" ///
				
		labvars prorev_gen prorev_cen prorev_sta prorev_loc ///
				"Tax Revenue % of Total Tax Revenues, General Government level" ///
				"Tax Revenue % of Total Tax Revenues, Central Government level" ///
				"Tax Revenue % of Total Tax Revenues, State Government level" ///
				"Tax Revenue % of Total Tax Revenues, Local Government level" ///
				
		labvars revgdp_gen revgdp_cen revgdp_sta revgdp_loc ///
				"Tax Revenue % of GDP, General Government level" ///
				"Tax Revenue % of GDP, Central Government level" ///
				"Tax Revenue % of GDP, State Government level" ///
				"Tax Revenue % of GDP, Local Government level" ///
		
		// Format
		ds revenu* revusd* 
		foreach var in `r(varlist)' {
			format `var' %20.2f
		}	
		ds prorev* revgdp*
		foreach var in `r(varlist)' {
			format `var' %7.5g
		}	

		if "`dataset'" == "oecd" keep if year < 1990
		tempfile `dataset'
		save "``dataset''", replace 
}

clear
append using "`all'"
append using "`oecd'"

*--- Separate currency and save ---*

	qui: count if curren == ""
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' missing Currency"
		tab GEO_long if curren == ""
	}

sort GEO tax year
	
	preserve 
		keep GEO year curren
		duplicates drop 
		save "$intfile/taxw_oecdrev_currency_$oecdver.dta", replace
	restore 		
	drop curren*
	save "$intfile/taxw_oecdrev_data_$oecdver.dta", replace
