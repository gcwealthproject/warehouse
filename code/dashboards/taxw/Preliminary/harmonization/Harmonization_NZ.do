use "$sources/Final_Data/NZ/appended_NZ", clear

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
	
		// Overlapping between EY and Tax Law for estate and inheritance in 1992 and 1993. We keep the law as primary source. 
		replace year_from = "1994" if year_from == "1992" & year_to == "2024" & tax != "gift" & substr(Source,1,2)=="EY"
		
		// Overlapping inheritance everybody 1956-2000 between Tax Law and Yale. We keep the law. 
		drop if tax == "inheritance" & year_from == "1956" & year_to == "2000" & Source == "YaleInheritanceData"
		
		// Overlaping between Tax law and Yale for estate between 1993 and 2000. We keep the Law. 
		drop if tax == "estate" & year_from == "1993" & year_to == "2000" & Source == "YaleInheritanceData"
 		
		// Overlapping EYb and tax law for 1994-2024 estate everybody (notax). We drop EY and correct Yale reporting estate tax for children until 1992 (but the abolition in 1993 was effective from 1992)
		drop if tax == "estate" & applies_to == "everybody" & year_from == "1994" & year_to == "2024"
		replace year_to = "1991" if year_to == "1992" & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
		
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
		
	// Overlapping for inheritance between Law and Yale for 1955-1992. We keep the law 
		destring year_from, gen(p_from)
		destring year_to, gen(p_to)
		drop if p_from >= 1955 & p_to <=1992 & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
		drop p_*
		
	// Overlapping in 1955 inheritance for Yale and Tax. Yale one year ahead. 
	replace year_to = "1954" if year_to == "1955" & tax == "inheritance" & applies_to == "children" & Source == "YaleInheritanceData"
	
	// Overlapping for 1955 estate between Yale and Tax. We keep the tax law since the 1955. 
	replace year_to = "1954" if year_to == "1955" & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
		
	
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
	
	// Overlapping between TIDD and Yale for estate between 1867 and 1954. We keep Yale. 
	drop if Source == "TIDData"
			
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
		
	export excel using "$sources/Final_Data/NZ/Final_NZ.xlsx", firstrow(variables) sheet(Data) replace	
	erase "$sources/Final_Data/NZ/appended_NZ.dta"		
		
		
		