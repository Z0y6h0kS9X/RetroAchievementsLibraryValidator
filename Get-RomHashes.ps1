<#
.SYNOPSIS
This script interacts with the RetroAchievements API to map local ROMs to their corresponding games in the RetroAchievements database.

.DESCRIPTION
This script allows users to hash their local ROM files and match them against games available on the RetroAchievements platform. 
It retrieves a list of active systems and games using the RetroAchievements API, hashes local ROMs, and attempts to find a match for each one. 
Results are stored in a CSV file with details about matched games, including their RetroAchievements game ID and achievement count.

The script processes ROM files from directories specified in the configuration file and reports any matching games along with relevant metadata. 
The CSV output provides a summary of matches for further use.

.INPUTS
The script requires a valid configuration file (config.json) and a set of local ROM directories to scan. The inputs are as follows:
- `config.json` (JSON file)
    - `RA_API_KEY`: Your RetroAchievements API Key (required to interact with the RetroAchievements API).
    - `RA_HASHER_PATH`: Path to the RAHasher program used to calculate ROM hashes.
    - `LIBRARY_PATH`: Path to the folder containing your ROM sub-directories.
    - `OUTPUT_DIRECTORY`: Directory where the results CSV file will be saved.
    - `OUTPUT_MISSING_ONLY`: (True/False) - Specifies whether to output only the ROMs that do not have a retroachievement match.

The directories inside `LIBRARY_PATH` should be named after game platforms (e.g., NES, SNES, etc.) or mapping specified for correct identifiaction and contain the respective ROM files.

.EXAMPLES
Example 1: Run the script to match ROMs from configured directories and export results.
    .\Get-RomHases.ps1

Example 2: Modify config.json to update paths and API key, then run the script again.
    1. Update `RA_API_KEY` in config.json.
    2. Set `LIBRARY_PATH` to point to the folder containing ROM directories.
    3. Run `.\Get-RomHases.ps1`.

.OUTPUTS
The script outputs a CSV file with the following columns:
- `MatchFound`: Boolean indicating if a match was found for the ROM.
- `System`: The platform name for the game system (e.g., NES, SNES).
- `RomName`: The name of the local ROM file.
- `Hash`: The hash of the ROM.
- `Path`: The location of the ROM on the filesystem.
- `RATitle`: The title of the matching game from RetroAchievements.
- `RAID`: The RetroAchievements ID of the game.
- `CheevoCount`: The number of achievements available for the game.

.NOTES
- Ensure that `RA_API_KEY` is correctly configured in the `config.json` file.
- Make sure the `RA_HASHER_PATH` points to the location of the RAHasher executable.
- The directories in `LIBRARY_PATH` must contain ROMs for different platforms, and the directory names should match platform names in RetroAchievements.
- The script requires PowerShell version 5.1 or later.

#>


#region FUNCTIONS

# Function to get a list of active systems from RetroAchievements
FUNCTION Get-RASystemsList {
    # Define the base URL for the API request
    $baseUrl = 'https://retroachievements.org/API/API_GetConsoleIDs.php'
    # Prepare the query parameters, including the API key
    $queryParams = @{ y = $config.RA_API_KEY }
    # Generate the full URL by appending the query parameters
    $fullUrl = Get-FullUrl -baseUrl $baseUrl -queryParams $queryParams
    
    # Send the API request and capture the response
    $response = Invoke-WebRequest -Uri $fullUrl
    # Parse the JSON content from the response
    $jsonContent = $response.Content | ConvertFrom-Json
    
    # Filter and return only active game systems
    return $jsonContent | Where-Object {$_.Active -and $_.IsGameSystem} | Select-Object ID, Name
}

# Function to get the list of games for a specific system
FUNCTION Get-RAGamesList {
    [CmdletBinding()]
    param (
        [string]$SystemID   # System ID to fetch game list for
    )
    
    # Define the base URL for the API request
    $baseUrl = 'https://retroachievements.org/API/API_GetGameList.php'
    # Prepare the query parameters, including the system ID and API key
    $queryParams = @{ y = $config.RA_API_KEY; i = $SystemID; h = 1 }
    # Generate the full URL by appending the query parameters
    $fullUrl = Get-FullUrl -baseUrl $baseUrl -queryParams $queryParams
    
    # Send the API request and capture the response
    $response = Invoke-WebRequest -Uri $fullUrl
    # Parse the JSON content from the response
    $jsonContent = $response.Content | ConvertFrom-Json
    
    # Return relevant fields for each game
    return $jsonContent | Select-Object ID, Title, ConsoleID, ConsoleName, NumAchievements, Hashes
}

# Function to build a complete URL from base URL and query parameters
FUNCTION Get-FullUrl {
    param (
        [string]$baseUrl,       # Base URL to which query parameters are appended
        [hashtable]$queryParams # A hashtable of query parameters
    )
    
    # Convert the hashtable into a query string
    $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
    # Return the full URL
    return "$($baseUrl)?$($queryString)"
}

# Function to test if an API key is valid by making a test API call
FUNCTION Test-ApiKey {
    [CmdletBinding()]
    [OutputType([bool])]  # The function returns a boolean indicating validity
    param (
        # The API key to test
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    # Define the base URL for the API test request
    $baseUrl = "https://retroachievements.org/API/API_GetAchievementOfTheWeek.php"
    # Prepare the query parameters, including the API key
    $queryParams = @{ y = $Key }
    # Generate the full URL by appending the query parameters
    $fullUrl = Get-FullUrl -baseUrl $baseUrl -queryParams $queryParams

    # Send the API request and capture the response
    $response = Invoke-RestMethod -Method Get -Uri $fullUrl
    # If the response is empty, the API key is invalid
    if (-not $response) {
        return $false
    } 
    
    # If there is a valid response, the API key is valid
    return $true
}

# Function to get the platform name corresponding to a given name
FUNCTION Get-PlatformFromName {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Name of the platform to match
        [Parameter()]
        [string]$Name
    )
    
    # If a Mapping_Override exists for the platform, return it immediately
    $systemMatch = $config.PLATFORM_MAPPING | Where-Object {
        $_.Mapping_Override -eq $Name
    }
    if ($systemMatch) {
        return $systemMatch.Platform
    }
    
    # Normalize input name for case-insensitive comparison
    $normalizedName = $Name.ToLower()
    
    # Compare 1: Exact match of the platform name (case-insensitive)
    $systemMatch = $config.PLATFORM_MAPPING | Where-Object {
        $_.Platform.ToLower() -eq $normalizedName
    }
    if ($systemMatch) {
        return $systemMatch.Platform
    }
    
    # Compare 2: Match following Linux naming standard (lowercase, - instead of spaces)
    $normalizedInput = $normalizedName -replace " ", "-" -replace "\s+", "" 
    $systemMatch = $config.PLATFORM_MAPPING | Where-Object {
        ($_.Platform.ToLower() -replace " ", "-") -eq $normalizedInput
    }
    if ($systemMatch) {
        return $systemMatch.Platform
    }
    
    # Compare 3: Check for any configured aliases (case-insensitive)
    foreach ($alias in $config.PLATFORM_MAPPING.Aliases) {
        if ($alias -contains $normalizedName) {
            return $config.PLATFORM_MAPPING | Where-Object { $_.Aliases -contains $alias } | Select-Object -ExpandProperty Platform
        }
    }
    
    # If no match is found, return null
    return $null
}

# Function to show a progress bar with the current step and message
FUNCTION Show-ProgressBar {
    param (
        [int]$CurrentStep,            # Current step being processed
        [int]$TotalSteps,             # Total number of steps
        [string]$Message,             # Message to display
        [int]$BarWidth = 50,          # Width of the progress bar
        [int]$MaxMessageLength,       # Maximum message length for padding
        [string]$SkipMessage = $null  # Optional skip message (shown if total steps are 0)
    )

    # If the total steps are 0, immediately show a skipped message with the reason
    if ($TotalSteps -eq 0) {
        $dotPadding = "." * ($MaxMessageLength - $Message.Length)
        $skipMessage = "$Message$dotPadding SKIPPED ($SkipMessage)"
        Write-Host "`r$skipMessage"
        return
    }

    # Calculate the length of the message and pad with dots for alignment
    $messageLength = $Message.Length
    $dotPadding = "." * ($MaxMessageLength - $messageLength)
    $fullMessage = "$Message$dotPadding"

    # Calculate progress percentage
    $percentComplete = ($CurrentStep / $TotalSteps) * 100

    # If it's the last step, print the DONE message and complete the progress bar
    if ($CurrentStep -eq ($TotalSteps - 1)) {
        $progressBar = "#" * $BarWidth
        $spaces = " " * ($BarWidth - $progressBar.Length)
        $output = "`r$fullMessage [$progressBar$spaces] 100%"
        Write-Host $output -NoNewline

        # Clear the remaining progress bar area with a DONE message
        $doneMessage = "`r$fullMessage DONE"
        $doneMessagePad = " " * ($BarWidth + 10)
        Write-Host "$doneMessage$doneMessagePad" -NoNewline
        Write-Host ""  # Move to the next line after DONE
    }
    else {
        # Regular progress bar update for intermediate steps
        $progressBar = "#" * ($CurrentStep * $BarWidth / $TotalSteps)
        $spaces = " " * ($BarWidth - $progressBar.Length)
        $output = "`r$fullMessage [$progressBar$spaces] $([math]::Round($percentComplete))%"
        Write-Host $output -NoNewline
    }
}

# Function to match a ROM with a game in the RetroAchievements database based on its hash
FUNCTION Get-ROMMatch {
    [CmdletBinding()]
    param (
        [int]$SystemID,            # System ID for the game
        [System.IO.FileInfo]$ROM,  # ROM file to match
        $GameList                  # List of games for the system
    )

    # Use RAHasher to get the hash of the ROM
    $gameHash = cmd /c $config.RA_HASHER_PATH $SystemID $ROM.FullName

    # Check if the hash length is valid (32 characters)
    if ($gameHash.Length -ne 32){
        Write-Error "Unable to parse $($ROM.Name)"
        $gameHash = $null
    }

    # Search for a game with the matching hash
    $gameMatch = $GameList | Where-Object { $_.hashes -match $gameHash }

    # Create an entry object to store the match result
    $entry = [PSCustomObject]@{
        MatchFound = $false
        System = $platform.Platform
        RomName = $localROMs[$i].Name
        Hash = $gameHash
        Path = $platform.Location
        RATitle = ''
        RAID = ''
        CheevoCount = ''
    }
    
    # If a match is found, populate the entry with game details
    if ($gameMatch){
        $entry.MatchFound = $true
        $entry.RATitle = $gameMatch.Title
        $entry.RAID = $gameMatch.ID
        $entry.CheevoCount = $gameMatch.NumAchievements
    }

    return $entry
}

#endregion

#region SCRIPT
# Validate that the config.json file exists, erroring out if not
if (-not (Test-Path ./config.json) ){
    Write-Error "config.json is missing from local directory!"
    Exit 1 
}

# Import configuration from the JSON file
$config = Get-Content -Path ./config.json | ConvertFrom-Json

# Validate the configured library path
if (-not (Test-Path $config.LIBRARY_PATH) ){
    Write-Error "Path to your Library was invalid, was it set in config.json?"
    Exit 1 
}

# Validate the RAHasher path
if (-not (Test-Path $config.RA_HASHER_PATH) ){
    Write-Error "Path to your RAHasher program was invalid, was it set in config.json?"
    Exit 1 
}

# Test the validity of the API key
if (-not (Test-ApiKey -Key $config.RA_API_KEY)){
    Write-Error "API Key Test did not have a successful response, it may be invalid"
    Exit 1
}

# Retrieve platform directories from the specified library path
$platformList = @()
Get-ChildItem -Path $config.LIBRARY_PATH -Directory | ForEach-Object {
    $dirName = $_.BaseName
    $platformMatch = Get-PlatformFromName -Name $dirName    
    if ($platformMatch) {
        Write-Host "Matching $dirName to $($platformMatch)"
        [PSCustomObject]@{
            Platform = $platformMatch
            Location = $_.FullName
        }
    }
} | ForEach-Object {
    # Add matched platforms to the list
    $platformList += $_
}

# Exit if no platforms were matched
if ($platformList.Count -lt 1){
    Write-Error "Could not map any of the subdirectories in [$($config.LIBRARY_PATH)] to platforms on RetroAchievements! Check your configured directories."
    Exit 1
}

# Get a list of active systems from RetroAchievements
$RASystems = Get-RASystemsList

# Initialize an array to store results
$results = New-Object System.Collections.ArrayList 

# Iterate over platforms and try to match ROMs with games
$maxMessageLength = ($platformList | ForEach-Object { ("Processing [$($_.Platform)] ROMs...").Length } | Measure-Object -Maximum).Maximum

foreach ($platform in $platformList) {   
    # Get ROM files for the current platform
    $localROMs = Get-ChildItem -Path $platform.Location -File
    if ($localROMs.Count -eq 0){
        # Skip if no ROMs are found in the folder
        Show-ProgressBar -TotalSteps 0 -Message "Processing [$($platform.Platform)] ROMs..." -SkipMessage "Empty Folder" -MaxMessageLength $maxMessageLength
        Continue
    }

    # Get the system ID for the platform from the active systems list
    $SystemID = ($RASystems | Where-Object { $_.Name -match "^$($platform.Platform)$" }).ID
    # Get the list of games for the system
    $gameList = Get-RAGamesList -SystemID $SystemID

    # Process each ROM in the directory
    for ($i=0; $i -lt ($localROMs.Count); $i++)
    {
        # Display progress with substep message for hashing ROMs
        Show-ProgressBar -CurrentStep $i -TotalSteps $localROMs.Count -Message "Processing [$($platform.Platform)] ROMs..." -MaxMessageLength $maxMessageLength -SubstepMessage "Hashing $($localROMs[$i].BaseName)"
        # Try to match the ROM with a game
        $entry = Get-ROMMatch -SystemID $SystemID -ROM $localROMs[$i] -GameList $gameList

        # Add the entry to the results list
        $results.Add($entry) | Out-Null
    }
}

# If the OUTPUT_MISSING_ONLY is specified, only output ROMs without a retroachievemnet match
if ($config.OUTPUT_MISSING_ONLY){
    $results = $results | Where-Object {$_.Match -eq $false}
}

# Export results to a CSV file
$results | Export-Csv "$($config.OUTPUT_DIRECTORY)\RA_HashMapReport.csv" -NoTypeInformation

# Output a message indicating the report has been saved
Write-Host "Exported Report to: [$($config.OUTPUT_DIRECTORY)\RA_HashMapReport.csv]"

#endregion
