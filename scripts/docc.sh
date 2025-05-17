xcodebuild docbuild -scheme window-scaling-kit -destination 'generic/platform=macOS' -derivedDataPath "$PWD/.derivedData"
$(xcrun --find docc) process-archive \
  transform-for-static-hosting "$PWD/.derivedData/Build/Products/Debug/WindowScalingKit.doccarchive" \
  --output-path docs \
  --hosting-base-path "window-scaling-kit"

echo "<script>window.location.href += \"/documentation/windowscalingkit\"</script>" > docs/index.html;
