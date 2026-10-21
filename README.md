# herdr-macos-statusbar

A [herdr](https://herdr.dev) plugin that puts an iTerm2-style status bar in the tab bar on macOS:

```
󰁾 54% 1:45 ⚡   󰻠 13% ▃▅▇██▅▄▂   󰍛 19 GB ▇▇▇▇▇▇▇▇   ↓121 kB/s ↑76 kB/s ▁▁▃▇▂▁▁▁
```

| Segment | Shows | Refresh |
|---|---|---|
| battery | charge, time to full or empty when macOS has an estimate, ⚡ while charging; hidden on Macs without a battery | 30 s |
| CPU | busy percent and a sparkline of the last 8 samples (0–100%) | 3 s |
| memory | used memory as Activity Monitor counts it (app + wired + compressed), sparkline scaled to total RAM | 5 s |
| network | download and upload per second on the default-route interface, download sparkline scaled to the busiest recent sample | 3 s |

It uses only tools that ship with macOS (`pmset`, `top`, `vm_stat`, `netstat`, `route`) and the system `/bin/bash`, so there is nothing else to install. Icons are Nerd Font glyphs; Ghostty ships them built in, other terminals need a Nerd Font.

## Install

Requires herdr 0.9.5 or newer.

```sh
herdr plugin install tomajask/herdr-macos-statusbar
herdr plugin action invoke configure --plugin tomajask.macos-statusbar
```

`configure` does this:

1. It copies the segment script to `~/.local/state/herdr/plugins/tomajask.macos-statusbar/bin/`. The script needs that fixed path because `herdr plugin update` replaces the plugin checkout.
2. It backs up `config.toml` to `backups/` in the same directory.
3. It adds the four segments at the start of `ui.tab_bar_right`, so whatever you already have there, such as a clock, stays on the right.
4. It runs `herdr server reload-config`. If herdr rejects the new config, the backup is restored.

You can run `configure` again safely: it only adds segments that are missing. Each entry carries a `# macos-statusbar:<segment>` comment. To reorder or drop a segment, edit or delete its line in `config.toml`. If you run `configure` again later, the deleted segments come back.

`configure` refuses to edit layouts it cannot change safely, such as a one-line `tab_bar_right = [...]` that already has entries, or `ui` written as dotted keys. In that case it prints why and leaves the file alone. Add the entries yourself, using a line `configure` would write:

```toml
[ui]
tab_bar_right = [
  { type = "command", command = "'/Users/you/.local/state/herdr/plugins/tomajask.macos-statusbar/bin/statusbar.sh' cpu", interval_seconds = 3, timeout_seconds = 5 },
]
```

After `herdr plugin update`, the copied script is refreshed the next time the herdr server starts.

## Uninstall

```sh
herdr plugin action invoke unconfigure --plugin tomajask.macos-statusbar
herdr plugin uninstall tomajask.macos-statusbar
```

`unconfigure` removes the marked lines and leaves the `tab_bar_right` array in place, which may now be empty.

## Notes

- herdr runs status commands on the server. With `herdr --remote`, the segments show the remote machine, and they stay hidden if that machine is not a Mac.
- CPU sampling takes about 2 s (`top` needs two samples), which is why every entry has `timeout_seconds = 5`.
- Network rates come from two `netstat` readings taken 1 s apart. On a VPN, the default route is the tunnel interface, so traffic is not counted twice.

## Development

```sh
brew install bats-core shellcheck
bats test/
shellcheck bin/*.sh
herdr plugin link .
```

The tests feed raw output from the macOS tools into each segment (see `test/fixtures/README.md` for which samples are real captures), and feed sample `config.toml` files into the config editor.

## License

MIT
