param([int]$Seed = 1234, [switch]$Audio, [string]$VerifiedRoute)

$reroute = $PSBoundParameters.ContainsKey('Seed')
if ($VerifiedRoute) { $VerifiedRoute = (Resolve-Path -LiteralPath $VerifiedRoute).Path }

$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $sdk = (Resolve-Path ../../AGM).Path
    $logicTools = "$sdk/AgRV_pio/packages/tool-agrv_logic"
    # Stage Prepare LOGIC and Native artifacts away from the released image.
    # -Audio remains valid for existing callers. Audio is part of the release.
    $project = New-Item -ItemType Directory -Path '.pio/release-build' -Force
    $rtl = New-Item -ItemType Directory -Path "$project/rtl" -Force
    foreach ($file in 'sfcbuilder.v', 'sfcbuilder_audio.v') {
        Copy-Item -LiteralPath "rtl/$file" -Destination $rtl -Force
    }
    Copy-Item -LiteralPath 'af_map.tcl' -Destination $project -Force
    foreach ($file in 'local_brams_m9k.txt', 'local_brams_map_m9k.v', 'timing.sdc') {
        Copy-Item -LiteralPath $file -Destination $rtl -Force
    }
    Get-Content 'top.ve', 'audio-clocks.ve' | Set-Content "$project/top.ve" -Encoding ascii
    (Get-Content 'platformio.ini') -replace '^core_dir = .*', "core_dir = $sdk/AgRV_pio" |
        Set-Content "$project/platformio.ini" -Encoding ascii

    Set-Location $project
    & "$sdk/pio-env/Scripts/pio.exe" run -t prelogic
    if ($LASTEXITCODE -ne 0) { throw 'Prepare LOGIC failed.' }

    Set-Location $rtl
    # Prepare LOGIC exposes the FIR clock port through PLL2. The release
    # shares the existing PLL3 global BUSCLK instead of adding a clock tree.
    $topPath = (Resolve-Path 'top.v').Path
    $top = [IO.File]::ReadAllText($topPath).Replace("`r`n", "`n")
    $firClock = '(?ms)^`ifdef ALTA_SYN\nalta_gclkgen \\PLL_CLKOUT\[2\]_gclkgen \(\n.*?^`endif(?=\nassign audio_fir_clock_out_en = 1''b1;)'
    $sharedClock = 'assign audio_fir_clock_out_data = bus_clk;'
    $clockBlocks = [regex]::Matches($top, $firClock).Count
    $sharedAssignments = [regex]::Matches($top, [regex]::Escape($sharedClock)).Count
    if ($clockBlocks -eq 1 -and $sharedAssignments -eq 0) {
        $top = [regex]::Replace($top, $firClock, $sharedClock)
    } elseif ($clockBlocks -ne 0 -or $sharedAssignments -ne 1) {
        throw 'Expected one Prepare LOGIC FIR clock source.'
    }
    [IO.File]::WriteAllText($topPath, $top, [Text.Encoding]::ASCII)

    & "$logicTools/map/bin/yosys.exe" -TQ -c ../af_map.tcl
    if ($LASTEXITCODE -ne 0) { throw 'Native synthesis failed.' }

    $release = Join-Path $PSScriptRoot 'rtl'
    $routeInputs = 'top.vqm', 'top.asf', 'top.pre.asf', 'top.post.asf', 'top.qsf',
                   'top.sdc', 'top.vex', 'timing.sdc', 'af_run.tcl'
    $bundledRoute = Join-Path $PSScriptRoot 'verified-route'
    $routeCandidates = if ($VerifiedRoute) { $VerifiedRoute } elseif (!$reroute) { $bundledRoute; $release }
    $flow = 'ALL'
    foreach ($routeSource in $routeCandidates) {
        if (!(Test-Path "$routeSource/alta_db/route.tx" -PathType Leaf)) {
            if ($VerifiedRoute) { throw "Verified route database was not found: $routeSource" }
            continue
        }

        $manifest = Join-Path $routeSource 'inputs.sha256.json'
        $inputHashes = if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
        }
        $differentInputs = foreach ($file in $routeInputs) {
            $expectedHash = if ($inputHashes) {
                $inputHashes.$file
            } else {
                $previous = Join-Path $routeSource $file
                if (Test-Path -LiteralPath $previous -PathType Leaf) {
                    (Get-FileHash -LiteralPath $previous).Hash
                }
            }
            if ($expectedHash -ne (Get-FileHash -LiteralPath $file).Hash) { $file }
        }
        if ($differentInputs) {
            if ($VerifiedRoute) { throw "Verified route does not match the generated build inputs: $differentInputs" }
            continue
        }

        Write-Output "Reusing verified route: $routeSource"
        $db = New-Item -ItemType Directory -Path 'alta_db' -Force
        Get-ChildItem -LiteralPath "$routeSource/alta_db" -File |
            Copy-Item -Destination $db -Force
        $flow = 'LOAD'
        break
    }

    & "$logicTools/bin/af.exe" --batch -X 'set MODE NATIVE' -X "set FLOW $flow" -X "set SEED $Seed" `
        -X 'set SDC_FILE ./timing.sdc' -X 'set rt_report_timing_fast true' `
        -X 'set EFFORT high' -X 'set FITTING timing' -F af_run.tcl
    if ($LASTEXITCODE -ne 0) { throw 'Place and route failed.' }

    foreach ($report in 'setup', 'hold', 'setup_fast', 'hold_fast') {
        $summary = "alta_db/${report}_summary.rpt"
        $slacks = Select-String -LiteralPath $summary -Pattern '^  (?:Slack:|Worst\s+(?:setup|hold):)\s+(-?\d+\.\d+)' |
            ForEach-Object { [double]::Parse($_.Matches[0].Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) }
        if (!$slacks -or ($slacks | Where-Object { $_ -lt 0 }).Count -gt 0) {
            throw "Timing did not pass. See $summary."
        }
    }

    foreach ($file in (@('top_routed.v', 'top.inc', 'top_batch.bin', 'top.v') + $routeInputs)) {
        Copy-Item -LiteralPath $file -Destination $release -Force
    }
    foreach ($directory in 'alta_db', 'alta_logs') {
        $output = New-Item -ItemType Directory -Path "$release/$directory" -Force
        Get-ChildItem -LiteralPath $directory -File | Copy-Item -Destination $output -Force
    }
    Copy-Item -LiteralPath 'top.bin' -Destination $release -Force
} finally {
    Pop-Location
}
