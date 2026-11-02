** Set the globals ** 

	run "code/mainstream/auxiliar/all_paths.do"

	
*** 1. Politics *** 
	
	global parl parlgov 
	global comp CPDS_1960-2021_Update_2023 


* Adjust and assempling inputs - parlgov and comparative politics data

	import excel "$politics/$parl.xlsx", firstrow clear sheet("party") 
	qui keep party_id country_name family_name state_market 
	tempfile party 
	save `party'
	
	import excel "$politics/$parl.xlsx", firstrow clear sheet("cabinet") 
	qui merge m:1 country_name party_id using `party', keep(match) nogen 
	
	
	** Create the days of duration of each cabinet ** 
	* 1. Create the start-date of each cabinet 
	gen startdate_c = date(start_date, "YMD")
	format startdate_c %td 

	* 2. Destring the election date
	gen electiondate = date(election_date, "YMD")
	format electiondate %td 

	
	* 3. Create the end date of each cabinet. Here we can have different cabinet WITHIN THE SAME ELECTION or a different cabinet DUE TO A NEW ELECTION. Therefore, the end-date reflect a change in the cabinet in both conditions. 
	
	* 3.0 - Create new cabinet and election id to be ordered chronologically 
	egen c_id = group(country_name start_date cabinet_id)
	egen e_id = group(country_name election_date election_id)
	
	
	* 3.a - enddate within same election 
	bysort country_name e_id (c_id) : gen enddate_c = startdate[_n+1] if c_id!=c_id[_n+1]
	format enddate_c %td 
	bysort c_id (enddate_c) : replace enddate_c = enddate_c[1]
	
	* 3.b - enddate due to different elections 
	bysort country_name (c_id)  : replace enddate_c = electiondate[_n+1] if enddate_c==. & c_id!=c_id[_n+1] 
	bysort c_id (enddate_c) : replace enddate_c = enddate_c[1]

	* 4. Days duration of each cabinet 
	gen day_duration_c = enddate_c - startdate_c
	
	* Check day_duration_c is not negative: sum day_duration_c -- ok! 
	
	* 5. Create the whole duration of an election period starting from the election date to the next election date
	
	bysort country_name (e_id) : gen enddate_e = electiondate[_n+1] if e_id!=e_id[_n+1]
	bysort e_id (enddate_e) : replace enddate_e = enddate_e[1]
	format enddate_e %td 
	
	gen day_duration_e = enddate_e - electiondate 

	** IMPORTANT: The last election does not have an end-date, so we do not have day_duration_e. So we compute the total sum of days of different cabinets (if any) within the last election id  
	
	* Fix the end at the 31-12 of the last observable year in the country 
	bysort country_name : gen last_date = mdy(12, 31, year(date(start_date, "YMD"))) if start_date==start_date[_N]
	format last_date %td 
	
	* Set the duration of the last cabinet with respect to the end of the last year 
	bysort country_name : replace day_duration_c = last_date - startdate_c if start_date==start_date[_N]
	
	* Compute the total days within the last election_id as the sum of the cabinet-specific days 
	egen unique_flag = tag(country_name e_id c_id)
	bysort country_name : egen max_election = max(e_id)
	bysort country_name : gen last_election = e_id == max_election
	bysort country_name (e_id) : egen last_days = sum(day_duration_c) if unique_flag==1 & last_election==1 
	bysort e_id (last_days) : replace last_days = last_days[1]
	
	bysort country_name e_id : gen weights = (day_duration_c / day_duration_e)
	
	* Replace the weights for the last election using day_duration_c/last_days
	bysort country_name e_id : replace weights = (day_duration_c / last_days) if last_election==1  
	
	drop unique_flag max_election last_election 

	
	* 6. Keep the parties participating in the government and create the corresponding definitions of gov_left2/3 

	/* 	a. The gov_left2 gov_right2 and gov_cent2 variables: seats share of the right/left/centre parties in government over parliamentary seats of ALL GOVERNING parties (weighted by days in office in a given year) 
		b. The gov_left3 gov_right3 and gov_cent3 variables: seats share of the right/left/centre parties in government over all parliamentary seats (weighted by days in office in a given year)
	*/ 
	
	keep if cabinet_party==1 
	
	* 6.a Definition 2
	
		* Cabinet seats 
			bysort country_name e_id c_id : egen gov_seats = total(seats) 
		
		* Right seats 
			bysort country_name e_id c_id : egen r_seats = total(seats) if inlist(family_name, "Conservative", "Right-wing", "Christian democracy") 		| (family_name=="Agrarian" & left_right>3.5) | (family_name=="Liberal" & left_right>3.5) | (family_name=="Special issue" & left_right>3.5)
		
		* Left seats 
			bysort country_name e_id c_id : egen l_seats = total(seats) if inlist(family_name, "Social democracy", "Green/Ecologist", 			"Communist/Socialist") | (family_name=="Agrarian" & left_right<=3.5) | (family_name=="Liberal" & left_right<=3.5) | (family_name=="Special issue" &			  left_right<=3.5)
	
	
	gen gov_right2 = (r_seats/gov_seats)
	gen gov_left2  = (l_seats/gov_seats) 
	
	
	* 6.b Definition 3 
	gen gov_right3 = (r_seats/election_seats_total)
	gen gov_left3  = (l_seats/election_seats_total)
	

	* 7. Need to collapse to one year-country-government and then fill the years, to finally create the gov_party variable 
	/* For this purpose, use the startdate_c year and then use weights to collapse the two definitions by country-year */ 
	
	gen year = year(date(start_date, "YMD"))
	
	* Within each year/election, keep the cabinet with the longest duration 
	bysort country_name year : egen max_duration = max(day_duration_c) 
	keep if day_duration_c==max_duration 
	
	
	collapse (mean) gov_right2 gov_left2 gov_right3 gov_left3  day_duration_c [aw=weights] , by(country_name country_name_short year)
	rename gov_right2 gov_right2M 
	rename gov_left2  gov_left2M
	rename gov_right3 gov_right3M
	rename gov_left3  gov_left3M 
	
	* In the comparative politics dta they use the 1st definition, we need to use 2nd and/or 3rd 
	gen gov_party = . 
	replace gov_party = 1 if (gov_left2M == 0 | gov_left2M==. ) & gov_right2M!=. 
	replace gov_party = 2 if gov_left2M <= 0.3333 
	replace gov_party = 3 if gov_left2M>0.3333 & gov_left2M< 0.6667
	replace gov_party = 4 if gov_left2M>=0.6667 & gov_left2M<1 
	replace gov_party = 5 if (gov_left2M==1 | gov_right2M==.) & gov_left2M!=.  

	cap assert missing(gov_party)
	if _rc!= 9 { 
	disp as error "Warning: cases without govern party"
	exit 
	}


	* Import USA to flag as democratic and republican *	
	preserve 
	qui import excel  "$politics/usa_elections.xlsx", firstrow clear sheet("Foglio1")
	gen country_name_short = "USA"
	tempfile usa
	save `usa'
	restore 
	
	append using `usa'
 


	* 8. Adding the "missing years"
	encode country_name, gen(country)
	drop country_name
	xtset country year 
	tsfill 

	* Count the inserted rows for each country: 
	bysort country (year) : gen flag =1 if country_name== "" 

	bysort country : gen change_indicator = flag != flag[_n-1] | _n == 1
	bysort country : replace change_indicator = sum(change_indicator)
	bysort country change_indicator: gen consecutive_ones = sum(flag == 1)
	bysort country change_indicator: replace consecutive_ones = consecutive_ones[_N] if flag == 1
	
	/* Problem: we need to exclude the filling for the "too many" added rows i.e., for a period longer of the election period. The general maximum period is 5, France 7 until 2000. So, we set as missing all those consecutive ones more than 5 */ 
	
	tab year country if consecutive_ones>5 

/* These are: 
	- Austria, from 1933 to 1944 
	- Finland, from 1938 to 1943 
	- Germany, from 1934 to 1948 
	- Malta,   from 1956 to 1961 
	- Norway,  from 1937 to 1944 

Therefore, all cases but Malta refer to WW2 period. Germany and Austria will be set as dictatorship. 
The other can be flagged as War period or missings (?) */ 

		
	* Filling the missings: 
	decode country, gen(country_name)
	
	bysort country_name (year) : replace gov_party = gov_party[_n-1] if gov_party==. & consecutive_ones<=5
	bysort country_name (year) : replace country_name_short = country_name_short[_n-1] if country_name_short==""
	 
	
	replace gov_party = 1 if country_name=="Germany" & (year>=1934 & year<=1948)
	replace gov_party = 1 if country_name=="Austria" & (year>=1933 & year<=1944) // set the dictatorship to right-dictatorship
	
	
	drop gov_right* gov_left*  country flag change_indicator consecutive_ones day_duration_c
	
	rename country_name_short GEO3 
	replace country_name = "United States" if GEO3=="USA"
	
	* Order variables 
	sort GEO3 year 
	order country_name GEO3 year gov_party  

	/* Decide whether to extend "Hegemony of right wing" to all years of USA */
	
	tempfile parlgov 
	save `parlgov'


********************************************************************************
*** Match parlgov with comparative politics *** 
********************************************************************************

	qui use "$politics/$comp.dta", clear 


* Keep the required variables - country, year, iso, government type and color, post-communist dummy, and some institutional variables (federalism, bicamearislm, etc.). 
	qui keep year country iso poco eu gov_party  gov_left2 fed pres prop bic 
	
	gen gov_party2 = . 
	replace gov_party2 = 1 if gov_left2==0
	replace gov_party2 = 2 if gov_left2>0 & gov_left2<=33.33
	replace gov_party2 = 3 if gov_left>33.33 & gov_left2<66.67
	replace gov_party2 = 4 if gov_left2>=66.67 & gov_left2<100 
	replace gov_party2 = 5 if gov_left2==100 
		
* Merge with parlgov 
	rename (iso gov_party ) (GEO3 gov_party1 )  
	
	merge 1:1 GEO3 year using `parlgov'

* Check the consistency of definition in parlgov 
	bysort GEO3 : gen _diff = 1 if (gov_party1<3 & gov_party>3) & _merge==3  
	bysort GEO3 : egen tot_diff = total(_diff)
	bysort GEO3 : egen tot_n = count(GEO3) if _merge==3 
	gen share_diff = (tot_diff/tot_n)*100 
	
	bysort GEO3 : sum share_diff
	
/* The error ranges between a minimum of 0 and 11% (in Cyprus) */ 

	
/* The definition is sufficiently robust to extend the dta backward with parlgov data. 
Of course, we replace the gov_party with comparative politics dta definition for the matched cases! */ 
	
	replace gov_party = gov_party2 if _merge==3 // replace our created gov_party in parlgov with the comparative politics dta
	replace gov_party = gov_party2 if _merge==1 // keep the gov_party2 for those coming from comparative politics data 
	
	replace gov_party = 6 if presidential_elections == "democratic"
	replace gov_party = 7 if presidential_elections == "republican"

	label define govparty 1 "Hegemony of right wing" 2 "Dominance of right wing" 3 "Balance btw left and right" /// 
		4 "Dominance of social-democratic & left" 5 "Hegemony of social-democratic & left" 6 "Democrat" 7 "Republican"
	
	label values gov_party govparty 

	replace country_name = country if _merge==1 
		
	rename country_name GEO_long
	
* Select the correct GEO name 
	preserve 
	qui import excel "handmade_tables/dictionary.xlsx", firstrow clear sheet("GEO")
	drop D-U 
	drop if GEO3=="_na"
	rename Country GEO_long
	keep in 1/249
	
	tempfile geo 
	save `geo'
	restore 
	
	merge m:1 GEO3 using `geo', keep(match) nogen 
	
	keep GEO year gov_party 
	order GEO year gov_party  
	sort GEO year 

	
** Export wide 
	rename GEO country 
	save "output/databases/supplementary_variables/politics/politics_wide.dta", replace 
	

** Reshape in long-format to match wid supplementary vars 
	label values gov_party // drop value label for long append
	rename gov_party valuegov_party 

	qui reshape long value, i(country year) j(variable) string

** Export long 
	qui export delimited ///
		"output/databases/supplementary_variables/politics/long_politics.csv", replace 	
	qui save ///
		"output/databases/supplementary_variables/politics/long_politics.dta", replace 	
		

*** 2. World Bank *** 

* 1. Combine WB sources 

	import excel "$wb/CLASS.xlsx", clear firstrow sheet("List of economies")
	drop if Economy == ""
	
	keep Economy Code Region Incomegroup 
	rename (Code Region) (GEO3 Region1)
	keep in 1/218
	
	tempfile wb1
	save `wb1'
	
	import excel "$wb/wits.xlsx", clear firstrow sheet("Country-Metadata") 
	
	* Drop "General Categories" from the File * 
	local cntrylist `" "Belgium-Luxembourg" "East Asia & Pacific" "Europe & Central Asia" "Free Zones" "German Democratic Republic" "Latin America & Caribbean" "Middle East & North Africa" "Neutral Zone" "North America" "Other Asia, nes"  "Pacific Islands" "South Asia" "Soviet Union" "Special Categories" "United States Minor Outlying I" "Unspecified" "Western Sahara" "World" "Us Msc.Pac.I" "Ethiopia(includes Eritrea)" "Yugoslavia,FR(Serbia/Montenegr"  "Serbia, FR(Serbia/Montenegro)" "Sub-Saharan Africa"  "'
	
	foreach name of local cntrylist {
    drop if CountryName == "`name'"
	}	
	
	rename CountryISO3 GEO3  
	keep CountryName GEO3 Region IncomeGroup LendingCategory
	
	merge 1:1 GEO3 using `wb1'
	
	/*
	With respect to wits file, we require some adjustments: 
	East Timor is now Timor-Leste, TLS; 
	Romania is ROU; 
	Congo, Dem. Rep as ZAR to drop 
	Czechoslovakia to drop 
	Yemen Democratic to drop 
	*/ 
	
	drop if GEO3 == "TMP" | GEO3 ==	"ZAR" | GEO3 == "CSK" | GEO3 == "YDR" | GEO3 == "ROM"
	
	gen GEO_WB = Economy if _merge==3 | _merge==2 
	replace GEO_WB = CountryName if _merge==1 
	
	gen Region_WB = Region1 if _merge==3 | _merge==2 
	replace Region_WB = Region if _merge==1 
	
	gen Income_WB = Incomegroup if _merge==3 | _merge==2 
	replace Income_WB = IncomeGroup if _merge==1 
	
	gen Lending_WB = LendingCategory if _merge==3 | _merge==2 
	replace Lending_WB = LendingCategory if _merge==1 
	
	drop Economy CountryName IncomeGroup Incomegroup LendingCategory Region1 _merge

	
* 2. Match the countries we have in dictionary 
* a. Open the dictionary file and save it temporarily 
	preserve 
	import excel "handmade_tables/dictionary.xlsx", clear firstrow sheet("GEO")
	drop if GEO3 == "_na"
	drop D-U
	keep in 1/249
	tempfile geo 
	save `geo'
	restore 	
	
* b. Merge  
	merge 1:1 GEO3 using `geo', nogen keep(2 3)
	
	drop Region Lending_WB Income_WB
	rename (Country GEO) (GEO_long country) 
	tempfile geo_full
	save `geo_full'
	
* 3. Add the income group historical data 
	import excel "$wb/OGHIST.xlsx", clear sheet("Country Analytical History") cellrange(A6:AM240) firstrow 
	
	* Adjust the import 
	drop if A == ""
	rename A GEO3 
	drop Dataforcalendaryear 

	* Set the variable name as their labels - e.g., y1987, y1989, etc. 
	foreach v of varlist C-AM {
		local x : variable label `v'
		rename `v' y`x'
	}

	reshape long y@ , i(GEO3) j(year)
	rename y income_group 
	tab income_group
	replace income_group = subinstr(income_group, "*", "", .) // remove special character 
	
	replace income_group = "High" if income_group == "H"
	replace income_group = "Low" if income_group == "L"
	replace income_group = "Lower-middle" if income_group == "LM"
	replace income_group = "Upper-middle" if income_group == "UM"
	
	merge m:1 GEO3 using `geo_full', keep(3) nogen 
	replace income_group = "" if income_group == ".." 
	replace Region_WB = ""  if Region_WB == "NULL"

	
* Export - wide and long format 
	drop GEO_long
	save "output/databases/supplementary_variables/wb/geo_wide.dta", replace 
	
	encode Region_WB, gen(valueRegion)
	encode income_group, gen(valueIncome_group)
	drop Region_WB income_group
	label values valueRegion
	label values valueIncome_group
	
	reshape long value, i(year GEO_WB GEO3 country) j(variable) string
	
	save "output/databases/supplementary_variables/wb/geo_long.dta", replace 

