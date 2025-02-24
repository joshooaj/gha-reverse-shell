param(
    [Parameter()]
    [uri]
    $DownloadUri = 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip',

    [Parameter()]
    [string]
    $AuthToken = $env:NGROK_AUTH_TOKEN,

    [Parameter()]
    [switch]
    $CreateUser,

    [Parameter()]
    [pscredential]
    $Credential
)

# Disable progress bar as it can hinder download speed.
$ProgressPreference = 'SilentlyContinue'

if ([string]::IsNullOrWhiteSpace($AuthToken)) {
    throw "Parameter 'AuthToken' is required if `$env:NGROK_AUTH_TOKEN is unset."
}

# Enable PSRemoting as ngrok will be used to expose it for public access
$null = Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Download and extract ngrok
Invoke-WebRequest -Uri $DownloadUri -OutFile ngrok.zip
Expand-Archive -Path ngrok.zip -DestinationPath . -Force
Remove-Item -Path ngrok.zip

if ($CreateUser) {
    if ($null -eq $Credential) {
        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'.ToCharArray()
        $password = [string]::new((1..16 | % { $chars | Get-Random })) | ConvertTo-SecureString -AsPlainText -Force
        $Credential = [pscredential]::new('ngrok', $password)
    }
    $SecurePassword = $Credential.GetNetworkCredential().SecurePassword
    $user = New-LocalUser $Credential.UserName -Password $SecurePassword -Description 'User for remote access via ngrok' -Confirm:$false
    $user | Add-LocalGroupMember -Group 'Remote Management Users' -Confirm:$false
}

$null = & .\ngrok.exe authtoken $AuthToken

$process = Start-Process .\ngrok.exe -ArgumentList tcp, 5985 -PassThru

do {
    Write-Host "Waiting for ngrok endpoint api availability..."
    try {
        $endpoint = [uri](Invoke-RestMethod http://127.0.0.1:4040/api/tunnels -ErrorAction Stop).tunnels.public_url
        if ($endpoint) {
            break
        }
        Start-Sleep -Seconds 1
    } catch {
        Start-Sleep -Seconds 1
    }
} while ($true)


Write-Host "Connect using $($Credential.UserName) and `"$($Credential.GetNetworkCredential().Password)`""
Write-Host "Enter-PSSession $($endpoint.Host) -Port $($endpoint.Port) -Credential (Get-Credential)"

$process | Wait-Process