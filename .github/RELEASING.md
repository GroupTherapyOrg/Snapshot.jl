# Releasing Snapshot

Snapshot uses the Julia-aware Release Please fork pinned in
`release-please.yml`. Release Please is the sole owner of release versions,
`CHANGELOG.md`, tags, and GitHub releases after the `0.2.0` bootstrap.

## Normal release flow

1. Merge ordinary pull requests with a Conventional Commit title (`fix:`,
   `feat:`, or a breaking-change footer). These squash titles are the source
   of the changelog and version bump.
2. CI must pass on the resulting `main` commit. Only then may the release
   workflow create or update the release PR.
3. Review the release PR like any other code change. Confirm that
   `Project.toml`, `.release-please-manifest.json`, and `CHANGELOG.md` describe
   the same intended version, and wait for its required `test` check.
4. Merge the release PR. After CI passes on that exact merge commit, Release
   Please creates the immutable tag and GitHub release. Its Julia integration
   asks JuliaRegistrator to register that exact tagged commit in General.
5. Confirm the new version in General before changing downstream compat.

Do not hand-edit a released tag, reuse a version, or revert release metadata
after JuliaRegistrator has accepted it. Publish a new patch release instead.

Before `1.0`, this repository intentionally treats ordinary `feat:` and
`fix:` changes as patch releases. A Conventional Commit with a
`BREAKING CHANGE:` footer produces a minor release. Use scopes where they add
useful context—for example, `fix(security):` or `fix(ci):`—because bare
`security:` and `ci:` commit types do not produce a release by default.

## One-time 0.2.0 bootstrap

The automation setup lands with an exact, blank-line-separated
`Release-As: 0.2.0` commit footer. That footer is deliberately one-time: it
aligns the first generated release PR with the already-reviewed `0.2.0`
version in `Project.toml`. After that release, Release Please derives versions
normally from Conventional Commits.

## Recovery

`workflow_dispatch` is intentionally not a CI bypass: it refuses to run unless
the current `main` commit already has a successful `test` check.

The release is published before preparation of the next release PR. If release
PR creation fails, rerun the workflow after fixing repository permissions; the
existing release remains valid.

If the GitHub tag and release exist but the JuliaRegistrator comment failed,
do not recreate or move the tag. Verify that the tag points at the release
commit, then comment on that exact commit:

```text
@JuliaRegistrator register
```

If General already contains the version, no registration retry is needed.
