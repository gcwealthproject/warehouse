cd ~/Dropbox/gcwealth
global user ~/Dropbox/gcwealth

global input_dictionary "${user}/handmade_tables"
global input_metadata "${user}/output/metadata"
global output_documentation "${user}/documentation/warehouse_documentation/docs"



** SECTORS
import excel "${input_dictionary}/dictionary.xlsx", sheet("d2_sector") firstrow clear
keep if code == "hs" | code == "hn" |  code == "np"
keep code label description
label var code "Code"
label var label "Sector"
label var description "Description"
export excel using "${output_documentation}/bible_wt_sectors.xlsx", sheet("sectors") firstrow(varlabels) replace	

** VARIABLE TYPE: CONSOLIDATION
import excel "${input_dictionary}/dictionary.xlsx", sheet("d3_vartype") firstrow clear
keep code label description
keep if code == "agg" | code == "agc" |  code == "agn"
gen ordering = 0
replace ordering = 1 if code == "agc"
replace ordering = 2 if code == "agn"
replace ordering = 3 if code == "agg"
sort ordering
drop ordering
label var code "Code"
label var label "Consolidation status"
label var description "Description"
export excel using "${output_documentation}/bible_wt_consolidation.xlsx", sheet("consolidation") firstrow(varlabels) replace	

** DASHBOARD SPECIFIC: RECORDING OF FINANCIAL POSITION
import excel "${input_dictionary}/dictionary.xlsx", sheet("d5_dboard_specific") firstrow clear
keep if dashboard == "Wealth Topography"
keep code label description
label var code "Code"
label var label "Financial position"
label var description "Description"
export excel using "${output_documentation}/bible_wt_finpos.xlsx", sheet("finpos") firstrow(varlabels) replace	


** WEALTH CONCEPTS
import excel "${input_metadata}/metadata_topo.xlsx", sheet("meta") firstrow clear
drop pos

rename _2_sector_lab sector
drop _1_dasboard
drop _4_concept_lab

* Extract main metadata (common to all sources)
preserve
	
	import excel "${input_dictionary}/dictionary.xlsx", sheet("d4_concept") firstrow clear
	keep code label description
	drop if _n >= 12
	tempfile d4_concept
	save `d4_concept'

restore
	
preserve

	replace metadata = subinstr(metadata, "  ", " ", .) 

	gen findposition = ustrpos(metadata,". In")
	list metadata if findposition == 0
	gen str1 common_metadata = ""
	replace common_metadata = usubstr(metadata,1,	findposition)

	sort common_metadata
	quietly by common_metadata:  gen dup = cond(_N==1,0,_n)
	drop if dup > 1

	replace common_metadata = subinstr(common_metadata, "SNA", "System of National Accounts", .) 

		ds source

	drop area sector source metadata findposition dup
	
	merge 1:1 label using `d4_concept'
	
	drop if _merge != 3 
	drop _merge
	
	gen ordering = 0
	order ordering, first
	replace ordering = 1 if code == "netwea"
	replace ordering = 2 if code == "nnhass"
	replace ordering = 3 if code == "fliabi"
	replace ordering = 4 if code == "fliabm"
	replace ordering = 5 if code == "facdbl"
	replace ordering = 6 if code == "fadepo"
	replace ordering = 7 if code == "faeqfd"
	replace ordering = 8 if code == "falipe"
	replace ordering = 9 if code == "nfabus"
	replace ordering = 10 if code == "nfadur"
	replace ordering = 11 if code == "offsho"
	replace ordering = 12 if code == "etnwea"
	replace ordering = 13 if code == "nfahou"
	replace ordering = 14 if code == "nfhous"
	replace ordering = 15 if code == "nfalan"
	sort ordering
	drop ordering
	
		
	rename common_metadata technical_description
	rename description nontechnical_description

	label var code "Code"
	label var label "Concept"
	label var technical_description "General composition rule"
	label var nontechnical_description "Description"
	
	order code label technical_description nontechnical_description

	keep code label nontechnical_description
	export excel using "${output_documentation}/bible_wt_concepts.xlsx", sheet("concepts") firstrow(varlabels) replace	
	
restore



** GENERAL COMPOSITION TABLE

import excel "${input_metadata}/metadata_topo.xlsx", sheet("meta") firstrow clear
drop pos

rename _2_sector_lab sector
drop _1_dasboard
drop _4_concept_lab

* Extract main metadata (common to all sources)
preserve
	
	import excel "${input_dictionary}/dictionary.xlsx", sheet("d4_concept") firstrow clear
	keep code label description
	drop if _n >= 12
	tempfile d4_concept
	save `d4_concept'

restore
	
preserve

	replace metadata = subinstr(metadata, "  ", " ", .) 
	gen findposition = ustrpos(metadata,". In")
	list metadata if findposition == 0
	gen str1 common_metadata = ""
	replace common_metadata = usubstr(metadata,1,	findposition)

	sort common_metadata
	quietly by common_metadata:  gen dup = cond(_N==1,0,_n)
	drop if dup > 1

	replace common_metadata = subinstr(common_metadata, "SNA", "System of National Accounts", .) 

	drop area sector source metadata findposition dup
	
	merge 1:1 label using `d4_concept'
	
	drop if _merge != 3 
	drop _merge
	
	gen ordering = 0
	order ordering, first
	replace ordering = 1 if code == "netwea"
	replace ordering = 2 if code == "nnhass"
	replace ordering = 3 if code == "fliabi"
	replace ordering = 4 if code == "fliabm"
	replace ordering = 5 if code == "facdbl"
	replace ordering = 6 if code == "fadepo"
	replace ordering = 7 if code == "faeqfd"
	replace ordering = 8 if code == "falipe"
	replace ordering = 9 if code == "nfabus"
	replace ordering = 10 if code == "nfadur"
	replace ordering = 11 if code == "offsho"
	replace ordering = 12 if code == "etnwea"
	replace ordering = 13 if code == "nfahou"
	replace ordering = 14 if code == "nfhous"
	replace ordering = 15 if code == "nfalan"
	sort ordering
	drop ordering
	
		
	rename common_metadata technical_description
	rename description nontechnical_description

	label var code "Code"
	label var label "Concept"
	label var technical_description "General composition rule"
	label var nontechnical_description "Description"
	
	order code label technical_description nontechnical_description

	gen findposition = ustrpos(technical_description," which")
	gen str1 code_description = ""
	replace code_description = usubstr(technical_description,findposition,.)	
	replace code_description = subinstr(code_description, " which is equivalent to:", "", .) 
	replace code_description = subinstr(code_description, ".", "", .) 

	drop findposition 
	gen start_pos = ustrpos(technical_description," (")
	gen str1 wordy_description = ""
	replace wordy_description = usubstr(technical_description,start_pos,.)	
	gen end_pos = ustrpos(wordy_description," which ")	
	gen str1 wordy_description_final = ""
	replace wordy_description_final = usubstr(wordy_description,1,end_pos-1)	
	
	keep code label code_description wordy_description_final
	label var wordy_description_final "Composition rule"
	label var code_description "Composition rule using codes"

	export excel using "${output_documentation}/bible_wt_generalcomposition.xlsx", sheet("generalcomposition") firstrow(varlabels) replace

restore


** SOURCE-SPECIFIC COMPOSITION TABLE
import excel "${input_metadata}/metadata_topo.xlsx", sheet("meta") firstrow clear
drop pos

rename _2_sector_lab sector
drop _1_dasboard
drop _4_concept_lab

gen sector_short = ""
replace sector_short = "hs" if sector == "Households"
replace sector_short = "hn" if sector == "Households & NPISH"
replace sector_short = "np" if sector == "NPISH"

drop sector
rename sector_short sector

tempfile full
save `full'

//

levelsof source, local(source_list)
	
foreach sou of local source_list {
	
		use `full', clear
		
		keep if source == "`sou'" // Keep source only

		tempfile dataset_`sou'
		save `dataset_`sou''

		levelsof sector, local(sector_list)

		foreach sec of local sector_list {

		use `dataset_`sou'', clear
		keep if sector == "`sec'" // Keep sector only


			// Extract specific composition
			gen findposition = ustrpos(metadata,"we use the following formula:")
			list metadata if findposition == 0
			gen str1 specific_composition = ""
			replace specific_composition = usubstr(metadata,findposition,.)
			replace specific_composition = subinstr(specific_composition, "we use the following formula:", " ", .)
			*replace specific_composition = subinstr(specific_composition, " ", "", .)
			replace findposition = ustrpos(specific_composition,".")
			replace specific_composition = usubstr(specific_composition,1,findposition-1)

			drop metadata findposition

			bysort specific_composition: gen frequency = _N
			sort specific_composition frequency
					
			sort specific_composition 
			quietly by specific_composition:  gen dup = cond(_N==1,0,_n)
			drop if dup > 1

			drop area dup

			gen code = "" // generate code
			order code, before(label)
			replace code = "netwea" if label == "Net Wealth"
			replace code = "nnhass" if label == "Financial Assets & Fixed Capital of Personal Businesses"
			replace code = "fliabi" if label == "Debt"
			replace code = "fliabm" if label == "Debt secured by a mortgage"
			replace code = "facdbl" if label == "Cash, Deposits, Bonds & Loans"
			replace code = "fadepo" if label == "Deposits"
			replace code = "faeqfd" if label == "Stocks, Business Equities & Fund Shares"
			replace code = "falipe" if label == "Pensions & Life Insurance"
			replace code = "nfabus" if label == "Fixed Capital of Personal Businesses"
			replace code = "nfadur" if label == "Durable Goods"
			replace code = "offsho" if label == "Offshore Financial Wealth"
			replace code = "etnwea" if label == "Wealth at Death"
			replace code = "nfahou" if label == "Housing & Land"
			replace code = "nfalan" if label == "Land"
			replace code = "nfhous" if label == "Housing"
				

			gen ordering = 0
			order ordering, first
				replace ordering = 1 if code == "netwea"
				replace ordering = 2 if code == "nnhass"
				replace ordering = 3 if code == "fliabi"
				replace ordering = 4 if code == "fliabm"
				replace ordering = 5 if code == "facdbl"
				replace ordering = 6 if code == "fadepo"
				replace ordering = 7 if code == "faeqfd"
				replace ordering = 8 if code == "falipe"
				replace ordering = 9 if code == "nfabus"
				replace ordering = 10 if code == "nfadur"
				replace ordering = 11 if code == "offsho"
				replace ordering = 12 if code == "etnwea"
				replace ordering = 13 if code == "nfahou"
				replace ordering = 14 if code == "nfhous"
				replace ordering = 15 if code == "nfalan"
			sort ordering
			drop ordering

			drop source

			order sector code label specific_composition frequency

			label var sector "Sector"
			label var code "Code"
			label var label "Concept"
			label var specific_composition "Composition rule using codes"
			label var frequency "Frequency"
			* Number of source-sector-concept triple for each composition rule
			
			replace sector = "Households" if sector == "hs"
			replace sector = "Households & NPISH" if sector == "hn"
			replace sector = "NPISH" if sector == "np"

			tempfile sector_`sou'_`sec'
			save `sector_`sou'_`sec''
			
		}
	
	drop _all
	foreach sec of local sector_list {
		append using `sector_`sou'_`sec''
	}
		
	
	
	export excel using "${output_documentation}/bible_wt_source_composition.xlsx", sheet(`sou') sheetreplace firstrow(varlabels) 

	
}



* MANUAL MATCHING TABLES

*FED_B101
global FED_B101 "${user}/raw_data/topo/FED_B101/auxiliary files"

import excel "${FED_B101}/matched_grid_b101.xls", firstrow clear
rename na_code code
keep code source_code varname_source
sort code source_code varname_source
keep if code != ""

replace varname_source = strproper(varname_source) 

label var code "Code" 
label var source_code "Original identifier" 
label var varname_source "Original label" 

export excel using "${output_documentation}/bible_wt_matching.xlsx", sheet(FED_B101) sheetreplace firstrow(varlabels) 


*FED_B101h
global FED_B101h "${user}/raw_data/topo/FED_B101h/auxiliary files"

import excel "${FED_B101h}/matched_grid_b101h.xls", firstrow clear
rename na_code code
keep code source_code varname_source
sort code source_code varname_source
keep if code != ""

replace varname_source = strproper(varname_source) 

label var code "Code" 
label var source_code "Original identifier" 
label var varname_source "Original label" 

export excel using "${output_documentation}/bible_wt_matching.xlsx", sheet(FED_B101h) sheetreplace firstrow(varlabels) 


*FED_B101n
global FED_B101n "${user}/raw_data/topo/FED_B101n/auxiliary files"

import excel "${FED_B101n}/matched_grid_b101n.xls", firstrow clear
rename na_code code
keep code source_code varname_source
sort code source_code varname_source
keep if code != ""

replace varname_source = strproper(varname_source) 

label var code "Code" 
label var source_code "Original identifier" 
label var varname_source "Original label" 

export excel using "${output_documentation}/bible_wt_matching.xlsx", sheet(FED_B101n) sheetreplace firstrow(varlabels) 


*FED_S3a_IMA
global FED_S3a_IMA "${user}/raw_data/topo/FED_S3a_IMA/auxiliary files"

import excel "${FED_S3a_IMA}/matched_grid_s3a.xlsx", firstrow clear
rename na_code code
keep code source_code varname_source
sort code source_code varname_source
keep if code != ""

replace varname_source = strproper(varname_source) 

label var code "Code" 
label var source_code "Original identifier" 
label var varname_source "Original label" 

export excel using "${output_documentation}/bible_wt_matching.xlsx", sheet(FED_S3a_IMA) sheetreplace firstrow(varlabels) 

	
*LWS_topo
global LWS_topo "${user}/raw_data/topo/LWS_topo/raw data/data_download"

import excel "${LWS_topo}/variable_labels.xls", firstrow clear

replace vlabel = strproper(vlabel) 
rename variable code_description
rename vlabel name
label var code_description "Original identifier"
label var name "Original label"
order name code_description 


keep if code_description == "ha" | /// 
	code_description == "hl" | ///
	code_description == "hanncv" | ///
	code_description == "han" | ///
	code_description == "haf" | ///
	code_description == "hl" | ///
	code_description == "has" | ///
	code_description == "hannb" | ///
	code_description == "hafc" | ///
	code_description == "hafib" | ///
	code_description == "hafis" | ///
	code_description == "hafii" | ///
	code_description == "hasi" | /// 
	code_description == "hanr" 


export excel using "${output_documentation}/bible_wt_matching.xlsx", sheet(LWS_topo) sheetreplace firstrow(varlabels) 




*HFCS_topo
global HFCS_topo "${user}/raw_data/topo/HFCS_topo/warehouse/auxiliary files"
import excel "${HFCS_topo}/HFCS_variable_list.xlsx", firstrow clear

rename label name
label var name "Original label"
rename code code_description
label var code_description "Original identifier"
order name code_description 

sort code_description
quietly by code_description:  gen dup = cond(_N==1,0,_n)
drop if dup > 1	
drop dup	
	
export excel using "${output_documentation}/bible_wt_matching.xlsx", sheet(HFCS_topo) sheetreplace firstrow(varlabels) 


*WID_topo: hs
global WID_topo "${user}/raw_data/topo/WID_topo/auxiliary files"
import excel "${WID_topo}/composition table WID.xlsx", sheet("hs info") firstrow clear

rename varname_source name
label var name "Original label"
rename source_code code_description
label var code_description "Original identifier"
keep code_description name
order name code_description 

gen index = _n
drop if index > 18

gen sector = ""
label var sector "Sector"
replace sector = "Households" 
order sector, first
drop index

tempfile WID_hs
save `WID_hs'

*WID_topo: np
import excel "${WID_topo}/composition table WID.xlsx", sheet("np info") firstrow clear

rename varname_source name
label var name "Original label"
rename source_code code_description
label var code_description "Original identifier"
keep code_description name
order name code_description 

gen index = _n
drop if index > 17

gen sector = ""
label var sector "Sector"
replace sector = "NPISH"
order sector, first
drop index

tempfile WID_np
save `WID_np'

*WID_topo: hn
import excel "${WID_topo}/composition table WID.xlsx", sheet("hn info") firstrow clear

rename varname_source name
label var name "Original label"
rename source_code code_description
label var code_description "Original identifier"
keep code_description name
order name code_description 

gen index = _n
drop if index > 18

gen sector = ""
label var sector "Sector"
replace sector = "Households & NPISH" 
order sector, first
drop index

tempfile WID_hn
save `WID_hn'

* append
append using `WID_hs'

append using `WID_np'
export excel using "${output_documentation}/bible_wt_matching.xlsx", sheet(WID_topo) sheetreplace firstrow(varlabels) 


*StatCan 
global StatCan_DWA "${user}/raw_data/topo/StatCan_DWA_topo/auxiliary files"

import excel "${StatCan_DWA}/matched_grid_StatCan.xls", firstrow clear
rename na_code code
keep code source_code varname_source
sort code source_code varname_source
keep if code != ""

replace varname_source = strproper(varname_source) 

label var code "Code" 
label var source_code "Original identifier" 
label var varname_source "Original label" 

export excel using "${output_documentation}/bible_wt_matching.xlsx", sheet(StatCan_DWA_topo) sheetreplace firstrow(varlabels) 


