clear all
local source OECD_wealth




** Working Directories Local
********************************************************************************
*global path	"`:env USERPROFILE'/OneDrive - Universita degli Studi Roma Tre\Research\GC - Update"
*cd "$path"

global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"
	local rawdata "`sourcef'/raw data/OECD_new"
	local results "`sourcef'/final_table/`source'"
********************************************************************************



/*
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${ineq_dir_raw}/`source'"
local rawdata "`sourcef'/raw data/OECD.xlsx"
local results "`sourcef'/final_table/`source'"
*/


///import
import delimited "`rawdata'"

	
drop 	structure structure_id structure_name action freq ///
		frequencyofobservation timeperiod observationvalue unit_mult unitmultiplier
	
	
keep if 	v10=="Net wealth" |	///
			v10=="Share of bottom 40% of wealth" |	///	
			v10=="Share of top 1% of wealth" |	///		
			v10=="Share of top 10% of wealth" |	///		
			v10=="Share of top 5% of wealth" 

rename time_period year	



// Gen Varcode
********************************************************************************
	
	** Dashboard and Sector
	gen dashboard = "t"
	gen sector = "hs"
	
	** Variable Specific
	gen vartype = "" 
	replace vartype = "avg" if statistical_operation=="MEAN"
	replace vartype = "thr" if statistical_operation=="MEDIAN"
	replace vartype = "dsh" if	v10=="Share of bottom 40% of wealth" |	///	
								v10=="Share of top 1% of wealth" |	///		
								v10=="Share of top 10% of wealth" |	///		
								v10=="Share of top 5% of wealth" 
	
	** Concept
	gen concept = "netwea"
	
	
	** Unit
	gen unit = ""
	replace unit="ho" if unitofmeasure=="Percentage of household wealth"
	replace unit="ho" if unitofmeasure=="National currency per household"
	replace unit="ia" if unitofmeasure=="National currency per person"
	
	
	gen varcode=dashboard+"-"+sector+"-"+vartype+"-"+concept+"-"+unit
	
	*************
	drop if varcode=="t-hs-avg-netwea-ia"
	tab varcode
	*************
	
	
	
// Gen percentile
********************************************************************************
	
	gen percentile=""
	replace percentile = "p0p100" 	if vartype == "avg"		// Average
	replace percentile = "p50p90" 	if vartype == "thr"		// Median
	replace percentile = "p0p40"	if measure == "SH_BOT40"
	replace percentile = "p90p100"	if measure == "SH_TOP10"
	replace percentile = "p95p100" 	if measure == "SH_TOP5"
	replace percentile = "p99p100" 	if measure == "SH_TOP1"
	
	
	// Extrapulate Bottom 90%
	*replace percentile = "p0p90" 	if MEASURE == "SH_TOP1"
	
	
	
	drop dashboard sector vartype concept unit 
	drop 	measure v10 unit_measure unitofmeasure 	///
			statistical_operation statisticaloperation 	///
			threshold v16 price_base pricebase
	
	
	
	
// Gen Value
********************************************************************************

	** Some Fixes Need.
	tab varcode decimals

	// Check Unique Currecny
	preserve
		keep if varcode!="t-hs-dsh-netwea-ho"	 
		
		** Count Years
		bys ref_a varcode (year):   gen h_year=_N
		** Count Currecny
		bys ref_a varcode curr (year):   gen h_curr=_N
	
		gen XXX=(h_curr==h_year)
		tab XXX
		** if XXX=1 --> ok!
	restore
			
	
	rename obs_value value
	drop if value==.
	drop decimals v22 obs* currency v26
	
	
	
	
	
	
//gen warehouse variables	
gen source = "`source'"

//clean area names
ssc install kountry
kountry ref_area, from(iso3c) to(iso2c)
drop ref_a refe 
rename _ISO2C_ area
	qui replace area = "UK" if area == "GB"


	
//export
order area year value percentile varcode source
qui export delimited "`results'", replace 	

	