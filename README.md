# Claude Code Configuration

Production-ready configuration for [Claude Code](https://claude.com/claude-code): global instructions, multi-language coding rules, plugins, MCP integration, and a self-improvement loop.

## Directory Structure

```
.
├── CLAUDE.md              # Global instructions
├── settings.json          # Settings (permissions, plugins, hooks, model)
├── lessons.md             # Self-correction log template (auto-loaded via hook)
├── rules/                 # Multi-language coding standards (common + python/typescript/golang)
├── mcp/                   # MCP server config (Lark-MCP only)
├── plugins/               # Plugin installation guide (20 plugins, 5 marketplaces)
├── skills/                # Custom skills (paper-reading, frontend-slides)
└── install.sh             # One-command installer
```

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-config.git
cd claude-code-config
./install.sh              # Install everything
./install.sh --dry-run    # Preview changes
```

Selective install:

```bash
./install.sh --rules python typescript  # Rules only
./install.sh --plugins                  # Plugins only
./install.sh --mcp                      # MCP only
```

## Key Features

### Self-Improvement Loop

1. User corrects Claude → auto-saved to `~/.claude/memory/lessons.md`
2. Next session → `SessionStart` hook auto-injects lessons into context
3. Pattern confirmed → rule promoted to `CLAUDE.md`

### SessionStart Hook

`settings.json` includes two `SessionStart` hooks:
- **startup**: Injects lessons.md when a new session starts
- **compact**: Re-injects lessons.md after context compaction

Replaces the previous approach of requiring manual `Read lessons.md` in CLAUDE.md (more reliable).

### Layered Rules

```
common/       → Universal principles (always loaded)
  ↓ extended by
python/       → PEP 8, pytest, black, bandit
typescript/   → Zod, Playwright, Prettier
golang/       → gofmt, table-driven tests, gosec
```

### Plugin-First Approach

20 plugins covering dev workflows, document creation, and ML/AI research. Context7, GitHub, Playwright have migrated from MCP to official plugins. Only Lark-MCP remains as MCP.

See [`plugins/README.md`](plugins/README.md) for details.

## Customization

- **Add a language**: Create `rules/<lang>/` extending common rules
- **Add a skill**: Place in `skills/<name>/SKILL.md`
- **Adapt CLAUDE.md**: Customize for your shell, package manager, and project context

## Acknowledgements

Workflow orchestration inspired by [**@OmerFarukOruc**](https://github.com/OmerFarukOruc)'s [AI Agent Workflow Orchestration Guidelines](https://gist.github.com/OmerFarukOruc/a02a5883e27b5b52ce740cadae0e4d60).

## License

MIT
