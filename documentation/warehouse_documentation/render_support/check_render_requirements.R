#!/usr/bin/env Rscript

# Internal preliminary checks for render.R.
#
# Users should normally open render.R and choose:
#   [2] Preliminary checks (find missing tools)
#
# Expected terminal use:
#   1. Open a terminal in the warehouse_documentation folder and run:
#   Rscript render.R 2
#   Or, from the repository root, run:
#   Rscript documentation/warehouse_documentation/render.R 2
#
# If the check reports missing installable dependencies, rerun with an
# installation flag. This can download packages and modify your local R/TinyTeX
# libraries, so the default mode only reports missing requirements.
#
# Install missing R packages and installable TinyTeX packages:
#   Rscript render.R 2 --install
#
# Show all command-line options:
#   Rscript render_support/check_render_requirements.R --help
#
# Equivalent environment flags for installation mode:
#   INSTALL_MISSING_RENDER_DEPS=true Rscript render.R 2
#   INSTALL_MISSING_R=true Rscript render.R 2
#   INSTALL_MISSING_TEX=true Rscript render.R 2

truthy <- function(x) {
  tolower(x) %in% c("1", "true", "t", "yes", "y")
}

usage_text <- function() {
  paste(c(
    "Preliminary checks for rendering the warehouse documentation",
    "",
    "Usage:",
    "  Rscript render_support/check_render_requirements.R [options]",
    "  Rscript documentation/warehouse_documentation/render_support/check_render_requirements.R [options]",
    "",
    "Run from the warehouse_documentation directory or the repository root. The",
    "script checks render requirements only; it does not render the documentation.",
    "",
    "Options:",
    "  -h, --help      Show this help text and exit.",
    "  --install       Install missing R packages and installable TinyTeX packages.",
    "  --install-r     Install missing R packages only.",
    "  --install-tex   Install missing TinyTeX packages only.",
    "",
    "Default behavior:",
    "  With no install flags, the script reports missing dependencies and exits",
    "  with a non-zero status if anything required is missing.",
    "",
    "Installation progress:",
    "  In install mode, the script prints each install step before it runs, lets",
    "  install.packages() or tinytex/tlmgr print their normal download/install",
    "  output, then rechecks the dependency list and reports anything still",
    "  missing.",
    "",
    "Environment flags equivalent to command-line install options:",
    "  INSTALL_MISSING_RENDER_DEPS=true  Same as --install.",
    "  INSTALL_MISSING_R=true            Same as --install-r.",
    "  INSTALL_MISSING_TEX=true          Same as --install-tex."
  ), collapse = "\n")
}

show_help <- function() {
  cat(usage_text(), "\n", sep = "")
}

find_this_script <- function() {
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile) && basename(frame$ofile) == "check_render_requirements.R") {
      return(normalizePath(frame$ofile, mustWork = FALSE))
    }
  }

  cmd <- commandArgs(FALSE)
  file_arg <- grep("^--file=", cmd, value = TRUE)
  if (length(file_arg)) {
    invoked_file <- sub("^--file=", "", file_arg[[1]])
    if (basename(invoked_file) == "check_render_requirements.R") {
      return(normalizePath(invoked_file, mustWork = FALSE))
    }
  }

  support_path <- file.path("render_support", "check_render_requirements.R")
  if (file.exists(support_path)) {
    return(normalizePath(support_path, mustWork = TRUE))
  }

  normalizePath("check_render_requirements.R", mustWork = FALSE)
}

script_file <- find_this_script()
script_dir <- dirname(script_file)
base_dir <- if (basename(script_dir) == "render_support") {
  dirname(script_dir)
} else {
  script_dir
}
base_dir <- normalizePath(base_dir, mustWork = FALSE)

path_from_base <- function(path) {
  if (grepl("^(/|~|[A-Za-z]:[/\\\\])", path)) {
    return(path.expand(path))
  }
  file.path(base_dir, path)
}

missing_r_packages <- function(packages) {
  packages[!vapply(packages, function(package) {
    suppressPackageStartupMessages(
      suppressWarnings(requireNamespace(package, quietly = TRUE))
    )
  }, logical(1))]
}

install_r_packages <- function(packages) {
  if (!length(packages)) return(invisible(TRUE))

  repos <- getOption("repos")
  if (is.null(repos) || identical(unname(repos["CRAN"]), "@CRAN@")) {
    repos <- c(CRAN = "https://cloud.r-project.org")
  }

  install.packages(packages, repos = repos)
  invisible(TRUE)
}

kpsewhich_has <- function(sty_file) {
  if (!nzchar(Sys.which("kpsewhich"))) return(FALSE)
  status <- suppressWarnings(system2("kpsewhich", sty_file,
    stdout = FALSE, stderr = FALSE
  ))
  identical(status, 0L)
}

tlmgr_install <- function(packages) {
  if (!length(packages)) return(invisible(TRUE))

  if (!requireNamespace("tinytex", quietly = TRUE)) {
    message("tinytex R package is missing; installing tinytex first.")
    install_r_packages("tinytex")
  }
  message("Requesting TinyTeX/tlmgr installation for: ",
    paste(unique(packages), collapse = ", ")
  )
  tinytex::tlmgr_install(unique(packages))
  invisible(TRUE)
}

relative_from_base <- function(path) {
  normalized_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  normalized_base <- normalizePath(base_dir, winslash = "/", mustWork = FALSE)
  base_prefix <- paste0(normalized_base, "/")
  if (startsWith(normalized_path, base_prefix)) {
    return(substring(normalized_path, nchar(base_prefix) + 1L))
  }
  normalized_path
}

format_hit <- function(path, line, text) {
  paste0(relative_from_base(path), ":", line, ": ", trimws(text))
}

format_hit_list <- function(hits, max_hits = 12L) {
  shown <- head(hits, max_hits)
  suffix <- if (length(hits) > max_hits) {
    paste0("\n  - ... ", length(hits) - max_hits, " more")
  } else {
    ""
  }
  paste0(paste(shown, collapse = "\n  - "), suffix)
}

windows_path_hits <- function(paths) {
  hits <- character()
  for (path in paths[file.exists(paths)]) {
    lines <- readLines(path, warn = FALSE)
    idx <- grep("(^|[^A-Za-z0-9_])[A-Za-z]:\\\\", lines)
    if (length(idx)) {
      hits <- c(hits, vapply(
        idx,
        function(i) format_hit(path, i, lines[[i]]),
        character(1)
      ))
    }
  }
  hits
}

unsafe_include_graphics_hits <- function(paths) {
  hits <- character()
  for (path in paths[file.exists(paths)]) {
    lines <- readLines(path, warn = FALSE)

    include_idx <- grep("include_graphics\\s*\\(", lines)
    for (i in include_idx) {
      window <- lines[i:min(length(lines), i + 4L)]
      uses_file_path <- any(grepl("file\\.path\\(", window))
      uses_render_path <- any(grepl("render_path\\(", window))
      if (uses_file_path && !uses_render_path) {
        hits <- c(hits, format_hit(path, i, lines[[i]]))
      }
    }

    latex_idx <- grep("includegraphics", lines, fixed = TRUE)
    for (i in latex_idx) {
      window <- lines[max(1L, i - 5L):i]
      builds_latex_path <- any(grepl("cat\\(", window)) ||
        any(grepl("file\\.path\\(", window))
      uses_render_path <- any(grepl("render_path\\(", window))
      if (builds_latex_path && !uses_render_path) {
        hits <- c(hits, format_hit(path, i, lines[[i]]))
      }
    }
  }
  unique(hits)
}

generated_debug_files <- function() {
  root_debug <- list.files(
    base_dir,
    pattern = "^_render_.*\\.(Rmd|tex)$|^warehouse_documentation\\.tex$",
    full.names = TRUE
  )

  output_dir <- path_from_base("outputs")
  output_debug <- if (dir.exists(output_dir)) {
    list.files(output_dir, pattern = "\\.(Rmd|tex)$", full.names = TRUE)
  } else {
    character()
  }

  unique(c(root_debug, output_debug))
}

audit_render_path_safety <- function(active_sources) {
  active_sources <- unique(active_sources[file.exists(active_sources)])
  problems <- c(
    windows_path_hits(active_sources),
    unsafe_include_graphics_hits(active_sources)
  )

  generated_warnings <- windows_path_hits(generated_debug_files())

  list(
    problems = unique(problems),
    generated_warnings = unique(generated_warnings)
  )
}

check_render_requirements <- function(install = FALSE,
                                      install_r = install,
                                      install_tex = install,
                                      stop_on_error = TRUE) {
  problems <- character()
  message("Preliminary checks base directory: ", normalizePath(base_dir, mustWork = FALSE))

  required_r <- c(
    "countrycode",
    "data.table",
    "dplyr",
    "expss",
    "flextable",
    "ftExtra",
    "glue",
    "haven",
    "janitor",
    "kableExtra",
    "knitr",
    "magrittr",
    "readr",
    "readxl",
    "rmarkdown",
    "stringr",
    "tibble",
    "tidyr",
    "tidyverse"
  )

  message("Checking R packages...")
  missing_r <- missing_r_packages(required_r)
  if (length(missing_r) && install_r) {
    message("Missing R packages found: ", paste(missing_r, collapse = ", "))
    message("Starting R package installation via install.packages().")
    tryCatch(
      install_r_packages(missing_r),
      error = function(e) {
        problems <<- c(problems, paste0(
          "R package installation failed: ", conditionMessage(e)
        ))
      }
    )
    message("Rechecking R packages after installation attempt...")
    missing_r <- missing_r_packages(required_r)
  } else if (length(missing_r)) {
    message("R package installation is disabled; reporting missing packages only.")
  }

  if (length(missing_r)) {
    problems <- c(problems, paste0(
      "Missing R packages: ", paste(missing_r, collapse = ", ")
    ))
  } else {
    message("R packages: ok")
  }

  message("Checking TeX command-line tools...")
  required_commands <- c("xelatex", "biber", "kpsewhich")
  missing_commands <- required_commands[!nzchar(Sys.which(required_commands))]

  if (length(missing_commands) && install_tex && "biber" %in% missing_commands) {
    message("Missing TeX command-line tools found: ",
      paste(missing_commands, collapse = ", ")
    )
    message("Attempting to install biber via TinyTeX/tlmgr.")
    tryCatch(
      tlmgr_install("biber"),
      error = function(e) {
        problems <<- c(problems, paste0(
          "TeX binary installation failed: ", conditionMessage(e)
        ))
      }
    )
    message("Rechecking TeX command-line tools after installation attempt...")
    missing_commands <- required_commands[!nzchar(Sys.which(required_commands))]
  } else if (length(missing_commands)) {
    message("TeX command installation is disabled or unavailable for this tool; reporting only.")
  }

  if (length(missing_commands)) {
    problems <- c(problems, paste0(
      "Missing required command(s): ", paste(missing_commands, collapse = ", ")
    ))
  } else {
    message("TeX commands: ok")
  }

  message("Checking Pandoc...")
  if (requireNamespace("rmarkdown", quietly = TRUE)) {
    pandoc_ok <- tryCatch(rmarkdown::pandoc_available(), error = function(e) FALSE)
    if (!pandoc_ok) {
      problems <- c(problems, "Pandoc is not available to rmarkdown.")
    } else {
      message("Pandoc: ok")
    }
  } else {
    message("Skipping Pandoc check because rmarkdown is not available.")
  }

  required_tex <- data.frame(
    name = c(
      "amsmath",
      "array",
      "biblatex",
      "bookmark",
      "booktabs",
      "colortbl",
      "float",
      "geometry",
      "graphics",
      "longtable",
      "makecell",
      "multirow",
      "pdflscape",
      "placeins",
      "setspace",
      "tabu",
      "threeparttable",
      "threeparttablex",
      "titling",
      "ulem",
      "wrapfig",
      "xcolor"
    ),
    sty = c(
      "amsmath.sty",
      "array.sty",
      "biblatex.sty",
      "bookmark.sty",
      "booktabs.sty",
      "colortbl.sty",
      "float.sty",
      "geometry.sty",
      "graphicx.sty",
      "longtable.sty",
      "makecell.sty",
      "multirow.sty",
      "pdflscape.sty",
      "placeins.sty",
      "setspace.sty",
      "tabu.sty",
      "threeparttable.sty",
      "threeparttablex.sty",
      "titling.sty",
      "ulem.sty",
      "wrapfig.sty",
      "xcolor.sty"
    ),
    tlpkg = c(
      "amsmath",
      "tools",
      "biblatex",
      "bookmark",
      "booktabs",
      "colortbl",
      "float",
      "geometry",
      "graphics",
      "tools",
      "makecell",
      "multirow",
      "pdflscape",
      "placeins",
      "setspace",
      "tabu",
      "threeparttable",
      "threeparttablex",
      "titling",
      "ulem",
      "wrapfig",
      "xcolor"
    ),
    stringsAsFactors = FALSE
  )

  message("Checking LaTeX packages...")
  missing_tex <- required_tex[!vapply(required_tex$sty, kpsewhich_has, logical(1)), ]

  if (nrow(missing_tex) && install_tex) {
    message("Missing TeX packages found: ",
      paste(sprintf("%s (%s)", missing_tex$name, missing_tex$sty), collapse = ", ")
    )
    message("Starting TinyTeX/tlmgr package installation.")
    tryCatch(
      tlmgr_install(missing_tex$tlpkg),
      error = function(e) {
        problems <<- c(problems, paste0(
          "TeX package installation failed: ", conditionMessage(e)
        ))
      }
    )
    message("Rechecking LaTeX packages after installation attempt...")
    missing_tex <- required_tex[!vapply(required_tex$sty, kpsewhich_has, logical(1)), ]
  } else if (nrow(missing_tex)) {
    message("TeX package installation is disabled; reporting missing packages only.")
  }

  if (nrow(missing_tex)) {
    problems <- c(problems, paste0(
      "Missing TeX package(s): ",
      paste(sprintf("%s (%s)", missing_tex$name, missing_tex$sty), collapse = ", ")
    ))
  } else {
    message("TeX packages: ok")
  }

  config_env <- new.env(parent = baseenv())
  config_file <- path_from_base(file.path("render_support", "render_config.R"))
  tryCatch(
    source(config_file, local = config_env, chdir = TRUE),
    error = function(e) {
      problems <<- c(problems, paste0(
        "Could not read render_config.R: ",
        conditionMessage(e)
      ))
    }
  )

  child_docs <- if (exists("required_child_files", envir = config_env, inherits = FALSE)) {
    get("required_child_files", envir = config_env)()
  } else {
    character()
  }

  required_files <- c(
    child_docs,
    file.path("render_support", "render_config.R"),
    "render.R",
    file.path("render_support", "check_render_requirements.R"),
    "../BibTeX files/digital_library.bib",
    "docs/GCWealthLogo-V2.png",
    "docs/widvars.csv",
    "docs/bible_ineq_sources.xlsx",
    "docs/bible_wt_concepts.xlsx",
    "docs/bible_wt_consolidation.xlsx",
    "docs/bible_wt_finpos.xlsx",
    "docs/bible_wt_generalcomposition.xlsx",
    "docs/bible_wt_matching.xlsx",
    "docs/bible_wt_sectors.xlsx",
    "docs/bible_wt_source_composition_v2.xlsx",
    "docs/bible_wt_sources.xlsx",
    "docs/bible_wt_tables.xlsx",
    "docs/build_composition_workbook.R",
    "docs/stylized_flow_chart_ineq.png",
    "docs/stylizes_flow_chart_wt.png",
    "../../handmade_tables/dictionary.xlsx",
    "../../handmade_tables/taxw_currency.xlsx",
    "../../handmade_tables/taxw_input_format.xlsx",
    "../../handmade_tables/exclude_sources_ineq.xlsx",
    "../../raw_data/taxw/taxw_ready.csv",
    "../../raw_data/ineq/CS_ineq/raw data/data_quality_table.xlsx",
    "../../raw_data/ineq/WID_ineq/raw data/data_quality_table.xlsx",
    "../../raw_data/ineq/ineq_ready.csv"
  )

  alternative_required_files <- list()

  if (exists("warehouse_version", envir = config_env, inherits = FALSE)) {
    warehouse_version <- get("warehouse_version", envir = config_env, inherits = FALSE)
    required_files <- c(required_files, paste0(
      "../../output/databases/warehouse/warehouse_v", warehouse_version, ".csv"
    ))
    required_files <- c(required_files, paste0(
      "../../output/databases/warehouse/warehouse_meta_v", warehouse_version, ".csv"
    ))
  }

  message("Checking required input files...")
  required_files <- unique(required_files)
  missing_files <- required_files[!file.exists(vapply(
    required_files,
    path_from_base,
    character(1)
  ))]

  if (length(missing_files)) {
    problems <- c(problems, paste0(
      "Missing required file(s):\n  - ",
      paste(missing_files, collapse = "\n  - ")
    ))
  } else {
    message("Input files: ok")
  }

  missing_alternatives <- character()
  for (alternative_name in names(alternative_required_files)) {
    alternatives <- alternative_required_files[[alternative_name]]
    alternative_paths <- vapply(alternatives, path_from_base, character(1))
    if (!any(file.exists(alternative_paths))) {
      missing_alternatives <- c(missing_alternatives, paste0(
        alternative_name,
        " (one of: ",
        paste(alternatives, collapse = ", "),
        ")"
      ))
    }
  }

  if (length(missing_alternatives)) {
    problems <- c(problems, paste0(
      "Missing required alternative file set(s):\n  - ",
      paste(missing_alternatives, collapse = "\n  - ")
    ))
  }

  active_source_files <- unique(c(
    "render.R",
    file.path("render_support", "render_config.R"),
    file.path("render_support", "check_render_requirements.R"),
    child_docs
  ))
  active_source_paths <- vapply(active_source_files, path_from_base, character(1))

  message("Checking render path safety...")
  path_audit <- audit_render_path_safety(active_source_paths)
  if (length(path_audit$problems)) {
    problems <- c(problems, paste0(
      "Potential Windows path render hazard(s) in active source files:\n  - ",
      format_hit_list(path_audit$problems)
    ))
  } else {
    message("Render path safety: active sources ok")
  }

  if (length(path_audit$generated_warnings)) {
    message("Render path safety warning:")
    message(
      "Generated debug files contain stale Windows-style paths. ",
      "Rerun through render.R instead of compiling these files directly:\n  - ",
      format_hit_list(path_audit$generated_warnings)
    )
  }

  if (length(problems)) {
    message("Preliminary checks failed:")
    for (problem in problems) {
      message("- ", problem)
    }

    if (stop_on_error) {
      stop("Missing render requirements; see messages above.", call. = FALSE)
    }
    return(invisible(FALSE))
  }

  message("All warehouse documentation render requirements are available.")
  invisible(TRUE)
}

running_as_script <- local({
  cmd <- commandArgs(FALSE)
  file_arg <- grep("^--file=", cmd, value = TRUE)
  if (!length(file_arg)) return(FALSE)

  invoked_file <- normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = FALSE)
  identical(basename(invoked_file), "check_render_requirements.R") &&
    identical(invoked_file, script_file)
})

if (running_as_script) {
  args <- commandArgs(trailingOnly = TRUE)
  allowed_args <- c("--help", "-h", "--install", "--install-r", "--install-tex")
  unknown_args <- setdiff(args, allowed_args)

  if ("--help" %in% args || "-h" %in% args) {
    show_help()
    quit(status = 0)
  }

  if (length(unknown_args)) {
    message("Unknown option(s): ", paste(unknown_args, collapse = ", "))
    message("")
    show_help()
    quit(status = 2)
  }

  install_all <- "--install" %in% args || truthy(Sys.getenv("INSTALL_MISSING_RENDER_DEPS"))
  install_r <- install_all || "--install-r" %in% args || truthy(Sys.getenv("INSTALL_MISSING_R"))
  install_tex <- install_all || "--install-tex" %in% args || truthy(Sys.getenv("INSTALL_MISSING_TEX"))

  check_render_requirements(
    install = install_all,
    install_r = install_r,
    install_tex = install_tex
  )
}
