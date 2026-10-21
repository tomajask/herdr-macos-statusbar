#!/usr/bin/env bats

SCRIPT=/Users/me/.local/state/herdr/plugins/tomajask.macos-statusbar/bin/statusbar.sh

setup() {
  source "$BATS_TEST_DIRNAME/../bin/configure.sh"
}

entries() {
  cat <<EOF
  { type = "command", command = "'$SCRIPT' batt", interval_seconds = 30, timeout_seconds = 5 }, # macos-statusbar:batt
  { type = "command", command = "'$SCRIPT' cpu", interval_seconds = 3, timeout_seconds = 5 }, # macos-statusbar:cpu
  { type = "command", command = "'$SCRIPT' mem", interval_seconds = 5, timeout_seconds = 5 }, # macos-statusbar:mem
  { type = "command", command = "'$SCRIPT' net", interval_seconds = 3, timeout_seconds = 5 }, # macos-statusbar:net
EOF
}

@test "add: an empty config gets a [ui] table with all four segments" {
  run config_add "$SCRIPT" < /dev/null
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '[ui]\ntab_bar_right = [\n%s\n]' "$(entries)")" ]
}

@test "add: a config with only [ui.*] sub-tables gets [ui] right before the first one" {
  input=$(printf 'onboarding = false\n\n[experimental]\npane_history = true\n\n[ui.toast]\ndelivery = "off"')
  run config_add "$SCRIPT" <<< "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'onboarding = false\n\n[experimental]\npane_history = true\n\n[ui]\ntab_bar_right = [\n%s\n]\n\n[ui.toast]\ndelivery = "off"' "$(entries)")" ]
}

@test "add: a config without any [ui] table gets one appended" {
  run config_add "$SCRIPT" <<< 'onboarding = false'
  [ "$output" = "$(printf 'onboarding = false\n\n[ui]\ntab_bar_right = [\n%s\n]' "$(entries)")" ]
}

@test "add: an existing [ui] table without tab_bar_right gets the array under its header" {
  input=$(printf '[ui]\naccent = "cyan"\n\n[keys]\nprefix = "ctrl+b"')
  run config_add "$SCRIPT" <<< "$input"
  [ "$output" = "$(printf '[ui]\ntab_bar_right = [\n%s\n]\naccent = "cyan"\n\n[keys]\nprefix = "ctrl+b"' "$(entries)")" ]
}

@test "add: an existing multi-line tab_bar_right keeps the user's entries after ours" {
  input=$(printf '[ui]\ntab_bar_right = [ # mine\n  { type = "datetime" }\n]')
  run config_add "$SCRIPT" <<< "$input"
  [ "$output" = "$(printf '[ui]\ntab_bar_right = [ # mine\n%s\n  { type = "datetime" }\n]' "$(entries)")" ]
}

@test "add: an empty one-line tab_bar_right becomes a multi-line array" {
  input=$(printf '[ui]\ntab_bar_right = []\naccent = "cyan"')
  run config_add "$SCRIPT" <<< "$input"
  [ "$output" = "$(printf '[ui]\ntab_bar_right = [\n%s\n]\naccent = "cyan"' "$(entries)")" ]
}

@test "add: running it again changes nothing" {
  once=$(config_add "$SCRIPT" <<< 'onboarding = false')
  run config_add "$SCRIPT" <<< "$once"
  [ "$status" -eq 0 ]
  [ "$output" = "$once" ]
}

@test "add: only the missing segments are added back" {
  without_batt=$(config_add "$SCRIPT" < /dev/null | grep -v 'macos-statusbar:batt')
  run config_add "$SCRIPT" <<< "$without_batt"
  [ "$output" = "$(config_add "$SCRIPT" < /dev/null)" ]
}

@test "add: refuses a one-line tab_bar_right that already has entries" {
  run config_add "$SCRIPT" <<< "$(printf '[ui]\ntab_bar_right = [{ type = "datetime" }]')"
  [ "$status" -eq 3 ]
  [[ "$output" == *"tab_bar_right"* ]]
}

@test "add: refuses ui settings written as dotted keys or an inline table" {
  run config_add "$SCRIPT" <<< 'ui.tab_bar_right = []'
  [ "$status" -eq 3 ]
  run config_add "$SCRIPT" <<< 'ui = { accent = "cyan" }'
  [ "$status" -eq 3 ]
}

@test "add: ignores a commented-out tab_bar_right" {
  run config_add "$SCRIPT" <<< "$(printf '[ui]\n# tab_bar_right = []')"
  [ "$output" = "$(printf '[ui]\ntab_bar_right = [\n%s\n]\n# tab_bar_right = []' "$(entries)")" ]
}

@test "remove: takes out exactly the lines add put in an existing array" {
  input=$(printf '[ui]\ntab_bar_right = [\n  { type = "datetime" },\n]\naccent = "cyan"')
  run config_remove <<< "$(config_add "$SCRIPT" <<< "$input")"
  [ "$status" -eq 0 ]
  [ "$output" = "$input" ]
}

@test "remove: a config without our segments is left as it is" {
  run config_remove <<< 'onboarding = false'
  [ "$output" = 'onboarding = false' ]
}

@test "add: a refusal prints the entries to paste by hand" {
  run config_add "$SCRIPT" <<< 'ui.tab_bar_right = []'
  [ "$status" -eq 3 ]
  [[ "$output" == *"$(entries | sed -n 2p)"* ]]
}
