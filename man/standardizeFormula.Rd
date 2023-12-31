% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/chemFormula.R
\name{standardizeFormula}
\alias{standardizeFormula}
\title{Standardize a chemical formula}
\usage{
standardizeFormula(x)
}
\arguments{
\item{x}{\code{character}, strings with the chemical formula to standardize.}
}
\value{
\code{character} strings with the standardized chemical formula.
}
\description{
\code{standardizeFormula} standardizes a supplied chemical formula according
to the Hill notation system.
}
\examples{

standardizeFormula("C6O6H12")
}
\seealso{
\code{\link[=pasteElements]{pasteElements()}} \code{\link[=countElements]{countElements()}}
}
\author{
Michael Witting and Sebastian Gibb
}
