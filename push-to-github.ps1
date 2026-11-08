#requires -Version 5.1
<#
  一键把本插件推送到你的 GitHub 仓库。
  用法：双击 push-to-github.cmd；或 push-to-github.cmd -Owner 你的GitHub用户名 -Repo dsh-ecommerce-analysis
  首次运行会询问一次 git 身份（名字/邮箱）和 GitHub 用户名，之后自动记住（存于本仓库 .git/config）。
  推送到 GitHub 时会由 Git Credential Manager 弹出浏览器登录授权（只需一次）。
  每次运行的完整输出会写入 push-to-github.log，便于排查失败原因。
#>
[CmdletBinding()]
param(
    [string]$Owner,
    [string]$Repo = 'dsh-ecommerce-analysis',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
$OutputEncoding = [Text.UTF8Encoding]::new($false)

Set-Location $PSScriptRoot

$logPath = Join-Path $PWD 'push-to-github.log'
try { Start-Transcript -Path $logPath -Force | Out-Null } catch {}

function Fail([string]$Message) {
    Write-Host ''
    Write-Host ('✗ ' + $Message) -ForegroundColor Red
    Write-Host ('  完整日志见：' + $logPath) -ForegroundColor Yellow
    Write-Host ''
    Read-Host '按回车键退出' | Out-Null
    exit 1
}
function Info([string]$Message) { Write-Host ('→ ' + $Message) }
function Ok([string]$Message) { Write-Host ('✓ ' + $Message) -ForegroundColor Green }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail '未找到 git，请先安装 Git for Windows：https://git-scm.com/download/win'
}

# ---------- 1. git 身份（只问一次） ----------
$name = $null
$email = $null
try { $name = (git config --local user.name) } catch {}
try { $email = (git config --local user.email) } catch {}
if (-not $name) {
    try { $name = (git config --global user.name) } catch {}
}
if (-not $email) {
    try { $email = (git config --global user.email) } catch {}
}
if (-not $name) {
    $name = Read-Host '请输入提交用的名字 (git user.name，如 GitHub 用户名)'
    if (-not $name) { Fail '名字不能为空' }
    git config --local user.name $name | Out-Null
}
if (-not $email) {
    $email = Read-Host '请输入提交用的邮箱 (git user.email，如 GitHub 邮箱)'
    if (-not $email) { Fail '邮箱不能为空' }
    git config --local user.email $email | Out-Null
}

# ---------- 2. GitHub 用户名 / 仓库名 ----------
if (-not $Owner) { try { $Owner = (git config --local dsh.githubOwner) } catch {} }
if (-not $Owner) {
    $Owner = Read-Host '请输入你的 GitHub 用户名（仓库会建在这个账号下）'
}
if ($Owner -notmatch '^[A-Za-z0-9-]+$') { Fail ('GitHub 用户名不合法：' + $Owner) }
try { $savedRepo = (git config --local dsh.githubRepo) } catch {}
if (-not $savedRepo) { git config --local dsh.githubRepo $Repo | Out-Null } elseif ($savedRepo -ne $Repo) { $Repo = $savedRepo }

# ---------- 3. 初始化仓库 ----------
$gitDir = $null
try { $gitDir = (git rev-parse --git-dir 2>$null) } catch {}
if (-not $gitDir) {
    Info '初始化 git 仓库（main 分支）...'
    git init -b main | Out-Null
}
if (-not (git config --local user.name)) { git config --local user.name $name | Out-Null }
if (-not (git config --local user.email)) { git config --local user.email $email | Out-Null }

$remoteUrl = 'https://github.com/' + $Owner + '/' + $Repo + '.git'
$existingRemote = $null
try { $existingRemote = (git remote get-url origin 2>$null) } catch {}
if ($existingRemote) {
    if ($existingRemote -ne $remoteUrl) {
        Write-Host ('⚠ 当前 origin 为：' + $existingRemote) -ForegroundColor Yellow
        if (-not $DryRun) {
            $ans = Read-Host ('是否改为 ' + $remoteUrl + ' ? [y/N]')
            if ($ans -match '^(y|Y)') { git remote set-url origin $remoteUrl } else { Fail '已取消，origin 未修改。' }
        }
    }
} else {
    Info ('添加 origin → ' + $remoteUrl)
    git remote add origin $remoteUrl | Out-Null
}

# ---------- 4. 写入 package.json 的 repository ----------
Info '更新 package.json 的 repository 字段...'
try {
    $pkgPath = Join-Path $PWD 'package.json'
    $pkg = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $pkg.repository = [pscustomobject]@{ type = 'git'; url = ('git+https://github.com/' + $Owner + '/' + $Repo + '.git') }
    $json = $pkg | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText($pkgPath, $json, [Text.UTF8Encoding]::new($false))
} catch {
    Fail ('写入 package.json 失败：' + $_.Exception.Message)
}

# ---------- 5. 提交 ----------
Info '暂存并提交改动...'
git add -A | Out-Null
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -m 'Release v1.1.0' | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail 'git commit 失败' }
    Ok '已创建提交'
} else {
    Info '没有需要提交的改动'
}

# ---------- 6. 填充市场条目模板 ----------
$yamlPath = Join-Path $PWD 'market\awesome-dsh-plugin-entry.yml'
if (Test-Path $yamlPath) {
    $yaml = Get-Content $yamlPath -Raw -Encoding UTF8
    $yaml = $yaml.Replace('OWNER', $Owner).Replace('REPO', $Repo)
    [IO.File]::WriteAllText($yamlPath, $yaml, [Text.UTF8Encoding]::new($false))
}

if ($DryRun) {
    Ok 'DryRun 完成：仓库已初始化/提交，未执行推送。'
    Write-Host ('  将推送到：' + $remoteUrl)
    exit 0
}

# ---------- 7. 推送 ----------
Info ('推送到 ' + $remoteUrl + ' ...（首次弹出浏览器时请登录 GitHub 授权）')
$pushOut = ''
try {
    # 用 cmd /c 包一层：git 的进度/拒绝信息走的是 stderr，PowerShell 5.1 在
    # ErrorActionPreference=Stop 下会把 stderr 当终止错误，导致只截到第一行就中断。
    # cmd /c 把 stderr 合并进 stdout，PowerShell 只看到普通文本，$LASTEXITCODE 仍是 git 的退出码。
    $pushOut = (cmd /c 'git push -u origin main 2>&1' | Out-String)
} catch {
    $pushOut = $_.Exception.Message
    if (-not $pushOut) { $pushOut = 'git push 未返回任何输出（网络或凭据问题）' }
}
$pushOut = $pushOut -replace "`r", "`n"
$pushed = $false
if ($LASTEXITCODE -ne 0) {
    Write-Host $pushOut
    if ($pushOut -match 'Repository not found|does not appear to be a git repository') {
        Write-Host ''
        Write-Host '远端仓库不存在。请先到以下地址创建空仓库（不要勾选 README / .gitignore），然后重新运行：' -ForegroundColor Yellow
        Write-Host ('  https://github.com/new?name=' + $Repo)
    } elseif ($pushOut -match 'Authentication failed|could not read Username|terminal prompts disabled|403') {
        Write-Host ''
        Write-Host '认证失败或权限不足。请确认：' -ForegroundColor Yellow
        Write-Host '  - Git Credential Manager 已安装并能弹出浏览器登录；'
        Write-Host '  - 登录的 GitHub 账号就是 ' + $Owner + '（多账号会缓存错账号）。'
        Write-Host '  可用 Personal Access Token 代替：https://github.com/settings/tokens'
    } elseif ($pushOut -match 'GH007|private email|email privacy') {
        Write-Host ''
        Write-Host 'GitHub 认为提交邮箱是私有邮箱，拒绝发布（GH007）。' -ForegroundColor Yellow
        Write-Host '  修复：把提交邮箱改成 GitHub 的 noreply 地址：' -ForegroundColor Yellow
        Write-Host '  1) 打开 https://github.com/settings/emails ，复制 Keep my email private 下显示的邮箱；'
        Write-Host '  2) git config user.email "<复制的邮箱>"'
        Write-Host '  3) git commit --amend --reset-author --no-edit'
        Write-Host '  4) 重新运行本脚本。'
    } elseif ($pushOut -match 'rejected|non-fast-forward|fetch first|needs merge') {
        Write-Host ''
        Write-Host '远端已有内容，推送被拒绝。正在检查远端内容...' -ForegroundColor Yellow
        cmd /c 'git fetch origin main 2>&1' | Out-Null
        $remoteCommits = 0
        try { $remoteCommits = [int](cmd /c 'git rev-list --count origin/main 2>&1') } catch {}
        $remoteFiles = @()
        try { $remoteFiles = @(cmd /c 'git ls-tree --name-only origin/main 2>&1') } catch {}
        $unexpected = @($remoteFiles | Where-Object { $_ -notmatch '^(README(\.md)?|LICENSE|\.gitignore|\.gitattributes)$' })
        if ($remoteCommits -eq 1 -and $unexpected.Count -eq 0) {
            Write-Host ('远端只有一个 GitHub 自动生成的 Initial commit（文件：' + ($remoteFiles -join ', ') + '），没有需要保留的内容。') -ForegroundColor Yellow
            $ans = Read-Host '是否用本地内容覆盖推送？（新建仓库场景推荐 y）[Y/n]'
            if ($ans -match '^(y|Y|)$') {
                Info '强制推送，覆盖远端自动生成的 Initial commit...'
                cmd /c 'git push -u origin main --force 2>&1' | Write-Host
                if ($LASTEXITCODE -eq 0) { $pushed = $true; Ok '已覆盖推送' }
            }
        } else {
            Write-Host '远端已有真实内容，脚本不会强行覆盖。请先同步远端内容，或换一个仓库名重试。' -ForegroundColor Yellow
        }
    } elseif ($pushOut -match 'schannel|SEC_E_NO_CREDENTIALS|unable to access|could not resolve') {
        Write-Host ''
        Write-Host '与 GitHub 的网络/TLS 连接失败。请检查网络或代理；可尝试在终端里手动运行：' -ForegroundColor Yellow
        Write-Host '  git push -u origin main'
    }
    if (-not $pushed) {
        Fail '推送失败（详见上方输出）。修好后重新运行本脚本即可，已提交的改动会保留。'
    }
}

Ok ('推送成功：https://github.com/' + $Owner + '/' + $Repo)
Write-Host ''
Write-Host '下一步（发布到插件市场）：'
Write-Host '  1. 打开 https://github.com/awesome-dsh-plugin/awesome-dsh-plugin 并 Fork'
Write-Host ('  2. 新建文件 data/plugins/' + $Owner + '__' + $Repo + '.yml，内容复制 market\awesome-dsh-plugin-entry.yml')
Write-Host '  3. 提交 PR，等待合并（通常一天内市场可见）'
Write-Host ''
Read-Host '完成，按回车键退出' | Out-Null