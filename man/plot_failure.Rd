% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/functions_to_predict.R
\name{plot_failure}
\alias{plot_failure}
\title{Plot failure probability predictions for a question}
\usage{
plot_failure(model, question)
}
\arguments{
\item{model}{The cox regression model to use in predicting failure (output from the fit_model function).
This function only works with cph fits.}

\item{question}{The question to predict failure probabilities on (one row of Answers data set).}
}
\value{
Returns a ggplot of the failure experience for the input question.
The plot indicates when the question is predicted to reach it's maximum
failure probabiity with red reference lines.
}
\description{
This function uses a fitted cox regression model to predict and plot failure probabilities
for a single question. Predictions are made at each minute, starting at 0 hours,
and ending at the maximum time of the data the cox model was fit on. This function then
plots those predictions against the corresponding time with ggplot.
}
\examples{
# importing data
dir <- file.path(getwd(),"data")
out <- read.csv(file.path(dir, "answers_data.csv")) # data set without any variables set up

# fitting model
model <- fit_model(out)

# setting up data to predict on
newdata <- variable_setup(newdata)
question <- newdata[1,]

plot_failure(model, question)

}
