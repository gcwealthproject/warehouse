********************************************************************************
*** 1 EIG: clean data
********************************************************************************

*** STEP 1: Load and prepare data 
*** STEP 2: Transform the database into a long format
*** STEP 3: Generate the class of variables in the vartype classification of the code dictionary
*** STEP 4: Create dashboard-specific brackets
*** STEP 5: Export and save long data

********************************************************************************

* Note: State data removed at bookmark 1 (Line 170), and in second file

*** STEP 0: Prepare do-file
	 	
	/*
	
	* set working directory to Dropbox/THE_GC_WEALTH_PROJECT_website
	*** automatized user paths
	global username "`c(username)'"
	
		dis "$username" // Displays your user name on your computer

		
		* Manuel
		if "$username" == "manuelstone" { 
			global dir  "/Users/manuelstone/Dropbox/THE_GC_WEALTH_PROJECT_website" 
		}
		
		* Twisha
		if "$username" == "twishaasher" { 
			global dir  "/Users/twishaasher/Dropbox (Hunter College)/THE_GC_WEALTH_PROJECT_website" 
		}

		* Francesca's office
		if "$username" == "fsubioli" { 
			global dir  "/Users/fsubioli/Dropbox/Dropbox/gcwealth" 
		}
		
		* YOURNAME
		if "$username" == "YOURUSERNAME" { 
			global dir  "/YOURUSERPATH/THE_GC_WEALTH_PROJECT_website" 
		}
  
	*/
	
		* ID variables: country Geo geo3 GeoReg year (ID) c // can drop ID

		
********************************************************************************
*** STEP 1: Load and prepare data 
********************************************************************************		
		
		
	*** import data
	clear all
	
	run "code/mainstream/auxiliar/all_paths.do"
	set maxvar  32767 
	
	do "code/dashboards/eigt/secondary/01a_check_errors.do"
	
	use "raw_data/eigt/intermediary_files/eigt_fixed_errs.dta", clear

	*** drop extreme inflation observations
	drop if country=="Zimbabwe"
	drop if geo3=="VEN"

	* drop empty cells
	drop if country=="" & Geo==""

	drop Gift_Valuation Gift_Notes Notes Tax_Basis Class_I Class_II Class_III Related_Tax_Notes Final_Notes

	
	*** rename variables
#delimit ;
ren (Currency Converted_From Residence_Basis EIG_Status First_EIG Estate_Tax Gift_Tax Inheritance_Tax Pickup Pickup_AddEstInh Inheritance_Tax_Relation_Based Inheritance_Estate_Exemption Gift_Unified GSTT_Status Gift_Integrated Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP Reg_Rev_GDP Reg_EIG Reg_Only Gift_Integration_Principle Gift_Yrs_Prior Gift_Exemption_Period Gift_Lower_Bound Gift_Upper_Bound Gift_Tax_on_Lower_Bound Gift_Rate Gift_Annual_Exemption Gift_Lifetime_Exemption Taxable_Gift_Basis Filing_Threshold Credit_Included Federal_Effective_Exemption Federal_Effective_Class_I_Lower_ Federal_Effective_Class_I_Upper_ Federal_Effective_Class_I_Tax_on Federal_Effective_Class_I_Statut Spousal_Exemption Child_Exemption Class_I_Exemption Statutory_Class_I_Lower_Bound Statutory_Class_I_Upper_Bound Statutory_Class_I_Tax_on_Lower_B Statutory_Class_I_Statutory_Marg Conc_InhEst_Tax_Class_I_Exemptio Conc_InhEst_Tax_Lower_Bound Conc_InhEst_Tax_Upper_Bound Conc_InhEst_Tax_Tax_on_Lower_Bou Conc_InhEst_Tax_Statutory_Margin Adjusted_Exemption Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound Adjusted_Class_I_Tax_on_Lower_Bo Adjusted_Class_I_Statutory_Margi OverFed_Class_I_Lower_Bound OverFed_Class_I_Upper_Bound OverFed_Class_I_Tax_on_Lower_Bou OverFed_Class_I_Statutory_Margin Effective_Class_I_Lower_Bound Effective_Class_I_Upper_Bound Effective_Class_I_Tax_on_Lower_B Effective_Class_I_Statutory_Marg State_Revenue_Class_I_Lower_Boun State_Revenue_Class_I_Upper_Boun State_Revenue_Class_I_Tax_on_Low State_Revenue_Class_I_Statutory_ Class_I_Lower_Bound Class_I_Upper_Bound Class_I_Tax_on_Lower_Bound Class_I_Statutory_Marginal_Rate Class_II_Exemption Class_II_Lower_Bound Class_II_Upper_Bound Class_II_Tax_on_Lower_Bound Class_II_Statutory_Marginal_Rate Class_III_Exemption Class_III_Lower_Bound Class_III_Upper_Bound Class_III_Tax_on_Lower_Bound Class_III_Statutory_Marginal_Rat Months_to_File_Estate Months_to_File_Inheritance Source_1 Source_2 Source_3 Source_4 Source_5 Source_6 Source_7 Gift_Top_Rate Top_Rate Estate_Top_Rate Inheritance_Top_Rate Estate_Lowest_Rate Inheritance_Lowest_Rate Top_Rate_Class_I_Lower_Bound )  
(curren conver residb eigsta eigfir esttax giftax inhtax pickup pickad itaxre ieexem gifuni gsttst gifint totrev eitrev gifrev fedrev refrev locrev tprrev fprrev rprrev lprrev trvgdp frvgdp rrvgdp regeig regonl gintpr gyrspr gexper gilobo giupbo gtlobo gifrat gannex glfexe tgibas flthre crincl feffex fec1lb fec1up fe1tlb fe1tsm spoexe chiexe cl1exe sec1lb sec1up se1tlb se1tsm cota1e cotalb cotaup cottlb cotstm adexem ad1lbo ad1ubo ad1tlb ad1smr of1lbo of1ubo of1tlb of1smr ef1lbo ef1ubo ef1tlb ef1smr srv1lb srv1ub srv1tl srv1sm cl1lbo cl1ubo cl1tlb cl1smr cl2exe cl2lbo cl2ubo cl2tlb cl2smr cl3exe cl3lbo cl3ubo cl3tlb cl3smr monest moninh sourc1 sourc2 sourc3 sourc4 sourc5 sourc6 sourc7 gtopra toprat etopra itopra elowra ilowra torac1);
#delimit cr


	*** drop irrelevant variables from the excel file
		cap drop DQ-EA
		
	preserve
	
		import excel "handmade_tables/eigt_concept_notes.xlsx", firstrow  clear
			levelsof code if Launch1=="N", local(dropvars)
		
	restore
	
	foreach v in `dropvars'{
		cap drop `v'
	}
		
  
	*** ###
	*foreach var of varlist E* {
	*	capture assert missing(`var')
	*	if !_rc drop `var'
	*}

	
	*** ---------- standardize reference pre-fix ---------- ***
	ren * v_*
	ren (v_country v_Geo v_GeoReg v_geo3 v_year) (country Geo GeoReg geo3 year)

	
	*** include new geographical area classification  
	
	cap drop __000000  __000001
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


	*** ---------- Brackets & ID ---------- ***
	
		* brackets
		gen i = 1
		gen c = .
		gen i_N1 = i+i[_n-1] if Geo == Geo[_n-1] & GeoReg == GeoReg[_n-1] & year == year[_n-1]

		* gen col for each bracket
		foreach k of numlist 2/33{
			local prebra = `k'-1
			gen i_N`k' = i+i_N`prebra' if Geo == Geo[_n-`k'] & GeoReg == GeoReg[_n-`k'] & year == year[_n-`k']
		}


		foreach k of numlist 33(-1)2{
			local prebra = `k'-1
			replace i_N`k' =i_N`prebra' if missing(i_N`k')
		}

			replace i_N1 =i if missing(i_N1)

		foreach k of numlist 33(-1)2{
			replace c =i_N`k' if missing(c)
		}

			replace c =i_N1 if missing(c)
			replace c =i if missing(c)

		drop i_N*
		
		* drop missing
		drop if country == "."

		sort r

		*drop i_N* ID_* i r
		drop i r

		* variable identifying the tax bracket 
		rename c bracket
			format bracket %02.0f
  
		foreach k of numlist 1/7{
			rename v_sourc`k' source`k'
		}



********************************************************************************
*** STEP 2: Transform the database into a long format
********************************************************************************

**# Bookmark #1
	keep if GeoReg == "_na" // Remove states

		drop country Geo GeoReg geo3 
		drop if area=="-" & year==.
		
		drop v_N	
	
	// CHANGED
	
	
	*** change revenue vars back to string for reshape
	global revdata v_totrev v_eitrev v_gifrev v_fedrev v_tprrev v_fprrev v_trvgdp v_frvgdp
			
	tostring $revdata, replace force
			
	reshape long v_, i(area year  bracket  source1 source2 source3 source4 source5 source6 source7) j(var) string
 

	*** THIS HAS TO BE CARFEULLY CHECKED! SOMETIMES  missing values are simply blanks! (CHECK WITH TWISHA! ###)
		drop if v_=="."
		drop if v_==""
 
	preserve
	*qui import excel "${code_translator}", sheet("EIG tax") firstrow clear
	qui import excel "handmade_tables/eigt_concept_notes.xlsx", firstrow  clear
		keep if Bracketspecific=="Y"
		qui levelsof code, clean local(eig_cods) 
	restore

	foreach cd in `eig_cods' {
		drop if var=="`cd'" & v_=="_na"
	}
	
	cap drop temp
	qui gen temp=0
	foreach var of varlist source* {
		foreach prev of varlist source* {
			if "`prev'" != "`var'" {
				qui replace temp = 1 if `var' == `prev' & `var' != "."
			}
			replace `prev' = "." if temp==1
			replace temp =0
		}
	}
	drop temp
	
********************************************************************************
*** STEP 3: Generate the class of variables in the vartype classification of the code dictionary
********************************************************************************
 
	order area year bracket
 
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
		str String
	*/
  
	generate _3_vartype = ""

	*cat Categorical variable
		/*local cat "Currency Converted_From Residence_Basis EIG_Status First_EIG Estate_Tax Gift_Tax Inheritance_Tax Pickup Pickup_AddEstInh Inheritance_Tax_Relation_Based Inheritance_Estate_Exemption Gift_Unified GSTT_Status Gift_Integrated
Reg_EIG Reg_Only Gift_Integration_Principle   Credit_Included Taxable_Gift_Basis Gift_Valuation Gift_Notes   Notes Tax_Basis    Class_I Class_II Class_III
Related_Tax_Notes Final_Notes Source_1 Source_2 Source_3 Source_4 Source_5 Source_6 Source_7 "
		*/
	* Question: should we create a separate type (TEXT) for these variables? Technically, they are not categorical variables ###

		/*Taxable_Gift_Basis Gift_Valuation Gift_Notes   Notes Tax_Basis    Class_I Class_II Class_III
	Related_Tax_Notes Final_Notes Source_1 Source_2 Source_3 Source_4 Source_5 Source_6 Source_7 */


	local cat " gintpr residb eigsta eigfir esttax giftax inhtax pickup pickad itaxre ieexem gifuni gsttst gifint tgibas crincl regeig regonl" 

	foreach v of local cat {
		replace _3_vartype= "cat" if var=="`v'"	
	}
 
	local str "curren conver tgibas monest moninh" 

	foreach v of local str {
		replace _3_vartype= "str" if var=="`v'"
	} 
 
	*rat Rate
		/* Gift_Rate    Federal_Effective_Class_I_Statut  Statutory_Class_I_Statutory_Marg   Conc_InhEst_Tax_Statutory_Margin  Adjusted_Class_I_Statutory_Margi   OverFed_Class_I_Statutory_Margin  Effective_Class_I_Statutory_Marg
 State_Revenue_Class_I_Statutory_  Class_I_Statutory_Marginal_Rate  Class_II_Statutory_Marginal_Rate  Class_III_Statutory_Marginal_Rat
 Gift_Top_Rate Top_Rate Estate_Top_Rate Inheritance_Top_Rate Estate_Lowest_Rate Inheritance_Lowest_Rate Top_Rate_Class_I_Lower_Bound */
 
	local rat "  gifrat fe1tsm se1tsm cotstm ad1smr of1smr ef1smr srv1sm cl1smr cl2smr cl3smr  gtopra toprat etopra itopra elowra ilowra"

	foreach v of local rat {
		replace _3_vartype= "rat" if var=="`v'"
	}
 
 

	*rto Ratio 
		*Tot_Prop_Rev Fed_Prop_Rev Reg_Prop_Rev Loc_Prop_Rev Tot_Rev_GDP Fed_Rev_GDP Reg_Rev_GDP

	local rto " tprrev fprrev rprrev lprrev trvgdp frvgdp rrvgdp"
	
	foreach v of local rto {
		replace _3_vartype= "rto" if var=="`v'"
	}

	*thr Threshold
	/* Gift_Yrs_Prior  Gift_Exemption_Period Gift_Lower_Bound Gift_Upper_Bound Gift_Annual_Exemption Gift_Lifetime_Exemption   Filing_Threshold Federal_Effective_Exemption Federal_Effective_Class_I_Lower_ Federal_Effective_Class_I_Upper_
Spousal_Exemption Child_Exemption Class_I_Exemption Statutory_Class_I_Lower_Bound Statutory_Class_I_Upper_Bound   Conc_InhEst_Tax_Class_I_Exemptio Conc_InhEst_Tax_Lower_Bound Conc_InhEst_Tax_Upper_Bound 
Adjusted_Exemption Adjusted_Class_I_Lower_Bound Adjusted_Class_I_Upper_Bound  OverFed_Class_I_Lower_Bound OverFed_Class_I_Upper_Bound Effective_Class_I_Lower_Bound Effective_Class_I_Upper_Bound 
 State_Revenue_Class_I_Lower_Boun State_Revenue_Class_I_Upper_Boun  Class_I_Lower_Bound Class_I_Upper_Bound  Class_II_Exemption Class_II_Lower_Bound Class_II_Upper_Bound    Class_III_Exemption Class_III_Lower_Bound Class_III_Upper_Bound
  Months_to_File_Estate Months_to_File_Inheritance  ID */
 
 
	local thr "gyrspr gexper gilobo giupbo gannex glfexe flthre feffex fec1lb fec1up spoexe chiexe cl1exe sec1lb sec1up cota1e cotalb cotaup adexem ad1lbo ad1ubo of1lbo of1ubo ef1lbo ef1ubo srv1lb srv1ub cl1lbo cl1ubo cl2exe cl2lbo cl2ubo cl3exe cl3lbo cl3ubo torac1 "

	foreach v of local thr {
		replace _3_vartype= "thr" if var=="`v'"
	}

	*agg Aggregate 
		/* Tot_Rev Tot_EI_Rev Tot_Gift_Rev Fed_Rev Reg_Rev Loc_Rev   Gift_Tax_on_Lower_Bound   Federal_Effective_Class_I_Tax_on Statutory_Class_I_Tax_on_Lower_B Conc_InhEst_Tax_Tax_on_Lower_Bou  Adjusted_Class_I_Tax_on_Lower_Bo
OverFed_Class_I_Tax_on_Lower_Bou Effective_Class_I_Tax_on_Lower_B   State_Revenue_Class_I_Tax_on_Low Class_I_Tax_on_Lower_Bound Class_II_Tax_on_Lower_Bound  Class_III_Tax_on_Lower_Bound
		*/
 
	local agg "  totrev eitrev gifrev fedrev refrev locrev gtlobo fe1tlb se1tlb cottlb ad1tlb of1tlb ef1tlb srv1tl cl1tlb cl2tlb cl3tlb ididid "

	foreach v of local agg {
		replace _3_vartype= "agg" if var=="`v'"
	}


	* check classification missing
		ta _3_vartype

	/*
	d1_dashboard
		x	Taxes and Transfers
		t	Inequality Trends
		p	Wealth Topography
		i	Inheritances
		z	Supplementary variables
	*/

	gen _1_dashboard = "x"

 
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

	
********************************************************************************
*** STEP 4: Create dashboard-specific brackets
********************************************************************************

	*gen _5_dboard_specific = bracket
	gen bracketspecific = "N"

	*since all variables need to be graphed, bracket-specific indicator may not be needed
	local bktspecific "  gilobo giupbo gtlobo gifrat fec1lb fec1up fe1tlb fe1tsm sec1lb sec1up se1tlb se1tsm cotalb cotaup cottlb cotstm ad1lbo ad1ubo ad1tlb ad1smr of1lbo of1ubo of1tlb of1smr ef1lbo ef1ubo ef1tlb ef1smr srv1lb srv1ub srv1tl srv1sm cl1lbo cl1ubo cl1tlb cl1smr cl2lbo cl2ubo cl2tlb cl2smr cl3lbo cl3ubo cl3tlb cl3smr "

	foreach v of local bktspecific {
		replace bracketspecific="Y"  if var=="`v'"
	}
 
		replace bracket=00 if bracketspecific=="N"
 
		duplicates drop

	gen _5_dboard_specific = bracket

	egen varcode = concat(_1_dashboard _2_sector _3_vartype _4_concept _5_dboard_specific ), format(%02.0f) punct("-")

	rename v_ value_string
	gen percentile ="p0p100"

	drop var _1 _2 _3 _4 _5 bracketspecific bracket 
	*drop var _1 _2 _3 _4 _5 bracket 

 
	
********************************************************************************
*** STEP 5: Export and save long data
********************************************************************************


		keep area year value_string percentile source1 source2 source3 source4 source5 source6 source7 varcode
		order area year value_string percentile source1 source2 source3 source4 source5 source6 source7 varcode


	qui export delimited using ///
		"raw_data/eigt/intermediary_files/eigt_long.csv", replace
	qui save "raw_data/eigt/intermediary_files/eigt_long.dta", replace
	
	
