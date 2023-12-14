# `gm repo query` (`nu-git-manager-sugar git`)
queries the `.git/` directory as a database with `nu_plugin_git_query`

## Examples
```nushell
# get the commits of the current repo
gm repo query commits
```
---
```nushell
# get the total number of insertions and deletions per author
gm repo query diffs
    | group-by name
    | transpose author data
    | insert insertions { get data.insertions | math sum }
    | insert deletions { get data.deletions | math sum }
    | reject data
```
```
#┬────author────┬insertions┬deletions
0│amtoine       │      6770│     5402
1│Antoine Stevan│      8537│     4562
2│Mel Massadian │       654│       64
─┴──────────────┴──────────┴─────────
```

## Parameters
- parameter_name: table
- parameter_type: positional
- syntax_shape: completable<string>
- is_optional: false
- custom_completion: git-query-tables

## Signatures
| input     | output  |
| --------- | ------- |
| `nothing` | `table` |