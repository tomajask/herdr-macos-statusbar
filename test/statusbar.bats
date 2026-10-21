#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../bin/statusbar.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  export MSB_STATE_DIR="$BATS_TEST_TMPDIR/state"
}

@test "batt: charging shows level icon, percent, time to full and a bolt" {
  run render_batt < "$FIXTURES/pmset-charging.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "󰁾 54% 1:45 ⚡" ]
}

@test "batt: discharging shows time left without a bolt" {
  run render_batt < "$FIXTURES/pmset-discharging.txt"
  [ "$output" = "󰂁 76% 4:12" ]
}

@test "batt: no estimate hides the time" {
  run render_batt < "$FIXTURES/pmset-no-estimate.txt"
  [ "$output" = "󰂁 76%" ]
}

@test "batt: fully charged shows a full icon and no time or bolt" {
  run render_batt < "$FIXTURES/pmset-charged.txt"
  [ "$output" = "󰁹 100%" ]
}

@test "batt: plugged in but not charging shows no bolt" {
  run render_batt < "$FIXTURES/pmset-not-charging.txt"
  [ "$output" = "󰂁 80%" ]
}

@test "batt: nearly empty shows the outline icon" {
  run render_batt < "$FIXTURES/pmset-low.txt"
  [ "$output" = "󰂎 3% 0:09" ]
}

@test "batt: a Mac without a battery prints nothing" {
  run render_batt < "$FIXTURES/pmset-desktop.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "batt: --text swaps the icon for a word" {
  run render_batt --text < "$FIXTURES/pmset-charging.txt"
  [ "$output" = "BAT 54% 1:45 ⚡" ]
}

@test "cpu: busy percent comes from the second top sample" {
  run render_cpu < "$FIXTURES/top.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "󰻠 13%" ]
}

@test "cpu: --graph adds a sparkline of the last 4 samples, oldest first" {
  mkdir -p "$MSB_STATE_DIR"
  printf '%s\n' 100 0 25 50 75 100 90 60 40 > "$MSB_STATE_DIR/cpu.history"
  run render_cpu --graph < "$FIXTURES/top.txt"
  [ "$output" = "󰻠 13% █▅▄▂" ]
}

@test "cpu: --text swaps the icon for a word" {
  run render_cpu --text < "$FIXTURES/top.txt"
  [ "$output" = "CPU 13%" ]
}

# 24 GiB Mac. Used = app (anonymous - purgeable) + wired + compressed, like Activity Monitor:
# (501000 - 8187 + 185983 + 593800) pages * 16384 B = 19.4 GiB, 81% of RAM.
@test "mem: shows used memory like Activity Monitor" {
  run render_mem 25769803776 < "$FIXTURES/vm_stat.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "󰍛 19G" ]
}

@test "mem: --graph scales the sparkline to total RAM, --text swaps the icon for a word" {
  run render_mem 25769803776 --text --graph < "$FIXTURES/vm_stat.txt"
  [ "$output" = "MEM 19G ▇" ]
}

# en0 fixture: 7280 B in and 4357 B out between the two samples.
@test "net: shows download and upload per second from two netstat samples 1 s apart" {
  run render_net < "$FIXTURES/netstat-en0.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "↓7k ↑4k" ]
}

# utun fixture has no link address column: 2097152 B in, 102400 B out.
@test "net: switches to M from 1024k and reads interfaces without a link address" {
  run render_net < "$FIXTURES/netstat-utun.txt"
  [ "$output" = "↓2.0M ↑100k" ]
}

@test "net: --graph scales the download sparkline to the busiest recent sample" {
  mkdir -p "$MSB_STATE_DIR"
  printf '%s\n' 0 20480 10240 > "$MSB_STATE_DIR/net.history"
  run render_net --graph < "$FIXTURES/netstat-en0.txt"
  [ "$output" = "↓7k ↑4k ▁█▅▃" ]
}

@test "net: --text adds a word in front of the arrows" {
  run render_net --text < "$FIXTURES/netstat-en0.txt"
  [ "$output" = "NET ↓7k ↑4k" ]
}

@test "cpu: no top output hides the segment and keeps the history clean" {
  run render_cpu < /dev/null
  [ "$status" -ne 0 ]
  [ "$output" = "" ]
  [ ! -s "$MSB_STATE_DIR/cpu.history" ]
}

# A Nerd Font glyph is easy to lose when an editor or tool rewrites the file.
starts_with_icon() {
  # shellcheck source=../scripts/glyphs.sh
  source "$BATS_TEST_DIRNAME/../scripts/glyphs.sh"
  perl -CSD -ne 'BEGIN { $glyph = qr/$ENV{NERD_FONT_GLYPH}/ } exit(/^$glyph \S/ ? 0 : 1)' <<< "$1"
}

@test "icons: batt starts with a Nerd Font icon" {
  run render_batt < "$FIXTURES/pmset-charging.txt"
  starts_with_icon "$output"
}

@test "icons: cpu starts with a Nerd Font icon" {
  run render_cpu < "$FIXTURES/top.txt"
  starts_with_icon "$output"
}

@test "icons: mem starts with a Nerd Font icon" {
  run render_mem 25769803776 < "$FIXTURES/vm_stat.txt"
  starts_with_icon "$output"
}

@test "icons: offline starts with a Nerd Font icon" {
  run render_offline
  starts_with_icon "$output"
}

@test "net: no default route shows offline, --text says NET" {
  run render_offline --text
  [ "$output" = "NET offline" ]
}
