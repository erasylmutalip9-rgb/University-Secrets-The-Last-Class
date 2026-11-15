# Keep this file ASCII-only: Windows PowerShell 5.1 treats UTF-8 without BOM as ANSI.
# The Python caller translates English diagnostics to Russian for the player.
param(
    [Parameter(Mandatory = $true)]
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$engine = $null
$response = @{ ok = $false; text = ''; error = 'Speech recognition did not start.' }

try {
    Add-Type -AssemblyName 'System.Speech' -ErrorAction Stop
    $culture = [System.Globalization.CultureInfo]::GetCultureInfo('ru-RU')
    $available = @([System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers() |
        Where-Object { $_.Culture.Name -eq 'ru-RU' })
    if ($available.Count -eq 0) {
        throw 'Russian Windows speech recognizer is not installed. Use SETUP_VOICE_WINDOWS.bat to install offline Vosk.'
    }

    $engine = New-Object -TypeName System.Speech.Recognition.SpeechRecognitionEngine -ArgumentList @($culture)
    $grammar = New-Object System.Speech.Recognition.DictationGrammar
    $engine.LoadGrammar($grammar)
    $engine.SetInputToDefaultAudioDevice()
    $recognition = $engine.Recognize([TimeSpan]::FromSeconds(10))

    if ($null -ne $recognition -and -not [string]::IsNullOrWhiteSpace($recognition.Text)) {
        $response = @{ ok = $true; text = $recognition.Text; error = '' }
    } else {
        $response = @{ ok = $false; text = ''; error = 'No speech detected or recognized.' }
    }
}
catch {
    $response = @{ ok = $false; text = ''; error = [string]$_.Exception.Message }
}
finally {
    if ($null -ne $engine) {
        try { $engine.Dispose() } catch { }
    }
}

try {
    $folder = Split-Path -Path $OutputPath -Parent
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    $json = ConvertTo-Json -InputObject $response -Compress -Depth 3
    [System.IO.File]::WriteAllText($OutputPath, $json, (New-Object System.Text.UTF8Encoding($false)))
}
catch {
    Write-Error ('Cannot write speech result: ' + $_.Exception.Message)
    exit 2
}
