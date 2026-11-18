[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)][int]$Port = 8789,
    [ValidatePattern('^[a-z0-9][a-z0-9_-]*$')][string]$ProjectName = 'oridrug-personal',
    [string]$ImageDirectory,
    [switch]$NoBrowser,
    [switch]$Stop
)

$ErrorActionPreference = 'Stop'
$releaseUrl = 'https://github.com/leisuper2006-collab/oridrug/releases/download/v0.7.1'
$installGuide = 'https://docs.docker.com/desktop/setup/install/windows-install/'
$workingDirectory = if ($env:ORIDRUG_HOME) { $env:ORIDRUG_HOME } else { Join-Path $PSScriptRoot '.oridrug' }
$composeFile = Join-Path $PSScriptRoot 'compose.yaml'
$manifestPath = Join-Path $PSScriptRoot 'images.lock'
$imageCache = Join-Path $workingDirectory 'downloads'
$instanceDirectory = Join-Path $workingDirectory $ProjectName
$instanceConfig = Join-Path $instanceDirectory 'instance.env'
$baseUrl = "http://127.0.0.1:$Port"
$dockerCommand = Get-Command docker.exe -ErrorAction SilentlyContinue
if (-not $dockerCommand) {
    $standardDocker = Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe'
    if (Test-Path -LiteralPath $standardDocker) { $dockerCommand = Get-Item -LiteralPath $standardDocker }
}
if (-not $dockerCommand) { throw "请安装 Docker Desktop，启动后重新打开本程序。$installGuide" }
$docker = if ($dockerCommand.Source) { $dockerCommand.Source } else { $dockerCommand.FullName }

function Invoke-Docker {
    param([string[]]$Arguments)
    & $docker @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Docker 操作失败，请查看上方的说明。" }
}

function New-RandomValue {
    param([int]$ByteCount)
    $bytes = New-Object byte[] $ByteCount
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
    [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_')
}

function Get-ImageLayers {
    param([string]$Tag)
    $present = Invoke-Docker -Arguments @('image', 'ls', '--quiet', $Tag)
    if (-not $present) { return '' }
    $layers = Invoke-Docker -Arguments @('image', 'inspect', '--format', '{{range .RootFS.Layers}}{{.}} {{end}}', $Tag)
    (($layers -join ' ').Trim() -split '\s+') -join ','
}

function Test-ArchiveHash {
    param([string]$Path, [string]$Expected)
    (Test-Path -LiteralPath $Path -PathType Leaf) -and ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $Expected)
}

function Import-ReleaseImages {
    $rows = @(Get-Content -LiteralPath $manifestPath -Encoding ASCII | Where-Object { $_ } | ConvertFrom-Csv -Delimiter "`t" -Header File,Sha256,Tag,Layers)
    if ($rows.Count -ne 3) { throw '请使用完整的启动包，缺少镜像清单。' }
    foreach ($group in ($rows | Group-Object File)) {
        $file = $group.Name
        $expectedHash = $group.Group[0].Sha256
        $needsImport = $false
        foreach ($item in $group.Group) {
            $actual = Get-ImageLayers $item.Tag
            if (-not $actual) { $needsImport = $true }
            elseif ($actual -ne $item.Layers) { throw "Docker 中已有内容不同的同名镜像 $($item.Tag)。请先为原镜像另存标签，再重新导入发行包。" }
        }
        if (-not $needsImport) { continue }
        $archive = if ($ImageDirectory) { Join-Path $ImageDirectory $file } else { Join-Path $imageCache $file }
        if (-not (Test-ArchiveHash $archive $expectedHash)) {
            if ($ImageDirectory) { throw "离线文件 $file 缺失或校验失败。请从 OriDrug 的 v0.7.1 Release 重新下载。" }
            Write-Host "正在从 GitHub 下载 $file"
            $partial = "$archive.$([guid]::NewGuid().ToString('N')).partial"
            try {
                $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
                if ($curl) {
                    & $curl.Source --fail --location --retry 3 --connect-timeout 20 --output $partial --url "$releaseUrl/$file"
                    if ($LASTEXITCODE -ne 0) { throw '下载中断。请检查网络后重新运行，已校验的文件可以继续使用。' }
                } else {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    Invoke-WebRequest -UseBasicParsing -Uri "$releaseUrl/$file" -OutFile $partial
                }
                if (-not (Test-ArchiveHash $partial $expectedHash)) { throw "$file 下载校验失败，请重新运行。" }
                Move-Item -LiteralPath $partial -Destination $archive -Force
            } finally {
                if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial }
            }
        }
        Write-Host "正在导入 $file"
        Invoke-Docker -Arguments @('image', 'load', '--input', $archive)
        foreach ($item in $group.Group) {
            if ((Get-ImageLayers $item.Tag) -ne $item.Layers) { throw "导入的镜像与清单不符：$($item.Tag)" }
        }
    }
}

function Write-InstanceConfiguration {
    if (Test-Path -LiteralPath $instanceConfig -PathType Leaf) { return }
    $existingDatabase = Invoke-Docker -Arguments @('volume', 'ls', '--quiet', '--filter', "label=com.docker.compose.project=$ProjectName", '--filter', 'label=com.docker.compose.volume=database')
    if ($existingDatabase) { throw "找到了已有的工作台数据库。请用首次启动时的目录打开，或恢复该实例的 .oridrug 配置文件后重试。" }
    $lines = @(
        "ORIDRUG_DATABASE_KEY=$(New-RandomValue 36)",
        "ORIDRUG_DJANGO_KEY=$(New-RandomValue 48)",
        "ORIDRUG_ENCRYPTION_KEY=$(New-RandomValue 32)"
    )
    $temporary = Join-Path $instanceDirectory "$([guid]::NewGuid().ToString('N')).env.tmp"
    try {
        [IO.File]::WriteAllLines($temporary, $lines, [Text.Encoding]::ASCII)
        [IO.File]::Move($temporary, $instanceConfig)
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
}

$engine = (& $docker version --format '{{.Server.Os}}/{{.Server.Arch}}' | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $engine -ne 'linux/amd64') { throw "请打开 Docker Desktop 并切换到 Linux 容器（x86-64）。$installGuide" }
$null = Invoke-Docker -Arguments @('compose', 'version', '--short')
foreach ($folder in @($instanceDirectory, $imageCache)) {
    $null = New-Item -ItemType Directory -Path $folder -Force
}
$launchLock = Join-Path $instanceDirectory 'launch.lock'
try {
    $exclusive = [IO.File]::Open($launchLock, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
} catch {
    throw '该工作台已有启动程序正在运行，请稍候。'
}
try {
    $env:ORIDRUG_PORT = "$Port"
    $env:ORIDRUG_ALLOWED_HOSTS = '127.0.0.1,localhost,api'
    $env:ORIDRUG_HTTPS = '0'
    $env:ORIDRUG_FORWARDED_HOST = ''
    $env:ORIDRUG_FORWARD_PROTO = 'http'
    $compose = @('compose', '--project-name', $ProjectName, '--env-file', $instanceConfig, '--file', $composeFile)
    if ($Stop) {
        if (-not (Test-Path -LiteralPath $instanceConfig)) { Write-Host '这个目录还没有启动过工作台。'; return }
        Invoke-Docker -Arguments ($compose + @('stop'))
        Write-Host '工作台已停止，项目和账号已保留。'
        return
    }
    $owners = @(Invoke-Docker -Arguments @('ps', '--filter', "publish=$Port", '--format', '{{.Names}}'))
    if ($owners.Count -gt 0 -and $owners -notcontains "$ProjectName-web-1") { throw "端口 $Port 已被其他容器占用。你可以打开已有工作台，或以 -Port 8790 使用不同端口。" }
    if (-not $owners.Count) {
        $listener = New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Loopback), $Port
        try { $listener.Start() } catch { throw "端口 $Port 正在使用。请换用空闲端口，例如 -Port 8790。" } finally { $listener.Stop() }
    }
    Import-ReleaseImages
    Write-InstanceConfiguration
    Write-Host '正在准备数据库并启动研究工作台…'
    Invoke-Docker -Arguments ($compose + @('up', '--detach'))
    $ready = $false
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        try {
            $request = [Net.HttpWebRequest]::Create("$baseUrl/api/health/")
            $request.Proxy = $null
            $request.Timeout = 2000
            $response = $request.GetResponse()
            try {
                $reader = New-Object IO.StreamReader ($response.GetResponseStream())
                try { $status = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
                $ready = $status.status -eq 'ok'
            } finally { $response.Close() }
        } catch {}
        if ($ready) { break }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) { throw '工作台仍在初始化，请重新运行启动器查看服务状态。' }
    Write-Host "工作台已就绪。打开 $baseUrl 并点「注册」，就能建立自己的项目。"
    if (-not $NoBrowser) { Start-Process "$baseUrl/" }
} finally {
    $exclusive.Dispose()
}
