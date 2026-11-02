//general settings 
clear all 
run "code/mainstream/auxiliar/all_paths.do"
run "code/mainstream/auxiliar/version_control.do" //centralized version control
	
//run all code from TAXW 

/* To fully replicate TAXW structure we need to follow this order: 
	1. 0_Paths 
	2. 1_0_TAXW_Warehouse
*/ 	
*1.	
display as result "running 0_Paths..."
run "code/dashboards/taxw/0_Paths.do"	

*2. 
display as result "running 1_0_TAXW_Warehouse.do..."
do "code/dashboards/taxw/1_0_TAXW_Warehouse.do"

di as result "done building TAXW tax!"

