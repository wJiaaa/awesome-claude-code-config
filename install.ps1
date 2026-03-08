#Requires -Version 5.1
<#
.SYNOPSIS
    Awesome Claude Code Configuration Installer (Windows)
.DESCRIPTION
    https://github.com/Mizoreww/awesome-claude-code-config
.EXAMPLE
    .\install.ps1                           # Install everything (core plugins)
    .\install.ps1 -Rules python,golang      # Install common + Python + Go rules
    .\install.ps1 -Plugins                  # Core plugins only
    .\install.ps1 -Plugins -PluginGroup all # All plugins
    .\install.ps1 -Uninstall               # Uninstall everything
    .\install.ps1 -DryRun                  # Preview changes
    # Remote install:
    irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex
#>

param(
    [switch]$All,
    [string[]]$Rules,
    [switch]$Skills,
    [switch]$Lessons,
    [switch]$Hooks,
    [switch]$Mcp,
    [switch]$Plugins,
    [string]$PluginGroup = "core",
    [switch]$ClaudeMd,
    [switch]$Settings,
    [switch]$Uninstall,
    [string[]]$UninstallComponents,
    [switch]$Version,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$CLAUDE_DIR = Join-Path $env:USERPROFILE ".claude"
$REPO_URL = "https://github.com/Mizoreww/awesome-claude-code-config"
$VERSION_STAMP_FILE = Join-Path $CLAUDE_DIR ".awesome-claude-code-config-version"

# --- Colors ----------------------------------------------------------------

function Write-Info  { param([string]$Msg) Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Ok    { param([string]$Msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn  { param([string]$Msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err   { param([string]$Msg) Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $Msg }

# --- Retry wrapper ---------------------------------------------------------

function Invoke-Retry {
    param(
        [int]$MaxAttempts,
        [int]$DelaySeconds,
        [string]$Description,
        [scriptblock]$Action
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            & $Action
            return $true
        } catch {
            if ($attempt -lt $MaxAttempts) {
                Write-Warn "$Description failed (attempt $attempt/$MaxAttempts), retrying in ${DelaySeconds}s..."
                Start-Sleep -Seconds $DelaySeconds
            } else {
                Write-Warn "$Description failed after $MaxAttempts attempts, skipping."
            }
        }
    }
    return $false
}

# --- Remote install detection ----------------------------------------------

$SCRIPT_DIR = ""
$REMOTE_MODE = $false

function Initialize-ScriptDir {
    $script:SCRIPT_DIR = $PSScriptRoot

    if ($script:SCRIPT_DIR -and (Test-Path (Join-Path $script:SCRIPT_DIR "CLAUDE.md"))) {
        $script:REMOTE_MODE = $false
        return
    }

    # Remote mode: download zip to temp dir
    $script:REMOTE_MODE = $true
    $tmpdir = Join-Path ([System.IO.Path]::GetTempPath()) "claude-config-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpdir -Force | Out-Null

    $ver = if ($env:VERSION) { $env:VERSION } else { "main" }
    $zipUrl = "$REPO_URL/archive/refs/heads/$ver.zip"
    if ($ver -match '^v\d') {
        $zipUrl = "$REPO_URL/archive/refs/tags/$ver.zip"
    }

    Write-Info "Remote mode: downloading $ver..."
    $zipPath = Join-Path $tmpdir "source.zip"

    $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Download source zip" -Action {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    }
    if (-not $ok) {
        Write-Err "Failed to download source after retries. Cannot continue in remote mode."
        exit 1
    }

    Expand-Archive -Path $zipPath -DestinationPath $tmpdir -Force
    $extracted = Get-ChildItem -Path $tmpdir -Directory | Where-Object { $_.Name -ne "source.zip" } | Select-Object -First 1
    $script:SCRIPT_DIR = $extracted.FullName
    Write-Ok "Source downloaded to temporary directory"
}

# --- Version management ----------------------------------------------------

function Get-SourceVersion {
    $vf = Join-Path $SCRIPT_DIR "VERSION"
    if (Test-Path $vf) { return (Get-Content $vf -Raw).Trim() }
    return "unknown"
}

function Get-InstalledVersion {
    if (Test-Path $VERSION_STAMP_FILE) { return (Get-Content $VERSION_STAMP_FILE -Raw).Trim() }
    return "not installed"
}

function Get-RemoteVersion {
    $url = "https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/VERSION"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $result = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10).Content.Trim()
        if ($result) { return $result }
    } catch {}
    return "unavailable"
}

function Show-Version {
    $sv = Get-SourceVersion
    $iv = Get-InstalledVersion
    $rv = Get-RemoteVersion
    Write-Host "awesome-claude-code-config version info:"
    Write-Host "  Source:    $sv"
    Write-Host "  Installed: $iv"
    Write-Host "  Remote:    $rv"
    if ($iv -ne "not installed" -and $rv -ne "unavailable" -and $iv -ne $rv) {
        Write-Warn "Update available: $iv -> $rv"
    }
}

function Save-VersionStamp {
    $ver = Get-SourceVersion
    if ($ver -ne "unknown") {
        $ver | Set-Content -Path $VERSION_STAMP_FILE -NoNewline
    }
}

# --- Confirm prompt --------------------------------------------------------

function Confirm-Action {
    param([string]$Prompt = "Continue?")
    if ($Force) { return $true }
    $answer = Read-Host "$Prompt [y/N]"
    return ($answer -match '^[Yy]$')
}

# --- Install functions -----------------------------------------------------

function Install-ClaudeMd {
    Write-Info "Installing CLAUDE.md..."
    if ($DryRun) {
        Write-Info "Would copy: CLAUDE.md -> $CLAUDE_DIR\CLAUDE.md"
    } else {
        Copy-Item (Join-Path $SCRIPT_DIR "CLAUDE.md") (Join-Path $CLAUDE_DIR "CLAUDE.md") -Force
        Write-Ok "CLAUDE.md installed"
    }
}

function Install-Settings {
    Write-Info "Installing settings.json..."
    $target = Join-Path $CLAUDE_DIR "settings.json"
    $source = Join-Path $SCRIPT_DIR "settings.json"

    if (-not (Test-Path $target)) {
        if ($DryRun) {
            Write-Info "Would copy: settings.json -> $target"
        } else {
            Copy-Item $source $target -Force
            Write-Ok "settings.json installed (new)"
        }
        return
    }

    # Smart merge using PowerShell JSON
    if ($DryRun) {
        Write-Info "Would smart-merge settings.json"
        Write-Info "  - env: incoming as defaults, existing overrides"
        Write-Info "  - permissions.allow: union of arrays"
        Write-Info "  - enabledPlugins: merged, existing keys take priority"
        Write-Info "  - hooks.SessionStart: deduplicated by matcher"
        Write-Info "  - statusLine: incoming takes priority"
        return
    }

    try {
        # Relax strict mode for dynamic JSON property access
        Set-StrictMode -Off

        $existing = Get-Content $target -Raw | ConvertFrom-Json
        $incoming = Get-Content $source -Raw | ConvertFrom-Json

        # Helper: convert PSCustomObject to ordered hashtable
        $toHt = {
            param($obj)
            if ($null -eq $obj) { return [ordered]@{} }
            if ($obj -is [System.Collections.IDictionary]) { return $obj }
            $ht = [ordered]@{}
            $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
            return $ht
        }

        # Helper: merge two objects as hashtables (second wins on conflict)
        $mergeHt = {
            param($base, $over)
            $result = [ordered]@{}
            $b = & $toHt $base
            $o = & $toHt $over
            foreach ($key in $b.Keys) { $result[$key] = $b[$key] }
            foreach ($key in $o.Keys) { $result[$key] = $o[$key] }
            return $result
        }

        # env: incoming as defaults, existing overrides
        $mergedEnv = & $mergeHt $incoming.env $existing.env

        # permissions.allow: union
        $baseAllow = if ($incoming.permissions -and $incoming.permissions.allow) { @($incoming.permissions.allow) } else { @() }
        $overAllow = if ($existing.permissions -and $existing.permissions.allow) { @($existing.permissions.allow) } else { @() }
        $mergedAllow = @($baseAllow + $overAllow | Select-Object -Unique)

        # enabledPlugins: merge, existing wins
        $mergedPlugins = & $mergeHt $incoming.enabledPlugins $existing.enabledPlugins

        # hooks.SessionStart: deduplicate by matcher (last wins)
        $sessionHooks = [ordered]@{}
        if ($incoming.hooks -and $incoming.hooks.SessionStart) {
            foreach ($h in @($incoming.hooks.SessionStart)) { if ($h.matcher) { $sessionHooks[$h.matcher] = $h } }
        }
        if ($existing.hooks -and $existing.hooks.SessionStart) {
            foreach ($h in @($existing.hooks.SessionStart)) { if ($h.matcher) { $sessionHooks[$h.matcher] = $h } }
        }
        $mergedSessionHooks = @($sessionHooks.Values)

        # Build merged result as hashtable (avoids PSCustomObject assignment issues)
        $merged = & $mergeHt $incoming $existing

        # Override with merged fields
        $merged["env"] = [PSCustomObject]$mergedEnv
        $merged["enabledPlugins"] = [PSCustomObject]$mergedPlugins
        $merged["statusLine"] = $incoming.statusLine
        $mergedPerms = & $mergeHt $incoming.permissions $existing.permissions
        $mergedPerms["allow"] = $mergedAllow
        $merged["permissions"] = [PSCustomObject]$mergedPerms
        $mergedHooks = & $mergeHt $incoming.hooks $existing.hooks
        $mergedHooks["SessionStart"] = $mergedSessionHooks
        $merged["hooks"] = [PSCustomObject]$mergedHooks

        [PSCustomObject]$merged | ConvertTo-Json -Depth 10 | Set-Content $target -Encoding UTF8

        Set-StrictMode -Version Latest
        Write-Ok "settings.json smart-merged"
    } catch {
        Set-StrictMode -Version Latest
        Write-Err "Merge failed: $_"
        Write-Warn "Please merge manually: $source -> $target"
    }
}

function Install-Rules {
    Write-Info "Installing rules..."
    $rulesDir = Join-Path $CLAUDE_DIR "rules"
    New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null

    # Always install common rules
    $commonSrc = Join-Path $SCRIPT_DIR "rules\common"
    $commonDst = Join-Path $rulesDir "common"
    if ($DryRun) {
        Write-Info "Would copy: rules\common\ -> $commonDst"
    } else {
        Copy-Item $commonSrc $commonDst -Recurse -Force
        Write-Ok "Common rules installed"
    }

    # Determine languages
    $langs = @()
    if ($Rules -and $Rules.Count -gt 0) {
        $langs = $Rules
    } else {
        Get-ChildItem (Join-Path $SCRIPT_DIR "rules") -Directory | ForEach-Object {
            if ($_.Name -ne "common") { $langs += $_.Name }
        }
    }

    foreach ($lang in $langs) {
        $langSrc = Join-Path $SCRIPT_DIR "rules\$lang"
        if (Test-Path $langSrc) {
            $langDst = Join-Path $rulesDir $lang
            if ($DryRun) {
                Write-Info "Would copy: rules\$lang\ -> $langDst"
            } else {
                Copy-Item $langSrc $langDst -Recurse -Force
                Write-Ok "$lang rules installed"
            }
        } else {
            Write-Err "Language rules not found: $lang"
        }
    }

    $readmeSrc = Join-Path $SCRIPT_DIR "rules\README.md"
    if (Test-Path $readmeSrc) {
        if ($DryRun) {
            Write-Info "Would copy: rules\README.md -> $rulesDir\README.md"
        } else {
            Copy-Item $readmeSrc (Join-Path $rulesDir "README.md") -Force
        }
    }
}

function Install-Skills {
    Write-Info "Installing custom skills..."
    $skillsDir = Join-Path $CLAUDE_DIR "skills"
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

    Get-ChildItem (Join-Path $SCRIPT_DIR "skills") -Directory | ForEach-Object {
        $skill = $_.Name
        $dst = Join-Path $skillsDir $skill
        if ($DryRun) {
            Write-Info "Would copy: skills\$skill\ -> $dst"
        } else {
            Copy-Item $_.FullName $dst -Recurse -Force
            Write-Ok "Skill installed: $skill"
        }
    }
}

function Install-Lessons {
    Write-Info "Installing lessons.md template..."
    $target = Join-Path $CLAUDE_DIR "lessons.md"
    if (Test-Path $target) {
        Write-Warn "lessons.md already exists -- skipping"
    } else {
        if ($DryRun) {
            Write-Info "Would copy: lessons.md -> $target"
        } else {
            Copy-Item (Join-Path $SCRIPT_DIR "lessons.md") $target -Force
            Write-Ok "lessons.md template installed to $target"
        }
    }
}

function Install-Hooks {
    Write-Info "Installing hooks..."
    $hooksDir = Join-Path $CLAUDE_DIR "hooks"
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null

    Get-ChildItem (Join-Path $SCRIPT_DIR "hooks") -File | ForEach-Object {
        $fname = $_.Name
        $dst = Join-Path $hooksDir $fname
        if ($DryRun) {
            Write-Info "Would copy: hooks\$fname -> $dst"
        } else {
            Copy-Item $_.FullName $dst -Force
            Write-Ok "Hook installed: $fname"
        }
    }

    # Ensure jq is available (required by statusline.sh)
    Install-Jq
}

function Install-Jq {
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        Write-Ok "jq already available in PATH"
        return
    }

    $binDir = Join-Path $CLAUDE_DIR "bin"
    $jqPath = Join-Path $binDir "jq.exe"
    if (Test-Path $jqPath) {
        Write-Ok "jq already installed at $jqPath"
        return
    }

    if ($DryRun) {
        Write-Info "Would download jq.exe -> $jqPath"
        return
    }

    Write-Info "Downloading jq (required by statusline)..."
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null

    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "i386" }
    $jqUrl = "https://github.com/jqlang/jq/releases/latest/download/jq-windows-$arch.exe"

    $ok = Invoke-Retry -MaxAttempts 3 -DelaySeconds 2 -Description "Download jq" -Action {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $jqUrl -OutFile $jqPath -UseBasicParsing
    }
    if ($ok) {
        Write-Ok "jq installed to $jqPath"
    } else {
        Write-Warn "Could not download jq. Install it manually: https://jqlang.github.io/jq/download/"
        Write-Warn "Or run: winget install jqlang.jq"
    }
}

function Install-Mcp {
    Write-Info "Installing MCP servers..."
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Err "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return
    }

    if ($DryRun) {
        Write-Info "Would add MCP server: lark-mcp (stdio)"
    } else {
        $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Add MCP server lark-mcp" -Action {
            & claude mcp add --scope user --transport stdio lark-mcp -- npx -y "@larksuiteoapi/lark-mcp" mcp -a YOUR_APP_ID -s YOUR_APP_SECRET 2>$null
        }
        if ($ok) { Write-Ok "MCP server added: lark-mcp" }
        else { Write-Warn "MCP server lark-mcp may already exist or could not be added, skipping" }
        Write-Warn "Replace YOUR_APP_ID and YOUR_APP_SECRET with your Feishu credentials"
    }
}

# --- Plugin groups ---------------------------------------------------------

$PLUGINS_CORE = @(
    "document-skills@anthropic-agent-skills"
    "example-skills@anthropic-agent-skills"
    "everything-claude-code@everything-claude-code"
    "claude-mem@thedotmack"
    "frontend-design@claude-plugins-official"
    "context7@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "code-review@claude-plugins-official"
    "github@claude-plugins-official"
    "playwright@claude-plugins-official"
    "feature-dev@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
    "commit-commands@claude-plugins-official"
)

$PLUGINS_AI_RESEARCH = @(
    "fine-tuning@ai-research-skills"
    "post-training@ai-research-skills"
    "inference-serving@ai-research-skills"
    "distributed-training@ai-research-skills"
    "optimization@ai-research-skills"
)

$MARKETPLACE_LIST = @(
    @{ Name = "anthropic-agent-skills"; Repo = "anthropics/skills" }
    @{ Name = "everything-claude-code"; Repo = "affaan-m/everything-claude-code" }
    @{ Name = "ai-research-skills"; Repo = "zechenzhangAGI/AI-research-SKILLs" }
    @{ Name = "claude-plugins-official"; Repo = "anthropics/claude-plugins-official" }
    @{ Name = "thedotmack"; Repo = "thedotmack/claude-mem" }
)

function Install-Plugins {
    Write-Info "Installing plugins (group: $PluginGroup)..."
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Err "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return
    }

    $plugins = switch ($PluginGroup) {
        "core"        { $PLUGINS_CORE }
        "ai-research" { $PLUGINS_AI_RESEARCH }
        "all"         { $PLUGINS_CORE + $PLUGINS_AI_RESEARCH }
    }

    # Collect needed marketplaces
    $neededMarketplaces = @{}
    foreach ($entry in $plugins) {
        $marketplace = ($entry -split '@')[-1]
        $neededMarketplaces[$marketplace] = $true
    }

    # Step 1: Add required marketplaces
    Write-Info "Adding marketplaces..."
    foreach ($mp in $MARKETPLACE_LIST) {
        if (-not $neededMarketplaces.ContainsKey($mp.Name)) { continue }
        if ($DryRun) {
            Write-Info "Would add marketplace: $($mp.Name) (github.com/$($mp.Repo))"
        } else {
            $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Add marketplace $($mp.Name)" -Action {
                & claude plugin marketplace add "https://github.com/$($mp.Repo)" 2>$null
            }
            if ($ok) { Write-Ok "Marketplace added: $($mp.Name)" }
            else { Write-Warn "Marketplace $($mp.Name) may already exist or could not be added" }
        }
    }

    # Step 2: Install plugins
    Write-Info "Installing $($plugins.Count) plugins..."
    foreach ($entry in $plugins) {
        $parts = $entry -split '@'
        $pluginName = $parts[0]
        $marketplace = $parts[1]
        if ($DryRun) {
            Write-Info "Would install plugin: $pluginName from $marketplace"
        } else {
            $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Install plugin $pluginName" -Action {
                & claude plugin install "$entry" 2>$null
            }
            if ($ok) { Write-Ok "Plugin installed: $pluginName" }
            else { Write-Warn "Plugin $pluginName could not be installed, skipping" }
        }
    }
}

# --- Uninstall -------------------------------------------------------------

function Invoke-Uninstall {
    $components = $UninstallComponents
    if (-not $components -or $components.Count -eq 0) {
        $components = @("claude-md", "settings", "rules", "skills", "lessons", "hooks")
    }

    Write-Host ""
    Write-Warn "The following will be removed:"
    foreach ($comp in $components) {
        switch ($comp) {
            "claude-md" { Write-Host "  - $CLAUDE_DIR\CLAUDE.md" }
            "settings"  { Write-Host "  - $CLAUDE_DIR\settings.json" }
            "rules"     { Write-Host "  - $CLAUDE_DIR\rules\" }
            "skills"    { Write-Host "  - $CLAUDE_DIR\skills\ (installer-managed only)" }
            "lessons"   { Write-Host "  - $CLAUDE_DIR\lessons.md" }
            "hooks"     { Write-Host "  - $CLAUDE_DIR\hooks\ (installer-managed only)" }
            "plugins"   { Write-Host "  - Installed plugins (requires claude CLI)" }
            "mcp"       { Write-Host "  - MCP server: lark-mcp (requires claude CLI)" }
        }
    }
    if (Test-Path $VERSION_STAMP_FILE) {
        Write-Host "  - $VERSION_STAMP_FILE"
    }
    Write-Host ""

    if ($DryRun) {
        Write-Warn "DRY RUN -- nothing will be removed"
        return
    }

    if (-not (Confirm-Action "Proceed with uninstall?")) {
        Write-Info "Cancelled."
        exit 0
    }

    foreach ($comp in $components) {
        switch ($comp) {
            "claude-md" {
                $p = Join-Path $CLAUDE_DIR "CLAUDE.md"
                if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed CLAUDE.md" }
            }
            "settings" {
                $p = Join-Path $CLAUDE_DIR "settings.json"
                if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed settings.json" }
            }
            "rules" {
                $p = Join-Path $CLAUDE_DIR "rules"
                if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed rules/" }
            }
            "skills" {
                $skillsSrc = Join-Path $SCRIPT_DIR "skills"
                if (Test-Path $skillsSrc) {
                    Get-ChildItem $skillsSrc -Directory | ForEach-Object {
                        $p = Join-Path $CLAUDE_DIR "skills\$($_.Name)"
                        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed skill: $($_.Name)" }
                    }
                } else {
                    $p = Join-Path $CLAUDE_DIR "skills"
                    if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed skills/" }
                }
            }
            "lessons" {
                $p = Join-Path $CLAUDE_DIR "lessons.md"
                if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed lessons.md" }
            }
            "hooks" {
                $hooksSrc = Join-Path $SCRIPT_DIR "hooks"
                if (Test-Path $hooksSrc) {
                    Get-ChildItem $hooksSrc -File | ForEach-Object {
                        $p = Join-Path $CLAUDE_DIR "hooks\$($_.Name)"
                        if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed hook: $($_.Name)" }
                    }
                } else {
                    $p = Join-Path $CLAUDE_DIR "hooks"
                    if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed hooks/" }
                }
            }
            "plugins" {
                $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
                if ($claudeCmd) {
                    $allPlugins = $PLUGINS_CORE + $PLUGINS_AI_RESEARCH
                    foreach ($entry in $allPlugins) {
                        $pluginName = ($entry -split '@')[0]
                        try {
                            & claude plugin uninstall $entry 2>$null
                            Write-Ok "Uninstalled plugin: $pluginName"
                        } catch {
                            Write-Warn "Could not uninstall: $pluginName"
                        }
                    }
                } else {
                    Write-Warn "Claude CLI not found - cannot uninstall plugins"
                }
            }
            "mcp" {
                $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
                if ($claudeCmd) {
                    try {
                        & claude mcp remove lark-mcp 2>$null
                        Write-Ok "Removed MCP server: lark-mcp"
                    } catch {
                        Write-Warn "Could not remove lark-mcp"
                    }
                } else {
                    Write-Warn "Claude CLI not found - cannot remove MCP servers"
                }
            }
        }
    }

    if (Test-Path $VERSION_STAMP_FILE) { Remove-Item $VERSION_STAMP_FILE -Force }
    Write-Host ""
    Write-Ok "Uninstall complete."
}

# --- Help ------------------------------------------------------------------

function Show-Help {
    Write-Host @"

Usage: .\install.ps1 [OPTIONS]

Install Claude Code configuration files.

Options:
    -All                    Install everything (default; MCP excluded, see -Mcp)
    -Rules LANG[,LANG...]   Install common + specific language rules
                            Available: python, typescript, golang
    -Skills                 Install custom skills only
    -Lessons                Install lessons.md template only
    -Hooks                  Install hooks (statusline) only
    -Mcp                    Install MCP servers (Lark) - not included in -All
    -Plugins [-PluginGroup] Install plugins (default: core)
                            Groups: core, ai-research, all
    -ClaudeMd               Install CLAUDE.md only
    -Settings               Install settings.json only
    -Uninstall [-UninstallComponents] Remove installed files
    -Version                Show version info
    -DryRun                 Show what would be installed without doing it
    -Force                  Skip confirmation prompts
    -Help                   Show this help

Examples:
    .\install.ps1                                       # Install everything
    .\install.ps1 -Rules python,golang                  # Common + Python + Go rules
    .\install.ps1 -Plugins                              # Core plugins only
    .\install.ps1 -Plugins -PluginGroup all             # All plugins
    .\install.ps1 -Uninstall                            # Uninstall everything
    .\install.ps1 -Uninstall -UninstallComponents rules # Uninstall rules only
    .\install.ps1 -DryRun                               # Preview changes
    irm $REPO_URL/raw/main/install.ps1 | iex            # Remote install

"@
}

# --- Main ------------------------------------------------------------------

function Main {
    Initialize-ScriptDir

    if ($Help) { Show-Help; return }
    if ($Version) { Show-Version; return }
    if ($Uninstall) {
        Write-Host ""
        Write-Host "========================================="
        Write-Host "  Claude Code Config - Uninstaller"
        Write-Host "========================================="
        Invoke-Uninstall
        return
    }

    # Determine if any specific component was requested
    $hasComponent = ($Rules -and $Rules.Count -gt 0) -or $Skills -or $Lessons -or $Hooks -or $Mcp -or $Plugins -or $ClaudeMd -or $Settings
    $installAll = (-not $hasComponent) -or $All

    $sourceVer = Get-SourceVersion
    Write-Host ""
    Write-Host "========================================="
    Write-Host "  Awesome Claude Code Config Installer"
    Write-Host "  $sourceVer"
    Write-Host "========================================="
    Write-Host ""

    if ($DryRun) {
        Write-Warn "DRY RUN MODE -- no changes will be made"
        Write-Host ""
    }

    $installedVer = Get-InstalledVersion
    if ($installedVer -ne "not installed") {
        Write-Info "Upgrading from $installedVer -> $sourceVer"
    }

    if (-not (Test-Path $CLAUDE_DIR)) {
        New-Item -ItemType Directory -Path $CLAUDE_DIR -Force | Out-Null
    }

    if ($installAll) {
        Install-ClaudeMd
        Install-Settings
        Install-Rules
        Install-Skills
        Install-Lessons
        Install-Hooks
        # MCP is NOT included in -All; use -Mcp explicitly
        Install-Plugins
    } else {
        if ($ClaudeMd) { Install-ClaudeMd }
        if ($Settings) { Install-Settings }
        if ($Rules -and $Rules.Count -gt 0) { Install-Rules }
        if ($Skills) { Install-Skills }
        if ($Lessons) { Install-Lessons }
        if ($Hooks) { Install-Hooks }
        if ($Mcp) { Install-Mcp }
        if ($Plugins) { Install-Plugins }
    }

    if (-not $DryRun) { Save-VersionStamp }

    Write-Host ""
    Write-Ok "Installation complete! ($sourceVer)"
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "  1. Restart Claude Code for changes to take effect"
    if ($Mcp) {
        Write-Host "  2. Replace YOUR_APP_ID/YOUR_APP_SECRET in Lark MCP config"
    }
    Write-Host "  3. Customize CLAUDE.md for your specific projects"
    Write-Host "  4. Review settings.json and merge with your existing config"
    Write-Host ""
}

Main
