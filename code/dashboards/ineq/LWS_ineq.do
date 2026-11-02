//settings
clear all

local source LWS_ineq

** Working Directories Local
********************************************************************************
*cd "`:env USERPROFILE'/Dropbox/gcwealth"


global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"
	local rawdata_ineq_pt1 "`sourcef'/raw data/LWS_ineq_12Mag2026_pt1.csv"
	local rawdata_ineq_pt2 "`sourcef'/raw data/LWS_ineq_12Mag2026_pt2.csv"
	local rawdata_ineq_pt3 "`sourcef'/raw data/LWS_ineq_12Mag2026_pt3.csv"
	local rawdata_ineq_pt4 "`sourcef'/raw data/LWS_ineq_12Mag2026_pt4.csv"
	local rawdata_ineq_pt5 "`sourcef'/raw data/LWS_ineq_12Mag2026_pt5.csv"
	local rawdata_ineq_pt6 "`sourcef'/raw data/LWS_ineq_12Mag2026_pt6.csv"
	local rawdata_own "`sourcef'/raw data/LWS_ownership_ratio_06Jan2026.csv"
	
	local results "`sourcef'/final_table/`source'"
********************************************************************************


********************************************************************************
// Ineq + Distrib Topo
********************************************************************************

** Append All parts
forvalues v=1(1)6{
	qui import delimited "`rawdata_ineq_pt`v''", clear varnames(1)
	tempfile a`v'
	save `a`v'', replace
}
clear
forvalues v=1(1)6{
	append using `a`v''
} 


** Set all implcates in different columns
drop if missing(value)
drop sd
reshape wide value, i(country year variable) j(impl)

** Make Average across implicates
egen value=rowmean(value1 value2 value3 value4 value5)
drop value1 value2 value3 value4 value5


** Generate Variable
split variable, p(_)
drop variable

** Fix Percentile
rename variable3 percentile

** Fix Varcode
replace variable1="gin" if variable1=="gini"
gen varcode="t-hs-"+variable1+"-"+variable2+"-ho"

** Fix units 
replace value=value*100 if variable1=="dsh"
replace value=value*100 if variable1=="gin"
replace value=-value    if variable2=="fliabi"		// All debt quantites set as negative!


** Fix Source and Area		
gen source="`source'"
rename country area

//order
order area year varcode percentile value source
keep  area year value percentile source varcode

		
//save
tempfile ineq
save `ineq' , replace
 

 
 
********************************************************************************
// OWnership Ratios
********************************************************************************

	qui import delimited using "`rawdata_own'", clear 
	
	
	** rename variables
	rename v1 area
	rename v2 year
		replace year=substr(year,1,4)
		destring year, replace
	rename v3 varcode
	rename v4 value
	rename v5 check
	
	
	// Note: we have different alternative values for same concept:
	** e.g. :
		* nfahou
		* nfahou1
		* nfahou2
		* nfahou3
	** This comes from "\gcwealth\raw_data\topo\LWS_topo\auxiliary files\composition table LWS.xlsx"
	** nfahou is the preferred, in case not availabe (check=0)
	** then use in oreder 1, 2, 3, ...
	gen help=varcode
	replace help = subinstr(help, "1", "", .)
	replace help = subinstr(help, "2", "", .)
	replace help = subinstr(help, "3", "", .)
	replace help = subinstr(help, "4", "", .)
	replace help = subinstr(help, "5", "", .)
	
	drop if check==0		// No variation in Outcome
	drop check
	
	bys area year help (varcode): gen n=_n
	keep if n==1
	replace varcode=help
	drop help n 
	
	sort area year varcode
	replace varcode="t-hs-owr-"+varcode+"-ho"
	
	replace value=value*100
	
	
	
	/*
	
	****************************************************************************
	** Check Time Series hown vs. hhou vs. nfhous
	****************************************************************************
	
	// Note: We have 3 concepts of Housing Ownership:
	** hown --> comes from varialbe "own" -->  OWNERSHIP of house of residence, 
	** hhou --> comes from  holidng of Rela Estate assets
	** nfhous --> should be the combo of the two, prioratizing hown
		preserve
			keep if varcode=="t-hs-owr--ho"  |  varcode=="t-hs-owr-hhou-ho" | varcode=="t-hs-owr-nfhous-ho"  
			tostring year, replace
			
			gen help=area+"-"+year
			encode help , gen(XX)
			
		sum XX
		local max=r(max)
		twoway 		(connect value XX if varcode=="t-hs-owr-hown-ho")		///
					(connect value XX if varcode=="t-hs-owr-hhou-ho"	)	///
					(connect value XX if varcode=="t-hs-owr-nfhous-ho"	)	///
					, legend(order(	1 "own - Do you own residence house?" 	///
									2 "nfhous - Housing assets"	///
									3 "Combo")	///
							pos(6) col(3))	///
					xlabel(1(1)`max', valuelabel angle(90)) scale(0.7)	///
					ysize(5) xsize(15)
		restore
		drop if varcode=="t-hs-owr-hown-ho" 
		drop if varcode=="t-hs-owr-hhou-ho" 
		
		
	gen percentile="p0p100"
	order area year varcode percentile value
	*/
	
	drop if varcode=="t-hs-owr-hhou-ho"
	drop if varcode=="t-hs-owr-hown-ho"
	
	gen lenght=strlen(varcode)
	tab lenght
	drop lenght
	
	gen percentile = "p0p100"
	gen source = "`source'"
	
	//order
	order area year value percentile source varcode

	
	// Select only Some Assets
	split varcode , p(-)
	tab varcode3 
	tab varcode4
	drop if varcode4=="facdbl"
	drop if varcode4=="fadepo"
	drop if varcode4=="fliabm"
	drop if varcode4=="nfadur"
	drop if varcode4=="nfhous"
	drop varcode1 varcode2 varcode3 varcode4 varcode5

	// Save
	tempfile own
	save `own' , replace
********************************************************************************	
	


clear

//append
qui append using `ineq'
qui append using `own'

qui sort area year


//export
qui export delimited "`results'" , replace

// Check
preserve 
bys area year percentile varcode: gen N=_N
tab N
restore

