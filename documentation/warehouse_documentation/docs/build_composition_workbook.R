library(readr)
library(dplyr)
library(stringr)
library(openxlsx)

################################################################################
#### Composition Tables ####
################################################################################

# ── 1. Load data ──────────────────────────────────────────────────────────────
if (!exists("warehouse_version")) {
  warehouse_version <- "2"
}
warehouse_meta_path <- paste0("../../output/databases/warehouse/warehouse_meta_v", warehouse_version, ".csv")
df <- read_csv(warehouse_meta_path, show_col_types = FALSE) |>
  filter(substr(varcode, 1, 1) == "p")

# ── 2. Extract composition rule from metadata ─────────────────────────────────
extract_formula <- function(meta) {
  str_match(meta, "we use the following formula:\\s*(.*?)(?:\\.|Using)")[, 2] |>
    str_trim()
}

df <- df |>
  mutate(composition_rule = extract_formula(metadata))

# ── 3. Build summary table ────────────────────────────────────────────────────
summary_tbl <- df |>
  group_by(source, d2_sector_lab, d2_sector, d4_concept_lab, d4_concept, composition_rule) |>
  summarise(Frequency = n_distinct(GEO), .groups = "drop") |>
  rename(
    Sector   = d2_sector_lab,
    Code     = d4_concept,
    Concept  = d4_concept_lab,
    `Composition rule using codes` = composition_rule
  ) |>
  select(source, Sector, Code, Concept, `Composition rule using codes`, Frequency)

# ── 4. Write one sheet per source ─────────────────────────────────────────────
sources <- sort(unique(summary_tbl$source))
cat("Sources found:", paste(sources, collapse = ", "), "\n")

wb <- createWorkbook()
for (src in sources) {
  sheet_data <- summary_tbl |>
    filter(source == src) |>
    select(-source) |>
    arrange(Sector, Code, `Composition rule using codes`)
  sheet_name <- str_trunc(src, 31)
  addWorksheet(wb, sheet_name)
  writeDataTable(wb, sheet_name, sheet_data, tableStyle = "TableStyleMedium9")
  setColWidths(wb, sheet_name, cols = 1:ncol(sheet_data),
               widths = c(22, 10, 10, 55, 12))
}

# ── 5. Save ───────────────────────────────────────────────────────────────────
saveWorkbook(wb, "docs/bible_wt_source_composition_v2.xlsx", overwrite = TRUE)
