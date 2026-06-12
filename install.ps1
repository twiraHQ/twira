# Twira installer for Windows
# Usage:  irm twira.com/install.ps1 | iex
#
# Runs INSIDE the calling PowerShell session (that is what iex means), which
# buys Windows the thing Unix installers physically cannot have: this script
# may update the CURRENT terminal's PATH directly. So `twira init` works in
# the same window, immediately — plus the user PATH registry entry makes
# every future terminal work too.
#
# Wrapped in a function and invoked once at the bottom: a bare `exit` in an
# iex-ed script would close the user's terminal. Nothing here calls exit.
#
# Opt out of any PATH changes with  $env:TWIRA_NO_MODIFY_PATH = '1'.

function Install-Twira {
    $ErrorActionPreference = 'Stop'

    $Repo = 'TwiraHQ/twira'
    $BinaryName = 'twira'
    $InstallDir = Join-Path $env:USERPROFILE '.twira\bin'

    Write-Host ''
    Write-Host '  Twira - power tools for your AI agents'
    Write-Host '  https://twira.com'
    Write-Host ''

    # Windows PowerShell 5.1 defaults to TLS 1.0; GitHub requires 1.2+.
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    # ── Detect architecture ─────────────────────────────────────────────
    $archRaw = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $archRaw = $env:PROCESSOR_ARCHITEW6432 }
    switch ($archRaw) {
        'AMD64' { $Target = 'x86_64-pc-windows-msvc' }
        'ARM64' { $Target = 'aarch64-pc-windows-msvc' }
        default { throw "Unsupported architecture: $archRaw" }
    }

    # ── Latest version ───────────────────────────────────────────────────
    $release = Invoke-RestMethod -UseBasicParsing `
        -Uri "https://api.github.com/repos/$Repo/releases/latest" `
        -Headers @{ 'User-Agent' = 'twira-installer' }
    $Version = $release.tag_name
    if (-not $Version) { throw 'Could not determine the latest version.' }

    $Archive = "$BinaryName-$Version-$Target.zip"
    $Url = "https://github.com/$Repo/releases/download/$Version/$Archive"

    # ── Download + verify ────────────────────────────────────────────────
    $Tmp = Join-Path $env:TEMP "twira-install-$([guid]::NewGuid().ToString('n').Substring(0,8))"
    New-Item -ItemType Directory -Path $Tmp -Force | Out-Null
    try {
        Write-Host "Downloading Twira $Version for $Target..."
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile (Join-Path $Tmp $Archive)
        Invoke-WebRequest -UseBasicParsing -Uri "$Url.sha256" -OutFile (Join-Path $Tmp "$Archive.sha256")

        Write-Host 'Verifying checksum...'
        $expected = ((Get-Content (Join-Path $Tmp "$Archive.sha256") -Raw).Trim() -split '\s+')[0].ToLower()
        $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $Tmp $Archive)).Hash.ToLower()
        if ($expected -ne $actual) {
            throw "Checksum mismatch for $Archive (expected $expected, got $actual)."
        }
        Write-Host "${Archive}: OK"

        # ── Install ──────────────────────────────────────────────────────
        Expand-Archive -Path (Join-Path $Tmp $Archive) -DestinationPath $Tmp -Force
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        Move-Item -Path (Join-Path $Tmp "$BinaryName.exe") `
                  -Destination (Join-Path $InstallDir "$BinaryName.exe") -Force
    }
    finally {
        Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host "Twira $Version installed to $InstallDir\$BinaryName.exe"
    Write-Host ''

    # ── PATH: current session + future terminals ─────────────────────────
    if ($env:TWIRA_NO_MODIFY_PATH) {
        Write-Host 'TWIRA_NO_MODIFY_PATH is set, so PATH was not touched.'
        Write-Host "Add this directory to your PATH yourself: $InstallDir"
    }
    else {
        # Future terminals: user PATH in the registry, idempotently.
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $userPath) { $userPath = '' }
        if (($userPath -split ';') -notcontains $InstallDir) {
            [Environment]::SetEnvironmentVariable('Path', "$InstallDir;$userPath", 'User')
            Write-Host 'Added Twira to your PATH (new terminals pick it up automatically).'
        }
        else {
            Write-Host 'PATH entry already present.'
        }
    }

    # THIS terminal: iex runs in-session, so this genuinely takes effect now.
    if (($env:Path -split ';') -notcontains $InstallDir) {
        $env:Path = "$InstallDir;$env:Path"
    }
    Write-Host 'twira is ready to use in this terminal.'
    Write-Host ''

    Write-Host 'Get started:'
    Write-Host '  twira init       # set up Twira in your repo (wires your AI agent)'
    Write-Host '  twira index      # build the local code graph'
    Write-Host '  twira dashboard  # open the dashboard in your browser'
    Write-Host ''
}

Install-Twira
