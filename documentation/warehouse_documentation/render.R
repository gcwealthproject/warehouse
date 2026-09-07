# Open this file in RStudio and click Source to render documentation.
# The script prints a console menu for your choice

truthy <- function(x) {
  tolower(x) %in% c("1", "true", "t", "yes", "y")
}

find_this_script <- function() {
  cmd <- commandArgs(FALSE)
  file_arg <- grep("^--file=", cmd, value = TRUE)
  if (length(file_arg)) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE))
  }

  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile) && basename(frame$ofile) == "render.R") {
      return(normalizePath(frame$ofile, mustWork = TRUE))
    }
  }

  normalizePath("render.R", mustWork = TRUE)
}

script_file <- find_this_script()
base_dir <- dirname(script_file)
support_dir <- file.path(base_dir, "render_support")
source(file.path(support_dir, "render_config.R"))
setwd(doc_root)

bibliography_file <- file.path(doc_root, "..", "BibTeX files", "digital_library.bib")
bibliography_resource <- "../BibTeX files/digital_library.bib"

dir.create(outputs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(section_outputs_dir, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
install_all_requested <- "--install" %in% args ||
  truthy(Sys.getenv("INSTALL_MISSING_RENDER_DEPS"))
install_r_requested <- install_all_requested || "--install-r" %in% args ||
  truthy(Sys.getenv("INSTALL_MISSING_R"))
install_tex_requested <- install_all_requested || "--install-tex" %in% args ||
  truthy(Sys.getenv("INSTALL_MISSING_TEX"))
open_rendered_output <- !("--no-open" %in% args) &&
  !truthy(Sys.getenv("NO_OPEN_RENDERED_OUTPUT"))
selection_args <- args[!startsWith(args, "--")]

targets <- section_targets()
targets$option <- targets$index + 2L

format_target <- function(target) {
  sprintf("[%s] %s (%s)", target$option, target$label, target$file)
}

menu_lines <- c(
  paste0("[1] Full documentation (", master_output_file, ")"),
  "[2] Preliminary checks (find missing tools)",
  vapply(seq_len(nrow(targets)), function(i) {
    format_target(targets[i, ])
  }, character(1))
)

read_selection <- function() {
  if (length(selection_args)) {
    return(paste(selection_args, collapse = ","))
  }

  if (!interactive()) {
    stop(
      "No option selected. Run with a choice, for example: ",
      "Rscript render.R 1, Rscript render.R 2, Rscript render.R gral.Rmd, ",
      "or from the repository root: ",
      "Rscript documentation/warehouse_documentation/render.R 1",
      call. = FALSE
    )
  }

  cat("\nRender Warehouse Documentation\n", sep = "")
  cat("------------------------------\n\n", sep = "")
  cat(paste(menu_lines, collapse = "\n"), "\n\n", sep = "")
  cat(
    "Type an option number, several section numbers separated by commas, ",
    "a section filename, or full.\n",
    sep = ""
  )
  flush.console()
  readline("Selection: ")
}

match_section <- function(piece, targets) {
  piece_lower <- tolower(piece)

  key_match <- which(tolower(targets$key) == piece_lower)
  file_match <- which(tolower(targets$file) == piece_lower)
  label_match <- which(tolower(targets$label) == piece_lower)

  unique(c(key_match, file_match, label_match))
}

parse_selection <- function(selection, targets) {
  selection <- trimws(selection)
  if (!nzchar(selection)) {
    stop("No option selected.", call. = FALSE)
  }

  selection_lower <- tolower(selection)
  if (selection_lower %in% c("1", "full", "all", "document", "documentation")) {
    return(list(type = "full"))
  }
  if (selection_lower %in% c("2", "check", "checks", "preliminary")) {
    return(list(type = "checks"))
  }

  pieces <- trimws(unlist(strsplit(selection, "[,;[:space:]]+")))
  pieces <- pieces[nzchar(pieces)]

  selected <- integer()
  for (piece in pieces) {
    piece_lower <- tolower(piece)

    if (piece_lower %in% c("full", "all", "document", "documentation")) {
      stop("Choose the full documentation by itself, not mixed with sections.", call. = FALSE)
    }
    if (piece_lower %in% c("check", "checks", "preliminary")) {
      stop("Choose preliminary checks by itself, not mixed with sections.", call. = FALSE)
    }

    if (grepl("^[0-9]+$", piece)) {
      option <- as.integer(piece)
      if (option == 1L) {
        stop("Choose the full documentation by itself, not mixed with sections.", call. = FALSE)
      }
      if (option == 2L) {
        stop("Choose preliminary checks by itself, not mixed with sections.", call. = FALSE)
      }

      idx <- which(targets$option == option)
      if (!length(idx)) {
        stop("Selection out of range: ", piece, call. = FALSE)
      }
      selected <- c(selected, idx)
      next
    }

    match_idx <- match_section(piece, targets)
    if (!length(match_idx)) {
      stop("Unknown option or section: ", piece, call. = FALSE)
    }
    selected <- c(selected, match_idx)
  }

  list(type = "sections", indices = unique(selected))
}

artifact_patterns <- c(
  "aux", "log", "out", "toc", "lof", "lot", "tex",
  "bbl", "bcf", "blg", "run.xml", "knit.md"
)

cleanup_render_artifacts <- function(stem, output_dir) {
  # LaTeX can leave auxiliary files beside the source Rmd, beside the temporary
  # wrapper, or inside the output directory depending on the render path.
  files <- c(
    file.path(doc_root, paste0(stem, ".", artifact_patterns)),
    file.path(sections_dir, paste0(stem, ".", artifact_patterns)),
    file.path(output_dir, paste0(stem, ".", artifact_patterns))
  )
  unlink(files[file.exists(files)])
}

cleanup_target_artifacts <- function(target) {
  cleanup_render_artifacts(target$key, section_outputs_dir)
  cleanup_render_artifacts(
    tools::file_path_sans_ext(target$output_file),
    section_outputs_dir
  )
}

section_output_format <- function() {
  # Direct section renders bypass the master YAML, so this format recreates the
  # LaTeX packages and bibliography support that sections normally inherit from
  # the master document.
  bibliography <- render_path(
    bibliography_file,
    mustWork = FALSE
  )

  bibliography_header <- tempfile("warehouse-bibliography-", fileext = ".tex")
  writeLines(paste0("\\addbibresource{", bibliography, "}"), bibliography_header, useBytes = TRUE)

  rmarkdown::pdf_document(
    citation_package = "biblatex",
    toc = FALSE,
    toc_depth = 3,
    number_sections = TRUE,
    highlight = "tango",
    df_print = "kable",
    latex_engine = "xelatex",
    extra_dependencies = c(
      "titling", "setspace", "placeins", "float", "pdflscape",
      "graphicx", "xcolor", "colortbl", "amsmath", "makecell",
      "booktabs", "longtable"
    ),
    includes = rmarkdown::includes(in_header = bibliography_header)
  )
}

r_string <- function(x) {
  encodeString(render_path(x), quote = "\"")
}

yaml_string <- function(x) {
  encodeString(x, quote = "\"")
}

wrapper_lines <- function(target) {
  # Some sections do not set up their own render context. For those, a temporary
  # wrapper gives them a small master-like YAML header and a setup chunk.
  bibliography <- render_path(
    bibliography_file,
    mustWork = FALSE
  )
  body <- readLines(target$path, warn = FALSE)
  if (length(body) >= 2 && identical(trimws(body[[1]]), "---")) {
    yaml_end <- which(trimws(body[-1]) == "---")
    if (length(yaml_end)) {
      body <- body[-seq_len(yaml_end[[1]] + 1)]
    }
  }

  c(
    "---",
    paste0("title: ", yaml_string(paste(target$label, "Preview"))),
    "author: \"\"",
    "date: \"\"",
    "output:",
    "  pdf_document:",
    "    citation_package: biblatex",
    "    toc: no",
    "    toc_depth: 3",
    "    number_sections: yes",
    "    highlight: tango",
    "    df_print: kable",
    "    latex_engine: xelatex",
    "header-includes:",
    "- \\usepackage{titling}",
    "- \\usepackage[margin=2.5cm]{geometry}",
    "- \\usepackage{setspace}",
    "- \\usepackage{placeins}",
    "- \\usepackage{float}",
    "- \\usepackage{pdflscape}",
    "- \\usepackage{graphicx}",
    "- \\usepackage{xcolor}",
    "- \\usepackage{colortbl}",
    "- \\usepackage{amsmath}",
    "- \\usepackage{makecell}",
    "- \\usepackage{booktabs}",
    "- \\usepackage{longtable}",
    "- \\renewcommand{\\chaptername}{Section}",
    paste0("- \\addbibresource{", bibliography, "}"),
    "urlcolor: blue",
    "documentclass: report",
    "link-citations: yes",
    "suppress-bibliography: no",
    "---",
    "",
    "```{r setup, include=FALSE}",
    paste0("source(", r_string(file.path(doc_root, "render_support", "render_config.R")), ")"),
    "knitr::opts_knit$set(root.dir = doc_root)",
    "```",
    "",
    body,
    ""
  )
}

uses_render_config <- function(path) {
  # A simple line-based check is enough here and avoids brittle quote-sensitive
  # regular expressions.
  lines <- readLines(path, warn = FALSE)
  any(grepl("source\\(", lines) & grepl("render_config\\.R", lines))
}

render_direct_section <- function(target) {
  # Sections that source render_config.R themselves are rendered directly. This
  # avoids recursive wrapper behavior while still passing the shared root paths.
  output_stem <- tools::file_path_sans_ext(target$output_file)
  render_env <- new.env(parent = globalenv())
  sys.source(file.path(doc_root, "render_support", "render_config.R"), envir = render_env)

  cleanup_render_artifacts(output_stem, section_outputs_dir)

  message("Rendering ", target$label, " (", target$file, ")...")
  output_path <- rmarkdown::render(
    input = target$path,
    output_format = section_output_format(),
    output_file = target$output_file,
    output_dir = section_outputs_dir,
    intermediates_dir = section_outputs_dir,
    knit_root_dir = doc_root,
    envir = render_env,
    quiet = FALSE
  )

  cleanup_render_artifacts(output_stem, section_outputs_dir)

  message("Created: ", normalizePath(output_path, mustWork = FALSE))
  invisible(output_path)
}

render_wrapped_section <- function(target) {
  # Plain sections are rendered through a temporary wrapper so they get a
  # standalone title, bibliography, and LaTeX setup without editing the section.
  wrapper_stem <- paste0("_render_", target$key)
  wrapper_file <- file.path(doc_root, paste0(wrapper_stem, ".Rmd"))
  output_stem <- tools::file_path_sans_ext(target$output_file)
  success <- FALSE

  cleanup_render_artifacts(wrapper_stem, section_outputs_dir)
  cleanup_render_artifacts(output_stem, section_outputs_dir)
  unlink(wrapper_file)

  writeLines(wrapper_lines(target), wrapper_file, useBytes = TRUE)
  on.exit(if (success) unlink(wrapper_file), add = TRUE)

  message("Rendering ", target$label, " (", target$file, ")...")
  output_path <- rmarkdown::render(
    input = wrapper_file,
    output_file = target$output_file,
    output_dir = section_outputs_dir,
    intermediates_dir = section_outputs_dir,
    envir = new.env(parent = globalenv()),
    quiet = FALSE
  )

  success <- TRUE
  cleanup_render_artifacts(wrapper_stem, section_outputs_dir)
  cleanup_render_artifacts(output_stem, section_outputs_dir)
  unlink(wrapper_file)

  message("Created: ", normalizePath(output_path, mustWork = FALSE))
  invisible(output_path)
}

render_one_section <- function(target) {
  if (uses_render_config(target$path)) {
    return(render_direct_section(target))
  }

  render_wrapped_section(target)
}

render_selected_sections <- function(selected_targets) {
  cat("Selected sections:\n")
  for (i in seq_len(nrow(selected_targets))) {
    cat("- ", selected_targets$label[[i]], " (", selected_targets$file[[i]], ")\n", sep = "")
  }
  cat("\n")

  outputs <- lapply(seq_len(nrow(selected_targets)), function(i) {
    render_one_section(selected_targets[i, ])
  })

  invisible(lapply(seq_len(nrow(selected_targets)), function(i) {
    cleanup_target_artifacts(selected_targets[i, ])
  }))

  # Some LaTeX auxiliary files can be written a moment after rmarkdown::render()
  # returns. The immediate cleanup handles normal cases; the delayed cleanup
  # catches late files after successful section renders without hiding failed
  # render diagnostics.
  section_cleanup_stems <- unique(c(
    selected_targets$key,
    paste0("_render_", selected_targets$key),
    tools::file_path_sans_ext(selected_targets$output_file)
  ))
  schedule_delayed_cleanup(section_cleanup_stems, section_outputs_dir)

  output_paths <- unlist(outputs, use.names = FALSE)
  cat("\nDone. Created section PDF(s):\n")
  for (output_path in output_paths) {
    cat("- ", normalizePath(output_path, mustWork = FALSE), "\n", sep = "")
  }
  cat("Folder: ", normalizePath(section_outputs_dir, mustWork = FALSE), "\n", sep = "")
  open_rendered_documents(output_paths)
  invisible(outputs)
}

render_full_document <- function() {
  # The master file lives in sections/ to keep the root folder user-facing. For
  # rendering, we copy it to a temporary root-level wrapper so LaTeX writes
  # byproducts where the normal cleanup can remove them after success.
  master_stem <- tools::file_path_sans_ext(master_rmd_file)
  wrapper_stem <- "_render_master"
  wrapper_file <- file.path(doc_root, paste0(wrapper_stem, ".Rmd"))
  output_stem <- tools::file_path_sans_ext(master_output_file)
  success <- FALSE

  cleanup_render_artifacts(master_stem, outputs_dir)
  cleanup_render_artifacts(wrapper_stem, outputs_dir)
  cleanup_render_artifacts(output_stem, outputs_dir)
  unlink(wrapper_file)

  wrapper_lines <- readLines(master_rmd_path, warn = FALSE)
  wrapper_lines <- ifelse(
    grepl('^- \\\\addbibresource\\{.*(BothLibraries|digital_library)\\.bib\\}$', wrapper_lines),
    paste0("- \\addbibresource{", bibliography_resource, "}"),
    wrapper_lines
  )
  wrapper_lines <- grep(
    '^bibliography: ".*(BothLibraries|digital_library)\\.bib"$',
    wrapper_lines,
    value = TRUE,
    invert = TRUE
  )
  writeLines(wrapper_lines, wrapper_file, useBytes = TRUE)
  on.exit(if (success) unlink(wrapper_file), add = TRUE)

  message("Rendering full documentation (", master_output_file, ")...")
  output_path <- rmarkdown::render(
    input = wrapper_file,
    output_file = master_output_file,
    output_dir = doc_root,
    knit_root_dir = doc_root,
    envir = new.env(parent = globalenv()),
    quiet = FALSE
  )

  success <- TRUE
  cleanup_render_artifacts(master_stem, outputs_dir)
  cleanup_render_artifacts(wrapper_stem, outputs_dir)
  cleanup_render_artifacts(output_stem, outputs_dir)
  unlink(wrapper_file)

  message("Created: ", normalizePath(output_path, mustWork = FALSE))
  Sys.sleep(0.1)
  cleanup_render_artifacts(master_stem, outputs_dir)
  cleanup_render_artifacts(wrapper_stem, outputs_dir)
  cleanup_render_artifacts(output_stem, outputs_dir)
  invisible(output_path)
}

cleanup_full_document_artifacts <- function() {
  Sys.sleep(2)
  cleanup_render_artifacts(tools::file_path_sans_ext(master_rmd_file), outputs_dir)
  cleanup_render_artifacts("_render_master", outputs_dir)
  cleanup_render_artifacts(tools::file_path_sans_ext(master_output_file), outputs_dir)
}

schedule_delayed_cleanup <- function(stems, output_dir, delay = 1, passes = 5) {
  # rmarkdown/tinytex can write the final .aux/.log files after render() has
  # returned. A short retry loop catches those late files, but it is only run
  # after a successful render so failed renders keep their diagnostics.
  for (pass in seq_len(passes)) {
    if (pass > 1L) {
      Sys.sleep(delay)
    }
    invisible(lapply(unique(stems), cleanup_render_artifacts, output_dir = output_dir))
  }
  invisible(TRUE)
}

open_rendered_documents <- function(paths) {
  # Successful renders open automatically for RStudio users. The --no-open flag
  # keeps scripted checks quiet without changing the normal menu behavior.
  if (!isTRUE(open_rendered_output)) {
    return(invisible(FALSE))
  }

  paths <- unique(normalizePath(unlist(paths), mustWork = FALSE))
  paths <- paths[file.exists(paths)]
  if (!length(paths)) {
    return(invisible(FALSE))
  }

  for (path in paths) {
    message("Opening: ", path)
    tryCatch(
      utils::browseURL(path),
      error = function(e) {
        message("Could not open automatically: ", conditionMessage(e))
      }
    )
  }

  invisible(TRUE)
}

ask_yes_no <- function(prompt) {
  if (!interactive()) {
    return(FALSE)
  }
  answer <- tolower(trimws(readline(prompt)))
  answer %in% c("y", "yes")
}

run_preliminary_checks <- function() {
  # The check script remains separate so it can still be run directly, but the
  # menu exposes it to users who prefer not to use terminal commands.
  check_env <- new.env(parent = globalenv())
  sys.source(
    file.path(doc_root, "render_support", "check_render_requirements.R"),
    envir = check_env
  )

  ok <- check_env$check_render_requirements(
    install = install_all_requested,
    install_r = install_r_requested,
    install_tex = install_tex_requested,
    stop_on_error = FALSE
  )

  if (!isTRUE(ok) && !install_all_requested && interactive()) {
    cat("\nSome tools or packages needed for rendering are missing.\n", sep = "")
    if (ask_yes_no("Install missing dependencies now? [y/N] ")) {
      ok <- check_env$check_render_requirements(
        install = TRUE,
        install_r = TRUE,
        install_tex = TRUE,
        stop_on_error = FALSE
      )
    } else {
      cat("No installation was run.\n", sep = "")
    }
  }

  if (isTRUE(ok)) {
    cat("\nPreliminary checks passed.\n", sep = "")
  }

  invisible(ok)
}

handle_render_error <- function(error) {
  message("\nRender failed: ", conditionMessage(error))
  message("Try [2] Preliminary checks (find missing tools), then render again.")
  message("Temporary render files were kept for debugging.")
  message("After fixing the issue, rerun through render.R; do not compile kept .tex or _render_*.Rmd files directly.")
  if (!interactive()) {
    quit(status = 1)
  }
  stop("Render failed; see messages above.", call. = FALSE)
}

selection <- read_selection()
action <- parse_selection(selection, targets)

if (identical(action$type, "checks")) {
  ok <- run_preliminary_checks()
  if (!isTRUE(ok) && !interactive()) {
    quit(status = 1)
  }
} else if (identical(action$type, "full")) {
  output_path <- tryCatch(render_full_document(), error = handle_render_error)
  cleanup_full_document_artifacts()
  schedule_delayed_cleanup(
    c(
      tools::file_path_sans_ext(master_rmd_file),
      "_render_master",
      tools::file_path_sans_ext(master_output_file)
    ),
    outputs_dir
  )
  open_rendered_documents(output_path)
} else if (identical(action$type, "sections")) {
  selected_targets <- targets[action$indices, , drop = FALSE]
  tryCatch(render_selected_sections(selected_targets), error = handle_render_error)
}
