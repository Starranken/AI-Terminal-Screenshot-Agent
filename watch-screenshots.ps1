param(
    [string]$Folder = '',
    [string]$Model = '',
    [int]$PollMilliseconds = 0
)

$ErrorActionPreference = 'Stop'

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $env:SCREENSHOT_AGENT_SCRIPT }
$configPath = Join-Path $scriptRoot 'config.json'
if (-not (Test-Path -LiteralPath $configPath)) { throw "Missing configuration file: $configPath" }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

if (-not $Folder) { $Folder = [string]$config.screenshot_folder }
if (-not $Folder) { $Folder = Split-Path -Parent $scriptRoot }
if (-not [IO.Path]::IsPathRooted($Folder)) { $Folder = Join-Path $scriptRoot $Folder }
if (-not $Model) { $Model = [string]$config.model }
if (-not $Model -and $env:GEMINI_MODEL) { $Model = $env:GEMINI_MODEL }
if (-not $Model) { $Model = 'gemini-3.5-flash-lite' }
if ($PollMilliseconds -le 0) { $PollMilliseconds = [int]$config.poll_milliseconds }
if ($PollMilliseconds -le 0) { $PollMilliseconds = 500 }

$apiKey = [string]$config.gemini_api_key
if (-not $apiKey -or $apiKey -eq 'PUT_YOUR_GEMINI_API_KEY_HERE') { $apiKey = $env:GEMINI_API_KEY }
if (-not $apiKey) {
    throw "Set gemini_api_key in $configPath or GEMINI_API_KEY in the environment."
}

$projectFolder = $scriptRoot
$Folder = (Resolve-Path -LiteralPath $Folder).Path
$responseFolder = [string]$config.response_folder
if (-not $responseFolder) { $responseFolder = 'responses' }
if (-not [IO.Path]::IsPathRooted($responseFolder)) { $responseFolder = Join-Path $projectFolder $responseFolder }
New-Item -ItemType Directory -Path $responseFolder -Force | Out-Null
$extensions = @('.png', '.jpg', '.jpeg', '.webp', '.gif')
$prompt = "Read this screenshot carefully. If it contains a question or task, answer it directly and concisely. If it contains code or an error, explain the likely fix. If no response is needed, briefly describe what is shown."

function Wait-ForStableFile([string]$Path) {
    $previous = -1
    do {
        Start-Sleep -Milliseconds $PollMilliseconds
        if (-not (Test-Path -LiteralPath $Path)) { return $false }
        $current = (Get-Item -LiteralPath $Path).Length
    } while ($current -ne $previous -and ($previous = $current))
    return $true
}

function Answer-Image([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $base64 = [Convert]::ToBase64String($bytes)
    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    $mime = switch ($extension) {
        '.jpg' { 'image/jpeg' }
        '.jpeg' { 'image/jpeg' }
        '.webp' { 'image/webp' }
        '.gif' { 'image/gif' }
        default { 'image/png' }
    }

    $body = @{
        contents = @(@{
            parts = @(
                @{ text = $prompt }
                @{ inlineData = @{ mimeType = $mime; data = $base64 } }
            )
        })
    } | ConvertTo-Json -Depth 10

    try {
        $uri = "https://generativelanguage.googleapis.com/v1beta/models/$Model`:generateContent"
        $result = Invoke-RestMethod -Uri $uri -Method Post `
            -Headers @{ 'x-goog-api-key' = $apiKey; 'Content-Type' = 'application/json' } `
            -Body $body
    } catch {
        $detail = $_.ErrorDetails.Message
        if (-not $detail -and $_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object IO.StreamReader($stream)
                $detail = $reader.ReadToEnd()
                $reader.Dispose()
            } catch { }
        }
        if (-not $detail) { $detail = $_.Exception.Message }
        throw "Gemini API error: $detail"
    }
    $answer = ($result.candidates[0].content.parts | ForEach-Object { $_.text }) -join "`n"
    if (-not $answer) { throw 'The API returned no text answer.' }
    return $answer.Trim()
}

Write-Host "Watching $Folder for new images. Press Ctrl+C to stop." -ForegroundColor Yellow
try {
    $lastImage = Get-ChildItem -LiteralPath $Folder -File |
        Where-Object { $_.Extension.ToLowerInvariant() -in $extensions } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    $lastIdentity = if ($lastImage) { "$($lastImage.FullName)|$($lastImage.Length)|$($lastImage.LastWriteTimeUtc.Ticks)" } else { '' }

    while ($true) {
        $image = Get-ChildItem -LiteralPath $Folder -File |
            Where-Object { $_.Extension.ToLowerInvariant() -in $extensions } |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        if ($image) {
            $identity = "$($image.FullName)|$($image.Length)|$($image.LastWriteTimeUtc.Ticks)"
            if ($identity -ne $lastIdentity -and (Wait-ForStableFile $image.FullName)) {
                # Mark it before calling the API so failures are not retried every second.
                $lastIdentity = $identity
                try {
                    Write-Host "`n$('=' * 72)" -ForegroundColor DarkGray
                    Write-Host "Screenshot: $($image.Name)" -ForegroundColor Cyan
                    Write-Host "Analyzing..." -ForegroundColor DarkCyan
                    $answer = Answer-Image $image.FullName
                    $output = Join-Path $responseFolder "$($image.BaseName).response.md"
                    "# Response to ``$($image.Name)```n`n$answer`n" | Set-Content -LiteralPath $output -Encoding UTF8
                    Write-Host "`n$answer" -ForegroundColor White
                    Write-Host "`nSaved response: $($output | Split-Path -Leaf)" -ForegroundColor DarkGreen
                    Write-Host "$('=' * 72)" -ForegroundColor DarkGray
                } catch {
                    Write-Host "Image processing failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        Start-Sleep -Seconds 1
    }
} finally {
    Write-Host "Stopped." -ForegroundColor Yellow
}
