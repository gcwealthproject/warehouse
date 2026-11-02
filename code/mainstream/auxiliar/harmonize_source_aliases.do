//Purpose: map legacy dashboard source codes to canonical dictionary source codes.
//Default: harmonizes variable -source- using handmade_tables/dictionary.xlsx,
//sheet SourceAliases. Optional args: source_var dictionary_path alias_sheet.

args source_var dictionary_path alias_sheet

if "`source_var'" == "" local source_var source
if "`dictionary_path'" == "" local dictionary_path "handmade_tables/dictionary.xlsx"
if "`alias_sheet'" == "" local alias_sheet SourceAliases

cap confirm variable `source_var'
if _rc == 0 {
	cap confirm string variable `source_var'
	if _rc != 0 {
		qui tostring `source_var', replace force
	}
	cap recast str244 `source_var', force

	tempfile tf_source_aliases
	preserve
		cap import excel "`dictionary_path'", ///
			sheet("`alias_sheet'") firstrow clear case(lower)
		if _rc == 0 {
			cap confirm variable alias
			local has_alias = (_rc == 0)
			cap confirm variable source
			local has_source = (_rc == 0)
			if `has_alias' == 1 & `has_source' == 1 {
				qui keep alias source
				foreach v in alias source {
					cap confirm string variable `v'
					if _rc != 0 qui tostring `v', replace force
					qui replace `v' = strtrim(`v')
				}
				qui rename alias `source_var'
				qui rename source canonical_source
				qui drop if missing(`source_var') | missing(canonical_source)
				qui duplicates drop `source_var', force
				qui save `tf_source_aliases', replace
			}
		}
	restore

	cap confirm file "`tf_source_aliases'"
	if _rc == 0 {
		tempvar source_order
		qui gen long `source_order' = _n
		merge m:1 `source_var' using `tf_source_aliases', keep(1 3) nogen
		qui count if !missing(canonical_source)
		if r(N) > 0 {
			di as result "harmonized source aliases: " r(N) ///
				" observation(s) mapped through `alias_sheet'"
		}
		qui replace `source_var' = canonical_source if !missing(canonical_source)
		qui drop canonical_source
		qui sort `source_order'
		qui drop `source_order'
	}
}
