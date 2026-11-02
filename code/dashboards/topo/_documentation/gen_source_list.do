

cd ~/Dropbox/gcwealth
global user ~/Dropbox/gcwealth

global input_dictionary "${user}/handmade_tables"
global input_data "${user}/output/databases"
global output_documentation "${user}/documentation/warehouse_documentation/docs"

import excel "${input_dictionary}/dictionary.xlsx", sheet("Sources") firstrow clear


keep if AggSource != ""

*replace Citekey = "@"+Citekey if Citekey!=""
*gen legend_extended = Legend+" "+Citekey
gen legend_extended = Legend

order Section Source Legend legend_extended AggSource 
keep Section Source Legend legend_extended AggSource 

tempfile full
save `full'

* Wealth Topography

	use `full', clear 

	keep if Section == "Wealth Topography"

	drop if Legend == "Bank of Italy & Istat - Balance Sheet Data"
	drop if Legend == "Bank of Portugal - Balance Sheet"
	drop if Legend == "OECD - Balance Sheet"

	gen pos = strpos(Legend," - ")
	gen type = substr(Legend, pos+2, .)
	drop pos 

	gen date = ""
	
	/* June 2023 Version
	replace date = "August 1, 2022" if Source == "BoI_FA"
	replace date = "September 29, 2022" if Source == "BoI_NA"
	replace date = "June 26, 2022" if Source == "ECB_IDCSA"
	replace date = "September 5, 2022" if Source == "ECB_QSA"
	replace date = "October 6, 2022" if Source == "Est"
	replace date = "October 28, 2022" if Source == "FED_B101"
	replace date = "October 31, 2022" if Source == "FED_B101h"
	replace date = "November 1, 2022" if Source == "FED_B101n"
	replace date = "October 12, 2022" if Source == "FED_S3a_IMA"
	replace date = "September 27, 2022" if Source == "HFCS_topo"
	replace date = "March 30, 2023" if Source == "LWS_topo"
	replace date = "October 10, 2022" if Source == "OECD_FA"
	replace date = "March 20, 2023" if Source == "WID_topo"
	*/
	
	// September 2023 Version
	replace date = "August 8, 2023" if Source == "BoI_FA"
	replace date = "September 29, 2022" if Source == "BoI_NA"
	replace date = "August 29, 2023" if Source == "ECB_IDCSA"
	replace date = "August 8, 2023" if Source == "ECB_QSA"
	replace date = "August 29, 2023" if Source == "Est"
	replace date = "August 29, 2023" if Source == "FED_B101"
	replace date = "August 29, 2023" if Source == "FED_B101h"
	replace date = "August 29, 2023" if Source == "FED_B101n"
	replace date = "August 28, 2023" if Source == "FED_S3a_IMA"
	replace date = "September 27, 2022" if Source == "HFCS_topo"
	replace date = "March 30, 2023" if Source == "LWS_topo"
	replace date = "August 29, 2023" if Source == "OECD_FA"
	replace date = "August 29, 2023" if Source == "WID_topo"
	

	label var legend_extended "Legend"
	label var AggSource "Source type"
	label var type "Account type"
	label var date "Download date"

	
	order legend_extended AggSource type date Source
	keep legend_extended AggSource type date Source
	
	export excel using "${output_documentation}/bible_wt_sources.xlsx", sheet("sources") firstrow(varlabels) replace	

	
* Wealth Inequality Trends

	import excel "${input_dictionary}/dictionary.xlsx", sheet("Sources") firstrow clear


	drop if Inclusion_in_Warehouse == "No"

	*replace Citekey = "@"+Citekey if Citekey!=""
	*gen legend_extended = Legend+" "+Citekey
	gen legend_extended = Legend

	order Section Source Legend legend_extended AggSource Inclusion_in_Warehouse
	keep Section Source Legend legend_extended AggSource Inclusion_in_Warehouse

	tempfile full
	save `full'

	use `full', clear 
		
		keep if Section == "Wealth Inequality"
	
	gen date = ""

	label var legend_extended "Legend"
	label var AggSource "Source type"
	label var date "Download date"
	
	drop Section Legend
	
	order legend_extended AggSource Source
	keep legend_extended AggSource Source
	
	gen date = ""
	label var date "Download date"

	
	//export excel using "${output_documentation}/bible_ineq_sources.xlsx", sheet("sources") firstrow(varlabels) replace	
	

	
* Estate, Inheritance, and Gift Taxes

	use `full', clear 
	
	keep if Section == "Taxes on Wealth"

	gen date = ""

	label var legend_extended "Legend"
	label var AggSource "Source type"
	label var date "Download date"
	
	drop Section Legend
	
	order legend_extended AggSource Source
	keep legend_extended AggSource Source
	
	gen date = ""
	label var date "Download date"
	
	//export excel using "${output_documentation}/bible_eig_sources.xlsx", sheet("sources") firstrow(varlabels) replace	

