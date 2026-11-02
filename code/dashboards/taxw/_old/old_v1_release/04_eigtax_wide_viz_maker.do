********************************************************************************
*** STEP 3: Generate data file for the visualization of tax schedule
********************************************************************************

*store variable format in memory 
local fnam EIGtax_wide_visualization
di as result "storing formats from warehouse_eigt" 
qui import delimited "output/databases/`fnam'.csv", clear 
global wht eigt
run "code/mainstream/auxiliar/describe_warehouse.do"
foreach v of global whvars_eigt {
	di as result "`v': " _continue 
	foreach u in isn {
		di as text "`u'(${`v'_`u'_eigt}) " _continue 
	}
}

//import main data 
qui import excel "output/metadata/code_desc_viz.xlsx", ///
	clear sheet("long_version") firstrow
tempfile tf_cdv 
qui save `tf_cdv' 	
	
//merge it with code_desc_viz	
qui use "raw_data/eigt/eigt_ready.dta", clear 
qui merge m:1 varcode using `tf_cdv', gen(checker1)
cap assert checker1 == 3 
if _rc != 0 {
	di as error "code_desc_viz is missing some varcodes !"
	exit 1
}
qui drop checker1
qui rename description metadata 

//
gen bracket=substr(varcode, -2, 2)
destring bracket, replace
replace varcode = substr(varcode, 1, 15)
replace varcode = subinstr(varcode, "-", "_", .)
**replace varcode=substr(varcode, -10, 10)

sort area year bracket source  percentile  varcode
by area year bracket source percentile  varcode:  gen dup = cond(_N==1,0,_n)
sort dup varcode year varcode

preserve
	keep if dup>0
	qui export delimited  ///
	"raw_data/eigt/intermediary_files/eigt_long_duplicates.csv", replace  
restore

*drop duplicates values- ---- THIS NEEDS TO BE SOLVED 
drop if dup>0
drop dup
ren value* v*
tostring v, gen(val) format("%40.5g") force
replace v_str = val if v_str=="" 

*save a long version here 
preserve 
	qui drop longname vartype val  
	qui rename (v v_str geo_reg area) (value value_str GEO_reg GEO) 
	format bracket %02.0f
	tostring bracket, replace format(%02.0f)
	qui replace varcode = varcode + "-" + bracket 
	qui drop brac*
	replace varcode = subinstr(varcode, "_", "-", .)
	qui replace value_str = "" if !missing(value)
	qui rename metadata met_eigt 
	qui gen ref_link = ""
	qui save ///
		"raw_data/eigt/intermediary_files/eigt_wm.dta", ///
		replace
restore 
qui drop c_citekey 

drop percentile vartype brac varname metadata longname v val

*replace Subject = substr(Subject, 1, 16)
reshape wide v_str, i(area geo_reg year bracket source) ///
	j(varcode) string
ren v_str*  *  


*** note May, 14th 2023: simply destring here? 
replace x_hs_thr_torac1 = "." if x_hs_thr_torac1 == "_na"
destring x_* , replace 


cap order area year bracket *curren *conver *residb *eigsta *eigfir *esttax *giftax *inhtax *pickup *pickad *itaxre *ieexem *gifuni *gsttst *gifint *totrev /**eitrev *gifrev *fedrev *refrev *locrev *tprrev *fprrev *rprrev *lprrev *trvgdp *frvgdp *rrvgdp *regeig *regonl *gintpr *gyrspr *gexper *gilobo *giupbo *gtlobo *gifrat *gannex *glfexe *tgibas *flthre *crincl *feffex *fec1lb *fec1up *fe1tlb *fe1tsm *spoexe *chiexe *cl1exe *sec1lb *sec1up *se1tlb *se1tsm *cota1e *cotalb *cotaup *cottlb *cotstm *adexem *ad1lbo *ad1ubo *ad1tlb *ad1smr *of1lbo *of1ubo *of1tlb *of1smr *ef1lbo *ef1ubo *ef1tlb *ef1smr *srv1lb *srv1ub *srv1tl *srv1sm *cl1lbo *cl1ubo *cl1tlb *cl1smr *cl2exe *cl2lbo *cl2ubo *cl2tlb *cl2smr *cl3exe *cl3lbo *cl3ubo *cl3tlb *cl3smr *monest *moninh *gtopra *toprat *etopra *itopra *elowra *ilowra *torac1**/, first

	sort area year bracket

	local nb x_hs_cat_eigsta x_hs_cat_esttax x_hs_cat_giftax x_hs_cat_inhtax x_hs_str_curren 
	
	local nb2 x_hs_rat_gtopra x_hs_rat_toprat x_hs_rat_etopra x_hs_rat_itopra x_hs_thr_torac1 

	
	
*** note May, 14th 2023: changed `var'==. (from `var'=="") bcs not string anymore for second local
	foreach var in `nb'{
		replace `var'=`var'[_n-1] if area==area[_n-1] & year==year[_n-1] & `var'==""
	}
	foreach var in `nb2'{
		replace `var'=`var'[_n-1] if area==area[_n-1] & year==year[_n-1] & `var'==.
	}
	
	

*** THESE VARIABLES ARE MISSING - VERIFY
*pickad *gyrspr *gannex *glfexe *gifval *gnotes *notess  *taxbas *fec1lb *class1 *class2 *cl2exe *class3 *cl3exe *finnot

*qui drop if !missing(geo_reg)

cap order area geo_reg year bracket *curren *conver *residb *eigsta *eigfir *esttax *giftax *inhtax *pickup *pickad *itaxre *ieexem *gifuni *gsttst *gifint *totrev /**eitrev *gifrev *fedrev *refrev *locrev *tprrev *fprrev *rprrev *lprrev *trvgdp *frvgdp *rrvgdp *regeig *regonl *gintpr *gyrspr *gexper *gilobo *giupbo *gtlobo *gifrat *gannex *glfexe *tgibas *flthre *crincl *feffex *fec1lb *fec1up *fe1tlb *fe1tsm *spoexe *chiexe *cl1exe *sec1lb *sec1up *se1tlb *se1tsm *cota1e *cotalb *cotaup *cottlb *cotstm *adexem *ad1lbo *ad1ubo *ad1tlb *ad1smr *of1lbo *of1ubo *of1tlb *of1smr *ef1lbo *ef1ubo *ef1tlb *ef1smr *srv1lb *srv1ub *srv1tl *srv1sm *cl1lbo *cl1ubo *cl1tlb *cl1smr *cl2exe *cl2lbo *cl2ubo *cl2tlb *cl2smr *cl3exe *cl3lbo *cl3ubo *cl3tlb *cl3smr *monest *moninh *gtopra *toprat *etopra *itopra *elowra *ilowra *torac1**/, first

sort area geo_reg year bracket

//compare old vs new 
global wht new
preserve 
	run "code/mainstream/auxiliar/describe_warehouse.do"
restore 

foreach v in $whvars_eigt {
	foreach u in isn {
		cap assert "${`v'_`u'_eigt}" == "${`v'_`u'_new}" 
		if _rc != 0 {
			if "`u'" == "isn" local u2 is_numeric 
			if !inlist("`v'", "vgeoreg") {
				local vardes_problems_eigt `vardes_problems_eigt' ///
				`v'-`u2': eigt(${`v'_`u'_eigt})/new(${`v'_`u'_new});
			}
		}			
	}
}

//report problems 
if "`vardes_problems_eigt'" != "" {
	di as error "mismatch found in the following variables:" _continue
	di as error "`vardes_problems_eigt'"
}

//report good news
else {
	di as result ///
	"all variables match the old warehouse's format (eigt), " _continue 
	di as result "variable type (numeric or not). georeg ignored" 
}

replace source_legend = subinstr(source_legend,"–","-",4)
replace source_legend = usubinstr(source_legend,"é","e",4)



qui export delimited  ///
"raw_data/eigt/intermediary_files/EIGtax_wide_visualization.csv", replace  

*unicode convertfile "raw_data/eigt/intermediary_files/EIGtax_wide_visualization.csv" "output/databases/EIGtax_wide_visualization.csv", dstencoding(ASCII) replace

unicode convertfile "raw_data/eigt/intermediary_files/EIGtax_wide_visualization.csv" "output/databases/EIGtax_wide_visualization.csv", dstencoding(Latin-1) replace

save "raw_data/eigt/intermediary_files/eigt_wide_viz.dta", replace
