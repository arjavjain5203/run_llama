# =============================
# Fully Robust Ollama Public API Automation
# =============================

# === Configuration ===
$LLMPort = 11434
$DuckDNSDomain = "ollama-l-lla.duckdns.org"
$DuckDNSToken = "1__fd234fee-d093-4848-8988-08db04fc6f4f__1"
$NgrokUser = "user"           # Optional HTTP auth
$NgrokPass = "password"       # Optional HTTP auth
$NgrokExePath = "C:\path\to\ngrok.exe"      # Update path
$OllamaScript = "C:\path\to\run_ollama.py" # Update path
$NgrokLog = "C:\ngrok.log"
$CheckInterval = 60  # seconds between health checks

# =============================
# Functions
# =============================

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
        Start-Process $NgrokExePath "http $LLMPort --auth=$NgrokUser:$NgrokPass --log=stdout > $NgrokLog" -WindowStyle Hidden
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[*] ngrok already running"
    }
}

function Get-NgrokURL {
    if (Test-Path $NgrokLog) {
        $log = Get-Content $NgrokLog -Tail 20
        $url = ($log | Select-String -Pattern "https://[0-9a-z]*\.ngrok.io").Matches.Value
        return $url
    }
    return $null
}

function Update-DuckDNS($NgrokURL) {
    if ($NgrokURL) {
        Invoke-WebRequest -Uri "https://www.duckdns.org/update?domains=$DuckDNSDomain&token=$DuckDNSToken&ip=$NgrokURL" -UseBasicParsing
        Write-Host "[*] DuckDNS updated: https://$DuckDNSDomain → tunnels to $NgrokURL"
    } else {
        Write-Host "[!] ngrok URL not found, DuckDNS not updated"
    }
}

# =============================
# Main Loop
# =============================

Write-Host "[*] Starting Ollama Public Endpoint Automation..."
while ($true) {
    Start-Ollama
    Start-Ngrok

    $NgrokURL = Get-NgrokURL
    Update-DuckDNS $NgrokURL

    Write-Host "[*] Waiting $CheckInterval seconds before next check..."
    Start-Sleep -Seconds $CheckInterval
}
