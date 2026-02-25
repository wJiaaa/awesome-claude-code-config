# Persistent Memory Index

## File Index

- [lessons.md](lessons.md) - Lessons learned (global, shared across all sessions)

## User Environment

<!-- Fill in your own environment details -->
- System: (your OS and shell)
- Main workspace: (your workspace path)

## Memory Structure

| Level | Path | Loaded when | Content |
|-------|------|-------------|---------|
| Global | `~/.claude/memory/` | Every conversation | Cross-project experience, preferences, lessons |
| Project | `~/.claude/projects/<path>/memory/` | Entering that directory | Project-specific context only |

- `lessons.md` exists only at global level, never at project level
- `CLAUDE.md` can only be modified when the user explicitly asks
