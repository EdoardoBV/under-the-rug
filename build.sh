#!/bin/zsh
# Сборка Rug.app без Xcode, хватает Command Line Tools (xcode-select --install).
#   ./build.sh            для своей машины (arm64 или x86_64)
#   ./build.sh universal  для Apple Silicon и Intel сразу
set -e
cd "$(dirname "$0")"
APP=build/Rug.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
FLAGS=(-O -swift-version 5 -framework AppKit -framework SwiftUI -framework Metal -framework MetalKit
       -framework QuartzCore -framework ApplicationServices)
if [[ "$1" == "universal" ]]; then
  swiftc $FLAGS -target arm64-apple-macos14.0 Sources/*.swift -o build/Rug-arm64
  swiftc $FLAGS -target x86_64-apple-macos14.0 Sources/*.swift -o build/Rug-x86_64
  lipo -create build/Rug-arm64 build/Rug-x86_64 -output $APP/Contents/MacOS/Rug
  rm build/Rug-arm64 build/Rug-x86_64
else
  swiftc $FLAGS -target $(uname -m)-apple-macos14.0 Sources/*.swift -o $APP/Contents/MacOS/Rug
fi
cp Info.plist $APP/Contents/Info.plist
cp Resources/AppIcon.icns $APP/Contents/Resources/
cp -R Resources/rugs Resources/floors Localization/*.lproj $APP/Contents/Resources/
# Подпись. RUG_SIGN задает сертификат, по умолчанию ad-hoc.
# С постоянным сертификатом macOS не спрашивает разрешения заново после каждой пересборки.
codesign --force --sign "${RUG_SIGN:--}" $APP
echo "built $APP"
