# Bash completion for dshell — a thin adapter: candidates come from
# `dshell --complete`, so the command registry in bin/dshell is the single
# source of truth.

_dshell_complete() {
  local cur
  _init_completion || return

  local out
  out="$(dshell --complete "${COMP_WORDS[@]:1:COMP_CWORD-1}" 2>/dev/null)"

  if [[ "$out" == "__files__" ]]; then
    COMPREPLY=($(compgen -f -- "$cur"))
  else
    COMPREPLY=($(compgen -W "$out" -- "$cur"))
  fi
}

complete -F _dshell_complete dshell
