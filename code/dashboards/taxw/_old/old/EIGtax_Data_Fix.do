
** ID variables: country Geo geo3 GeoReg year (ID) c // can drop ID
*set working directory to Dropbox/THE_GC_WEALTH_PROJECT_website

clear all
run "code/auxiliar/all_paths.do"
set maxvar  32767 
import excel "EIG Taxes/data_inputs/EIGtax_mergeable.xlsx", firstrow  clear
 
 #delimit ;
ren (Currency Converted_From Residence_Basis EIG_Status First_EIG Estate_Tax Gift_Tax Inheritance_Tax Pickup Pickup_AddEstInh Inheritance_Tax_Relation_Based Inheritance_Estate_Exemption Gift_Unified GSTT_Status Gift_Integrated Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP Reg_Rev_GDP Reg_EIG Reg_Only Gift_Integration_Principle Gift_Yrs_Prior Gift_Exemption_Period Gift_Lower_Bound Gift_Upper_Bound Gift_Tax_on_Lower_Bound Gift_Rate Gift_Annual_Exemption Gift_Lifetime_Exemption Taxable_Gift_Basis Gift_Valuation Gift_Notes Filing_Threshold Credit_Included Notes Tax_Basis Federal_Effective_Exemption Federal_Effective_Class_I_Lower_ Federal_Effective_Class_I_Upper_ Federal_Effective_Class_I_Tax_on Federal_Effective_Class_I_Statut Class_I Spousal_Exemption Child_Exemption Class_I_Exemption Statutory_Class_I_Lower_Bound Statutory_Class_I_Upper_Bound Statutory_Class_I_Tax_on_Lower_B Statutory_Class_I_Statutory_Marg Conc_InhEst_Tax_Class_I_Exemptio Conc_InhEst_Tax_Lower_Bound Conc_InhEst_Tax_Upper_Bound Conc_InhEst_Tax_Tax_on_Lower_Bou Conc_InhEst_Tax_Statutory_Margin Adjusted_Exemption Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound Adjusted_Class_I_Tax_on_Lower_Bo Adjusted_Class_I_Statutory_Margi OverFed_Class_I_Lower_Bound OverFed_Class_I_Upper_Bound OverFed_Class_I_Tax_on_Lower_Bou OverFed_Class_I_Statutory_Margin Effective_Class_I_Lower_Bound Effective_Class_I_Upper_Bound Effective_Class_I_Tax_on_Lower_B Effective_Class_I_Statutory_Marg State_Revenue_Class_I_Lower_Boun State_Revenue_Class_I_Upper_Boun State_Revenue_Class_I_Tax_on_Low State_Revenue_Class_I_Statutory_ Class_I_Lower_Bound Class_I_Upper_Bound Class_I_Tax_on_Lower_Bound Class_I_Statutory_Marginal_Rate Class_II Class_II_Exemption Class_II_Lower_Bound Class_II_Upper_Bound Class_II_Tax_on_Lower_Bound Class_II_Statutory_Marginal_Rate Class_III Class_III_Exemption Class_III_Lower_Bound Class_III_Upper_Bound Class_III_Tax_on_Lower_Bound Class_III_Statutory_Marginal_Rat Months_to_File_Estate Months_to_File_Inheritance Related_Tax_Notes Final_Notes Source_1 Source_2 Source_3 Source_4 Source_5 Source_6 Source_7 Gift_Top_Rate Top_Rate Estate_Top_Rate Inheritance_Top_Rate Estate_Lowest_Rate Inheritance_Lowest_Rate Top_Rate_Class_I_Lower_Bound )  
(curren 
conver
residb
eigsta
eigfir
esttax
giftax
inhtax
pickup
pickad
itaxre
ieexem
gifuni
gsttst
gifint
totrev
eitrev
gifrev
fedrev
refrev
locrev
tprrev
fprrev
rprrev
lprrev
trvgdp
frvgdp
rrvgdp
regeig
regonl
gintpr
gyrspr
gexper
gilobo
giupbo
gtlobo
gifrat
gannex
glfexe
tgibas
gifval
gnotes
flthre
crincl
notess
taxbas
feffex
fec1lb
fec1up
fe1tlb
fe1tsm
class1
spoexe
chiexe
cl1exe
sec1lb
sec1up
se1tlb
se1tsm
cota1e
cotalb
cotaup
cottlb
cotstm
adexem
ad1lbo
ad1ubo
ad1tlb
ad1smr
of1lbo
of1ubo
of1tlb
of1smr
ef1lbo
ef1ubo
ef1tlb
ef1smr
srv1lb
srv1ub
srv1tl
srv1sm
cl1lbo
cl1ubo
cl1tlb
cl1smr
class2
cl2exe
cl2lbo
cl2ubo
cl2tlb
cl2smr
class3
cl3exe
cl3lbo
cl3ubo
cl3tlb
cl3smr
monest
moninh
finnot
relnot
sourc1
sourc2
sourc3
sourc4
sourc5
sourc6
sourc7
gtopra
toprat
etopra
itopra
elowra
ilowra
torac1);
#delimit cr




* drop irrelevant variables from the excel file
  drop DQ-EA
 



**------------------------------ Standardized reference pre-fix 
ren * v_*
ren (v_country v_Geo v_GeoReg v_geo3 v_year) (country Geo GeoReg geo3 year)


  
* Include new geographical area classification  

preserve
drop  if GeoReg=="_na"
egen area = concat(Geo GeoReg), punct("-") 
tempfile region
save "`region'"
restore

keep if GeoReg=="_na"
gen area = Geo
	
append using "`region'"






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
drop if country == "."
 
*---------------------------ID Values by Geo GeoReg and year
*egen ID_geo = group(Geo)
*egen ID_georeg = group(GeoReg)
*egen ID_year = group(year)
*gen ID_geo_6f = 1000000*ID_geo
*replace ID_georeg = 123 if strlen(GeoReg)==3
*gen ID_georeg_3f = ID_georeg*1000
*gen ID_GGRY = ID_geo_6f+ID_georeg_3f+ID_year

*---------------------------ID Values by bracket and Geo GeoReg year
*egen ID_GGRYB = concat(ID_GGRY c), format(%02.0f)
*destring ID_GGRYB, replace

*rename v_ididid ididid
*gen ididid = ID_GGRYB

sort r




*drop i_N* ID_* i r
drop i_N* i r

* variable identifying the tax bracket 
  
   rename c bracket
   format bracket %02.0f
  

  rename v_sourc1 source1
  rename v_sourc2 source2
  rename v_sourc3 source3
  rename v_sourc4 source4
  rename v_sourc5 source5
  rename v_sourc6 source6
  rename v_sourc7 source7





* TRANSFORM THE DATABASE INTO A LONG FORMAT  


*-------------------------------------------------------------------------------------------------
drop country Geo GeoReg geo3 
drop if area=="-" & year==.
reshape long v_, i(   area year bracket    source1 source2 source3 source4 source5 source6 source7) j(var) string


 
 
****************
** THIS HAS TO BE CARFEULLY CHECKED! SOMETIMES  missing values are simply blanks! 
 drop if v_=="."
  drop if v_==""
 
**************************************
 
 order area year bracket
 
 


  * GENERATE the class of variables in the Vartype classification of the Code Dictionary

  /*
d3_vartype

dsh	Distribution share
csh	Composition share
rat	Rate
gin	Gini coefficient
avg	Average
rto	Ratio 
thr	Threshold
cat	Categorical variable
agg	Aggregate 

  */
  
generate _3_vartype=""

*cat	Categorical variable
/*local cat "Currency Converted_From Residence_Basis EIG_Status First_EIG Estate_Tax Gift_Tax Inheritance_Tax Pickup Pickup_AddEstInh Inheritance_Tax_Relation_Based Inheritance_Estate_Exemption Gift_Unified GSTT_Status Gift_Integrated
Reg_EIG Reg_Only Gift_Integration_Principle   Credit_Included Taxable_Gift_Basis Gift_Valuation Gift_Notes   Notes Tax_Basis    Class_I Class_II Class_III
Related_Tax_Notes Final_Notes Source_1 Source_2 Source_3 Source_4 Source_5 Source_6 Source_7 "
*/
*Question: should we create a separate type (TEXT) for these variables? Technically, they are not categorical variables

/*Taxable_Gift_Basis Gift_Valuation Gift_Notes   Notes Tax_Basis    Class_I Class_II Class_III
Related_Tax_Notes Final_Notes Source_1 Source_2 Source_3 Source_4 Source_5 Source_6 Source_7 */


local cat "curren conver residb eigsta eigfir esttax giftax inhtax pickup pickad itaxre ieexem gifuni gsttst gifint tgibas gifval gnotes crincl notess taxbas class1 class2 class3 monest moninh finnot  relnot sourc1 sourc2 sourc3 sourc4 sourc5 sourc6 sourc7 " 

foreach v of local cat {
replace _3_vartype= "cat" if var=="`v'"
}
 
*rat	Rate
/* Gift_Rate    Federal_Effective_Class_I_Statut  Statutory_Class_I_Statutory_Marg   Conc_InhEst_Tax_Statutory_Margin  Adjusted_Class_I_Statutory_Margi   OverFed_Class_I_Statutory_Margin  Effective_Class_I_Statutory_Marg
 State_Revenue_Class_I_Statutory_  Class_I_Statutory_Marginal_Rate  Class_II_Statutory_Marginal_Rate  Class_III_Statutory_Marginal_Rat
 Gift_Top_Rate Top_Rate Estate_Top_Rate Inheritance_Top_Rate Estate_Lowest_Rate Inheritance_Lowest_Rate Top_Rate_Class_I_Lower_Bound */
 
local rat "  gifrat fe1tsm se1tsm cotstm ad1smr of1smr ef1smr srv1sm cl1smr cl2smr cl3smr  gtopra toprat etopra itopra elowra ilowra"

 foreach v of local rat {
replace _3_vartype= "rat" if var=="`v'"
}
 
 

*rto	Ratio 
*Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP Reg_Rev_GDP

local rto " tprrev fprrev rprrev lprrev trvgdp frvgdp rrvgdp"
 foreach v of local rto {
replace _3_vartype= "rto" if var=="`v'"
}

*thr	Threshold

/* Gift_Yrs_Prior  Gift_Exemption_Period Gift_Lower_Bound Gift_Upper_Bound Gift_Annual_Exemption Gift_Lifetime_Exemption   Filing_Threshold Federal_Effective_Exemption Federal_Effective_Class_I_Lower_ Federal_Effective_Class_I_Upper_
Spousal_Exemption Child_Exemption Class_I_Exemption Statutory_Class_I_Lower_Bound Statutory_Class_I_Upper_Bound   Conc_InhEst_Tax_Class_I_Exemptio Conc_InhEst_Tax_Lower_Bound Conc_InhEst_Tax_Upper_Bound 
Adjusted_Exemption Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound  OverFed_Class_I_Lower_Bound OverFed_Class_I_Upper_Bound Effective_Class_I_Lower_Bound Effective_Class_I_Upper_Bound 
 State_Revenue_Class_I_Lower_Boun State_Revenue_Class_I_Upper_Boun  Class_I_Lower_Bound Class_I_Upper_Bound  Class_II_Exemption Class_II_Lower_Bound Class_II_Upper_Bound    Class_III_Exemption Class_III_Lower_Bound Class_III_Upper_Bound
 
  Months_to_File_Estate Months_to_File_Inheritance  ID */
 
 
local thr "regeig regonl gintpr gyrspr gexper gilobo giupbo gannex glfexe flthre feffex fec1lb fec1up spoexe chiexe cl1exe sec1lb sec1up cota1e cotalb cotaup adexem ad1lbo ad1ubo of1lbo of1ubo ef1lbo ef1ubo srv1lb srv1ub cl1lbo cl1ubo cl2exe cl2lbo cl2ubo cl3exe cl3lbo cl3ubo torac1 "

 foreach v of local thr {
replace _3_vartype= "thr" if var=="`v'"
}




*agg	Aggregate 

/* Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev   Gift_Tax_on_Lower_Bound   Federal_Effective_Class_I_Tax_on Statutory_Class_I_Tax_on_Lower_B Conc_InhEst_Tax_Tax_on_Lower_Bou  Adjusted_Class_I_Tax_on_Lower_Bo
OverFed_Class_I_Tax_on_Lower_Bou Effective_Class_I_Tax_on_Lower_B   State_Revenue_Class_I_Tax_on_Low Class_I_Tax_on_Lower_Bound Class_II_Tax_on_Lower_Bound  Class_III_Tax_on_Lower_Bound
*/
 
 local agg "  totrev eitrev gifrev fedrev refrev locrev gtlobo fe1tlb se1tlb cottlb ad1tlb of1tlb ef1tlb srv1tl cl1tlb cl2tlb cl3tlb ididid "


 foreach v of local agg {
replace _3_vartype= "agg" if var=="`v'"
}


*check classification missing

ta _3_vartype


/*
d1_dashboard

x	Taxes and Transfers
t	Inequality Trends
p	Wealth Topography
i	Inheritances
z	Supplementary variables
*/

gen _1_dashboard="x"


 
/*
d2_sector

na	National level
hs	Household
hn	Households & NPISH
np	NPISH
gg	General Government
*/

gen _2_sector = "hs"

 
gen _4_concept = var

*****-------------------------------------------------------------------------------------------TA modified
************shifting gen _5_dboard_specific = bracket to after 00 bracket added*************************

*gen _5_dboard_specific = bracket

gen bracketspecific = "N"



*since all variables need to be graphed, bracket-specific indicator may not be needed
local bktspecific "  gilobo giupbo gtlobo gifrat fec1lb fec1up fe1tlb fe1tsm sec1lb sec1up se1tlb se1tsm cotalb cotaup cottlb cotstm ad1lbo ad1ubo ad1tlb ad1smr of1lbo of1ubo of1tlb of1smr ef1lbo ef1ubo ef1tlb ef1smr srv1lb srv1ub srv1tl srv1sm cl1lbo cl1ubo cl1tlb cl1smr cl2lbo cl2ubo cl2tlb cl2smr cl3lbo cl3ubo cl3tlb cl3smr "

foreach v of local bktspecific {
replace bracketspecific="Y"  if var=="`v'"

}
 
replace bracket=00 if bracketspecific=="N"
 
 duplicates drop
 
************shifted gen _5_dboard_specific = bracket  here *************************
 gen _5_dboard_specific = bracket
 
*****---------------------------------------------------------------------------------------TA modified end

egen varcode = concat(_1_dashboard _2_sector _3_vartype _4_concept _5_dboard_specific ), format(%02.0f) punct("-")

rename v_ value_string
gen percentile ="p0p100"

drop var _1 _2 _3 _4 _5 bracketspecific bracket 
*drop var _1 _2 _3 _4 _5 bracket 

 
*****---------------------------------------------------------------------------------------Longname



*egen source = concat(source1 source2 source3 source4 source5 source6 source7), punct("/")
*replace source = subinstr(source,"/.","",.)

keep area year value_string percentile source1 source2 source3 source4 source5 source6 source7 varcode
order area year value_string percentile source1 source2 source3 source4 source5 source6 source7 varcode
//export result

**#
*************************may need to reset working directiry at this stage
qui export delimited using "EIG Taxes/data_output/EIGtax_long.csv", replace
qui save ///
	"EIG Taxes/data_output/EIGtax_long.dta",replace
