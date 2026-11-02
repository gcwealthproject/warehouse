

use "raw_data/eigt/intermediary_files/eigt_wide_viz.dta", clear

*** find inconsistencies between torac and ad1ubo
br area year x_hs_thr_torac1 x_hs_thr_ad1ubo x_hs_thr_ad1lbo if (x_hs_thr_ad1ubo == "_and_over") & (x_hs_thr_torac1 != x_hs_thr_ad1lbo) & (x_hs_thr_torac1 != .)



br area year x_hs_thr_torac1 x_hs_thr_ad1ubo x_hs_thr_ad1lbo if (x_hs_thr_ad1ubo == "_and_over") & (x_hs_thr_torac1 == x_hs_thr_ad1lbo) & (x_hs_thr_torac1 != .)


