# Project Architecture & Structure

- **`Makefile`**: Central entrypoint for all operations. It dynamically generates per-image targets for images defined in `IMAGES` (`opencode` and `crush`).
- **`Containerfile.agents`**: Multi-stage build containing:
  - `base-tools`: Core OS utilities (git, curl, fzf, rg, gh, jq) on a `nodejs-24` base.
  - `base-runtimes`: Language runtimes (Go, Python) and LSPs (gopls, pyright), MCP servers, and GitHub App auth scripts.
  - Target-specific stages: `opencode` and `crush`.
- **`scripts/`**: Shell scripts wrapped by the Makefile (e.g., `build.sh`, `push.sh`, `deploy.sh`).
- **`scripts/github-app/`**: GitHub App IAT generation, token caching, `gh` wrapper, and git credential helper (from kubeopencode/devbox / server-foundation-agent). Wired in `base-runtimes` so both agent images get transparent auth when `/etc/github-app/` is mounted or `GH_APP_*` env vars are set. If `GH_TOKEN` is already set (e.g. agent-swarm session PAT), the wrapper uses it instead.
- **`.push-defaults`**: A gitignored file that persists your registry and image tag preferences across builds. Sourced from `../agent-swarm/.push-defaults` if available.
