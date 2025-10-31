#analisis del dataset "datos del clima de Argentina" 
#documento descargado de https://www.kaggle.com/datasets/minahilfatima12328/argentina-atmospheric-data


library (tidyverse)
library(broom)
library (ggmap)
library(readr)
library(lubridate)
library(naniar)
library(trend)
library(moments)
library(tseries)
library(boot)


Argentina_weather_data <- read_csv("~/Documentos/mpd/datos/Argentina_weather_data.csv", 
                                   col_types = cols(Country = col_skip(), 
                                                    Date = col_date(format = "%d-%m-%Y")))

#primer acercamiento ------------------------
tail(Argentina_weather_data)
head(Argentina_weather_data)
#un registro por dia desde 01-01-2000 hasta 26-12-2023

vis_miss(Argentina_weather_data)

colSums(is.na(Argentina_weather_data))
#datos 100% precentes  
#sin valores faltantes

#primeras cuentas ----
estadis <- Argentina_weather_data %>%
  summarise(
    across(c(Temp_Min, Temp_Max), 
           list(mean = ~mean(.x, na.rm = TRUE),
                median = ~median(.x, na.rm = TRUE),
                sd = ~sd(.x, na.rm = TRUE),
                q25 = ~quantile(.x, 0.25, na.rm = TRUE),
                q75 = ~quantile(.x, 0.75, na.rm = TRUE))))
#
rango_total <- max(Argentina_weather_data$Temp_Max, na.rm = TRUE) - 
  min(Argentina_weather_data$Temp_Min, na.rm = TRUE)

estadis
rango_total

#hipotesis------------------------------------

# H1: 
# Temperaturas máximas más altas están correlacionadas 
# con temperaturas mínimas y medias más altas por día

# H2: 
# Días con viento fuerte se correlacionan 
# con rafagas de viento más intensas
#---------------------------------------------

#analisis por subconjuntos
sub_temp = subset(Argentina_weather_data, select = c("Temp_Max", "Temp_Min", "Temp_Mean"))
sub_viento =subset(Argentina_weather_data, select = c("Windspeed_Max", "Windgusts_Max"))

pairs(sub_temp)
cor(sub_temp)

pairs(sub_viento) 
cor(sub_viento)

#fuerte correlacion positiva entre los datos temperatura min max mean
#fuerte correlacion positiva entre los datos viento rafagas de viento

#hipotesis------------------------------------

# H3: 
#En Argentina se observa una evolución hacia días más cálidos
#con un aumento significativo de las temperaturas mínimas 
#---------------------------------------------

#creo la columna estacion para las estaciones del año
Argentina_weather_data <-Argentina_weather_data  %>%
    mutate(Date = as.Date(Date),
         mes = month(Date, label = TRUE, abbr = FALSE),
         año = year(Date),
         estacion = case_when(
           mes %in% c("diciembre", "enero", "febrero") ~ 1, #verano
           mes %in% c("marzo", "abril", "mayo") ~ 2, #otoño
           mes %in% c("junio", "julio", "agosto") ~ 3, #invierno
           mes %in% c("septiembre", "octubre", "noviembre") ~ 4 )) #primavera

#agrupo por año y estacion me quedo la maxima temperatura de la minima la media y la maxima 
Argentina_weather_data_group <-Argentina_weather_data %>% 
  group_by(año, estacion) %>% 
  summarise(tmin = max(Temp_Min, na.rm = TRUE),
            tmax = max(Temp_Max, na.rm = TRUE),
            tmedia = max(Temp_Mean, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(año = as.Date(paste(año, "01", "01", sep = "-")))
  
#etiquetas para el grafico
Argentina_weather_data_group <- Argentina_weather_data_group %>%
  mutate(estacion = factor(estacion,
                           levels = 1:4,
                           labels = c("verano", "otono", "invierno", "primavera")))

# agrupo la temperatura para poderla graficar
tl_largo <- Argentina_weather_data_group %>%
  pivot_longer(cols = c(tmin, tmax,  tmedia),
               names_to = "tipo", 
               values_to = "valor")

#-----------------grafico 1----------------------
p <- ggplot(tl_largo, aes(x = año, y = valor, color = tipo, group = interaction(tipo, estacion))) +
  geom_line() +
  facet_wrap(~ estacion, ncol = 2) +
  labs(title = "Evolución de la temperatura a través del tiempo por estación",
       x = "Fecha",
       y = "Temperatura (°C)",
       color = "Tipo de temperatura") +
  theme_minimal()
plot(p)
#guardar archivo----
ggsave("~/Documentos/mpd/graficos/R_temperatura_en_funcion_del_tiempo_por_estacion.jpeg", 
       plot = p, device = "jpeg", width = 27, height =21 , units = "cm")
#---------------------------------------------

#regresion lineal-----------------------

modelo_min <- lm(tmin ~ año, data = Argentina_weather_data_group)
modelo_max <- lm(tmax ~ año, data = Argentina_weather_data_group)
modelo_med <- lm(tmedia ~ año, data = Argentina_weather_data_group)

resultados_reg <- bind_rows(
  tidy(modelo_min) %>% mutate(tipo = "min"),
  tidy(modelo_max) %>% mutate(tipo = "max"),
  tidy(modelo_med) %>% mutate(tipo = "media")
)
print(resultados_reg)
#tendencia estimada muy debil

#Mann-Kendall---------------------------

variables <- c("tmin", "tmax", "tmedia")
resultados_mk <- map_df(variables, ~ mk.test(Argentina_weather_data_group[[.x]]) %>%
                          broom::tidy() %>% mutate(var = .x))

resultados_mk

# s positivo (pendiente positiva en datos de temperatura)
#es mas notorio el aumento en la maxima que en la minima o la media

# ! p > 0.05 no hay evidencia suficiente en los datos para afirmar una tendencia


#hipotesis------------------------------------

# H4:
#La ausencia datos faltantes y la falta de especificación geográfica en un país
#con alta heterogeneidad climática como Argentina, 
#sugiere que los datos podrían no provenir de mediciones reales 
#o estar artificialmente regularizados.

#graficos 2 ----------------------

#histograma y densidad (rojo) vs normal teorica (celeste)
a <- ggplot(Argentina_weather_data_group, aes(x = tmin)) +
  geom_histogram(aes(y = after_stat(density)), bins = 30, color = "black", fill = "lightblue") +
  stat_function(fun = dnorm, args = list(mean = mean(Argentina_weather_data_group$tmin), sd = sd(Argentina_weather_data_group$tmin)), color = "darkviolet", linewidth = 1) +
  geom_density(color = "red", linewidth = 0.8)
plot(a)
#---------
ggsave("~/Documentos/mpd/graficos/R_histograma_y_densidad.jpeg",
       plot = a, device = "jpeg", width = 27, height =21 , units = "cm")
#---------

#graficos 3 ----------------------
# densidad por grupos 
i <- ggplot(Argentina_weather_data_group, aes(x = tmin, color = estacion)) + 
  geom_density() + 
  labs(title = "Densidad de los datos por estación", 
       x = "Temperatura", 
       y = "Densidad", 
       color = "Estación") +
  theme_minimal()
plot(i)
#---------
ggsave("~/Documentos/mpd/graficos/R_densisdad_por_estacion.jpeg", plot = i, device = "jpeg", width = 27, height =21 , units = "cm")
#---------

# Añadir fórmula como anotación
p + annotate("text", x = Inf, y = Inf, hjust = 1, vjust = 1,
             label = "hat(f)(x) == frac(1,nh) sum(K(frac(x-x[i],h)))",
             parse = TRUE, size = 3)
#graficos 4 ----------------------
hist(resultado$t, freq = FALSE,
     xlim = c(mean(resultado$t) - 3*sd(resultado$t), mean(resultado$t) + 3*sd(resultado$t)),
     main = "Distribución de medias (Bootstrap)", xlab = "Media de temperatura minima")
lines(density(resultado$t), col = "red", lwd = 2)  # Densidad observada
curve(dnorm(x, mean = mean(resultado$t), sd = sd(resultado$t)), 
      add = TRUE, col = "darkviolet", lwd = 2)  # Normal teórica

# curvas suaves
#----------------------------------------



#bootstraping-----------------------
# media temperatura minima
media_temp <- function(data, i) {
  return(mean(data[i], na.rm = TRUE))
}
resultado <- boot(data = Argentina_weather_data_group$tmin, statistic = media_temp, R = 1500)
# bootstrap
resultado <- boot(data = Argentina_weather_data_group$tmin, statistic = media_temp, R = 1500)

# Intervalo de confianza
boot.ci(resultado, type = "perc") 


#--------------------------------------------
#rango intercuartilico q-q -----------------------

n <- ggplot(Argentina_weather_data_group, aes(sample = tmin, color ="darkred")) +
  stat_qq() + stat_qq_line(color = "darkviolet") 
plot(n)
#---------
ggsave("~/Documentos/mpd/graficos/R_Q-Q.jpeg", plot = n, device = "jpeg", width = 27, height =21 , units = "cm")
#---------

#--------------------------------------------

#colas y simetria
Argentina_weather_data_group %>%
  summarise(
    skewness = skewness(tmin, na.rm = TRUE),
    kurtosis = kurtosis(tmin, na.rm = TRUE)
  )
#leptokurtosis (de esperarse analizando temperaturas)
#asimetria negativa

#por estacion
Argentina_weather_data_group %>%
  group_by(estacion) %>%
  summarise(
    skewness = skewness(tmin, na.rm = TRUE),
    kurtosis = kurtosis(tmin, na.rm = TRUE)
  )

#---------------------------------------------

#  IQR y límites --> outliers
Q1 <- quantile(Argentina_weather_data_group$tmin, 0.25)
Q3 <- quantile(Argentina_weather_data_group$tmin, 0.75)
IQR_val <- Q3 - Q1
lim_inf <- Q1 - 1.5 * IQR_val
lim_sup <- Q3 + 1.5 * IQR_val

outliers <- Argentina_weather_data_group %>%
  filter(tmin < lim_inf | tmin > lim_sup) 

print(paste("Outliers:", length(outliers)))

# ! 5 outliers en datos climaticos de 23 anos
#---------------------------------------------

# Prueba de rachas (runs test)
runs.test(factor(sign(Argentina_weather_data_group$tmin - mean(Argentina_weather_data_group$tmin))))  



# CSV no incluye ubicación, los datos podrían ser nacionales promediados o de una sola estación,
#lo que justifica hipótesis (H4).

# 5 outliers en datos climáticos 

#Falta de especificación geográfica limita la validez del análisis por región.

