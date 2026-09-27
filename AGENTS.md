# Initializing a New Mirror from This Template

This repository is a template for mirroring another project's prebuilt binaries into GitHub Releases, for machines that can reach GitHub but not the upstream's download server. A mirror has no product code: the releases are the product. `.github/workflows/updater.yml` publishes them hourly from whatever `scripts/fetch.sh` downloads, and `scripts/fetch.sh` is the only file that knows about the upstream.

[Mai0313/claude-code-binaries](https://github.com/Mai0313/claude-code-binaries) is a working instance. Its `scripts/fetch.sh` is the reference for an upstream that publishes a manifest with checksums and signatures.

## Establish the Upstream First

Find the following in the upstream's own documentation and installer rather than guessing. The installer is what the vendor keeps current: the Claude Code mirror was still downloading from a retired bucket until its installer was read.

| Information                                                                | Used by                                            |
| -------------------------------------------------------------------------- | -------------------------------------------------- |
| Where the newest version is announced (a `latest` pointer, an API, a feed) | `version`                                          |
| Where every file of a version lives, and which platforms exist             | `download`, the README's platform table            |
| The checksums and signatures the upstream publishes, and its signing key   | `download`, the README's verification section      |
| Where the release notes live, and how a version's heading is written       | `notes`                                            |
| Whether the upstream's license allows redistribution                       | Whether to build the mirror at all, and the README |

Ask the user about redistribution when the license is unclear.

## Implement `scripts/fetch.sh`

The workflow depends on this contract, so keep the three command names and their arguments:

- `version` prints exactly one version, used verbatim as the release tag. Pass it through `require_version`, because an error page served with status 200 must not become a tag.
- `download VERSION DIR` puts every file the upstream publishes for that version into `DIR`: every platform, plus the checksum and signature files a user needs to verify them. When the upstream has a manifest, derive the list from it instead of hard-coding platforms, so a new platform arrives without an edit. Fetch each file with `download_file` and its checksum. Any failure must exit non-zero: a partial release is worse than none, since the next hourly run retries only while no release exists. Every file becomes a release asset under its own name, so keep names unique, stable across versions, and carrying the version.
- `notes VERSION` prints that version's release notes. `changelog_section` covers a Markdown changelog; its heading must match the line exactly, such as `"## $1"`.

Keep the helpers: each one encodes a rule that was learned the hard way. Keep TLS verification on. `fetch.sh` runs on Ubuntu runners with bash, curl, jq and sha256sum, and nothing else should be assumed.

## Rewrite the READMEs

After initialization, `README.md`, `README.zh-TW.md` and `README.zh-CN.md` describe the mirror, not this template, and say the same thing in all three. What the Claude Code mirror needed:

- What it mirrors, for whom, and that it is unofficial, with a pointer to the official download for anyone who can reach it.
- A platform-to-file table for the latest release.
- Installation for each OS without the upstream's installer, which usually downloads from the upstream again. Test the steps in a `docker run --network none` container before documenting them.
- How to turn off the product's self-updater, if it has one, since it cannot reach the upstream either.
- How to verify a download against the upstream's checksums and signatures, quoting the signing key's fingerprint from the upstream's own documentation: a key downloaded from the mirror proves nothing by itself.
- How the mirror works, and the upstream's license.

## Workflows and Repository Settings

Modify workflows rather than deleting them. `updater.yml` needs no change: its job condition only skips this template repository, and is harmless anywhere else.

In the new repository's settings, keep the default branch `main` (the updater publishes on pushes to it), and turn on "Allow GitHub Actions to create and approve pull requests". Without it, Dependabot's auto-approve in `auto_review_merge.yml` and the pull request `pre-commit-updater.yml` opens both fail.

## Verification Order

```bash
./scripts/fetch.sh version
./scripts/fetch.sh download "$(./scripts/fetch.sh version)" dist  # dist/ is gitignored
./scripts/fetch.sh notes "$(./scripts/fetch.sh version)"
uvx pre-commit run -a
```

Also break one checksum and confirm `download` fails. pre-commit only sees tracked files, so `git add` new files first.

Then open a pull request that touches `scripts/fetch.sh`: the updater runs the full download without publishing, and its log should list every file. The publish step runs for real only on `main`. After merging, the push run publishes the newest upstream version, since no release exists yet; check its assets and notes.

Finally, replace this initialization guide with a description of the mirror, as Mai0313/claude-code-binaries's `AGENTS.md` does: what the mirror is, how a release gets published, the commands, and anything that looks simplifiable and is not. Keep the sections below.

## How a Release Gets Published

The updater publishes only when no *published* release carries the tag. The check uses `gh api repos/$GITHUB_REPOSITORY/releases/tags/$VERSION` on purpose: `gh release view` also matches a draft left by a cancelled `gh release create` (which drafts, uploads, then publishes), and treats an empty tag as "the latest release". Either would silently stop the mirror. For the same reason the version step assigns `VERSION=$(...)` before writing `$GITHUB_OUTPUT`: `echo "version=$(cmd)"` hides a failing `cmd` under `bash -e`.

Only the newest upstream version is mirrored. A version superseded within the hour is never published.

## Ongoing Rules

- Everything specific to the upstream stays in `scripts/fetch.sh` and the READMEs; `updater.yml` stays generic.
- mdformat re-aligns tables in the Chinese READMEs and URL-encodes CJK anchors. Let it. codespell flags some hexadecimal fragments, such as the groups of a spaced key fingerprint, so quote fingerprints unspaced.
- Every workflow except `updater.yml`, plus `.pre-commit-config.yaml`, `.gitattributes`, `.gitignore` and `.github/{CODEOWNERS,dependabot.yml,labeler.yml}`, is shared with the other Mai0313 templates. A change to one of them belongs in those templates too.
- Commit messages and PR titles are English Conventional Commits; `semantic-pull-request.yml` enforces the title. `labeler.yml` labels a PR by its branch prefix (`feat/`, `fix/`, `docs/`, `refactor/`, `chore/`, ...), so a branch without one gets no type label.
