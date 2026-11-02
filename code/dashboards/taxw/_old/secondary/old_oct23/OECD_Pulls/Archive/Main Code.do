
do "D:/My Drive/PhD Stuff/Stone Center/JEM 01a_check_errors.do"

*https://www.statalist.org/forums/forum/general-stata-discussion/general/1653859-update-data-file

************************************
******* OECD Member Countries ******
************************************

*These commands will pull the 4300, 4310, and 4320 tax indicators for each OECD member country.
*Percentages have "PC" in the unit column, with a powercode of 0.

*Level of government: total

*4300:  EIG
*4310: EI
*4320: G

*tax rev: in national currency, as % of GDP, as % of total taxation, tax rev of government subsectors as % of total taxation

*want to account for the power code via multiplying (not for percents though as that'd blow them away.  Maybe make the power code 1 where power code is 0 and then multiply?)
		


************************************
**** Non-OECD Member Countries *****
************************************

*These commands will pull the 4300, 4310, and 4320 tax indicators for all countries in the data.
*Here, blank units are percentages


*BE SURE TO DO THE DO FILES in the check error do file immediately after the import.  so that it goes through the checks.




