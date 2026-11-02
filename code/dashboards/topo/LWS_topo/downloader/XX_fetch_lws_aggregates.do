//////////////////////////////////////////////////////////////////////////// 
//																 		  // 
//	This program computes distributional statistics from LWS and LIS	  // 
// 						Author: Ignacio Flores (2021)					  //
//																 		  // 
////////////////////////////////////////////////////////////////////////////

//Prepare command (execution at the end)
//////////////////////////////////////////////////////////////////
global execute ///
	get_aggregates_lissy summarize, weight(hpopwgt) edad(0) ///
		ccyy() hvars(hpopwgt ha han hanr hanrp hanro hann hannb ///
		hannc hanncv hanncd hanno haf hafc hafi hafib hafis hafii ///
		hafo has hasi hasil hasip haso hasodb hasodc hass hassdb ///
		hassdc hl hlr hlrp hlro hln hlni hlnc hlncv hlncd hlne hlno) ///
		/*pvars(ppopwgt)*/ database(lws) //test 
//////////////////////////////////////////////////////////////////
	
//define program 
cap program drop get_aggregates_lissy
program define get_aggregates_lissy
	version 11 
	syntax name ///
		[, weight(string) EDad(real 0) CCyy(string) BCKTavgs TEST ] ///
		HVARs(string) /*PVARs(string)*/ DATAbase(string) 
		
	*-----------------------------------------------------------------------
	*PART 0: Check inputs
	*---------------------------------- -------------------------------------
	
	//Choice of database 
	if ("`database'" == "") {
		di as text "You must choose a database (LIS or LWS)"
		exit 1
	}
	if ("`database'" != "" & inlist("`database'", "lws", "lis")) {
		local database `database'
		local dname = upper("`database'")
		di as text "Extracting information from `dname' at $S_TIME"
	}
	
	//Weights
	if ("`weight'" == "") {
		local weight "ppopwgt"
		display as text "Weight: `weight' (default)"
	} 
	else {
		
	} 
	
	*select countries 
	if ("`ccyy'") == "" & "`test'" == "" {
		lissydata, `database' from(1980) to(2025) 
		local ccyy "${selected}"
		di as text "ccyy() was left empty, retrieve all (default)"
	}
	
	*select variables 
	if ("`hvars'") == "" & "`test'" == "" {
		di as text "No specific hvars were chosen, getting everything then"
	}
	if ("`hvars'") != "" {
		di as text "You just chose the following hvars: `hvars'"
	}
	if ("`pvars'") == "" & "`test'" == "" {
		di as text "No specific pvars were chosen, getting everything then"
	}
	if ("`pvars'") != "" {
		di as text "You just chose the following hvars: `pvars'"
	}

	if "`test'" == "test" {
		local ccyy xx17 zz98
	}
	*---------------------------------------------------------------------------
	*PART 1: Summary statistics 
	*---------------------------------------------------------------------------
	
	local oc = 0 
	
	// Loop over all country-years 
	foreach c in `ccyy' {
		
		//split country and year 
		local yr = substr("`c'", 3, 2)
		if `yr' < 50 local `c'year = `yr' + 2000
		if `yr' > 50 local `c'year = `yr' + 1900
		local `c'iso2 = upper(substr("`c'", 1, 2))
	
		// Open data
		clear
		
		*decide to open real or testing dataset
		if "`test'" == "" {
			qui cap lissyuse, ///
				`database' ccyy(`c') /*pvars(`pvars')*/ hvars(`hvars')	
		}
		if "`test'" != "" {
			qui set obs 2000 
			foreach v in `pvars' `hvars' {
				qui gen `v' = runiform() * 10^9
			}
			//simulate a number of implicates 
			if strpos("`c'", "xx") qui gen inum = ceil(3*runiform())
			if strpos("`c'", "zz") qui gen inum = ceil(5*runiform())
			label variable haf "label testing"
		}
		if "`database'" == "lws" {
			if "`liabilities'" != "" {
				foreach v in `liabilities' {
					qui replace `v' = -`v'
				}
			}
		} 
		
		//continue only if file exists
		cap assert _N == 0
		if _rc != 0 {
			
			*recast weight if necessary		
			/*
			cap assert int(`weight') == `weight' 
			if _rc != 0 {
				di as text "weights contained decimals" _continue
				di as text ", integers now"
				qui replace `weight' = round(`weight')
			}
			*/
			
			//save labels 
			foreach v in `hvars' {
				local `c'_`v'_lab : var label `v' 
			}

			//summarize 
			qui collapse (sum) `hvars' ///
				(rawsum) sumwgt = `weight' ///
				(count) cntobs = `weight' ///
				[pw=`weight'], fast by(inum)
			local othvars sumwgt cntobs 
			
			//count implicates 
			qui levelsof inum, clean local(inum_`c')
			qui sum inum, meanonly
			local max_inum = r(max)
			assert _N == `max_inum'
			
			//store values in memory 
			foreach i in `inum_`c'' {
				foreach v in `hvars' `othvars' {
					qui format %15.0g `v' 
					qui sum `v' if inum == `i', meanonly format
					local `v'_`c'_`i' = r(mean)
				}
			}
			
			//add to observation counter 
			local oc = `oc' + `max_inum'
		}
	}	
	
	
	//Summarize main info for all countries
	clear
	local nobs = `oc' //wordcount("`ccyy'") 
	local nvars = wordcount("`hvars'") + wordcount("`othvars'")
	local tobs =  `nobs' * `nvars'
	set obs `tobs'

	//Generate empty vars
	foreach v in country year variable inum vlabel value  {
		if inlist("`v'", "country", "variable", "vlabel") qui gen `v' = ""
		if inlist("`v'", "year", "value", "inum") {
			qui gen `v' = .
			format %15.0g `v' 
		}  
	}
	
	//Fill primary variables
	local iter = 1 
	foreach c in `ccyy' {	
		foreach i in `inum_`c'' {
			foreach v in `hvars' `othvars' {
				if ("``v'_`c'_`i''" != "") {
					qui replace country = "``c'iso2'" in `iter'
					qui replace year = ``c'year' in `iter'
					qui replace variable = "`v'" in `iter'
					qui replace inum = `i' in `iter'
					qui replace value = ``v'_`c'_`i'' in `iter'
					qui replace vlabel = "``c'_`v'_lab'" in `iter'
				}
				local iter = `iter' + 1	
			}
		}
	}
	
	//make pretty 
	qui sort country year variable inum 
		
	//keep data points in memory 
	qui gen n = _n
	local vbls country year variable inum value vlabel
	local N = _N
	forvalues n = 1/`N' {
		foreach v in `vbls' {
			if inlist("`v'", "country", "variable", "vlabel") {
				qui levelsof `v' if n == `n', clean local(scl_`v'_`n')
				scal scl_`v'_`n' = "`scl_`v'_`n''"
			}
			if inlist("`v'", "year", "value", "inum") {
				quietly sum `v' if n == `n', format 
				scal scl_`v'_`n' = r(max)
			}
		}
	}

	//display as csv 
	forvalues n = 1/`N' {
		if `n' == 1 {
			local linelength = 55
			//Prepare display table with summary info 
			display as text "{hline `linelength'}"
			display as text "INEQSTATS-LISSY Results"
			display as text "{hline `linelength'}"
			di as text "Settings: "
			di as text "Extracted from `dname' database"		
			display as text "Weight used: `weight'"
			display as text "Summarizing: `hvars' `othvars'"
			display as text "{hline `linelength'}"

			//Display csv 
			di as result ///
				"{bf:<<<<<<<<<<<<<<<< CSV file starts here >>>>>>>>>>>>>>>>>}"
			di as text "country, year, variable, inum, value, vlabel"
		} 
		di as text scl_country_`n' "," scl_year_`n' "," ///
			scl_variable_`n' "," scl_inum_`n' ","  ///
			scl_value_`n' "," scl_vlabel_`n'
		if `n' == _N {
			di as result ///
				"{bf:<<<<<<<<<<<<<<<< CSV file ends here >>>>>>>>>>>>>>>>>>>}"
			display as text "{hline `linelength'}"
		}
	}
	
end	

//Execute program 
$execute
 
