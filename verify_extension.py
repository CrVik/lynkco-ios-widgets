"""Validate the compiled artifact before it is joined to the local IPA."""
from pathlib import Path
import hashlib
import json
import plistlib
import struct
import sys

root = Path(sys.argv[1]).resolve()
info = plistlib.loads((root / 'Info.plist').read_bytes())
assert info['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension'
name = info['CFBundleExecutable']
assert Path(name).name == name
data = (root / name).read_bytes()
magic, cpu, subtype, kind, commands, size, flags, reserved = struct.unpack_from('<8I', data)
assert magic == 0xFEEDFACF and cpu == 0x0100000C and kind == 2
position = 32
platforms, cryptids = [], []
for _ in range(commands):
    command, length = struct.unpack_from('<II', data, position)
    assert length >= 8 and position + length <= 32 + size
    if command == 0x32:
        platforms.append(struct.unpack_from('<I', data, position + 8)[0])
    if command == 0x2C:
        cryptids.append(struct.unpack_from('<I', data, position + 16)[0])
    position += length
assert position == 32 + size and 2 in platforms and not any(cryptids)
files = []
for path in sorted(root.rglob('*')):
    if path.is_file():
        blob = path.read_bytes()
        files.append({'file': str(path.relative_to(root)), 'bytes': len(blob), 'sha256': hashlib.sha256(blob).hexdigest()})
manifest = {'architecture': 'arm64', 'platform': 'iOS', 'encrypted': False,
            'bundle_id': info['CFBundleIdentifier'], 'unsigned_for_local_IPA_integration': True, 'files': files}
(root.parent / 'extension-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps(manifest, indent=2))
