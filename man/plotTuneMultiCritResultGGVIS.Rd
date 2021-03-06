% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plotTuneMultiCritResult.R
\name{plotTuneMultiCritResultGGVIS}
\alias{plotTuneMultiCritResultGGVIS}
\title{Plots multi-criteria results after tuning using ggvis.}
\usage{
plotTuneMultiCritResultGGVIS(res, path = TRUE, point.info = "hover",
  point.trafo = TRUE)
}
\arguments{
\item{res}{(\link{TuneMultiCritResult})\cr
Result of \link{tuneParamsMultiCrit}.}

\item{path}{(\code{logical(1)})\cr
Visualize all evaluated points (or only the non-dominated pareto front)?
Points are colored according to their location.
Default is \code{TRUE}.}

\item{point.info}{(\code{character(1)})\cr
Show for each point which hyper parameters led to this point?
For \code{"click"}, information is displayed on mouse click.
For \code{"hover"}, information is displayed on mouse hover.
If set to \code{"none"}, no information is displayed.
Default is \code{"hover"}.}

\item{point.trafo}{(\code{logical(1)})\cr
Should the information show the transformed hyper parameters?
Default is \code{TRUE}.}
}
\value{
(`character(1)`) ggvis plot object.
}
\description{
Visualizes the pareto front and possibly the dominated points.
}
\examples{
# see tuneParamsMultiCrit
}
\seealso{
Other tune_multicrit: \code{\link{TuneMultiCritControl}},
  \code{\link{plotTuneMultiCritResult}},
  \code{\link{tuneParamsMultiCrit}}
}
