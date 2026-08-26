# Coverage matrix summary

Package: timescales 0.5.0

## Rows by kind x depth

```
Key: <kind>
        kind     U     P     B
      <char> <int> <int> <int>
    argument     5    14    27
    constant     3     0     0
 constructor     4     1     1
        plot    10     0     0
       query    13     2     0
    registry    15     0     0
        verb     5     0     3
```

## Backend sweep (from @covers tags)

```
                   fn data.frame tibble data.table dtplyr  arrow
               <char>     <lgcl> <lgcl>     <lgcl> <lgcl> <lgcl>
        join_calendar       TRUE   TRUE       TRUE   TRUE   TRUE
      recast_calendar       TRUE   TRUE       TRUE   TRUE   TRUE
 recast_from_timebase       TRUE   TRUE       TRUE   TRUE  FALSE
   recast_to_timebase       TRUE   TRUE       TRUE   TRUE  FALSE
```

## Zero-coverage rows (0)

```
Empty data.table (0 rows and 2 cols): name,kind
```

Tagged rows: 4 | inferred: 99 | uncovered: 0 of 103
