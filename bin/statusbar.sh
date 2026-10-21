#!/bin/bash
# Status segments for herdr's tab bar (ui.tab_bar_right) on macOS.
# Usage: statusbar.sh batt|cpu|mem|net [--graph] [--text]
#   --graph  add a sparkline of the last samples (cpu, mem, net)
#   --text   show BAT/CPU/MEM/NET instead of Nerd Font icons

HISTORY_LENGTH=4
NET_SPARKLINE_FLOOR=10240 # B/s; keeps a quiet link from drawing full bars

# Sets GRAPH and TEXT from the segment's flags.
parse_options() {
  GRAPH=0
  TEXT=0
  local option
  for option in "$@"; do
    case "$option" in
      --graph) GRAPH=1 ;;
      --text) TEXT=1 ;;
    esac
  done
}

# $1: icon, $2: word. Prints the one the --text flag asks for, followed by a space.
label() {
  if [ "$TEXT" = 1 ]; then printf '%s ' "$2"; else printf '%s ' "$1"; fi
}

state_dir() {
  if [ -n "$MSB_STATE_DIR" ]; then
    echo "$MSB_STATE_DIR"
  else
    # Installed as <plugin state>/bin/statusbar.sh; history lives in <plugin state>/state.
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/state"
  fi
}

# Appends a sample to the named history and prints the last HISTORY_LENGTH samples.
# History is kept without --graph too, so turning it on shows a full graph at once.
push_history() {
  local dir file
  dir=$(state_dir)
  file="$dir/$1.history"
  mkdir -p "$dir"
  { [ -f "$file" ] && cat "$file"; echo "$2"; } | tail -n "$HISTORY_LENGTH" > "$file.tmp.$$"
  /bin/mv -f "$file.tmp.$$" "$file"
  cat "$file"
}

# stdin: one sample per line. Each bar covers 1/8 of 0..max.
sparkline() {
  awk -v max="$1" '
    BEGIN { split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", bar, " ") }
    {
      i = (max > 0) ? int($1 * 8 / max) + 1 : 1
      if (i > 8) i = 8
      if (i < 1) i = 1
      printf "%s", bar[i]
    }'
}

# $1: history, $2: sparkline max. Prints " <sparkline>" with --graph, nothing without.
graph() {
  if [ "$GRAPH" = 1 ]; then printf ' %s' "$(echo "$1" | sparkline "$2")"; fi
}

# stdin: `top -l 2 -n 0 -s 1`. The first sample covers time since boot, so use the last.
render_cpu() {
  parse_options "$@"
  local busy history
  busy=$(awk '
    /^CPU usage/ { idle = $7 }
    END { if (idle == "") exit 1; sub("%", "", idle); printf "%.0f", 100 - idle }') || return 1
  history=$(push_history cpu "$busy")
  echo "$(label 󰻠 CPU)${busy}%$(graph "$history" 100)"
}

# stdin: `vm_stat`. $1: total RAM in bytes (`sysctl -n hw.memsize`).
# Used memory matches Activity Monitor: app memory + wired + compressed.
render_mem() {
  local total="$1"
  shift
  parse_options "$@"
  local used gb history
  used=$(awk '
    /page size of/           { page = $8 }
    /^Anonymous pages/       { anon = $3 }
    /^Pages purgeable/       { purgeable = $3 }
    /^Pages wired down/      { wired = $4 }
    /^Pages occupied by compressor/ { compressed = $5 }
    END { printf "%.0f", (anon - purgeable + wired + compressed) * page }')
  gb=$(awk -v b="$used" 'BEGIN { printf "%.0f", b / 1073741824 }')
  history=$(push_history mem "$used")
  echo "$(label 󰍛 MEM)${gb}G$(graph "$history" "$total")"
}

# Bytes per second -> "121k" or "1.4M".
format_rate() {
  awk -v b="$1" 'BEGIN {
    kb = int(b / 1024)
    if (kb >= 1024) printf "%.1fM", b / 1048576
    else printf "%dk", kb
  }'
}

# stdin: two `netstat -ibn -I <iface>` outputs taken 1 s apart.
# Byte columns are counted from the end: utun rows have no link address.
render_net() {
  parse_options "$@"
  local down up history max prefix=""
  read -r down up < <(awk '
    /<Link#/ {
      sample++
      if (sample == 1) { bytes_in_before = $(NF-4); bytes_out_before = $(NF-1) }
      else             { bytes_in_after = $(NF-4); bytes_out_after = $(NF-1) }
    }
    END {
      down = bytes_in_after - bytes_in_before
      up = bytes_out_after - bytes_out_before
      if (down < 0) down = 0
      if (up < 0) up = 0
      printf "%.0f %.0f\n", down, up
    }')
  history=$(push_history net "$down")
  max=$(echo "$history" | awk -v floor="$NET_SPARKLINE_FLOOR" '
    BEGIN { max = floor } $1 > max { max = $1 } END { printf "%.0f", max }')
  # The arrows already say "network", so only --text adds a label.
  [ "$TEXT" = 1 ] && prefix="NET "
  echo "${prefix}↓$(format_rate "$down") ↑$(format_rate "$up")$(graph "$history" "$max")"
}

# stdin: `pmset -g batt`. Prints nothing on a Mac without a battery.
render_batt() {
  parse_options "$@"
  awk -F'\t' -v text="$TEXT" '
    /InternalBattery/ {
      n = split($2, part, "; ")
      pct = part[1] + 0
      state = part[2]
      remain = (n >= 3 && part[3] ~ /^[0-9]+:[0-9][0-9] /) ? part[3] : ""
      sub(/ .*/, "", remain)
      if (remain == "0:00") remain = ""

      split("󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹", icon, " ")
      level = int((pct + 5) / 10) + 1

      out = (text == 1 ? "BAT" : icon[level]) " " pct "%"
      if (remain != "") out = out " " remain
      if (state == "charging" || state == "finishing charge") out = out " ⚡"
      print out
      exit
    }'
}

main() {
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
  if [ "$(uname)" != "Darwin" ]; then
    echo "herdr-macos-statusbar only runs on macOS" >&2
    return 1
  fi

  local segment="$1"
  shift
  case "$segment" in
    batt) pmset -g batt | render_batt "$@" ;;
    cpu) top -l 2 -n 0 -s 1 | render_cpu "$@" ;;
    mem) vm_stat | render_mem "$(sysctl -n hw.memsize)" "$@" ;;
    net)
      local iface
      iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
      if [ -z "$iface" ]; then
        parse_options "$@"
        echo "$(label 󰖪 NET)offline"
        return
      fi
      { netstat -ibn -I "$iface"; sleep 1; netstat -ibn -I "$iface"; } | render_net "$@"
      ;;
    *)
      echo "usage: statusbar.sh batt|cpu|mem|net [--graph] [--text]" >&2
      return 64
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
