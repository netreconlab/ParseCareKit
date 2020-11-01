ver=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ParseCareKit/Info.plist`
bundle exec jazzy \
  --clean \
  --author "Corey E. Baker" \
  --author_url https://www.cs.uky.edu/~baker \
  --github_url https://github.com/netreconlab/ParseCareKit \
  --root-url https://netreconlab.github.io/api/ \
  --module-version ${ver} \
  --theme fullwidth \
  --skip-undocumented \
  --output ./docs/api \
  --module ParseCareKit \
  --swift-build-tool spm \
  --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5
