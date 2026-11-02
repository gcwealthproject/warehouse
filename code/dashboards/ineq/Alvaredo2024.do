** Alvaredo 2016
********************************************************************************
clear all

local source Alvaredo2024

** Working Directories Local
********************************************************************************

global ineq_dir_raw raw_data/ineq

	local sourcef "${ineq_dir_raw}/`source'"
	local pt1 "`sourcef'/raw data/Figure1_EW_with_bands.csv"
	local pt2 "`sourcef'/raw data/Cartel1.xlsx"
	local results "`sourcef'/final_table/`source'"
	
	
		
********************************************************************************
** Part 1
********************************************************************************
import delimited "`pt1'" ,  clear 
	
rename france_year_heterogeneous france_year
keep *_year *_estate_simplified	
drop *band_year

foreach cc in uk italy korea france us australia {
	preserve
	
		keep `cc'*
		rename `cc'_year year
		rename `cc'_esta value	
		
		gen percentile="p99p100"
		gen source ="`source'"
		gen area="`cc'"
		
		replace percentile="p99.9p100" if area=="us"
		
		order area year value percentile source
		drop if value==.
		tempfile a`cc'
		save `a`cc'', replace
	restore
}


** 
clear
foreach cc in uk italy korea france us australia {
	append using `a`cc''
}
replace value=value*100 if area=="us"

/*
label variable year ""
label variable value ""
foreach cc in uk italy korea france us australia {
	twoway (connect value year if area=="`cc'") , name(`cc', replace)
}
graph combine australia france italy korea uk us, col(2)
*/

gen varcode="t-hs-dsh-netwea-ia"

replace area="UK" if area=="uk"
replace area="IT" if area=="italy"
replace area="KR" if area=="korea"
replace area="FR" if area=="france"
replace area="US" if area=="us"
replace area="AU" if area=="australia"

tempfile part1
save `part1'
		
********************************************************************************
** Part 2
********************************************************************************
foreach cc in  Belgium Japan SouthAfrica {
import excel using "`pt2'" ,  clear sheet("`cc'") firstrow
	
	rename Year year	
	ds year, not
	local XX = r(varlist)

	foreach var of local XX {
		preserve
			keep year `var'
			rename `var' value
			
			gen percentile="`var'"
			gen area="`cc'"
			gen source="`source'"
			gen varcode="t-hs-dsh-netwea-ia"
			
			tempfile a`var'
			save `a`var'' , replace
		restore
	}
	
	clear 
	foreach var of local XX {
		append using  `a`var'' 
	}
	
	tempfile a`cc'
	save `a`cc'', replace
	
}	

clear 
foreach cc in Belgium Japan SouthAfrica {	
	append using `a`cc''
}
	
**	
replace area="BE" if area=="Belgium"
replace area="JP" if area=="Japan"
replace area="ZA" if area=="SouthAfrica"	
	
drop if percentile=="Top01externaltotal"
drop if percentile=="Top001externaltotal"	
	
** Keep internal total	
replace percentile="Top01" 	if 	percentile=="Top01internaltotal"
replace percentile="Top001" 	if 	percentile=="Top001internaltotal"
	
replace percentile="p90p100" if percentile=="Top10"
replace percentile="p99p100" if percentile=="Top1" 	
replace percentile="p99.9p100" if percentile=="Top01"
replace percentile="p99.99p100" if percentile=="Top001" 	
	
	
tab percentile, m	
	
tempfile part2
save `part2', replace




** Appned
********************************************************************************
clear
use `part1'
append using `part2'


** Still Missing data from Figure 2!!!	


** Save
//export
order area year value percentile varcode source
qui export delimited "`results'", replace 	

	
	
	
	
	
	
	
	