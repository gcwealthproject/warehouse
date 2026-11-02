clear all

** Set paths here
global path "${topo_dir_raw}/ECB_DWA_topo/auxiliary files"

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


gen A_AF2M = .
label var A_AF2M "Deposits"

gen A_AF3 = .
label var A_AF3 "Debt securities"

gen XAF42LM = .
label var XAF42LM "Loans for house purchasing"

gen L_AF4X = .
label var L_AF4X "Loans other than for house purchasing"

gen A_AF511 = .
label var A_AF511 "Listed shares"

gen A_AF51M = .
label var A_AF51M "Unlisted shares and other equity"

gen A_AF52 = .
label var A_AF52 "Investment fund shares/units"

gen A_AF62 = .
label var A_AF62 "Life insurance and annuity entitlements"

gen L_AF_NNA = .
label var L_AF_NNA "Adjusted total liabilities (financial and net non-financial)"

gen A_AF_NNA = .
label var A_AF_NNA "Adjusted total assets (financial and net non-financial)"

gen ANUB = .
label var ANUB "Non-financial business wealth"

gen ANUN = .
label var ANUN "Housing wealth (net)"

gen NWA = .
label var NWA "Adjusted wealth (net)"


* Recast all variables as double 
foreach var of varlist A_AF2M-  NWA{
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


