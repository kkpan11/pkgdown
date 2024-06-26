build_citation_authors <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  source <- if (has_citation(pkg$src_path)) {
    repo_source(pkg, "inst/CITATION")
  } else {
    repo_source(pkg, "DESCRIPTION")
  }

  authors <- data_authors(pkg)
  data <- list(
    pagetitle = tr_("Authors and Citation"),
    citations = data_citations(pkg),
    authors = unname(authors$all),
    inst = authors$inst,
    source = source
  )

  data$before <- markdown_text_block(pkg$meta$authors$before)
  data$after <- markdown_text_block(pkg$meta$authors$after)

  render_page(pkg, "citation-authors", data, "authors.html")
}

data_authors <- function(pkg = ".", roles = default_roles()) {
  pkg <- as_pkgdown(pkg)
  author_info <- pkg$meta$authors %||% list()

  inst_path <- path(pkg$src_path, "inst", "AUTHORS")
  if (file_exists(inst_path)) {
    inst <- read_lines(inst_path)
  } else {
    inst <- NULL
  }

  all <- pkg %>%
    pkg_authors() %>%
    purrr::map(author_list, author_info, pkg = pkg)

  main <- pkg %>%
    pkg_authors(roles) %>%
    purrr::map(author_list, author_info, pkg = pkg)

  more_authors <- length(main) != length(all)

  comments <- pkg %>%
    pkg_authors() %>%
    purrr::map(author_list, author_info, pkg = pkg) %>%
    purrr::map("comment") %>%
    purrr::compact() %>%
    length() > 0

  print_yaml(list(
    all = all,
    main = main,
    inst = inst,
    needs_page = more_authors || comments || !is.null(inst)
  ))
}

default_roles <- function() {
  c("aut", "cre", "fnd")
}

pkg_authors <- function(pkg, role = NULL) {
  if (pkg$desc$has_fields("Authors@R")) {
    authors <- unclass(pkg$desc$get_authors())
  } else {
    # Just show maintainer
    authors <- unclass(utils::as.person(pkg$desc$get_maintainer()))
    authors[[1]]$role <- "cre"
  }

  if (is.null(role)) {
    authors
  } else {
    purrr::keep(authors, ~ any(.$role %in% role))
  }
}

data_home_sidebar_authors <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)
  roles <- pkg$meta$authors$sidebar$roles %||% default_roles()
  data <- data_authors(pkg, roles)

  authors <- data$main %>% purrr::map_chr(author_desc, comment = FALSE)

  sidebar <- pkg$meta$authors$sidebar
  bullets <- c(
    markdown_text_inline(sidebar$before, "authors.sidebar.before", pkg = pkg),
    authors,
    markdown_text_inline(sidebar$after, "authors.sidebar.after", pkg = pkg)
  )

  if (data$needs_page) {
    bullets <- c(bullets, a(tr_("More about authors..."), "authors.html"))
  }

  sidebar_section(tr_("Developers"), bullets)
}

author_name <- function(x, authors, pkg) {
  name <- format_author_name(x$given, x$family)

  if (!(name %in% names(authors))) {
    return(name)
  }

  author <- authors[[name]]

  if (!is.null(author$html)) {
    name <- markdown_text_inline(
      author$html,
      paste0("authors.", name, ".html"),
      pkg = pkg
    )
  }

  if (is.null(author$href)) {
    name
  } else {
    a(name, author$href)
  }
}

format_author_name <- function(given, family) {
  given <- paste(given, collapse = " ")

  if (is.null(family)) {
    given
  } else {
    paste0(given, " ", family)
  }
}

author_list <- function(x, authors_info = NULL, comment = FALSE, pkg = ".") {
  name <- author_name(x, authors_info, pkg = pkg)

  roles <- paste0(role_lookup(x$role), collapse = ", ")
  substr(roles, 1, 1) <- toupper(substr(roles, 1, 1))

  orcid <- purrr::pluck(x$comment, "ORCID")
  x$comment <- remove_orcid(x$comment)

  list(
    name = name,
    roles = roles,
    comment = linkify(x$comment),
    orcid = orcid_link(orcid)
  )
}

author_desc <- function(x, comment = TRUE) {
  paste(
    x$name,
    "<br />\n<small class = 'roles'>", x$roles, "</small>",
    if (!is.null(x$orcid)) {
      x$orcid
    },
    if (comment && !is.null(x$comment) && length(x$comment) != 0) {
      paste0("<br/>\n<small>(", linkify(x$comment), ")</small>")
    }
  )
}

orcid_link <- function(orcid) {
  if (is.null(orcid)) {
    return(NULL)
  }

  paste0(
    "<a href='https://orcid.org/", orcid, "' target='orcid.widget' aria-label='ORCID'>",
    "<span class='fab fa-orcid orcid' aria-hidden='true'></span></a>"
  )
}

# Derived from:
# db <- utils:::MARC_relator_db
# db <- db[db$usage != "",]
# dput(setNames(tolower(db$term), db$code))
# # and replace creater with maintainer
role_lookup <- function(abbr) {
  # CRAN roles are translated
  roles <- c(
    aut = tr_("author"),
    com = tr_("compiler"),
    ctr = tr_("contractor"),
    ctb = tr_("contributor"),
    cph = tr_("copyright holder"),
    cre = tr_("maintainer"),
    dtc = tr_("data contributor"),
    fnd = tr_("funder"),
    rev = tr_("reviewer"),
    ths = tr_("thesis advisor"),
    trl = tr_("translator")
  )

  # Other roles are left as is
  marc_db <- getNamespace("utils")$MARC_relator_db
  extra <- setdiff(marc_db$code, names(roles))
  roles[extra] <- tolower(marc_db$term[match(extra, marc_db$code)])

  out <- unname(roles[abbr])
  if (any(is.na(out))) {
    missing <- abbr[is.na(out)]
    cli::cli_warn("Unknown MARC role abbreviation{?s}: {.field {missing}}")
    out[is.na(out)] <- abbr[is.na(out)]
  }
  out
}

# citation ---------------------------------------------------------------------

has_citation <- function(path = ".") {
  file_exists(path(path, 'inst/CITATION'))
}

create_citation_meta <- function(path) {
  path <- path(path, "DESCRIPTION")

  dcf <- read.dcf(path)
  meta <- as.list(dcf[1, ])

  if (!is.null(meta$Encoding)) {
    meta <- lapply(meta, iconv, from = meta$Encoding, to = "UTF-8")
  } else {
    meta$Encoding <- "UTF-8"
  }

  if (!is.null(meta$Title)) meta$Title <- str_squish(meta$Title)

  meta
}

read_citation <- function(path = ".") {
  if (!has_citation(path)) {
    return(character())
  }
  meta <- create_citation_meta(path)
  cit_path <- path(path, 'inst/CITATION')

  utils::readCitationFile(cit_path, meta = meta)
}

data_home_sidebar_citation <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  sidebar_section(
    heading = tr_("Citation"),
    bullets = a(sprintf(tr_("Citing %s"), pkg$package), "authors.html#citation")
  )
}

data_citations <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  if (has_citation(pkg$src_path)) {
    return(citation_provided(pkg$src_path))
  }

  citation_auto(pkg)
}

citation_provided <- function(src_path) {
  provided_citation <- read_citation(src_path)

  text_version <- format(provided_citation, style = "textVersion")
  cit <- list(
    html = ifelse(
      text_version == "",
      format(provided_citation, style = "html"),
      paste0("<p>", escape_html(text_version), "</p>")
    ),
    bibtex = format(provided_citation, style = "bibtex")
  )

  purrr::transpose(cit)
}

citation_auto <- function(pkg) {
  cit_info <- utils::packageDescription(
    path_file(pkg$src_path),
    lib.loc = path_dir(pkg$src_path)
  )
  cit_info$`Date/Publication` <- cit_info$`Date/Publication` %||% Sys.time()
  if (!is.null(cit_info$Title)) cit_info$Title <- str_squish(cit_info$Title)

  cit <- utils::citation(auto = cit_info)
  list(
    html = format(cit, style = "html"),
    bibtex = format(cit, style = "bibtex")
  )
}

# helpers -----------------------------------------------------------------

# Not strictly necessary, but produces a simpler data structure testing
remove_orcid <- function(x) {
  out <- x[names2(x) != "ORCID"]
  if (all(names(out) == "")) {
    names(out) <- NULL
  }
  out
}