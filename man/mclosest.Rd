% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mclosest.R
\name{mclosest}
\alias{mclosest}
\title{Extract closest values in a pairwise manner between two matrices}
\usage{
mclosest(x, table, ppm = 0, tolerance = Inf)
}
\arguments{
\item{x}{\code{numeric} matrix or data frame representing the query data. Each
row in \code{x} will be compared to every row in \code{table}. Both \code{x} and \code{table} are
expected to have the same number of columns, and the columns are expected to
be in the same order.}

\item{table}{\code{numeric} matrix or data frame containing the reference data to
be matched with each row of \code{x}. Each row in \code{table} will be compared to
every row in \code{x}. Both \code{table} and \code{x} are expected to have the same number
of columns, and the columns are expected to be in the same order.}

\item{ppm}{\code{numeric} representing a relative, value-specific
parts-per-million (PPM) tolerance that is added to tolerance (default is 0).}

\item{tolerance}{\code{numeric} accepted tolerance. Defaults to \code{tolerance = Inf},
thus for each row in x the closest row in table is reported, regardless of
the magnitude of the (absolute) difference.}
}
\value{
\code{integer} vector of indices indicating the closest row of \code{table} for
each row of \code{x}. If no suitable match is found for a row in \code{x} based on the
specified \code{tolerance} and \code{ppm}, the corresponding index is set to \code{NA}.
}
\description{
The \code{mclosest} function calculates the closest rows between two matrices
(or data frames) considering pairwise differences between values in columns
of \code{x} and \code{table}. It returns the index of the closest row in \code{table} for
each row in \code{x}.
}
\details{
If, for a row of \code{x}, two rows of \code{table} are closest only the index of first
row will be returned.

For both the \code{tolerance} and \code{ppm} arguments, if their length is different to
the number of columns of \code{x} and \code{table}, the input argument will be
replicated to match it.
}
\examples{
x <- data.frame(a = 1:5, b = 3:7)
table <- data.frame(c = c(11, 23, 3, 5, 1), d = c(32:35, 45))

## Get for each row of `x` the index of the row in `table` with the smallest
## difference of values (per column)
mclosest(x, table)

## If the absolute difference is larger than `tolerance`, return `NA`. Note
## that the tolerance value of `25` is used for difference for each pairwise
## column in `x` and `table`.
mclosest(x, table, tolerance = 25)

}
\author{
Philippine Louail
}
