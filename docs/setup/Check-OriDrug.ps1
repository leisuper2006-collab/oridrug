#requires -Version 5.1
[CmdletBinding()]
param([string]$ReportPath)

if (!$ReportPath) { $ReportPath = Join-Path $PSScriptRoot 'OriDrug-environment.json' }

$ErrorActionPreference = 'Stop'
$checks = New-Object System.Collections.ArrayList
$dockerGuide = 'https://docs.docker.com/desktop/setup/install/windows-install/'
$wslGuide = 'https://learn.microsoft.com/zh-cn/windows/wsl/basic-commands'
$virtualGuide = 'https://support.microsoft.com/windows/enable-virtualization-on-windows-c5578302-6e43-4b4b-a449-8ced115f58e1'

function Add-Check($Id, $Status, $Detail, $Next = '') {
    [void]$checks.Add([ordered]@{ id = $Id; status = $Status; detail = $Detail; next = $Next })
}

# Read stdout and stderr concurrently. Older WSL versions write UTF-16 even when redirected.
function Read-Tool([string]$File, [string]$Arguments) {
    $proc = New-Object System.Diagnostics.Process
    try {
        $proc.StartInfo.FileName = $File
        $proc.StartInfo.Arguments = $Arguments
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.CreateNoWindow = $true
        $proc.StartInfo.RedirectStandardInput = $true
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError = $true
        [void]$proc.Start()
        $proc.StandardInput.Close()
        $readOutput = $proc.StandardOutput.ReadToEndAsync()
        $readError = $proc.StandardError.ReadToEndAsync()
        if (!$proc.WaitForExit(7000)) {
            try { $proc.Kill() } catch {}
            return ''
        }
        $result = $readOutput.GetAwaiter().GetResult()
        [void]$readError.GetAwaiter().GetResult()
        if ($proc.ExitCode -eq 0) { return $result.Replace([string][char]0, '').Trim() }
    } catch {
        return ''
    } finally {
        $proc.Dispose()
    }
    return ''
}

function Read-Hardware($ClassName, $Filter) {
    $arguments = @{ ClassName = $ClassName; ErrorAction = 'SilentlyContinue'; OperationTimeoutSec = 5 }
    if ($Filter) { $arguments.Filter = $Filter }
    Get-CimInstance @arguments
}

function Find-Docker {
    $fromPath = Get-Command docker.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($fromPath) { return $fromPath.Source }
    $directories = @(
        (Join-Path $env:ProgramFiles 'Docker\Docker')
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop')
    )
    foreach ($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Docker Desktop'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Docker Desktop'
    )) {
        $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($entry -and $entry.InstallLocation) { $directories += $entry.InstallLocation }
    }
    foreach ($directory in $directories) {
        $candidate = Join-Path $directory 'resources\bin\docker.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
}

Write-Host 'OriDrug 正在读取本机配置与软件版本…'
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$machine = Read-Hardware Win32_ComputerSystem
$cpu = @(Read-Hardware Win32_Processor) | Select-Object -First 1
$physicalChips = @(Read-Hardware Win32_PhysicalMemory)
$build = [int]$windows.CurrentBuildNumber
$release = [string]$windows.DisplayVersion
$windowsFamily = if ($build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
$supportedBuild = $build -ge 22631 -or ($build -ge 19045 -and $build -lt 22000)
if (!$windows -or !$build) {
    Add-Check windows review 'Windows 版本需要核对。' '运行 winver，与 Docker Desktop 的系统要求核对。'
} elseif ($windows.InstallationType -ne 'Client' -or !$supportedBuild) {
    Add-Check windows unsupported "检测到 Windows $release（内部版本 $build）。" '本机启动包面向桌面版 Windows 10 22H2 或 Windows 11 23H2 及以上。可先使用云端工作台。'
} else {
    Add-Check windows ready "$windowsFamily $release（内部版本 $build），符合系统版本下限。" '可在 Docker 官方系统要求中核对 Windows 版本的支持周期。'
}

$architecture = $env:PROCESSOR_ARCHITEW6432
if (!$architecture) { $architecture = $env:PROCESSOR_ARCHITECTURE }
if ($null -ne $cpu.Architecture) {
    switch ($cpu.Architecture) { 9 { $architecture = 'AMD64' } 12 { $architecture = 'ARM64' } 0 { $architecture = 'x86' } }
}
if (!$architecture) {
    Add-Check architecture review '未读取到处理器架构。' '打开“设置 → 系统 → 系统信息”，查看系统类型。'
} elseif ($architecture -eq 'AMD64') {
    Add-Check architecture ready 'x86-64 处理器，与 OriDrug 的 Linux x86-64 镜像匹配。'
} else {
    Add-Check architecture unsupported "检测到 $architecture 处理器，当前本机启动包使用 x86-64 镜像。" '可在 GitHub Codespaces 中使用完整工作台。'
}

$installedBytes = ($physicalChips | Measure-Object Capacity -Sum).Sum
if (!$installedBytes) { $installedBytes = $machine.TotalPhysicalMemory }
if (!$installedBytes) {
    Add-Check memory review '未读取到内存容量。' '打开“设置 → 系统 → 系统信息”，核对已安装内存是否达到 8 GB。'
} else {
    $ram = [Math]::Round($installedBytes / 1GB, 1)
    if ($ram -ge 8) { Add-Check memory ready "物理内存 $ram GB。" }
    elseif (!$physicalChips.Count -and $ram -ge 7) { Add-Check memory review "操作系统可用内存 $ram GB。" '请在设备规格中核对物理内存是否达到 8 GB。' }
    else { Add-Check memory unsupported "物理内存 $ram GB，低于 Docker Desktop 的 8 GB 要求。" '可改用云端工作台。' }
}
if ($machine.HypervisorPresent) {
    Add-Check virtualization ready 'Windows 虚拟机监控程序已在运行。'
} elseif ($cpu.SecondLevelAddressTranslationExtensions -eq $false) {
    Add-Check virtualization unsupported '处理器未报告二级地址转换（SLAT）支持。' '请核对 CPU 规格；虚拟机用户可请管理员开放嵌套虚拟化。'
} elseif ($cpu.VirtualizationFirmwareEnabled -eq $true -and $cpu.SecondLevelAddressTranslationExtensions -eq $true) {
    Add-Check virtualization ready '硬件虚拟化已开启，处理器支持二级地址转换。'
} elseif ($cpu.VirtualizationFirmwareEnabled -eq $false) {
    Add-Check virtualization action '固件中的硬件虚拟化尚未启用。' '按微软指南在 UEFI/BIOS 打开虚拟化，再重启电脑。'
} else {
    Add-Check virtualization review '需要核对硬件虚拟化。' '打开“任务管理器 → 性能 → CPU”查看虚拟化状态，并核对处理器的 SLAT 支持。'
}

$serverService = Read-Hardware Win32_Service "Name = 'LanmanServer'"
if (!$serverService) {
    Add-Check service review '未读取到 Windows Server 服务状态。' '在“服务”中核对 Server（LanmanServer）使用自动启动。'
} elseif ($serverService.StartMode -eq 'Auto' -and $serverService.State -eq 'Running') {
    Add-Check service ready 'Windows Server 服务正在运行，启动类型为自动。'
} else {
    Add-Check service action 'Windows Server 服务需要自动启动并运行。' '在“服务”中将 Server（LanmanServer）设为自动，启动后重新检测。'
}

$platform = Read-Hardware Win32_OptionalFeature "Name = 'VirtualMachinePlatform'"
if (!$platform -or $platform.InstallState -eq 4) {
    Add-Check platform review '未读取到虚拟机平台功能状态。' '在“启用或关闭 Windows 功能”中核对“虚拟机平台”。'
} elseif ($platform.InstallState -eq 1) {
    Add-Check platform ready 'Windows 已启用“虚拟机平台”。'
} else {
    Add-Check platform action 'Windows 的“虚拟机平台”需要启用。' '按微软 WSL 安装步骤启用功能，依系统提示重启。'
}

$wslCommand = Get-Command wsl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$wslText = if ($wslCommand) { Read-Tool $wslCommand.Source '--version' }
$versionMatch = [regex]::Match([string]$wslText, '(?im)^\s*WSL[^\r\n]*?(\d+\.\d+\.\d+(?:\.\d+)?)')
if ($versionMatch.Success) {
    $wslVersion = [version]$versionMatch.Groups[1].Value
    if ($wslVersion -ge [version]'2.1.5') { Add-Check wsl ready "WSL $wslVersion，达到 Docker 的 2.1.5 要求。" }
    else { Add-Check wsl action "已安装 WSL $wslVersion，需要 2.1.5 或更新。" '在管理员 PowerShell 中运行 wsl --update，按提示重启。' }
} else {
    Add-Check wsl action '未检测到可报告版本的现代 WSL。' '首次安装可在管理员 PowerShell 中运行 wsl --install --no-distribution；已有 WSL 可运行 wsl --update。'
}

$docker = Find-Docker
if (!$docker) {
    Add-Check docker action '未找到 Docker 命令。' '从 Docker 官方 Windows 安装页下载 Docker Desktop，选择 WSL 2 引擎并打开应用。'
    Add-Check engine review '等待检测本机 Linux 容器引擎。' '打开 Docker Desktop 后重新检测。'
    Add-Check compose review '等待检测 Docker Compose。' 'Docker Desktop 自带 Compose，安装并启动后重新检测。'
} else {
    $cli = Read-Tool $docker '--version'
    $cliVersion = [regex]::Match([string]$cli, '\d+(?:\.\d+)+')
    if ($cliVersion.Success) { Add-Check docker ready ("Docker 客户端 " + $cliVersion.Value + '。') }
    else { Add-Check docker action '已找到 Docker 客户端，但读取版本失败。' '打开 Docker Desktop，按官方指南修复安装并重试。' }

    # Only probe a Docker engine on this machine's named pipe. Remote contexts remain untouched.
    $endpoint = if ($env:DOCKER_HOST -and !$env:DOCKER_CONTEXT) { $env:DOCKER_HOST }
                else { Read-Tool $docker 'context inspect --format "{{.Endpoints.docker.Host}}"' }
    if ($endpoint -and $endpoint -notmatch '^npipe:/+\./pipe/') {
        Add-Check engine review '当前 Docker 连接没有指向本机的 Windows 命名管道。' '在 Docker Desktop 中切换至本机 Linux 引擎后重新检测。'
    } elseif (!$endpoint) {
        Add-Check engine review '当前 Docker 连接尚未就绪。' '打开 Docker Desktop，等引擎启动后重新检测。'
    } else {
        $engine = Read-Tool $docker 'version --format "{{.Server.Os}}/{{.Server.Arch}} {{.Server.Version}}"'
        if ($engine -match '^linux/(amd64|x86_64) ([\d.]+)') {
            Add-Check engine ready ("本机 Linux x86-64 引擎已启动，版本 " + $Matches[2] + '。')
        } elseif ($engine -match '^windows/') {
            Add-Check engine action 'Docker 当前使用 Windows 容器。' '打开 Docker Desktop，将容器模式切换为 Linux containers。'
        } elseif ($engine -match '^linux/') {
            Add-Check engine unsupported '当前 Linux 引擎的处理器架构与 x86-64 运行包不同。' '可选择 x86-64 Linux 环境，或进入云端工作台。'
        } else {
            Add-Check engine action 'Docker 客户端可用，Linux 引擎尚未响应。' '打开 Docker Desktop，选择 WSL 2 引擎，等待启动完成后重新检测。'
        }
    }
    $composeText = Read-Tool $docker 'compose version --short'
    $composeVersion = [regex]::Match([string]$composeText, '\d+(?:\.\d+)+')
    if ($composeVersion.Success -and [version]$composeVersion.Value -ge [version]'2.0') {
        Add-Check compose ready ("Docker Compose " + $composeVersion.Value + '。')
    } else {
        Add-Check compose action 'Docker Compose v2 或更新版本尚未就绪。' '从 Docker 官方安装页更新 Docker Desktop，并重新检查。'
    }
}

$report = [ordered]@{
    format = 'oridrug.environment.v1'
    checkedAt = [DateTime]::UtcNow.ToString('o')
    checks = @($checks)
}
$labels = @{ ready = '已就绪'; action = '需设置'; review = '待复核'; unsupported = '需更换环境' }
foreach ($check in $checks) {
    Write-Host ('[' + $labels[$check.status] + '] ' + $check.detail)
    if ($check.next -and $check.status -ne 'ready') { Write-Host ('  ' + $check.next) }
}
try {
    $outputPath = [IO.Path]::GetFullPath($ReportPath)
    [IO.File]::WriteAllText($outputPath, (ConvertTo-Json -InputObject $report -Depth 5), (New-Object Text.UTF8Encoding($false)))
    Write-Host ('结果文件：' + $outputPath)
    Write-Host '回到 OriDrug 的环境检查区，点“导入检测结果”查看下一步。'
} catch {
    Write-Error '结果文件保存失败。请将检测工具解压至可写文件夹后重试。' -ErrorAction Continue
    exit 2
}
if (@($checks | Where-Object { $_.status -ne 'ready' }).Count) {
    Write-Host ('Docker 官方安装：' + $dockerGuide)
    Write-Host ('微软 WSL 指南：' + $wslGuide)
    Write-Host ('硬件虚拟化指南：' + $virtualGuide)
}
