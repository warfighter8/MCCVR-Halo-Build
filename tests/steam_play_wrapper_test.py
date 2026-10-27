#!/usr/bin/env python3
"""Offline argument/lifecycle tests; no Steam or real MCC installation required."""
import os
from pathlib import Path
import subprocess
import tempfile

SCRIPT = Path(__file__).resolve().parents[1] / 'tools' / 'mccvr-steam-play.sh'


def main():
    with tempfile.TemporaryDirectory() as tmp:
        base = Path(tmp)
        root = base / 'Halo The Master Chief Collection'
        mod = root / 'Halo_MCC_VR'
        mod.mkdir(parents=True)
        (mod / 'HaloMCCVRLauncher.exe').touch()
        (mod / 'HaloMCCVR.dll').touch()
        capture = base / 'captured'
        stub = base / 'steam-launch-wrapper'
        stub.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$CAPTURE"\nprintf "%s\\n" "$PROTON_USE_WINED3D" "$PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES" "$WINEDLLOVERRIDES" > "$CAPTURE.env"\nexit 23\n')
        stub.chmod(0o755)
        env = dict(os.environ, HOME=str(base), XDG_STATE_HOME=str(base / 'state'), CAPTURE=str(capture))
        env.pop('WINEDLLOVERRIDES', None)
        prefix = [str(stub), '--', '/steam/reaper', 'SteamLaunch', 'AppId=976730', '--',
                  '/steam/SteamLinuxRuntime_4/_v2-entry-point', '--verb=waitforexitandrun', '--',
                  '/steam/Proton - Experimental/proton', 'waitforexitandrun']
        launcher = str(mod / 'HaloMCCVRLauncher.exe')
        shipping = str(root / 'MCC/Binaries/Win64/MCC-Win64-Shipping.exe')
        bootstrap = str(root / 'mcclauncher.exe')

        def invoke(tail):
            capture.unlink(missing_ok=True)
            return subprocess.run(['bash', str(SCRIPT), *prefix, *tail], env=env, check=False).returncode

        for tail in ([bootstrap], [shipping, '-no-eac']):
            assert invoke(tail) == 23
            assert capture.read_text().splitlines() == prefix[1:] + [launcher]
            assert Path(str(capture) + '.env').read_text().splitlines() == [
                '0', '1', 'd3d11=n;d3d10core=n;d3d9=n;dxgi=n']
        for tail in ([shipping], [shipping, '-other'], ['/unknown.exe'],
                     [bootstrap, '--unexpected'], [bootstrap, shipping, '-no-eac']):
            assert invoke(tail) != 0 and not capture.exists(), tail
        log = base / 'state/mccvr-steam-play.log'
        assert (log.stat().st_mode & 0o077) == 0, 'new log must be private'
        env['WINEDLLOVERRIDES'] = 'custom=n,b'
        assert invoke([bootstrap]) == 23
        assert Path(str(capture) + '.env').read_text().splitlines()[-1] == 'custom=n,b'
        env.pop('WINEDLLOVERRIDES')
        (mod / 'HaloMCCVRLauncher.exe').unlink()
        assert invoke([bootstrap]) != 0 and not capture.exists()
        (mod / 'HaloMCCVRLauncher.exe').touch()
        (mod / 'HaloMCCVR.dll').unlink()
        assert invoke([bootstrap]) != 0 and not capture.exists()
        print('PASS: 2 launch shapes, override preservation, and 7 fail-closed cases; synthetic runtime only')


if __name__ == '__main__':
    main()
