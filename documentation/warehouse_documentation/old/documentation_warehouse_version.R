version_file <- local({
  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile) && basename(frame$ofile) == "documentation_warehouse_version.R") {
      return(normalizePath(frame$ofile, mustWork = TRUE))
    }
  }

  normalizePath("documentation_warehouse_version.R", mustWork = FALSE)
})

source(file.path(dirname(dirname(version_file)), "render_support", "render_config.R"))
ver <- warehouse_version
