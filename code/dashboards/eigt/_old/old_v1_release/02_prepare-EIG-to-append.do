********************************************************************************
*** 2 EIG: prepare EIG data to append
********************************************************************************

*** STEP 1: Load and prepare data 
*** STEP 2: Save and export eig warehouse
*** STEP 3: Generate data file for the visualization of tax schedule
********************************************************************************

***** State-based info modified in lines 218-223

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

		* YOURNAME
		if "$username" == "YOURUSERNAME" { 
			global dir  "/YOURUSERPATH/THE_GC_WEALTH_PROJECT_website" 
		}
  
	*/
	
	
	*** define path to save files 
	run "code/mainstream/auxiliar/all_paths.do"

	
********************************************************************************
*** STEP 1: Load and prepare data 
********************************************************************************	

	* remember varcodes   
	*qui import excel "${code_translator}" , sheet("EIG tax") firstrow clear
	qui import excel "handmade_tables/eigt_concept_notes.xlsx", firstrow  clear
	
	/*
		drop if missing(code)
		qui levelsof code, clean local(eig_cods) 
		
		foreach cd in `eig_cods' {
			di as result "`cd': " _continue
			qui levelsof Variable if code == "`cd'", clean local(var_`cd')
			di as text "`var_`cd''"
		}	
	*/
		*build a categorical value depending on concept 
		*qui import excel "EIG Taxes/Warehouse_Structure_EIG", ///
		*	clear firstrow sheet("5. Categorical_Variables")
		*qui drop if missing(NumericValue)	
		*qui keep Variable LabelStructure NumericValue Definition 
		*qui gen concept = ""
		*foreach cd in `eig_cods' {
		*	qui replace concept = "`cd'" if Variable == "`var_`cd''"
		*}
		*qui egen concept_categ = concat(concept LabelStructure)

		*Save categorical labels in memory 
		*qui levelsof concept_categ, local(catlabs) clean 
		*foreach cl in `catlabs' {
		*	di as result "`cl': " _continue 
		*save number 
		*	qui levelsof NumericValue if concept_categ == "`cl'", ///
		*		clean local(num_`cl')
		*	di as text "`num_`cl''" _continue 
		*save definition 
		*	qui levelsof Definition if concept_categ == "`cl'", ///
		*		clean local(def_`cl')
		*	di as text " -`def_`cl''" 
		*}
		
 
	*** I. Destring values from EIG warehouse  ----------------------------

	*** open dataset 
	qui use "raw_data/eigt/intermediary_files/eigt_long.dta", clear

		*save _na in a drawer (completar)
		*qui drop if inlist(value, "_na", "na")

		*save currencies in another drawer (completar)
		*qui gen curr = regexm(value, "[A-Z][A-Z][A-Z]$")
		*qui drop if curr == 1 

		*save metadata notes and string-concepts 
		*qui gen dropper = . 
		*foreach c in notess class1 class2 class3 cl2exe ///
		*	cl3exe gannex taxbas gnotes finnot relnot ///
		*	conver gifval fec1lb pickad gyrspr {
		*		qui replace dropper = 1 ///
		*			if substr(varcode,10,6) == "`c'"
		*}
		*qui drop if dropper == 1 
		*qui drop dropper 

		*replace categorical variables  
		*qui gen concept = substr(varcode,10,6)
		*qui egen concept_categ = concat(concept value)
		*qui drop concept 
		*qui gen auxnum = "" 
		*qui gen defini = ""
		*foreach cl in `catlabs' {
		*	qui replace auxnum = "`num_`cl''" if concept_categ == "`cl'"
		*	*qui replace defini = "`def_`cl''" if concept_categ == "`cl'"
		*}
		*qui replace value = auxnum if !missing(auxnum) 
		*qui drop auxnum 
		*qui replace value = "0" if value == "N"
		*qui replace value = "1" if value == "Y"

		qui destring year, replace 

	*** II. Concatenate sources --------------------------------------------

	*** Import legend entries 
	preserve
		qui import excel "handmade_tables/dictionary.xlsx", ///
			sheet("Sources") ///
			cellrange(C1:I400) firstrow case(lower) allstring clear
			keep legend source citekey
		qui save "handmade_tables/source_legend.dta", replace
	restore
		
	*** Add entries by modifying number (more elegant solution needed)
		forvalues n=1/7{
			preserve  // save current doc for merging
				use "handmade_tables/source_legend.dta", clear
				 rename source source`n'  // rename to master file name for each source
				 rename legend source_legend`n'  // legend for each source
				 rename citekey citekey`n'
				 tempfile source`n'
				 save  "`source`n''", replace
			restore			
		
			cap drop _merge 
			qui merge m:1 source`n' using "`source`n''"
				qui drop if _merge==2
				drop _merge
			qui replace source_legend`n' = "Ernst & Young (2021) Personal Tax Guide" ///
			if source`n'=="EY2021a" // ***temporary until source is added to library***
			qui replace source_legend`n' = source`n' ///
			if source`n'=="Inferred"
		}
	
		*** concetenate and clean citekey
		qui egen citekey_concat = concat(citekey*), punct(/)
		qui replace citekey_concat = subinstr(citekey_concat, "////", "", .)
		qui replace citekey_concat = subinstr(citekey_concat, "///", "", .)
		qui replace citekey_concat = subinstr(citekey_concat, "//", "", .)
		qui replace citekey_concat = subinstr(citekey_concat, "/", "", 1) if substr(citekey_concat, 1, 1) == "/"
		qui gen ck1 = strreverse(citekey_concat)
		qui replace ck1 = subinstr(ck1, "/", "", 1) if substr(ck1, 1, 1) == "/"
		qui replace citekey_concat = strreverse(ck1)
		qui drop ck1
		qui rename citekey_concat c_citekey 
		qui drop citekey*		
	
		*** concatenate and clean legend
		cap drop source_legend_concat 
		qui egen source_legend_concat = concat(source_legend*), punct(/)
		qui replace source_legend_concat = subinstr(source_legend_concat, "///", "", .)
		qui replace source_legend_concat = subinstr(source_legend_concat, "//", "", .)

		*** list values just in case 
		forvalues s = 1/7 {
			di as result "Source `s' values: "
			qui replace source`s' = "." if missing(source`s')
			qui levelsof source`s', clean local(srcs`s') 
		foreach s2 in `srcs`s'' {
			di as text " - `s2'"
		}
		}

		*** concatenate and clean 
		forvalues sn=1/7{
			rename source`sn' sourcekey`sn'
		}
		cap drop source_concat 
		qui egen source_concat = concat(sourcekey*), punct(/)
		qui replace source_concat = subinstr(source_concat, "./", "", .)
		qui replace source_concat = subinstr(source_concat, "/.", "", .)
		qui order area year value percentile varcode source_concat 
	

		*** list new values of source 
		qui levelsof source_concat, clean local(new_srcs) 
		foreach ns in `new_srcs' {
			di as text " - `ns'"
		}

		*** drop excess sources 
		qui keep area year value percentile varcode source_concat source_legend_concat c_citekey
			qui rename source_concat source
			qui rename source_legend_concat source_legend

	*** III. fill longname --------------------------------------------

		gen vartype = substr(varcode, 6,3)

		local full ""Distribution share" "Composition share" Rate "Gini coefficient" Average Ratio Threshold "Categorical variable" Aggregate"
		local abbrv "dsh csh rat gin avg rto thr cat agg"

		local n: word count `full'

		forvalues i = 1/`n' {
			local a : word `i' of `full'
			local b : word `i' of `abbrv'
			replace vartype="`a'" if vartype=="`b'"
		}


		gen varname = substr(varcode, 10, 6)

local full_name ""Currency" "Source Currency" "Residence Basis" "Transfer Tax Indicator" "First Year for EIG Taxes" "Estate Tax Indicator" "Gift Tax Indicator" "Inheritance Tax Indicator" "Pickup Tax" "State-Specific Tax and Pickup Tax" "Inheritance Tax by Relationship" "Alternate Type Exemption" "Gift Tax Unification" "Generation Skipping Transfer Tax" "Gift Tax Integration" "Total Revenue" "Total Revenue from Estate and Inheritance Taxes" "Total Revenue from Gift Taxes" "Federal Revenue" "Regional Revenue" "Local EIG Revenue" "Total Revenue from EIG taxes as % of Tax Revenue" "Federal Revenue from EIG taxes as % of Tax Revenue" "Regional Revenue from EIG taxes as % of Tax Revenue" "Local Revenue from EIG taxes as % of Tax Revenue" "Total Revenue from EIG taxes as a percentage of GDP" "Federal Revenue from EIG Taxes as a Percentage of GDP" "Regional Revenue from EIG Taxes as a Percentage of GDP" "Regional Wealth Transfer Tax" "Regional Wealth Transfer Taxes Only" "Gift Integration Principle" "Gift Integration Period" "Number of Years Until Gift Exemptions Renew" "Lower Bound for Gift Tax Bracket" "Upper Bound for Gift Tax Bracket" "Tax Paid on Lower Bound for Gift Tax Bracket" "Gift Tax Rate on Tax Bracket" "Gift Exemption Threshold" "Lifetime Gift Exemption Threshold" "Gift Exemption Renewal Basis" "Method of Valuation for Gifts" "Gift Notes" "Tax Filing Threshold" "Credit Included" "Notes" "Assets Included in Tax Base" "Exemption for Federal Effective Tax Bracket" "Lower Bound for Federal Effective Tax Bracket" "Upper Bound for Federal Effective Tax Bracket" "Tax Paid on Lower Bound for Federal Effective Tax Bracket" "Tax Rate for Federal Effective Tax Bracket" "Class I Definition" "Spousal Exemption" "Child Exemption" "Class I Exemption" "Lower Bound for Statutory Tax Bracket" "Upper Bound for Statutory Tax Bracket" "Tax Paid on Lower Bound for Statutory Tax Bracket" "Tax Rate for Statutory Tax Bracket" "Exemption for Added State-Specific Tax Bracket" "Lower Bound for Added State-Specific Tax Bracket" "Upper Bound for Added State-Specific Tax Bracket" "Tax Paid on Lower Bound for Added State-Specific Tax Bracket" "Tax Rate for Added State-Specific Tax Bracket" "Exemption for Exemption Adjusted Tax Bracket" "Lower Bound for Exemption Adjusted Tax Bracket" "Upper Bound for Exemption Adjusted Tax Bracket" "Tax Paid on Lower Bound for Exemption Adjusted Tax Bracket" "Tax Rate for Exemption Adjusted Tax Bracket" "Lower Bound for Effective State-Specific Tax Bracket" "Upper Bound for Effective State-Specific Tax Bracket" "Tax Paid on Lower Bound for Effective State-Specific Tax Bracket" "Tax Rate for Effective State-Specific Tax Bracket" "Lower Bound for Effective Tax Bracket" "Upper Bound for Effective Tax Bracket" "Tax Paid on Lower Bound for Effective Tax Bracket" "Tax Rate for Effective Tax Bracket" "Lower Bound for State Effective Tax Bracket" "Upper Bound for State Effective Tax Bracket" "Tax Paid on Lower Bound for State Effective Tax Bracket" "Tax Rate for Federal Plus Tax Bracket" "Lower Bound for Visualization Tax Bracket" "Upper Bound for Visualization Tax Bracket" "Tax Paid on Lower Bound for  Visualization Tax Bracket" "Tax Rate for Visualization Tax Bracket" "Class II" "Class II Exemption" "Lower Bound for Class II Tax Bracket" "Upper Bound for Class II Tax Bracket" "Tax Paid on Lower Bound for Class II Tax Bracket" "Tax Rate for Class II Tax Bracket" "Class III" "Class III Exemption" "Lower Bound for Class III Recipients" "Upper Bound for Class III Tax Bracket" "Tax Paid on Lower Bound for Class III Tax Bracket" "Tax Rate for Class III Tax Bracket" "Months to File Estate Tax" "Months to File Inheritance Tax" "Notes About Related Taxes" "Final Notes" "Source 1" "Source 2" "Source 3" "Source 4" "Source 5" "Source 6" "Source 7" "Top Rate for Gift Tax" "Top Rate for Estate/Inheritance Tax" "Top Rate for Estate Tax" "Top Rate for Inheritance Tax" "Lowest Rate for Estate Tax" "Lowest Rate for Inheritance Tax" "Top Rate Applicable From""
local abbrv_name "curren conver residb eigsta eigfir esttax giftax inhtax pickup pickad itaxre ieexem gifuni gsttst gifint totrev eitrev gifrev fedrev refrev locrev tprrev fprrev rprrev lprrev trvgdp frvgdp rrvgdp regeig regonl gintpr gyrspr gexper gilobo giupbo gtlobo gifrat gannex glfexe tgibas gifval gnotes flthre crincl notess taxbas feffex fec1lb fec1up fe1tlb fe1tsm class1 spoexe chiexe cl1exe sec1lb sec1up se1tlb se1tsm cota1e cotalb cotaup cottlb cotstm adexem ad1lbo ad1ubo ad1tlb ad1smr of1lbo of1ubo of1tlb of1smr ef1lbo ef1ubo ef1tlb ef1smr srv1lb srv1ub srv1tl srv1sm cl1lbo cl1ubo cl1tlb cl1smr class2 cl2exe cl2lbo cl2ubo cl2tlb cl2smr class3 cl3exe cl3lbo cl3ubo cl3tlb cl3smr monest moninh finnot relnot sourc1 sourc2 sourc3 sourc4 sourc5 sourc6 sourc7 gtopra toprat etopra itopra elowra ilowra torac1"

		local n: word count `full_name'

		forvalues i = 1/`n' {
			local a : word `i' of `full_name'
			local b : word `i' of `abbrv_name'
			qui replace varname="`a'" if varname=="`b'"
		}

		gen brac = substr(varcode, -2,2)
			destring brac, replace
			tostring brac, replace

		forvalues i = 1/30 {
			qui replace brac="`i'th Bracket" if brac=="`i'"
		}
		
			qui replace brac = subinstr(brac,"1th","1st",.)
			qui replace brac = subinstr(brac,"2th","2nd",.)
			qui replace brac = subinstr(brac,"3th","3rd",.)
			qui replace brac = subinstr(brac,"11st","11th",.)
			qui replace brac = subinstr(brac,"12nd","12th",.)
			qui replace brac = subinstr(brac,"13rd","13th",.)
			qui replace brac = "Not Bracket-Specific" if brac=="0"

		local op "("
		local cp ")"
		gen longname = ///
	"Taxes and Transfers: " + vartype + " " + varname + " (" + brac + ")"

	*** prepare to be appended 
		qui gen value = real(value_string)
			qui rename value_string value_str 
			*qui replace value_str = "" if !missing(value)
			qui replace value_str = subinstr(value_str, ",","", .)
			qui replace value_str = subinstr(value_str, ";","", .)
			qui replace value_str = subinstr(value_str, `"""',  "", .)
			qui replace value_str = subinstr(value_str, char(10),  "", .)
			qui replace value_str = subinstr(value_str, char(13),  "", .)
			*qui replace value_str = substr(value_str, 1, 126)

		*qui split area, parse(-)
		*drop area
		*	qui rename (area1 area2) (area geo_reg), replace

			gen geo_reg = "" // Remove when including states	
			
			
			
			
		*** only keep countries that appear in dictionary	
		gen GEO = area 
			
			preserve  // save current doc for merging
			
				qui import excel "handmade_tables/dictionary.xlsx", sheet("GEO")  firstrow  clear
				keep GEO
				keep if GEO != ""
				save "raw_data/eigt/intermediary_files/GEO.dta" , replace

			restore			
		
			cap drop _merge 
			qui merge m:1 GEO using "raw_data/eigt/intermediary_files/GEO.dta"
			
			keep if _merge == 3
			
			drop _merge
			
		drop GEO	
			
		
			
	
********************************************************************************
*** STEP 2: Save and export eig warehouse
********************************************************************************			
	qui replace value_str = "" if !missing(value)
	qui export delimited area year value value_str ///
		percentile varcode source c_citekey longname ///
		using "raw_data/eigt/eigt_ready.csv", replace  

	qui save "raw_data/eigt/eigt_ready.dta", replace


