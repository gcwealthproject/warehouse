
********************************************************************************
// Bulid 2 datest:
** 1) ECB_DWA_ineq as usual for Inequality Trends
** 2) ECB_DWA_distr_topo with distributiuonal Topography Info
********************************************************************************

clear all

local source ECB_DWA_ineq
* Dataset last update: 25 November 2025 11:00 CET


** Working Directories Local
********************************************************************************
global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"
	local rawdata "`sourcef'/raw data/data.csv"
	local results "`sourcef'/final_table/`source'"
********************************************************************************

import delimited "`rawdata'", clear
drop if obs_value==.
drop 	ref_sector key valuation trans ///
		obs_status conf_status title_compl data_comp compiling_org ///
		pre_break_value comment_obs freq time_per_collect diss_org time_for comment_ts

order ref_area time_period dwa_grp unit_measure obs_value unit_* decimals
recast double obs_value , force		

********************************************************************************	
// Prepare
********************************************************************************
	
	// Help
	split title , p(" - ")
	
	// Area
	rename ref_area area
	
	// Year + isolate q4
	gen year=substr(time_period,1,4)	
		gen trim=substr(time_period,7,8)
		destring year trim, replace
		keep if trim==4
		drop trim
		tostring year, replace
		replace time_period=year
		drop year
		rename time_period year
		destring year, replace
	
	*keep if year==2020
		
	
	// value
	gen value=.
	
	
	// Percentiles
	gen percentile=""
	
	replace percentile="p0p50" 		if dwa_grp=="B50"
	replace percentile="p90p100" 	if dwa_grp=="D10"
	replace percentile="p50p60" 	if dwa_grp=="D6"
	replace percentile="p60p70" 	if dwa_grp=="D7"
	replace percentile="p70p80" 	if dwa_grp=="D8"
	replace percentile="p80p90" 	if dwa_grp=="D9"
	replace percentile="p0p100"		if dwa_grp=="_Z"
	replace percentile="p95p100"	if dwa_grp=="T5"
	keep if percentile!=""
	
	// Varcode
	gen varcode_1=""	
	gen varcode_2=""
	gen varcode=""
	
	
	// source
	gen source="`source'"
	
	
	
	tempfile STARTINGPOINT
	save `STARTINGPOINT'
	
	
	
	
	
	
	
********************************************************************************
** Extract Infomrations for "usual" Ineq Trends Estimates
******************************************************************************** 	
clear 	
use `STARTINGPOINT'


	// Drop Useless groups
	foreach grp in  HSO HST WSE WSR WSS WSU WSX  {
		drop if dwa_grp=="`grp'"
	}
	
	** Drop IA series
	drop if unit_measure=="EUR_R_POP"	
	
	
	********************************************************************************
	// Gini
	********************************************************************************
	preserve
		keep if unit_measure=="GI"
		
		replace value=obs_value
		replace varcode="t-hs-gin-netwea-ho"	// HHs
		replace percentile="p0p100"
		
		
		keep area year value percentile varcode source
		list in 1/10
		
		
		tempfile gini
		save `gini', replace
	restore		
	
	
	********************************************************************************
	// Top 5% Wealth Share - only available for Net Wealth
	********************************************************************************
	preserve
		keep if unit_measure=="PT"	& dwa_grp=="T5"
		
		replace value=obs_value
		replace varcode="t-hs-dsh-netwea-ho"	// HHs
		replace percentile="p95p100"
		
		
		keep area year value percentile varcode source
		
		
		tempfile top5
		save `top5', replace
	restore		
	drop if dwa_grp=="T5"
	
	
	
********************************************************************************
// Calulate Totals, Averages and Shares
********************************************************************************
clear 	
use `STARTINGPOINT'

		
	// Drop Useless groups - I only need Deciles
	** Note that D1 D2 D3 D4 D5 --> only have "Adjusted debt to asset ratio of households" and we do not need it!
		foreach grp in  HSO HST WSE WSR WSS WSU WSX ///
						D1 D2 D3 D4 D5 T10 T5 /*_Z*/ {
		drop if dwa_grp=="`grp'"
	}
	
	
	
// 1.a rename "instr_asset" into GC-wealth VARIABLES names
********************************************************************************
qui gen na_code= account_entry + "_A" + instr_asset
replace na_code="NWA" if na_code=="N_ANWA"
replace na_code="ANUB" if na_code=="A_ANUB"
replace na_code="ANUN" if na_code=="A_ANUN"			
drop account_entry instr_asset sto


// 1.b Select Assets to use - looking at column "compostion2" of "composition table DWA.xlsx""
********************************************************************************
keep if na_code=="NWA"	///
		| na_code=="ANUB"	///
		| na_code=="A_AF2M"	///
		| na_code=="A_AF3"	///
		| na_code=="A_AF52"	///
		| na_code=="A_AF511"	///
		| na_code=="A_AF51M"	///
		| na_code=="A_AF62"	///
		| na_code=="A_AF_NNA"	///
		| na_code=="L_AF_NNA"	///
		| na_code=="ANUN"	///
		| na_code=="L_AF4B"	
	
	
// 1.c Express value in Euros
********************************************************************************
replace value=obs_value*10^unit_mult 
drop unit_mult decimals
format  value %20.2fc
	
	
// 1.d Focus on Totals and Averages
********************************************************************************
keep 	if unit_measure=="EUR" 			/// 	Total
		|  unit_measure=="EUR_R_NH" 	/// 	Total divided number of HHs
		/// |  unit_measure=="EUR_R_POP" 	/// 	Total divided number of Individuals
				
	
	
	
	
// 1.e Relevant Variables
********************************************************************************
		
		** Net Wealth
		global netwea ="NWA"
		global netwea_label="Net Wealth"
		
		** Real Estate
		global nfahou ="ANUN"
		global nfahou_label="Housing & Land"
	
		** Fiancial Assets
		global nnhass = "ANUB A_AF2M A_AF3 A_AF52 A_AF511 A_AF51M A_AF62"
		global nnhass_label = "Financial Assets & Fixed Capital of Personal Businesses"
		
		** Durables - Not avialbe
		
		** Debt
		global fliabi = "L_AF_NNA"
		global fliabi_label="Debt"
		
		** All Assets
		*global assets = "A_AF_NNA"
		*global assets_label="Assets"
		
			
			
// 1.e Adjust Varcode
********************************************************************************


// 1.f Isolate Relevant Variables
********************************************************************************
keep area year value percentile unit_measure source na_code




// 1.d Extract populations for Calulation of Averages
********************************************************************************
	preserve
		keep if na_code=="NWA"
	
			** Total Wealth
			bys area year (unit_measure): gen help_tot=value if unit_measure=="EUR" & percentile=="p0p100"
			bys area year (unit_measure): egen tot=max(help_tot)
			
			** Total Wealth by Percentile
			bys area year percentile (unit_measure): gen help_tot_in_p=value if unit_measure=="EUR"
			bys area year percentile (unit_measure): egen tot_in_p=max(help_tot_in_p)

			** N of HHs and IAs
			gen pop=tot_in_p/value
	
			keep area year percentile unit_measure pop
			list 
			
			tempfile pop
			save `pop', replace
		restore
	
	merge m:1 area year percentile unit_measure using `pop'
	drop _m
	
	

	
********************************************************************************
// 2. Calulate Relevant Indicators by Asset Class
********************************************************************************
tempfile xxx
save `xxx', replace

foreach concept in netwea nfahou nnhass fliabi {
	
	clear
	use `xxx' 
	
	** Create Asset Category
	gen help=.
	foreach var in ${`concept'} {
		replace help=1 if na_code=="`var'"
	}
	
	keep if help==1
	
	** Generate Value summing all assets intso relevant class
	collapse (sum) value (max) pop, by(area year percentile unit_measure source)
	
	
	************************************************************************
	** Extract Totals
	************************************************************************
	preserve
		keep if unit_measure=="EUR"
		gen varcode="t-hs-tot-`concept'-ho" 
		
		** Reshape Data
		reshape wide value, i(area year varcode source) j(percentile) string
		
			* Bottom cumulative shares 
			gen valuep0p60   = valuep0p50  + valuep50p60              // Bottom 60
			gen valuep0p70   = valuep0p60  + valuep60p70              // Bottom 70
			gen valuep0p80   = valuep0p70  + valuep70p80              // Bottom 80
			gen valuep0p90   = valuep0p80  + valuep80p90              // Bottom 90
			
			* Mid 40 (p50-p90)
			gen valuep50p90  = valuep50p60 + valuep60p70 + valuep70p80 + valuep80p90

			* Top 20 (p80-p100)
			gen valuep80p100 = valuep80p90 + valuep90p100
		
		* Reshape new indicators back to long format 
		reshape long value, i(area year varcode source) j(percentile) string
		
		drop unit pop
		
		** Save
		tempfile tot
		save `tot', replace
	restore
	
	
	************************************************************************
	** Extract Averages
	************************************************************************
	preserve
		keep if unit_measure=="EUR_R_NH"
		gen varcode="t-hs-avg-`concept'-ho" 
		
		
		** Reshape Data
		reshape wide value pop, i(area year varcode source) j(percentile) string
		
			** Exapnd Averages - Note we do not have average in Top 5%
			gen popp0p60   = popp0p50  + popp50p60
			gen popp0p70   = popp0p60  + popp60p70
			gen popp0p80   = popp0p70  + popp70p80
			gen popp0p90   = popp0p80  + popp80p90
			gen popp50p90  = popp50p60 + popp60p70 + popp70p80 + popp80p90
			gen popp80p100 = popp80p90 + popp90p100
			
			* Bottom
			gen valuep0p60   = (valuep0p50*popp0p50   + valuep50p60*popp50p60)  / (popp0p50  + popp50p60)
			gen valuep0p70   = (valuep0p60*popp0p60   + valuep60p70*popp60p70)  / (popp0p60  + popp60p70)
			gen valuep0p80   = (valuep0p70*popp0p70   + valuep70p80*popp70p80)  / (popp0p70  + popp70p80)
			gen valuep0p90   = (valuep0p80*popp0p80   + valuep80p90*popp80p90)  / (popp0p80  + popp80p90)

			* Mid 40
			gen valuep50p90  = (valuep50p60*popp50p60 + valuep60p70*popp60p70 	///
							+  valuep70p80*popp70p80 + valuep80p90*popp80p90)  ///
							/ (popp50p60 + popp60p70 + popp70p80 + popp80p90)

			* Top 20
			gen valuep80p100 = (valuep80p90*popp80p90 + valuep90p100*popp90p100) / (popp80p90 + popp90p100)
						
			
		* Reshape new indicators back to long format 
		reshape long value, i(area year varcode source) j(percentile) string
		drop pop* unit_measure
		
		list in 1/100
		
		** Save
		tempfile avg
		save `avg', replace
	restore
	
	
	
	clear
	use `tot'
	append using `avg'
	
	
	tempfile a`concept'
	save `a`concept'', replace
	
}


// 3. Append All Datasets, so far
********************************************************************************
clear
use `gini'
append using `top5' 

foreach concept in netwea nfahou nnhass fliabi {
	append using `a`concept''
}




// 3. Calulate Shares (dsh)
********************************************************************************
preserve
	split varcode , p(-)
	keep if varcode3=="tot"
	
	bys area year: gen help=value if varcode=="t-hs-tot-netwea-ho" & percentile=="p0p100"
	bys area year: egen den=max(help)
	
	** Genrate Shares
	replace value=(value/den)*100
	drop help den
	
	** Rename Varcode
	replace varcode3="dsh"
	replace varcode=varcode1+"-"+varcode2+"-"+varcode3+"-"+varcode4+"-"+varcode5
	drop varcode1 varcode2 varcode3 varcode4 varcode5
	
	tempfile dsh
	save `dsh', replace
restore


// 4. Clean Dataset
********************************************************************************
append using `dsh'

bys area year percentile varcode: gen N=_n
tab N
keep if N==1
drop N

drop if area=="I9"

drop if varcode=="t-hs-dsh-netwea-ho" & percentile=="p0p100"	
	
	
** Save
//export
order area year value percentile varcode source
qui export delimited "`results'", replace 	
	
	


/*
// Checks
********************************************************************************
	preserve
		keep if area=="IT"
		keep if year==2020
		list
		
		** Isolate Percentiles valid for Distrib Topo 
		foreach concept in nfahou nnhass fliabi {
			gen value_`concept'=value  if varcode=="t-hs-dsh-`concept'-ho"
		}
		
		// Display dshby by percentile
		graph bar value_* , stack over(percentile , label(angle(45)))	name(a, replace)
		
		// Disply dsh/weath share by percentile
		bys area year percentile: gen help=value if varcode=="t-hs-dsh-netwea-ho"  
		bys area year percentile: egen nwshare=max(help)
		
		foreach concept in nfahou nnhass fliabi {
			gen nwshare_`concept'=value/nwshare  if varcode=="t-hs-dsh-`concept'-ho"
		}
		
		graph bar nwshare_* , stack over(percentile , label(angle(45)))	name(b, replace)
		graph combine a b
	restore
*/
	
	
	
	
	
	
	