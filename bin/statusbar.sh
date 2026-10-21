#!/bin/bash
# Status segments for herdr's tab bar (ui.tab_bar_right) on macOS.
# Usage: statusbar.sh batt|cpu|mem|net

HISTORY_LENGTH=8

state_dir() {
  if [ -n "$MSB_STATE_DIR" ]; then
    echo "$MSB_STATE_DIR"
  else
    # Installed as <plugin state>/bin/statusbar.sh; history lives in <plugin state>/state.
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/state"
  fi
}

# Appends a sample to the named history and prints the last HISTORY_LENGTH samples.
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

# stdin: `top -l 2 -n 0 -s 1`. The first sample covers time since boot, so use the last.
render_cpu() {
  local busy
  busy=$(awk '
    /^CPU usage/ { idle = $7 }
    END { if (idle == "") exit 1; sub("%", "", idle); printf "%.0f", 100 - idle }') || return 1
  echo "󰻠 ${busy}% $(push_history cpu "$busy" | sparkline 100)"
}

# stdin: `vm_stat`. $1: total RAM in bytes (`sysctl -n hw.memsize`).
# Used memory matches Activity Monitor: app memory + wired + compressed.
render_mem() {
  local used
  used=$(awk '
    /page size of/           { page = $8 }
    /^Anonymous pages/       { anon = $3 }
    /^Pages purgeable/       { purgeable = $3 }
    /^Pages wired down/      { wired = $4 }
    /^Pages occupied by compressor/ { compressed = $5 }
    END { printf "%.0f", (anon - purgeable + wired + compressed) * page }')
  local gb
  gb=$(awk -v b="$used" 'BEGIN { printf "%.0f", b / 1073741824 }')
  echo "󰍛 ${gb} GB $(push_history mem "$used" | sparkline "$1")"
}

NET_SPARKLINE_FLOOR=10240 # B/s; keeps a quiet link from drawing full bars

# Bytes per second -> "121 kB/s" or "1.4 MB/s".
format_rate() {
  awk -v b="$1" 'BEGIN {
    kb = int(b / 1024)
    if (kb >= 1024) printf "%.1f MB/s", b / 1048576
    else printf "%d kB/s", kb
  }'
}

# stdin: two `netstat -ibn -I <iface>` outputs taken 1 s apart.
# Byte columns are counted from the end: utun rows have no link address.
render_net() {
  local down up history max
  read -r down up < <(awk '
    /<Link#/ {
      n++
      if (n == 1) { in0 = $(NF-4); out0 = $(NF-1) }
      else        { in1 = $(NF-4); out1 = $(NF-1) }
    }
    END {
      d = in1 - in0; u = out1 - out0
      if (d < 0) d = 0
      if (u < 0) u = 0
      printf "%.0f %.0f\n", d, u
    }')
  history=$(push_history net "$down")
  max=$(echo "$history" | awk -v floor="$NET_SPARKLINE_FLOOR" '
    BEGIN { max = floor } $1 > max { max = $1 } END { printf "%.0f", max }')
  echo "↓$(format_rate "$down") ↑$(format_rate "$up") $(echo "$history" | sparkline "$max")"
}

# stdin: `pmset -g batt`. Prints nothing on a Mac without a battery.
render_batt() {
  awk -F'\t' '
    /InternalBattery/ {
      n = split($2, part, "; ")
      pct = part[1] + 0
      state = part[2]
      remain = (n >= 3 && part[3] ~ /^[0-9]+:[0-9][0-9] /) ? part[3] : ""
      sub(/ .*/, "", remain)
      if (remain == "0:00") remain = ""

      split("󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹", icon, " ")
      level = int((pct + 5) / 10) + 1

      out = icon[level] " " pct "%"
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

  case "$1" in
    batt) pmset -g batt | render_batt ;;
    cpu) top -l 2 -n 0 -s 1 | render_cpu ;;
    mem) vm_stat | render_mem "$(sysctl -n hw.memsize)" ;;
    net)
      local iface
      iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
      if [ -z "$iface" ]; then
        echo "󰖪 offline"
        return
      fi
      { netstat -ibn -I "$iface"; sleep 1; netstat -ibn -I "$iface"; } | render_net
      ;;
    *)
      echo "usage: statusbar.sh batt|cpu|mem|net" >&2
      return 64
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
