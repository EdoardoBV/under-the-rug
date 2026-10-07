#!/bin/zsh
# Универсальная сборка с ad-hoc подписью и zip для GitHub Releases.
set -e
cd "$(dirname "$0")"
RUG_SIGN=- ./build.sh universal
mkdir -p dist
rm -f dist/Rug.zip
ditto -c -k --keepParent build/Rug.app dist/Rug.zip
ls -lh dist/Rug.zip
