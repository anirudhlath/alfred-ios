# Re-enable CI-excluded snapshot and Keychain tests

**Priority:** medium

## Summary

`.github/workflows/ci.yml`'s `swift` job skips 9 tests via `-skip-testing:` flags so the
CI gate could go green on the macos-15 runner. All 9 are excluded for CI-environment
reasons, not known app bugs, but the exclusion has no expiry or tracking today — left
alone, it is effectively permanent. This ticket tracks re-enabling them (or documenting a
deliberate, reviewed alternative) rather than letting the gap go unnoticed.

## Context / Motivation

Introduced in PR #2 (`ci: add swift test gate, CLA, and community-health files`), after
CI iteration showed both groups fail on the bare, unsigned macos-15 runner regardless of
app logic:

**Snapshot tests (4 XCTest classes, `Tests/AlfredTests/Presentation/SnapshotTests.swift`):**
- `AlfredTests/ChatViewSnapshotTests`
- `AlfredTests/NotificationsViewSnapshotTests`
- `AlfredTests/SettingsViewSnapshotTests`
- `AlfredTests/OnboardingSnapshotTests`

Root cause: `swift-snapshot-testing` reference images are recorded against a specific
simulator device/OS combination. The macos-15 runner's `iPhone 16` simulator (whichever
exact OS/runtime GitHub's image ships) doesn't bit-match the images checked into
`Tests/AlfredTests/Presentation/__Snapshots__/`, so every comparison fails on rendering
drift rather than a real UI regression. This is the same class of issue CLAUDE.md's
"Snapshot device mismatch" testing gotcha already describes for local dev.

**Keychain / session-repo tests (5 Swift Testing free functions,
`Tests/AlfredTests/Data/KeychainStoreTests.swift` and
`Tests/AlfredTests/Data/RepositoryTests.swift`):**
- `AlfredTests/keychainSaveAndLoad()`
- `AlfredTests/keychainOverwritesExistingValue()`
- `AlfredTests/sessionRepoSavesAndRestoresConfig()`
- `AlfredTests/sessionRepoSavesAndRestoresSessionId()`
- `AlfredTests/sessionRepoSavesAndRestoresConversationId()`

Root cause: `App/Alfred/Data/Local/KeychainStore.swift` calls `SecItemAdd`/
`SecItemCopyMatching` with no `kSecAttrAccessGroup`, and discards the `SecItemAdd` status
entirely (`SecItemAdd(query as CFDictionary, nil)`). The CI `Test` step runs with
`CODE_SIGNING_ALLOWED=NO` (required so the job doesn't need a real signing identity), so
the test binary has no `application-identifier`/keychain-access-group entitlement.
`SecItemAdd` silently no-ops without one, and the paired read returns `nil` — the round
trip fails even though the code itself is correct. (`keychainDeleteRemovesValue()` and
`keychainLoadReturnsNilForMissing()` are unaffected and still run in CI, since they don't
depend on a prior successful write.)

Both root causes and the exact `-skip-testing:` flags are also inlined as a comment in
`.github/workflows/ci.yml` at the point of use, and in
`alfred/.superpowers/sdd/task-12b-report.md` (source-of-truth for how/why this PR reached
green — not committed to this repo, so this ticket is the durable, in-repo record).

## Acceptance Criteria

- [ ] Snapshot tests: either (a) re-recorded against whatever simulator/OS the `macos-15`
  runner actually ships (verified by running `withSnapshotTesting(record: .all)` once in
  CI or against a matching local simulator, then removing the flag) and re-enabled in
  `ci.yml`, or (b) a deliberate decision to keep them CI-excluded long-term is recorded in
  CLAUDE.md's Testing Gotchas with a reviewed rationale (not just inherited silently from
  this ticket).
- [ ] Keychain/session-repo tests: either (a) `KeychainStore` gains explicit status
  checking (stop discarding `SecItemAdd`'s return value) plus a CI-compatible way to grant
  the test binary a keychain-access-group entitlement (e.g. ad-hoc signing
  `CODE_SIGN_IDENTITY=-` instead of `CODE_SIGNING_ALLOWED=NO`, if that proves compatible
  with the rest of the `swift` job), and the 5 tests are re-enabled in `ci.yml`; or (b) a
  `docs/qa-backlog/` ticket is filed for manual/device verification of the Keychain
  round-trip path, and the CI exclusion + its rationale is written up permanently in
  CLAUDE.md's Testing Gotchas rather than only in this ticket.
- [ ] Once resolved, this ticket is deleted (per the repo's backlog convention) and the
  `-skip-testing:` flags + workflow comment in `ci.yml` are updated to match whatever was
  actually decided.
