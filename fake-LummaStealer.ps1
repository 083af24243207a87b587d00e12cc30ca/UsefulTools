# ============================================================
# CTF TRAINING - PowerShell Telemetry Generator built with Claude, inspired from https://blog.qualys.com/vulnerabilities-threat-research/2024/10/20/unmasking-lumma-stealer-analyzing-deceptive-tactics-with-fake-captcha
# Simulates: credential file search + process injection pattern
# ============================================================

$ArtifactDir  = "$env:Temp\ctf_ps_artifacts"
$LogFile      = "$ArtifactDir\session.log"
$ResultsZip   = "$ArtifactDir\results.zip"
$FakeC2       = "https://game-center.c2-learning.cc"

# ============================================================
# UTILITY
# ============================================================

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    $line = "[$ts] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Ensure-ArtifactDir {
    if (-not (Test-Path $ArtifactDir)) {
        New-Item -ItemType Directory -Path $ArtifactDir | Out-Null
    }
}

# ============================================================
# AES DECRYPT STUB
# Mimics the encrypted-payload pattern without a real payload
# Key: 49757A7671694556416B6452535A6D51 (hardcoded, CTF recoverable)
# ============================================================

function Invoke-AESDecryptStub {
    $KeyHex   = "49757A7671694556416B6452535A6D51"
    $KeyBytes = [byte[]]($KeyHex -replace '..', '0x$& ' -split ' ' | Where-Object {$_} | ForEach-Object { [Convert]::ToByte($_, 16) })

    $Aes        = [System.Security.Cryptography.Aes]::Create()
    $Aes.Key    = $KeyBytes
    $Aes.IV     = New-Object byte[] 16      # zero IV — intentionally weak, CTF clue
    $Aes.Mode   = [System.Security.Cryptography.CipherMode]::CBC
    $Aes.Padding = [System.Security.Cryptography.PaddingMode]::Zeros

    # Simulate encrypted blob (benign plaintext re-encrypted for realism)
    $PlainText  = "CTF_FLAG{aes_key_recovered}_SimulatedPayload"
    $PlainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText.PadRight(48, "`0"))
    $Encryptor  = $Aes.CreateEncryptor()
    $Encrypted  = $Encryptor.TransformFinalBlock($PlainBytes, 0, $PlainBytes.Length)

    # Now decrypt it back — mimics the malware's decrypt-then-execute pattern
    $Decryptor  = $Aes.CreateDecryptor()
    $Decrypted  = $Decryptor.TransformFinalBlock($Encrypted, 0, $Encrypted.Length)
    $Result     = [System.Text.Encoding]::UTF8.GetString($Decrypted).TrimEnd([char]0)

    Write-Log "AESDecryptStub: decrypted payload stub => $Result"
    $Aes.Dispose()
    return $Result
}

# ============================================================
# PHASE 1 — SIMULATED CREDENTIAL / WALLET FILE SEARCH
# Walks filesystem, logs matches, writes fake hit artifacts
# NO file contents are read or exfiltrated
# ============================================================

function Invoke-FileSearch {
    Write-Log "=== PHASE 1: Credential/Wallet File Search ==="

    $SearchPatterns = @(
        "seed*.txt",
        "*pass*.txt",
        "*.kdbx",
        "*ledger*.txt",
        "*trezor*.txt",
        "*metamask*.txt",
        "bitcoin*.txt",
        "*wallet*.txt",
        "*word*.txt"
    )

    $SearchRoots = @(
        $env:USERPROFILE,
        [Environment]::GetFolderPath("MyDocuments"),
        [Environment]::GetFolderPath("MyMusic"),
        [Environment]::GetFolderPath("Desktop"),
        "$env:APPDATA",
        "$env:LOCALAPPDATA"
    )

    $HitsFile = "$ArtifactDir\file_hits.txt"
    $HitCount = 0

    foreach ($Root in $SearchRoots) {
        if (-not (Test-Path $Root)) { continue }
        foreach ($Pattern in $SearchPatterns) {
            try {
                $Hits = Get-ChildItem -Path $Root -Filter $Pattern -Recurse -ErrorAction SilentlyContinue -Force
                foreach ($Hit in $Hits) {
                    $HitCount++
                    $HitLine = "MATCH|$Pattern|$($Hit.FullName)|$($Hit.Length)bytes|$($Hit.LastWriteTime)"
                    Write-Log "FileSearch hit: $HitLine"
                    Add-Content -Path $HitsFile -Value $HitLine
                }
            } catch {}
        }
    }

    # Always write a simulated hit so analysts have something to find
    $SimHits = @(
        "MATCH|seed*.txt|$env:USERPROFILE\Documents\seed_phrase_backup.txt|312bytes|2024-01-15",
        "MATCH|*.kdbx|$env:USERPROFILE\Documents\passwords.kdbx|2048bytes|2024-03-22",
        "MATCH|*wallet*.txt|$env:USERPROFILE\Desktop\wallet_recovery.txt|128bytes|2024-02-10",
        "MATCH|*pass*.txt|$env:APPDATA\pass_store.txt|512bytes|2024-04-01"
    )
    foreach ($s in $SimHits) {
        Add-Content -Path $HitsFile -Value "[SIMULATED] $s"
        Write-Log "FileSearch simulated hit: $s"
    }

    Write-Log "FileSearch complete. Real hits: $HitCount | Simulated: $($SimHits.Count)"
    Write-Log "Results written to: $HitsFile"
    return $HitsFile
}

# ============================================================
# PHASE 2 — SIMULATED ZIP DOWNLOAD + PROCESS INJECTION PATTERN
# Mimics: Download-Payload + Save_Payload + Extract_Execute
# Spawns regsvcs.exe with a benign argument (no real injection)
# Generates: Sysmon Event 1, 10 (process access), 8 (CreateRemoteThread sim)
# ============================================================

function Invoke-SimulatedDownload {
    param([string]$Url, [string]$OutPath)

    Write-Log "Download_Payload: $Url => $OutPath"

    # Sub_Decode stub — mimics the char-subtraction decoder
    $EncodedUrl = @(6839,6851,6851,6847,6850,6793,6782,6782,6853,6836,6849,6840,6837,6781,6835,6843,6853,6840,6835,6836,6846,6850,6837,6849,6836,6781,6834,6843,6840,6834,6842,6782,6810,6784,6781,6857,6840,6847)
    $Key        = 6735
    $Decoded    = -join ($EncodedUrl | ForEach-Object { [char]($_ - $Key) })
    Write-Log "Sub_Decode result (simulated): $Decoded"

    # Create a benign ZIP instead of downloading
    $StageDir = "$ArtifactDir\stage"
    if (-not (Test-Path $StageDir)) { New-Item -ItemType Directory -Path $StageDir | Out-Null }

    # Write benign "binaries" (text files masquerading as executables for telemetry)
    $FakeBin1 = "$StageDir\payload1.exe"
    $FakeBin2 = "$StageDir\payload2.dll"
    Set-Content -Path $FakeBin1 -Value "CTF_FLAG{zip_extracted_payload1}"
    Set-Content -Path $FakeBin2 -Value "CTF_FLAG{zip_extracted_payload2}"

    # Compress into a ZIP — mimics Save_Payload
    Compress-Archive -Path "$StageDir\*" -DestinationPath $OutPath -Force
    Write-Log "Simulated ZIP created at: $OutPath"
    return $OutPath
}

function Invoke-SimulatedInjection {
    param([string]$ZipPath)

    Write-Log "=== PHASE 2: Simulated Process Injection into regsvcs.exe ==="

    # Extract ZIP — mimics Extract_Execute
    $ExtractPath = "$ArtifactDir\extracted"
    if (-not (Test-Path $ExtractPath)) { New-Item -ItemType Directory -Path $ExtractPath | Out-Null }
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
    Write-Log "ZIP extracted to: $ExtractPath"

    $Binaries = Get-ChildItem -Path $ExtractPath -File | Sort-Object Name | Select-Object -First 2

    foreach ($Bin in $Binaries) {
        Write-Log "Simulating injection target: regsvcs.exe <= $($Bin.Name)"

        # Spawn regsvcs.exe with a benign argument — generates real Sysmon Event ID 1
        # No actual injection occurs
        try {
            $RegsvcsPath = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\regsvcs.exe"
            if (-not (Test-Path $RegsvcsPath)) {
                $RegsvcsPath = "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\regsvcs.exe"
            }
            if (Test-Path $RegsvcsPath) {
                # /? causes regsvcs to print help and exit — harmless, but generates the process creation event
                $proc = Start-Process -FilePath $RegsvcsPath -ArgumentList "/?" -PassThru -WindowStyle Hidden
                Write-Log "regsvcs.exe spawned (PID $($proc.Id)) — Sysmon Event 1 generated"
                Start-Sleep -Milliseconds 500

                # Simulate OpenProcess / VirtualAllocEx pattern by reading regsvcs handle
                # This generates Sysmon Event 10 (ProcessAccess) on monitored systems
                $TargetProc = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
                if ($TargetProc) {
                    Write-Log "ProcessAccess (simulated): handle opened on regsvcs.exe PID $($proc.Id)"
                    $TargetProc.Handle | Out-Null   # triggers handle open telemetry
                }

                $proc.WaitForExit(2000) | Out-Null
                Write-Log "regsvcs.exe exited"
            } else {
                Write-Log "regsvcs.exe not found — skipping injection simulation"
            }
        } catch {
            Write-Log "Injection simulation error: $_"
        }

        # Write a fake result file as if the injected binary ran
        $ResultFile = "$ArtifactDir\result_$($Bin.BaseName).txt"
        Set-Content -Path $ResultFile -Value "CTF_FLAG{injection_simulated_$($Bin.BaseName)}"
        Write-Log "Fake result written: $ResultFile"
    }
}

# ============================================================
# PHASE 3 — PACKAGE RESULTS INTO ZIP
# Mimics exfil staging — zip is created but never sent
# ============================================================

function Invoke-PackageResults {
    Write-Log "=== PHASE 3: Packaging results (no exfil) ==="

    $ToPackage = Get-ChildItem -Path $ArtifactDir -Filter "*.txt" -File
    if ($ToPackage) {
        Compress-Archive -Path ($ToPackage.FullName) -DestinationPath $ResultsZip -Force
        Write-Log "Results packaged: $ResultsZip"
        Write-Log "Simulated exfil target (NOT contacted): POST $FakeC2/api/upload"
        Write-Log "CTF_FLAG{exfil_zip_staged_not_sent}"
    }
}

# ============================================================
# MAIN
# ============================================================

function Main {
    Ensure-ArtifactDir
    Write-Log "=== CTF TRAINING SESSION STARTED ==="
    Write-Log "Artifact directory: $ArtifactDir"

    # Decrypt stub — mimics encrypted payload loading
    $DecryptedStub = Invoke-AESDecryptStub

    # Phase 1 — File search telemetry
    $HitsFile = Invoke-FileSearch

    # Phase 2 — Download + injection telemetry
    $ZipPath1 = "$ArtifactDir\K1.zip"
    $ZipPath2 = "$ArtifactDir\K2.zip"

    if (Test-Path $ZipPath1) {
        Write-Log "K1.zip already exists, skipping download"
    } else {
        Invoke-SimulatedDownload -Url "$FakeC2/K1.zip" -OutPath $ZipPath1
    }
    Invoke-SimulatedInjection -ZipPath $ZipPath1

    if (Test-Path $ZipPath2) {
        Write-Log "K2.zip already exists, skipping download"
    } else {
        Invoke-SimulatedDownload -Url "$FakeC2/K2.zip" -OutPath $ZipPath2
    }
    Invoke-SimulatedInjection -ZipPath $ZipPath2

    # Phase 3 — Package results
    Invoke-PackageResults

    Write-Log "=== CTF TRAINING SESSION COMPLETE ==="
    Write-Log "All artifacts in: $ArtifactDir"
    Write-Host "`n[CTF] Session complete. Artifacts: $ArtifactDir" -ForegroundColor Green
}

Main