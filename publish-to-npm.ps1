<#
  可选：把插件发布到 npm（市场收录推荐）。
  用法：双击 publish-to-npm.cmd
  首次运行会执行 npm login（浏览器打开 npm 登录页）。
#>
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
Set-Location $PSScriptRoot

function Fail([string]$Message) {
    Write-Host ''
    Write-Host ('✗ ' + $Message) -ForegroundColor Red
    Read-Host '按回车键退出' | Out-Null
    exit 1
}
function Info([string]$Message) { Write-Host ('→ ' + $Message) }

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Fail '未找到 npm，请先安装 Node.js。' }

$pkg = Get-Content (Join-Path $PWD 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Info ('包名：' + $pkg.name + '  版本：' + $pkg.version)
if ($pkg.private) { Fail 'package.json 仍标记 private，不能发布。' }

$who = $null
try { $who = (npm whoami 2>$null) } catch {}
if (-not $who) {
    Info '未登录 npm，先执行 npm login ...'
    npm login
    if ($LASTEXITCODE -ne 0) { Fail 'npm login 失败' }
    $who = (npm whoami 2>$null)
}
Info ('当前 npm 用户：' + $who)

Info '执行 npm publish --access public ...'
npm publish --access public
if ($LASTEXITCODE -ne 0) { Fail 'npm publish 失败（详见上方输出）。' }

Write-Host ''
Write-Host ('✓ 已发布：https://www.npmjs.com/package/' + $pkg.name) -ForegroundColor Green
Write-Host '下一步：在 awesome-dsh-plugin 提交条目（见 market\awesome-dsh-plugin-entry.yml）。'
Read-Host '完成，按回车键退出' | Out-Null
