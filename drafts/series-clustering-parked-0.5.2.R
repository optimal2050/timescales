# ======================================================================== #
# Series-clustering API -- PARKED (user ruling 2026-08-26: move to drafts/,
# will be added later). Recovered from the installed timescales 0.5.2 build
# (built 2026-08-26 20:21 UTC); srcrefs/deparse below, roxygen docs at the
# bottom recovered from the installed Rd database where available.
# Exports: SERIES_DISTANCES, series_distance, get_series_distance, list_series_distances, clear_series_distances, register_series_distance, cluster_series, cluster_medoids, cluster_series_sweep
# Related prior art: merra2ools/R/series-clustering.R, R/cluster.R.
# ======================================================================== #

# ---- SERIES_DISTANCES -------------------------------------------------- #
SERIES_DISTANCES <- c("cor", "spearman", "cosine", "euclidean", "manhattan", "minkowski", "infnorm", 
"sts", "cid", "cort", "acf", "pacf", "ccor", "dtw")

# ---- series_distance --------------------------------------------------- #
series_distance <- function(x, method = "cor", normalize = "none",
                            block_weights = NULL, combine = c("l2", "l1"),
                            na_dist = NULL, as_matrix = FALSE, ...) {
  combine <- match.arg(combine)
  if (!is.character(method) || length(method) != 1L || is.na(method)) {
    .stop("`method` must be a single distance name; see SERIES_DISTANCES")
  }

  blocks <- .as_series_blocks(x)
  wb <- .block_weights(blocks, block_weights)

  dl <- lapply(blocks, function(b) {
    b <- .normalize_series(b, normalize)
    as.matrix(.series_distance_one(b, method, ...))
  })

  if (length(dl) == 1L) {
    d <- dl[[1L]]
  } else {
    p <- if (combine == "l2") 2 else 1
    d <- Reduce(`+`, Map(function(di, wi) wi * di^p, dl, wb))
    d <- d^(1 / p)
  }

  d <- .finish_series_distance(d, rownames(blocks[[1L]]), na_dist, method)
  if (as_matrix) d else stats::as.dist(d)
}

# ---- get_series_distance ----------------------------------------------- #
get_series_distance <- function(method) {
  if (!is.character(method) || length(method) != 1L) return(NULL)
  if (!exists(method, envir = .SERIES_DISTANCE_REGISTRY, inherits = FALSE)) {
    return(NULL)
  }
  get(method, envir = .SERIES_DISTANCE_REGISTRY, inherits = FALSE)
}

# ---- list_series_distances --------------------------------------------- #
list_series_distances <- function() {
  reg <- sort(ls(envir = .SERIES_DISTANCE_REGISTRY, all.names = FALSE))
  data.frame(
    method = c(SERIES_DISTANCES, reg),
    source = c(rep("builtin", length(SERIES_DISTANCES)),
               rep("registered", length(reg))),
    stringsAsFactors = FALSE
  )
}

# ---- clear_series_distances -------------------------------------------- #
clear_series_distances <- function(method = NULL) {
  if (is.null(method)) {
    rm(list = ls(envir = .SERIES_DISTANCE_REGISTRY, all.names = TRUE),
       envir = .SERIES_DISTANCE_REGISTRY)
  } else {
    present <- intersect(method,
                         ls(envir = .SERIES_DISTANCE_REGISTRY,
                            all.names = TRUE))
    if (length(present) > 0L) {
      rm(list = present, envir = .SERIES_DISTANCE_REGISTRY)
    }
  }
  invisible(NULL)
}

# ---- register_series_distance ------------------------------------------ #
register_series_distance <- function(method, fun) {
  if (!is.character(method) || length(method) != 1L || is.na(method) ||
      !nzchar(method)) {
    .stop("`method` must be a single non-empty string")
  }
  if (method %in% SERIES_DISTANCES) {
    .stop(paste0("`%s` is a built-in measure and cannot be overridden; ",
                 "choose another name"), method)
  }
  if (is.null(fun)) {
    if (exists(method, envir = .SERIES_DISTANCE_REGISTRY, inherits = FALSE)) {
      rm(list = method, envir = .SERIES_DISTANCE_REGISTRY)
    }
    return(invisible(method))
  }
  if (!is.function(fun)) {
    .stop("`fun` must be a function(x, ...) or NULL")
  }
  assign(method, fun, envir = .SERIES_DISTANCE_REGISTRY)
  invisible(method)
}

# ---- cluster_series ---------------------------------------------------- #
cluster_series <- function(x, k, method = "cor", weights = NULL,
                           weight_medoids = TRUE, d = NULL, ...) {
  blocks <- .as_series_blocks(x)
  v <- blocks[[1L]]
  w <- .medoid_weights(weights, nrow(v), rownames(v))
  if (is.null(d)) d <- series_distance(x, method = method, ...)
  res <- cluster_medoids(d, k = k,
                         weights = if (isTRUE(weight_medoids)) w else NULL)
  prof <- .cluster_profiles(v, res$clustering, w)
  c(res, prof)
}

# ---- cluster_medoids --------------------------------------------------- #
cluster_medoids <- function(d, k, weights = NULL, max_iter = 100L,
                            max_n = 8000L) {
  dm <- .as_dissimilarity(d, max_n)
  n <- nrow(dm)
  labels <- rownames(dm)

  if (!is.numeric(k) || length(k) != 1L || is.na(k) || k != round(k)) {
    .stop("`k` must be a single integer")
  }
  k <- as.integer(k)
  if (k < 1L || k > n) {
    .stop("`k` must be between 1 and the number of objects (%d); got %d",
          n, k)
  }
  w <- .medoid_weights(weights, n, labels)

  if (k == n) {
    med <- seq_len(n)
    cl <- stats::setNames(seq_len(n), labels)
    return(list(clustering = cl, medoids = med, medoid_names = labels,
                cost = 0, iterations = 0L))
  }

  med <- .pam_build(dm, k, w)
  res <- .pam_swap(dm, med, w, max_iter)

  ord <- order(res$medoids)
  med <- res$medoids[ord]
  near <- max.col(-dm[, med, drop = FALSE], ties.method = "first")
  cl <- stats::setNames(as.integer(near), labels)
  cost <- sum(w * dm[cbind(seq_len(n), med[near])])

  list(clustering = cl, medoids = med, medoid_names = labels[med],
       cost = cost, iterations = res$iterations)
}

# ---- cluster_series_sweep ---------------------------------------------- #
cluster_series_sweep <- function(x, k = NULL, max_loss = 0.05,
                                 method = "cor", weights = NULL,
                                 weight_medoids = TRUE, values = NULL,
                                 d = NULL, verbose = TRUE, ...) {
  blocks <- .as_series_blocks(x)
  v <- if (is.null(values)) blocks[[1L]] else .as_series_blocks(values)[[1L]]
  n <- nrow(blocks[[1L]])
  if (nrow(v) != n) {
    .stop("`values` must have the same number of rows as `x` (%d); got %d",
          n, nrow(v))
  }
  nm <- rownames(blocks[[1L]])
  w <- .medoid_weights(weights, n, nm)

  kk <- .sweep_grid(k, n)
  if (!is.null(max_loss) && !is.na(max_loss) &&
      (!is.numeric(max_loss) || length(max_loss) != 1L)) {
    .stop("`max_loss` must be a single number, or NA to try every k")
  }

  sd_n <- .weighted_sd(as.vector(v), rep(w, times = ncol(v)))
  if (!is.finite(sd_n) || sd_n == 0) {
    .stop(paste0("the weighted standard deviation of `values` is %s, so ",
                 "sd_loss is undefined; check the weights and the data"),
          format(sd_n))
  }

  if (is.null(d)) d <- series_distance(x, method = method, ...)
  d <- .as_dissimilarity(d)

  out <- vector("list", length(kk))
  for (i in seq_along(kk)) {
    ki <- kk[i]
    if (verbose) cat("k-clusters (k-max): ", ki, " (", max(kk), ")", sep = "")
    res <- cluster_medoids(
      d, k = ki, weights = if (isTRUE(weight_medoids)) w else NULL)
    prof <- .cluster_profiles(v, res$clustering, w)
    sd_k <- .weighted_sd(as.vector(prof$profiles),
                         rep(prof$cluster_weights, times = ncol(v)))
    loss <- 1 - sd_k / sd_n
    if (verbose) {
      cat(", sd_k: ", sd_k, ", sd_loss: ",
          100 * round(loss, 5), "%\n", sep = "")
    }
    out[[i]] <- data.frame(
      k = ki, N = n, series = nm,
      cluster = as.integer(res$clustering),
      weight = w, sd_N = sd_n, sd_k = sd_k, sd_loss = loss,
      row.names = NULL, stringsAsFactors = FALSE
    )
    if (!is.null(max_loss) && !is.na(max_loss) && loss <= max_loss) {
      out <- out[seq_len(i)]
      break
    }
  }
  do.call(rbind, out)
}

# ==== Rd: SERIES_DISTANCES.Rd ======================================== #

# _S_u_p_p_o_r_t_e_d _t_i_m_e-_s_e_r_i_e_s _d_i_s_t_a_n_c_e _m_e_a_s_u_r_e_s
# 
# _D_e_s_c_r_i_p_t_i_o_n:
# 
#      The built-in catalogue consulted by 'series_distance()'. Each
#      measure takes a numeric matrix whose *rows are series* and returns
#      pairwise dissimilarities between those rows.
# 
# _U_s_a_g_e:
# 
#      SERIES_DISTANCES
#      
# _F_o_r_m_a_t:
# 
#      A character vector of length 13.
# 
# _D_e_t_a_i_l_s:
# 
#      'cor' sqrt{2(1-rho)} on Pearson correlation; with 'beta',
#           sqrt{((1-rho)/(1+rho))^beta}. Shape-only - blind to level and
#           amplitude. The default.
# 
#      'spearman' The same transform on rank correlation; robust to
#           outliers and monotone rescaling.
# 
#      'cosine' 1 - \langle x,y\rangle/(\|x\|\|y\|). Like 'cor' but
#           without centring, so level still matters.
# 
#      'euclidean', 'manhattan', 'minkowski', 'infnorm' The lock-step
#           L_2, L_1, L_p (p=) and L_Inf metrics.
# 
#      'sts' Short time series distance (Moller-Levet et al. 2003):
#           Euclidean distance between slope profiles,
#           (x_{t+1}-x_t)/Delta t. Compares rates of change rather than
#           levels.
# 
#      'cid' Complexity-invariant distance (Batista et al. 2011):
#           Euclidean distance scaled by the ratio of complexity
#           estimates CE(x)=sqrt{sum (x_t-x_{t+1})^2}. Separates smooth
#           from spiky profiles that are otherwise close.
# 
#      'cort' Temporal-correlation distance (Chouakria-Douzal and
#           Nagabhushan 2007): a base metric modulated by
#           phi_k(CORT)=2/(1+e^{k\,CORT}), where 'CORT' is the
#           correlation of first differences. Combines proximity in value
#           and in behaviour.
# 
#      'acf', 'pacf' Euclidean distance between (partial) autocorrelation
#           feature vectors (Galeano and Pena 2000), optionally
#           geometrically down-weighted by lag via p=.
# 
#      'ccor' Cross-correlation distance (Golay et al. 1998),
#           sqrt{(1-rho^2(0))/sum_{k>= 1}rho^2(k)}. Sensitive to lagged
#           co-movement; the one genuinely pairwise measure here.
# 
#      'dtw' Dynamic time warping, delegated to the 'dtw' package
#           (Suggests). Elastic in time; the slowest option by a wide
#           margin.
# 
# _R_e_f_e_r_e_n_c_e_s:
# 
#      Batista, G. et al. (2011) A complexity-invariant distance measure
#      for time series. _SDM_, 699-710.
# 
#      Chouakria-Douzal, A. and Nagabhushan, P. N. (2007) Adaptive
#      dissimilarity index for measuring time series proximity. _ADAC_
#      1(1), 5-21.
# 
#      Galeano, P. and Pena, D. (2000) Multivariate analysis in vector
#      time series. _Resenhas_ 4(4), 383-403.
# 
#      Golay, X. et al. (1998) A new correlation-based fuzzy logic
#      clustering algorithm for fMRI. _Magnetic Resonance in Medicine_
#      40(2), 249-260.
# 
#      Moller-Levet, C. S. et al. (2003) Fuzzy clustering of short time
#      series and unevenly distributed sampling points. _IDA_, 330-340.
# 
# _E_x_a_m_p_l_e_s:
# 
#      SERIES_DISTANCES
#      

# ==== Rd: cluster_medoids.Rd ======================================== #

# _P_a_r_t_i_t_i_o_n _a_r_o_u_n_d _m_e_d_o_i_d_s
# 
# _D_e_s_c_r_i_p_t_i_o_n:
# 
#      Clusters objects described by a dissimilarity matrix into 'k'
#      groups, each represented by one of the objects (its _medoid_). The
#      objective is the total weighted distance from every object to its
#      assigned medoid.
# 
# _U_s_a_g_e:
# 
#      cluster_medoids(d, k, weights = NULL, max_iter = 100L, max_n = 8000L)
#      
# _A_r_g_u_m_e_n_t_s:
# 
#        d: A 'stats::dist' object or a symmetric matrix of
#           dissimilarities.
# 
#        k: Number of clusters, between 1 and 'nrow(d)'.
# 
#  weights: Optional non-negative weight per object, entering the cost as
#           sum_i w_i\, d(i, m(i)). 'NULL' (default) weights all objects
#           equally, which reproduces the classical PAM objective.
# 
# max_iter: Maximum number of SWAP iterations.
# 
#    max_n: Refuse inputs larger than this, since the algorithm holds the
#           full n \times n matrix in memory. Raise it deliberately.
# 
#           Cluster labels follow the medoids in *increasing index
#           order*. This is a deliberate difference from
#           'cluster::pam()', whose labels follow the order in which
#           medoids happened to be discovered by BUILD and SWAP; the
#           medoid _sets_ and the objective agree exactly, but the
#           numbering here is reproducible from the result alone.
# 
# _V_a_l_u_e:
# 
#      A list with elements
# 
#      'clustering' integer vector of cluster labels, '1:k', named by the
#           objects; labels follow the medoids in increasing index order
# 
#      'medoids' integer indices of the medoids, increasing
# 
#      'medoid_names' their names, if 'd' carries labels
# 
#      'cost' the total weighted distance to the assigned medoids
# 
#      'iterations' number of SWAP iterations performed
# 
# _R_e_f_e_r_e_n_c_e_s:
# 
#      Kaufman, L. and Rousseeuw, P. J. (1990) _Finding Groups in Data_.
#      Wiley.
# 
#      Schubert, E. and Rousseeuw, P. J. (2019) Faster k-medoids
#      clustering. _SISAP_, 171-187.
# 
# _S_e_e _A_l_s_o:
# 
#      'cluster_series()', 'series_distance()'
# 
# _E_x_a_m_p_l_e_s:
# 
#      set.seed(1)
#      x <- rbind(matrix(rnorm(20, 0), 4), matrix(rnorm(20, 5), 4))
#      d <- stats::dist(x)
#      cluster_medoids(d, k = 2)$clustering
#      
#      # weights change which objects the medoids are pulled toward
#      cluster_medoids(d, k = 2, weights = c(rep(1, 4), rep(10, 4)))$medoids
#      

# ==== Rd: cluster_series.Rd ======================================== #

# _C_l_u_s_t_e_r _t_i_m_e _s_e_r_i_e_s
# 
# _D_e_s_c_r_i_p_t_i_o_n:
# 
#      Groups the *rows* of 'x' into 'k' clusters by k-medoids on a
#      time-series distance. A thin composition of 'series_distance()'
#      and 'cluster_medoids()'; use 'cluster_series_sweep()' when 'k' is
#      itself the question.
# 
# _U_s_a_g_e:
# 
#      cluster_series(
#        x,
#        k,
#        method = "cor",
#        weights = NULL,
#        weight_medoids = TRUE,
#        d = NULL,
#        ...
#      )
#      
# _A_r_g_u_m_e_n_t_s:
# 
#        x: A numeric matrix with one series per row, or a named list of
#           such matrices; see 'series_distance()'.
# 
#        k: Number of clusters.
# 
#   method: Distance measure; see 'SERIES_DISTANCES'.
# 
#  weights: Optional non-negative weight per series (area, capacity,
#           period duration). Weights always shape the cluster profiles;
#           whether they also shape the partition is 'weight_medoids'.
# 
# weight_medoids: Should 'weights' enter the k-medoids objective, so that
#           heavy series pull the medoids toward them? 'TRUE' by default,
#           which is what a weighted aggregation should do. 'FALSE'
#           partitions as if every series were equally important and
#           applies the weights only afterwards, when averaging members
#           into cluster profiles - the behaviour of
#           'merra2ools::cluster_locid()' up to version 0.3.0, kept
#           reachable so earlier results can be reproduced.
# 
#        d: Optional precomputed distance (a 'stats::dist' or symmetric
#           matrix). Supplying it skips 'method' entirely - the way to
#           reuse one distance across many calls.
# 
#      ...: Passed to 'series_distance()' ('normalize', 'block_weights',
#           'na_dist', and measure-specific arguments).
# 
# _V_a_l_u_e:
# 
#      The list returned by 'cluster_medoids()', with two additions:
#      'profiles' (a k x T matrix of weighted-mean cluster profiles, from
#      the first block of 'x') and 'cluster_weights' (the summed weight
#      per cluster).
# 
# _E_x_a_m_p_l_e_s:
# 
#      set.seed(1)
#      x <- rbind(matrix(rnorm(3 * 48, 0), 3), matrix(rnorm(3 * 48, 4), 3))
#      rownames(x) <- paste0("s", 1:6)
#      cl <- cluster_series(x, k = 2, method = "euclidean")
#      cl$clustering
#      dim(cl$profiles)
#      

# ==== Rd: cluster_series_sweep.Rd ======================================== #

# _C_h_o_o_s_e _h_o_w _m_a_n_y _c_l_u_s_t_e_r_s, _b_y _t_o_l_e_r_a_t_e_d _l_o_s_s _o_f _v_a_r_i_a_b_i_l_i_t_y
# 
# _D_e_s_c_r_i_p_t_i_o_n:
# 
#      Walks a grid of 'k', clusters at each one, and records how much
#      weighted standard deviation the aggregation destroys. The sweep
#      stops at the first 'k' whose 'sd_loss' is within 'max_loss', so
#      the returned table ends at the cheapest acceptable aggregation
#      while still showing everything tried.
# 
# _U_s_a_g_e:
# 
#      cluster_series_sweep(
#        x,
#        k = NULL,
#        max_loss = 0.05,
#        method = "cor",
#        weights = NULL,
#        weight_medoids = TRUE,
#        values = NULL,
#        d = NULL,
#        verbose = TRUE,
#        ...
#      )
#      
# _A_r_g_u_m_e_n_t_s:
# 
#        x: A numeric matrix with one series per row, or a named list of
#           such matrices; see 'series_distance()'.
# 
#        k: Integer vector of cluster counts to try, in increasing order.
#           'NULL' uses a log-spaced default grid. Values above the
#           number of series are dropped, and the number of series is
#           always appended so the no-aggregation reference is available.
# 
# max_loss: Stop at the first 'k' with 'sd_loss <= max_loss'. Default
#           '0.05', i.e. accept up to 5% loss of weighted standard
#           deviation. Use 'NA' to evaluate the whole grid.
# 
#   method: Distance measure; see 'SERIES_DISTANCES'.
# 
#  weights: Optional non-negative weight per series (area, capacity,
#           period duration). Weights always shape the cluster profiles;
#           whether they also shape the partition is 'weight_medoids'.
# 
# weight_medoids: Should 'weights' enter the k-medoids objective, so that
#           heavy series pull the medoids toward them? 'TRUE' by default,
#           which is what a weighted aggregation should do. 'FALSE'
#           partitions as if every series were equally important and
#           applies the weights only afterwards, when averaging members
#           into cluster profiles - the behaviour of
#           'merra2ools::cluster_locid()' up to version 0.3.0, kept
#           reachable so earlier results can be reproduced.
# 
#   values: Optional matrix, same rows as 'x', on which the loss metric
#           is evaluated. Lets you cluster on normalized shapes while
#           measuring the loss on physical levels. Defaults to the first
#           block of 'x'.
# 
#        d: Optional precomputed distance (a 'stats::dist' or symmetric
#           matrix). Supplying it skips 'method' entirely - the way to
#           reuse one distance across many calls.
# 
#  verbose: Report progress per 'k'.
# 
#      ...: Passed to 'series_distance()' ('normalize', 'block_weights',
#           'na_dist', and measure-specific arguments).
# 
# _D_e_t_a_i_l_s:
# 
#      The distance matrix is computed *once* and reused for every 'k'.
# 
# _V_a_l_u_e:
# 
#      A 'data.frame' with one row per ('k', series):
# 
#      'k' number of clusters
# 
#      'N' number of series clustered
# 
#      'series' series name (the row name of 'x')
# 
#      'cluster' cluster label, '1:k'
# 
#      'weight' that series' weight
# 
#      'sd_N' weighted sd of the unclustered values
# 
#      'sd_k' weighted sd of the 'k' cluster profiles
# 
#      'sd_loss' '1 - sd_k / sd_N'
# 
# _E_x_a_m_p_l_e_s:
# 
#      set.seed(42)
#      x <- rbind(matrix(rnorm(4 * 48, 0), 4), matrix(rnorm(4 * 48, 6), 4))
#      rownames(x) <- paste0("s", 1:8)
#      res <- cluster_series_sweep(x, method = "euclidean", max_loss = 0.2,
#                                  verbose = FALSE)
#      unique(res[c("k", "sd_loss")])
#      

# ==== Rd: register_series_distance.Rd ======================================== #

# _R_e_g_i_s_t_e_r _a _c_u_s_t_o_m _t_i_m_e-_s_e_r_i_e_s _d_i_s_t_a_n_c_e
# 
# _D_e_s_c_r_i_p_t_i_o_n:
# 
#      The escape hatch for measures outside 'SERIES_DISTANCES'. A
#      registered function becomes usable as series_distance(x, method =
#      <name>) and hence in 'cluster_series()' and
#      'cluster_series_sweep()'.
# 
# _U_s_a_g_e:
# 
#      register_series_distance(method, fun)
#      
#      get_series_distance(method)
#      
#      list_series_distances()
#      
#      clear_series_distances(method = NULL)
#      
# _A_r_g_u_m_e_n_t_s:
# 
#   method: Name of the measure. Must not collide with a built-in.
# 
#      fun: A function with signature 'fun(x, ...)' receiving the
#           prepared numeric matrix (*rows are series*, already
#           normalized) and returning a 'stats::dist' object or a
#           symmetric matrix of the same row count. 'NULL' removes a
#           previously registered measure.
# 
# _V_a_l_u_e:
# 
#      Invisibly, 'method'.
# 
#      'get_series_distance()' returns the registered function or 'NULL'.
# 
#      'list_series_distances()' returns a 'data.frame' with columns
#      'method' and 'source' ('"builtin"' or '"registered"').
# 
#      'clear_series_distances()' returns invisibly 'NULL'.
# 
# _E_x_a_m_p_l_e_s:
# 
#      register_series_distance("chebyshev", function(x, ...) {
#        stats::dist(x, method = "maximum")
#      })
#      m <- matrix(c(1, 2, 3, 3, 2, 1), nrow = 2, byrow = TRUE)
#      series_distance(m, method = "chebyshev")
#      clear_series_distances()
#      

# ==== Rd: series_distance.Rd ======================================== #

# _D_i_s_t_a_n_c_e _b_e_t_w_e_e_n _t_i_m_e _s_e_r_i_e_s
# 
# _D_e_s_c_r_i_p_t_i_o_n:
# 
#      Pairwise dissimilarities between the *rows* of a numeric matrix,
#      using one of 'SERIES_DISTANCES' or a measure added with
#      'register_series_distance()'.
# 
# _U_s_a_g_e:
# 
#      series_distance(
#        x,
#        method = "cor",
#        normalize = "none",
#        block_weights = NULL,
#        combine = c("l2", "l1"),
#        na_dist = NULL,
#        as_matrix = FALSE,
#        ...
#      )
#      
# _A_r_g_u_m_e_n_t_s:
# 
#        x: A numeric matrix with one series per row, or a named list of
#           such matrices for multivariate clustering (see above). A
#           'data.frame' of numeric columns is accepted and coerced.
# 
#   method: Distance measure; one of 'SERIES_DISTANCES' or a registered
#           name.
# 
# normalize: Per-series rescaling applied before the measure: '"none"'
#           (default), '"zscore"' (centre and scale to unit sd),
#           '"minmax"' (rescale to [0, 1]), or '"unit"' (scale to unit L2
#           norm). Constant series are left untouched by
#           '"zscore"'/'"minmax"'.
# 
# block_weights: Optional numeric weights for a list 'x', matched by name
#           or by position. Defaults to equal weights.
# 
#  combine: Exponent used to pool block distances: '"l2"' (default, p =
#           2) or '"l1"' (p = 1).
# 
#  na_dist: Replacement for non-finite dissimilarities (which arise from,
#           e.g., a zero-variance series under 'cor'). The default 'NULL'
#           raises an error naming the offending series.
# 
# as_matrix: If 'TRUE', return a full symmetric matrix instead of a
#           'stats::dist' object.
# 
#      ...: Measure-specific arguments: 'beta' ('cor'), 'p' ('minkowski'
#           exponent; 'acf'/'pacf' geometric lag decay), 'lag_max'
#           ('acf', 'pacf', 'ccor'), 'k' and 'base' ('cort'), 'dt' ('sts'
#           time spacing), or any argument of 'dtw::dtw()'.
# 
# _V_a_l_u_e:
# 
#      A 'stats::dist' object, or a symmetric matrix if 'as_matrix'.
# 
# _M_u_l_t_i_v_a_r_i_a_t_e _i_n_p_u_t:
# 
#      Passing a named list of matrices clusters several variables
#      jointly (wind, solar and demand profiles over the same locations
#      or days). Every block must have the same number of rows, in the
#      same order. Each block is normalized and measured *separately*,
#      then combined as d = (sum_b \tilde{w}_b d_b^p)^{1/p} with
#      \tilde{w}_b the normalized 'block_weights' and 'p' set by
#      'combine'. Combining after the metric (rather than concatenating
#      columns) is what keeps block weights meaningful for
#      scale-invariant measures such as 'cor'.
# 
# _S_e_e _A_l_s_o:
# 
#      'cluster_series()', 'cluster_series_sweep()',
#      'register_series_distance()'
# 
# _E_x_a_m_p_l_e_s:
# 
#      set.seed(1)
#      x <- matrix(rnorm(4 * 24), nrow = 4,
#                  dimnames = list(c("a", "b", "c", "d"), NULL))
#      series_distance(x)
#      series_distance(x, method = "euclidean", normalize = "zscore")
#      
#      # multivariate: two variables over the same four sites
#      y <- matrix(rnorm(4 * 24), nrow = 4, dimnames = dimnames(x))
#      series_distance(list(wind = x, solar = y),
#                      block_weights = c(wind = 2, solar = 1))
#      


# ==== internal helpers ================================================ #

`.as_series_blocks` <- function(x) {
  one <- function(m, nm) {
    if (is.data.frame(m)) m <- as.matrix(m)
    if (!is.matrix(m) || !is.numeric(m)) {
      .stop("`%s` must be a numeric matrix (rows = series)", nm)
    }
    if (nrow(m) < 2L) {
      .stop("`%s` must contain at least two series (rows); got %d",
            nm, nrow(m))
    }
    if (ncol(m) < 2L) {
      .stop("`%s` must contain at least two time steps (columns); got %d",
            nm, ncol(m))
    }
    if (is.null(rownames(m))) rownames(m) <- as.character(seq_len(nrow(m)))
    m
  }

  if (is.list(x) && !is.data.frame(x)) {
    if (length(x) == 0L) .stop("`x` is an empty list")
    nms <- names(x) %||% paste0("block", seq_along(x))
    nms[!nzchar(nms)] <- paste0("block", which(!nzchar(nms)))
    blocks <- Map(one, x, sprintf("x$%s", nms))
    names(blocks) <- nms
    n <- vapply(blocks, nrow, integer(1))
    if (length(unique(n)) != 1L) {
      .stop("all blocks of `x` must have the same number of rows; got %s",
            paste(sprintf("%s=%d", nms, n), collapse = ", "))
    }
    rn <- lapply(blocks, rownames)
    if (!all(vapply(rn, identical, logical(1), rn[[1L]]))) {
      .stop(paste0("all blocks of `x` must carry the same row names, in ",
                   "the same order"))
    }
    return(blocks)
  }
  list(x = one(x, "x"))
}

`.block_weights` <- function(blocks, w) {
  n <- length(blocks)
  if (is.null(w)) return(as.list(rep(1 / n, n)))
  if (!is.numeric(w)) .stop("`block_weights` must be numeric")
  if (!is.null(names(w)) && !is.null(names(blocks))) {
    miss <- setdiff(names(blocks), names(w))
    if (length(miss) > 0L) {
      .stop("`block_weights` is missing an entry for %s", .preview(miss))
    }
    w <- w[names(blocks)]
  }
  if (length(w) != n) {
    .stop("`block_weights` must have one value per block (%d); got %d",
          n, length(w))
  }
  if (anyNA(w) || any(w < 0) || sum(w) <= 0) {
    .stop("`block_weights` must be non-negative, non-NA and not all zero")
  }
  as.list(w / sum(w))
}

`.cluster_profiles` <- function(v, clustering, w) {
  cl <- as.integer(clustering)
  k <- max(cl)
  cw <- as.vector(rowsum(w, cl, reorder = TRUE))
  num <- rowsum(w * v, cl, reorder = TRUE)
  den <- rowsum((!is.na(v)) * w, cl, reorder = TRUE)
  prof <- num / den
  prof[!is.finite(prof)] <- NA_real_
  dimnames(prof) <- list(as.character(seq_len(k)), colnames(v))
  list(profiles = prof, cluster_weights = cw)
}

`.finish_series_distance` <- function(d, rn, na_dist, method) {
  d <- as.matrix(d)
  dimnames(d) <- list(rn, rn)
  diag(d) <- 0
  bad <- !is.finite(d)
  if (any(bad)) {
    if (is.null(na_dist)) {
      rows <- rn[unique(which(bad, arr.ind = TRUE)[, 1L])]
      .stop(paste0("`%s` produced non-finite distances for %s; a constant ",
                   "or all-NA series is the usual cause -- drop it, or set ",
                   "`na_dist=` to substitute a value"),
            method, .preview(rows))
    }
    d[bad] <- na_dist
  }
  d[] <- pmax(d, 0)
  d <- (d + t(d)) / 2
  diag(d) <- 0
  d
}

`.medoid_weights` <- function(weights, n, labels) {
  if (is.null(weights)) return(rep(1, n))
  if (!is.numeric(weights)) .stop("`weights` must be numeric")
  if (!is.null(names(weights)) && !is.null(labels) &&
      all(labels %in% names(weights))) {
    weights <- weights[labels]
  }
  if (length(weights) != n) {
    .stop("`weights` must have one value per object (%d); got %d",
          n, length(weights))
  }
  if (anyNA(weights) || any(weights < 0)) {
    .stop("`weights` must be non-negative and non-NA")
  }
  if (sum(weights) <= 0) .stop("`weights` must not be all zero")
  as.numeric(weights)
}

`.normalize_series` <- function(x, normalize) {
  normalize <- match.arg(normalize, c("none", "zscore", "minmax", "unit"))
  if (normalize == "none") return(x)
  if (normalize == "zscore") {
    x <- x - rowMeans(x, na.rm = TRUE)
    s <- sqrt(rowSums(x^2, na.rm = TRUE) / (ncol(x) - 1L))
    s[!is.finite(s) | s == 0] <- 1
    return(x / s)
  }
  if (normalize == "minmax") {
    lo <- apply(x, 1L, min, na.rm = TRUE)
    hi <- apply(x, 1L, max, na.rm = TRUE)
    rng <- hi - lo
    rng[!is.finite(rng) | rng == 0] <- 1
    return((x - lo) / rng)
  }
  nrm <- sqrt(rowSums(x^2, na.rm = TRUE))
  nrm[!is.finite(nrm) | nrm == 0] <- 1
  x / nrm
}

`.series_distance_one` <- function(x, method, ...) {
  reg <- get_series_distance(method)
  if (!is.null(reg)) return(reg(x, ...))
  if (!method %in% SERIES_DISTANCES) {
    .stop(paste0("unknown distance `%s`; supported measures are %s -- or ",
                 "add your own with register_series_distance()"),
          method, paste(SERIES_DISTANCES, collapse = ", "))
  }
  switch(
    method,
    cor       = .dist_correlation(x, cor_method = "pearson", ...),
    spearman  = .dist_correlation(x, cor_method = "spearman", ...),
    cosine    = .dist_cosine(x, ...),
    euclidean = stats::dist(x, method = "euclidean"),
    manhattan = stats::dist(x, method = "manhattan"),
    minkowski = .dist_minkowski(x, ...),
    infnorm   = stats::dist(x, method = "maximum"),
    sts       = .dist_sts(x, ...),
    cid       = .dist_cid(x, ...),
    cort      = .dist_cort(x, ...),
    acf       = .dist_acf_family(x, type = "correlation", ...),
    pacf      = .dist_acf_family(x, type = "partial", ...),
    ccor      = .dist_ccor(x, ...),
    dtw       = .dist_dtw(x, ...)
  )
}

