# Contributing

Licensed MIT; contributions require the one-time [CLA](CLA.md) signature (the bot
prompts on your first PR).

Development: `xcodebuild test -project Alfred.xcodeproj -scheme Alfred -destination
'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`.

PRs: branch `<type>/<slug>`, conventional-commit PR title, squash-only, `ci-ok` must be
green. Same conventions as [alfred](https://github.com/anirudhlath/alfred/blob/master/CONTRIBUTING.md).
