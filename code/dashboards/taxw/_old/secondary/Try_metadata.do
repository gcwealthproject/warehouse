
*import data 
import excel using "EIG Taxes/data_inputs/EIGtax_mergeable.xlsx", ///
	firstrow clear

*reshape and drop duplicates 
qui keep Geo GeoReg year Gift_Valuation Gift_Notes Notes ///
	Tax_Basis Class_I Class_II Class_III Related_Tax_Notes Final_Notes
duplicates drop
ds Geo GeoReg year, not 
foreach v in `r(varlist)'{
	rename `v' v_`v'
}

duplicates drop Geo GeoReg year, force
reshape long v_, i(Geo GeoReg year) j(notes_type) str
exit 1
drop if v_ == "." | v_== "" | missing(Geo)




/*
*study combinations and encode unique 
qui egen aux1 = concat(Geo GeoReg notes_type v_)
sort aux1 Geo year
qui levelsof aux1, local(combi)
qui encode aux1, gen(aux1e)
local ncomb = r(r)
di as result "we have " `ncomb' " combinations and " _N "obs" 

*list countries and years with same info 
tsset aux1e year 
tsspell aux1e //ssc install tsspell
qui sort aux1e year 
qui collapse (firstnm) Geo GeoReg notes_type v_ ///
	(min) min_y = year (max) max_y = year, by(aux1e _spell)	
cap drop area
qui egen area = concat(Geo GeoReg) if GeoReg != "_na", punct("-") 
qui replace area = Geo if GeoReg == "_na"
qui egen peri = concat(min_y max_y ), punct(":")
qui gen aux3 = area + "(" + peri + ")"
qui drop min_y max_y area peri aux1e aux1 _spell

qui replace notes_str = subinstr(notes_str, char(10),  "", .)
qui replace notes_str = subinstr(notes_str, char(13),  "", .)
//put everything together 
qui egen aux4 = concat(notes_type v_)
qui encode aux4, gen(aux4e)
/*
cap drop aux2
qui egen aux2 = concat(lister*)
qui egen aux3 = concat(lister*) if aux2 != "", punct(" ; ")
qui drop aux2 
*/

//compact even more 
levelsof aux4e, local(idk) clean 
cap drop lister
qui gen lister = ""
foreach x in `idk' {
	di as result "`x'"
	levelsof aux3 if aux4e == `x', local(x`x') separate(" ; ") clean
	qui replace lister = "`x`x''" if aux4e == `x'
}

qui collapse (firstnm) notes_type v_ lister, by(aux4e)
qui drop aux4e

//tidy up
qui rename (v_ lister) (notes_str country_years)
qui sort notes_type notes_str

export excel using "EIG Taxes/data_inputs/is_this_trash.xlsx", ///
	firstrow(variables) replace 	
	
di as result "after collapse we have " _N " obs"	 
*/
