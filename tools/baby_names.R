
#devtools::install_github("hadley/babynames")
require('babynames')
library(dplyr)

head(babynames)

names_by_year <- group_by(babynames, year)
summed_names <- summarise(names_by_year, count = n(), names = sum(n), female = sum(sex == 'F'), male = sum(sex == 'M'))

names_by_year <- arrange(names_by_year, year, -n)
names_by_year_i <- mutate(names_by_year, index = row_number(n))

top_names_by_year <- filter(names_by_year, )

tallied <- tally(names_by_year)
top_names_by_year <- top_n(names_by_year, 100, n )

summed_names <- summarise(top_names_by_year, count = n(), names = sum(n), female = sum(sex == 'F'), male = sum(sex == 'M'))

write.table(top_names_by_year, file = "~/Desktop/top_baby_names.tsv", sep = "\t", row.names = FALSE, col.names = TRUE)
