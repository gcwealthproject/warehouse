******************************
*** EIGT data: currency update
******************************

// Last update: July 2025

// Data used: $intfile/eigt_taxsched_currency.dta, $intfile/eigt_taxsched_data.dta; $hdmade/eigt_currency.xlsx 
// $supvars/supplementary_var_16Jul2024
// $intfile/eigt_oecdrev_currency_14april25.dta, $intfile/eigt_oecdrev_data_14april25.dta 


// Output: $intfile/eigt_taxsched_data_correct.dta, $intfile/eigt_oecdrev_data_14april25_correct.dta  

// Content: convert monetary values to the local currency unit used in WID for conversion

******************** 1. TAX SCHEDULES CONVERSION *******************************

// Prepare WID currency
	use "$supvars/supplementary_var_$supvarver", clear
	xfill LCU_wid
	keep country LCU_wid
	rename country GEO
	duplicates drop
	drop if LCU == "" | substr(GEO, 3, 1) != ""
	tempfile widcurren
	qui save "`widcurren'", replace
	
// Open tax schedule currencies 
	qui use "$intfile/eigt_taxsched_currency.dta", clear

// Attach WID data currencies 
	qui merge m:1 GEO using "`widcurren'" , keep(master matched)
	rename curren taxsch_curren 
	rename LCU_wid wid_currency

// For the cases unmatched with wid, check that the currency is the local 
//currency unit in 2023 so no conversion is needed
	preserve 
		qui import excel "$hmade/eigt_currency.xlsx", sheet("LCU2023") firstrow clear
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
		count if taxsch_curren != nat_currency // 0
	restore
	qui replace wid_currency = taxsch_curre if _m == 1 // GG and JE, GBP

// Check observations for which tax schedule currency != wid_currency	
	display "Countries for which tax schedule currency != wid_currency"
	tab GEO if _m == 3 & taxsch_curre != wid_currency // work on it
	qui gen toupdate = (_m == 3 & taxsch_curre != wid_currency) // flag those cases
	drop _m

// Attach conversion rates to those cases
	preserve 
		qui import excel "$hmade/eigt_currency.xlsx", sheet("conversion") firstrow clear
		rename curren taxsch_curren
		rename nat_currency wid_currency
		tempfile conversion
		qui save "`conversion'", replace
	restore

	qui merge m:1 GEO taxsch_curren wid_currency using "`conversion'" , keep(master matched)
	qui: count if toupdate == 1 & _m == 1 
	if (`r(N)' != 0) {
		display in red "`r(N)' cases unmatched for tax schedule data, check"
		tab GEO if toupdate == 1 & _m == 1
	}	
	drop _m GEO_long

// Set conversion rate to 1 in case no conversion is needed 
	qui replace conv_rate = 1 if !toupdate

// Save conversion rates for tax schedule data
	tempfile taxsch_curren
	qui save "`taxsch_curren'", replace

// Attach conversion rates to tax schedule data 
	qui use "$intfile/eigt_taxsched_data.dta", clear
	qui merge m:1 GEO year using "`taxsch_curren'", nogen 

	labvars taxsch_curren wid_currency toupdate conv_rate fixed_rate ///
			"Original currency from the source" "WID currency" ///
			"Whether currency conversion is needed" "Conversion rate 1 wid_currency" ///
			"Whether the conversion rate is fixed (1) or the market rate is needed (0)"

// Apply conversion rate and prepare for matching
	preserve
		qui use "$supvars/supplementary_var_$supvarver", clear
		keep country year xlcusx // WID: Market exchange rate with USD
		rename country GEO
		tempfile convert
		qui save "`convert'", replace
	restore
	qui merge m:1 GEO year using "`convert'", keep(master match)
	qui: count if _m == 1 & fixed_rate == 0
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases unmatched for tax schedule data in supvar, check"
		tab GEO year if _m == 1 & fixed_rate == 0
	}	
	qui: count if _m == 3 & fixed_rate == 0 & taxsch_curren != "USD" & wid_currency != "USD"
	if (`r(N)' != 0) {
		display in red "`r(N)' cases for which xlcusx cannot be used directly, check"
		tab GEO year if _m == 3 & fixed_rate == 0 & taxsch_curren != "USD" & wid_currency != "USD"
	}	
	qui replace conv_rate = 1/xlcusx if conv_rate == . & fixed_rate == 0 & taxsch_curren == "USD" // from USD to wid
	qui replace conv_rate = xlcusx if conv_rate == . & fixed_rate == 0 & wid_currency == "USD" // to USD from wid
	
// DIVIDE the monetary variables by conv_rate to convert currency
	foreach var in chiexe ad1lbo ad1ubo torac1 {
		replace `var' = `var' / conv_rate if (`var' != -999 &  `var' != -998 & `var' != -997)
	}
	drop toupdate conv_rate fixed_rate xlcusx _merge taxsch_curre
	rename wid_currency curren 
	qui compress

// Make currency numeric 
	preserve 
		qui import excel "$hmade/eigt_currency.xlsx", sheet("codes") firstrow clear
		tempfile codes
		qui save "`codes'", replace
	restore

	qui merge m:1 curren using "`codes'" , keep(master matched)
	qui: count if _m == 1
	if (`r(N)' != 0) {
		display in red "`r(N)' cases of currency numeric code not found, check"
		continue, break
	}		
	rename numericcode curre
	qui labmask curre, values(curren)
	drop curren _m
	rename curre curren

	qui save "$intfile/eigt_taxsched_data_correct", replace
			

******************** 2. OECD REVENUES CONVERSION *******************************

// Open oecd currencies 
	qui use "$intfile/eigt_oecdrev_currency_$oecdver.dta", clear

// Attach WID data currencies 
	qui merge m:1 GEO using "`widcurren'" , keep(master matched)
	rename curren oecd_curren 
	rename LCU_wid wid_currency

	preserve 
		qui import excel "$hmade/eigt_currency.xlsx", sheet("LCU2023") firstrow clear
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
		count if oecd_curren != nat_currency // 0
	restore
	qui replace wid_currency = oecd_curren if _m == 1 // TK, NZD
	

// Check observations for which oecd currency != wid_currency	
	tab GEO if _m == 3 & oecd_curren != wid_currency // work on it
	qui gen toupdate = (_m == 3 & oecd_curren != wid_currency) // flag those cases
	drop _m

// Attach conversion rates to those cases
	preserve 
		qui import excel "$hmade/eigt_currency.xlsx", sheet("conversion") firstrow clear
		rename curren oecd_curren
		rename nat_currency wid_currency
		tempfile conversion
		qui save "`conversion'", replace
	restore

	qui merge m:1 GEO oecd_curren wid_currency using "`conversion'" , keep(master matched)
	qui: count if toupdate == 1 & _m == 1 
	if (`r(N)' != 0) {
		display in red "`r(N)' cases unmatched for OECD data, check"
		tab GEO if toupdate == 1 & _m == 1 // check HR - decide what to do (replace in supplementary would be the ideal)
	}	
	drop _m GEO_long

// Set conversion rate to 1 in case no conversion is needed 
	qui replace conv_rate = 1 if !toupdate

// Save conversion rates for oecd revenues data
	tempfile oecd_curren
	qui save "`oecd_curren'", replace

// Attach conversion rates to oecd revenues data 
	qui use "$intfile/eigt_oecdrev_data_$oecdver.dta", clear
	qui merge m:1 GEO year using "`oecd_curren'", nogen 

	labvars oecd_curren wid_currency toupdate conv_rate fixed_rate ///
			"Original currency from OECD data" "WID currency" ///
			"Whether currency conversion is needed" "Conversion rate 1 wid_currency" ///
			"Whether the conversion rate is fixed (1) or the market rate is needed (0)"

// Apply conversion rate and prepare for matching
	preserve
		qui use "$supvars\supplementary_var_$supvarver", clear
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
		display in red "452 cases checked: Bolivia, Belize, Barbados, solved"
		tab GEO if _m == 3 & fixed_rate == 0 & oecd_curren != "USD" & wid_currency != "USD"
	}	
	qui replace conv_rate = 1/xlcusx if conv_rate == . & fixed_rate == 0 & oecd_curren == "USD" // from USD to wid
	qui replace conv_rate = xlcusx if conv_rate == . & fixed_rate == 0 & wid_currency == "USD" // to USD from wid
	
// 1) Bolivia: OECD data for Bolivia are in Belize Dollar (BZD), need to be BOB 
// 2) Barbados: OECD data for Barbados are in Bolivian Bolivares (BOB), need to be BBD 
// 3) Belize: OECD data for Belize are in Barbados Dollar (BBD), need to BZD
	qui replace xlcusx = . if _m == 3 & fixed_rate == 0 & oecd_curren != "USD" & wid_currency != "USD"

	// BOLIVIA
	// BZD->USD
	preserve
		qui use "$supvars\supplementary_var_$supvarver", clear
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
		qui use "$supvars\supplementary_var_$supvarver", clear
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
	qui replace conv_rate = xlcusx2 if conv_rate == . & fixed_rate == 0 & oecd_curren != "USD" & wid_currency != "USD"
	drop xlcusx2
	
	
	
	// Barbados
	// BOB->USD
	preserve
		qui use "$supvars\supplementary_var_$supvarver", clear
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
		qui use "$supvars\supplementary_var_$supvarver", clear
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
	qui replace conv_rate = xlcusx2 if conv_rate == . & fixed_rate == 0 & oecd_curren != "USD" & wid_currency != "USD"
	drop xlcusx2
	
	
	// Belize
	// BBD->USD
	preserve
		qui use "$supvars\supplementary_var_$supvarver", clear
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
		qui use "$supvars\supplementary_var_$supvarver", clear
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
	qui replace conv_rate = xlcusx2 if conv_rate == . & fixed_rate == 0 & oecd_curren != "USD" & wid_currency != "USD"
	drop xlcusx2
	
	
	
// DIVIDE the monetary variables by conv_rate to convert currency
	foreach var in revenu_gen revenu_loc revenu_sta revusd_cen  {
		qui replace `var' = `var' / conv_rate 
	}
	drop toupdate conv_rate fixed_rate xlcusx oecd_curren
	rename wid_currency curren 

	// Make currency numeric 
	preserve 
		qui import excel "$hmade/eigt_currency.xlsx", sheet("codes") firstrow clear
		tempfile codes
		qui save "`codes'", replace
	restore

	qui merge m:1 curren using "`codes'" , keep(master matched)
	qui: count if _m == 1
	if (`r(N)' != 0) {
		display in red "`r(N)' cases of currency numeric code not found, check"
		continue, break
	}		
	rename numericcode curre
	qui labmask curre, values(curren)
	drop curren _m
	rename curre curren
	order GEO GEO_long year curren
	qui compress
	
	qui save  "$intfile/eigt_oecdrev_data_$oecdver_correct.dta", replace	
	
