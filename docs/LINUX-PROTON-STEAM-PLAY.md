# Steam Play-button launch on Linux / Proton (experimental)

This source branch provides a Proton-aware Steam-process check in the Windows
launcher and `tools/mccvr-steam-play.sh`, which redirects Steam's Play command
to that launcher while preserving Steam's selected Proton/runtime chain. This is
an experiment, not a claim of full Linux support. One user reported a successful
Steam Play launch on Bazzite with Proton Experimental; other versions, headsets,
and Steam command shapes need further testing. Windows and Store paths were not
runtime-tested as part of this change.

**Prerequisite: a launcher built from this branch (or a future release explicitly
containing its Proton fix).** Existing published release ZIPs are not rebuilt by
checking out this source, and do not contain this branch's changes. Build the
launcher from the source with the documented Windows/MSVC build in `BUILDING.md`,
or use a separately provided compatible test build. Back up the existing
`Halo_MCC_VR/HaloMCCVRLauncher.exe` before replacing it. Do not assume the flat
ZIP's older launcher includes this fix.

1. With MCC closed, install the mod payload into `Halo_MCC_VR` directly under the
   MCC installation root, preserving its subfolders. Put the compatible launcher
   beside `HaloMCCVR.dll` there. Keep the old launcher for rollback.
2. Copy `tools/mccvr-steam-play.sh` from this source checkout to a stable path,
   for example:

   ```bash
   mkdir -p "$HOME/.local/bin"
   cp tools/mccvr-steam-play.sh "$HOME/.local/bin/mccvr-steam-play.sh"
   bash "$HOME/.local/bin/mccvr-steam-play.sh" --version
   ```

   Run these commands from the source checkout. Existing release archives do not
   currently include the wrapper; copy it from the source branch instead.
3. In Steam's MCC Properties > Launch Options, save your existing value and use
   the absolute path to that script, substituting your Linux username:

   ```text
   /bin/bash /home/YOUR_USERNAME/.local/bin/mccvr-steam-play.sh %command%
   ```

   Use your actual absolute path: Steam does not expand `~` in this field. Quote
   the script path if it contains spaces. Select a Proton version in Steam's
   Compatibility settings and start SteamVR with your headset connected.
4. Press Play. If Steam asks which MCC mode to run, select the
   **anti-cheat-disabled** option. When the VR launcher opens, select **Launch
   MCC**. The wrapper runs automatically; no terminal command is needed per
   launch. Use the mod only with anti-cheat disabled, in single-player—not
   matchmaking.

The wrapper recognizes Steam's `mcclauncher.exe` command and its shipping
executable followed by `-no-eac`. It substitutes the mod launcher, requires the
mod DLL to exist, and fails closed for unknown command shapes rather than
silently starting an unmodded game. It sets `PROTON_USE_WINED3D=0`, requests
OpenXR runtime import, and supplies DXVK overrides if no `WINEDLLOVERRIDES` was
already set. Existing user-provided overrides are preserved.

## Troubleshooting and rollback

The wrapper logs to `~/.local/state/mccvr-steam-play.log` (or
`$XDG_STATE_HOME/mccvr-steam-play.log`). The launcher and mod write
`HaloMCCVRLauncher.log` and `HaloMCCVR.log` inside `Halo_MCC_VR`. The wrapper
logs the selected executable's SHA-256 to help identify stale builds. A launcher
update/install can replace that executable. The log can contain local paths and
command arguments; new logs are created private, but existing log permissions
are not changed. Review its contents before sharing it.

A successful launch does not establish compatibility with all Proton versions
or Steam runtimes. If the wrapper reports an unknown command or missing file,
stop and inspect the log; do not force through it. To restore normal MCC, remove
the wrapper from Steam Launch Options or restore the saved original value. To
roll back the launcher, close MCC and restore the backed-up executable.

Developer mechanical checks (Linux): `bash -n tools/mccvr-steam-play.sh` and
`python3 tests/steam_play_wrapper_test.py`. These use synthetic files and a fake
runtime; they do not launch Steam, MCC, or a headset.
