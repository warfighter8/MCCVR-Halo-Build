#!/usr/bin/env python3
"""Offline tests for tools/mccvr-update.sh and tools/mccvr-what-version.sh.

Uses a synthetic archive and fake mod folder, with the expected hashes injected
through the environment, so no network, Steam, MCC or headset is involved.
"""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
UPDATE = ROOT / 'tools' / 'mccvr-update.sh'
IDENTIFY = ROOT / 'tools' / 'mccvr-what-version.sh'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def run(script, env, *args):
    return subprocess.run(['bash', str(script), *args], env=env,
                          text=True, capture_output=True, check=False)


def make_archive(base, dll_bytes, cfg_text, name='release.zip'):
    archive = base / name
    with zipfile.ZipFile(archive, 'w') as zf:
        zf.writestr('HaloMCCVR.dll', dll_bytes)
        zf.writestr('halomccvr.cfg', cfg_text)
        zf.writestr('README.txt', 'payload')
    return archive


def env_for(home, archive, dll_bytes):
    return {
        'PATH': os.environ['PATH'],
        'HOME': str(home),
        'MCCVR_DIR': str(home / 'Halo_MCC_VR'),
        'ZIP': str(archive),
        'TARGET': '9.9.9',
        'ZIP_SHA_EXPECTED': sha(archive),
        'DLL_SHA_EXPECTED': hashlib.sha256(dll_bytes).hexdigest().upper(),
    }


def main():
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        mod = home / 'Halo_MCC_VR'
        mod.mkdir()
        old_dll = b'old mod payload'
        new_dll = b'new mod payload v2'
        (mod / 'HaloMCCVR.dll').write_bytes(old_dll)
        (mod / 'HaloMCCVRLauncher.exe').write_bytes(b'patched launcher')
        (mod / 'halomccvr.cfg').write_text('screen = 4.00\n')
        archive = make_archive(home, new_dll, 'screen = 4.00\nnew_option = 1\n')
        env = env_for(home, archive, new_dll)

        r = run(UPDATE, env)
        assert r.returncode == 0 and 'DRY RUN' in r.stdout, r.stdout + r.stderr
        assert (mod / 'HaloMCCVR.dll').read_bytes() == old_dll, 'dry run must not write'

        r = run(UPDATE, env, '--apply')
        assert r.returncode == 0, r.stdout + r.stderr
        assert (mod / 'HaloMCCVR.dll').read_bytes() == new_dll, r.stdout
        assert (mod / 'HaloMCCVRLauncher.exe').read_bytes() == b'patched launcher', 'launcher must be kept'
        assert (mod / 'halomccvr.cfg').read_text() == 'screen = 4.00\n', 'user config must be kept'
        assert (mod / 'halomccvr.cfg.9.9.9.new').read_text().startswith('screen = 4.00'), 'reference config'
        backups = list((home / 'mccvr-backups').glob('*-before-9.9.9'))
        assert len(backups) == 1, backups
        assert (backups[0] / 'HaloMCCVR.dll').read_bytes() == old_dll
        assert (backups[0] / 'halomccvr.cfg').exists()

        r = run(UPDATE, env, '--apply')
        assert r.returncode == 0 and 'nothing to do' in r.stdout, r.stdout

        # A corrupted archive must be refused and leave the DLL alone.
        (mod / 'HaloMCCVR.dll').write_bytes(old_dll)
        bad = home / 'bad.zip'
        bad.write_bytes(b'not the release')
        bad_env = dict(env, ZIP=str(bad))
        r = run(UPDATE, bad_env, '--apply')
        assert r.returncode != 0 and 'archive hash mismatch' in (r.stdout + r.stderr), r.stdout
        assert (mod / 'HaloMCCVR.dll').read_bytes() == old_dll

        # Unknown target without explicit hashes must fail before doing anything.
        bare = {'PATH': os.environ['PATH'], 'HOME': str(home), 'MCCVR_DIR': str(mod),
                'TARGET': 'nope'}
        r = run(UPDATE, bare, '--apply')
        assert r.returncode == 64 and 'unknown TARGET' in (r.stdout + r.stderr), r.stdout

        print('PASS: dry run, apply, keeps launcher and config, backup, idempotent re-run')
        print('PASS: corrupt archive and unknown target fail closed')

    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        mod = home / 'Halo_MCC_VR'
        mod.mkdir()
        (mod / 'HaloMCCVR.dll').write_bytes(b'unknown payload')
        (mod / 'HaloMCCVRLauncher.exe').write_bytes(b'unknown launcher')
        (mod / 'HaloMCCVR.log').write_text('[00:00:00.000] HaloMCCVR loaded (source deadbeef)\n')
        env = {'PATH': os.environ['PATH'], 'HOME': str(home), 'MCCVR_DIR': str(mod)}
        r = run(IDENTIFY, env)
        assert r.returncode == 2, (r.returncode, r.stdout)
        assert 'unrecognized' in r.stdout and 'VERDICT: payload is NOT' in r.stdout, r.stdout
        assert 'source deadbeef' in r.stdout, 'should echo the last-run source line'

        r = run(IDENTIFY, dict(env, MCCVR_DIR=str(home / 'missing')))
        assert r.returncode == 1 and 'no mod folder' in r.stdout, r.stdout
        print('PASS: identifier rejects unknown hashes and a missing folder')


if __name__ == '__main__':
    main()
