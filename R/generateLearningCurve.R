#' @title Generates a learning curve.
#'
#' @description
#' Observe how the performance changes with an increasing number of observations.
#'
#' @family generate_plot_data
#' @family learning_curve
#' @aliases LearningCurveData
#'
#' @param learners [(list of) [Learner])\cr
#'   Learning algorithms which should be compared.
#' @template arg_task
#' @param resampling ([ResampleDesc] | [ResampleInstance])\cr
#'   Resampling strategy to evaluate the performance measure.
#'   If no strategy is given a default "Holdout" will be performed.
#' @param percs ([numeric])\cr
#'   Vector of percentages to be drawn from the training split.
#'   These values represent the x-axis.
#'   Internally [makeDownsampleWrapper] is used in combination with [benchmark].
#'   Thus for each percentage a different set of observations is drawn resulting in noisy performance measures as the quality of the sample can differ.
#' @param measures [(list of) [Measure])\cr
#'   Performance measures to generate learning curves for, representing the y-axis.
#' @param stratify (`logical(1)`)\cr
#'   Only for classification:
#'   Should the downsampled data be stratified according to the target classes?
#' @template arg_showinfo
#' @return ([LearningCurveData]). A `list` containing:
#'   \item{task}{[[Task])\cr
#'     The task.}
#'   \item{measures}{[(list of) [Measure])\cr
#'     Performance measures.}
#'   \item{data}{([data.frame]) with columns:
#'     \itemize{
#'       \item `learner` Names of learners.
#'       \item `percentage` Percentages drawn from the training split.
#'       \item One column for each
#'     [Measure] passed to [generateLearningCurveData].
#'    }}
#' @examples
#' r = generateLearningCurveData(list("classif.rpart", "classif.knn"),
#' task = sonar.task, percs = seq(0.2, 1, by = 0.2),
#' measures = list(tp, fp, tn, fn), resampling = makeResampleDesc(method = "Subsample", iters = 5),
#' show.info = FALSE)
#' plotLearningCurve(r)
#' @noMd
#' @export
generateLearningCurveData = function(learners, task, resampling = NULL,
  percs = seq(0.1, 1, by = 0.1), measures, stratify = FALSE, show.info = getMlrOption("show.info"))  {

  learners = ensureVector(learners, 1, "Learner")
  learners = lapply(learners, checkLearner)
  assertClass(task, "Task")
  assertNumeric(percs, lower = 0L, upper = 1L, min.len = 2L, any.missing = FALSE)
  measures = checkMeasures(measures, task)
  assertFlag(stratify)

  if (is.null(resampling))
    resampling = makeResampleInstance("Holdout", task = task)
  else
    assert(checkClass(resampling, "ResampleDesc"), checkClass(resampling, "ResampleInstance"))

  # create downsampled versions for all learners
  lrnds1 = lapply(learners, function(lrn) {
    lapply(seq_along(percs), function(p.id) {
      perc = percs[p.id]
      dsw = makeDownsampleWrapper(learner = lrn, dw.perc = perc, dw.stratify = stratify)
      list(
        lrn.id = lrn$id,
        lrn = setLearnerId(dsw, stri_paste(lrn$id, ".", p.id)),
        perc = perc
      )
    })
  })
  lrnds2 = unlist(lrnds1, recursive = FALSE)
  dsws = extractSubList(lrnds2, "lrn", simplify = FALSE)

  bench.res = benchmark(dsws, task, resampling,  measures, show.info = show.info)
  perfs = getBMRAggrPerformances(bench.res, as.df = TRUE)

  # get perc and learner col data
  perc = extractSubList(lrnds2[perfs$learner.id], "perc")
  learner = extractSubList(lrnds2[perfs$learner.id], "lrn.id")
  perfs = dropNamed(perfs, c("task.id", "learner.id"))

  # set short measures names and resort cols
  mids = replaceDupeMeasureNames(measures, "id")
  names(measures) = mids
  colnames(perfs) = mids
  out = cbind(learner = learner, percentage = perc, perfs)
  makeS3Obj("LearningCurveData",
    task = task,
    measures = measures,
    data = out)
}
#' @export
print.LearningCurveData = function(x, ...) {
  catf("LearningCurveData:")
  catf("Task: %s", x$task$task.desc$id)
  catf("Measures: %s", collapse(extractSubList(x$measures, "name")))
  printHead(x$data, ...)
}
#' @title Plot learning curve data using ggplot2.
#'
#' @family learning_curve
#' @family plot
#'
#' @description
#' Visualizes data size (percentage used for model) vs. performance measure(s).
#'
#' @param obj ([LearningCurveData])\cr
#'   Result of [generateLearningCurveData], with class `LearningCurveData`.
#' @param facet (`character(1)`)\cr
#'   Selects \dQuote{measure} or \dQuote{learner} to be the facetting variable.
#'   The variable mapped to `facet` must have more than one unique value, otherwise it will
#'   be ignored. The variable not chosen is mapped to color if it has more than one unique value.
#'   The default is \dQuote{measure}.
#' @param pretty.names (`logical(1)`)\cr
#'   Whether to use the [Measure] name instead of the id in the plot.
#'   Default is `TRUE`.
#' @template arg_facet_nrow_ncol
#' @template ret_gg2
#' @export
plotLearningCurve = function(obj, facet = "measure", pretty.names = TRUE,
  facet.wrap.nrow = NULL, facet.wrap.ncol = NULL) {
  assertClass(obj, "LearningCurveData")
  mappings = c("measure", "learner")
  assertChoice(facet, mappings)
  assertFlag(pretty.names)
  color = mappings[mappings != facet]

  if (pretty.names) {
    mnames = replaceDupeMeasureNames(obj$measures, "name")
    colnames(obj$data) = mapValues(colnames(obj$data),
      names(obj$measures), mnames)
  }

  data = melt(as.data.table(obj$data), id.vars = c("learner", "percentage"), variable.name = "measure", value.name = "performance")
  nlearn = length(unique(data$learner))
  nmeas = length(unique(data$measure))

  if ((color == "learner" & nlearn == 1L) | (color == "measure" & nmeas == 1L))
    color = NULL
  if ((facet == "learner" & nlearn == 1L) | (facet == "measure" & nmeas == 1L))
    facet = NULL

  if (!is.null(color))
    plt = ggplot(data, aes_string(x = "percentage", y = "performance", colour = color))
  else
    plt = ggplot(data, aes_string(x = "percentage", y = "performance"))
  plt = plt + geom_point()
  plt = plt + geom_line()
  if (!is.null(facet)) {
    plt = plt + ggplot2::facet_wrap(as.formula(stri_paste("~", facet, sep = " ")),
      scales = "free_y", nrow = facet.wrap.nrow, ncol = facet.wrap.ncol)
  }
  return(plt)
}
#' @title Plot learning curve data using ggvis.
#'
#' @family plot
#' @family learning_curve
#'
#' @description
#' Visualizes data size (percentage used for model) vs. performance measure(s).
#'
#' @param obj ([LearningCurveData])\cr
#'   Result of [generateLearningCurveData].
#' @param interaction (`character(1)`)\cr
#'   Selects \dQuote{measure} or \dQuote{learner} to be used in a Shiny application
#'   making the `interaction` variable selectable via a drop-down menu.
#'   This variable must have more than one unique value, otherwise it will be ignored.
#'   The variable not chosen is mapped to color if it has more than one unique value.
#'   Note that if there are multiple learners and multiple measures interactivity is
#'   necessary as ggvis does not currently support facetting or subplots.
#'   The default is \dQuote{measure}.
#' @param pretty.names (`logical(1)`)\cr
#'   Whether to use the [Measure] name instead of the id in the plot.
#'   Default is `TRUE`.
#' @template ret_ggv
#' @export
plotLearningCurveGGVIS = function(obj, interaction = "measure", pretty.names = TRUE) {
  requirePackages("_ggvis")
  assertClass(obj, "LearningCurveData")
  mappings = c("measure", "learner")
  assertChoice(interaction, mappings)
  assertFlag(pretty.names)
  color = mappings[mappings != interaction]

  if (pretty.names) {
    mnames = replaceDupeMeasureNames(obj$measures, "name")
    colnames(obj$data) = mapValues(colnames(obj$data),
                                   names(obj$measures),
                                   mnames)
  }

  data = setDF(melt(as.data.table(obj$data), id.vars = c("learner", "percentage"), variable.name = "measure", value.name = "performance"))
  nmeas = length(unique(data$measure))
  nlearn = length(unique(data$learner))

  if ((color == "learner" & nlearn == 1L) | (color == "measure" & nmeas == 1L))
    color = NULL
  if ((interaction == "learner" & nlearn == 1L) | (interaction == "measure" & nmeas == 1L))
    interaction = NULL

  createPlot = function(data, color) {
    if (!is.null(color)) {
      plt = ggvis::ggvis(data, ggvis::prop("x", as.name("percentage")),
                         ggvis::prop("y", as.name("performance")),
                         ggvis::prop("stroke", as.name(color)))
      plt = ggvis::layer_points(plt, ggvis::prop("fill", as.name(color)))
    } else {
      plt = ggvis::ggvis(data, ggvis::prop("x", as.name("percentage")),
                         ggvis::prop("y", as.name("performance")))
      plt = ggvis::layer_points(plt)
    }
    ggvis::layer_lines(plt)
  }

  if (!is.null(interaction)) {
    requirePackages("_shiny")
    ui = shiny::shinyUI(
        shiny::pageWithSidebar(
            shiny::headerPanel("learning curve"),
            shiny::sidebarPanel(
                shiny::selectInput("interaction_select",
                                   stri_paste("choose a", interaction, sep = " "),
                                   levels(data[[interaction]]))
            ),
            shiny::mainPanel(
                shiny::uiOutput("ggvis_ui"),
                ggvis::ggvisOutput("ggvis")
            )
        ))
    server = shiny::shinyServer(function(input, output) {
      data.sub = shiny::reactive(data[which(data[[interaction]] == input$interaction_select), ])
      plt = createPlot(data.sub, color)
      ggvis::bind_shiny(plt, "ggvis", "ggvis_ui")
    })
    shiny::shinyApp(ui, server)
  } else {
    createPlot(data, color)
  }
}
