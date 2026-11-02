To run the entire warehouse for TAXW, version updated July 2026:
- run 0_Paths
- run 1_0_TAXW_New_Warehouse

[1_0_taxw_New_Warehouse includes running of the Auxiliary do files, of the content of USstates folder, and of all the do files in code/taxw folder (from 1_1 to 1_7)]

The folder "Preliminary" should be run only in case of data updates and BEFORE running the warehouse code. It starts from data in excel for single sources for each country, checks the validity of the data through the taxw_verify_intermediate ado file, and addresses any conflict and/or overlapping between sources. The result are Final_Data_country excel files (available in "intermediary files"), completely harmonized and ready for the main code.

To update also the graphs for the country sheets:
- run 0_Paths
- run 2_0_Check_coverage
