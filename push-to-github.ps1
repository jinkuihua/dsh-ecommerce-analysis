#requires -Version 5.1
<#
  一键把本插件推送到你的 GitHub 仓库。
  用法：双击 push-to-github.cmd；或 push-to-github.cmd -Owner 你的GitHub用户名 -Repo dsh-ecommerce-analysis
  首次运行会询问一次 git 身份（名字/邮箱）和 GitHub 用户名，之后自动记住（存于本仓库 .git/config）。
  推送到 GitHub 时会由 Git Credential Manager 弹出浏览器登录授权（只需一次）。
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

function Fail([string]$Message) {
    Write-Host ''
    Write-Host ('✗ ' + $Message) -ForegroundColor Red
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
    $pushOut = (git push -u origin main 2>&1 | Out-String)
} catch {
    $pushOut = $_.Exception.Message
}
if ($LASTEXITCODE -ne 0) {
    Write-Host $pushOut
    if ($pushOut -match 'Repository not found|does not appear to be a git repository') {
        Write-Host ''
        Write-Host '远端仓库不存在。请先到以下地址创建空仓库（不要勾选 README / .gitignore），然后重新运行：' -ForegroundColor Yellow
        Write-Host ('  https://github.com/new?name=' + $Repo)
    } elseif ($pushOut -match 'Authentication failed|could not read Username|terminal prompts disabled') {
        Write-Host ''
        Write-Host '认证失败。请确认 Git Credential Manager 可用，或配置 Personal Access Token（https://github.com/settings/tokens）。' -ForegroundColor Yellow
    } elseif ($pushOut -match 'rejected|non-fast-forward|fetch first') {
        Write-Host ''
        Write-Host '远端已有内容，推送被拒绝。本脚本不会强制覆盖；请先同步远端内容，或换一个仓库名重试。' -ForegroundColor Yellow
    }
    Fail '推送失败（详见上方输出）。修好后重新运行本脚本即可，已提交的改动会保留。'
}

Ok ('推送成功：https://github.com/' + $Owner + '/' + $Repo)
Write-Host ''
Write-Host '下一步（发布到插件市场）：'
Write-Host '  1. 打开 https://github.com/awesome-dsh-plugin/awesome-dsh-plugin 并 Fork'
Write-Host ('  2. 新建文件 data/plugins/' + $Owner + '__' + $Repo + '.yml，内容复制 market\awesome-dsh-plugin-entry.yml')
Write-Host '  3. 提交 PR，等待合并（通常一天内市场可见）'
Write-Host ''
Read-Host '完成，按回车键退出' | Out-Null
