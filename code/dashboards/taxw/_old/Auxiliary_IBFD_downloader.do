

	qui import excel "C:/Users/Francesca/Dropbox/gcwealth/handmade_tables/dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
   // No information at all 
   drop if GEO == "_na"
      
	rename Country GEO_long
	duplicates drop
		
	gen geo = strlower(GEO)
	levelsof geo, local(levels)
	
   // Country tax features (Excel)

   local base_url "https://research.ibfd.org/collections/kf/excel/"
   local save_dir "C:/Users/Francesca/Dropbox/gcwealth/handmade_tables/taxsched_input/IBFD/tables/"
   
	foreach country of local levels {
   	    
		local url = "`base_url'kf_`country'.xls"
		local name = strupper("`country'")
		
		cap dir `save_dir'`name'
		
		if _rc != 0 {
			qui mkdir `save_dir'`name'
		}
		else qui cd `save_dir'`name'
		
		cap copy "`url'" "kf_`country'.xls", replace
		if _rc != 0 {
			di as error "File `country' not found or error in download"
		}
		else global found_kf $found_kf `country'
	}

	// Casi anomali
	
   local base_url "https://research.ibfd.org/collections/kf/excel/"
   local save_dir "C:/Users/Francesca/Dropbox/gcwealth/handmade_tables/taxsched_input/IBFD/tables/"
   
	foreach country of local levels {
   	    
		local name = strupper("`country'")
		local letter = substr("`country'", 1, 1)
		local url = "`base_url'kf_`letter'1.xls"
		
		cap dir `save_dir'`name'
		
		if _rc != 0 {
			qui mkdir `save_dir'`name'
		}
		else qui cd `save_dir'`name'
		
		if strpos(" $found_kf ", " `country' ") == 0 {
			cap copy "`url'" "kf_`country'.xls", replace
			if _rc != 0 {
				di as error "File `country' not found or error in download"
			}
			else global found_kf $found_kf `country' 
		}				
	}
	
    // Kosovo
	copy "https://research.ibfd.org/collections/kf/excel/kf_k1.xls" "C:\Users\Francesca\Dropbox\gcwealth\handmade_tables\taxsched_input\IBFD\tables\XK\kf_xk.xls", replace
    global found_kf $found_kf xk

	// Comoros
	copy "https://research.ibfd.org/collections/kf/excel/kf_c5.xls" "C:\Users\Francesca\Dropbox\gcwealth\handmade_tables\taxsched_input\IBFD\tables\KM\kf_km.xls", replace
    global found_kf $found_kf km  
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	// mf and tv not available in source
	
*------------------------------------------------------------------------------*

	levelsof geo, local(levels)
	
    local base_url "https://research.ibfd.org/collections/ita/printversion/pdf/"
    local save_dir "C:\Users\Francesca\Dropbox\gcwealth\handmade_tables\taxsched_input\IBFD\pdf\2025"
   
   foreach country of local levels {
   	    
		local filename = "ita_`country'.pdf"
		local url = "`base_url'`filename'"
		local path = "`save_dir'`filename'"
	   	
		if strpos(" $found_it ", " `country' ") == 0 {
			cap copy "`url'" "`path'", replace
			if _rc != 0 {
				di as error "File `country' not found or error in download"
			}
			else global found_it $found_it `country' 
		}
   }

    local base_url "https://research.ibfd.org/collections/gthb/printversion/pdf/"
    local save_dir "C:\Users\Francesca\Dropbox\gcwealth\handmade_tables\taxsched_input\IBFD\pdf\2025"
   
   levelsof geo, local(levels)
   foreach country of local levels {
   	    
		local filename = "gthb_`country'.pdf"
		local url = "`base_url'`filename'"
		local path = "`save_dir'`filename'"
	   	
		if strpos(" $found_it ", " `country' ") == 0 {
			cap copy "`url'" "`path'", replace
			if _rc != 0 {
				di as error "File `country' not found or error in download"
			}
			else global found_it $found_it `country' 
		}
   }

    // Kosovo
	copy "https://research.ibfd.org/collections/gthb/printversion/pdf/gthb_k1.pdf" "C:\Users\Francesca\Dropbox\gcwealth\handmade_tables\taxsched_input\IBFD\pdf\gthb_k1.pdf", replace
    global found_it $found_it xk   
    
	// Comoros
	copy "https://research.ibfd.org/collections/gthb/printversion/pdf/gthb_c5.pdf" "C:\Users\Francesca\Dropbox\gcwealth\handmade_tables\taxsched_input\IBFD\pdf\gthb_c5.pdf", replace
    global found_it $found_it km   
	
    
*------------------------------------------------------------------------------*


	// Cases for which we do not have neither tax features nor the pdf
   qui import excel "C:/Users/Francesca/Dropbox/gcwealth/handmade_tables/dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
   
   	rename Country GEO_long
	duplicates drop
		
	gen geo = strlower(GEO)
	
   levelsof geo, local(levels)
   foreach country of local levels {	
		if strpos(" $found_it ", " `country' ") == 0 & strpos(" $found_kf ", " `country' ") == 0 {
			display "File `country' not in IBDF"
			global noinfo $noinfo `country'
			qui drop if geo == "`country'" & strpos(" $noinfo ", " `country' ") > 1
		}
   }
 
	// Cases for which we do not have the pdf
	
   levelsof geo, local(levels)
   foreach country of local levels {	
		if strpos(" $found_it ", " `country' ") == 0 & strpos(" $found_kf ", " `country' ") != 0 display "File `country' with only excel table"
   } 
