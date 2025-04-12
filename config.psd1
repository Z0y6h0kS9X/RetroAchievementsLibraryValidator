@{
    # Path to the game library containing subfolders with your platorms
    # e.g. C:\Games\Retro
    LibraryPath       = ''

    # Directory where output will be written
    OutputDirectory   = ''

    # If true, only output entries that do not have a RetroAchievements match
    OutputMissingOnly = $false

    # RetroAchievements API key
    APIKey            = ''

    # Platform to alias mappings
    # It will automatically test and associate common aliases and linux naming standards (Nintendo GameCube -> nintendo-gamecube)
    # Add an alias with your platform's folder name if it does not already exist
    PlatformMapping = @(
        @{
            Platform = '32X'
            Aliases  = @()
        },
        @{
            Platform = '3DO Interactive Multiplayer'
            Aliases  = @('3do')
        },
        @{
            Platform = 'Amstrad CPC'
            Aliases  = @('cpc')
        },
        @{
            Platform = 'Apple II'
            Aliases  = @('a2')
        },
        @{
            Platform = 'Arcade'
            Aliases  = @('arc', 'mame', 'fbneo')
        },
        @{
            Platform = 'Arcadia 2001'
            Aliases  = @('a2001')
        },
        @{
            Platform = 'Arduboy'
            Aliases  = @('ard')
        },
        @{
            Platform = 'Atari 2600'
            Aliases  = @('2600')
        },
        @{
            Platform = 'Atari 7800'
            Aliases  = @('7800')
        },
        @{
            Platform = 'Atari Jaguar'
            Aliases  = @('jag')
        },
        @{
            Platform = 'Atari Jaguar CD'
            Aliases  = @('jcd')
        },
        @{
            Platform = 'Atari Lynx'
            Aliases  = @('lynx')
        },
        @{
            Platform = 'ColecoVision'
            Aliases  = @('cv')
        },
        @{
            Platform = 'Dreamcast'
            Aliases  = @('dc')
        },
        @{
            Platform = 'Elektor TV Games Computer'
            Aliases  = @('elek')
        },
        @{
            Platform = 'Fairchild Channel F'
            Aliases  = @('chf')
        },
        @{
            Platform = 'Game Boy'
            Aliases  = @('gb')
        },
        @{
            Platform = 'Game Boy Advance'
            Aliases  = @('gba')
        },
        @{
            Platform = 'Game Boy Color'
            Aliases  = @('gbc')
        },
        @{
            Platform = 'Game Gear'
            Aliases  = @('gg')
        },
        @{
            Platform = 'GameCube'
            Aliases  = @('gc', 'ngc')
        },
        @{
            Platform = 'Genesis/Mega Drive'
            Aliases  = @('md', 'megadrive', 'genesis')
        },
        @{
            Platform = 'Intellivision'
            Aliases  = @('intv')
        },
        @{
            Platform = 'Interton VC 4000'
            Aliases  = @('vc4000')
        },
        @{
            Platform = 'Magnavox Odyssey 2'
            Aliases  = @('mo2')
        },
        @{
            Platform = 'Master System'
            Aliases  = @('sms')
        },
        @{
            Platform = 'Mega Duck'
            Aliases  = @('duck')
        },
        @{
            Platform = 'MSX'
            Aliases  = @('msx')
        },
        @{
            Platform = 'Neo Geo CD'
            Aliases  = @('ngcd')
        },
        @{
            Platform = 'Neo Geo Pocket'
            Aliases  = @('ngp')
        },
        @{
            Platform = 'NES/Famicom'
            Aliases  = @('nes', 'famicom')
        },
        @{
            Platform = 'Nintendo 64'
            Aliases  = @('n64')
        },
        @{
            Platform = 'Nintendo DS'
            Aliases  = @('ds', 'nds')
        },
        @{
            Platform = 'Nintendo DSi'
            Aliases  = @('dsi', 'ndsi')
        },
        @{
            Platform = 'PC Engine CD/TurboGrafx-CD'
            Aliases  = @('pccd')
        },
        @{
            Platform = 'PC Engine/TurboGrafx-16'
            Aliases  = @('pce')
        },
        @{
            Platform = 'PC-8000/8800'
            Aliases  = @('8088')
        },
        @{
            Platform = 'PC-FX'
            Aliases  = @('pc-fx')
        },
        @{
            Platform = 'PlayStation'
            Aliases  = @('psx', 'ps', 'ps1')
        },
        @{
            Platform = 'PlayStation 2'
            Aliases  = @('ps2')
        },
        @{
            Platform = 'PlayStation Portable'
            Aliases  = @('psp')
        },
        @{
            Platform = 'Pokemon Mini'
            Aliases  = @('mini')
        },
        @{
            Platform = 'Saturn'
            Aliases  = @('sat', 'saturn')
        },
        @{
            Platform = 'Sega CD'
            Aliases  = @('scd')
        },
        @{
            Platform = 'SG-1000'
            Aliases  = @('sg1000', 'sg1k')
        },
        @{
            Platform = 'SNES/Super Famicom'
            Aliases  = @('snes', 'super-famicom')
        },
        @{
            Platform = 'Standalone'
            Aliases  = @('exe')
        },
        @{
            Platform = 'Uzebox'
            Aliases  = @('uze')
        },
        @{
            Platform = 'Vectrex'
            Aliases  = @('vect')
        },
        @{
            Platform = 'Virtual Boy'
            Aliases  = @('vb')
        },
        @{
            Platform = 'WASM-4'
            Aliases  = @('wasm4')
        },
        @{
            Platform = 'Watara Supervision'
            Aliases  = @('wsv')
        },
        @{
            Platform = 'WonderSwan'
            Aliases  = @('ws')
        }
    )
}
