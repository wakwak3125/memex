# memex

External memory system for humans and AI agents.

Collects information from Slack, Notion, and Linear, then dumps it into an Obsidian vault as persistent external memory.

## Architecture

- **This repository**: Collection mechanisms (skills, configuration)
- **Obsidian vault** (`~/Documents/vault/00-memex/`): Data storage (markdown files)

```
vault/00-memex/
├── context/     # Structured long-term memory
├── snapshot/    # Periodic dumps from Linear / Slack / Notion
├── inbox/       # Unsorted temporary staging area
└── MEMORY.md    # Vault guide and structure explanation
```

## Skills

| Skill | Description |
|-------|-------------|
| `/sync-linear` | Collect issues and sprint info from Linear into `snapshot/linear.md` |

## Writing Rules

- All layers are writable by AI
- Writes are **overwrites** (no appending) — history is managed by Git
- Files in `context/` should be under 200 lines; link to SaaS for details
- Items in `inbox/` are deleted after promotion to `context/`

## Frontmatter

All vault files include:

```yaml
---
source: linear | slack | notion | manual
collected_at: 2026-04-01T09:00
ttl: 7d
auto_generated: true
---
```

## License

Private
