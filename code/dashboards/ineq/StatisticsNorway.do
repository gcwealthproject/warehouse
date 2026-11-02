// Update of Stat Norway


clear all

local source "StatisticsNorway"


** Working Directories Local
********************************************************************************
*global path	"`:env USERPROFILE'/OneDrive - Universita degli Studi Roma Tre\Research\GC - Update"
*cd "$path"

global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"
	local rawdata "`sourcef'/raw data/Statistics_Norway_2026_04_01.csv"
	local results "`sourcef'/final_table/`source'"
********************************************************************************




import delimited "`rawdata'" , clear 
** Assets: unit Millions of Dollars


********************************************************************************
** Rename Variables
********************************************************************************
keep if _n<=15
br

rename share share_2010
rename average average_2010
rename lowest lowest_2010
rename number number_2010

local v=6
forvalues y=2011(1)2024 {
foreach var in share average lowest number {
		
		rename v`v' `var'_`y'
		
		local v=`v'+1
}	
}

drop number*
destring lowest*, replace force



********************************************************************************
** Reshape Data
********************************************************************************
forvalues y=2010(1)2024 {
foreach var in share average lowest {
	preserve
		keep decile `var'_`y'
		gen year=`y'
		gen varcode="`var'"
		rename `var'_`y' value
		
		tempfile `var'_`y'
		save ``var'_`y'', replace
	restore
}
}

clear
forvalues y=2010(1)2024 {
foreach var in share average lowest {
	append using ``var'_`y''
}
}


** Clean
********************************************************************************
gen percentile="p0p100" if decile=="Total"
replace percentile="p0p100" 	if decile=="Total"
replace percentile="p0p10" 	if decile=="Decile 1"
replace percentile="p10p20" 	if decile=="Decile 2"
replace percentile="p20p30" 	if decile=="Decile 3"
replace percentile="p30p40" 	if decile=="Decile 4"
replace percentile="p40p50" 	if decile=="Decile 5"
replace percentile="p50p60" 	if decile=="Decile 6"
replace percentile="p60p70" 	if decile=="Decile 7"
replace percentile="p70p80" 	if decile=="Decile 8"
replace percentile="p80p90" 	if decile=="Decile 9"
replace percentile="p90p100" 	if decile=="Decile 10"
replace percentile="p95p100" 	if decile=="Top 5 per cent"
replace percentile="p99p100" 	if decile=="Top 1 per cent"
replace percentile="p99_9p100" 	if decile=="Top 0,1 per cent"


drop if percentile==""
drop if varcode=="share" & percentile=="p0p100"
drop if varcode=="lowest" & percentile=="p0p100"
drop if varcode=="lowest" & percentile=="p0p10"
drop decile

** Add Some Extra Points
********************************************************************************
	
	** Shares
	preserve
		keep if varcode=="share"
		reshape wide value , i(year) j(percentile) string

		gen valuep0p50=valuep0p10	+ valuep10p20	+ valuep20p30	+ valuep30p40	+ valuep40p50
		gen valuep0p80=valuep0p50	+ valuep50p60	+ valuep60p70	+ valuep70p80
		gen valuep0p90=valuep0p80	+ valuep80p90

		gen valuep50p90=valuep50p60 + valuep60p70 	+ valuep70p80 	+ valuep80p90

		gen valuep80p100=valuep80p90 + valuep90p100 	

		gen valuep90p95=valuep90p100-valuep95p100
		gen valuep90p99=valuep90p100-valuep99p100

		reshape long value , i(year) j(percentile) string

		replace varcode="t-hs-dsh-netwea-ho"

		tempfile share
		save `share', replace
	restore
	
	
	** Averages
	preserve
		keep if varcode=="average"
		reshape wide value , i(year) j(percentile) string

		gen valuep0p50=(valuep0p10	+ valuep10p20	+ valuep20p30	+ valuep30p40	+ valuep40p50)/5
		gen valuep0p80=(valuep0p50	+ valuep50p60	+ valuep60p70	+ valuep70p80)/8
		gen valuep0p90=(valuep0p80	+ valuep80p90)/9

		gen valuep50p90=(valuep50p60 + valuep60p70 	+ valuep70p80 	+ valuep80p90)/4

		gen valuep80p100=(valuep80p90 + valuep90p100)/2	

		
		reshape long value , i(year) j(percentile) string

		replace varcode="t-hs-avg-netwea-ho"

		tempfile average
		save `average', replace
	restore
	
	
	
	** Threshold
	preserve
		keep if varcode=="lowest"
		
		replace varcode="t-hs-thr-netwea-ho"

		tempfile lowest
		save `lowest', replace
	restore
	
	
** Append
clear
use `share'
append using `average'
append using `lowest'
gen source = "`source'"
gen area="NO"

order area year value percentile varcode source