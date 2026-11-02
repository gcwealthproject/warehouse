
***************

import excel "$dofile\New_structure\currency_information.xlsx", sheet("LCU_WID2023") firstrow clear
rename GEO country
merge 1:m country using "C:\Users\fsubioli\Dropbox\gcwealth\output\databases\supplementary_variables\supplementary_var_28sep2023.dta"
drop if LCU_wid==""
drop if xlcusx==.
duplicates drop
keep country LCU_wid unitlabel year xlcusx

replace LCU_wid="" if LCU == "USD" & country == "ZW"
replace LCU_wid="ZWL" if LCU == "USD" & country == "ZW"
replace LCU_wid="ZWL" if LCU == "" & country == "ZW"
replace unitlabel ="" if LCU == "USD" & country == "ZW"
replace unitlabel ="" if country == "ZW"
sort LCU year
collapse (p50) xlcusx, by(LCU_wid unitlabel year)

*******************



qui wid, indicators(ntaxma ntaxto xlcusp xlceup xlcyup xlcusx xlceux xlcyux inyixx mnninc mgdpro mpweal) ages(999) pop(i) meta clear

keep country year unit unitlabel variable value // WID: Market exchange rate with USD
duplicates drop

gen curre = unit if variable == "mnninc999i"
encode country, gen(geo)
xfill curre unitlabel, i(geo)

keep if variable == "xlcusx999i"
rename value conv_rate_usd 
label var conv_rate_usd "Conversion rate LCU to USD"

keep year conv curre unitlab
duplicates drop
sort curre year
drop if curre == ""

rename curre currency
merge m:1 currency using "handmade_tables/currencies/ISO4217codes_conversion", keep(matched master)
rename numericcode curre
labmask curre, values(currency)
drop currency _m
order curre unitlabel year conv
	
xtset curre year

bro if curre == curre[_n-1] & year == year[_n-1]