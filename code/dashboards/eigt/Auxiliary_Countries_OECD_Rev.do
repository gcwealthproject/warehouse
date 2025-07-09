
// Last update: April 2025

**** 4110 (household recurrent taxes on immovable property Revenues) **********
**** 4210 (individual recurrent taxes on net wealth Revenues) **********
**** 4300 (EIG Revenues) **********
**** 4310 (EI Revenues) **********
**** 4320 (G Revenues) **********
**** 1100 (taxes on income, profits, and capital gains on individuals) ****
**** 1110 (taxes on income & profits on individuals) ****
**** 1120 (taxes on capital gains on individuals) **** 

	clear

//---- csv file with tax revenues for OECD countries (1965-2023)

// Link for the right filters for the download from the website: https://data-explorer.oecd.org/vis?fs[0]=Topic%2C1%7CTaxation%23TAX%23%7CGlobal%20tax%20revenues%23TAX_GTR%23&pg=0&fc=Topic&bp=true&snb=153&isAvailabilityDisabled=false&df[ds]=dsDisseminateFinalDMZ&df[id]=DSD_REV_COMP_OECD%40DF_RSOECD&df[ag]=OECD.CTP.TPS&df[vs]=1.1&dq=GBR%2BUSA%2BTUR%2BCHE%2BSWE%2BESP%2BSVK%2BSVN%2BPRT%2BNOR%2BPOL%2BNZL%2BMEX%2BNLD%2BLUX%2BLTU%2BKOR%2BLVA%2BJPN%2BITA%2BISR%2BISL%2BIRL%2BHUN%2BGRC%2BDEU%2BFRA%2BFIN%2BEST%2BDNK%2BCZE%2BCOL%2BCRI%2BCHL%2BCAN%2BBEL%2BAUS%2BAUT..S1313%2BS1312%2BS1311%2BS13.T_4110%2BT_4310%2BT_4320%2BT_4300%2BT_4210..PT_OTR_REV_CAT%2BXDC%2BUSD%2BPT_B1GQ.A&pd=1965%2C2023&to[TIME_PERIOD]=false&vw=ov
// Last updated: January 16, 2025 at 1:13:47 PM

//---- csv file with tax revenues for non-OECD countries (1990-2022)

// Link for the right filters for the download from the website: https://data-explorer.oecd.org/vis?fs[0]=Topic%2C1%7CTaxation%23TAX%23%7CGlobal%20tax%20revenues%23TAX_GTR%23&pg=0&fc=Topic&bp=true&snb=153&isAvailabilityDisabled=false&df[ds]=dsDisseminateFinalDMZ&df[id]=DSD_REV_COMP_GLOBAL%40DF_RSGLOBAL&df[ag]=OECD.CTP.TPS&df[vs]=1.1&dq=ZMB%2BVNM%2BVEN%2BVUT%2BURY%2BUGA%2BUKR%2BTUN%2BTTO%2BTGO%2BTKL%2BTLS%2BTHA%2BLKA%2BZAF%2BSLB%2BSOM%2BSLE%2BSGP%2BSYC%2BSEN%2BWSM%2BLCA%2BRWA%2BROU%2BPHL%2BPER%2BPRY%2BPNG%2BPAN%2BPAK%2BNGA%2BNIC%2BNER%2BNRU%2BNAM%2BMOZ%2BMAR%2BMNG%2BMUS%2BMRT%2BMHL%2BMLT%2BMLI%2BMDV%2BMYS%2BMWI%2BLIE%2BMDG%2BLAO%2BLSO%2BKGZ%2BKIR%2BKEN%2BKAZ%2BJAM%2BIDN%2BHKG%2BHND%2BGUY%2BGIN%2BGHA%2BGTM%2BGEO%2BGAB%2BFJI%2BSWZ%2BGNQ%2BSLV%2BEGY%2BECU%2BCOD%2BDOM%2BCUB%2BHRV%2BCIV%2BCOK%2BCHN%2BCOG%2BTCD%2BCMR%2BKHM%2BBFA%2BCPV%2BBGR%2BBRA%2BBWA%2BBOL%2BBTN%2BBLZ%2BBGD%2BBRB%2BBHS%2BARM%2BAZE%2BARG%2BATG..S1313%2BS1312%2BS1311%2BS13.T_4320%2BT_4310%2BT_4300%2BT_4210%2BT_4110..PT_OTR_REV_CAT%2BUSD%2BXDC%2BPT_B1GQ.A&pd=1990%2C2022&to[TIME_PERIOD]=false
// Last updated: December 20, 2024 at 4:30:14 PM

foreach dataset in oecd nonoecd {
	
	*--- Import ---*
		
		import delimited "$intfile\OECD_sourcefiles\OECD_taxrev_`dataset'_14april25.csv", clear

		drop structure* action measure v8 ctry_specific_revenue countryspecificrevenuecategory unit_measure freq frequencyofobservation timeperiod observationvalue obs_status observationstatus revenuecode standard_revenue v30 decimals sector revenue_code

		replace currency = "" if currency == "_Z" // not applicable

		gen double value = obs_value*(10^unit_mult)
		drop obs
		drop unit_ unitm

	*--- Reshape ---*

		gen var = "revenu" if unitofmeasure == "National currency"
		replace var = "prorev" if unitofmeasure == "Percentage of revenues in the same revenue category"
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
		replace tax = "estate & inheritance" if revenuecategory == "Estate and inheritance taxes"
		replace tax = "gift" if revenuecategory == "Gift taxes"
		replace tax = "income, profits & capital gains" if revenuecategory == "Taxes on income, profits and capital gains of individuals" 
		replace tax = "capital gains" if revenuecategory == "Taxes on capital gains of individuals" 
		replace tax = "income & profits" if revenuecategory == "Taxes on income and profits of individuals"

		drop revenuecategory
		
		rename value* *
		rename v32 currency_name
		
	*--- Attach 2-digit country codes and country names ---*

		rename ref_area GEO3
		preserve 
			qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
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

		tempfile `dataset'
		save "``dataset''", replace 
}

clear
append using "`oecd'"
append using "`nonoecd'"

*--- Separate currency and save ---*

	qui: count if curren == ""
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' missing Currency"
		tab GEO_long if curren == ""
	}
	
	
	preserve 
		keep GEO year curren
		duplicates drop 
		save "$intfile/eigt_oecdrev_currency_$oecdver.dta", replace
	restore 		
	drop curren*
	save "$intfile/eigt_oecdrev_data_$oecdver.dta", replace
