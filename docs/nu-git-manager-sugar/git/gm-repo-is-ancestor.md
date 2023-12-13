# `nu-git-manager-sugar git gm repo is-ancestor`
## Description
return true iif the first revision is an ancestor of the second

# Examples
    HEAD~20 is an ancestor of HEAD
    > gm repo is-ancestor HEAD~20 HEAD
    true

    HEAD is never an ancestor of HEAD~20
    > gm repo is-ancestor HEAD HEAD~20
    false

## Parameters
- parameter_name: a
- parameter_type: positional
- syntax_shape: string
- is_optional: false
- description: the base commit-ish revision
---
- parameter_name: b
- parameter_type: positional
- syntax_shape: string
- is_optional: false
- description: the *head* commit-ish revision

## Signatures
| input     | output |
| --------- | ------ |
| `nothing` | `bool` |