# =============================================================================
# Backend dispatch -- delegated to multiscales
# =============================================================================
# data.frame / tibble / data.table / dtplyr / arrow in, the same class out,
# lazy inputs staying lazy unless collected. The implementation lives in
# `multiscales`, which exports the quintet for exactly this. These are direct
# bindings rather than wrapper calls: they sit in the per-row path of every
# conversion, so an extra frame is not free.
#
# Verified byte-identical to the former local copies modulo the `.ts_`/`.ms_`
# prefix before they were removed.
# =============================================================================

# data.table dispatch: without this `[.data.table` falls through to
# `[.data.frame` and the joins break.
.datatable.aware <- TRUE

# Internal working columns referenced as bare symbols inside dplyr verbs
# (bare symbols, not `.data[[...]]`, because dtplyr and arrow mistranslate
# pronoun subsetting) -- declared so R CMD check knows they are data masks.
utils::globalVariables(c(".ts_to", ".ts_y", ".ts_f", ".ts_n_from",
                         ".ts_n_overlap", ".ts_w", ".ts_label",
                         ".ts_year"))

.ts_backend <- multiscales::.ms_backend
.ts_is_lazy <- multiscales::.ms_is_lazy
.ts_lazy    <- multiscales::.ms_lazy
.ts_schema  <- multiscales::.ms_schema
.ts_pull    <- multiscales::.ms_pull
.ts_restore <- multiscales::.ms_restore

# No `.ms_` counterpart: trivial over the schema.
#' @noRd
.ts_names <- function(x) names(.ts_schema(x))
