library(dplyr)
library(tidyr)
library(datacovidbr)
library(brazilmaps)

## necessarios para mapa dinamico
library(sf)
library(stringr)

load_data <- function() {
  brasilio(silent = TRUE) %>%
    group_by(place_type, state, city) %>%
    arrange(place_type, state, city, date) %>%
    mutate(confirmed_day=confirmed - lag(confirmed, n=1, default=0),
           deaths_day=deaths - lag(deaths, n=1, default = 0)) %>% 
    ungroup()
}

calc_map_data <- function(data) {
  map_data <- data %>%
    filter(place_type == "state", is_last) %>%
    select(date,
           state,
           confirmed,
           deaths,
           estimated_population_2019,
           city_ibge_code) %>%
    mutate(
      CFR = deaths / confirmed * 100,
      deaths1m = deaths / estimated_population_2019 * 1e6,
      confirmed1m = confirmed / estimated_population_2019 * 1e6
    )
  map_data = get_brmap("State") %>%
    inner_join(map_data, by = c("State" = "city_ibge_code"))
  
  map_data
}

get_data_state <- function(data, keep_state = "SP") {
  data %>%
    filter(place_type == "state", state == keep_state) %>%
    select(date, confirmed, deaths, confirmed_day, deaths_day) %>%
    mutate(deaths = ifelse(is.na(deaths), 0, deaths))
}

get_data_city <- function(data, keep_city = "Campinas") {
  data %>%
    filter(place_type == "city", city == keep_city) %>%
    select(date, confirmed, deaths, confirmed_day, deaths_day) %>%
    mutate(deaths = ifelse(is.na(deaths), 0, deaths))
}

get_last_date <- function(data) {
  format(last(data$date), "%d/%m/%Y")
}

# x must be ordered by date
get_today_increase_text <- function(x) {
  new_value <- last(x) - nth(x, -2)
  percent_value <- ceiling(new_value / last(x) * 100)
  percent_text <- paste0("(+", percent_value, "%)")
  paste("+", new_value, percent_text)
}


### Dados para mapa dinamico no estado de SP
get_data_munic_from_state = function(data, keep_state, mun){
  cidades = data %>%
    filter(place_type == "city", state==keep_state, is_last)
  mun =  mun %>%
      left_join(cidades, by=c("code_muni"="city_ibge_code"))
  mun = mun %>% select(-abbrev_state, -state, -city, -place_type, -is_last)
  as(mun, "Spatial")
}
