test_that("authors page includes inst/AUTHORS", {
  pkg <- local_pkgdown_site(test_path("assets/inst-authors"))
  suppressMessages(init_site(pkg))
  suppressMessages(build_citation_authors(pkg))

  lines <- read_lines(path(pkg$dst_path, "authors.html"))
  expect_true(any(grepl("<pre>Hello</pre>", lines)))
})

# authors --------------------------------------------------------------------

test_that("ORCID can be identified & removed from all comment styles", {
  desc <- desc::desc(text = c(
    'Authors@R: c(',
    '    person("no comment"),',
    '    person("bare comment", comment = "comment"),',
    '    person("orcid only",   comment = c(ORCID = "1")),',
    '    person("both",         comment = c("comment", ORCID = "2"))',
    '  )'
  ))
  authors <- purrr::map(desc$get_authors(), author_list, list())
  expect_equal(
    purrr::map(authors, "orcid"),
    list(NULL, NULL, orcid_link("1"), orcid_link("2"))
  )

  expect_equal(
    purrr::map(authors, "comment"),
    list(character(), "comment", character(), "comment")
  )
})

test_that("author comments linkified with escaped angle brackets (#2127)", {
  p <- list(name = "Jane Doe", roles = "rev", comment = "<https://x.org/>")
  expect_match(
    author_desc(p),
    "&lt;<a href='https://x.org/'>https://x.org/</a>&gt;",
    fixed = TRUE
  )
})

test_that("authors data can be filtered with different roles", {
  pkg <- as_pkgdown(test_path("assets/sidebar"))
  expect_length(data_authors(pkg)$main, 2)
  expect_length(data_authors(pkg, roles = "cre")$main, 1)
})

test_that("authors data includes inst/AUTHORS", {
  pkg <- as_pkgdown(test_path("assets/inst-authors"))
  expect_equal(data_authors(pkg)$inst, "Hello")
})

test_that("sidebar can accept additional before and after text", {
  pkg <- as_pkgdown(test_path("assets/sidebar-comment"))
  pkg$meta$authors$sidebar$before <- "yay"
  pkg$meta$authors$sidebar$after <- "cool"
  expect_snapshot(cat(data_home_sidebar_authors(pkg)))
})

test_that("role has multiple fallbacks", {
  expect_equal(role_lookup("cre"), "maintainer")
  expect_equal(role_lookup("res"), "researcher")
  expect_snapshot(role_lookup("unknown"))
})

# citations -------------------------------------------------------------------

test_that("can handle UTF-8 encoding (#416, #493)", {
  # Work around bug in utils::citation()
  local_options(warnPartialMatchDollar = FALSE)

  path <- test_path("assets/site-citation-UTF-8")
  local_citation_activate(path)

  cit <- read_citation(path)
  expect_s3_class(cit, "citation")

  meta <- create_citation_meta(path)
  expect_type(meta, "list")
  expect_equal(meta$`Authors@R`, 'person("Florian", "Privé")')
})

test_that("can handle latin1 encoding (#689)", {
  path <- test_path("assets/site-citation-latin1")
  local_citation_activate(path)

  cit <- read_citation(path)
  expect_s3_class(cit, "citation")
})

test_that("source link is added to citation page", {
  # Work around bug in utils::citation()
  local_options(warnPartialMatchDollar = FALSE)

  path <- test_path("assets/site-citation-UTF-8")
  local_citation_activate(path)

  pkg <- local_pkgdown_site(path)
  suppressMessages(build_home(pkg))

  lines <- read_lines(path(pkg$dst_path, "authors.html"))
  expect_true(any(grepl("<code>inst/CITATION</code></a></small>", lines)))
})

test_that("multiple citations all have HTML and BibTeX formats", {
  path <- test_path("assets/site-citation-multi")
  local_citation_activate(path)

  citations <- data_citations(path)
  expect_snapshot_output(citations)
})
