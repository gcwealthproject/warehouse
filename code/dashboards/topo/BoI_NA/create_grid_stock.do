clear all

** Set paths here
global path "${topo_dir_raw}/BoI_NA/auxiliary files"
global origin "${topo_dir_raw}/BoI_NA/raw data"


* Import dates
import excel "${origin}/data.xlsx", sheet("data") cellrange(D1:W1)  clear

foreach var of varlist E-S {
	destring `var', generate(`var'_)
}

xpose, clear 
drop if v1 == .

rename v1 year 


* Non-financial assets

gen AN1 = .
label var AN1 "Produced non-financial assets"

gen AN11 = .
label var AN11 "Fixed assets (by type of assets)"

gen AN111 = .
label var AN111 "Dwellings"

gen AN112 = .
label var AN112 "Other buildings and structures"

gen AN1121 = .
label var AN1121 "Buildings other than dwellings"

gen AN1122 = .
label var AN1122 "Other structures"

gen AN1123 = .
label var AN1123 "Land improvements"

gen AN113 = .
label var AN113 "Machinery and equipment"

gen AN1131 = .
label var AN1131 "Transport equipment"

gen AN1132 = .
label var AN1132 "ICT equipment"

gen AN1133 = .
label var AN1133 "Other machinery and equipment"

gen AN114 = .
label var AN114 "Weapons systems"

gen AN115 = .
label var AN115 "Cultivated biological resources"

gen AN1151 = .
label var AN1151 "Animal resources yielding repeat products"

gen AN1152 = .
label var AN1152 "Tree, crop and plant resources yielding repeat products"

gen AN117 = .
label var AN117 "Intellectual property products"

gen AN1171 = .
label var AN1171 "Research and development"

gen AN1172 = .
label var AN1172 "Mineral exploration and evaluation"

gen AN1173 = .
label var AN1173 "Computer software and databases"

gen AN11731 = .
label var AN11731 "Computer software"

gen AN11732 = .
label var AN11732 "Databases"

gen AN1174 = .
label var AN1174 "Entertainment, literary or artistic originals"

gen AN1179 = .
label var AN1179 "Other intellectual property products"

gen AN12 = .
label var AN12 "Inventories (by type of inventory)"

gen AN121 = .
label var AN121 "Materials and supplies"

gen AN122 = .
label var AN122 "Work-in-progress"

gen AN1221 = .
label var AN1221 "Work-in-progress on cultivated biological assets"

gen AN1222 = .
label var AN1222 "Other work-in-progress"

gen AN123 = .
label var AN123 "Finished goods"

gen AN124 = .
label var AN124 "Military inventories"

gen AN125 = .
label var AN125 "Goods for resale"

gen AN13 = .
label var AN13 "Valuables"

gen AN131 = .
label var AN131 "Precious metals and stones"

gen AN132 = . 
label var AN132 "Antiques and other art objects"

gen AN133 = .
label var AN133 "Other valuables"

gen AN2 = .
label var AN2 "Non-produced non-financial assets"

gen AN21 = . 
label var AN21 "Natural resources"

gen AN211 = .
label var AN211 "Land"

gen AN21111 = .
label var AN21111 "Land underlying dwellings"

gen AN212 = .
label var AN212 "Mineral and energy reserves"

gen AN213 = .
label var AN213 "Non-cultivated biological resources"

gen AN214  = .
label var AN214 "Water resources"

gen AN215 = .
label var AN215 "Other natural resources"

gen AN2151 = .
label var AN2151 "Radio spectra"

gen AN2159 = .
label var AN2159 "Other (Other natural resources)"

gen AN22 = .
label var AN22 "Contracts, leases and licences"

gen AN221 = .
label var AN221 "Marketable operating leases"

gen AN222 = .
label var AN222 "Permissions to use natural resources"

gen AN223 = .
label var AN223 "Permissions to undertake specific activities"

gen AN224 = .
label var AN224 "Entitlement to future goods and services on an exclusive basis"

gen AN23 = .
label var AN23 "Purchases less sales of goodwill and marketing assets"

gen XDHHCE = .
label var XDHHCE "Consumer durables"

** Financial Assets

gen A_AF = .
label var A_AF "Financial assets"

gen A_AF1 = .
label var A_AF1 "Monetary gold and SDRs"

gen A_AF11 = .
label var A_AF11 "Monetary gold"
	
gen A_AF12 = .		
label var A_AF12 "SDRs"

gen A_AF2 = .
label var A_AF2 "Currency and deposits"

gen A_AF21 = .
label var A_AF21 "Currency"

gen A_AF22 = .
label var A_AF22 "Transferable deposits"

gen A_AF221 = .
label var A_AF221 "Interbank positions"

gen A_AF229 = .
label var A_AF229 "Other transferable deposits"

gen A_AF29 = .
label var A_AF29 "Other deposits"

gen A_AF3 = .
label var A_AF3 "Debt securities"

gen A_AF31 = .
label var A_AF31 "Short-term debt securities"

gen A_AF32 = .
label var A_AF32 "Long-term debt securities"

gen A_AF4 = .
label var A_AF4	"Loans"

gen A_AF41 = .	
label var A_AF41 "Short-term loans"

gen A_AF42 = .
label var A_AF42 "Long-term	loans"

gen A_AF5 = .
label var A_AF5 "Equity and investment fund shares "

gen A_AF51 = .
label var A_AF51 "Equity"

gen A_AF511 = .
label var A_AF511 "Listed shares"

gen A_AF512 = . 
label var A_AF512 "Unlisted shares"

gen A_AF519 = .
label var A_AF519 "Other equity"

gen A_AF52 = .		
label var A_AF52 "Investment fund shares/units"
	
gen A_AF521 = .
label var A_AF521 "Money market fund shares/units"

gen A_AF522 = .
label var A_AF522 "Non-MMF investment fund shares/units"

gen A_AF6 = .
label var A_AF6 "Insurance, pension and standardized guarantee schemes"

gen A_AF61 = .
label var A_AF61 "Non-life insurance technical provisions"
	
gen A_AF62 = .
label var A_AF62 "Life insurance and annuity entitlements"	

gen A_AF63 = .
label var A_AF63 "Pension entitlements"
	
gen A_AF64 = .
label var A_AF64 "Claims of pension funds on pension managers"

gen A_AF65 = .
label var A_AF65 "Entitlements to non-pension benefits"

gen A_AF66 = .
label var A_AF66 "Provisions for calls under standardized guarantees"

gen A_AF7 = .
label var A_AF7 "Financial derivatives and employee stock options"

gen A_AF71 = .
label var A_AF71 "Financial derivatives"

gen A_AF711 = .
label var A_AF711 "Options" 

gen A_AF712	= .
label var A_AF712 "Forwards"

gen A_AF72 = .
label var A_AF72 "Employee stock options"
	
gen A_AF8 = .
label var A_AF8 "Other accounts receivable"
		
gen A_AF81 = .
label var A_AF81 "Trade credits and advances"
	
gen A_AF89 = .
label var A_AF89 "Other accounts receivable"

** Liabilities

gen L_AF = .
label var L_AF "Liabilities"
			
gen L_AF1 = .
label var L_AF1 "Monetary gold and SDRs"
	
gen L_AF11 = .
label var L_AF11 "Monetary gold"
	
gen L_AF12 = .
label var L_AF12 "SDRs"

gen L_AF2 = .
label var L_AF2 "Currency and deposits"
		
gen L_AF21 = .
label var L_AF21 "Currency"
	
gen L_AF22 = .
label var L_AF22 "Transferable deposits"
	
gen L_AF221 = .
label var L_AF221 "Inter-bank positions"

gen L_AF229 = .
label var L_AF229 "Other transferable deposits"

gen L_AF29 = .
label var L_AF29 "Other deposits"
	
gen L_AF3 = .
label var L_AF3 "Debt securities"
		
gen L_AF31 = .
label var L_AF31 "Short-term debt securities"
	
gen L_AF32 = .
label var L_AF32 "Long-term debt securities"
	
gen L_AF4 = .
label var L_AF4 "Loans"

gen L_AF41 = . 
label var L_AF41 "Short-term loans"

gen L_AF42 = .
label var L_AF42 "Long-term loans"
	
gen L_AF5 = .
label var L_AF5 "Equity and investment fund shares"
 		
gen L_AF51 = .
label var L_AF51 "Equity"
	
gen L_AF511 = .
label var L_AF511 "Listed shares"

gen L_AF512 = .
label var L_AF512 "Unlisted shares"

gen L_AF519 = .
label var L_AF519 "Other equity"

gen L_AF52 = .
label var L_AF52 "Investment fund shares/units"
	
gen L_AF521 = .
label var L_AF521 "Money market fund shares/units"

gen L_AF522 = .
label var L_AF522 "Non-MMF investment fund shares/units"

gen L_AF6 = .
label var L_AF6	"Insurance, pension and standardized guarantee schemes"		

gen L_AF61 = .
label var L_AF61 "Non-life insurance technical provisions"

gen L_AF62 = .
label var L_AF62 "Life insurance and annuity entitlements"
	
gen L_AF63 = .
label var L_AF63 "Pension entitlements"

gen L_AF64 = .
label var L_AF64 "Claims of pension funds on pension managers"

gen L_AF65 = .
label var L_AF65 "Entitlements to non-pension benefits"

gen	L_AF66 = .
label var L_AF66 "Provisions for calls under standardized guarantees"
	
gen L_AF7 = .
label var L_AF7 "Financial derivatives and employee stock options"
		
gen L_AF71 = .
label var L_AF71 "Financial derivatives"
	
gen L_AF711 = .
label var L_AF711 "Options"

gen L_AF712 = .
label var L_AF712 "Forwards"

gen L_AF72 = .
label var L_AF72 "Employee stock options"
	
gen L_AF8 = .
label var L_AF8 "Other accounts payable"		

gen L_AF81  = .
label var L_AF81 "Trade credits and advances"
	
gen L_AF89 = .
label var L_AF89 "Other accounts payable"	


gen BF90 = .
label var BF90 "Financial net worth"	

* Recast all variables as double 
foreach var of varlist AN1- BF90{
   recast double `var'
}

sort year



* Save quarterly grid
*save "C:\Users\grella\Dropbox\GC Wealth Project\Data\Raw data\Create general grid\grid_q_stock.dta", replace
*save "${path}/grid_q_stock.dta", replace



* Generate and save annual grid

*save "C:\Users\grella\Dropbox\GC Wealth Project\Data\Raw data\Create general grid\grid_a_stock.dta", replace
save "${path}/grid_a_stock.dta", replace



