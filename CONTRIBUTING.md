# Contributing

The value of this repo is that it works in environments where OpenVPN normally cannot. Contributions are judged against that.

## What helps most

- Reports of restricted environments where the quickstart succeeds or fails: CI runners, sandboxed VMs, containers, locked-down lab cells. State the environment, what the stock client did, and what this one did, with logs trimmed to the relevant lines.
- Fixes to `bootstrap.sh` and the `Dockerfile` for distributions and base images beyond Debian/Ubuntu.
- Documentation corrections backed by a run. If a command in the README did not work as written, the pull request that fixes the text and shows the working run is the ideal shape.

## Rules

- No OpenVPN profiles, keys, or credentials in any contribution, including in logs and screenshots. Profiles are excluded by `.gitignore` on purpose; keep it that way.
- Upstream code is fetched at pinned commits by `build.sh` and is never vendored here. Changes to upstream behaviour belong upstream.
- Keep the scripts idempotent and confined to the repo directory. Nothing installs system-wide beyond the documented apt packages in `bootstrap.sh`.

## Testing a change

Run `./bootstrap.sh --check`, then a clean-checkout build (`git clone` this repo somewhere fresh, `./bootstrap.sh`), and say in the pull request which restricted environment you verified in, or that the verification is still owed.
