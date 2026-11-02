clear all

** Set paths here
global path "${topo_dir_raw}/StatCan_DWA_topo/auxiliary files"

** STEP 2: Create SNA2008 Grid for Stocks

*** Something adjusted
import excel "${path}/qdates.xlsx", sheet("qdates") cellrange(A1) clear

rename A fulldate
gen year_q = quarterly(fulldate, "YQ")
format year_q %tq

split fulldate, p("Q")
encode fulldate1, gen(year)
encode fulldate2, gen(quarter)
drop fulldate fulldate1 fulldate2


gen A_AF = .
label var A_AF "Financial assets"

gen A_AF6 = .
label var A_AF6 "Life insurance and pensions"

gen A_AFX = .
label var A_AFX "Other financial assets"

gen AN = .
label var AN "Non-financial assets"

gen AN_H = .
label var AN_H "Real estate"

gen AN_N = .
label var AN_N "Other non-financial assets"

gen L_AF = .
label var L_AF "Total liabilities"

gen XAF42LM = .
label var XAF42LM "Mortgage liabilities"

gen L_AFO = .
label var L_AFO "Other liabilities"

gen NWA = .
label var NWA "Net worth (wealth)"


* Recast all variables as double 
foreach var of varlist A_AF-  NWA{
   recast double `var'
}

sort year_q



* Save quarterly grid
*save "C:\Users\grella\Dropbox\GC Wealth Project\Data\Raw data\Create general grid\grid_q_stock.dta", replace
*save "${path}/grid_q_stock.dta", replace



* Generate and save annual grid
keep if quarter == 4

*save "C:\Users\grella\Dropbox\GC Wealth Project\Data\Raw data\Create general grid\grid_a_stock.dta", replace
save "${path}/grid_a_stock.dta", replace


