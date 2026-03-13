# Bash completion for dshell

_dshell_themes() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotshell/themes"
  local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/dotshell/themes"
  local names=""
  for f in "$config_dir"/*.json "$data_dir"/*.json; do
    [[ -f "$f" ]] || continue
    local base="${f##*/}"
    names+="${base%.json} "
  done
  echo "$names" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

_dshell_profiles() {
  local general="${XDG_DATA_HOME:-$HOME/.local/share}/dotshell/general.json"
  if [[ -f "$general" ]]; then
    sed -n 's/.*"name" *: *"\([^"]*\)".*/\1/p' "$general" | tr '\n' ' '
  fi
}

_dshell_settings_categories() {
  local general="${XDG_DATA_HOME:-$HOME/.local/share}/dotshell/general.json"
  if [[ -f "$general" ]]; then
    sed -n '/"settingsCategoryOrder"/,/]/{ s/.*"\([a-z-]*\)".*/\1/p }' "$general" | tr '\n' ' '
  fi
}

_dshell_popup_modules() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotshell/modules"
  local names=""
  for f in "$config_dir"/*/module.json; do
    [[ -f "$f" ]] || continue
    if grep -q '"popup"' "$f"; then
      local id
      id="$(sed -n 's/.*"id" *: *"\([^"]*\)".*/\1/p' "$f")"
      [[ -n "$id" ]] && names+="$id "
    fi
  done
  echo "$names"
}

_dshell_complete() {
  local cur prev
  _init_completion || return

  case "$COMP_CWORD" in
  1)
    COMPREPLY=($(compgen -W "bar idle notifications power popup profile settings theme" -- "$cur"))
    ;;
  2)
    case "${COMP_WORDS[1]}" in
    bar) COMPREPLY=($(compgen -W "focus" -- "$cur")) ;;
    idle) COMPREPLY=($(compgen -W "enable disable toggle state" -- "$cur")) ;;
    notifications) COMPREPLY=($(compgen -W "toggle clear-all" -- "$cur")) ;;
    power) COMPREPLY=($(compgen -W "toggle" -- "$cur")) ;;
    popup) COMPREPLY=($(compgen -W "toggle close" -- "$cur")) ;;
    profile) COMPREPLY=($(compgen -W "list current enable" -- "$cur")) ;;
    settings) COMPREPLY=($(compgen -W "toggle show-category" -- "$cur")) ;;
    theme) COMPREPLY=($(compgen -W "list set current" -- "$cur")) ;;
    esac
    ;;
  3)
    case "${COMP_WORDS[1]}:${COMP_WORDS[2]}" in
    theme:set)
      COMPREPLY=($(compgen -W "$(_dshell_themes)" -- "$cur"))
      ;;
    profile:enable)
      COMPREPLY=($(compgen -W "$(_dshell_profiles)" -- "$cur"))
      ;;
    settings:show-category)
      COMPREPLY=($(compgen -W "$(_dshell_settings_categories)" -- "$cur"))
      ;;
    popup:toggle)
      COMPREPLY=($(compgen -W "$(_dshell_popup_modules)" -- "$cur"))
      ;;
    esac
    ;;
  esac
}

complete -F _dshell_complete dshell
