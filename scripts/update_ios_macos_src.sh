# This script copies the source files from the src directory to the ios and macos directories.
# Should be run every time the src directory files are updated.

srcPath="../src" 
zxingPath="$srcPath/zxing/core/src"
iosSrcPath="../ios/Classes/src"
macosSrcPath="../macos/Classes/src"

# Remove the source files if they exist
rm -rf $iosSrcPath
rm -rf $macosSrcPath

# create the source directories
mkdir -p $iosSrcPath
mkdir -p $macosSrcPath

# Copy the source files
rsync -av --exclude '*.txt' --exclude "zxing/" "$srcPath/" "$iosSrcPath/" 
rsync -av "$zxingPath/" "$iosSrcPath/zxing/"

rsync -av --exclude '*.txt' --exclude "zxing/" "$srcPath/" "$macosSrcPath/" 
rsync -av "$zxingPath/" "$macosSrcPath/zxing/"
