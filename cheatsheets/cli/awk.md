# awk

Field extraction, light reporting, and stateful text processing.

## Everyday selection and fields

```bash
awk '{print $1}' file
awk '{print $NF}' file                  # last field
awk -F ':' '{print $1, $3}' /etc/passwd
awk 'NR > 1' data.csv                   # skip header
awk '/pattern/' file                    # matching lines
awk '$1 == "foo" {print $2}' file
```

## Reports and transforms

```bash
awk '{sum += $1} END {print sum}' file
awk '{sum += $1; n++} END {if (n) print sum / n}' file
awk '{count[$1]++} END {for (k in count) print count[k], k}' file | sort -nr
awk '{print NR ":" $0}' file            # add line numbers
awk -F, 'BEGIN {OFS="\t"} {$1=$1; print}' file  # CSV-ish delimiter conversion
```

## Practical filters

```bash
df -h | awk 'NR == 1 || $5 + 0 >= 80'  # header plus nearly-full filesystems
ps aux | awk '$3 > 10 {print $2, $3, $11}'
rg -n 'TODO' | awk -F: '{print $1}' | sort -u
```

## With shell history

```bash
awk '{count[$1]++} END {for (k in count) print count[k], k}' ~/.bash_history |
  sort -nr |
  head
```

## Notes

`$0` is the full record, `$1` through `$NF` are fields, `NR` is the input line number, and `FNR` resets for each file. Use `-F` to set the input separator and `OFS` for output.
