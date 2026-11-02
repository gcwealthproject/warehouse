	use "$sources/Final_Data/JP/appended_JP", clear

		qui drop if subnat == "1"
		gsort -GEO year_from year_to tax applies_to
		qui duplicates tag GEO_l year_from year_to tax applies_to, gen(dupl)
		tab dupl
		drop dupl
		preserve
			qui {
			// Replicate for years 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
						
			// Replicate for kinship
			qui split(applies_to), parse(,)
			
			forvalues i = 1/`r(k_new)' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `r(k_new)'
			local k = `r(k_new)'
			local k = `r(k_new)'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			sort GEO year applies_to tax dupl

			egen group = group(GEO applies_to tax year Source)
			replace applies_to = applies_to1 if dupl == 0		
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies_to`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies_to`i' != ""
			}	
			drop applies_to1-applies_to`k' expans dupl group
		
			duplicates tag GEO_l year tax applies_to, gen(dupl)
			}
			tab dupl
			tab year Source if dupl
			tab year tax if dupl
			tab year applies_to if dupl
		restore
	
	
	
	// TEMPORANEOUSLY DROP YALE AS INCONSISTENCY WITH OTHER SOURCES -- TO CHECK
	drop if Source == "YaleInheritanceData"
	
	
	// Overlapping between BartholdIto1992 and JapanTaxGuide2022 for years 1987-1992. Only in 1987 JapanTaxGuide2022 reports the exemption which is missing in BartholdIto1992
	destring year_from, replace	
	drop if Source == "JapanTaxGuide2022" & year_from <= 1992
	tostring year_from, gen(pippo)
	drop year_from
	rename pippo year_from
	
	// Overlapping gift everybody in 2003-2005 between Moriguchi and Tax Law. We keep the Tax Law. 
	replace year_to = "2002" if year_to == "2005" & tax == "gift" & applies_to == "everybody" & Source == "MoriguchiSaez2008"
	
	
	*replace year_to = "2005" if year_to == "2007" & Source =="YaleInheritanceData" & applies_to == "children" & tax == "inheritance"	
	drop if Source == "JapanTaxGuide2022" & year_from == "2015" & year_to == "2024"
	
	// Overlapping between Yale and EYa for estate-everybody. We keep Yale until 2005 and then EY
	* replace year_to = "2005" if year_to == "2007" & Source =="YaleInheritanceData" & applies_to == "everybody" & tax == "estate"	
	destring year_from, gen(p_fr)	
	destring year_to, gen(p_to)	
	drop if p_fr >= 2006 & p_to <= 2014 & tax == "gift" & substr(Source,1,2) == "EY"
	drop p_*
	
	// Overlapping between law and Moriguchi for inheritance everybody between 1994 and 2005.We keep the law 
	replace year_to = "1993" if year_to == "2005" & tax == "inheritance" & applies_to == "everybody" & Source == "MoriguchiSaez2008" 
	
	
	
		// Further possible overlapping: everybody and children
	
		preserve
			qui {
			// Replicate for years 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
						
			// Replicate for kinship
			qui split(applies_to), parse(,)
			
			forvalues i = 1/`r(k_new)' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `r(k_new)'
			local k = `r(k_new)'
			local k = `r(k_new)'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			forvalues i = `k'(-1)1 {
				rename applies_to`i' applies`i'
				replace applies`i' = "children" if applies`i' == "everybody"
			}			
			sort GEO year applies_to tax dupl

			egen group = group(GEO applies_to tax year Source)
			replace applies_to = applies1 if dupl == 0
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies`i' != ""
			}	
			drop applies1-applies`k' expans dupl group
		
			duplicates tag GEO_l year tax applies_to, gen(dupl)
			}
			tab dupl
			tab year Source if dupl
			tab year tax if dupl
			tab year applies if dupl
		restore
		
		
	// Overlapping EY (children) and Tax law (everybody) for inheritance in 2006-2014. We keep the law	
	destring year_from, gen(p_fr)	
	destring year_to, gen(p_to)	
	drop if p_fr >= 2006 & p_to <= 2014 & tax == "inheritance" & substr(Source,1,2) == "EY"
	drop p_*

		
	// Further possible overlapping: children and unknown: we keep children because the source is more specific
		preserve
			qui {
			// Replicate for years 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
						
			// Replicate for kinship
			qui split(applies_to), parse(,)
			
			forvalues i = 1/`r(k_new)' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `r(k_new)'
			local k = `r(k_new)'
			local k = `r(k_new)'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			forvalues i = `k'(-1)1 {
				rename applies_to`i' applies`i'
				replace applies`i' = "children" if applies`i' == "unknown"
			}			
			sort GEO year applies_to tax dupl

			egen group = group(GEO applies_to tax year Source)
			replace applies_to = applies1 if dupl == 0
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies`i' != ""
			}	
			drop applies1-applies`k' expans dupl group
		
			duplicates tag GEO_l year tax applies_to, gen(dupl)
			}
			tab dupl
			tab year Source if dupl
			tab year tax if dupl
			tab year applies if dupl
		restore		
		
			
	// Last possible overlapping: everybody and unknown
		preserve
			qui {
			// Replicate for years 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
						
			// Replicate for kinship
			qui split(applies_to), parse(,)
			
			forvalues i = 1/`r(k_new)' {
				replace applies_to`i' = strtrim(applies_to`i')
			} 
			
			gen expans = `r(k_new)'
			local k = `r(k_new)'
			local k = `r(k_new)'
			forvalues i = `k'(-1)1 {
				replace expans = expans - 1 if applies_to`i' == "" 
			}			
			expand expans, gen(dupl)
			forvalues i = `k'(-1)1 {
				rename applies_to`i' applies`i'
				replace applies`i' = "everybody" if applies`i' == "unknown"
			}			
			sort GEO year applies_to tax dupl

			egen group = group(GEO applies_to tax year Source)
			replace applies_to = applies1 if dupl == 0
			forvalues i = 2/`k' {
				local j = `i' -1
				replace applies_to = applies`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies`i' != ""
			}	
			drop applies1-applies`k' expans dupl group
		
			duplicates tag GEO_l year tax applies_to, gen(dupl)
			}
			tab dupl
			tab year Source if dupl
			tab year tax if dupl
			tab year applies if dupl
		restore		
		
		// Overlapping for estate in 1905-1953 between TIDD (unkown) and Moriguchi (everybody). We keep Moriguchi as reporting more infor 
		drop if year_from == "1905" & year_to == "1949" & tax == "estate" & Source == "TIDData" & applies_to == "unknown"
		drop if year_from == "1950" & year_to == "1953" & tax == "estate" & Source == "TIDData" & applies_to == "unknown"
		drop if year_from == "1950" & year_to == "1952" & tax == "inheritance" & Source == "TIDData" & applies_to == "unknown"
		drop if year_from == "1953" & year_to == "1953" & tax == "inheritance" & Source == "TIDData" & applies_to == "unknown"


// Last check: conflict in status by tax -- we can have conflict between everybody vs any other kinship (BUT NOT BETWEEN ANY OTHER COMBINATION e.g. children vs spouse) 
		preserve 
			destring year_from, replace 
			destring year_to, replace
			gen expans = year_to - year_from + 1
			expand expans, gen(dupl)
			gen year = year_from
			egen group = group(GEO applies_to tax year_from year_to Source)
			sort group year dupl
			replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
			drop dupl year_* expans group
			order GEO* year appl tax 
			sort GEO* year appl tax 
			
			// Gen conflict: 
				bysort year tax: egen has_everybody = max(applies_to == "everybody")

			// compute min and max status within the group
			destring status, replace 
			bysort year tax: egen min_status = min(status)
			bysort year tax: egen max_status = max(status)

			// flag conflict only if there is a difference AND 'everybody' is in the group
			gen conflict = (min_status != max_status) & (has_everybody == 1)
			tab conflict	
		restore 			
		
	export excel using "$sources/Final_Data/JP/Final_JP.xlsx", firstrow(variables) sheet(Data) replace	
	erase "$sources/Final_Data/JP/appended_JP.dta"