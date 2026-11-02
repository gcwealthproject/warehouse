//settings
clear all

*global path 	"`:env USERPROFILE'/Dropbox/gcwealth"
*cd "$path"

local source Blanchet2023
run "code/mainstream/auxiliar/all_paths.do"
run $memorize_labels

//define internal paths 
local sourcef "${ineq_dir_raw}/`source'"
local data 		"`sourcef'/raw data"
local results 	"`sourcef'/final_table/`source'"


********************************************************************************
// The series are presented as a multiple of average national income for each country/year
********************************************************************************

	// This Dataset is more Complete as it present Welath Aggregates 
	// but it does not have all years avalilbe
	// Stilluseful in case we want to add more ineq indicators

	use "`data'/data.dta" , clear
	
	****************************************************************************
	** Graphical Checks
	****************************************************************************
	// Panel (a) Figure 1 - W/Y
	replace macro_wealth=macro_wealth*100
	
	
	// Panel (b) Figure 1 - Top 1%
	bys iso year: egen total=total(n)
	
	bys iso year: gen wealth_share=((wealth*n)/(macro_wealth))*(10000/total)
	bys iso year: egen help=total(wealth_share)
	sum help
	bys  iso year: 	egen top1=total(wealth_share) if p>=99000
	
	
	// Collpase by Year and Country
	collapse top1 macro_wealth, by(iso year)
	
	
	// Drop  IS and NL --> can not plot top1
	drop if top1==.		
	
	levelsof iso , c local(area)
	
	gen twoway="" 
	gen legend=""
	local x=1
	foreach aa of local area {
		replace twoway=twoway+"(line top1 year if iso=="+`" ""'+"`aa'"+`"""' +"& year>=1970 & year<=2018 , lc(gray))"
		if "`aa'"=="US" {
			replace twoway=twoway+"(line top1 year if iso=="+`" ""'+"`aa'"+`"""' +"& year>=1970 & year<=2018 , lc(red))"
		}
		replace legend=legend+"`x' "+`" ""'+"`aa'"+`"""' 
		local x=`x'+1
	}
	
	levelsof twoway, c local(twoway)
	levelsof legend, c local(legend)
	
	twoway `twoway' , legend(order(`legend')) scheme(  stcolor )
	
	
	
	
********************************************************************************
// Updated Dataset
****************************************************************************
	clear	
	use "`data'/wealth-gperc-all.dta" 

	
	// Panel (b) Figure 1 - Top 1%
	bys  iso year: 	egen top1=total(s) if p>=99000
	
	// Collpase by Year and Country
	collapse top1 , by(iso year)
		
	// Drop  IS and NL --> can not plot top1
	drop if top1==.		
	replace top1=top1*100
	
	levelsof iso , c local(area)
	
	
	****************************************************************************
	// Graph
	****************************************************************************	
	
	// Help With Command lines
			gen twoway="" 
			gen legend=""
			local x=1
			foreach aa of local area {
				replace twoway=twoway+"(line top1 year if iso=="+`" ""'+"`aa'"+`"""' +"& year>=1970 & year<=2018 , lc(gray))"
				if "`aa'"=="US" {
					replace twoway=twoway+"(line top1 year if iso=="+`" ""'+"`aa'"+`"""' +"& year>=1970 & year<=2018 , lc(red))"
				}
				replace legend=legend+"`x' "+`" ""'+"`aa'"+`"""' 
				local x=`x'+1
			}
			
			levelsof twoway, c local(twoway)
			levelsof legend, c local(legend)
	
	twoway `twoway' , legend(order(`legend')) scheme(  stcolor ) ylabel(10(5)40)
	
	
	
	
	// Harmonize
	****************************************************************************
	drop twoway legend
	
	rename iso area
	rename top1 value
	
	gen source="`source'"
	gen percentile="p99p100" 
	gen varcode="t-hs-dsh-netwea-es"
	
	replace area="UK" if area=="GB"
	
	export delimited "`results'" , replace
