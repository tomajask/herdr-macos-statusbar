# How herdr runs this plugin

Facts read from the herdr v0.9.5 source (github.com/herdrdev/herdr). Paths are relative to that repo, and `plugins.mdx` and `marketplace.mdx` are in `docs/next/website/src/content/docs/`. `scripts/check-herdr-citations.sh` fetches the herdr commit it pins and proves each cited file and line range exists. Set `HERDR_CHECKOUT` to reuse a local clone. It can't tell whether a range says what the bullet claims, so read the lines when you add or change a citation.

## Status entries (`ui.tab_bar_right`)

- **Execution:** a `command` entry runs as `/bin/sh -lc "<command>"` on the herdr **server** (`src/platform/macos.rs:192-201`), so with `herdr --remote` the segments show the remote machine. Shell quoting applies, and so does `~`. The shell reads the login profile (`~/.profile`), not `.zshrc`.
- **Environment:** the server's environment plus `HERDR_SOCKET_PATH`, `HERDR_BIN_PATH`, `HERDR_ACTIVE_{WORKSPACE,TAB,PANE}_ID` and `HERDR_ACTIVE_PANE_CWD`. The working directory is the focused pane's. There are no `HERDR_PLUGIN_*` variables, which is why `statusbar.sh` finds its state dir from its own path (`src/app/custom_commands.rs:244-286`).
- **Output:** herdr shows the **last** line, with control characters stripped and whitespace trimmed, cut to 80 characters per entry (`src/app/tab_bar_status.rs:17`, `:241-249`, `:278-283`).
- **Hidden entries:** a non-zero exit, a timeout (the process group gets SIGKILL) or empty output hides the entry (`src/app/tab_bar_status.rs:200-214`, `:506-515`).
- **Defaults and limits:** `interval_seconds` defaults to 5 and `timeout_seconds` to 2. There are at most 16 entries, and runs of one entry never overlap (`src/config/tab_bar.rs:3-7`).

## Tab row layout

- **Placement:** the status only ever appears in the tab row. `tab_bar_position` (`top` or `bottom`) moves the whole row, and no setting gives the status a row of its own (`src/config/model.rs:984-990`).
- **Width:** tabs win. The status shows only if at least 17 columns stay free for tabs, and otherwise it is hidden as a whole, never truncated (`src/client/shell/tabs.rs:237-255`). Every column of status takes a column from the tabs.
- **Separator:** `tab_bar_right_separator` goes between rendered entries only, and hidden entries are skipped (`src/server/client_shell.rs:205-219`, `src/client/shell/tabs.rs:268-279`).
- **Single tab:** `hide_tab_bar_when_single_tab` hides the status along with the row (`src/client/shell/config.rs:418-419`, `src/client/shell/render.rs:312`).

## Plugins

- **Manifest:** `herdr-plugin.toml` requires `id`, `name`, `version` and `min_herdr_version` (`src/app/api/plugins/manifest.rs:11-95`, `:227-243`). There is no manifest key for status entries. The only way to add one is to edit `config.toml`, which `configure` does.
- **Commands:** action, startup and build commands are argv arrays run with no shell, with the plugin root as working directory (`plugins.mdx:119-121`). Action and startup commands get `HERDR_PLUGIN_ROOT`, `HERDR_PLUGIN_STATE_DIR`, `HERDR_PLUGIN_CONFIG_DIR` and `HERDR_BIN_PATH` (`plugins.mdx:265-284`). Build commands get none of these (`plugins.mdx:242-243`). `herdr plugin action invoke` passes no arguments (`src/cli/plugin.rs:622-643`).
- **Install path:** every `herdr plugin install` and `update` creates a new checkout directory (`src/plugin_paths.rs:22-42`) and deletes the old one once no server uses it (`src/plugin_installations.rs:191-220`). That is why `configure` copies `statusbar.sh` to `$HERDR_PLUGIN_STATE_DIR/bin/` and points `config.toml` at the copy.
- **Startup hooks:** `[[startup]]` runs once per server start and again on live handoff, but not on config reload, link or enable (`plugins.mdx:247-262`).
- **Action output:** stdout and stderr go to the plugin log, capped, which you read with `herdr plugin log list` (`src/app/api/plugins/runtime.rs:316-337`).
- **Marketplace:** a public repo with the GitHub topic `herdr-plugin` is indexed every 30 minutes, unreviewed (`marketplace.mdx:12-54`). Add the topic only for a release.

## Config

- **Path:** `config.toml` lives at `$HERDR_CONFIG_PATH`, else `$XDG_CONFIG_HOME/herdr/config.toml`, else `~/.config/herdr/config.toml` (`src/config/io.rs:30-35`, `:195-200`).
- **Reload:** `herdr server reload-config` printed this on herdr 0.9.5: `{"id":"cli:server:reload-config","result":{"diagnostics":[],"status":"applied","type":"config_reload"}}`. Any other output counts as rejected, and `configure` then rolls back.
