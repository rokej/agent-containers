# GitHub App authentication scripts

Vendored from [server-foundation-agent `build/scripts`](https://github.com/stolostron/server-foundation-agent/tree/main/build/scripts) (kubeopencode/devbox pattern).

Installed into agent images at build time (`base-runtimes` stage in `containerfiles/Containerfile.agents`).

## Runtime credentials

Provide GitHub App credentials via **either**:

1. **Files** mounted at `/etc/github-app/`:
   - `client_id` — App ID
   - `installation_id` — installation ID for the target org
   - `private_key` — PEM private key

2. **Environment variables**:
   - `GH_APP_ID`
   - `GH_APP_INSTALLATION_ID`
   - `GH_APP_PRIVATE_KEY`

## Behavior

| Component | Role |
|-----------|------|
| `github-app-iat.sh` | Mint Installation Access Token (JWT → `ghs_…`) |
| `github-token-manager.sh` | Cache in `/tmp/gh_token`, refresh when &lt;10 min left |
| `gh-wrapper.sh` | Inject token into `gh` when `GH_TOKEN` unset |
| `git-credential-github-app.sh` | System git credential helper for `github.com` |

## agent-swarm

When a workspace has GitHub App credentials configured, session pods mount them at `/etc/github-app/`. Swarmer injects session PATs as `GITHUB_PAT` only (not `GH_TOKEN`) so `gh-wrapper` mints App tokens first. Both `gh-wrapper` and `git-credential-github-app.sh` fall back to `GITHUB_PAT` when App auth fails.
