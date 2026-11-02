
//runs all do-files to build ECB data 
run "code/mainstream/auxiliar/all_paths.do"


//create_grid_stock.do
//When updating data, input to create_grid_stock.do needs to be updated to
qui do "${topo_pro}/ECB_QSA/codes/create_grid_stock.do"

*exit 1
//run translate and populate grid
do "${topo_pro}/ECB_QSA/codes/translate.do"
qui di as result "raw data have been translated!"
pwd

// gen grid
do "${topo_pro}/ECB_QSA/codes/gen_mapped_grid.do"
qui di as result "grid has been generated!"
pwd

//gen metadata
do "${topo_pro}/ECB_QSA/codes/gen_metadata.do"
qui di as result "metadata have been generated!"
pwd 

//gen topography
do "${topo_pro}/ECB_QSA/codes/gen_topography.do"
qui di as result "topography have been generated!"
qui di as result "topography have saved in final table/ECB_QSA_warehouse.csv!"
pwd 




