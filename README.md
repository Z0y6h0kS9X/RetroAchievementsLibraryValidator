# RetroAchievements Library Validator

This project aims to make the process of checking the validity of your ROMs for RetroAchievements a breeze. Just download the script or clone the repository, configure your variables, and get a report of which ROMs are valid for earning achievements. If you have any questions, please feel free to message me on Reddit under the same username.

## Prerequisites

Before using the script, ensure you have the following prerequisites set up:

1. **RetroAchievements Account**:
   - You need a RetroAchievements account and API key.
   - You can find or generate your API key by logging into [RetroAchievements](https://retroachievements.org) and navigating to the control panel: [https://retroachievements.org/controlpanel.php](https://retroachievements.org/controlpanel.php).

2. **PowerShell**:
   - Ensure you are using PowerShell to run this script.

## Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Siallus/RetroAchievementsLibraryValidator
   ```

2. **Configure Script Variables**:

   Open the config.psd1 and set the following variables according to your system configuration:

   - `LibraryPath`: Path to the root folder containing your ROMs. Each system should have its own subfolder within this path.
   - `PlatformMapping`: The name of the subfolders to map to the RetroAchievement platforms.  It will try to enumerate common names automatically.
   - `OutputDirectory`: Path to the folder where the hash report will be exported.
   - `OutputMissingOnly`: (True/False) - Specifies whether to generate a full report, or only return values that do not have a RetroAcheivements match.
   - `APIKey`: Your RetroAchievements API key.
   
## Running the Script

Once everything is set up, you can run the script to hash your ROMs and generate a report.

1. Open PowerShell and navigate to the directory where the script is located.
2. Run the script:
   ```powershell
   .\Get-RomHashes.ps1
   ```

The script will attempt to match each ROM file in your specified system folders with the RetroAchievements database. It will generate a CSV file at the specified `OutputDirectory`, detailing the results of each match, including game titles and achievement counts.

## CSV Output

The resulting CSV report contains the following columns:

- `MatchFound`: Indicates whether a matching ROM was found in the RetroAchievements database.
- `System`: The system name (e.g., NES, SNES).
- `RomName`: The filename of the ROM.
- `Hash`: The calculated hash of the ROM file.
- `Path`: The folder path where the ROM is located.
- `RATitle`: The game title according to RetroAchievements.
- `RAID`: The RetroAchievements ID of the game.
- `CheevoCount`: The number of achievements for the game.

## Notes

- Ensure that your system folder names in `PlatformMapping` match exactly with the corresponding subfolders in `$LibraryPath`, or are one of the platform's configures aliases.
- The script uses RAHasher to generate hashes for ROMs.

## Disclaimer

This script is a work in progress but is expected to function well into the future given the stability and longevity of the tools it utilizes, such as RAHasher and the RetroAchievements API.

## Future Enhancements

- Add support for renaming ROMs to match the RetroAchievements standard.
- Add support for checking individual ROMs.
- Add additional error checking and handling.
- General cleanup.
