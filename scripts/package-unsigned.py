"""Package a device .app for later local signing; this does not sign or install it."""
import argparse
import plistlib
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('app', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
app = args.app.resolve()
if not app.is_dir() or app.suffix != '.app':
    parser.error('Input must be an existing .app directory')
info = plistlib.loads((app / 'Info.plist').read_bytes())
if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
    parser.error('Only device iPhoneOS builds can be packaged, not simulator builds')
if not (app / info['CFBundleExecutable']).is_file():
    parser.error('App executable is missing')
if args.output.suffix != '.ipa':
    parser.error('Output must have .ipa extension')
args.output.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(args.output, 'w', compression=ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob('*')):
        if file.is_symlink():
            parser.error('Unexpected symlink in application')
        if file.is_file():
            archive.write(file, 'Payload/' + app.name + '/' + file.relative_to(app).as_posix())
print(f'Packaged {args.output}; UNSIGNED, requires local signing before installation.')
