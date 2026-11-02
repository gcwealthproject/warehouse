
run "code/mainstream/auxiliar/all_paths.do"


//create_grid_stock.do
//When updating data, input to create_grid_stock.do needs to be updated to
qui do "${topo_pro}/OECD NA/codes/create_grid_stock.do"


***


// generate grid
do "${topo_pro}/OECD NA/codes/gen_mapped_grid.do"
qui di as result "the grid has been generated!"
pwd

//run translate and populate grid
qui do "${topo_pro}/OECD NA/codes/translate.do"
qui di as result "raw data have been translated and the grid has been populated!"
pwd

cd ..
cd ..
cd ..
cd ..

//gen metadata
do "${topo_pro}/OECD NA/codes/gen_metadata.do"
qui di as result "metadata have been generated!"
pwd 


//gen topography
do "${topo_pro}/OECD NA/codes/gen_topography.do"
qui di as result "topography have been generated!"
qui di as result "topography have saved in final table/OECD_FA_warehouse.csv!"
pwd 




