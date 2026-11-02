*Add supplementary variables to warehouse 

//general settings 
clear all 
run "code/mainstream/auxiliar/all_paths.do"
run "code/mainstream/auxiliar/version_control.do"

////////////////////////////////////////////////////////////////////////////
//You need to chose between wid_update supvars from wid (web) or
//defining the version of the -already- stored data you want to use 
////////////////////////////////////////////////////////////////////////////

*IMPORT POLICAL COLOR DATA 
*SAVE AS TEMPFILE 

global wid_update ${supvar_ver} //defined in version_control.do
*global wid_update "yes" 

//list widvars
local widvars ntaxma ntaxto xlcusp xlceup xlcyup xlcusx /// 
	xlceux xlcyux inyixx mnninc mgdpro mpweal // add unit here for the currency
local popvars npopul npopem

if "$wid_update" == "yes" {
	//download population data 
	qui wid, indicators(`popvars') ages(999 992) pop(i) meta clear 
	preserve 
		qui replace variable = subinstr(variable, "999i", "", .)
		qui replace variable = subinstr(variable, "992i", "", .)
		qui collapse (firstnm) shortname simpledes, by(variable)
		tempfile tfpop 
		qui save `tfpop'
	restore 
	qui keep country variable year value 
	qui reshape wide value, i(year country) j(variable) string
	qui rename value* *
	qui rename npopul992i npopul_adu  
	qui rename *999i *
	tempfile popdf
	qui save `popdf'
	//download other variables 
	wid, indicators(`widvars') ages(999) pop(i) meta clear  
	
	*get currency data 
	preserve 
		qui keep if variable == "mgdpro999i"
		qui keep country year unit 
		local todrop OA OA-MER OB OB-MER OC OC-MER OD OD-MER OE OE-MER OI OI-MER OJ OJ-MER ///
			QB QB-MER QD QD-MER QE QE-MER QF QF-MER QJ QJ-MER QK QK-MER QL QL-MER ///
			QM QM-MER QN QN-MER QO QO-MER QP QP-MER QS QS-MER QT QT-MER QU QU-MER ///
			QV QV-MER QW QW-MER QX QX-MER QY QY-MER WO WO-MER XA XA-MER XB ///
			XB-MER XF XF-MER XL XL-MER XM XM-MER XN XN-MER XR XR-MER XS XS-MER ///
			CN-RU CN-UR
		foreach c of local todrop {
			qui drop if country == "`c'"
		}  
		qui rename unit LCU_wid
		label var LCU_wid "Local currency in WID data ${S_DATE}"
		tempfile tf_curr
		qui save `tf_curr'
	restore
	*something 
	preserve 
		qui replace variable = subinstr(variable, "999i", "", .)
		qui replace variable = subinstr(variable, "992i", "", .)
		qui collapse (firstnm) shortname simpledes, by(variable)
		qui append using `tfpop'
		qui export delimited ///
			"documentation/warehouse_documentation/docs/widvars.csv", ///
			replace 	
		qui export excel using ///
			"handmade_tables/dictionary.xlsx", ///
			sheet("widcodes", replace) firstrow(variables)	
	restore 
	qui keep country variable year value
	local today ${S_DATE}
	local today = subinstr("`today'", " ", "", .)
	//reshape and save 
	qui reshape wide value, i(year country) j(variable) string
	qui rename value* *
	qui rename *999i *
	qui gen nomgdp = mgdpro * inyixx
	qui gen nomnni = mnninc * inyixx
	qui merge 1:1 country year using `popdf', nogen 
	qui merge 1:1 country year using `tf_curr', nogen 
	qui sort country year 
	qui export delimited using ///
		"${supvar_wid_dwld}/supvars_wide_`today'.csv", replace 	
	qui export excel using ///
		"${supvar_wid_dwld}/supvars_wide_`today'.xlsx", ///
		replace sheet("data") firstrow(variables) 
	di as result ///
		"Supplementary variables from wid have been updated successfully " ///
		"today (`today')"
}

else if "$wid_update" != "" {
	di as result ///
		"We are using " wordcount("`widvars'") + wordcount("`popvars'") ///
		" supplementary variables " ///
		"from wid (last wid_update $wid_update): `widvars' `popvars'"	
	qui import excel using ///
		"${supvar_wid_dwld}/supvars_wide_$wid_update.xlsx", ///
		sheet("data") firstrow 	
}

else {
	di as error "please specify the date of download in version_control.do" ///
		"for the suplementary variables you want to use in the " ///
		"following format: DDmmmYYYY. If you want to wid_update the data base" ///
		" uncomment line 18 of the 03c do file"
}

//harmonize country names 
qui rename country GEO 
run $harmonize_ctries 
qui rename GEO country 

*clean 
cap drop percentile 

*export wide
*export in three formats
/* 
qui export excel using "${sv_folder}/supplementary_var_wide.xlsx", ///
	replace sheet("Sheet1") firstrow(variables) 
qui export delimited "${sv_folder}/supplementary_var_wide.csv", replace 	
qui save "${sv_folder}/supplementary_var_wide.dta", replace 	 
*/

*merge with wb and politics 
preserve 
	*merge all 
	merge 1:1 country year using "${sv_folder}/politics/politics_wide.dta", nogen 
	merge 1:1 country year using "${sv_folder}/wb/geo_wide.dta" , nogen 
	
	*export in 3 formats 
	qui export excel using ///
		"${sv_folder}/supplementary_var_$wid_update.xlsx", ///
		replace sheet("Sheet1") firstrow(variables) 
	qui export delimited ///
		"${sv_folder}/supplementary_var_$wid_update.csv", replace 	
	qui save ///
		"${sv_folder}/supplementary_var_$wid_update.dta", replace 	
restore 


*export long format too 
qui drop LCU_wid
qui ds country year, not 
foreach v in `r(varlist)' {
	qui rename `v' value`v'
}
qui reshape long value, i(country year) j(variable) string
qui drop if missing(value)
qui sort country variable year


** Append political and WB supplementary variables 
append using "${sv_folder}/politics/long_politics.dta"
append using "${sv_folder}/wb/geo_long.dta"

*export in three formats 
qui export excel using "${sv_folder}/supplementary_var_long.xlsx", ///
	replace sheet("Sheet1") firstrow(variables) 
qui export delimited "${sv_folder}/supplementary_var_long.csv", replace 	
qui save "${sv_folder}/supplementary_var_long.dta", replace 	
