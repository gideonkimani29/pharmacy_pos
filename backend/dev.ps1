Get-Content .\.env | ForEach-Object {
    if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)\s*$') {
        Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
    }
}
Write-Host "Bootstrap token: $env:BOOTSTRAP_TOKEN"
go run .\cmd\pharmacy-api
