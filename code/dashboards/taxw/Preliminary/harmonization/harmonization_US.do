use "$sources/Final_Data/US/appended_US", clear

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

	// Discrepancy in 1926 between Shultz and US_Leg1976 for estate everybody. We keep the lex as more reliable
	replace year_to = "1925" if year_to == "1926" & Source == "Shultz1926" & tax == "estate" & applies == "everybody"

	// Discrepancy from 1942 to 1976 between PMIC1942 (lex) and IRS1976 (gov. research) for estate everybody. The lex reports the "adjusted" schedule collapsing brackets with the same marginal rates, while IRS1976 reports the "original" schedule. We keep the lex but the result is equvalent
	drop if substr(Source, 1, 3)== "IRS"	
		
	// Overlapping Jacobson and US_Leg1976 for estate everybody from 1977 to 1980. We keep the lex with the schedule.
	drop if inlist(year_from, "1977", "1978", "1979", "1980") & Source == "Jacobson2007" & tax == "estate" & applies == "everybody"
	
	// Overlapping TIDData Shultz for estate tax spouse, identical. We keep Shultz which is the source of TID.
	drop if year_from == "1898" & year_to == "1902" & Source == "TIDData" & applies_to == "spouse" & tax == "estate"
	
	// Overlapping EYa Jacobson in 2010-2011 for estate and gift tax. We keep Jacobson in all years and taxes for consistency with future years (according to Jacobson spouse is fully exempt from 2011 on).
	drop if inlist(year_from, "2010", "2011") & inlist(year_to, "2010", "2011") & inlist(tax, "estate", "gift") & Source != "Jacobson2007"
	
	// Overlapping EYa Jacobson from 2006 to 2009 and in 2011 for estate and gift tax spouse. Jacobson has the tax credit indicator and the first year, so we keep it. 
	drop if inlist(year_from, "2006", "2007", "2008", "2009", "2011") & inlist(year_to, "2006", "2007", "2008", "2009", "2011") & (tax == "estate" | tax == "gift") & applies_to == "spouse" & substr(Source, 1, 2) == "EY" 
	drop if year_from == "2010" & year_to == "2010" & tax == "gift" & applies_to == "spouse" & Source == "EY2010a"
	
	// Overlapping Shultz and Jacobson for children, spouse, non relatives 1862-1869 for inheritance tax. We keep Jacobson which is our main source
	replace applies_to = "siblings" if applies_to == "children,siblings" & year_from == "1862" & year_to == "1863" & Source == "Shultz1926" & tax == "inheritance"
	*replace year_from = "1870" if applies_to == "children" & year_from == "1864" & year_to == "1870" & Source == "Shultz1926" & tax == "inheritance"
	drop if applies_to == "spouse" & year_from == "1862" & year_to == "1863" & Source == "Shultz1926" & tax == "inheritance"
	*replace year_from = "1870" if applies_to == "spouse" & year_from == "1864" & year_to == "1870" & Source == "Shultz1926" & tax == "inheritance"
	drop if applies_to == "non relatives" & year_from == "1862" & year_to == "1863" & Source == "Shultz1926" & tax == "inheritance"
	*replace year_from = "1870" if applies_to == "non relatives" & year_from == "1864" & year_to == "1870" & Source == "Shultz1926" & tax == "inheritance"	
	
	// Overlapping Shultz and Jacobson for siblings, other relatives 1864-1869 for inheritance tax. We keep Jacobson which is our main source	
	*replace year_from = "1870" if applies_to == "siblings" & year_from == "1864" & year_to == "1870" & Source == "Shultz1926" & tax == "inheritance"	
	*replace year_from = "1870" if applies_to == "other relatives" & year_from == "1864" & year_to == "1870" & Source == "Shultz1926" & tax == "inheritance"		
	
	// Overlapping Shultz and Jacobson for everybody inheritance 1871-1926 for inheritance tax. We keep Jacobson which is our main source		
	drop if applies_to == "everybody" & year_from == "1871" & year_to == "1926" & Source == "Shultz1926" & tax == "inheritance"	
	
	// Overlapping EYa and Jacobson for everybody inheritance 2006-2011 for inheritance tax, status 0. We keep Jacobson which is our main source
	drop if inlist(year_from, "2006", "2007", "2008", "2009", "2010", "2011") & inlist(year_to, "2006", "2007", "2008", "2009", "2010", "2011") & (tax == "inheritance") & applies_to == "everybody" & substr(Source, 1, 2) == "EY" 
	
	// Conflict for estate children between Yale and Jacobson from 2006 to 2009 (there is also EY overlapping but without further info). Different top rate lower bound
	// We are adding a further source which will have full schedule, so we can drop from 1984-2009 the other sources, while keeping the notes from Jacobson.
	
	// Drop TID (applies to unknow, useless) 
	drop if Source == "TIDData"
	
	// The tax credit indicator is there from 1977! 
	
	// Conflict between Shultz and Jacobson for children-estate in 1898-1901. Same exemption and rates, but different schedule! We keep Jacobson as more complete note and specified repeal in 1902
	drop if year_from == "1898" & year_to == "1902" & tax == "estate" & applies_to == "children" & Source == "Shultz1926" 
	drop if year_from == "1903" & year_to == "1915" & tax == "estate" & applies_to == "everybody" & Source == "Shultz1926"
	
	// Overlapping between Yale an Jacobson for children-estate in 1981-1983. We keep Jacobson as detailed applies_to and for coherence with time series
	drop if year_from == "1981" & year_to == "1981" & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
	drop if year_from == "1982" & year_to == "1982" & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
	drop if year_from == "1983" & year_to == "1983" & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
	
	// Between 1984 to 2001, we keep CBPP and drop all other sources overlapping as CBPP reports the full schedule for children-estate & gift. 
	destring year_from, gen(p_from)
	destring year_to, gen(p_to)
	drop if p_from >= 1984 & p_to <=2001 & (tax == "estate" | tax == "gift") & substr(applies_to,1,8)=="children" & Source != "CBPP2004"
	drop p_from p_to 
	
	// Between 2002 and 2011, we keep DTIRS as it has the full schedule for estate and gift for children
	destring year_from, gen(p_from)
	destring year_to, gen(p_to)
	drop if p_from >= 2002 & p_to <=2009 & (tax == "estate" | tax == "gift") & substr(applies_to,1,8)=="children" & substr(Source,1,5) != "DTIRS"
	drop p_from p_to 
	
	// Between 1898-1901 overlapping spouse-estate in Shultz and Jacobson. As did for children, we keep Jacobson
	drop if year_from == "1898" & year_to == "1902" & tax == "estate" & applies_to == "spouse" & Source == "Shultz1926" 
	
	// Between 1984 to 2001, we keep CBPP and drop all other sources overlapping as CBPP reports the full schedule for spouse-estate & gift. 
	destring year_from, gen(p_from)
	destring year_to, gen(p_to)
	drop if p_from >= 1984 & p_to <=2001 & (tax == "estate" | tax == "gift") & applies_to=="spouse" & Source != "CBPP2004"
	drop p_from p_to 

	// Between 2002 and 2011, we keep DTIRS as it has the full schedule for estate and gift for spouse
	destring year_from, gen(p_from)
	destring year_to, gen(p_to)
	drop if p_from >= 2002 & p_to <=2009 & (tax == "estate" | tax == "gift") & applies_to=="spouse" & substr(Source,1,5) != "DTIRS"
	drop p_from p_to 

	// Between 1898 and 1901 overlapping between non-relatives, siblings and other relatives in Shultz and Jacobson. As above, keep Jacobson
	drop if year_from == "1898" & year_to == "1902" & tax == "estate" & inlist(applies_to, "siblings", "other relatives", "non relatives") & Source == "Shultz1926" 

	// Overlapping for everybody estate between 1942 and 1976 for Jacobson and IRS. As IRS has the schedule, we keep it 
	
	drop if year_from == "1942" & year_to == "1976" & applies_to == "everybody" & Source == "Jacobson2007" & tax == "estate"
	
	// Overlapping for everybody inheritance status 0 between 1926 and 2009 for Jacobson and Yale. We keep Jacobson that covers a longer period.
	drop if year_from == "1926" & year_to == "2009" & tax == "inheritance" & applies_to == "everybody" & Source == "YaleInheritanceData"	
	
	// Overlapping between Shultz and Jacobson for all kinship and inheritance between 1864 and 1869. We keep Jacobsobn as providing more information. 
	drop if year_from == "1864" & year_to == "1869" & tax == "inheritance" & Source == "Shultz1926"
		
		
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
		
	// 1927-1941 overlapping Yale and legislative sources for estate children. We drop Yale not reporting the schedule
	drop if substr(Source, 1, 4)=="Yale"

	// 1981-1983 overlapping Jacobson and legislative sources for estate children. We drop Jacobson not reporting the schedule
	replace applies_to = "siblings,other relatives,non relatives" if Source == "Jacobson2007" & tax == "estate" & inlist(year_from, "1981", "1982", "1983") & inlist(year_to, "1981", "1982", "1983") & applies_to == "children,siblings,other relatives,non relatives"
	
	// Overlapping between Yale and Shultz for estate in 1926. We keep Shultz as it reports the full schedule. 
	*replace year_from = "1927" if year_from == "1926" & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
	
	// Overlapping for estate tax between 1942 and 1976 between Yale and IRS. We keep IRS as reports the full schedule. 
	*drop if year_from == "1942" & year_to == "1942" & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
	*drop if year_from == "1943" & year_to == "1976" & tax == "estate" & applies_to == "children" & Source == "YaleInheritanceData"
	
	
	// Overlapping for estate tax between 1977 and 1980 between Yale and Jacobson. As above, keep Jacobson. 
	*drop if inlist(year_from, "1977", "1978", "1979", "1980") & inlist(year_to, "1977", "1978", "1979", "1980") & tax == "estate" & Source == "YaleInheritanceData" & applies_to == "children" 
	
	
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

	// 	Overlapping for estate between 1927 and 1941 for Jacobson and Yale. In this case we keep Yale as it refers to children, although the data reported are the same! 
		drop if year_from == "1926" & year_to == "1931" & tax == "estate" & applies_to == "unknown" & Source == "Jacobson2007"
		drop if year_from == "1932" & year_to == "1933" & tax == "estate" & applies_to == "unknown" & Source == "Jacobson2007"
		drop if year_from == "1934" & year_to == "1934" & tax == "estate" & applies_to == "unknown" & Source == "Jacobson2007"
		drop if year_from == "1935" & year_to == "1939" & tax == "estate" & applies_to == "unknown" & Source == "Jacobson2007"
		drop if year_from == "1940" & year_to == "1940" & tax == "estate" & applies_to == "unknown" & Source == "Jacobson2007"
		drop if year_from == "1941" & year_to == "1941" & tax == "estate" & applies_to == "unknown" & Source == "Jacobson2007"
	
	// Overlapping for gift tax unknown and everybody. Jacobson does not report the schedule so we drop it and keep the law.
	drop if tax == "gift" & applies_to == "unknown" & Source == "Jacobson2007" & year_from == "1932" & year_to == "1976" 
			
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
		
	// Overlapping between 1916 and 1925 for estate tax in Jacobson vs Shultz- As Shultz reports the schedule, we keep it. 
	drop if inlist(year_from, "1916", "1917") & inlist(year_to, "1916", "1917") & applies_to == "unknown" & tax == "estate" & Source == "Jacobson2007"
	drop if year_from == "1918" & year_to == "1923" & applies_to == "unknown" & tax == "estate" & Source == "Jacobson2007"
	drop if year_from == "1924" & year_to == "1925" & applies_to == "unknown" & tax == "estate" & Source == "Jacobson2007"
	

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
	
	export excel using "$sources/Final_Data/US/Final_US.xlsx", firstrow(variables) sheet(Data) replace	
	erase "$sources/Final_Data/US/appended_US.dta"	
		
		
		
		
		