// CS


** Set paths here
global intermediate_to_erase "${topo_dir_raw}/CS_topo/intermediate to erase"
global origin "${topo_dir_raw}/CS_topo/raw data"
global aux "${topo_dir_raw}/CS_topo/auxiliary files"
global intermediate "${topo_dir_raw}/CS_topo/intermediate"


//import raw data

use "${origin}/wealth_data_wide.dta", clear


* Filter by specific variables
qui  keep if var == "totw" | var == "totf" | var == "totn" | var == "totd"


* Step 1: Specify the data structure before reshaping
qui  reshape long v_, i(level country c3 region var wealth_rank data_quality EuroZone emerging vname) j(year)

* Step 2: Rename the variable for clarity
qui  rename v_ value


*Data quality at least "fair"
qui  keep if data_quality>2

// the next to lines make the variable names the same to those on CS website
drop if c3==""


qui kountry c3, from(iso3c) to(iso2c)

qui  rename _ISO2C_ c2

qui  rename vname varname_source

qui rename var source_code
qui keep if year==2023

qui keep c2   varname_source source_code
replace varname_source  = subinstr(varname_source, " ($)", "", .)

qui gen na_code=""
qui  gen nacode_label=""

qui rename c2 area

// generate sector variable
qui gen sector = "hs"


qui levelsof area,  local(ctr)

tempfile grid_c
save `grid_c' 

foreach c of local ctr {
use `grid_c', clear
qui keep if area == "`c'"
qui export excel "${intermediate}/grid", sheet("`c'_hs", replace) firstrow(variables) 	
}
