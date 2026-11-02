


////////////////////////////////////////////////////////////////////////////////
// Example Italian tax 1902-1914
/*
taxinput IT inheritance 1902 1914, source(ItalianTaxLaw_1918) status(1) ///
		currency(ITL) type(1) applies_to(1, 2) exemption(300) ///
		lbounds(300, 1000, 50000, 100000, 250000, 500000, 1000000) ///
		ubounds(1000, 50000, 100000, 250000, 500000, 1000000, -2) ///
		mrates(0.8, 1.6, 2, 2.4, 2.8, 3.2, 3.6) note()

// Package required, automatic check 
	cap which labmask
	if _rc ssc install labmask	
*/


clear all
macro drop all

///////////////////////////////////////////
///			MANUAL DATA INPUT			///
///////////////////////////////////////////

	*** General 
	local source        ItalianTaxLaw_1902
	local country       IT
	local currency      ITL

	*** Tax-specific
	local tax           2 // EIG = 0, Estate = 1, Inheritance = 2, Gift = 3
	local status        1 // No = 0, Yes = 1
	local type_tax      1 // Progressive by brackets = 1, Progressive by class = 2, Progressive continue = 3, Flat = 4, Lump-sum = 5
	local first_year    -999

	*** Schedule-specific
	matrix applies_to = 1, 2 // Child = 1, Parent = 2, Spouse = 3, Direct line 2nd degree = 4, Sibling = 5, Collateral line 2nd degree = 6, Other relative = 7, Anybody else = 8
	local year_from     1902
	local year_to       1914
	local exemption     300
	local top_rate      ""
	matrix lbounds =    0, 1000, 50000, 100000, 250000, 500000, 1000000
	matrix ubounds =    1000, 50000, 100000, 250000, 500000, 1000000, -997
	matrix mrates =     0.8, 1.6, 2, 2.4, 2.8, 3.2, 3.6
	local note          ""


///////////////////////////////////////////
///		    	MANIPULATIONS			///
///////////////////////////////////////////

// Top marginal rate 

local cols = colsof(mrates)
local top_rate = mrates[1, `cols']

// Statutory schedule

mat schedule = (lbounds \ ubounds \ mrates)'

// Adjusted schedule 

// Create 1st bracket with exemption
mat first = 0, `exemption', 0

// Adjust the statutory brackets according to the exemption

display "Statutory schedule"
mat list schedule 

local cols = colsof(schedule)
local colls = `cols' -1


// revise, need to shift the schedule (see Manuel's email)
	if (`exemption' == 0) mat adjschedule = schedule // No exemption
	else if (`exemption' >= ubounds[1, `colls']) mat adjschedule = 0, -997, 0 // Full exemption
	else {
		forvalues i = 1/`colls' {
			if (`exemption' <= ubounds[1, `i']) {
				local ii = `i' + 1
				if (`exemption' != ubounds[1, `i']) mat first = first \ `exemption', ubounds[1, `i'], schedule[`i', 3]
				mat adjschedule = first \ schedule[`ii'..., .]
				continue, break
			}
			else continue
		}
	}

display "Adjusted schedule"
mat list adjschedule 

		// Currency conversion here

// Generate row with bracket 0 
mat adjschedule = -998, -998, -998 \ adjschedule

svmat adjschedule
rename adjschedule1 adjlb // Adjusted lower bound
rename adjschedule2 adjub // Adjusted upper bound 
rename adjschedule3 adjmr // Adjusted marginal rate
*format adjlb adjub adjmr %20.0f

gen byte bracket = _n - 1
foreach var in adjlb adjub adjmr {
	replace `var' = . if bracket == 0 
}

gen GEO = "`country'"
gen int year = `year_from'
gen curre = "`currency'"
gen int taxname = `tax'
gen int statu = `status'
gen int typet = `type_tax'
gen int first = `first_year'
gen exemp = `exemption'
gen topra = `top_rate'

// Define variable "applies_to"

forvalues i = 1/8 {
	if (applies_to[1, `i'] == 1) local recip`i' Child 
	if (applies_to[1, `i'] == 2) local recip`i' Parent 
	if (applies_to[1, `i'] == 3) local recip`i' Spouse  
	if (applies_to[1, `i'] == 4) local recip`i' Direct relative II degree
	if (applies_to[1, `i'] == 5) local recip`i' Sibling 
	if (applies_to[1, `i'] == 6) local recip`i' Collateral relative II degree 	
	if (applies_to[1, `i'] == 7) local recip`i' Other relative 
	if (applies_to[1, `i'] == 8) local recip`i' Anybody Else 
	if (applies_to[1, `i'] == -999) local recip`i' General 	
	
	if (`i' == 1) local recipient `recip`i''
	if (`i' != 1 & !missing(`"`recip`i''"')) local recipient `recipient', `recip`i''
}	

gen applies_to = "`recipient'" if bracket == 0

// Replicate for years

tempfile temp
save "`temp'", replace
local year = `year_from' + 1
forvalues y = `year'(1)`year_to' {
	replace year = `y' 
	tempfile `y'
	save "``y''", replace
}
use "`temp'", replace
forvalues y = `year'(1)`year_to' {
	append using "``y''"
}
sort year bracket

// Make currency numeric 
rename curre currency
merge m:1 currency using "C:\Users\fsubioli\Dropbox\gcwealth\handmade_tables\currencies\ISO4217codes_conversion", keep(matched master)
rename numericcode curre
labmask curre, values(currency)
drop currency _m

gen taxnote = "`note'" if bracket == 0
gen source = "`source'" if bracket == 0
order GEO year taxname bracket adjlb adjub adjmr curre statu typet first exemp topra applies_to taxnote source

foreach var in curre statu typet first exemp topra {
	replace `var' = . if bracket != 0 
}

compress

// Define labels 

label define taxname 0 "EIG" 1 "Estate" 2 "Inheritance" 3 "Gift"
label define statu 0 "No" 1 "Yes" -999 "Missing" -998 "_na"
label define typet 1 "Progressive by brackets" 2 "Progressive by classes" 3 "Progressive, continue" 4 "Proportional" 5 "Lump-sum" -999 "Missing" -998 "_na"
label define labels -999 "Missing" -998 "_na" -997 "_and_over"
label define curre -999 "Missing" -998 "_na", add

foreach var in taxname statu typet  {
	label values `var' `var', nofix
}
foreach var in exemp topra adjlb adjub adjmr first {
	label values `var' labels, nofix
}

label var GEO "Country: ISO 2-digit country code"
label var year "Year"
label var source "Source"
label var curre "Currency: ISO4217 national currency code, Jan 2023"
label var taxname "Name: tax definition"
label var statu "Status: whether the tax is levied"
label var typet "Type: type of tax schedule"
label var first "First year: first year a tax is levied"
label var exemp "Exemption threshold"
label var topra "Top marginal rate" 
label var adjlb "Bracket lower bound adjusted for exemption and currency" 
label var adjub "Bracket upper bound adjusted for exemption and currency"
label var adjmr "Marginal tax rate: tax rate applicable to the bracket adjusted for exemption"
label var bracket "Tax bracket number"
label var applies_to "Categories to which the tax schedule applies"
label var taxnote "Notes"

export excel using "C:\Users\fsubioli\Dropbox\gcwealth\code\dashboards\eigt\New_structure\example_4dec2023.xlsx", sheet(data_labels) sheetmodify firstrow(variables)

////////////////////////////////////////
///		   ADJUST FOR WAREHOUSE    	////
////////////////////////////////////////

// Categories of relationship

if ("`recipient'" == "Child")  local short cc // Child only
else if ("`recipient'" == "Child, Parent" | "`recipient'" == "Child, Parent, Direct relative II degree") ///
		local short dd // Direct line
else if ("`recipient'" == "Spouse") local recipient ss // Spouse only
else if ("`recipient'" == "Child, Parent, Spouse" | "`recipient'" == "Child, Parent, Spouse, Direct relative II degree") ///
		local short ds // Direct line and spouse	
else if ("`recipient'" == "Child, Parent, Direct relative II degree, Sibling" | "`recipient'" == "Child, Parent, Direct relative II degree, Sibling, Collateral relative II degree" ///
		| "`recipient'" == "Child, Parent, Spouse, Direct relative II degree, Sibling" | "`recipient'" == "Child, Parent, Spouse, Direct relative II degree, Sibling, Collateral relative II degree") ///
		local short cr // Closed relatives
else if ("`recipient'" == "Child, Parent, Spouse, Direct relative II degree, Sibling, Collateral relative II degree, Other relative" | "`recipient'" == "Child, Parent, Direct relative II degree, Sibling, Collateral relative II degree, Other relative") ///
		local short ar // Any relative
else if ("`recipient'" == "Other relative") ///
		local short dr // Distant relatives
else if ("`recipient'" == "Other relative, Anybody Else") ///
		local short de // Distant relatives and anybody else
else if ("`recipient'" == "Anybody Else") ///
		local short nr // Any non relative
else if ("`recipient'" == "Child, Parent, Spouse, Direct relative II degree, Sibling, Collateral relative II degree, Other relative, Anybody Else" | `status' == 0) ///
		local short ee // Everybody
else if ("`recipient'" == "General") ///
		local short gg // General (no spefici info)
else display in red "Warning: applies_to non typical, check"

// Remove labels 
label drop _all
drop taxnote source applies_to

qui sum bracket
local max `r(max)'
reshape wide adjlb adjub adjmr curre statu typet first exemp topra, i(GEO year taxname) j(bracket) 

foreach var in adjlb adjub adjmr curre statu typet first exemp topra {
	forvalues i = 0/`max' {
		local vars `vars' `var'`i'
	}
}
foreach var in `vars' {
	rename `var' value`var'
}

reshape long value, i(GEO year taxname) j(varcode) string
*format value %15.1f
drop if value == . 
sort year varcode

gen tax = ""
replace tax = "t" if taxname == 0 // Transfer tax, any EIG
replace tax = "e" if taxname == 1 // Estate tax
replace tax = "i" if taxname == 2 // Inheritance tax
replace tax = "g" if taxname == 3 // Gift tax

gen varc1 = substr(varcode, 1, 5)
gen varc2 = substr(varcode, 6, .)
replace varc2 = "0" + varc2 if strlen(varc2) == 1

// Type of variable
gen categ = ""
replace categ = "cat" if (varc1 == "curre" | varc1 == "statu" | varc1 == "typet") 
replace categ = "rat" if (varc1 == "adjmr" | varc1 == "topra")
replace categ = "thr" if (varc1 == "adjlb" | varc1 == "adjub" | varc1 == "exemp" | varc1 == "first")

local abc x-`short'-
gen varc = "`abc'" + categ + "-" + tax + varc1 + "-" + varc2
drop varcode
rename varc varcode

label define labels -999 "Missing" -998 "_na" -997 "_and_over"
label values value labels, nofix

// Sort
gen n = 1 if varcode == "x-ee-cat-istatu-00"
replace n = 2 if varcode == "x-ee-cat-itypet-00"
replace n = 3 if varcode == "x-ee-thr-iexemp-00"
replace n = 4 if varcode == "x-ee-rat-itopra-00"
replace n = 5 if varcode == "x-ee-thr-iadjlb-01"
replace n = 6 if varcode == "x-ee-thr-iadjub-01"
replace n = 7 if varcode == "x-ee-rat-iadjmr-01"

sort GEO year tax n

keep GEO year varcode value
order GEO year varcode value

save "C:\Users\fsubioli\Dropbox\gcwealth\code\dashboards\eigt\New_structure\example_4dec2023_warehouse", replace



