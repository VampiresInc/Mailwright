"""Package only the independently implemented Mailwright addon."""
from pathlib import Path
import hashlib
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'dist'
FILES = ['Core.lua', 'API.lua', 'Contacts.lua', 'Mailbox.lua', 'Sending.lua',
         'UI.lua', 'MailboxUI.lua', 'FlavorForever.lua', 'LICENSE', 'README.md', 'TESTING.md']

def package_files():
    paths = [ROOT / name for name in FILES] + sorted(ROOT.glob('Mailwright*.toc'))
    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(path)
    return paths

def build():
    version = re.search(r'^## Version: (.+)$', (ROOT / 'Mailwright.toc').read_text(), re.M).group(1)
    DIST.mkdir(exist_ok=True)
    output = DIST / f'Mailwright-{version}.zip'
    paths = package_files()
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in paths:
            archive.write(path, 'Mailwright/' + path.name)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(paths)
        for path in paths:
            assert hashlib.sha256(archive.read('Mailwright/' + path.name)).digest() == hashlib.sha256(path.read_bytes()).digest()
    print(f'Verified {len(paths)} files: {output}')
    return output

if __name__ == '__main__':
    build()
