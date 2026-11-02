// Sources harmonization for France

	use "$sources/Final_Data/FR/appended_FR", clear

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
	
		
		/* "Conflict" between Shultz & Yale between 1798-1849 for inheritance and children. Yale reports 0.2875 rates, while Shultz 1%. The two are 
		in line in reporting the 1% for immovable properties. We keep Shultz as we focus on the immovable for this historical period. */ 
			replace exemption = "0" if year_from == "1798" & year_to == "1849" & tax == "inheritance" & applies_to == "children" & Source == "Shultz1926"
			drop if year_from == "1798" & year_to == "1849" & tax == "inheritance" & applies_to == "children" & Source == "YaleInheritanceData"
			
		// Overlapping between TIDD and Shultz in 1901 for inheritance tax applies to other relatives and non-relatives. We keep Shultz as it reports full info 
			drop if year_from == "1901" & year_to == "1901" & tax == "inheritance" & (applies_to == "other relatives" | applies_to == "non relatives") & Source == "TIDData"
	
		// Overlapping between Yale and Shltz between 1902 and 1909 in children-ibheritance. Same info, we recover the type of tax from Shultz and keep Yale for coherence with subsequent years 
			replace typetax = "4" if year_from == "1902" & year_to == "1909" & tax == "inheritance" & Source == "YaleInheritanceData" & applies_to == "children"
			drop if year_from == "1902" & year_to == "1909" & tax == "inheritance" & Source == "Shultz1926" & applies_to == "children"
				
		
		// Overlapping for siblings-inheritance between 1798 to 1832 between TIDD and Shultz. The latter report the scheudle, so drop TIDD. 
			replace year_from = "1833" if year_from == "1798" & tax == "inheritance" & year_to == "1900" & (applies_to == "spouse, siblings" | applies_to == "other relatives") & Source == "TIDData"
		
		// Conflict between Shultz and TIDD for non-relatives inheritance between 1832 and 1900. We keep Shultz as it reports the full schedule and because TID reports a conflict between different sources. 
			replace year_to = "1831" if year_from == "1798" & tax == "inheritance" & year_to == "1900" & applies_to == "non relatives" & Source == "TIDData"
		
		// Overlapping between Shultz and TIDD in 1901 for spouse. We keep Shultz as it reports the schedule. We keep Siblings from TIDD for 1901
			drop if year_from == "1901" & year_to == "1901" & tax == "inheritance" & applies_to == "spouse, siblings" & Source == "TIDData" 
		
		// Overlapping between Shultz and TIDD in 1798-1831 for non relatives. We keep Shultz as it reports the schedule.
		drop if Source == "TIDData" & year_from == "1798" & year_to == "1831" & applies_to == "non relatives" & tax == "inheritance"
		
		// Conflict for children inheritance 1850-1900: Yale reports several changes of surcharge making the flat rate change over time, while Shultz always reports 1.25. We keep Yale as more detailed.
		drop if tax == "inheritance" & applies_to == "children" & Source == "Shultz1926" & year_from == "1850" & year_to == "1900"
		
		// Conflict for children inheritance 1901: Yale reports the same flat tax as 1900, while Shultz reports the new progressive tax. Since Yale reports that "rates applies from April 1902" for the reform 25 February 1901, Art. 1; 30 March 1902, Art. 10, we keep Yale
		drop if tax == "inheritance" & applies_to == "children" & Source == "Shultz1926" & year_from == "1901" & year_to == "1901"
		
		// Overlapping for children inheritance 1910-1914 between Yale and Shultz, we combine information keeping Yale as more complete (with exemption)
		drop if tax == "inheritance" & applies_to == "children" & Source == "Shultz1926" & year_from == "1910" & year_to == "1914"
		replace typetax = "4" if tax == "inheritance" & applies_to == "children" & Source == "YaleInheritanceData" & year_from == "1910" & year_to == "1917"
		replace note = "8 April 1910, Art. 10; Capgras and Domergue (1935: 3); rate applies from 12 April 1910. The rate was 1% for the first 2.000 of inheritance" if tax == "inheritance" & applies_to == "children" & Source == "YaleInheritanceData" & year_from == "1910" & year_to == "1917"

		// Overlapping for everybody estate bewtween Yale and Shultz. We keep Shultz until 1799.
		replace year_to = "1799" if year_to == "1914" & year_from == "1798" & Source == "Shultz1926" & tax == "estate" & applies_to == "everybody"
				
		// Conflict between Legifrance1983 and Yale in toprate only in 1983 (20 for Yale, 40 for Legifrance1983), but the law is from Dec 1983.
		replace year_to = "1982" if tax == "inheritance" & applies_to == "children" & Source == "YaleInheritanceData" & year_from == "1981" & year_to == "1983"
			
		// Overlapping between Yale and Government Legislation between 1979 and 2008 for children-inheritance. We keep Legislation with full schedule.  
		destring year_from, gen(pp_from)
		destring year_to, gen(pp_to)
		drop if pp_from >= 1979 & pp_to <= 2008 & Source == "YaleInheritanceData" & applies_to == "children" & tax == "inheritance"
		drop pp_*
		replace year_to = "1978" if year_to == "1980" & Source == "YaleInheritanceData" & applies_to == "children" & tax == "inheritance"
		
		// Overlapping between Yale and EY for children-inheritance in 2009. We keep Eya as it has all the schedule. 
		drop if year_from == "2009" & year_to == "2009" & applies_to == "children" & tax == "inheritance" & Source == "YaleInheritanceData"
		
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
	
	export excel using "$sources/Final_Data/FR/Final_FR.xlsx", firstrow(variables) sheet(Data) replace	
	erase "$sources/Final_Data/FR/appended_FR.dta"	
	
	
	
	