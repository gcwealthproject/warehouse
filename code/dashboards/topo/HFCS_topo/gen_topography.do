

global origin "${topo_dir_raw}/HFCS_topo/tables/topography/"
global output1 "${topo_dir_raw}/HFCS_topo/warehouse/final table"
global output2 "${topo_dir_raw}/HFCS_topo/final table"

use "${origin}/aggregates_ho.dta", clear


*qui drop n_group_size
qui gen longname = ""
qui drop label 

qui replace source = "HFCS_topo"

qui gen sector = substr(varcode, 3, 2) // gen sector

qui order area source sector year percentile varcode value longname


qui replace varcode = substr(varcode, 1, 16)
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "netwea"
qui replace varcode = varcode+"ga" if substr(varcode, 10, 6) == "nnhass"
qui replace varcode = varcode+"lb" if substr(varcode, 10, 6) == "fliabi"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "facdbl"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "fadepo"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "faeqfd"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "falipe"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "nfabus"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "nfadur"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "offsho"
qui replace varcode = varcode+"na" if substr(varcode, 10, 6) == "nfahou"
qui replace varcode = varcode+"lb" if substr(varcode, 10, 6) == "fliabm"

*qui destring year, gen(yearr)
*qui drop year 
*qui rename yearr year


save "${output2}/HFCS_topo_warehouse.dta", replace
export delimited using "${output1}/HFCS_topo_warehouse.csv", replace
export delimited using "${output2}/HFCS_topo_warehouse.csv", replace
