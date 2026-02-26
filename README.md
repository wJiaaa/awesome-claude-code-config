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
├── plugins/               # Plugin installation guide (19 plugins, 5 marketplaces)
├── skills/                # Custom skills (paper-reading, frontend-slides)
└── install.sh             # One-command installer
```

## Quick Start

```bash
git clone https://github.com/Mizoreww/claude-code-config.git
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

1. User corrects Claude → auto-saved to `~/.claude/lessons.md`
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

19 plugins across 5 marketplaces. Context7, GitHub, Playwright migrated from MCP to official plugins. Only Lark-MCP remains as MCP.

| Plugin | Marketplace | What It Does |
|--------|-------------|--------------|
| [**superpowers**](https://github.com/obra/superpowers) | claude-plugins-official | Brainstorming, debugging, code review, git worktrees, plan writing |
| [**everything-claude-code**](https://github.com/affaan-m/everything-claude-code) | everything-claude-code | TDD, security review, database patterns, Go/Python/Spring Boot |
| [**document-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | PDF, DOCX, PPTX, XLSX creation and manipulation |
| [**example-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | Frontend design, MCP builder, canvas design, algorithmic art |
| [**claude-mem**](https://github.com/thedotmack/claude-mem) | thedotmack | Persistent memory with smart search, timeline, AST-aware code search |
| **frontend-design** | claude-plugins-official | Production-grade frontend interfaces |
| [**context7**](https://github.com/upstash/context7) | claude-plugins-official | Up-to-date library documentation lookup |
| **code-review** | claude-plugins-official | Confidence-based code review |
| [**github**](https://github.com/github/github-mcp-server) | claude-plugins-official | GitHub integration (issues, PRs, workflows) |
| [**playwright**](https://github.com/microsoft/playwright-mcp) | claude-plugins-official | Browser automation, E2E testing, screenshots |
| **feature-dev** | claude-plugins-official | Guided feature development |
| **code-simplifier** | claude-plugins-official | Code simplification and refactoring |
| **ralph-loop** | claude-plugins-official | Session-aware AI assistant REPL |
| **commit-commands** | claude-plugins-official | Git commit, clean branches, commit-push-PR |
| [**fine-tuning**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | Axolotl, LLaMA-Factory, PEFT, Unsloth |
| [**post-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | GRPO, RLHF, DPO, SimPO |
| [**inference-serving**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | vLLM, SGLang, TensorRT-LLM, llama.cpp |
| [**distributed-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | DeepSpeed, FSDP, Megatron-Core, Ray Train |
| [**optimization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | AWQ, GPTQ, GGUF, Flash Attention, bitsandbytes |

See [`plugins/README.md`](plugins/README.md) for installation details.

## Security Note

`settings.json` ships with `bypassPermissions` mode for power users. If you prefer safer defaults, change `defaultMode` to `"default"` and set `skipDangerousModePermissionPrompt` to `false`.

## Customization

- **Add a language**: Create `rules/<lang>/` extending common rules
- **Add a skill**: Place in `skills/<name>/SKILL.md`
- **Adapt CLAUDE.md**: Customize for your shell, package manager, and project context

## Acknowledgements

- [**AI Agent Workflow Orchestration Guidelines**](https://gist.github.com/OmerFarukOruc/a02a5883e27b5b52ce740cadae0e4d60) by [@OmerFarukOruc](https://github.com/OmerFarukOruc) — 工作流编排的灵感来源
- [**Harness Engineering**](https://openai.com/zh-Hans-CN/index/harness-engineering/) by OpenAI — "驾驭工程"理念：工程师从代码编写者转变为系统设计者，用 Agent 生成百万行代码
- [**我给 10 个 Claude Code 打工**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by 胡渊鸣 — 多 Claude Code 实例并行协作的实践经验分享
- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — 官方课程，涵盖 Claude Code 工具集成、MCP 服务器、GitHub 自动化等开发工作流
- [**ChatGPT Prompt Engineering for Developers**](https://www.deeplearning.ai/short-courses/chatgpt-prompt-engineering-for-developers/) by DeepLearning.AI & OpenAI — Andrew Ng 与 Isa Fulford 合作的提示工程入门课程

## License

MIT
