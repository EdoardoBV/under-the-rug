#!/bin/zsh
# Универсальная сборка с ad-hoc подписью и zip для GitHub Releases.
# Расширенные атрибуты macOS (provenance и прочие) в архив не попадают.
set -e
cd "$(dirname "$0")"
RUG_SIGN=- ./build.sh universal
xattr -cr build/Rug.app
codesign --verify --deep build/Rug.app
mkdir -p dist
rm -f dist/Rug.zip
ditto -c -k --norsrc --noextattr --noacl --keepParent build/Rug.app dist/Rug.zip
ls -lh dist/Rug.zip
