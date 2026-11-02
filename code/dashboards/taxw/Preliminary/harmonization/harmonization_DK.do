// Sources harmonization for Denmark

	use "$sources/Final_Data/DK/appended_DK", clear

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
		
	// TID, Yale, Schultz report inheritance tax in 1792 (first year) for children, but only TID reports 1% top rate, so we delete it for inconsistency.
	drop if Source == "TIDData"
	
	// From 1792 to 1860, Schultz and Yale have consistent information for children (full exemption) inheritance tax. We keep Schultz, as for the period 1861-1907 we think it is more reliable than Yale. 
	drop if Source == "YaleInheritanceData" & tax == "inheritance" & applies_to == "children" & year_from == "1792" & year_to == "1907"
	
	replace note = "Lov af 12. September, 1792. Collateral inheritance tax, direct line exempted" if note == "Collateral inhertiance tax, direct line exempted." & Source == "Shultz1926"
	
	
	// However, from 1861 to 1907, Yale keeps reporting full exemption, while Schultz reports 1% flat rate. So, we keep Schultz up to 1908 included (where we have also kinships rates). From 1909 we have Schultz. 
	replace year_from = "1909" if year_from == "1908" & Source == "YaleInheritanceData" & tax == "inheritance" & applies_to == "children" 
	
	
	// Overlapping between Yale and EYa for children in estate tax between 2006 and 2009. We keep EYa. 
	drop if Source == "YaleInheritanceData" & applies_to == "children" & tax == "estate" & inlist(year_from, "2006", "2007", "2008", "2009") & inlist(year_to, "2006", "2007", "2008", "2009")
		
		
		
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
		
	* No overlapping between children (or other) and everybody	
		
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
		
		
	export excel using "$sources/Final_Data/DK/Final_DK.xlsx", firstrow(variables) sheet(Data) replace	
	erase "$sources/Final_Data/DK/appended_DK.dta"	
