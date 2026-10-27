#!/usr/bin/env bash
# MCCVR Steam Play integration. Preserve Steam's runtime/proton command and
# replace only the confirmed MCC bootstrap executable. Single-player/mods only.
set -u
# The log includes local paths and command arguments; protect newly created files.
umask 077
VERSION=1.1.0
if [[ ${1-} == --version ]]; then printf 'mccvr-steam-play %s\n' "$VERSION"; exit 0; fi
log="${XDG_STATE_HOME:-$HOME/.local/state}/mccvr-steam-play.log"
mkdir -p "$(dirname "$log")" || exit 1
exec >>"$log" 2>&1
printf '\n=== mccvr-steam-play %s %s ===\n' "$VERSION" "$(date -Is)"
args=("$@")
match=-1
for i in "${!args[@]}"; do
  case "${args[i]}" in
    */mcclauncher.exe|*/MCC/Binaries/Win64/MCC-Win64-Shipping.exe)
      if (( match >= 0 )); then echo 'ERROR: multiple MCC executable arguments; refusing to guess'; exit 1; fi
      match=$i ;;
  esac
done
if (( match < 0 )); then
  echo 'ERROR: no recognized MCC executable in Steam command; refusing to start an unmodded game.'
  for i in "${!args[@]}"; do printf 'argv[%s]=%q\n' "$i" "${args[i]}"; done
  exit 1
fi
case "${args[match]}" in
  */mcclauncher.exe)
    (( match == ${#args[@]}-1 )) || { echo 'ERROR: unexpected bootstrap arguments'; exit 1; }
    root=${args[match]%/*} ;;
  */MCC/Binaries/Win64/MCC-Win64-Shipping.exe)
    # Steam's explicit anti-cheat-disabled choice. The VR launcher supplies its
    # own game arguments, so consume -no-eac rather than pass it to its UI.
    (( match == ${#args[@]}-2 )) && [[ ${args[match+1]} == -no-eac ]] || {
      echo 'ERROR: shipping executable must be followed only by -no-eac'; exit 1; }
    root=${args[match]%/MCC/Binaries/Win64/MCC-Win64-Shipping.exe}
    unset 'args[match+1]' ;;
esac
launcher="$root/Halo_MCC_VR/HaloMCCVRLauncher.exe"
if [[ ! -f "$launcher" ]]; then printf 'ERROR: mod launcher missing: %s\n' "$launcher"; exit 1; fi
if [[ ! -f "$root/Halo_MCC_VR/HaloMCCVR.dll" ]]; then echo 'ERROR: HaloMCCVR.dll missing from Halo_MCC_VR'; exit 1; fi
args[match]="$launcher"
export PROTON_USE_WINED3D=0
export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-d3d11=n;d3d10core=n;d3d9=n;dxgi=n}"
printf 'launcher=%s\nsha256=' "$launcher"
sha256sum "$launcher"
printf 'SteamAppId=%s SteamGameId=%s\n' "${SteamAppId-}" "${SteamGameId-}"
printf 'Command:'; printf ' %q' "${args[@]}"; printf '\n'
printf 'Starting Steam runtime chain; launcher should offer Launch MCC (anti-cheat disabled).\n'
exec "${args[@]}"
