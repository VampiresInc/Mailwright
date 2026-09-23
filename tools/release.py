"""Build client-specific release assets without modifying public source files."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from package import ROOT, FILES

parser = argparse.ArgumentParser()
parser.add_argument('--tag', required=True)
args = parser.parse_args()
version = args.tag.removeprefix('v')
# Select by the exact manifest version so a stable tag never includes beta assets.
matches = []
for flavor, manifest, suffix in [('mainline', 'Mainline', ''), ('forever', 'Camelot', '-forever')]:
    declared = re.search(r'^## Version: (.+)$', (ROOT / f'Mailwright_{manifest}.toc').read_text(), re.M).group(1)
    if declared == version:
        matches.append((flavor, manifest, suffix))
if not args.tag.startswith('v') or len(matches) != 1:
    raise SystemExit('Tag must match exactly one client manifest version')
output = ROOT / 'dist' / 'release' / args.tag
output.mkdir(parents=True, exist_ok=True)
metadata = []
for flavor, manifest, suffix in matches:
    toc = (ROOT / f'Mailwright_{manifest}.toc').read_bytes()
    entries = {f'Mailwright/{name}': (ROOT / name).read_bytes() for name in FILES}
    core = entries['Mailwright/Core.lua'].decode()
    core, count = re.subn(r'(M.addon, M.version = addon, ")[^"]+(" )?', lambda m: m.group(1) + version, core, count=1)
    assert count == 1
    entries['Mailwright/Core.lua'] = core.encode()
    # A generic fallback for each client; Forever may select Mainline in beta.
    entries['Mailwright/Mailwright.toc'] = toc
    entries[f'Mailwright/Mailwright_{manifest}.toc'] = toc
    if flavor == 'forever':
        entries['Mailwright/Mailwright_Mainline.toc'] = toc
    filename = f'Mailwright-{version}{suffix}.zip'
    with zipfile.ZipFile(output / filename, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, data in entries.items():
            archive.writestr(name, data)
    with zipfile.ZipFile(output / filename) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == set(entries)
        for name, data in entries.items():
            assert archive.read(name) == data
        for name in entries:
            if name.endswith('.toc'):
                for line in entries[name].decode().splitlines():
                    if line.strip() and not line.startswith('#'):
                        assert 'Mailwright/' + line.strip() in entries
    interface = int(re.search(rb'## Interface: (\d+)', toc).group(1))
    metadata.append({'filename': filename, 'nolib': False, 'metadata': [{'flavor': flavor, 'interface': interface}]})
    print(f'Verified {filename}: {len(entries)} files, SHA256 {hashlib.sha256((output / filename).read_bytes()).hexdigest()}')
(output / 'release.json').write_text(json.dumps({'releases': metadata}, indent=2) + '\n')
