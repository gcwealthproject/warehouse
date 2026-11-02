
clear all
run "code/mainstream/auxiliar/all_paths.do"

local iter = 1
//loop over sources 
foreach f in  OECD_NA Est LWS_topo WID_topo ECB_IDCSA HFCS_topo ///
	BoI_NA ECB_QSA BoI_FA OECD_FA FED_S3a_IMA FED_B101 ///
	FED_B101h FED_B101n AOW ECOW CS_topo ECB_DWA_topo StatCan_DWA_topo { 
	
	//inform activity 
	di as result "working with `f':"
	cap drop if source == "`f'"
	
	//run do files one-by-one 
	preserve 
		//loop over potential do files 
		foreach d in create_grid_stock gen_mapped_grid translate  ///
			gen_metadata gen_topography {
			
			//list what is found 
			local lister : dir "${topo_code}/`f'/" files "`d'*"
			global lister `lister'
		
			local checker = subinstr("$lister", char(34), "", .)
			if "`checker'" != "" {
				//run them one by one 
				foreach dn in "$lister" {
					di as text " ...running ${topo_code}/`f'/`dn'..." _continue
					qui run "${topo_code}/`f'/`dn'"
					di as text " (done)"
				}
			}
		}
	restore
	if `iter' == 1 {
		qui use "${topo_dir_raw}/`f'/final table/`f'_warehouse.dta", clear  
	}
	else {
		qui append using "${topo_dir_raw}/`f'/final table/`f'_warehouse.dta"
	}
	local iter = 0
}


//drop zero and empty values
drop if value == 0
drop if value == .

//drop durable goods
*drop if strpos(varcode,"nfadur") != 0
	
	
*save below 
qui export delimited area sector year value percentile varcode source ///
	using "raw_data/topo/topo_ready.csv", replace 
