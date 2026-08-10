# The calendar catalog

Enumerates the named calendar designs
[`calendar()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md)
knows about — the curated set ported from the predecessor `timeslices`
package, all with duration-proportional shares. Every id here can be
built with `calendar(id)`; the same objects are shipped pre-built in the
[`calendars`](https://optimal2050.github.io/timescales/r/reference/calendars.md)
dataset.

## Usage

``` r
calendar_catalog()
```

## Value

A `data.frame` with one row per catalog entry: `id`, `tokens`
(`+`-joined), `timeframes` (`/`-joined), `n_slices`, `coverage`
(`complete`/`truncated`/`representative`), `regularity`
(`regular`/`irregular`), and a generated `desc`.

## Examples

``` r
cat_df <- calendar_catalog()
head(cat_df)
#>         id   tokens timeframes n_slices  coverage regularity
#> 1     d360     d360       YDAY      360 truncated    regular
#> 2     d364     d364       YDAY      364 truncated    regular
#> 3     d365     d365       YDAY      365 truncated    regular
#> 4     d366     d366       YDAY      366  complete    regular
#> 5 d360_h24 d360+h24  YDAY/HOUR     8640 truncated    regular
#> 6 d364_h24 d364+h24  YDAY/HOUR     8736 truncated    regular
#>                                                   desc
#> 1       YDAY calendar (360 slices; truncated, regular)
#> 2       YDAY calendar (364 slices; truncated, regular)
#> 3       YDAY calendar (365 slices; truncated, regular)
#> 4        YDAY calendar (366 slices; complete, regular)
#> 5 YDAY/HOUR calendar (8640 slices; truncated, regular)
#> 6 YDAY/HOUR calendar (8736 slices; truncated, regular)
subset(cat_df, coverage == "complete")
#>               id        tokens      timeframes n_slices coverage regularity
#> 4           d366          d366            YDAY      366 complete    regular
#> 8       d366_h24      d366+h24       YDAY/HOUR     8784 complete    regular
#> 9            m12           m12           MONTH       12 complete    regular
#> 10          m12a          m12a           MONTH       12 complete    regular
#> 11       m12_h24       m12+h24      MONTH/HOUR      288 complete    regular
#> 12      m12a_h24      m12a+h24      MONTH/HOUR      288 complete    regular
#> 17     m12_md366     m12+md366      MONTH/MDAY      366 complete  irregular
#> 18 m12_md366_h24 m12+md366+h24 MONTH/MDAY/HOUR     8784 complete  irregular
#> 19            q4            q4         QUARTER        4 complete    regular
#> 20            s4            s4          SEASON        4 complete    regular
#> 24           w53           w53            WEEK       53 complete    regular
#> 28      w53_h168      w53+h168      WEEK/WHOUR     8904 complete  irregular
#>                                                           desc
#> 4                YDAY calendar (366 slices; complete, regular)
#> 8          YDAY/HOUR calendar (8784 slices; complete, regular)
#> 9                MONTH calendar (12 slices; complete, regular)
#> 10               MONTH calendar (12 slices; complete, regular)
#> 11         MONTH/HOUR calendar (288 slices; complete, regular)
#> 12         MONTH/HOUR calendar (288 slices; complete, regular)
#> 17       MONTH/MDAY calendar (366 slices; complete, irregular)
#> 18 MONTH/MDAY/HOUR calendar (8784 slices; complete, irregular)
#> 19              QUARTER calendar (4 slices; complete, regular)
#> 20               SEASON calendar (4 slices; complete, regular)
#> 24                WEEK calendar (53 slices; complete, regular)
#> 28      WEEK/WHOUR calendar (8904 slices; complete, irregular)
```
