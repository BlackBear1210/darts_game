param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('api', 'server', 'player')]
    [string]$Role,
    [string]$PythonExe = 'python',
    [ValidateRange(1024, 65535)][int]$ApiPort = 8080,
    [ValidateRange(1024, 65535)][int]$GamePort = 7000
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$apiUrl = "http://127.0.0.1:$ApiPort"

if ($Role -ne 'player') {
    $dataPath = Join-Path $PSScriptRoot 'data'
    New-Item -ItemType Directory -Force -Path $dataPath | Out-Null
    $keyPath = Join-Path $dataPath 'server_key.txt'
    if (-not (Test-Path -LiteralPath $keyPath)) {
        $keyBytes = [byte[]]::new(32)
        $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $generator.GetBytes($keyBytes) } finally { $generator.Dispose() }
        $serverKey = [BitConverter]::ToString($keyBytes).Replace('-', '').ToLowerInvariant()
        [IO.File]::WriteAllText($keyPath, $serverKey, [Text.UTF8Encoding]::new($false))
    }
    $env:DART_SERVER_KEY = [IO.File]::ReadAllText($keyPath).Trim()
}

switch ($Role) {
    'api' {
        & $PythonExe (Join-Path $PSScriptRoot 'server.py') --dev --port $ApiPort
    }
    'server' {
        $serverExe = Join-Path $projectRoot 'output/builds/server/DartPartyServer.console.exe'
        if (-not (Test-Path -LiteralPath $serverExe)) { throw 'Windows Server 빌드가 필요합니다.' }
        & $serverExe -- --backend-url $apiUrl --port $GamePort
    }
    'player' {
        $playerExe = Join-Path $projectRoot 'output/builds/client/DartParty.exe'
        if (-not (Test-Path -LiteralPath $playerExe)) { throw 'Windows Client 빌드가 필요합니다.' }
        & $playerExe -- --normal --backend-url $apiUrl --port $GamePort
    }
}
