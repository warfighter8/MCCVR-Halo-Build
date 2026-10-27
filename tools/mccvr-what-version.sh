#!/usr/bin/env bash
# mccvr-what-version.sh 1.0.0 - identify the installed MCCVR payload by hash.
# Reference hashes taken from the published release ZIPs, each verified against
# the SHA-256 values in that release's own SHA256.txt.
set -u
if [[ ${1-} == --version ]]; then echo 'mccvr-what-version 1.0.0'; exit 0; fi

MOD="${MCCVR_DIR:-$HOME/.steam/steam/steamapps/common/Halo The Master Chief Collection/Halo_MCC_VR}"
if [[ ! -d $MOD ]]; then
  echo "FAIL: no mod folder at: $MOD"
  echo "      set MCCVR_DIR=/path/to/Halo_MCC_VR and run again."
  exit 1
fi

sha() { [[ -f $1 ]] && sha256sum "$1" | cut -d' ' -f1 | tr 'a-f' 'A-F' || echo MISSING; }

dll=$(sha "$MOD/HaloMCCVR.dll")
exe=$(sha "$MOD/HaloMCCVRLauncher.exe")

identify() { # $1=hash $2=kind
  case "$2:$1" in
    dll:18D4F4AB94FA8065718AF43E36020BAE989259007A4C079CF69AA94EFB72AB69) echo 'Alpha 0.5.1 (published release)';;
    dll:8B6FFB78884420588432DA19A5348F330689F201094660729FA8B9AB72C58F60) echo 'Alpha 0.4.2 (published release)';;
    exe:35D5286506515000D39312F0E24D8A509C9637CD591E8ABA4CD07A6AFCEDD79C) echo 'Alpha 0.5.1 launcher (upstream)';;
    exe:095463D4F9CFC7FED181E852F71F0A87C644CC185DAEC66C73BE22F3F2A67C48) echo 'Alpha 0.4.2 launcher (upstream)';;
    exe:F63B76C59E624D5F366E8E740CC4EAB1F10543BE9A9986447426E65BD4838B37) echo 'Proton-fix test launcher (this fork, b9333b7/f7d4570)';;
    *) : ;;
  esac
}

dll_id=$(identify "$dll" dll)
exe_id=$(identify "$exe" exe)

echo "folder : $MOD"
echo "DLL    : $dll"
echo "         $( [[ -n $dll_id ]] && echo "= $dll_id" || echo 'unrecognized (not a published release payload)' )"
echo "launcher: $exe"
echo "         $( [[ -n $exe_id ]] && echo "= $exe_id" || echo 'unrecognized (not a published release or this fork'"'"'s test build)' )"

if [[ -f $MOD/HaloMCCVR.log ]]; then
  echo
  echo "last run (from HaloMCCVR.log):"
  sed -n '1,2p' "$MOD/HaloMCCVR.log" | sed 's/^/  /'
  echo "  (the source commit above is the DLL that actually loaded; it can lag"
  echo "   what is on disk now if you replaced files after that run)"
fi

echo
case "$dll_id" in
  'Alpha 0.5.1'*)  echo 'VERDICT: installed payload matches published 0.5.1.'; exit 0 ;;
  'Alpha 0.4.2'*)  echo 'VERDICT: installed payload matches published 0.4.2 (accepted baseline), not 0.5.1.'; exit 0 ;;
  *)               echo 'VERDICT: payload is NOT a published 0.4.2 or 0.5.1 DLL.'; exit 2 ;;
esac
