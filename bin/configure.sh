#!/bin/bash
# herdr plugin actions for herdr-macos-statusbar.
# Usage: configure.sh configure|unconfigure|startup

SEGMENTS="batt cpu mem net"
MARKER="# macos-statusbar:"

segment_interval() {
  case "$1" in
    batt) echo 30 ;;
    mem) echo 5 ;;
    *) echo 3 ;;
  esac
}

# $1: script path, rest: segments. Prints one tab_bar_right entry per line.
segment_entries() {
  local script="$1" segment
  shift
  for segment in "$@"; do
    printf '  { type = "command", command = "'\''%s'\'' %s", interval_seconds = %s, timeout_seconds = 5 }, %s%s\n' \
      "$script" "$segment" "$(segment_interval "$segment")" "$MARKER" "$segment"
  done
}

# stdin: config.toml, stdout: config.toml with the segments that are not there yet
# at the start of ui.tab_bar_right. Exits 3 on a layout it cannot edit safely.
config_add() {
  local script="$1" input missing="" segment
  input=$(cat)
  for segment in $SEGMENTS; do
    case "$input" in
      *"$MARKER$segment"*) ;;
      *) missing="$missing $segment" ;;
    esac
  done
  if [ -z "$missing" ]; then
    printf '%s\n' "$input"
    return
  fi

  # shellcheck disable=SC2086 # $missing is a list of segment names
  printf '%s\n' "$input" | MSB_ENTRIES="$(segment_entries "$script" $missing)" awk '
    BEGIN { entries = ENVIRON["MSB_ENTRIES"] }
    { line[NR] = $0 }
    /^[ \t]*\[/ { in_ui = 0; seen_table = 1 }
    !seen_table && /^[ \t]*ui[ \t]*[.=]/ {
      refuse = "ui settings are written as dotted keys or an inline table"
    }
    /^[ \t]*\[ui\][ \t]*(#.*)?$/ { ui = NR; in_ui = 1; next }
    /^[ \t]*\[ui\.[^]]*\][ \t]*(#.*)?$/ && !first_sub { first_sub = NR }
    in_ui && /^[ \t]*tab_bar_right[ \t]*=/ {
      if ($0 ~ /=[ \t]*\[[ \t]*(#.*)?$/) array_open = NR
      else if ($0 ~ /=[ \t]*\[[ \t]*\][ \t]*(#.*)?$/) array_empty = NR
      else refuse = "tab_bar_right is not a multi-line array"
    }
    END {
      if (refuse != "") {
        print "Unsupported config.toml layout: " refuse ". No changes made." > "/dev/stderr"
        print "Add these entries to ui.tab_bar_right by hand:\n" entries > "/dev/stderr"
        exit 3
      }
      if (NR == 1 && line[1] == "") NR = 0
      new_array = "tab_bar_right = [\n" entries "\n]"
      new_table = "[ui]\n" new_array
      if (NR == 0) { print new_table; exit }

      for (i = 1; i <= NR; i++) {
        if (!ui && i == first_sub) print new_table "\n"
        if (i == array_empty) { print new_array; continue }
        print line[i]
        if (i == array_open) print entries
        if (i == ui && !array_open && !array_empty) print new_array
      }
      if (!ui && !first_sub) print "\n" new_table
    }'
}

# stdin: config.toml, stdout: config.toml without the lines config_add put in.
config_remove() {
  # grep exits 1 when every line was ours; only 2 is an error.
  grep -v -F "$MARKER" || [ $? -eq 1 ]
}

config_path() {
  echo "${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
}

installed_script() {
  echo "$HERDR_PLUGIN_STATE_DIR/bin/statusbar.sh"
}

# Copies statusbar.sh out of the versioned plugin checkout, which
# `herdr plugin update` replaces, to a path config.toml can keep pointing at.
install_script() {
  local dest
  dest=$(installed_script)
  mkdir -p "$(dirname "$dest")"
  /bin/cp -f "$HERDR_PLUGIN_ROOT/bin/statusbar.sh" "$dest.tmp.$$"
  chmod +x "$dest.tmp.$$"
  /bin/mv -f "$dest.tmp.$$" "$dest"
}

reload_config() {
  local result
  result=$("${HERDR_BIN_PATH:-herdr}" server reload-config 2>&1)
  case "$result" in
    *'"status":"applied"'*)
      case "$result" in
        *'"diagnostics":[]'*) return 0 ;;
      esac
      ;;
  esac
  echo "herdr did not accept the new config: $result" >&2
  return 1
}

# Runs an edit function over config.toml with a backup, then reloads herdr and
# restores the backup if herdr rejects the result.
edit_config() {
  local config before after backup_dir backup tmp
  config=$(config_path)
  if [ -L "$config" ]; then
    echo "$config is a symlink; edit the file it points to by hand. No changes made." >&2
    return 1
  fi

  before=""
  [ -f "$config" ] && before=$(cat "$config")
  after=$(printf '%s\n' "$before" | "$@") || return 1
  if [ "$after" = "$before" ]; then
    echo "config.toml already up to date"
    return 0
  fi

  backup_dir="$HERDR_PLUGIN_STATE_DIR/backups"
  mkdir -p "$backup_dir" "$(dirname "$config")"
  if [ -f "$config" ]; then
    backup="$backup_dir/config-$(date +%Y%m%d-%H%M%S)-$$.toml"
    /bin/cp -f "$config" "$backup"
  else
    backup="$backup_dir/config-$(date +%Y%m%d-%H%M%S)-$$.absent"
    : > "$backup"
  fi

  tmp="$config.tmp.$$"
  printf '%s\n' "$after" > "$tmp"
  if [ -f "$config" ] && [ "$(cat "$config")" != "$before" ]; then
    /bin/rm -f "$tmp"
    echo "$config changed while editing it. No changes made." >&2
    return 1
  fi
  /bin/mv -f "$tmp" "$config"

  if ! reload_config; then
    case "$backup" in
      *.absent) /bin/rm -f "$config" ;;
      *) /bin/cp -f "$backup" "$config" ;;
    esac
    reload_config >/dev/null 2>&1
    echo "Restored $config from $backup." >&2
    return 1
  fi
  echo "Updated $config (backup: $backup)"
}

main() {
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
  : "${HERDR_PLUGIN_STATE_DIR:?run this through herdr plugin action invoke}"
  : "${HERDR_PLUGIN_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

  case "$1" in
    configure)
      install_script
      edit_config config_add "$(installed_script)"
      ;;
    unconfigure)
      edit_config config_remove && /bin/rm -f "$(installed_script)"
      ;;
    startup)
      # Pick up a plugin update, but only for users who ran configure.
      if [ -f "$(installed_script)" ]; then install_script; fi
      ;;
    *)
      echo "usage: configure.sh configure|unconfigure|startup" >&2
      return 64
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
