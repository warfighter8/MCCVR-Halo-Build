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

## Reportedly working combination

One report (Bazzite, GE-Proton and Proton Experimental, SteamVR/OpenXR, Steam
edition) launched MCC from the Play button with this combination:

| Part | Version | Hash |
|---|---|---|
| `HaloMCCVR.dll` | Alpha 0.4.2, then Alpha 0.5.1 | `8B6FFB78…` then `18D4F4AB…` |
| `HaloMCCVRLauncher.exe` | build with the Proton Steam-context fix | `F63B76C5…` |
| Launch | Steam Play button via `tools/mccvr-steam-play.sh` | — |

That is a **mixed pairing**: the payload comes from a published release while the
launcher comes from this branch. It worked on that system for both payloads, but
it is a single report, not a guarantee for other Proton versions, runtimes or
headsets. Windows and Microsoft Store behavior was not runtime-tested here.

## Keeping the fix across mod updates

An update replaces `HaloMCCVRLauncher.exe`, so re-apply the working launcher
afterwards; do not rebuild one from a new tag and assume it behaves the same.
`tools/mccvr-update.sh` does the narrow version of this — it swaps **only** the
DLL, after verifying the release archive and the DLL inside it, and leaves the
launcher and your `halomccvr.cfg` untouched:

```bash
bash tools/mccvr-update.sh            # dry run: verify and report, change nothing
bash tools/mccvr-update.sh --apply    # back up, then replace the DLL
```

It refuses to run while MCC is loaded, writes the new DLL beside the target and
renames it into place, keeps the previous DLL/launcher/config under
`~/mccvr-backups/<timestamp>-before-<version>/`, and prints the rollback
commands with the real backup path. The release's own config is saved as
`halomccvr.cfg.<version>.new` for comparison; your settings are not overwritten.
Add a release with `TARGET=<version>`, providing `ZIP_SHA_EXPECTED` and
`DLL_SHA_EXPECTED` for versions without a built-in hash.

`tools/mccvr-what-version.sh` identifies what is installed by hash:

```bash
bash tools/mccvr-what-version.sh
```

It names a published release when the DLL matches one, reports the launcher
separately, echoes the source commit from the most recent `HaloMCCVR.log` line,
and exits `0` for a recognized payload, `2` for an unrecognized one, `1` when no
mod folder is found (`MCCVR_DIR=/path/to/Halo_MCC_VR` overrides the location).


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

Developer mechanical checks (Linux): `bash -n tools/mccvr-steam-play.sh`,
`python3 tests/steam_play_wrapper_test.py` and `python3 tests/mccvr_tools_test.py`.
These use synthetic files and a fake runtime; they do not launch Steam, MCC, or a
headset.
