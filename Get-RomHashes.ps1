#TODO
# Suppress RAHasher warnings
# Add write-progress and sub progress

# Path to ROM files
# ROMs should be contained within folders of each system
$ROM_BASE_PATH = ''
# Path to the RAHasher.exe program
$RAHASHER_PATH = ''
# Path to export hash report
$HASH_OUTPUT_PATH = ''

# Retroachievements username and web API key
# API key found/generated here: https://retroachievements.org/controlpanel.php
$RA_USERNAME = ''
$RA_API_KEY = ''

# Match the below systems to the system folders within $ROM_BASE_PATH
$SYSTEM_TO_FOLDER_MAP = @{
    '32X'                         = ''
    '3DO Interactive Multiplayer' = ''
    'Amstrad CPC'                 = ''
    'Apple II'                    = ''
    'Arcade'                      = ''
    'Arcadia 2001'                = ''
    'Arduboy'                     = ''
    'Atari 2600'                  = ''
    'Atari 7800'                  = ''
    'Atari Jaguar'                = ''
    'Atari Jaguar CD'             = ''
    'Atari Lynx'                  = ''
    'ColecoVision'                = ''
    'Dreamcast'                   = ''
    'Elektor TV Games Computer'   = ''
    'Fairchild Channel F'         = ''
    'Game Boy'                    = 'gb'
    'Game Boy Advance'            = 'gba'
    'Game Boy Color'              = 'gbc'
    'Game Gear'                   = ''
    'GameCube'                    = 'gc'
    'Genesis/Mega Drive'          = ''
    'Intellivision'               = ''
    'Interton VC 4000'            = ''
    'Magnavox Odyssey 2'          = ''
    'Master System'               = ''
    'Mega Duck'                   = ''
    'MSX'                         = ''
    'Neo Geo CD'                  = ''
    'Neo Geo Pocket'              = ''
    'NES/Famicom'                 = 'nes'
    'Nintendo 64'                 = 'n64'
    'Nintendo DS'                 = 'nds'
    'Nintendo DSi'                = ''
    'PC Engine CD/TurboGrafx-CD'  = ''
    'PC Engine/TurboGrafx-16'     = ''
    'PC-8000/8800'                = ''
    'PC-FX'                       = ''
    'PlayStation'                 = 'psx'
    'PlayStation 2'               = 'ps2'
    'PlayStation Portable'        = 'psp'
    'Pokemon Mini'                = ''
    'Saturn'                      = ''
    'Sega CD'                     = ''
    'SG-1000'                     = ''
    'SNES/Super Famicom'          = 'snes'
    'Standalone'                  = ''
    'Uzebox'                      = ''
    'Vectrex'                     = ''
    'Virtual Boy'                 = ''
    'WASM-4'                      = ''
    'Watara Supervision'          = ''
    'WonderSwan'                  = ''
}

# Gets a full system list from RetroAchievements
function Get-RASystemsList {
    $ConsolesBasePath = 'https://retroachievements.org/API/API_GetConsoleIDs.php'
    $ConsolesArgs = "z=$RA_USERNAME&y=$RA_API_KEY&a=1&g=1"
    $ConsolesFullPath = $ConsolesBasePath + "?" + $ConsolesArgs
    
    $Consoles = (Invoke-WebRequest $ConsolesFullPath).Content
    
    return ($Consoles | ConvertFrom-Json) | Select-Object ID, Name
}

# Gets a full game list for a given system from RetroAchievements
function Get-RAGamesList ([string]$SystemID) {
    $GamesBasePath =  'https://retroachievements.org/API/API_GetGameList.php'
    $GamesArgs = "z=$RA_USERNAME&y=$RA_API_KEY&i=$SystemID&h=1"
    $GamesFullPath = $GamesBasePath + "?" + $GamesArgs

    $Games = (Invoke-WebRequest $GamesFullPath).Content
    
    return ($Games | ConvertFrom-Json) | Select-Object ID, Title, ConsoleID, ConsoleName, NumAchievements, Hashes
}

# Create a list of systems where a folder path was provided
$Systems = [System.Collections.Generic.List[Object]]::New()
Write-Host "Compiling list of known systems..."
$SYSTEM_TO_FOLDER_MAP.Keys | ForEach-Object {
    If ($SYSTEM_TO_FOLDER_MAP.$_) {
        $Systems.Add([PSCustomObject]@{
            System = $_
            SystemFolder = $SYSTEM_TO_FOLDER_MAP.$_
        })
    }
}

If ($Systems.Count -lt 1) {
    Write-Host "No system paths mapped. Please update `$SYSTEM_TO_FOLDER_MAP and rerun the script." -ForegroundColor Red
    Exit
}

$PathFound = $False
$SystemsToRemove = @()

# Remove systems from the list that have invalid paths
Foreach ($System in $Systems) {
    If (-not(Test-Path -Path "$ROM_BASE_PATH\$($System.SystemFolder)")) {
        Write-Host "Invalid path: $ROM_BASE_PATH\$($System.SystemFolder). Skipping path for hash matching." -ForegroundColor Red
        $SystemsToRemove += $System 
        Continue
    }
    $PathFound = $True
}

$SystemsToRemove | ForEach-Object { $Systems.Remove($_) } | Out-Null

If (-not($PathFound)) {
    Write-Host "None of the provided system paths are valid. Please update the system values in `$SYSTEM_TO_FOLDER_MAP to match the subfolders found in $ROM_BASE_PATH and rerun the script." -ForegroundColor Red
    Exit
}

$RASystems = Get-RASystemsList

$HashOutputObject = [System.Collections.Generic.List[Object]]::New()

$SystemCount = 1
Foreach ($System in $Systems) {
    Write-Progress -Activity "Checking $($System.System)..." -Status "$SystemCount of $($Systems.count)" -PercentComplete "$($SystemCount/$Systems.count)" -id 1
    
    $SystemID = $RASystems | Where-Object { $_.Name -eq $System.System } | Select-Object -ExpandProperty ID
    $RAGames = Get-RAGamesList -SystemID $SystemID

    $RomFiles = Get-ChildItem -Path "$ROM_BASE_PATH\$($System.SystemFolder)" -File
    $GameCount = 1
    Foreach ($RomFile in $RomFiles) {
        Write-Progress -Activity "Checking $($RomFile.Name)..." -Status "$GameCount of $($RomFiles.count)" -PercentComplete "$($GameCount/$RomFiles.count)" -id 2 -ParentId 1
        # Get the current ROM file hash
        $FileHash = cmd /c "$RAHASHER_PATH\RAHasher.exe" $SystemID $RomFile.FullName

        # If the hash is malformed, set the match to false
        If ($FileHash.Length -ne 32) {
            Write-Host "Unable to parse $($RomFile.Name)" -ForegroundColor Red
            $HashOutputObject.add([PSCustomObject]@{
                MatchFound = $false
                System = $System.System
                RomName = $RomFile.Name
                Hash = $FileHash
                Path = "$ROM_BASE_PATH\$($System.SystemFolder)"
                RATitle = ''
                RAID = ''
                CheevoCount = ''
            })
            $GameCount++
            Continue
        }

        # If no RA match was found on the hash, set the match as false
        $RomMatch = $RAGames | Where-Object { $_.hashes -match $FileHash }
        If (($RomMatch | Measure-Object).Count -lt 1) {
            #Write-Host "Bad file hash for $($RomFile.Name)" -ForegroundColor Red
            $HashOutputObject.add([PSCustomObject]@{
                MatchFound = $false
                System = $System.System
                RomName = $RomFile.Name
                Hash = $FileHash
                Path = "$ROM_BASE_PATH\$($System.SystemFolder)"
                RATitle = ''
                RAID = ''
                CheevoCount = ''
            })
            $GameCount++
            Continue
        }

        # If a match is found on the hash, set the match to true and add the RA details to the output
        $HashOutputObject.add([PSCustomObject]@{
            MatchFound = $true
            System = $System.System
            RomName = $RomFile.Name
            Hash = $FileHash
            Path = "$ROM_BASE_PATH\$($System.SystemFolder)"
            RATitle = $RomMatch.Title
            RAID = $RomMatch.ID
            CheevoCount = $RomMatch.NumAchievements
        })
        $GameCount++
    }
    $SystemCount++
}

# Output CSV report
$HashOutputObject | Export-Csv "$HASH_OUTPUT_PATH\RA_HashMapReport.csv" -NoTypeInformation
