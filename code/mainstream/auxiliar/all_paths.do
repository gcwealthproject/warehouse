

//1. define paths and directories 

//inequality and trends
global ineq_dir_raw raw_data/ineq
global ineq_code 	code/dashboards/ineq


//Inheritance and trends
global inhe_dir_raw raw_data/inhe
global inhe_code 	code/dashboards/inhe


//topography 
global topo_dir_raw raw_data/topo
global topo_code 	code/dashboards/topo
	
//supplementary variables 
global supvar_wid_dwld raw_data/wid	
global wb raw_data/wb	
global politics raw_data/politics
global sv_folder output/databases/supplementary_variables

//excels 
global code_translator handmade_tables/code_translator

//auxiliary do-files 	
global memorize_labels code/mainstream/auxiliar/store_labels_in_memory.do
global memorize_ctry_names  code/mainstream/auxiliar/store_ctries_in_memory.do 
global fill_longname code/mainstream/auxiliar/fill_longname.do
global harmonize_ctries code/mainstream/auxiliar/harmonize_country_names.do
global harmonize_source_aliases code/mainstream/auxiliar/harmonize_source_aliases.do
global check_nonmissings code/mainstream/auxiliar/check_nonmissings.do
