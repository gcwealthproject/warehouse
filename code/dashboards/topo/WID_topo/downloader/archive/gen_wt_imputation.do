//settings
local source WID_topo
run "code/mainstream/auxiliar/all_paths.do"

global aux "${topo_dir_raw}/WID_topo/auxiliary files"


import excel "${aux}/wt_imputations_initial.xlsx", sheet("imputation_wt") firstrow clear

rename countryname Country

* Countries with wealth data available for all asset groups:
replace wt_imputation = 0 if Country == "Australia"
replace wt_imputation = 0 if Country == "Canada"
replace wt_imputation = 0 if Country == "China"
replace wt_imputation = 0 if Country == "Czech Republic"
replace wt_imputation = 0 if Country == "Denmark"
replace wt_imputation = 0 if Country == "Finland"
replace wt_imputation = 0 if Country == "France"
replace wt_imputation = 0 if Country == "Germany"
replace wt_imputation = 0 if Country == "Ireland"
replace wt_imputation = 0 if Country == "Italy"
replace wt_imputation = 0 if Country == "Japan"
replace wt_imputation = 0 if Country == "Korea"
replace wt_imputation = 0 if Country == "Mexico"
replace wt_imputation = 0 if Country == "Netherlands"
replace wt_imputation = 0 if Country == "Norway"
replace wt_imputation = 0 if Country == "Russian Federation"
replace wt_imputation = 0 if Country == "Spain"
replace wt_imputation = 0 if Country == "Sweden"
replace wt_imputation = 0 if Country == "Switzerland"
replace wt_imputation = 0 if Country == "Taiwan"
replace wt_imputation = 0 if Country == "Thailand"
replace wt_imputation = 0 if Country == "United Kingdom"
replace wt_imputation = 0 if Country == "USA"

* Countries with wealth data available for at least two asset groups:
replace wt_imputation = 1 if Country == "Albania"
replace wt_imputation = 1 if Country == "Austria"
replace wt_imputation = 1 if Country == "Barbados"
replace wt_imputation = 1 if Country == "Belarus"
replace wt_imputation = 1 if Country == "Belgium"
replace wt_imputation = 1 if Country == "Bhutan"
replace wt_imputation = 1 if Country == "Bolivia"
replace wt_imputation = 1 if Country == "Brazil"
replace wt_imputation = 1 if Country == "Bulgaria"
replace wt_imputation = 1 if Country == "Chile"
replace wt_imputation = 1 if Country == "Colombia"
replace wt_imputation = 1 if Country == "Congo"
replace wt_imputation = 1 if Country == "Costa Rica"
replace wt_imputation = 1 if Country == "Croatia"
replace wt_imputation = 1 if Country == "Cyprus"
replace wt_imputation = 1 if Country == "Dominican Republic"
replace wt_imputation = 1 if Country == "El Salvador"
replace wt_imputation = 1 if Country == "Estonia"
replace wt_imputation = 1 if Country == "Ethiopia"
replace wt_imputation = 1 if Country == "Georgia"
replace wt_imputation = 1 if Country == "Greece"
replace wt_imputation = 1 if Country == "Hungary"
replace wt_imputation = 1 if Country == "Iceland"
replace wt_imputation = 1 if Country == "India"
replace wt_imputation = 1 if Country == "Indonesia"
replace wt_imputation = 1 if Country == "Israel"
replace wt_imputation = 1 if Country == "Jordan"
replace wt_imputation = 1 if Country == "Kazakhstan"
replace wt_imputation = 1 if Country == "Kyrgyzstan"
replace wt_imputation = 1 if Country == "Latvia"
replace wt_imputation = 1 if Country == "Lithuania"
replace wt_imputation = 1 if Country == "Luxembourg"
replace wt_imputation = 1 if Country == "North Macedonia"
replace wt_imputation = 1 if Country == "Malta"
replace wt_imputation = 1 if Country == "Micronesia"
replace wt_imputation = 1 if Country == "Moldova"
replace wt_imputation = 1 if Country == "New Zealand"
replace wt_imputation = 1 if Country == "Poland"
replace wt_imputation = 1 if Country == "Portugal"
replace wt_imputation = 1 if Country == "Romania"
replace wt_imputation = 1 if Country == "Serbia"
replace wt_imputation = 1 if Country == "Singapore"
replace wt_imputation = 1 if Country == "Slovakia"
replace wt_imputation = 1 if Country == "Slovenia"
replace wt_imputation = 1 if Country == "South Africa"
replace wt_imputation = 1 if Country == "Turkey"
replace wt_imputation = 1 if Country == "Ukraine"
replace wt_imputation = 1 if Country == "United Arab Emirates"
replace wt_imputation = 1 if Country == "Uruguay"

rename Country countryname 

export excel "${topo_dir_raw}/WID_topo/auxiliary files/wt_imputations_final.xlsx", sheet("imputation_wt") firstrow(variables) replace






 