# Define the project name (the same as name: in the pubspec.yaml file)
Set-Variable project "flutter_zxing"

# Define the versions to download
Set-Variable zxing_version "1.4.0"

# Define the paths to the directories where the files will be installed
Set-Variable projectPath "../../$project"
Set-Variable zxingPath "$projectPath/ios/Classes/src/zxing"

# Create the download directory
mkdir -p download
Set-Location download

# Download the zxing source code and unzip it
Invoke-WebRequest -O "zxing-cpp-$zxing_version.zip" "https://github.com/nu-book/zxing-cpp/archive/refs/tags/v$zxing_version.zip"
Expand-Archive "zxing-cpp-$zxing_version.zip"

# remove zxing from project
Remove-Item -R "$zxingPath"

# create the zxing directory
mkdir -p "$zxingPath"

# copy zxing
Copy-Item -R "zxing-cpp-$zxing_version/core/" "$zxingPath"

# print success message for zxing
Write-Output "ZXing $zxing_version has been successfully installed"

# remove the downloaded files
Set-Location ..
Remove-Item -R download