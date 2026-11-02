***************************
*** TAXW data: add new data 
***************************

// Last update: August 2026
	
//------------------	
// TAX SCHEDULE DATA	
//------------------	
// Input: excel files from various sources (handmade); taxw_currency.xlsx; raw_data/wid/supvars_wide_$supvarver.csv
// Output: data_longformat for each country and source; taxw_countries_newdata_transformed 	
	
	//---------------------------	
	// 1) Verify each source file	
	//---------------------------
	
	run "$dofile/taxw_verify.ado" // run the ado file

	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	cap log close 
	log using "$sources/Final_Data_v2.0/logfile_Final_Data.txt", replace text	

	levelsof GEO, local(levels)
    foreach country of local levels {
		cap log close
		qui log using "$sources/Final_Data_v2.0/logfile_Final_Data.txt", append text	
		local filepath "$sources/Final_Data_v2.0/`country'"
			
			if fileexists("`filepath'/Final_`country'.xlsx") {
			display as result "Verifying `country'..."
			if "`country'" != "US" taxw_verify Final_Data_v2.0 `country'
			else taxw_verify Final_Data_v2.0 `country', value(exemption) dummy(taxcredit)		
		}
		cap log close 
	}
	
	//------------------------------------------
	// 2) Import and transform each complete dta	
	//------------------------------------------
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C500) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		
	// Import data 
		local filepath "$sources/Final_Data_v2.0/`country'"
		if fileexists("`filepath'/data_longformat.dta") {
			display as result "Appending `country'..."
			qui use "`filepath'/data_longformat.dta", clear
			drop subnationallevel
			
	// Replicate for years 
		qui {
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to bracket)
			sort group year bracket dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax br
				
		// Replicate for kinship
			qui split(applies_to), parse(,)
			if `c(version)' < 17 local nv = `r(nvars)'
			else local nv = `r(k_new)'
			
			forvalues i = 1/`nv' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `nv'
			local k = `nv'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			sort GEO year applies_to tax bracket dupl
			egen group = group(GEO applies_to tax year)
			replace applies_to = applies_to1 if dupl == 0		
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies_to`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies_to`i' != ""
			}	
			drop applies_to1-applies_to`k' expans dupl group
			keep GEO GEO_long year applies_to tax bracket adjlbo adjubo adjmrt currency status typtax firsty exempt toprat toplbo homexe bssexe taxablevalue different_tax AggSource Legend Source Link note
			tempfile `country'
			save "``country''", replace
			}
		}
	}
	clear
    foreach country of local levels {
		if fileexists("``country''") {
			qui append using "``country''"
		}
	}
	
	qui compress
	sort GEO year tax applies_to bracket
	
	// Check that the top rate is always the marginal rate on the last bracket: if not, check the data!
	
	bys GEO applies tax year (bracket): gen Nrate = adjmrt[_N]
	qui count if Nrate != toprat & br == 0 & Nrate != -999
	if `r(N)' != 0 {
		display as error "ERROR: Top rate != marginal rate on the last bracket"
		continue, break
	}
	
	// Currency checks and conversion

	// For Chile, if monetary variables are reported in ATU, convert to CLP
	preserve 
		keep if GEO == "CL"
		keep GEO year applies_to tax currency
		drop if currency == ""
		gen toconvert = 1 if currency == "ATU" | currency == "UTA"
		drop currency
		duplicates drop 
		tempfile tempor 
		save "`tempor'", replace
	restore
	merge m:1 GEO year applies_to tax using "`tempor'", nogen 
	preserve 
		qui import excel "$hmade/taxw_currency.xlsx", sheet("Chile") firstrow clear		
		keep year avg_UTA 
		gen GEO = "CL"
		duplicates drop
		tempfile tempor 
		save "`tempor'", replace		
	restore
	merge m:1 year GEO using "`tempor'", keep(master matched) nogen
	foreach var in adjlbo adjubo exempt toplbo {
		replace `var' = `var'*avg_UTA if toconvert == 1 & GEO == "CL" & `var' > 0 
	}
	replace currency = "CLP" if currency == "ATU" | currency == "UTA" 
	drop toconvert 
	
	// For Venezuela, if monetary variables are reported in TU, convert to VED
	preserve 
		keep if GEO == "VE"
		keep GEO year applies_to tax currency
		drop if currency == ""
		gen toconvert = 1 if currency == "TU"
		drop currency
		duplicates drop 
		tempfile tempor 
		save "`tempor'", replace
	restore
	merge m:1 GEO year applies_to tax using "`tempor'", nogen 
	preserve 
		qui import excel "$hmade/taxw_currency.xlsx", sheet("Venezuela") firstrow clear		
		keep year TU 
		gen GEO = "VE"
		duplicates drop
		tempfile tempor 
		save "`tempor'", replace		
	restore
	merge m:1 year GEO using "`tempor'", keep(master matched) nogen
	foreach var in adjlbo adjubo exempt toplbo {
		replace `var' = `var'*TU if toconvert == 1 & GEO == "VE" & `var' > 0 
	}
	replace currency = "VEB" if currency == "TU" & year <= 2007
	replace currency = "VEF" if currency == "TU" & year >= 2008 & year <= 2017
	replace currency = "VES" if currency == "TU" & year >= 2018 & year <= 2021
	replace currency = "VED" if currency == "TU" & year >= 2022	
	
	drop toconvert 	
	
// Check currency is the LCU in WID 

// Prepare WID currency
	preserve 
		import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		egen countr = group(country)
		xtset countr year
		xfill lcu_wid
		rename lcu_wid LCU_wid
		keep country LCU_wid
		rename country GEO
		duplicates drop
		drop if LCU == "" | substr(GEO, 3, 1) != ""
		tempfile widcurren
		qui save "`widcurren'", replace
	restore 
	
// Attach WID data currencies 
	qui merge m:1 GEO using "`widcurren'" , keep(master matched) // all matched
	rename curren taxsch_curren 
	rename LCU_wid wid_currency

	egen id = group(GEO year applies_to tax)
	xtset id
	xfill taxsch_curren, i(id)
	drop id
	
// Check observations for which tax schedule currency != wid_currency	
	display "Countries for which tax schedule currency != wid_currency"
	tab GEO if _m == 3 & taxsch_curre != wid_currency & br == 0 // 25 countries
	qui gen toupdate = (_m == 3 & taxsch_curre != wid_currency) // flag those cases
	drop _m

	
// Attach conversion rates to those cases
	preserve 
		qui import excel "$hmade/taxw_currency.xlsx", sheet("conversion") firstrow clear
		rename curren taxsch_curren
		rename nat_currency wid_currency
		tempfile conversion
		qui save "`conversion'", replace
	restore

	preserve 
		qui keep if br == 0
		keep GEO year tax applies_to taxsch_curre wid_currency toupdate
		qui duplicates drop 
		qui merge m:1 GEO taxsch_curren wid_currency using "`conversion'" , keep(master matched)
		qui: count if toupdate == 1 & _m == 1 
		if (`r(N)' != 0) {
			display in red "`r(N)' cases of currencies unmatched, check"
			tab GEO if toupdate == 1 & _m == 1
			tab GEO taxsch_curre if toupdate == 1 & _m == 1			
		}	
		tempfile converted
		qui save "`converted'", replace
	restore
	
		// If some countries are still not matched, go to the conversion sheet of taxw_currency.xlsx to add the conversion rate. For example, Isle of Man in WID is reported with GBP, so add the row with IMP to GBP with 0 fixed conversion rate. 
	
	qui merge m:1 GEO year tax applies_to taxsch_curre wid_currency using "`converted'", nogen
	
// There can still be cases of missing conversion rate if fixed conversion rate is == 0 (e.g., Cuba) and tax-schedule currency != wid currency. We merge with supvar from Wid to get the time-varying conversion rate 
	preserve
		qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		rename country GEO
		tempfile convert
		qui save "`convert'", replace
	restore
	qui merge m:1 GEO year using "`convert'", keep(master match) nogen 
	
	count if conv_rate == . 
	if (`r(N)' != 0) {
			display in red "`r(N)' cases of missing conversion rates"
			tab GEO if conv_rate == .  & toupdate
			// Cuba and Isle of Man 
		}	
	
	
		// Cuba - it is the conversion from USD to CUP 
		replace conv_rate = 1/xlcusx if GEO == "CU" & taxsch_curren == "USD"
	
		// Isle of Man - needs to be converted from IMP to USD and from USD to GBP 
		// IMP->USD
		replace conv_rate = xlcusx if GEO == "IM" & taxsch_curre == "IMP"

		// USD->GBP
		preserve
			qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
			keep country year xlcusx // WID: Market exchange rate with USD
			qui keep if country == "GB" // UK to have the exchange rate GBP -> USD
			rename country GEO
			qui gen taxsch_curren = "IMP" 
			qui gen wid_currency = "GBP"
			replace GEO = "IM" 
			tempfile imp
			qui save "`imp'", replace			
		restore	

		cap drop _m
		merge m:1 GEO year using "`imp'", keep(master matched)
		drop _m 
		qui replace conv_rate = conv_rate*xlcusx if GEO == "IM" & taxsch_curren == "IMP"
				
	
// Set conversion rate to 1 in case no conversion is needed 
	qui replace conv_rate = 1 if !toupdate
	ereplace conv_rate = min(conv_rate), by(GEO year applies_to tax)
	
// DIVIDE the monetary variables by conv_rate to convert currency

	foreach var in exempt adjlbo adjubo toplbo {
		replace `var' = `var' / conv_rate if (`var' != 0 & `var' != -999 &  `var' != -998 & `var' != -997)
	}

	// Check GEO-year with missing conversion rate 
	count if conv_rate == . 
		if (`r(N)' != 0) { 
			display in red "Cases of missing conversion rates"
			tab year GEO if conv_rate == . 
		}
	
	drop toupdate conv_rate fixed_rate taxsch_curre avg_UTA
	rename wid_currency curren 
	qui compress
	replace curren = "" if br != 0
		
// Save
	sort GEO year tax appl br
	drop if year < firsty & firsty != . // Consistency check 
	qui save "$intfile/taxw_countries_newdata_transformed.dta", replace
	
	
	
//-----------------	
// TAX REVENUE DATA	
//-----------------	
// Input: "$intfile/taxw_oecdrev_currency_$oecdver.dta"; taxw_currency.xlsx; raw_data/wid/supvars_wide_$supvarver.csv
// Output: "$intfile/taxw_oecdrev_data_$oecdver_correct.dta"		

// Open oecd currencies 
	qui use "$intfile/taxw_oecdrev_currency_$oecdver.dta", clear

// Prepare WID currency
	preserve 
		import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		egen countr = group(country)
		xtset countr year
		xfill lcu_wid
		rename lcu_wid LCU_wid
		keep country LCU_wid
		rename country GEO
		duplicates drop
		drop if LCU == "" | substr(GEO, 3, 1) != ""
		tempfile widcurren
		qui save "`widcurren'", replace
	restore 
		
// Attach WID data currencies 
	qui merge m:1 GEO using "`widcurren'" , keep(master matched)
	rename curren oecd_curren 
	rename LCU_wid wid_currency

	preserve 
		qui import excel "$hmade/taxw_currency.xlsx", sheet("LCU2023") firstrow clear
		keep GEO nat_
		tempfile currenc
		qui save "`currenc'", replace
	restore
	preserve 
		qui keep if _m==1
		drop _m

		qui merge m:1 GEO using "`currenc'", keep(master matched)
		qui: count if _m == 1 
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' cases unmatched, check"
			tab GEO_long if _m == 1 
		}	
		drop _m
		qui count if oecd_curren != nat_currency
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' cases oecd_curren != nat_currency, check"
			tab GEO if oecd_curren != nat_currency 
		}			
	restore
	replace wid_currency = "GBP" if _m == 1 & GEO == "UK" // UK -> GBP
	
// Check observations for which oecd currency != wid_currency	
	tab GEO if _m == 3 & oecd_curren != wid_currency // work on it
	qui gen toupdate = (_m == 3 & oecd_curren != wid_currency) // flag those cases
	drop _m

// Attach conversion rates to those cases
	preserve 
		qui import excel "$hmade/taxw_currency.xlsx", sheet("conversion") firstrow clear
		rename curren oecd_curren
		rename nat_currency wid_currency
		tempfile conversion
		qui save "`conversion'", replace
	restore

	qui merge m:1 GEO oecd_curren wid_currency using "`conversion'" , keep(master matched)
	qui: count if toupdate == 1 & _m == 1 
	if (`r(N)' != 0) {
		display in red "`r(N)' cases unmatched for OECD data, check"
		tab GEO if toupdate == 1 & _m == 1 // Croatia (HR), still in HRK in WID, and Liberia, USD in WID 
	}	
	drop _m GEO_long

// Set conversion rate to 1 in case no conversion is needed 
	qui replace conv_rate = 1 if !toupdate
	
// Save conversion rates for oecd revenues data
	tempfile oecd_curren
	qui save "`oecd_curren'", replace

// Attach conversion rates to oecd revenues data 
	qui use "$intfile/taxw_oecdrev_data_$oecdver.dta", clear
	qui merge m:1 GEO year using "`oecd_curren'", nogen 

	labvars oecd_curren wid_currency toupdate conv_rate fixed_rate ///
			"Original currency from OECD data" "WID currency" ///
			"Whether currency conversion is needed" "Conversion rate 1 wid_currency" ///
			"Whether the conversion rate is fixed (1) or the market rate is needed (0)"

// Apply conversion rate and prepare for matching
	preserve
		qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		rename country GEO
		tempfile convert
		qui save "`convert'", replace
	restore
	qui merge m:1 GEO year using "`convert'", keep(master match)
	qui: count if _m == 1 & fixed_rate == 0
	if (`r(N)' != 0) {
		display in red "`r(N)' cases unmatched for oecd rev data in supvar, check"
		tab GEO year if _m == 1 & fixed_rate == 0
	}	
	qui: count if _m == 3 & fixed_rate == 0 & oecd_curren != "USD" & wid_currency != "USD"
	if (`r(N)' != 0) {
		display in red "`r(N)' cases for which xlcusx cannot be used directly, check"
		display in red "206 cases checked: Bolivia, Belize, Barbados, solved"
		tab GEO if _m == 3 & fixed_rate == 0 & oecd_curren != "USD" & wid_currency != "USD"
	}
	replace conv_rate = 1/xlcusx if conv_rate == . & fixed_rate == 0 & oecd_curren == "USD" // from USD to wid
	replace conv_rate = xlcusx if conv_rate == . & fixed_rate == 0 & wid_currency == "USD" // to USD from wid
	replace conv_rate = xlcusx if conv_rate == . & GEO == "LR" & wid_currency == "USD" // to USD from wid for Liberia
	
// Set conversion rate for Croatia 
	replace fixed_rate = 1 if GEO == "HR"
	replace conv_rate = 0.13272281 if GEO == "HR" 
	replace oecd_curren = "HRK" if GEO == "HR" & oecd_curren == "EUR"
		
// 1) Bolivia: OECD data for Bolivia are in Belize Dollar (BZD), need to be BOB 
// 2) Barbados: OECD data for Barbados are in Bolivian Bolivares (BOB), need to be BBD 
// 3) Belize: OECD data for Belize are in Barbados Dollar (BBD), need to BZD
	qui replace xlcusx = . if _m == 3 & fixed_rate == 0 & oecd_curren != "USD" & wid_currency != "USD"

	// BOLIVIA
	// BZD->USD
	preserve
		qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		qui keep if country == "BZ" // Belize to have the exchange rate BZD -> USD
		drop country 
		qui gen GEO = "BO"
		rename xlcusx xlcusx2 
		tempfile bolivia1
		qui save "`bolivia1'", replace
	restore
	// USD->BOB
	preserve
		qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		qui keep if country == "BO" // Bolivia to have the exchange rate BOB -> USD
		rename country GEO
		qui merge 1:1 GEO year using "`bolivia1'"
		qui replace xlcusx2 = xlcusx2 / xlcusx // need for BZD -> USD and USD -> BOB
		drop xlcusx _m
		qui gen oecd_curren = "BZD" 
		qui gen wid_currency = "BOB"
		tempfile bolivia2
		qui save "`bolivia2'", replace
	restore	
	cap drop _m
	qui merge m:1 GEO year using "`bolivia2'", keep(master matched)
	drop _m 
	qui replace conv_rate = xlcusx2 if GEO == "BO"
	drop xlcusx2
	
	// Barbados
	// BOB->USD
	preserve
		qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		qui keep if country == "BO" // Bolivia to have the exchange rate BOB -> USD
		drop country 
		qui gen GEO = "BB"
		rename xlcusx xlcusx2 
		tempfile barbados1
		qui save "`barbados1'", replace
	restore
	// USD->BBD
	preserve
		qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		qui keep if country == "BB" // Barbados to have the exchange rate BBD -> USD
		rename country GEO
		qui merge 1:1 GEO year using "`barbados1'"
		qui replace xlcusx2 = xlcusx2 / xlcusx // need for BOB -> USD and USD -> BBD
		drop xlcusx _m
		qui gen oecd_curren = "BOB" 
		qui gen wid_currency = "BBD"
		tempfile barbados2
		qui save "`barbados2'", replace
	restore	
	cap drop _m
	qui merge m:1 GEO year using "`barbados2'", keep(master matched)
	drop _m 
	qui replace conv_rate = xlcusx2 if GEO == "BB"
	drop xlcusx2
	
	// Belize
	// BBD->USD
	preserve
		qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		qui keep if country == "BB" // Barbados to have the exchange rate BBD -> USD
		drop country 
		qui gen GEO = "BZ"
		rename xlcusx xlcusx2 
		tempfile belize1
		qui save "`belize1'", replace
	restore
	// USD->BZD
	preserve
		qui import delimited "raw_data/wid/supvars_wide_$supvarver.csv", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		qui keep if country == "BZ" // Belize to have the exchange rate BZD -> USD
		rename country GEO
		qui merge 1:1 GEO year using "`belize1'"
		qui replace xlcusx2 = xlcusx2 / xlcusx // need for BBD -> USD and USD -> BZD
		drop xlcusx _m
		qui gen oecd_curren = "BBD" 
		qui gen wid_currency = "BZD"
		tempfile belize2
		qui save "`belize2'", replace
	restore	
	cap drop _m
	qui merge m:1 GEO year using "`belize2'", keep(master matched)
	drop _m 
	qui replace conv_rate = xlcusx2 if GEO == "BZ"
	drop xlcusx2

// DIVIDE the monetary variables by conv_rate to convert currency
	foreach var in revenu_gen revenu_loc revenu_sta revusd_cen  {
		qui replace `var' = `var' / conv_rate 
	}
	
	// Check GEO-year with missing conversion rate 
	count if conv_rate == . 
		if (`r(N)' != 0) { 
			display in red "Cases of missing conversion rates"
			tab year GEO if conv_rate == . 
		}
	
	drop toupdate conv_rate fixed_rate xlcusx oecd_curren
	rename wid_currency curren 

	order GEO GEO_long year curren
	qui compress
	
	// For Georgia, years 2002-2003 have positive revenues with no evidence of tax
	foreach var in revenu_cen revenu_gen revenu_loc revenu_sta revusd_cen revusd_gen revusd_loc revusd_sta prorev_cen prorev_gen prorev_loc prorev_sta revgdp_cen revgdp_gen revgdp_loc revgdp_sta {
		replace `var' = 0 if `var' > 0 & `var' < . & GEO == "GE" & tax == "estate, inheritance & gift"
	}
	
	qui save  "$intfile/taxw_oecdrev_data_$oecdver_correct.dta", replace
