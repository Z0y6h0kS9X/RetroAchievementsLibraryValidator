#region FUNCTIONS

# Function to get a list of active systems from RetroAchievements
FUNCTION Get-RASystemsList {
    $BaseUrl = 'https://retroachievements.org/API/API_GetConsoleIDs.php'
    $QueryParams = @{ y = $Config.APIKey }
    $FullUrl = Get-FullUrl -BaseUrl $BaseUrl -QueryParams $QueryParams

    $Response = Invoke-WebRequest -Uri $FullUrl
    $JsonContent = $Response.Content | ConvertFrom-Json

    return $JsonContent | Where-Object { $_.Active -and $_.IsGameSystem } | Select-Object ID, Name
}

# Function to get the list of games for a specific system
FUNCTION Get-RAGamesList {
    [CmdletBinding()]
    param (
        [string]$SystemId
    )

    $BaseUrl = 'https://retroachievements.org/API/API_GetGameList.php'
    $QueryParams = @{ y = $Config.APIKey; i = $SystemId; h = 1 }
    $FullUrl = Get-FullUrl -BaseUrl $BaseUrl -QueryParams $QueryParams

    $Response = Invoke-WebRequest -Uri $FullUrl
    $JsonContent = $Response.Content | ConvertFrom-Json

    return $JsonContent | Select-Object ID, Title, ConsoleID, ConsoleName, NumAchievements, Hashes
}

# Function to build a complete URL from base URL and query parameters
FUNCTION Get-FullUrl {
    param (
        [string]$BaseUrl,
        [hashtable]$QueryParams
    )

    $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
    return "$($BaseUrl)?$($QueryString)"
}

# Function to test if an API key is valid by making a test API call
FUNCTION Test-ApiKey {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $BaseUrl = "https://retroachievements.org/API/API_GetAchievementOfTheWeek.php"
    $QueryParams = @{ y = $Key }
    $FullUrl = Get-FullUrl -BaseUrl $BaseUrl -QueryParams $QueryParams

    $Response = Invoke-RestMethod -Method Get -Uri $FullUrl
    if (-not $Response) {
        return $false
    }

    return $true
}

# Function to get the platform name corresponding to a given name
FUNCTION Get-PlatformFromName {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [string]$Name
    )

    $NormalizedName = $Name.ToLower()

    $SystemMatch = $Config.PlatformMapping | Where-Object { $_.Platform.ToLower() -eq $NormalizedName }
    if ($SystemMatch) {
        return $SystemMatch.Platform
    }

    $NormalizedInput = $NormalizedName -replace " ", "-" -replace "\s+", ""
    $SystemMatch = $Config.PlatformMapping | Where-Object {
        ($_.Platform.ToLower() -replace " ", "-") -eq $NormalizedInput
    }
    if ($SystemMatch) {
        return $SystemMatch.Platform
    }

    foreach ($Alias in $Config.PlatformMapping.Aliases) {
        if ($Alias -contains $NormalizedName) {
            return ($Config.PlatformMapping | Where-Object { $_.Aliases -contains $Alias }).Platform
        }
    }

    return $null
}

# Function to show a progress bar with the current step and message
FUNCTION Show-ProgressBar {
    param (
        [int]$CurrentStep,
        [int]$TotalSteps,
        [string]$Message,
        [int]$BarWidth = 50,
        [int]$MaxMessageLength,
        [string]$SkipMessage = $null
    )

    if ($TotalSteps -eq 0) {
        $DotPadding = "." * ($MaxMessageLength - $Message.Length)
        $SkipMessageOutput = "$Message$DotPadding SKIPPED ($SkipMessage)"
        Write-Host "`r$SkipMessageOutput"
        return
    }

    $MessageLength = $Message.Length
    $DotPadding = "." * ($MaxMessageLength - $MessageLength)
    $FullMessage = "$Message$DotPadding"

    $PercentComplete = ($CurrentStep / $TotalSteps) * 100

    if ($CurrentStep -eq ($TotalSteps - 1)) {
        $ProgressBar = "#" * $BarWidth
        $Spaces = " " * ($BarWidth - $ProgressBar.Length)
        $Output = "`r$FullMessage [$ProgressBar$Spaces] 100%"
        Write-Host $Output -NoNewline

        $DoneMessage = "`r$FullMessage DONE"
        $DoneMessagePad = " " * ($BarWidth + 10)
        Write-Host "$DoneMessage$DoneMessagePad" -NoNewline
        Write-Host ""
    }
    else {
        $ProgressBar = "#" * ($CurrentStep * $BarWidth / $TotalSteps)
        $Spaces = " " * ($BarWidth - $ProgressBar.Length)
        $Output = "`r$FullMessage [$ProgressBar$Spaces] $([math]::Round($PercentComplete))%"
        Write-Host $Output -NoNewline
    }
}

# Function to match a ROM with a game in the RetroAchievements database based on its hash
FUNCTION Get-RomMatch {
    [CmdletBinding()]
    param (
        [int]$SystemId,
        [System.IO.FileInfo]$Rom,
        $GameList
    )

    $GameHash = cmd /c $Config.RaHasherPath $SystemId $Rom.FullName

    if ($GameHash.Length -ne 32) {
        Write-Error "Unable to parse $($Rom.Name)"
        $GameHash = $null
    }

    $GameMatch = $GameList | Where-Object { $_.Hashes -match $GameHash }

    $Entry = [PSCustomObject]@{
        MatchFound   = $false
        System       = $Platform.Platform
        RomName      = $LocalRoms[$I].Name
        Hash         = $GameHash
        Path         = $Platform.Location
        RATitle      = ''
        RAID         = ''
        CheevoCount  = ''
    }

    if ($GameMatch) {
        $Entry.MatchFound = $true
        $Entry.RATitle = $GameMatch.Title
        $Entry.RAID = $GameMatch.ID
        $Entry.CheevoCount = $GameMatch.NumAchievements
    }

    return $Entry
}

#endregion

#region SCRIPT
if (-not (Test-Path ./config.psd1)) {
    Write-Error "config.psd1 is missing from local directory!"
    Exit 1
}

# $Config = Get-Content -Path "config.psd1" | ConvertFrom-Json
$Config = Import-PowerShellDataFile -Path "config.psd1"

if (-not (Test-Path $Config.LibraryPath)) {
    Write-Error "Path to your Library was invalid, was it set in config.psd1?"
    Exit 1
}

if (-not (Test-Path $Config.RaHasherPath)) {
    Write-Error "Path to your RAHasher program was invalid, was it set in config.psd1?"
    Exit 1
}

if (-not (Test-ApiKey -Key $Config.APIKey)) {
    Write-Error "API Key Test did not have a successful response, it may be invalid"
    Exit 1
}

$PlatformList = @()
Get-ChildItem -Path $Config.LibraryPath -Directory | ForEach-Object {
    $DirName = $_.BaseName
    $PlatformMatch = Get-PlatformFromName -Name $DirName    
    if ($PlatformMatch) {
        Write-Host "Matching $DirName to $($PlatformMatch)"
        [PSCustomObject]@{
            Platform = $PlatformMatch
            Location = $_.FullName
        }
    }
} | ForEach-Object {
    $PlatformList += $_
}

if ($PlatformList.Count -lt 1) {
    Write-Error "Could not map any of the subdirectories in [$($Config.LibraryPath)] to platforms on RetroAchievements! Check your configured directories."
    Exit 1
}

$RaSystems = Get-RASystemsList
$Results = New-Object System.Collections.Generic.List[Object]

$MaxMessageLength = ($PlatformList | ForEach-Object { ("Processing [$($_.Platform)] ROMs...").Length } | Measure-Object -Maximum).Maximum

foreach ($Platform in $PlatformList) {
    $LocalRoms = Get-ChildItem -Path $Platform.Location -File
    if ($LocalRoms.Count -eq 0) {
        Show-ProgressBar -TotalSteps 0 -Message "Processing [$($Platform.Platform)] ROMs..." -SkipMessage "Empty Folder" -MaxMessageLength $MaxMessageLength
        Continue
    }

    $SystemId = ($RaSystems | Where-Object { $_.Name -match "^$($Platform.Platform)$" }).ID
    $GameList = Get-RAGamesList -SystemId $SystemId

    for ($I = 0; $I -lt ($LocalRoms.Count); $I++) {
        Show-ProgressBar -CurrentStep $I -TotalSteps $LocalRoms.Count -Message "Processing [$($Platform.Platform)] ROMs..." -MaxMessageLength $MaxMessageLength
        $Entry = Get-RomMatch -SystemId $SystemId -Rom $LocalRoms[$I] -GameList $GameList
        $Results.Add($Entry) | Out-Null
    }
}

if ($Config.OutputMissingOnly) {
    $Results = $Results | Where-Object { $_.MatchFound -eq $false }
}

$Results | Export-Csv "$($Config.OutputDirectory)\RA_HashMapReport.csv" -NoTypeInformation

Write-Host "Exported Report to: [$($Config.OutputDirectory)\RA_HashMapReport.csv]"

#endregion
