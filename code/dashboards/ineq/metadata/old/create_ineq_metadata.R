library(tidyverse)
library(readxl)
library(xlsx)
library(qdapRegex)

#d1 set set to "t"
d1_dashboard <- "t-"
#d2 set to to "ho"
d2_sector <- "hs"

#d3 vartype
vartypes_t <- c("dsh", "csh", "gin", "avg", "thr")
d3_vartype <- read_excel("handmade_tables/dictionary.xlsx", 
                                                      sheet = "d3_vartype")
d3_vartype <- d3_vartype %>% filter(code %in% vartypes_t)

#d4 concept
#only net net wealth in inequality trends-section
d4_concept <- "netwea"
#d5 dashboard
d5_dashboard <- read_excel("handmade_tables/dictionary.xlsx", 
                                            sheet = "d5_dboard_specific") %>%
  filter(dashboard == "Wealth Inequality Trends")

#percentiles
percentiles <- read_excel("handmade_tables/dictionary.xlsx", 
                          sheet = "percentiles")

#d1d2d3d4
out <- data.frame(out = NA, vartype = NA)
for(l in 1:length(unique(d3_vartype$code))){
  out[l,1] <- paste0(d1_dashboard, d2_sector, "-", unique(d3_vartype$code)[l], "-", d4_concept)
  out[l,2] <- unique(d3_vartype$code)[l]
}

#d1d2d3d4d5 + unit of analysis description for metadata
df_out <- data.frame(out = rep(out$out, length(d5_dashboard$code)), 
                     vartype = rep(out$vartype, length(d5_dashboard$code)),
                     d5 = rep(d5_dashboard$code, dim(out)[1]))

df_out <- merge(df_out, d5_dashboard %>% select(d5=code, label))
#Add percentiles
df_in <- merge(df_out, percentiles %>% select(percentile))
df_in <- left_join(df_in, percentiles)

#Start filling it
overall <- "p0p100"
richest <- "Richest"
poorest <- "Poorest"
next_p <- "Next"
upper_middle <- "Middle"
#tsh lower percentiles 
df_in$percentile <- ifelse(df_in$percentile=="p995p100", "p99.5p100", df_in$percentile)
perc <- ex_between(df_in$percentile, "p", "p")
perc <- as.character(do.call(rbind, perc))
df_in$perc_thresholds <- perc
df_in$perc_thresnolds_num <- as.numeric(perc)
df_in$varcode <- paste0(df_in$out, "-",df_in$d5)

  #overall
  tmpa <- df_in %>% filter(percentile==overall)
  tmpa$percentile_help <- qdapRegex::ex_between(tmpa$percentile, "p", "p")
  #n=35
  md_overall <- tmpa %>% 
    mutate(metadata = case_when(
    vartype=="gin" ~  paste0("Gini index of net wealth in the overall population (", percentile, ")."),
    vartype=="dsh" ~  paste0("NOT_AVAILABLE_IN_WAREHOUSE"),
    vartype=="avg" ~  paste0("Average net wealth among the overall population (", percentile, ")."),
    vartype=="csh" ~ "NOT_AVAILABLE_IN_WAREHOUSE",
    vartype=="thr" ~  paste0("Minimum of  net wealth (", 
                             perc_thresnolds_num, "-th percentile) of the distribution of net wealth.")))
  
  #richest n=350
  tmpb <- df_in %>% filter(str_detect(label_percentile, richest))
  md_richest <- tmpb %>%
    mutate(metadata = case_when(
      vartype=="gin" ~ paste0("Gini index of net wealth among the ", tolower(label_percentile), 
                              " (", percentile, ")."), 
      vartype=="dsh" ~ paste0("Share of total net wealth held by the ",  tolower(label_percentile),
                                " (", percentile, ")."), 
      vartype=="avg" ~ paste0("Average net wealth among the " , tolower(label_percentile), " (", percentile, ")."),
      vartype=="csh" ~ "NOT_AVAILABLE_IN_WAREHOUSE",
      vartype=="thr" ~ paste0("Threshold of net wealth to enter the ", 
                              tolower(label_percentile), 
                              " (p", perc_thresnolds_num, ") of the population.")))
                          
  #poorest  n = 385
  tmpc <- df_in %>% filter(str_detect(label_percentile, poorest))
  md_poorest <- tmpc %>%
    mutate(metadata = case_when(
      vartype=="gin" ~ paste0("Gini index of net wealth among the ", 
                              tolower(label_percentile), " (", percentile, ")."),
      vartype=="dsh" ~ paste0("Share of total net wealth held by the ",  tolower(label_percentile),
                              " (", percentile, ")."), 
      vartype=="avg" ~ paste0("Average net wealth among the " , tolower(label_percentile),
                              " (", percentile, ")."),
      vartype=="csh" ~ "NOT_AVAILABLE_IN_WAREHOUSE",
      vartype=="thr" ~  paste0("Minimum of net wealth (", perc_thresnolds_num,
                               "-th percentile) of the distribution of net wealth." )))
  
  #next 
  tmpd <- df_in %>% filter(str_detect(label_percentile, next_p))
  md_next <- tmpd %>%
    mutate(metadata = case_when(
      vartype=="gin" ~ paste0("Gini index of net wealth among the ",
                              tolower(label_percentile), " (", percentile, ")."), 
      vartype=="dsh" ~ paste0("Share of total net wealth held by the ",  tolower(label_percentile),
                              " (", percentile, ")."), 
      vartype=="avg" ~ paste0("Average net wealth among the " , tolower(label_percentile), 
                              " (", percentile, ")."), 
      vartype=="csh" ~ "NOT_AVAILABLE_IN_WAREHOUSE",
      vartype=="thr" ~ paste0("Threshold of net wealth to enter the ", 
                              tolower(label_percentile), 
                              " (p", perc_thresnolds_num, ") of the population.")))
  
  
  #middle
  tmpe<- df_in %>% filter(str_detect(label_percentile, upper_middle))
  md_middle <- tmpe %>%
    mutate(metadata = case_when(
      vartype=="gin" ~ paste0("Gini index of net wealth among the ", tolower(label_percentile), 
                              " (", percentile, ")."),
      vartype=="dsh" ~ paste0("Share of total net wealth held by the ",  tolower(label_percentile),
                              " (", percentile, ")."), 
      vartype=="avg" ~ paste0("Average net wealth of the " , tolower(label_percentile),
                              " (", percentile, ")."), 
      vartype=="csh" ~ "NOT_AVAILABLE_IN_WAREHOUSE",
      vartype=="thr" ~ paste0("Threshold of net wealth to enter the ", 
                              tolower(label_percentile), 
                              " (p", perc_thresnolds_num, ") of the population.")))
  
 
  meta_ineq <- bind_rows(md_overall, md_richest, md_poorest, md_next, md_middle)

  meta_ineq <- meta_ineq %>% filter(metadata !="NOT_AVAILABLE_IN_WAREHOUSE") %>%
    select(varcode, percentile, metadata)

  meta_ineq <- unique(meta_ineq)
  write.csv(meta_ineq, "output/metadata/metadata_ineq.csv", row.names = FALSE)
  write.xlsx2(meta_ineq, "output/metadata/metadata_ineq.xlsx", row.names = FALSE, sheetName = "meta_ineq")
