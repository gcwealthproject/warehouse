
cap program drop ibfd_download
program define ibfd_download, 
	syntax varlist(max=1 string)
	
	levelsof `varlist', local(levels)
	
// Country tax features (Excel)

   local base_url "https://research.ibfd.org/collections/kf/excel/"
   local archive_url "https://research.ibfd.org/archive/kf/excel/"   
   *local save_dir "C:/Users/Francesca/Dropbox/gcwealth/handmade_tables/taxsched_input/IBFD/tables/"
   local save_dir "C:/Users/Francesca/Desktop/tables/"   

	foreach country of local levels {

		local url = "`base_url'kf_`country'.xls"
		local name = strupper("`country'")
		
		display as result "Working on country `name'"
				
		cap dir `save_dir'`name'
		
		if _rc != 0 {
			qui mkdir `save_dir'`name'
		}
		else qui cd `save_dir'`name'
		
		cap copy "`url'" "kf_`name'.xls", replace
		if _rc != 0 {
			local letter = substr("`country'", 1, 1)
			local url2 = "`base_url'kf_`letter'1.xls"
			cap copy "`url2'" "kf_`name'.xls", replace
			if _rc != 0 {
				di as error "File `country' not found or error in download"
			}
			else {
				global found_kf $found_kf `country' 
				forvalues y = 2008(1)2024 {
					display as result "Year `y'"
					forvalues m = 1(1)12 {
						forvalues d = 1(1)31 {
							local mm = string(`m', "%02.0f")
							local dd = string(`d', "%02.0f")
							local urlarc2 = "`archive_url'kf_`letter'1_`y'-`mm'-`dd'.xls"
							cap copy "`urlarc2'" "kf_`name'_`y'-`mm'-`dd'.xls", replace		
						}
					}
				}			
			}
		}							
		else {
			global found_kf $found_kf `country'
			forvalues y = 2008(1)2024 {
				display as result "Year `y'"
				forvalues m = 1(1)12 {
					forvalues d = 1(1)31 {
						local mm = string(`m', "%02.0f")
						local dd = string(`d', "%02.0f")
						local urlarc = "`archive_url'kf_`country'_`y'-`mm'-`dd'.xls"
						cap copy "`urlarc'" "kf_`name'_`y'-`mm'-`dd'.xls", replace		
					}
				}
			}			
		}
	}	
	
end

	qui import excel "C:/Users/Francesca/Dropbox/gcwealth/handmade_tables/dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
    drop if GEO == "_na"
   
	rename Country GEO_long
	duplicates drop
		
	gen geo = strlower(GEO)
	keep if geo=="it" | geo=="im"

ibfd_download geo


























	
	
	qui import excel "C:/Users/Francesca/Dropbox/gcwealth/handmade_tables/dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
   drop if GEO == "_na"
   
	rename Country GEO_long
	duplicates drop
		
	gen geo = strlower(GEO)
	keep if geo=="it" | geo=="im"
	levelsof geo, local(levels)
	
// Country tax features (Excel)

   local base_url "https://research.ibfd.org/collections/kf/excel/"
   local archive_url "https://research.ibfd.org/archive/kf/excel/"   
   *local save_dir "C:/Users/Francesca/Dropbox/gcwealth/handmade_tables/taxsched_input/IBFD/tables/"
   local save_dir "C:/Users/Francesca/Desktop/tables/"   

	foreach country of local levels {

		local url = "`base_url'kf_`country'.xls"
		local name = strupper("`country'")
		
		display "Working on country `name'"
				
		cap dir `save_dir'`name'
		
		if _rc == 0 {
			qui mkdir `save_dir'`name'
		}
		else qui cd `save_dir'`name'
		
		cap copy "`url'" "kf_`name'.xls", replace
		if _rc != 0 {
			local letter = substr("`country'", 1, 1)
			local url2 = "`base_url'kf_`letter'1.xls"
			cap copy "`url2'" "kf_`name'.xls", replace
			if _rc != 0 {
				di as error "File `country' not found or error in download"
			}
			else {
				global found_kf $found_kf `country' 
				forvalues y = 2008(1)2024 {
					display "Year `y'"
					forvalues m = 1(1)12 {
						forvalues d = 1(1)31 {
							local mm = string(`m', "%02.0f")
							local dd = string(`d', "%02.0f")
							local urlarc2 = "`archive_url'kf_`letter'1_`y'-`mm'-`dd'.xls"
							cap copy "`urlarc2'" "kf_`name'_`y'-`mm'-`dd'.xls", replace		
						}
					}
				}			
			}
		}							
		else {
			global found_kf $found_kf `country'
			forvalues y = 2008(1)2024 {
				display "Year `y'"
				forvalues m = 1(1)12 {
					forvalues d = 1(1)31 {
						local mm = string(`m', "%02.0f")
						local dd = string(`d', "%02.0f")
						local urlarc = "`archive_url'kf_`country'_`y'-`mm'-`dd'.xls"
						cap copy "`urlarc'" "kf_`name'_`y'-`mm'-`dd'.xls", replace		
					}
				}
			}			
		}
	}
	
	
	
	
	
	
    // Kosovo
	copy "https://research.ibfd.org/collections/kf/excel/kf_k1.xls" "C:\Users\Francesca\Dropbox\gcwealth\handmade_tables\taxsched_input\IBFD\tables\XK\kf_xk.xls", replace
    global found_kf $found_kf xk

	// Comoros
	copy "https://research.ibfd.org/collections/kf/excel/kf_c5.xls" "C:\Users\Francesca\Dropbox\gcwealth\handmade_tables\taxsched_input\IBFD\tables\KM\kf_km.xls", replace
    global found_kf $found_kf km  
	