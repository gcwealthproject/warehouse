************************************************
*** taxw data: new data adjustmeny for warehouse
************************************************

// Last update: August 2026
// Input data: $intfile/taxw_countries_transformed; $hmade/dictionary.xlsx 
// Output data: $intfile/taxw_countries_new_ready

// Upload data
	use "$intfile/taxw_countries_transformed.dta", clear
	drop taxablevalue

// d2 sector 1st digit for tax  
	replace applies_to = trim(applies_to)
	
	gen d1_a = "t" if tax == "estate, inheritance & gift"
	replace d1_a  = "i" if tax == "inheritance"
	replace d1_a  = "e" if tax == "estate"
	replace d1_a  = "g" if tax == "gift"
	
// d2_sector 2nd digit for "applies_to"
	
	gen d1_b = applies_to
	replace d1_b  = "c" if applies_to == "children"
	replace d1_b = "e" if applies_to == "everybody"
	replace d1_b = "u" if applies_to == "unknown"
	replace d1_b  = "s" if applies_to == "spouse"
	replace d1_b = "l" if applies_to == "siblings"
	replace d1_b = "r" if applies_to == "other relatives"
	replace d1_b = "n" if applies_to == "non relatives"
	replace d1_b = "g" if applies_to == "general"
	
	*drop if d1_b == applies_to
	tab d1_b

	gen d2 = d1_a + d1_b
	qui drop d1_* 
	

// Brackets adjustment for reshape
	qui sum bracket
	local max = `r(max)'
	reshape wide status adjlbo adjubo adjmrt firsty typtax exempt toplbo toprat different_tax homexe bssexe revenu prorev revgdp curren AggSource Legend Source Link note, i(GEO year d2) j(bracket)


// Create concept 
	foreach var in adjlbo adjubo adjmrt status firsty typtax exempt toprat toplbo different_tax homexe bssexe revenu prorev revgdp {
		forvalues i = 0/`max' {
			rename `var'`i' value_`var'`i'
		}
	}
	
	foreach var in Source curren Link note AggSource Legend {
		forvalues i = 1/`max'  {
			drop `var'`i' 
		}
	}
	
	rename (Source0 curren0 Link0 note0 AggSource0 Legend0) (Source curren Link note AggSource Legend)
	
	compress
	ds GEO year d2 Source curren Link note AggSource Legend GEO_long tax applies_to, not 
	foreach var in `r(varlist)' {
			count if `var' != .
			if (`r(N)' == 0) drop `var'
	}
	
	
	// Set the dif tax value to 0 for gift tax in case it is paid at the death
	replace value_different_tax0 = 0 if tax == "gift" & value_status0 == 1 & value_different_tax0 == 1
	
	reshape long value, i(GEO GEO_long year d2 tax applies_to curren) j(concept) string
	format value %30.2f
	drop if value == . 
	sort GEO year d2 concept
	
	
// d3_vartype	
	replace concept = substr(concept, 2, .)
	replace concept = "diftax0" if concept == "different_tax0" 
	
	gen d3 = "cat" if substr(concept, 1, 6) == "curren" | substr(concept, 1, 6) == "status" ///
					| substr(concept, 1, 6) == "typtax" | substr(concept, 1, 6) == "homexe" ///
					| substr(concept, 1, 6) == "bssexe" | substr(concept, 1, 6) == "diftax" 
					
	replace d3 = "rat" if substr(concept, 1, 6) == "adjmrt" | substr(concept, 1, 6) == "toprat"				
	replace d3 = "thr" if substr(concept, 1, 6) == "adjlbo" | substr(concept, 1, 6) == "adjubo" ///
					| substr(concept, 1, 6) == "toplbo" | substr(concept, 1, 6) == "exempt" 					
	
	replace d3 = "per" if substr(concept, 1, 6) == "firsty" 			
	replace d3 = "rto" if substr(concept, 1, 6) == "prorev" | substr(concept, 1, 6) == "revgdp"
	replace d3 = "tot" if substr(concept, 1, 6) == "revenu" 

	
	replace concept = substr(concept, 1, 6) + "0" + substr(concept, 7, .) if strlen(substr(concept, 7, .)) == 1
	replace concept = substr(concept, 1, 6) + "-" + substr(concept, 7, 2)

	gen varcode = d2 + "-" + d3 + "-" + concept

	gen percentile = "p0p100"
	sort GEO GEO_long year varcode 
	keep GEO GEO_long year perc varcode value Source note Link AggSource Legend
	order GEO GEO_long year perc varcode value
	drop if value == -999

	sort GEO year varcode 
	
// Generate vartype

	gen code = substr(varcode, 4,3)
	
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d3_vartype") firstrow case(lower) allstring clear
			keep code label
			rename label vartype
			drop if code == ""
		tempfile d3
		save "`d3'", replace	
	restore
	
	merge m:1 code using "`d3'", keep(master matched)
	qui count if _m==1 
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d3_vartype not found in dictionary"
		tab code if _m==1 
	}	
	drop code _m
			
// Generate varname 

	// Concept
	gen code = substr(varcode, 8, 6)
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d4_concept") firstrow case(lower) allstring clear
			keep code label
			rename label varname
			drop if code == ""
		tempfile d4
		save "`d4'", replace	
	restore
	
	merge m:1 code using "`d4'", keep(master matched)
	qui count if _m==1 & code != "curren"
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d4_concept not found in dictionary"
		tab code if _m==1 & code != "curren" 
	}	
	drop code _m

	
	// Sector

	gen code = substr(varcode, 1, 2)
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d2_sector") firstrow case(lower) allstring clear
			keep code label
			duplicates drop 
			rename label sector
			drop if code == ""
		tempfile d2
		save "`d2'", replace	
	restore
	
	merge m:1 code using "`d2'", keep(master matched)
	qui count if _m==1 
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d4_concept not found in dictionary"
		tab code if _m==1 
	}	
	drop code _m

// Generate longname
	
	// bracket
	gen brac = substr(varcode, -2,2)
			destring brac, replace
			sum brac 
			local max = `r(max)'
			tostring brac, replace

	forvalues i = 1/`max' {
		qui replace brac="`i'th Bracket" if brac=="`i'"
	}
		
	qui replace brac = subinstr(brac,"1th","1st",.)
	qui replace brac = subinstr(brac,"2th","2nd",.)
	qui replace brac = subinstr(brac,"3th","3rd",.)
	qui replace brac = subinstr(brac,"11st","11th",.)
	qui replace brac = subinstr(brac,"12nd","12th",.)
	qui replace brac = subinstr(brac,"13rd","13th",.)
	qui replace brac = "Not Bracket-Specific" if brac=="0"

	gen longname = vartype + "; " +  varname + ";" + " applicable to " + sector + "; " + "(" + brac + ")"
	
	* drop sector
	sort GEO year varcode
		
	drop if value == -999
	
// Save and export eig 
	replace varcode = "x-" + varcode
	sort GEO year varcode
	
// Follow the economic-criteria: set status = 0 if full exemption and lower and upper bounds 
	gen exemption = value if substr(varcode, 10, 6) == "exempt"
	gen status = value if substr(varcode, 10,6) == "status" 
	gen tax = substr(varcode, 3, 1)
	gen applies_to = substr(varcode, 4,1)
	egen flag = min(status), by(GEO year tax applies_to)
	egen flag_ex = min(exemption), by(GEO tax year flag applies_to) 

	replace value = 0 if substr(varcode, 10,6)=="status" & flag == 1 & substr(varcode, 3, 2) != "tg" & substr(varcode, 3, 2) != "gg" & flag_ex == -997	
	replace value = -998 if substr(varcode, 10,6)=="typtax" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3, 2) != "gg" & flag_ex == -997
	replace value = -998 if substr(varcode, 10,6)=="bssexe" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3, 2) != "gg" & flag_ex == -997
	replace value = -998 if substr(varcode, 10,6)=="homexe" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3, 2) != "gg" & flag_ex == -997
	
// Correct notes 
	
	replace note = note + "." if !inlist(substr(trim(note), -1, 1), ".", ";", ":") & note != ""
	
	replace note = note + " We report no" + sector + "because they are fully exempted from tax even if tax is legally levied." if flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3, 2) != "gg" & flag_ex == -997 & note != ""
	replace note = "We report no" + sector + "because they are fully exempted from tax even if tax is legally levied." if flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3, 2) != "gg" & flag_ex == -997 & note == ""

	replace note = note + " Data are imputed through prior and subsequent years information." if note != "" & Source == "Imputed data"
	replace note = "Data are imputed through prior and subsequent years information." if note == "" & Source == "Imputed data"
	
	replace note = subinstr(note, "Nephews and nieces taxed at 1. 5%;", "Nephews and nieces taxed at 1. 5%.", .)
	replace note = subinstr(note, "noGift Tax", "no Gift Tax", .)
	replace note = subinstr(note, "noInheritance Tax", "no Inheritance Tax", .)
	replace note = subinstr(note, "noEstate Tax", "no Estate Tax", .)
	replace note = subinstr(note, "Childrenbecause", "Children because", .)
	replace note = subinstr(note, "Siblingsbecause", "Siblings because", .)
	replace note = subinstr(note, "Spousebecause", "Spouse because", .)
	replace note = subinstr(note, "Other Relativesbecause", "Other Relatives because", .)
	replace note = subinstr(note, "nice ", "niece ", .)
	replace note = subinstr(note, "It inferred", "It is inferred", .)
	replace note = subinstr(note, " .", ".", .)
	replace note = subinstr(note, "ware", "were", .)
	replace note = subinstr(note, "filfilled", "fulfilled", .)
	replace note = subinstr(note, "benifit", "benefit", .)
	replace note = subinstr(note, "orginal", "original", .)
	replace note = subinstr(note, "defination", "definition", .)
	replace note = subinstr(note, "milion", "million", .)
	replace note = subinstr(note, ").", "). ", .)
	replace note = subinstr(note, "the the", "the", .)
	replace note = subinstr(note, "rate rate", "rate", .)
	replace note = subinstr(note, "million million", "million", .)
	replace note = subinstr(note, "There is no information provided for Brunei Darussalam in 2021 guide.", "There is no information provided for Brunei Darussalam in the 2021 guide.", .)
	replace note = subinstr(note, "This schedules applies", "This schedule applies", .)
	replace note = subinstr(note, "The Art.", "Article", .)
	replace note = subinstr(note, "is in act", "is in force", .)

	replace note = subinstr(note, "),", "), ", .)
	replace note = subinstr(note, ");", "); ", .)
	replace note = subinstr(note, ".,", ".", .)
	replace note = subinstr(note, "( ", "(", .)
	replace note = subinstr(note, " )", ")", .)
	replace note = subinstr(note, " €", "EUR", .)
	replace note = subinstr(note, "€ ", "EUR ", .)
	replace note = subinstr(note, "€", "EUR", .)
	replace note = subinstr(note, "%  ", "% ", .) 
	replace note = subinstr(note, " %", "%", .)
	replace note = subinstr(note, "%and", "% and", .)
	replace note = subinstr(note, "  ", " ", .) 
	replace note = subinstr(note, "inheritance /gift", "inheritance/gift", .)
	replace note = subinstr(note, "inhertiances", "inheritances", .)
	replace note = subinstr(note, "recieve", "receive", .)
	replace note = subinstr(note, "recieved", "received", .)
	replace note = subinstr(note, "agrigultural", "agricultural", .)
	replace note = subinstr(note, "folllowing", "following", .)
	replace note = subinstr(note, "It should be noticed", "It should be noted", .)
	
	replace note = trim(note)
	replace note = itrim(note)	
	
	* --- Sentence rewrites (syntax clarity) ---

	replace note = "Before that date, gifts were subject to income tax at a flat rate of 15%. Income received from an inheritance was not explicitly exempt and had to be included in the annual tax return." if strpos(note, "gifts were, however, subject to income tax") > 0

	replace note = "No exemption is reported; therefore, a zero exemption is assumed." if strpos(note, "there is 0 exemption") > 0

	replace note = "It is inferred that widows were also exempt from the legacy tax." if strpos(note, "widows were exempt also from legacy") > 0

	replace note = "The tax ranges from 2% to 6%; therefore, the top rate of 6% is used for spouses and children." if strpos(note, "from 2% to 6%. Hence,") > 0

	replace note = "The tax ranges from 4% to 12%; therefore, the top rate of 12% is used for siblings." if note == "The tax range for siblings is from 4% to 12%. Hence, 12% is used as a top rate."

	replace note = "The tax rates apply to nephews and nieces and range from 6% to 18%." ///
	if strpos(note, "nephew and niece which ranges") > 0

	replace note = "The tax rates apply to cousins and range from 6% to 18%." ///
	if strpos(note, "only for cousins which ranges") > 0

	replace note = "No subsequent law establishes any estate tax." if note == "No subsequent law establish any estate tax."

	replace note = "Gifts made within three years before death are taxed." if note == "Gift made within 3 years before the death are taxed."

	replace note = "No information is provided for Brunei Darussalam in the 2021 guide." ///
if strpos(note, "provided for Brunei") > 0

	replace note = "The source does not specify whether the tax is an inheritance tax or an estate tax." if note == "The source does not specify if it is an inheritance or estate tax."

	replace note = "An Estate Duty Act was still in force in 1982." ///
	if strpos(note, "still in act in 1982") > 0

	replace note = "The inheritance and gift tax ranges from 0% to 60%; therefore, the top rate is 60%." ///
	if strpos(note, "0% to 60%. Hence, 60% is set") > 0

	replace note = "The inheritance and gift tax ranges from 0% to 18%; therefore, the top rate is 18%." ///
	if strpos(note, "0% to 18%. Hence, 18% is set") > 0

	replace note = "The tax ranges from 2% to 6% for spouses and children. For parents, the range is 3% to 9%, and for grandchildren it is 6% to 18%. The top applicable rates are used." if note == "The tax range is from 2% to 6%. Hence, the top rate of 6% is used which is only for the spouse and child. However, for parents the range is 3% to 9%, and for the grandchild the range is 6% to 18%."

	* --- Academic standardization (global phrases) ---

	replace note = subinstr(note, "We report no Gift Tax for", "No gift tax applies to", .)
	replace note = subinstr(note, "We report no Inheritance Tax for", "No inheritance tax applies to", .)
	replace note = subinstr(note, "We report no Estate Tax for", "No estate tax applies to", .)

	replace note = subinstr(note, "because they are fully exempted from tax even if tax is legally levied", "as they are fully exempt despite the tax being legally in force", .)

	* --- Final whitespace cleaning ---

	replace note = trim(note)
	replace note = itrim(note)	
		
	keep GEO* year value percentile varcode Source longname note
	rename Source source
	label var source ""
	label var note ""	
	
	qui save "$intfile/taxw_countries_new_ready.dta", replace


	
	
	
	





