# Thinned discrete breaks that keep the end values

A breaks *function* for discrete timeslice axes: picks about `n` evenly
spaced labels and ALWAYS includes the first and last – dense
vocabularies (`d001..d365`, `h00..h23`) stop overlapping without losing
the axis range. Pass it to
[`ggplot2::scale_x_discrete()`](https://ggplot2.tidyverse.org/reference/scale_discrete.html)
/
[`scale_y_discrete()`](https://ggplot2.tidyverse.org/reference/scale_discrete.html):

## Usage

``` r
calendar_breaks(n = 6)
```

## Arguments

- n:

  Approximate number of labels (\>= 2; default 6).

## Value

A function of the level vector, for `breaks =`.

## Details

    ggplot(x) +
      geom_calendar(calendar = cal, datetime = "t", z = "v") +
      scale_x_discrete(breaks = calendar_breaks()) +
      theme_calendar()
