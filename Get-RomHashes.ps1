<#
.SYNOPSIS
    Scans a local ROM library, uses RAHasher to hash ROMs, matches them to RetroAchievements games, 
    and generates a CSV report. Also validates API keys and configuration paths.

.DESCRIPTION
    This script connects to the RetroAchievements API, downloads game/system data, and 
    compares it to local ROM files by hashing them with RAHasher. It maps ROMs to their 
    corresponding RA entries (if any) and exports the results.

.NOTES
    Make sure config.psd1 is properly filled with:
        - APIKey
        - LibraryPath
        - OutputDirectory
        - RaHasherPath
        - PlatformMapping
#>

#region Functions

# Function to get a list of active systems from RetroAchievements
Function Get-RASystemsList {
    # Builds the URL to call
    $BaseUrl = 'https://retroachievements.org/API/API_GetConsoleIDs.php'
    $QueryParams = @{ y = $Config.APIKey }
    $FullUrl = Get-FullUrl -BaseUrl $BaseUrl -QueryParams $QueryParams

    # Calls the URL and converts the response
    $Response = Invoke-WebRequest -Uri $FullUrl
    $JsonContent = $Response.Content | ConvertFrom-Json

    # Returns the necessary info to the caller
    return $JsonContent | Where-Object { $_.Active -and $_.IsGameSystem } | Select-Object ID, Name
}

# Function to get the list of games for a specific system
Function Get-RAGamesList {
    [CmdletBinding()]
    param (
        [string]$SystemId
    )

    # Builds the URL to call
    $BaseUrl = 'https://retroachievements.org/API/API_GetGameList.php'
    $QueryParams = @{ y = $Config.APIKey; i = $SystemId; h = 1 }
    $FullUrl = Get-FullUrl -BaseUrl $BaseUrl -QueryParams $QueryParams

    # Calls the URL and converts the response
    $Response = Invoke-WebRequest -Uri $FullUrl
    $JsonContent = $Response.Content | ConvertFrom-Json

    # Returns the output with necessary information to the caller
    return $JsonContent | Select-Object ID, Title, ConsoleID, ConsoleName, NumAchievements, Hashes
}

# Function to build a complete URL from base URL and query parameters
Function Get-FullUrl {
    param (
        [string]$BaseUrl,
        [hashtable]$QueryParams
    )

    $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
    return "$($BaseUrl)?$($QueryString)"
}

# Function to test if an API key is valid by making a test API call
Function Test-ApiKey {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    # Builds the URL with the API Key
    $BaseUrl = "https://retroachievements.org/API/API_GetAchievementOfTheWeek.php"
    $QueryParams = @{ y = $Key }
    $FullUrl = Get-FullUrl -BaseUrl $BaseUrl -QueryParams $QueryParams

    # Gets the response, if it is empty (unsuccessful) - return false, else return true
    $Response = Invoke-RestMethod -Method Get -Uri $FullUrl
    if (-not $Response) {
        return $false
    }

    return $true
}

# Function to get the platform name corresponding to a given name
Function Get-PlatformFromName {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [string]$Name
    )

    # Normalizes the name to allow matches, despite casing difference
    $NormalizedName = $Name.ToLower()

    # Checks to see if there is a match on the direct normalized name
    $SystemMatch = $Config.PlatformMapping | Where-Object { $_.Platform.ToLower() -eq $NormalizedName }
    if ($SystemMatch) {
        return $SystemMatch.Platform
    }

    # Checks to see if there is match on the name in linux standard naming (- instead of ' ', all lowercase)
    $NormalizedInput = $NormalizedName -replace " ", "-" -replace "\s+", ""
    $SystemMatch = $Config.PlatformMapping | Where-Object {
        ($_.Platform.ToLower() -replace " ", "-") -eq $NormalizedInput
    }
    if ($SystemMatch) {
        return $SystemMatch.Platform
    }

    # Checks to see if there are any matches on any configured alias
    foreach ($Alias in $Config.PlatformMapping.Aliases) {
        if ($Alias -contains $NormalizedName) {
            return ($Config.PlatformMapping | Where-Object { $_.Aliases -contains $Alias }).Platform
        }
    }

    # If no matches to any of the above - match was unsuccessful, return $null
    return $null
}

# Function to match a ROM with a game in the RetroAchievements database based on its hash
Function Get-RomMatch {
    [CmdletBinding()]
    param (
        [int]$SystemId,
        [System.IO.FileInfo]$Rom,
        $GameList
    )

    # Gets the Hash for the given rom and SystemID
    $GameHash = cmd /c "RAHasher.exe" $SystemId $Rom.FullName

    # If the response is not 32 characters long, it did not process successfuly or the rom is bad
    if ($GameHash.Length -ne 32) {
        Write-Error "Unable to parse $($Rom.Name)"
        $GameHash = $null
    }

    # Gets what game has the hash, if applicable
    $GameMatch = $GameList | Where-Object { $_.Hashes -eq $GameHash }

    # Creates the Output Object
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

    # If there was a successful game match, add the following information
    if ($GameMatch) {
        $Entry.MatchFound = $true
        $Entry.RATitle = $GameMatch.Title
        $Entry.RAID = $GameMatch.ID
        $Entry.CheevoCount = $GameMatch.NumAchievements
    }

    # Returns the output to the caller
    return $Entry
}

# Downloads and extracts the RAHasher tool using validated version (1.8.0)
Function Get-RAHasher {
    $URL = "https://github.com/RetroAchievements/RALibretro/releases/download/1.8.0/RAHasher-x64-Windows-1.8.0.zip"

    Invoke-WebRequest -Uri $URL -OutFile "./RAHasher.zip"

    Expand-Archive -Path "./RAHasher.zip" -DestinationPath . -Force 

    Remove-Item -Path "./RAHasher.zip"
}

#endregion

#region Script

# Ensures that the config.psd1 is in the local directory
if (-not (Test-Path ./config.psd1)) {
    Write-Error "config.psd1 is missing from local directory!"
    Exit 1
}

# Imports the values set in the config.psd1 file
if (Test-Path "./config.dev.psd1") {
    # Loads config.dev.psd1 if present, for easy development
    Write-Debug "Using Debug Settings"
    $Config = Import-PowerShellDataFile -Path "config.dev.psd1"
} else {
    $Config = Import-PowerShellDataFile -Path "config.psd1"
}

# Tests to ensure that the Path to the Library specified is valid
if (-not (Test-Path $Config.LibraryPath)) {
    Write-Error "Path to your Library was invalid, was it set in config.psd1?"
    Exit 1
}

# Tests to ensure that the RAHasher executable is located in the current directory
# If not, calls the Get-RAHasher function to download it
if (-not (Test-Path "./RAHasher.exe")) {
    Write-Host "Downloading RAHasher Tool..."
    Get-RAHasher
    # Re-run test to ensure that the RAHasher is located there
    if (-not (Test-Path "./RAHasher.exe")) {
        Write-Error "Unable to locate the RAHasher tool! YOu may need to put it in the script's directory manually."
        Write-Error "Aborting..."
        Exit 1
    }
}

# Tests to ensure that the API Key is valid with a simple global test.
# If it is not, aborts the script
if (-not (Test-ApiKey -Key $Config.APIKey)) {
    Write-Error "API Key Test did not have a successful response, it may be invalid"
    Exit 1
}

# Creates a list of Platforms given the configured aliases/mapping and Library Path
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

# If there were no successful Platform matches, abort before attempting to do anything
if ($PlatformList.Count -lt 1) {
    Write-Error "Could not map any of the subdirectories in [$($Config.LibraryPath)] to platforms on RetroAchievements! Check your configured directories."
    Exit 1
}

# Gets the list of Systems (Platforms) configured and active in RetroAchievements and builds a list to store results
$RaSystems = Get-RASystemsList
$Results = New-Object System.Collections.Generic.List[Object]

# Iterates through each platform and performs processing
for ($L=0; $L -lt ($PlatformList.Count - 1); $L++) {

    $PercentCompleteSystems = [Math]::Min(100, [int]((($L+1) / $PlatformList.Count) * 100))
    Write-Progress -Activity "Processing Systems..." -Status "Checking $($PlatformList[$L].Platform) ($($L+1) of $($PlatformList.Count))" -PercentComplete $PercentCompleteSystems -id 1

    # Gets the list of roms inside of the platform folder
    $LocalRoms = Get-ChildItem -Path $PlatformList[$L].Location -File
    if ($LocalRoms.Count -eq 0) {
        Continue
    }

    # Determines the SystemID based on the Platform Match
    $SystemId = ($RaSystems | Where-Object { $_.Name -match "^$($PlatformList[$L].Platform)$" }).ID

    # Gets all the Game Hashes from a given System ID
    $GameList = Get-RAGamesList -SystemId $SystemId

    # Iterates thorugh all the roms in the platform folder and tries to find Hash matches
    # It then adds the repsonse to the Results
    for ($I = 0; $I -lt ($LocalRoms.Count); $I++) {
        $PercentCompleteGames = [Math]::Min(100, [int]((($I+1) / $LocalRoms.Count) * 100))
        Write-Progress -Activity "Processing ROMs for $($PlatformList[$L].Platform)" -CurrentOperation "$($LocalRoms[$I].Name)" -Status "$($I+1) of $($LocalRoms.Count)" -PercentComplete $PercentCompleteGames -id 2 -ParentId 1
        $Entry = Get-RomMatch -SystemId $SystemId -Rom $LocalRoms[$I] -GameList $GameList
        $Results.Add($Entry) | Out-Null
    }
}

# Filters out all successful matches from the output, if set in the config.psd1
if ($Config.OutputMissingOnly) {
    $Results = $Results | Where-Object { $_.MatchFound -eq $false }
}

# Exports the results to the output directory configured
$Results | Export-Csv "$($Config.OutputDirectory)\RA_HashMapReport.csv" -NoTypeInformation

# Prints completion message and location of the report to the user
Write-Host "Exported Report to: [$($Config.OutputDirectory)\RA_HashMapReport.csv]"

#endregion
