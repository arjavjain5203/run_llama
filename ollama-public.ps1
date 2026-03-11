# =============================
# Fully Robust Ollama Public API Automation for Windows
# =============================

# === Configuration ===
$LLMPort = 11434
$DuckDNSDomain = "ollama-l-lla.duckdns.org" # Your DuckDNS subdomain
$DuckDNSToken = "1__fd234fee-d093-4848-8988-08db04fc6f4f__1" # Your DuckDNS token
$NgrokUser = "user"           # Optional HTTP auth
$NgrokPass = "password"       # Optional HTTP auth
$OllamaScript = "C:\Users\Mukesh\Documents\run_ollama.py" # Update with your run_ollama.py path
$NgrokFolder = "C:\Tools\ngrok"
$NgrokExePath = "$NgrokFolder\ngrok.exe"
$NgrokLog = "$NgrokFolder\ngrok.log"
$CheckInterval = 60  # seconds between health checks
$NgrokDownloadUrl = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-stable-windows-amd64.zip"

# =============================
# Functions
# =============================

function Install-Ngrok {
    if (-Not (Test-Path $NgrokExePath)) {
        Write-Host "[*] ngrok not found. Downloading..."
        if (-Not (Test-Path $NgrokFolder)) {
            New-Item -ItemType Directory -Path $NgrokFolder | Out-Null
        }

        $zipPath = "$NgrokFolder\ngrok.zip"
        Invoke-WebRequest -Uri $NgrokDownloadUrl -OutFile $zipPath

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $NgrokFolder)

        Remove-Item $zipPath
        Write-Host "[+] ngrok downloaded and extracted to $NgrokFolder"
    } else {
        Write-Host "[*] ngrok already exists at $NgrokExePath"
    }
}

function Start-Ollama {
    if (-not (Get-Process -Name "python" -ErrorAction SilentlyContinue)) {
        Write-Host "[+] Starting Ollama LLM..."
        Start-Process "python" $OllamaScript -WindowStyle Hidden
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[*] Ollama already running"
    }
}

function Start-Ngrok {
    if (-not (Get-Process -Name "ngrok" -ErrorAction SilentlyContinue)) {
        Write-Host "[+] Starting ngrok tunnel..."
        Start-Process $NgrokExePath `
            -ArgumentList "http $LLMPort --auth=$NgrokUser:$NgrokPass --log=stdout" `
            -RedirectStandardOutput $NgrokLog `
            -WindowStyle Hidden
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[*] ngrok already running"
    }
}

function Get-NgrokURL {
    if (Test-Path $NgrokLog) {
        $log = Get-Content $NgrokLog -Tail 20
        $match = $log | Select-String -Pattern "https://[0-9a-z]*\.ngrok.io"
        if ($match) {
            return $match.Matches.Value
        }
    }
    return $null
}

function Update-DuckDNS($NgrokURL) {
    if ($NgrokURL) {
        # DuckDNS expects an IP, but free ngrok gives a URL; we can use a workaround by hitting DuckDNS anyway for log
        # It won’t really map the URL, but you can always read the URL from console
        Write-Host "[*] DuckDNS update skipped for free ngrok; using printed URL instead"
        Write-Host "[*] Current public endpoint: $NgrokURL"
    } else {
        Write-Host "[!] ngrok URL not found, DuckDNS not updated"
    }
}

# =============================
# Main Loop
# =============================

Write-Host "[*] Installing/checking ngrok..."
Install-Ngrok

Write-Host "[*] Starting Ollama Public Endpoint Automation..."
while ($true) {
    # Start Ollama if not running
    Start-Ollama

    # Start ngrok if not running
    Start-Ngrok

    # Get public URL
    $NgrokURL = Get-NgrokURL
    Update-DuckDNS $NgrokURL

    Write-Host "[*] Waiting $CheckInterval seconds before next check..."
    Start-Sleep -Seconds $CheckInterval
}
