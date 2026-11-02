** ID variables: country Geo geo3 GeoReg year (ID) c // can drop ID

import excel "Dropbox (Hunter College)/THE_GC_WEALTH_PROJECT_website/EIG Taxes/EIGtax_mergeable.xlsx", firstrow allstring clear

*--------------------------------Trim variable names for standardized reference
foreach var of varlist Federal_Effective_Class_I_Lower_ Federal_Effective_Class_I_Upper_ Federal_Effective_Class_I_Tax_on Federal_Effective_Class_I_Statut Statutory_Class_I_Tax_on_Lower_B Statutory_Class_I_Statutory_Marg Conc_InhEst_Tax_Class_I_Exemptio Conc_InhEst_Tax_Tax_on_Lower_Bou Conc_InhEst_Tax_Statutory_Margin Adjusted_Class_I_Tax_on_Lower_Bo Adjusted_Class_I_Statutory_Margi OverFed_Class_I_Tax_on_Lower_Bou OverFed_Class_I_Statutory_Margin Effective_Class_I_Tax_on_Lower_B Effective_Class_I_Statutory_Marg State_Revenue_Class_I_Lower_Boun State_Revenue_Class_I_Upper_Boun State_Revenue_Class_I_Tax_on_Low State_Revenue_Class_I_Statutory_ Class_III_Statutory_Marginal_Rat Class_I_Statutory_Marginal_Rate Class_II_Statutory_Marginal_Rate {
 local x = substr("`var'", 1 ,30)
   rename `var' `x'
 }

**------------------------------ Standardized reference pre-fix 
ren * v_*
ren (v_country v_Geo v_GeoReg v_geo3 v_year) (country Geo GeoReg geo3 year)

*original seq
gen r = _n
**------------------------------ Brackets & ID -----------------------------------------------------------------------------------------------------
*Brackets--------------------------------------------------------------------------------------------
gen i = 1
gen i_N = i+i[_n-1] if Geo == Geo[_n-1] & GeoReg == GeoReg[_n-1] & year == year[_n-1]
gen i_N2 = i+i_N if Geo == Geo[_n-2] & GeoReg == GeoReg[_n-2] & year == year[_n-2]
gen i_N3 = i+i_N2 if Geo == Geo[_n-3] & GeoReg == GeoReg[_n-3] & year == year[_n-3]
gen i_N4 = i+i_N3 if Geo == Geo[_n-4] & GeoReg == GeoReg[_n-4] & year == year[_n-4]
gen i_N5 = i+i_N4 if Geo == Geo[_n-5] & GeoReg == GeoReg[_n-5] & year == year[_n-5]
gen i_N6 = i+i_N5 if Geo == Geo[_n-6] & GeoReg == GeoReg[_n-6] & year == year[_n-6]
gen i_N7 = i+i_N6 if Geo == Geo[_n-7] & GeoReg == GeoReg[_n-7] & year == year[_n-7]
gen i_N8 = i+i_N7 if Geo == Geo[_n-8] & GeoReg == GeoReg[_n-8] & year == year[_n-8]
gen i_N9 = i+i_N8 if Geo == Geo[_n-9] & GeoReg == GeoReg[_n-9] & year == year[_n-9]
gen i_N10 = i+i_N9 if Geo == Geo[_n-10] & GeoReg == GeoReg[_n-10] & year == year[_n-10]
gen i_N11 = i+i_N10 if Geo == Geo[_n-11] & GeoReg == GeoReg[_n-11] & year == year[_n-11]
gen i_N12 = i+i_N11 if Geo == Geo[_n-12] & GeoReg == GeoReg[_n-12] & year == year[_n-12]
gen i_N13 = i+i_N12 if Geo == Geo[_n-13] & GeoReg == GeoReg[_n-13] & year == year[_n-13]
gen i_N14 = i+i_N13 if Geo == Geo[_n-14] & GeoReg == GeoReg[_n-14] & year == year[_n-14]
gen i_N15 = i+i_N14 if Geo == Geo[_n-15] & GeoReg == GeoReg[_n-15] & year == year[_n-15]
gen i_N16 = i+i_N15 if Geo == Geo[_n-16] & GeoReg == GeoReg[_n-16] & year == year[_n-16]
gen i_N17 = i+i_N16 if Geo == Geo[_n-17] & GeoReg == GeoReg[_n-17] & year == year[_n-17]
gen i_N18 = i+i_N17 if Geo == Geo[_n-18] & GeoReg == GeoReg[_n-18] & year == year[_n-18]
gen i_N19 = i+i_N18 if Geo == Geo[_n-19] & GeoReg == GeoReg[_n-19] & year == year[_n-19]
gen i_N20 = i+i_N19 if Geo == Geo[_n-20] & GeoReg == GeoReg[_n-20] & year == year[_n-20]
gen i_N21 = i+i_N20 if Geo == Geo[_n-21] & GeoReg == GeoReg[_n-21] & year == year[_n-21]
gen i_N22 = i+i_N21 if Geo == Geo[_n-22] & GeoReg == GeoReg[_n-22] & year == year[_n-22]
gen i_N23 = i+i_N22 if Geo == Geo[_n-23] & GeoReg == GeoReg[_n-23] & year == year[_n-23]
gen i_N24 = i+i_N23 if Geo == Geo[_n-24] & GeoReg == GeoReg[_n-24] & year == year[_n-24]
gen i_N25 = i+i_N24 if Geo == Geo[_n-25] & GeoReg == GeoReg[_n-25] & year == year[_n-25]
gen i_N26 = i+i_N25 if Geo == Geo[_n-26] & GeoReg == GeoReg[_n-26] & year == year[_n-26]
gen i_N27 = i+i_N26 if Geo == Geo[_n-27] & GeoReg == GeoReg[_n-27] & year == year[_n-27]
gen i_N28 = i+i_N27 if Geo == Geo[_n-28] & GeoReg == GeoReg[_n-28] & year == year[_n-28]
gen i_N29 = i+i_N28 if Geo == Geo[_n-29] & GeoReg == GeoReg[_n-29] & year == year[_n-29]
gen i_N30 = i+i_N29 if Geo == Geo[_n-30] & GeoReg == GeoReg[_n-30] & year == year[_n-30]
gen i_N31 = i+i_N30 if Geo == Geo[_n-31] & GeoReg == GeoReg[_n-31] & year == year[_n-31]
gen i_N32 = i+i_N31 if Geo == Geo[_n-32] & GeoReg == GeoReg[_n-32] & year == year[_n-32]
gen i_N33 = i+i_N32 if Geo == Geo[_n-33] & GeoReg == GeoReg[_n-33] & year == year[_n-33]

replace i_N33 =i_N32 if missing(i_N33)
replace i_N32 =i_N31 if missing(i_N32)
replace i_N31 =i_N30 if missing(i_N31)
replace i_N30 =i_N29 if missing(i_N30)
replace i_N29 =i_N28 if missing(i_N29)
replace i_N28 =i_N27 if missing(i_N28)
replace i_N27 =i_N26 if missing(i_N27)
replace i_N26 =i_N25 if missing(i_N26)
replace i_N25 =i_N24 if missing(i_N25)
replace i_N24 =i_N23 if missing(i_N24)
replace i_N23 =i_N22 if missing(i_N23)
replace i_N22 =i_N21 if missing(i_N22)
replace i_N21 =i_N20 if missing(i_N21)
replace i_N20 =i_N19 if missing(i_N20)
replace i_N19 =i_N18 if missing(i_N19)
replace i_N18 =i_N17 if missing(i_N18)
replace i_N17 =i_N16 if missing(i_N17)
replace i_N16 =i_N15 if missing(i_N16)
replace i_N15 =i_N14 if missing(i_N15)
replace i_N14 =i_N13 if missing(i_N14)
replace i_N13 =i_N12 if missing(i_N13)
replace i_N12 =i_N11 if missing(i_N12)
replace i_N11 =i_N10 if missing(i_N11)
replace i_N10 =i_N9 if missing(i_N10)
replace i_N9 =i_N8 if missing(i_N9)
replace i_N8 =i_N7 if missing(i_N8)
replace i_N7 =i_N6 if missing(i_N7)
replace i_N6 =i_N5 if missing(i_N6)
replace i_N5 =i_N4 if missing(i_N5)
replace i_N4 =i_N3 if missing(i_N4)
replace i_N3 =i_N2 if missing(i_N3)
replace i_N2 =i_N if missing(i_N2)
replace i_N =i if missing(i_N)

gen c = .
replace c =i_N33 if missing(c)
replace c =i_N32 if missing(c)
replace c =i_N31 if missing(c)
replace c =i_N30 if missing(c)
replace c =i_N29 if missing(c)
replace c =i_N28 if missing(c)
replace c =i_N27 if missing(c)
replace c =i_N26 if missing(c)
replace c =i_N25 if missing(c)
replace c =i_N24 if missing(c)
replace c =i_N23 if missing(c)
replace c =i_N22 if missing(c)
replace c =i_N21 if missing(c)
replace c =i_N20 if missing(c)
replace c =i_N19 if missing(c)
replace c =i_N18 if missing(c)
replace c =i_N17 if missing(c)
replace c =i_N16 if missing(c)
replace c =i_N15 if missing(c)
replace c =i_N14 if missing(c)
replace c =i_N13 if missing(c)
replace c =i_N12 if missing(c)
replace c =i_N11 if missing(c)
replace c =i_N10 if missing(c)
replace c =i_N9 if missing(c)
replace c =i_N8 if missing(c)
replace c =i_N7 if missing(c)
replace c =i_N6 if missing(c)
replace c =i_N5 if missing(c)
replace c =i_N4 if missing(c)
replace c =i_N3 if missing(c)
replace c =i_N2 if missing(c)
replace c =i_N if missing(c)
replace c =i if missing(c)
*-------------------------------------------------------------------------------------------------
*---------------------------Drop Missing
drop if country == ""
 
*---------------------------ID Values by Geo GeoReg and year
egen ID_geo = group(Geo)
egen ID_georeg = group(GeoReg)
egen ID_year = group(year)
gen ID_geo_6f = 1000000*ID_geo
replace ID_georeg = 123 if strlen(GeoReg)==3
gen ID_georeg_3f = ID_georeg*1000
gen ID_GGRY = ID_geo_6f+ID_georeg_3f+ID_year

*---------------------------ID Values by bracket and Geo GeoReg year
egen ID_GGRYB = concat(ID_GGRY c), format(%02.0f)
destring ID_GGRYB, replace

rename v_ID ID
replace ID = ID_GGRYB

sort r

drop i_N* ID_* i r
*-------------------------------------------------------------------------------------------------
reshape long v_, i(country Geo geo3 GeoReg year ID c) j(var) string
