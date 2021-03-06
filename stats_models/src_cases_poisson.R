library(splines)

library(Metrics)
library(cowplot)
library(ggplot2)
library(DT)

# Preprocess eweek data ---------------------------------------------------

source("../stats_models/get_eweek_data.R")


# Mean interval score (MIS) -----------------------------------------------

mis <- function(y, lt, ut, alpha = 0.05) {
  s1 <- 2 / alpha * (lt - y)
  s2 <- 2 / alpha * (y - ut)
  o  <- ifelse(y > ut, (ut - lt) + s2,
               ifelse(y < lt, (ut - lt) + s1, ut - lt))
  mean(o)
}

# Model fit and predictions -------------------------------------------------
fit_model <- function(train, ahead=2, cv=FALSE) {

  test <- train %>%
    filter(eweek > max(eweek) - ahead) 
       
  if (cv) {
    train <- train %>% 
      filter(eweek <= max(eweek) - ahead)
  } else {
    test <- test %>% 
      group_by(cidade) %>% 
      mutate(
        eweek = eweek + ahead,
        myweek = myweek + ahead,
        wcases = NA_real_
      ) %>% 
      ungroup() 
  }
  
  ## Fit the model
  fit <- glm(
    formula = wcases ~ ns(myweek, 3) + cidade + offset(log(estimated_population_2019)),
    family = quasipoisson(link = "log"),
    data = train
  )

  test <- test %>%
    getPI(fit, nSim = 100, confs = .95) %>% 
    rename(lw_pi = lwr0.950, up_pi = upr0.950)
  
  train <- train %>% 
    getPI(fit, nSim = 100, confs = .95) %>% 
    rename(lw_pi = lwr0.950, up_pi = upr0.950)
  
  tb <- train %>% 
    mutate(base = "train") %>% 
    bind_rows(
      test %>% 
        mutate(base = "test")
    ) %>% 
    select(cidade, myweek, eweek, wcases, pred, lw_pi, up_pi, base) 
  
  tb
}

summary_model <- function(tb, cities) {
  
  met <- tb %>% 
    filter(cidade %in% cities) %>% 
    group_by(cidade, base) %>% 
    summarise(
      rmse = rmse(wcases, pred),
      mdae = mdae(wcases, pred),
      mae  = mae(wcases, pred),
      mis  = mis(wcases, lw_pi, up_pi),
      n_obs = n()
    )
  
  plots <- tb %>%
    filter(cidade %in% cities) %>% 
    ggplot(aes(x = myweek, y = wcases)) +
    facet_wrap(~cidade, scales = "free") +
    geom_point(shape = 21, size = 3, fill = "grey69", col = "black") +
    geom_errorbar(aes(ymin = lw_pi, ymax = up_pi)) +
    geom_point(aes(y = pred), shape = 21, size = 3, fill = "blue", col = "black") +
    theme_half_open() +
    background_grid()
  
  future <- tb %>% 
    filter(base == "test") %>% 
    mutate(pred = round(pred, 2), 
           ip = paste0("(", lw_pi, ", ", up_pi, ")")) %>% 
    select(-c(lw_pi, up_pi, base, wcases))
  
  tab <- datatable(
    data = future,
    colnames = c("Cidade" = 1, "My week" = 2, "Epi. Week" = 3,
                 "Predito" = 4, "Int. Prev." = 5 ),
    rownames = FALSE,
    filter = "top", 
    options = list(pageLength = 8, autoWidth = TRUE)
  )
  
  list(
    met = met, 
    plots = plots,
    tab = tab
  )
}

## Usage
# tb  <- fit_model(eweekdata, ahead = 2, cv = TRUE)
# out <- summary_model(tb, cities = c("São Paulo-SP", "Campinas-SP"))



