use "raw_data/eigt/intermediary_files/eigt_transcribed.dta", clear

bys Geo year: gen number = _n

encode Source_1, gen(temp1)
encode Source_2, gen(temp2)
encode Source_3, gen(temp3)
encode Source_4, gen(temp4)
encode Source_5, gen(temp5)
encode Source_6, gen(temp6)
encode Source_7, gen(temp7)


bys Geo year GeoReg: gen tag = 1 if (number != number[_n-1]) & Geo==Geo[_n-1] & ((temp1 != temp1[_n-1]) | (temp2 != temp2[_n-1]) | (temp3 != temp3[_n-1]) | (temp4 != temp4[_n-1]) | (temp5 != temp5[_n-1]) | (temp6 != temp6[_n-1]) | (temp7 != temp7[_n-1]))
