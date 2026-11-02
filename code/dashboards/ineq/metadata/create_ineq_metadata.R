library(tidyverse)
library(readxl)
library(xlsx)

dictionary_path <- "handmade_tables/dictionary.xlsx"
warehouse_path <- "raw_data/taxw/intermediary_files/warehouse_ar.csv"
output_csv <- "output/metadata/metadata_ineq.csv"
output_xlsx <- "output/metadata/metadata_ineq.xlsx"

normalize_percentile <- function(x) {
  x <- as.character(x)
  x <- str_replace_all(x, "_", ".")
  recode(
    x,
    "p995p100" = "p99.5p100",
    "p999p100" = "p99.9p100",
    "p9995p100" = "p99.95p100",
    "p9999p100" = "p99.99p100",
    "p99999p100" = "p99.999p100",
    "p999999p100" = "p99.9999p100",
    .default = x
  )
}

build_metadata <- function(group_type, vartype, concept_text, group_text, percentile, entry_point) {
  case_when(
    group_type == "overall" & vartype == "gin" ~ str_c(
      "Gini index of ", concept_text, " in the overall population (", percentile, ")."
    ),
    group_type == "overall" & vartype == "dsh" ~ str_c(
      "Share of total ", concept_text, " held by the overall population (", percentile, ")."
    ),
    group_type == "overall" & vartype == "avg" ~ str_c(
      "Average ", concept_text, " among the overall population (", percentile, ")."
    ),
    group_type == "overall" & vartype == "thr" ~ str_c(
      "Minimum of ", concept_text, " (", entry_point,
      "-th percentile) of the distribution of ", concept_text, "."
    ),
    group_type == "overall" & vartype == "tot" ~ str_c(
      "Total ", concept_text, " held by the overall population (", percentile, ")."
    ),
    group_type == "overall" & vartype == "owr" ~ str_c(
      "Ownership rate of ", concept_text, " in the overall population (", percentile, ")."
    ),
    group_type == "overall" & vartype == "csh" ~ str_c(
      "Composition share of ", concept_text, " in the overall population (", percentile, ")."
    ),
    group_type == "poorest" & vartype == "thr" ~ str_c(
      "Minimum of ", concept_text, " (", entry_point,
      "-th percentile) of the distribution of ", concept_text, "."
    ),
    vartype == "gin" ~ str_c(
      "Gini index of ", concept_text, " among the ", group_text, " (", percentile, ")."
    ),
    vartype == "dsh" ~ str_c(
      "Share of total ", concept_text, " held by the ", group_text, " (", percentile, ")."
    ),
    vartype == "avg" ~ str_c(
      "Average ", concept_text, " among the ", group_text, " (", percentile, ")."
    ),
    vartype == "thr" ~ str_c(
      "Threshold of ", concept_text, " to enter the ", group_text,
      " (p", entry_point, ") of the population."
    ),
    vartype == "tot" ~ str_c(
      "Total ", concept_text, " held by the ", group_text, " (", percentile, ")."
    ),
    vartype == "owr" ~ str_c(
      "Ownership rate of ", concept_text, " among the ", group_text, " (", percentile, ")."
    ),
    vartype == "csh" ~ str_c(
      "Composition share of ", concept_text, " among the ", group_text, " (", percentile, ")."
    ),
    TRUE ~ NA_character_
  )
}

if (!file.exists(dictionary_path)) {
  stop("Dictionary file not found: ", dictionary_path, call. = FALSE)
}

if (!file.exists(warehouse_path)) {
  stop("Warehouse file not found: ", warehouse_path, call. = FALSE)
}

d3_vartype <- read_excel(dictionary_path, sheet = "d3_vartype") %>%
  transmute(d3 = code, vartype_label = str_squish(label))

d4_concept <- read_excel(dictionary_path, sheet = "d4_concept") %>%
  transmute(d4 = code, concept_label = str_squish(label))

d5_dashboard <- read_excel(dictionary_path, sheet = "d5_dboard_specific") %>%
  filter(dashboard == "Wealth Inequality") %>%
  transmute(d5 = code, d5_label = str_squish(label))

percentiles <- read_excel(dictionary_path, sheet = "percentiles") %>%
  transmute(
    percentile = normalize_percentile(percentile),
    label_percentile = str_squish(label_percentile)
  )

meta_ineq <- read_csv(warehouse_path, show_col_types = FALSE) %>%
  transmute(
    varcode = str_replace_all(varcode, "_", "-"),
    percentile = normalize_percentile(percentile)
  ) %>%
  filter(str_starts(varcode, "t-")) %>%
  distinct(varcode, percentile) %>%
  separate(varcode, into = c("d1", "d2", "d3", "d4", "d5"), sep = "-", remove = FALSE) %>%
  left_join(d3_vartype, by = "d3") %>%
  left_join(d4_concept, by = "d4") %>%
  left_join(d5_dashboard, by = "d5") %>%
  left_join(percentiles, by = "percentile") %>%
  mutate(
    concept_text = str_to_lower(concept_label),
    group_text = str_to_lower(label_percentile),
    group_type = case_when(
      percentile == "p0p100" ~ "overall",
      str_detect(label_percentile, "^Richest") ~ "richest",
      str_detect(label_percentile, "^Poorest") ~ "poorest",
      str_detect(label_percentile, "^Next") ~ "next",
      str_detect(label_percentile, "Middle") ~ "middle",
      TRUE ~ "other"
    ),
    entry_point = str_match(percentile, "^p([0-9.]+)p")[, 2],
    metadata = build_metadata(group_type, d3, concept_text, group_text, percentile, entry_point)
  )

missing_labels <- meta_ineq %>%
  filter(
    is.na(vartype_label) |
      is.na(concept_label) |
      is.na(d5_label) |
      is.na(label_percentile) |
      is.na(metadata)
  )

if (nrow(missing_labels) > 0) {
  stop(
    "Could not build metadata for some ineq pairs. Check missing dictionary labels or templates for: ",
    paste(unique(missing_labels$varcode), collapse = ", "),
    call. = FALSE
  )
}

meta_ineq <- meta_ineq %>%
  select(varcode, percentile, metadata) %>%
  distinct() %>%
  arrange(varcode, percentile)

write.csv(meta_ineq, output_csv, row.names = FALSE)
write.xlsx2(meta_ineq, output_xlsx, row.names = FALSE, sheetName = "meta_ineq")
