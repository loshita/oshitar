
#' Set up iFixit Answers data for model fitting
#'
#' Used in fit_model function. This function subsets the data to all questions in English,
#' creates the time_until_answer variable and sets up all other variables required for the cox regression model.
#'
#' @param data Answers data frame. The data should include variables: langid, first_answer_date, post_date, download_date,
#' new_user, category, subcategory, device, title, text, tags, n_tags
#'
#' @importFrom magrittr "%>%"
#' @importFrom stringr str_detect str_to_lower str_length str_count str_replace_all str_locate
#' @importFrom rebus "%R%" START SPC QUESTION END or1 or
#' @importFrom dplyr filter select
#'
#' @return Returns a data frame to be used in model fitting.
#'
#' @details Variables created:
#'
#' \itemize{
#'   \item new_category: reorganizes category variable (e.g. pulled out Apple products)
#'   \item weekday: day of the week the question was posted
#'   \item ampm: (morning, noon, evening, night) time of day the question was posted
#'   \item text_length, title_length, device_length
#'   \item title_questionmark: whether or not the title ends with a "?"
#'   \item title_beginwh: whether or not the title begins with "Wh"
#'   \item text_all_lower: whether or not the text is in all lower case
#'   \item text_contain_punct: whether or not the text contains any end punctuation marks
#'   \item update: whether or not the asker updated their question
#'   \item prior_effort: whether or not the asker included words in the text that indicated that
#'   they made prior effort/did research before asking the question
#'   \item gratitude: whether or not the asker expressed gratitude in the text (e.g. "Thank you", "appreciate")
#'   \item greeting: whether or not the asker included a greeting in the text
#'   \item newline_ratio: ratio of newlines to the length of the question's text
#'   \item avg_tag_length: the average length of all of a question's tags
#'   \item avg_tag_score: the score or frequency of a tag is defined as the proportion of times that tag appears
#'   in all of the data. avg_tag_score is defined as the average score/frequency of all of a question's tags
#'   \item contain_answered: whether or not the question's title contains words considered to be frequent answered terms
#'   \item contain_unanswered: whether or not the question's title contains words considered to be frequent unanswered terms
#' }
#'
#' @export

variable_setup <- function(data){

  x <- data %>%
    tibble::as.tibble() %>%
    filter(langid == "en")

  #----Create time_until_answer---------------------------------
  x$time_until_answer <- (x$first_answer_date - x$post_date) / 3600
  empty <- is.na(x$time_until_answer)
  x$time_until_answer[empty] <- (x$download_date[empty] - x$post_date[empty])/3600

  #----Convert factors to characters----------------------------
  x <- dplyr::mutate_if(x, is.factor, as.character)

  #----Recoding NAs---------------------------------------------
  # coding NAs as "Other"
  x$category[is.na(x$category)] <- "Other"
  x$subcategory[is.na(x$subcategory)] <- "Other"

  #----Creates new_category-------------------------------------
  x$new_category <- x$category

  x$apple <- str_detect(str_to_lower(x$device), pattern = START %R% or("apple",
                                                                       "ipod",
                                                                       "ipad") %R% SPC)
  x$new_category[x$apple == TRUE | x$subcategory == "iPhone" | x$category == "Mac"] <- "Apple Product"
  x$new_category[x$new_category == "Phone"] <- "Android/Other Phone" # renaming left-over phones
  x$new_category[x$new_category == "Appliance" | x$new_category == "Household"] <- "Home"
  x$new_category[x$new_category == "Car and Truck" | x$new_category == "Vehicle"] <- "Vehicle"
  # grouping smaller categories with other
  x$new_category <- forcats::fct_lump(as.factor(x$new_category), prop = 0.02)

  #----new_user-------------------------------------------------
  x$new_user <- as.factor(x$new_user)

  #----weekday--------------------------------------------------
  datetime <- as.POSIXct(x$post_date,origin="1970-01-01")
  x$weekday <- factor(weekdays(datetime), levels = c("Monday", "Tuesday", "Wednesday",
                                                     "Thursday", "Friday", "Saturday", "Sunday"))

  #----ampm/hour------------------------------------------------
  hour <- as.numeric(format(datetime,"%H"))
  x$ampm <- "Night"
  x$ampm[hour >= 5 & hour < 12] <- "Morning"
  x$ampm[hour >= 12 & hour < 17] <- "Afternoon" #noon - 5pm
  x$ampm[hour >= 17 & hour < 20] <- "Evening" #5pm - 8pm

  #----text length----------------------------------------------
  x$text_length <- str_length(x$text)

  #----device_length--------------------------------------------
  x$device_length <- str_length(x$device)

  #----title_length---------------------------------------------
  x$title_length <- str_length(x$title)

  #----if the title ends with a "?"-----------------------------
  x$title_questionmark <- str_detect(x$title, pattern = QUESTION %R% END)

  #----if the title begins with "wh"----------------------------
  x$title_beginwh <- str_detect(str_to_lower(x$title), pattern = "^wh")

  #----if text is in all lower case-----------------------------
  cleaned <- str_replace_all(x$text, " ", "")
  cleaned <- str_replace_all(cleaned, "[[:punct:]]|[[:digit:]]", "")
  x$text_all_lower <- str_detect(cleaned, pattern = "^[[:lower:]]+$")

  #----if text contains any end punct---------------------------
  x$text_contain_punct <- str_detect(x$text, pattern = "[.|?|!]")

  #----if user updated question---------------------------------
  x$update <- str_detect(x$text, pattern = "===")

  #----if user showed any prior effort--------------------------
  x$prior_effort <- str_detect(str_to_lower(x$text),
                               pattern = or("tried", "searched", "researched", "tested",
                                            "replaced", "used", "checked", "investigated",
                                            "considered", "measured", "attempted", "inspected", "fitted"))

  #----if user showed any gratitude-----------------------------
  x$gratitude <- str_detect(str_to_lower(x$text),
                            pattern = or("please", "thank you", "thanks", "thankful",
                                         "appreciate", "appreciated", "grateful"))

  #----if user included a greeting------------------------------
  x$greeting <- str_detect(str_to_lower(x$text), pattern = START %R% or("hey", "hello", "greetings", "hi"))

  #----newline ratio to length of text--------------------------
  x$newline_ratio <- str_count(x$text, pattern = "\n")/str_length(x$text)

  #----average tag length---------------------------------------
  taglist <- oshitar::tag_frequency(x$tags)
  split_tags <- taglist[[1]]
  tag_freq <- taglist[[2]]

  x$avg_tag_length <- 0
  for (j in which(x$n_tags != 0)) {
    x$avg_tag_length[j] <- sum(str_length(as.vector(split_tags[j,]))) / sum(as.vector(split_tags[j,]) != "")
  }

  #----freqency of tags-----------------------------------------
  score1 <- oshitar::assign_tag_freq(split_tags[,1], tag_freq)
  score2 <- oshitar::assign_tag_freq(split_tags[,2], tag_freq)
  score3 <- oshitar::assign_tag_freq(split_tags[,3], tag_freq)
  score4 <- oshitar::assign_tag_freq(split_tags[,4], tag_freq)

  x$avg_tag_score <- 0
  hastag <- which(x$n_tags != 0)
  x$avg_tag_score[hastag] <- (score1[hastag] + score2[hastag] + score3[hastag] + score4[hastag]) / as.numeric(x$n_tags[hastag])

  #----frequent terms in answered/unanswered questions' titles--
  remove <- c(unique(as.character(x$category)), unique(as.character(x$subcategory)),
              unique(as.character(x$new_category)), "macbook", "imac", "ipod")

  au_terms <- oshitar::get_au_terms(x, "title", stopwords = c("can", "will", "cant", "wont",
                                                              "works", "get", "help", "need",
                                                              "fix", "doesnt", "dont"), remove = remove)
  p <- 0.01
  r <- 1
  answeredTerms <- au_terms %>%
    filter(prop_in_answered > p) %>% filter(ratio > r)

  unansweredTerms <- au_terms %>%
    filter(prop_in_unanswered > p) %>% filter(ratio < r)

  x$contain_answered <- str_detect(str_to_lower(as.character(x$title)), pattern = or1(answeredTerms$word))
  x$contain_unanswered <- str_detect(str_to_lower(as.character(x$title)), pattern = or1(unansweredTerms$word))

  return(x)
}

#-------------------------------------------------------------------------------

#' Fit cox regression model
#'
#' This function sets up variables in the input data using the variable_setup function,
#' and then fits and returns the model.
#'
#' @param data The data to use in fitting the model.
#' @param summary If true, this function will print a summary of the model (e.g. statistics, coefficients).
#' Default is set to false.
#'
#' @importFrom rms cph strat pol rcs
#'
#' @return Returns the cox regression model with 19 independent predictors. See the documentation on the
#' variable_setup function for details on what each predictor represents.
#'
#' @details
#' \itemize {
#'   \item this model is stratified on ampm
#'   \item contains a quadratic term on text_length
#'   \item restricted cubic splines on device_length (5 knots), avg_tag_length (4 knots), and newline_ratio (4 knots)
#' }
#'
#' @export

fit_model <- function(data, summary = FALSE) {
  data <- oshitar::variable_setup(data)
  fit <- rms::cph(survival::Surv(time_until_answer, answered) ~ new_category + new_user + contain_unanswered +
                    contain_answered + title_questionmark + title_beginwh + text_contain_punct +
                    text_all_lower + update + greeting + gratitude + prior_effort + weekday + strat(ampm) +
                    sqrt(avg_tag_score) + pol(text_length, 2) + rcs(device_length, 5) + rcs(avg_tag_length, 4) +
                    rcs(newline_ratio, 4), data = data, x = TRUE, y = TRUE, surv = TRUE)
  if (summary == TRUE) {
    print(fit)
  }
  return(fit)
}

#-------------------------------------------------------------------------------

#' Predict failure probabilities for questions on Answers
#'
#' This function uses a fitted cox proportional hazards model to predict failure probabilities with the
#' survest function from the rms package. Failure is defined as 1 - survival probability, and indicates the
#' probability that an event does happen before a certain time. In this case, the failure probability at time t
#' for a question is the probability that a question receives an answer before time t.
#'
#' @param model The cox regression model to use for predictions (output from the fit_model function). This function
#' only works with cph fits, not coxph fits.
#' @param newdata Optional, new data from which to get predictions for. If this is omitted, this function
#' will output predictions for each row/question in the data set the model was fit on.
#' @param times vector of times at which to predict on. If omitted, this function will return predictions at
#' 0.5, 1, 3, 4, 10, 24 hours.
#'
#' @return Returns a data frame of predicted failure probabilities. The columns are the times predicted on, the
#' rows correspond to each question in the data.

predict_failure <- function(model, newdata = NULL, times = c(0.5, 1, 3, 5, 10, 24)) {
  if (!is.null(newdata)) {
    pr <- data.frame(1 - rms::survest(model, newdata, times = times, conf.int = FALSE)$surv)
  } else {
    pr <- data.frame(1 - rms::survest(model, times = times, conf.int = FALSE)$surv)
  }
  colnames(pr) <- times
  return(pr)
}

#-------------------------------------------------------------------------------