//// DO FILE FOR CURRENCIES IN WID 2024 
// AUTHOR: FRANCESCA
// LAST UPDATE: 15/07/2024

/// Aim: generate an excel file with national currencies form WID data

	clear

// Working directory and paths

	*** automatized user paths
	global username "`c(username)'"
	
	dis "$username" // Displays your user name on your computer

	* Francesca
	if "$username" == "fsubioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	if "$username" == "Francesca Subioli" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth" 
	}	
	
	global dofile "$dir/code/dashboards/eigt"
	global intfile "$dir/raw_data/eigt/intermediary_files"
	global hmade "$dir/handmade_tables"
	global supvars "$dir/output/databases/supplementary_variables"
	                   
	cd "$dir"
	
// Import the currency 

	wid, ind(aptinc) perc(p0p100) metadata clear
	keep country year unit unitlabel
	drop if unit == ""
	duplicates drop
	sort country year
	count if country == country[_n-1] & unit != unit[_n-1]
	drop year 
	duplicates drop 

	local todrop OA OA-MER OB OB-MER OC OC-MER OD OD-MER OE OE-MER OI OI-MER OJ OJ-MER ///
				QB QB-MER QD QD-MER QE QE-MER QF QF-MER QJ QJ-MER QK QK-MER QL QL-MER ///
				QM QM-MER QN QN-MER QO QO-MER QP QP-MER QS QS-MER QT QT-MER QU QU-MER ///
				QV QV-MER QW QW-MER QX QX-MER QY QY-MER WO WO-MER XA XA-MER XB ///
				XB-MER XF XF-MER XL XL-MER XM XM-MER XN XN-MER XR XR-MER XS XS-MER ///
				CN-RU CN-UR

	foreach country of local todrop {
		drop if country == "`country'"
	}  

	rename unit LCU_wid
	rename country GEO
	label var LCU_wid "Local currency in WID data (15/07/2024)"

// Check correspondance with our handmade list of LCU in 2023

// Keep only countries we have in the dictionary
	preserve 
		import excel "$hmade/dictionary.xlsx", sheet("GEO") firstrow clear
		drop if GEO == "_na"
		keep GEO GEO3
		duplicates drop
		tempfile geo
		save "`geo'", replace
	restore
	merge 1:1 GEO using "`geo'", keep(matched) nogen
	
	preserve 
		import excel "$hmade/eigt_currency.xlsx", sheet("LCU2023") firstrow clear
		tempfile currenc
		save "`currenc'", replace
	restore

	merge 1:1 GEO using "`currenc'", keep(matched)

	tab GEO_long if LCU_wid != nat_currency & _m ==3
	tab LCU_wid nat_currency if LCU_wid != nat_currency & _m ==3

// Croatia (HRK in wid, but it's EUR), Venezuela (VEF in wid, but it's VES)

	keep GEO* LCU_wid unitlab 
	order GEO GEO_l LCU unit

// Attach ISO 4217 codes

	preserve 
		import excel "$hmade/eigt_currency.xlsx", sheet("codes") firstrow clear
		tempfile iso
		save "`iso'", replace
	restore

	rename LCU_wid curren
	merge m:1 curren using "`iso'", keep(master matched) 
	drop _m
	
// Use labels 
	cap which labmask
	if _rc ssc install labmask
	
	labmask numericcode, values(curren)
	drop curren 
	rename numericcode LCU_wid
	label var LCU_wid "Local currency in WID data (15/07/2024), ISO4217"	
	rename unit LCU_wid_label
	order GEO* LCU_wid 


