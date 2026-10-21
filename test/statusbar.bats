#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../bin/statusbar.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  export MSB_STATE_DIR="$BATS_TEST_TMPDIR/state"
}

@test "battery: charging shows level icon, percent, time to full and a bolt" {
  run render_batt < "$FIXTURES/pmset-charging.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "󰁾 54% 1:45 ⚡" ]
}

@test "battery: discharging shows time left without a bolt" {
  run render_batt < "$FIXTURES/pmset-discharging.txt"
  [ "$output" = "󰂁 76% 4:12" ]
}

@test "battery: no estimate hides the time" {
  run render_batt < "$FIXTURES/pmset-no-estimate.txt"
  [ "$output" = "󰂁 76%" ]
}

@test "battery: fully charged shows a full icon and no time or bolt" {
  run render_batt < "$FIXTURES/pmset-charged.txt"
  [ "$output" = "󰁹 100%" ]
}

@test "battery: plugged in but not charging shows no bolt" {
  run render_batt < "$FIXTURES/pmset-not-charging.txt"
  [ "$output" = "󰂁 80%" ]
}

@test "battery: nearly empty shows the outline icon" {
  run render_batt < "$FIXTURES/pmset-low.txt"
  [ "$output" = "󰂎 3% 0:09" ]
}

@test "battery: a Mac without a battery prints nothing" {
  run render_batt < "$FIXTURES/pmset-desktop.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "cpu: busy percent comes from the second top sample" {
  run render_cpu < "$FIXTURES/top.txt"
  [ "$status" -eq 0 ]
  [ "$output" = " 13% ▂" ]
}

@test "cpu: the sparkline shows the last 8 samples, oldest first" {
  mkdir -p "$MSB_STATE_DIR"
  printf '%s\n' 100 0 25 50 75 100 90 60 40 > "$MSB_STATE_DIR/cpu.history"
  run render_cpu < "$FIXTURES/top.txt"
  [ "$output" = " 13% ▃▅▇██▅▄▂" ]
}

# 24 GiB Mac. Used = app (anonymous - purgeable) + wired + compressed, like Activity Monitor:
# (501000 - 8187 + 185983 + 593800) pages * 16384 B = 19.4 GiB, 81% of RAM.
@test "mem: shows used memory like Activity Monitor, scaled to total RAM" {
  run render_mem 25769803776 < "$FIXTURES/vm_stat.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "󰍛 19 GB ▇" ]
}

# en0 fixture: 7280 B in and 4357 B out between the two samples.
@test "net: shows download and upload per second from two netstat samples 1 s apart" {
  run render_net < "$FIXTURES/netstat-en0.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "↓7 kB/s ↑4 kB/s ▆" ]
}

# utun fixture has no link address column: 2097152 B in, 102400 B out.
@test "net: switches to MB/s from 1024 kB/s and reads interfaces without a link address" {
  run render_net < "$FIXTURES/netstat-utun.txt"
  [ "$output" = "↓2.0 MB/s ↑100 kB/s █" ]
}

@test "net: the download sparkline scales to the busiest recent sample" {
  mkdir -p "$MSB_STATE_DIR"
  printf '%s\n' 0 20480 10240 > "$MSB_STATE_DIR/net.history"
  run render_net < "$FIXTURES/netstat-en0.txt"
  [ "$output" = "↓7 kB/s ↑4 kB/s ▁█▅▃" ]
}
