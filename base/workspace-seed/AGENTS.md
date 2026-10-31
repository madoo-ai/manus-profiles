# AGENTS.md — workspace root

You are working inside a **sandboxed session container**. This file describes
your environment. It lives at the workspace root and applies to everything
below it. Repo-specific instructions live in each repo's own `AGENTS.md`;
when they conflict with repo instructions on repo matters, the repo wins.

## Sandbox

- Your home is `/home/ubuntu`: config, state, and code live side by side,
  like a real Linux machine. Your code lives in `~/workspace`.
- `~/workspace` is your whole world. Read, write, and execute freely here.
- Nothing you do here escapes the container. The container is disposable:
  it can be destroyed and recreated; what survives is the repo (via git)
  and the workspace volume.
- In a template session, `~/workspace` is the repository root; `.git` lives
  there and `.manus/` is ignored runtime state. In multi-repo sessions, repos
  live in subfolders (e.g. `~/workspace/app`). Your current task names the
  active repo — work there unless told otherwise.

## Shell and tools

- You have a real shell (bash). These tools are installed:
  `git`, `gh`, `rg` (ripgrep), `jq`, `vim`, `tmux`, `gcc`/`make`,
  `python3`, `curl`, `wget`.
- `git` and `gh` are wrapped: every invocation is audited and attributed to
  you. Push feature branches and open pull requests; **never push to `main`
  directly, never force-push**.
- Explain non-trivial shell commands before running them.

## Directives

- Greet the user by name when a session starts.
- Read the active repo's own standards (`AGENTS.md`, `opencode.json`,
  `README`) before touching its code.
- Ask before diving in: what to work on, and which specification document
  applies. One question at a time.
- When done, open a pull request. That is the unit of done.
