#!/usr/bin/env bash
# mccvr-update.sh 1.1.0 - swap the MCCVR payload DLL to a published release while
# keeping the Proton-aware launcher and your existing settings.
#
# Default target is Alpha 0.5.1. Runs a dry-run unless --apply is given.
# Preserves the previous DLL, launcher and config in a timestamped backup folder.
set -u
umask 077
VERSION=1.1.0
TARGET=${TARGET:-0.5.1}

# Known published releases: archive hash, then the DLL hash inside that archive.
# The DLL hash is not in the release's SHA256.txt for these builds, so it was taken
# from the archive after the archive itself matched its published value.
case "$TARGET" in
  0.5.1)
    ZIP_SHA_EXPECTED=${ZIP_SHA_EXPECTED:-F262D7638C5AF1CEAB1E57A2646EEC8A07E3EFCDF0598FBCF95B85E462441E45}
    DLL_SHA_EXPECTED=${DLL_SHA_EXPECTED:-18D4F4AB94FA8065718AF43E36020BAE989259007A4C079CF69AA94EFB72AB69} ;;
  0.4.2)
    ZIP_SHA_EXPECTED=${ZIP_SHA_EXPECTED:-8DC79C7A5A9E3FC565EB525994208D9D477DA6D57DF869301F6907ED0CB03565}
    DLL_SHA_EXPECTED=${DLL_SHA_EXPECTED:-8B6FFB78884420588432DA19A5348F330689F201094660729FA8B9AB72C58F60} ;;
  *)
    ZIP_SHA_EXPECTED=${ZIP_SHA_EXPECTED:-}
    DLL_SHA_EXPECTED=${DLL_SHA_EXPECTED:-}
    [[ -n $ZIP_SHA_EXPECTED && -n $DLL_SHA_EXPECTED ]] || {
      echo "ERROR: unknown TARGET '$TARGET'; set ZIP_SHA_EXPECTED and DLL_SHA_EXPECTED explicitly" >&2
      exit 64; } ;;
esac
ZIP_URL_DEFAULT=${ZIP_URL_DEFAULT:-https://github.com/moistman42069/MCCVR-Halo-Build/releases/download/MCC_VR_ALPHA_${TARGET}/Halo-MCC-VR.zip}

applied=0
for a in "$@"; do
  case $a in
    --apply) applied=1 ;;
    --version) printf 'mccvr-update %s\n' "$VERSION"; exit 0 ;;
    -h|--help) echo "usage: $0 [--apply]   (TARGET=$TARGET, MCCVR_DIR=..., ZIP=...)"; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 64 ;;
  esac
done

MOD=${MCCVR_DIR:-$HOME/.steam/steam/steamapps/common/Halo The Master Chief Collection/Halo_MCC_VR}
say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
sha() { sha256sum "$1" | cut -d' ' -f1 | tr 'a-f' 'A-F'; }

[[ -d $MOD ]] || die "no mod folder at: $MOD (set MCCVR_DIR)"
[[ -f $MOD/HaloMCCVR.dll ]] || die "no HaloMCCVR.dll in $MOD"
[[ -f $MOD/HaloMCCVRLauncher.exe ]] || die "no HaloMCCVRLauncher.exe in $MOD"

dll_now=$(sha "$MOD/HaloMCCVR.dll")
lch_now=$(sha "$MOD/HaloMCCVRLauncher.exe")

say "mod folder : $MOD"
say "current DLL: $dll_now"
say "launcher   : $lch_now"
say "target     : Alpha $TARGET (DLL $DLL_SHA_EXPECTED)"

if pgrep -f 'MCC-Win64-Shipping.exe' >/dev/null 2>&1; then
  die "MCC is running - close it first (the DLL cannot be replaced while loaded)"
fi

if [[ $dll_now == "$DLL_SHA_EXPECTED" ]]; then
  say "nothing to do: the installed DLL is already Alpha $TARGET."
  exit 0
fi

# --- obtain and verify the payload -----------------------------------------
zip=${ZIP:-}
cleanup=0
if [[ -z $zip ]]; then
  zip=$(mktemp -d)/Halo-MCC-VR-$TARGET.zip
  cleanup=1
  say ""
  say "downloading $ZIP_URL_DEFAULT"
  curl -fL --retry 3 -o "$zip" "$ZIP_URL_DEFAULT" || die "download failed: $ZIP_URL_DEFAULT"
fi
[[ -f $zip ]] || die "no such archive: $zip"
zip_now=$(sha "$zip")
say "archive    : $zip ($zip_now)"
[[ $zip_now == "$ZIP_SHA_EXPECTED" ]] || die "archive hash mismatch - refusing to install
  got  $zip_now
  want $ZIP_SHA_EXPECTED"

work=$(mktemp -d)
trap 'rm -rf "$work"; [[ $cleanup == 1 ]] && rm -rf "$(dirname "$zip")"' EXIT
python3 - "$zip" "$work" <<'PY' || die "could not extract the archive"
import sys, zipfile, pathlib
zf = zipfile.ZipFile(sys.argv[1])
names = zf.namelist()
if any(n.startswith(('/','..')) or '..' in pathlib.PurePosixPath(n).parts for n in names):
    raise SystemExit('unsafe paths in archive')
zf.extractall(sys.argv[2])
PY
new_dll=""
for cand in "$work/HaloMCCVR.dll" "$work/ModFiles/HaloMCCVR.dll"; do
  [[ -f $cand ]] && new_dll=$cand && break
done
[[ -n $new_dll ]] || die "no HaloMCCVR.dll inside the archive"
got_dll=$(sha "$new_dll")
[[ $got_dll == "$DLL_SHA_EXPECTED" ]] || die "archive DLL hash mismatch - refusing to install
  got  $got_dll
  want $DLL_SHA_EXPECTED"
say "payload DLL: $got_dll (matches the published $TARGET build)"

new_cfg=""
for cand in "$work/halomccvr.cfg" "$work/ModFiles/halomccvr.cfg"; do
  [[ -f $cand ]] && new_cfg=$cand && break
done

if [[ $applied == 0 ]]; then
  say ""
  say "DRY RUN - nothing changed. Re-run with --apply to:"
  say "  1. back up HaloMCCVR.dll, HaloMCCVRLauncher.exe and halomccvr.cfg"
  say "  2. replace only the DLL with the $TARGET payload"
  say "  3. keep your existing halomccvr.cfg and the Proton-fix launcher"
  [[ -n $new_cfg ]] && say "  4. save the release's own config as halomccvr.cfg.$TARGET.new for reference"
  exit 0
fi

# --- apply -------------------------------------------------------------------
backup="$HOME/mccvr-backups/$(date +%Y%m%d-%H%M%S)-before-$TARGET"
mkdir -p "$backup" || die "could not create $backup"
cp -p "$MOD/HaloMCCVR.dll" "$MOD/HaloMCCVRLauncher.exe" "$backup/"
[[ -f $MOD/halomccvr.cfg ]] && cp -p "$MOD/halomccvr.cfg" "$backup/"
say ""
say "backup     : $backup"

# Write beside the target, verify, then rename: no half-written DLL is ever live.
tmp_dll="$MOD/.HaloMCCVR.dll.new"
cp -f "$new_dll" "$tmp_dll" || die "could not stage the new DLL"
[[ $(sha "$tmp_dll") == "$DLL_SHA_EXPECTED" ]] || { rm -f "$tmp_dll"; die "staged DLL hash mismatch"; }
mv -f "$tmp_dll" "$MOD/HaloMCCVR.dll" || die "could not replace the DLL"

if [[ -n $new_cfg ]]; then
  cp -f "$new_cfg" "$MOD/halomccvr.cfg.$TARGET.new" || say "WARNING: could not save the reference config"
fi

final_dll=$(sha "$MOD/HaloMCCVR.dll")
final_lch=$(sha "$MOD/HaloMCCVRLauncher.exe")
say ""
say "installed DLL     : $final_dll"
say "launcher (kept)   : $final_lch"
[[ $final_dll == "$DLL_SHA_EXPECTED" ]] || die "post-install DLL hash mismatch: $final_dll"
say ""
say "VERDICT: DLL is now Alpha $TARGET; launcher unchanged."
say "Settings file kept as-is. If F1 shows missing new options, compare with"
say "  $MOD/halomccvr.cfg.$TARGET.new"
say "Rollback:"
say "  cp -p '$backup/HaloMCCVR.dll' '$MOD/'"
say "  cp -p '$backup/HaloMCCVRLauncher.exe' '$MOD/'"
say "Then launch from Steam as usual (Play button, anti-cheat-disabled, single-player)."
