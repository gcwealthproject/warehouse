*** Currency check ***

// Inputs: handmade_tables/eigt_transcribed.xlsx, handmade_tables/national_currencies_2023.xlsx
// Output: $intfile/country_codes.dta country name, 2-digit, 3-digit ISO codes ///
			// and currency ISO code in 2023

// Take currency from ISO codes
 
import excel "handmade_tables/eigt_transcribed.xlsx", sheet(ISO_ref) cellrange(A1:D252) firstrow clear
rename (official_name_en ISO31661Alpha2 ISO31661Alpha3 ISO4217currency_alphabetic_code) ///
		(country Geo geo3 currency)
drop if currency == ""

tempfile countries
save "`countries'", replace

import excel "handmade_tables/national_currencies_2023.xlsx", firstrow clear
merge 1:m geo3 using "`countries'" 

replace nat_currency = currency if nat_currency == "" & currency != ""
drop currency _m
label var nat_currency "National currency ISO code in 2023"
duplicates drop // one for Ireland

save "$intfile/country_codes.dta", replace








