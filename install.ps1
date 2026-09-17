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
        #
        # Everything in the archive goes into the install directory, not just
        # the .exe. The Windows build imports the Visual C++ runtime
        # (VCRUNTIME140*, MSVCP140*), which ships in the Visual C++
        # Redistributable rather than in Windows itself — so those DLLs travel
        # inside the archive and must land next to the binary, where the
        # loader looks for them. Install only the .exe and Twira will not
        # start on a machine that has never installed a Visual C++
        # Redistributable: the loader fails with 0xC0000135 before the program
        # runs, and nothing is printed at all.
        #
        # Extract into a subdirectory so the archive and its checksum file
        # (both sitting in $Tmp) can never be mistaken for payload.
        $Extract = Join-Path $Tmp 'unpacked'
        New-Item -ItemType Directory -Path $Extract -Force | Out-Null
        Expand-Archive -Path (Join-Path $Tmp $Archive) -DestinationPath $Extract -Force

        $payload = @(Get-ChildItem -Path $Extract -File)
        if (-not ($payload | Where-Object { $_.Name -eq "$BinaryName.exe" })) {
            throw "$Archive did not contain $BinaryName.exe."
        }

        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

        # A running twira (an MCP server held open by an editor, a dashboard,
        # a background watcher) keeps its image mapped, and Windows refuses to
        # overwrite or delete a mapped file. Renaming it aside is always
        # allowed, and frees the name for the new copy; the stale .old is
        # swept on the next install once nothing holds it.
        Get-ChildItem -Path $InstallDir -Filter '*.old' -File -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }

        foreach ($file in $payload) {
            $dest = Join-Path $InstallDir $file.Name
            if (Test-Path $dest) {
                try {
                    Remove-Item $dest -Force -ErrorAction Stop
                }
                catch {
                    Rename-Item -Path $dest -NewName "$($file.Name).old" -Force -ErrorAction Stop
                }
            }
            Move-Item -Path $file.FullName -Destination $dest -Force
        }

        $extras = @($payload | Where-Object { $_.Name -ne "$BinaryName.exe" })
        if ($extras.Count -gt 0) {
            Write-Host "Installed $($extras.Count) runtime $(if ($extras.Count -eq 1) { 'library' } else { 'libraries' }) alongside the binary."
        }
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

    # Prove the install before claiming it works. The one failure this cannot
    # talk its way past is a missing runtime: the process never starts, so
    # there is no output and no exit code from Twira itself. Say what that
    # means rather than leaving the user with a bare loader error.
    $installed = Join-Path $InstallDir "$BinaryName.exe"
    $reported = $null
    $startFailure = $null
    try {
        # A process that cannot start raises a terminating error under
        # $ErrorActionPreference = 'Stop' rather than returning an exit code,
        # so both outcomes have to be handled.
        $reported = (& $installed --version 2>&1) -join ' '
        if ($LASTEXITCODE -ne 0) { $startFailure = $reported }
    }
    catch {
        $startFailure = $_.Exception.Message
    }

    if ($startFailure) {
        Write-Host ''
        Write-Host 'Twira was downloaded and verified, but the binary would not start:'
        Write-Host "  $startFailure"
        Write-Host ''
        Write-Host 'Please report this at https://github.com/TwiraHQ/twira/issues with'
        Write-Host "the message above, your Windows version, and $Target."
        return
    }

    Write-Host "$reported is ready to use in this terminal."
    Write-Host ''

    Write-Host 'Get started:'
    Write-Host '  twira init       # set up Twira in your repo (wires your AI agent)'
    Write-Host '  twira index      # build the local code graph'
    Write-Host '  twira dashboard  # open the dashboard in your browser'
    Write-Host ''
}

Install-Twira
