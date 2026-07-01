param(
    [string]$Project = "koom-9f163",
    [string]$ResultsBucket = "test-lab-6vjdt6tj89142-m32qah5830n90",
    [string]$ApiBaseUrl = "https://koom.servemp3.com",
    [string]$Device = "model=Pixel2.arm,version=30,locale=ru,orientation=portrait",
    [string]$Timeout = "15m"
)

$ErrorActionPreference = "Stop"

$roles = @(
    @{
        Name = "user-group-owner"
        Phone = "+996555555555"
        ExpectedUserRole = "user"
        ExpectedGroupRole = "owner,admin"
    },
    @{
        Name = "super-admin"
        Phone = "+996000000000"
        ExpectedUserRole = "super_admin"
        ExpectedGroupRole = "any"
    }
)

foreach ($role in $roles) {
    $resultsDir = "mobilechat-role-$($role.Name)-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "Running role scenario: $($role.Name)" -ForegroundColor Cyan
    & "$PSScriptRoot\run_firebase_integration_testlab.ps1" `
        -Build `
        -Project $Project `
        -ResultsBucket $ResultsBucket `
        -ResultsDir $resultsDir `
        -ApiBaseUrl $ApiBaseUrl `
        -Device $Device `
        -Timeout $Timeout `
        -TestAuthPhone $role.Phone `
        -TestExpectedUserRole $role.ExpectedUserRole `
        -TestExpectedGroupRole $role.ExpectedGroupRole
}
