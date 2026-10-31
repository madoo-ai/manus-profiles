# manus-profiles

Platform-owned environment profiles for Manus Dei sessions.

Each directory is one profile:

- `profile.yaml` — profile metadata, platform, and base profile
- `Dockerfile` — the system image recipe
- profile-owned runtime files — entrypoint, browser config, service hooks

The application source lives in the template repository, not here. A profile
image contains the environment; the session clones the app source at summon.

## Profiles

| Profile | Purpose |
| --- | --- |
| `base` | Shared developer shell, Manica Dei server, browser, Node, Python |
| `laravel-php85` | Laravel runtime: PHP 8.5, Composer, Node 22, PostgreSQL 18 |

## Build

The build worker reads `profile.yaml`, checks out a commit, builds the
Dockerfile, runs a smoke test, and records the image digest in the registry.

Do not bake application source or secrets into a profile.
