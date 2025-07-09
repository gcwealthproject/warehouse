/////////////////////////
/// Main do file for EIGT translation from old to new structure
/////////////////////////

/// Last update: July 2025
/// Author: Francesca


	
////////////////////////////////////////////////////////////////////////////////
/// STEP 0: a. OECD revenue download and harmonization; b .ado for new data reading/import /// 
/// 		c. US States data preparation
			
	run "$dofile/Auxiliary_Countries_OECD_Rev.do"
	run "$dofile/eigt_verify.ado"
	run "$dofile/Auxiliary_US_States.do"
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 1: Country-level data

	display as result "Checking tax schedule data for countries..."
	do "$dofile/0_1_Countries_Taxsch_Check.do"

	display as result "Updating the currency..."
	display as result "Supvar version $supvarver"
	display as result "OECD version $oecdver"	

	do "$dofile/0_2_Countries_Currency_Update.do"
	
	display as result "Translating into the new structure..."
	do "$dofile/0_3_Countries_Translation.do"

	
////////////////////////////////////////////////////////////////////////////////
/// STEP 2: New country-level data	
	
	display as result "Translating into the new structure..."
	do "$dofile/0_4_NewData_Adjustment.do"
	
////////////////////////////////////////////////////////////////////////////////
/// STEP 3: Regional-level data	

	display as result "Checking tax schedule data for US states..."
	do "$dofile/0_5_Regions_Taxsch_Check.do"
	
	display as result "Checking revenue data for US states..."
	do "$dofile/0_6_Regions_Revenues_Check.do"
	
	display as result "Translating US states into the new structure..."
	do "$dofile/0_7_Regions_Translation.do"

