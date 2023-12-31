#' @title Identfying isotopologue peaks in MS data
#'
#' @description
#'
#' Given a spectrum (i.e. a peak matrix with m/z and intensity values)
#' the function identifies groups of potential isotopologue peaks based on
#' pre-defined mass differences and intensity (probability) ratios that need
#' to be passed to the function with the `substDefinition` parameter. Each
#' isotopic substitution in a compound determines a certain isotopologue and it
#' is associated with a certain mass difference of that with respect to the
#' monoisotopic isotopologue. Also each substitution in a compound is linked
#' to a certain ratio between the intensities of the peaks of the corresponding
#' isotopologue and the monoisotopic one. This ratio isn't the same for
#' isotopologues corresponding to the same isotopic substitution but to
#' different compounds. Through the `substDefinition` parameter we provide
#' upper and lower values to compute bounds for each isotopic substitution
#' dependent on the peak's mass.
#'
#' @param x `matrix` or `data.frame` with spectrum data. The first column is
#'     expected to contain *m/z* and the second column intensity values. The
#'     *m/z* values in that matrix are expected to be increasingly ordered
#'     and no `NA` values should be present.
#'
#' @param substDefinition `matrix` or `data.frame` with definition of isotopic
#'     substitutions (columns `"name"` and `"md"` are among the mandatory
#'     columns). The rows in this matrix have to be ordered by column `md`
#'     in increasing order. See [isotopicSubstitutionMatrix()] for more
#'     information on the format and content.
#'
#' @param tolerance `numeric(1)` representing the absolute tolerance for the
#'     relaxed matching of m/z values of peaks. See [MsCoreUtils::closest()] for
#'     details.
#'
#' @param ppm `numeric(1)` representing a relative, value-specific
#'     parts-per-million (PPM) tolerance for the relaxed matching of m/z values
#'     of peaks. See [MsCoreUtils::closest()] for details.
#'
#' @param seedMz `numeric` vector of **ordered** m/z values. If provided,
#'     the function checks if there are peaks in `x` which m/z match them.
#'     If any, it looks for groups where the first peak is one of the matched
#'     ones.
#'
#' @param charge `numeric(1)` representing the expected charge of the ionized
#'     compounds.
#'
#' @param .check `logical(1)` to disable input argument check. Should only be
#'     set to `FALSE` if provided *m/z* values are guaranteed to be increasingly
#'     ordered and don't contain `NA` values.
#'
#' @return `list` of `integer` vectors. Each `integer` vector contains the
#'     indixes of the rows in `x` with potential isotopologues of the same
#'     compound.
#'
#' @details
#'
#' The function iterates over the peaks (rows) in `x`. For each peak (which is
#' assumed to be the monoisotopic peak) it searches other peaks in `x` with a
#' difference in mass matching (given `ppm` and `tolerance`) any of the
#' pre-defined mass differences in `substDefinitions` (column `"md"`). The mass
#' is obtained by multiplying the m/z of the peaks for the `charge` expected
#' for the ionized compounds.
#'
#' For matching peaks, the function next evaluates whether their intensity is
#' within the expected (pre-defined) intensity range. Using `"LBint"`,
#' `"LBslope"`, `"UBint"`, `"UBslope"` of the previously matched isotopic
#' substitution in `substDefinition`, the function estimates a (mass dependent)
#' lower and upper intensity ratio limit based on the peak's mass.
#'
#' When some peaks are grouped together their indexes are excluded from the set
#' of indexes that are searched for further groups (i.e. peaks already assigned
#' to an isotopologue group are not considered/tested again thus each peak can
#' only be part of one isotopologue group).
#'
#' @author Andrea Vicini
#'
#' @export
#'
#' @examples
#'
#' ## Read theoretical isotope pattern (high resolution) from example file
#' x <- read.table(system.file("exampleSpectra",
#'     "serine-alpha-lactose-caffeine.txt", package = "MetaboCoreUtils"),
#'     header = TRUE)
#' x <- x[order(x$mz), ]
#' plot(x$mz, x$intensity, type = "h")
#'
#' isos <- isotopologues(x, ppm = 5)
#' isos
#'
#' ## highlight them in the plot
#' for (i in seq_along(isos)) {
#'     z <- isos[[i]]
#'     points(x$mz[z], x$intensity[z], col = i + 1)
#' }
isotopologues <- function(x, substDefinition = isotopicSubstitutionMatrix(),
                          tolerance = 0, ppm = 20, seedMz = numeric(),
                          charge = 1, .check = TRUE) {
    if (is.data.frame(substDefinition))
        substDefinition <- as.matrix(
            substDefinition[, colnames(substDefinition) != "name"])
    if (.check && (anyNA(x[, 1L]) || is.unsorted(x[, 1L])))
        stop("m/z values in `x` need to be increasingly ordered and should ",
             "not be NA")
    .isotope_peaks(x, substDefinition, tolerance, ppm, seedMz, charge)
}

#' @importFrom MsCoreUtils closest
#'
#' @importFrom stats na.omit
#'
#' @noRd
.isotope_peaks <- function(x, substDefinition = isotopicSubstitutionMatrix(),
                           tolerance = 0, ppm = 20, seedMz = numeric(),
                           charge = 1) {
  wtt <- which(x[, 2] > 0)
  if (length(seedMz))
    idxs <- wtt[na.omit(closest(seedMz, x[wtt, 1], tolerance = tolerance,
                                ppm = ppm, duplicates = "closest",
                                .check = FALSE))]
  else idxs <- wtt
  lst <- vector(mode = "list", length = length(idxs))
  mzd <- substDefinition[, "md"] / charge
  for (i in idxs) {
      if (!is.na(ii <- match(i, wtt))) {
          wtt <- wtt[-(1:ii)]
          cur_m <- x[i, 1] * charge
          sub_ok <- which(substDefinition[, "leftend"] < cur_m &
                          substDefinition[, "rightend"] >= cur_m)
          cls <- closest(x[i, 1] + mzd[sub_ok], x[wtt, 1],
                         tolerance = tolerance, ppm = ppm,
                         duplicates = "keep", .check = FALSE)
          i_cls <- which(!is.na(cls))
          cls <- cls[i_cls]
          if(length(cls)) {
              int_ok <- .is_isotope_intensity_range(
                  x[wtt[cls], 2], cur_m, x[i, 2],
                  substDefinition[sub_ok[i_cls], , drop = FALSE])
              if (length(int_ok)) {
                  cls <- unique(cls[int_ok])
                  lst[[i]] <- c(i, wtt[cls])
                  wtt <- wtt[-cls]
              }
          }
      }
  }
  lst[lengths(lst) > 0]
}

#' performs the comparison "reverse", i.e. matching each peak against the
#' isotopologue mz
#'
#' @noRd
.isotope_peaks_reverse <- function(x, substDefinition =
                                          isotopicSubstitutionMatrix(),
                                   tolerance = 0, ppm = 20, seedMz = numeric(),
                                   charge = 1) {
  wtt <- which(x[, 2] > 0)
  if (length(seedMz))
    idxs <- wtt[na.omit(closest(seedMz, x[wtt, 1], tolerance = tolerance,
                                ppm = ppm, duplicates = "closest",
                                .check = FALSE))]
  else idxs <- wtt
  lst <- vector(mode = "list", length = length(idxs))
  mzd <- substDefinition[, "md"] / charge
  for (i in idxs) {
      if (!is.na(ii <- match(i, wtt))) {
          wtt <- wtt[-(1:ii)]
          cur_m <- x[i, 1L] * charge
          sub_ok <- which(substDefinition[, "leftend"] < cur_m &
                          substDefinition[, "rightend"] >= cur_m)
          cls <- closest(x[wtt, 1L], x[i, 1L] + mzd[sub_ok],
                         tolerance = tolerance, ppm = ppm,
                         duplicates = "keep", .check = FALSE)
          i_cls <- which(!is.na(cls))
          cls <- cls[i_cls]
          if (length(cls)) {
              int_ok <- unique(i_cls[.is_isotope_intensity_range(
                  x[wtt[i_cls], 2L], cur_m, x[i, 2L],
                  substDefinition[sub_ok[cls], , drop = FALSE])])
              if (length(int_ok)) {
                  lst[[i]] <- c(i, wtt[int_ok])
                  wtt <- wtt[-int_ok]
              }
          }
      }
  }
  lst[lengths(lst) > 0]
}


#' Why this function?
#' By using `cls <- closest(x[i, 1] + mzd, x[wtt, 1], duplicates = "closest"`
#' the `.isotope_peaks` function evaluates only a single potential peak (the
#' one with the most similar m/z) for each isotopic substitution and discards
#' others, potentially also or even better matching, peaks.
#'
#' This function makes an exhaustive comparison between the m/z of each isotope
#' substitution against each (m/z) matching peak in x using a `for` loop:
#' for each tested monoisotopic peak the mass of each potential isotopologue is
#' calculated and each of them is compared against all (not yet assigned) peaks
#' in the spectrum.
#'
#' @author Andrea Vicini, Johannes Rainer
#'
#' @noRd
#'
#' @importFrom MsCoreUtils ppm
.isotope_peaks_exhaustive <- function(x, substDefinition =
                                             isotopicSubstitutionMatrix(),
                                      tolerance = 0, ppm = 20,
                                      seedMz = numeric(), charge = 1) {
    ## wtt integer: which peaks in x to test against.
    ## ii integer: which peaks to test
    wtt <- which(x[, 2L] > 0)
    if (length(seedMz))
        idxs <- wtt[na.omit(closest(seedMz, x[wtt, 1L], tolerance = tolerance,
                                    ppm = ppm, duplicates = "closest",
                                    .check = FALSE))]
    else idxs <- wtt
    lst <- vector(mode = "list", length = length(idxs))
    mzd <- unname(substDefinition[, "md"]) / charge
    for (i in idxs) {
        if (!is.na(ii <- match(i, wtt))) {
            wtt <- wtt[-(1:ii)]
            cur_m <- x[i, 1L] * charge
            cur_int <- x[i, 2L]
            sub_ok <- which(substDefinition[, "leftend"] < cur_m &
                            substDefinition[, "rightend"] >= cur_m)
            ## exhaustive: calculate all md that make sense and determine which
            ## peaks (wtt) would match that with m/z and intensity.
            m <- cur_m + mzd[sub_ok]
            mppm <- ppm(m, ppm) + tolerance
            iso_peaks <- integer()
            for (j in seq_along(mppm)) {
                cls <- which(abs(x[wtt, 1L] - m[j]) <= mppm[j])
                ## cls are the matching peaks in x/wtt for this one substitution
                if (length(cls)) {
                    int_ok <- .is_isotope_intensity_range(
                        x[wtt[cls], 2L], rep(cur_m, length(cls)), cur_int,
                        substDefinition[sub_ok[j], , drop = FALSE])
                    if (length(int_ok))
                        iso_peaks <- c(iso_peaks, cls[int_ok])
                }
            }
            ## don't test matching peaks again.
            if (length(iso_peaks)) {
                iso_peaks <- sort(unique(iso_peaks))
                lst[[i]] <- c(i, wtt[iso_peaks])
                wtt <- wtt[-iso_peaks]
            }
        }
    }
    lst[lengths(lst) > 0]
}

#' @title Checking the intensity
#'
#' @param x intensity of the candidate isotopologue peaks.
#'
#' @param m mass of the current (assumed monoisotopic) peak.
#'
#' @param intensity  intensity of the current (assumed monoisotopic) peak.
#'
#' @param substDefinition `matrix` or `data.frame` with the definition of the
#' parameters to compute intensity bounds for the candidate peaks.
#' `substDefinition` has a number of rows equal to the number of candidate peaks.
#' The i-th row contains the parameters associated to the substitution to which
#' we assume the i-th peak is matched.
#'
#' @return indexes of the intensities in `x` that are part of a isotopic group.
#'
#' @noRd
.is_isotope_intensity_range <- function(x, m, intensity, substDefinition) {
  R_min <- m * substDefinition[, "LBslope"] + substDefinition[, "LBint"]
  R_max <- m * substDefinition[, "UBslope"] + substDefinition[, "UBint"]
  which(x >= R_min * intensity & x <= R_max * intensity)
}

#' @title Definitions of isotopic substitutions
#'
#' @description
#'
#' In order to identify potential isotopologues based on only m/z and intensity
#' values with the [isotopologues()] function, sets of pre-calculated parameters
#' are required. This function returns such parameter sets estimated on
#' different sources/databases. The nomenclature used to describe isotopes
#' follows the following convention: the number of neutrons is provided in `[`
#' as a prefix to the element and the number of atoms of the element as suffix.
#' `[13]C2[37]Cl3` describes thus an isotopic substitution containing 2 `[13]C`
#' isotopes and 3 `[37]Cl` isotopes.
#'
#' Each row in the returned `data.frame` is associated with an isotopic
#' substitution (which can involve isotopes of several elements or different
#' isotopes of the same element). In general for each isotopic substitution
#' multiple rows are present in the `data.frame`. Each row provides parameters
#' to compute bounds (for the ratio between the isotopologue peak and the
#' monoisotopic one) on a certain mass range. The provided isotopic
#' substitutions are in general the most frequently observed substitutions in
#' the database (e.g. HMDB) on which they were defined. Parameters (columns)
#' defined for each isotopic substitution are:
#'
#' - `"minmass"`: the minimal mass of a compound for which the isotopic
#'   substitution was found. Peaks with a mass lower than this will most likely
#'   not have the respective isotopic substitution.
#' - `"maxmass"`: the maximal mass of a compound for which the isotopic
#'   substitution was found. Peaks with a mass higher than this will most likely
#'   not have the respective isotopic substitution.
#' - `"md"`: the mass difference between the monoisotopic peak and a peak of an
#'   isotopologue characterized by the respective isotopic substitution.
#' - `"leftend"`: left endpoint of the mass interval.
#' - `"rightend"`: right endpoint of the mass interval.
#' - `"LBint"`: intercept of the lower bound line on the mass interval whose
#'   endpoints are `"leftend"` and `"rightend"`.
#' - `"LBslope"`: slope of the lower bound line on the mass interval.
#' - `"UBint"`: intercept of the upper bound line on the mass interval.
#' - `"UBslope"`: slope of the upper bound line on the mass interval.
#'
#' @section Available pre-calculated substitution matrices:
#'
#' - `source = "HMDB"`: most common isotopic substitutions and parameters for
#'   these have been calculated for all compounds from the
#'   [Human Metabolome Database](https://hmdb.ca) (HMDB, July 2021). Note that
#'   the substitutions were calculated on the **neutral masses** (i.e. the
#'   chemical formulas of the compounds, not considering any adducts).
#'
#' @param source `character(1)` defining the set of predefined parameters and
#'     isotopologue definitions to return.
#'
#' @return `data.frame` with parameters to detect the defined isotopic
#'     substitutions
#'
#' @author Andrea Vicini
#'
#' @export
#'
#' @examples
#'
#' ## Get the substitution matrix calculated on HMDB
#' isotopicSubstitutionMatrix("HMDB_NEUTRAL")
isotopicSubstitutionMatrix <- function(source = c("HMDB_NEUTRAL")) {
    available <- availableIsotopicSubstitutionMatrix()
    if (!any(available == toupper(source)))
        stop("No substitution matrix '", source, "' available.")
    res <- get(paste0(".SUBSTS_", toupper(source)))
}

availableIsotopicSubstitutionMatrix <- function() {
    res <- ls(pattern = "^.SUBSTS_", all.names = TRUE,
              envir = asNamespace("MetaboCoreUtils"))
    sub("^.SUBSTS_", "", res)
}

## #' Combine rows in the substitution matrix if the difference between them
## #' (after adding mz) is smaller than `ppm` and `tolerance`.
## #'
## #' For the reduced/combined isotopic substitution the mean `"md"` is reported.
## #'
## #' The selection of the `"degree"`, `"min_slope"` and `"max_slope"` is by no
## #' means ideal. At present the values from the substitution with the largest
## #' range (`"max_slope"` - `"min_slope"`) is selected. Maybe selecting the most
## #' frequent substitution might be a better choice.
## #'
## #' @noRd
## .reduce_substitution_matrix <- function(x, mz = 0, ppm = 0, tolerance = 0) {
##     grps <- as.factor(group(x[, "md"] + mz, ppm = ppm, tolerance = 0))
##     res <- lapply(split.data.frame(x, grps), function(z) {
##         keep <- which.max(z[, "max_slope"] - z[, "min_slope"])
##         tmp <- z[keep, , drop = FALSE]
##         rownames(tmp) <- paste0(rownames(z), collapse = "|")
##         tmp[, "md"] <- mean(z[, "md"])
##         tmp
##     })
##     do.call(rbind, res)
## }


#' Instead of matching a peak's m/z against all individual isotopic substitution
#' this function first groups isotopic substitutions if the difference of their
#' m/z is smaller than the user provided `ppm` and `tolerance`. The peak's m/z
#' is then matched against the mean m/z of the grouped isotopic substitutions.
#' The intensity evaluation is then performed for each individual substitution
#' of the matched groups.
#'
#' @details
#'
#' This version avoids the inherent problem of all other approaches using the
#' `closest` function: the m/z of a peak can match potentially many isotopic
#' substitutions, but using `closest` only a single match is reported. Thus, the
#' intensity evaluation is performed for this single match only which can result
#' in false negative findings.
#'
#' The *exhaustive* method, by comparing each peak against each isotopic
#' substitution solves this m:n mapping exactly, but is very slow. This version
#' groups isotopic substitutions before matching them if the difference of their
#' m/z is smaller than tolerated (based on `ppm` and `tolerance`). This reduces
#' the problem from m:n to m:1, i.e. each peak is supposed to match a single
#' isotopic substitution *group*. The intensity evaluation is then performed
#' against all individual substitutions of a matching isotopic substitution
#' group. The limitation of this method is that the m/z of a peak is compared
#' against the mean m/z of an isotopic substitution group and due to this
#' average m/z a peak might not be matched to a group, even if it would to an
#' individual substitution.
#'
#' @author Johannes Rainer
#'
#' @importFrom MsCoreUtils group
#'
#' @noRd
.isotope_peaks_grouped <- function(x, substDefinition =
                                          isotopicSubstitutionMatrix(),
                                   tolerance = 0, ppm = 20, seedMz = numeric(),
                                   charge = 1) {
    wtt <- which(x[, 2] > 0)
    if (length(seedMz))
        idxs <- wtt[na.omit(closest(seedMz, x[wtt, 1], tolerance = tolerance,
                                    ppm = ppm, duplicates = "closest",
                                    .check = FALSE))]
    else idxs <- wtt
    lst <- vector(mode = "list", length = length(idxs))
    mzd <- substDefinition[, "md"] / charge
    for (i in idxs) {
        if (!is.na(ii <- match(i, wtt))) {
            wtt <- wtt[-(1:ii)]
            cur_m <- x[i, 1] * charge
            sub_ok <- which(substDefinition[, "leftend"] < cur_m &
                            substDefinition[, "rightend"] >= cur_m)
            ## group substitutions if the difference between them is smaller
            ## than we could detect with the given ppm
            grps <- unname(group(mzd[sub_ok] + cur_m,
                                 tolerance = tolerance, ppm = ppm))
            grps_md <- split(mzd[sub_ok], grps)
            ## calculate mean md per group
            grp_md <- vapply(grps_md, mean, numeric(1), USE.NAMES = FALSE)
            ## match each peak from spectrum against groups
            cls <- closest(x[wtt, 1L], x[i, 1L] + grp_md, tolerance = tolerance,
                           ppm = ppm, duplicates = "keep", .check = FALSE)
            i_cls <- which(!is.na(cls)) # index of peaks
            cls <- cls[i_cls]           # index of sub groups
            if (length(cls)) {
                ## each peak can match multiple substitutions and we need to
                ## "ungroup" the substitutions again for the intensity
                ## comparison
                pk_idx <- rep(i_cls, lengths(grps_md[cls]))
                sub_idx <- unlist(split(seq_along(grps), grps)[cls],
                                  use.names = FALSE)
                int_ok <- .is_isotope_intensity_range(
                    x[wtt[pk_idx], 2L],
                    cur_m, x[i, 2L],
                    substDefinition[sub_ok[sub_idx], , drop = FALSE]
                )
                if (length(int_ok)) {
                    cls <- unique(pk_idx[int_ok])
                    lst[[i]] <- c(i, wtt[cls])
                    wtt <- wtt[-cls]
                }
            }
        }
    }
    lst[lengths(lst) > 0]
}
