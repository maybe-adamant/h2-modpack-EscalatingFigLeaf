local mods = rom.mods
mods['SGG_Modding-ENVY'].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods['SGG_Modding-ModUtil']
chalk = mods['SGG_Modding-Chalk']
reload = mods['SGG_Modding-ReLoad']
local lib = mods['adamant-ModpackLib']

config = chalk.auto('config.lua')
public.config = config

local _, revert = lib.createBackupSystem()

-- =============================================================================
-- MODULE DEFINITION
-- =============================================================================

public.definition = {
    id       = "EscalatingFigLeaf",
    name     = "Incrementing Fig Leaf",
    category = "Run Modifiers",
    group    = "World & Combat Tweaks",
    tooltip  = "Dionysus Skip Chance starts at default value and increases by 13% after every encounter, resetting on biome start.",
    default  = false,
    dataMutation = false,
    modpack = "h2-modpack",
}

-- =============================================================================
-- MODULE LOGIC
-- =============================================================================

local function apply()
end

local function registerHooks()
    modutil.mod.Path.Wrap("DionysusSkipTrait", function(baseFunc, args, traitData)
        if not lib.isEnabled(config, public.definition.modpack) then return baseFunc(args, traitData) end
        baseFunc(args, traitData)
        for _, trait in ipairs(CurrentRun.Hero.Traits) do
            if trait.Name == "PersistentDionysusSkipKeepsake" then
                trait.InitialSkipEncounterChance = trait.SkipEncounterChance
                trait.SkipEncounterGrowthPerRoom = 0.13
                break
            end
        end
    end)

    modutil.mod.Path.Wrap("EndEncounterEffects", function(baseFunc, currentRun, currentRoom, currentEncounter)
        if not lib.isEnabled(config, public.definition.modpack) then return baseFunc(currentRun, currentRoom, currentEncounter) end
        baseFunc(currentRun, currentRoom, currentEncounter)
        if currentEncounter == currentRoom.Encounter or currentEncounter == MapState.EncounterOverride then
            if HeroHasTrait("PersistentDionysusSkipKeepsake") then
                local traitData = GetHeroTrait("PersistentDionysusSkipKeepsake")
                if traitData.SkipEncounterChance and traitData.SkipEncounterGrowthPerRoom then
                    traitData.SkipEncounterChance = math.min(1, traitData.SkipEncounterChance + traitData.SkipEncounterGrowthPerRoom)
                end
            end
        end
    end)

    modutil.mod.Path.Wrap("StartRoom", function(baseFunc, currentRun, currentRoom)
        if not lib.isEnabled(config, public.definition.modpack) then return baseFunc(currentRun, currentRoom) end
        baseFunc(currentRun, currentRoom)
        if currentRoom.BiomeStartRoom then
            if HeroHasTrait("PersistentDionysusSkipKeepsake") then
                local traitData = GetHeroTrait("PersistentDionysusSkipKeepsake")
                if traitData.InitialSkipEncounterChance then
                    traitData.SkipEncounterChance = traitData.InitialSkipEncounterChance
                end
            end
        end
    end)
end

-- =============================================================================
-- Wiring
-- =============================================================================

public.definition.apply = apply
public.definition.revert = revert

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(function()
        import_as_fallback(rom.game)
        registerHooks()
        if lib.isEnabled(config, public.definition.modpack) then apply() end
        if public.definition.dataMutation and not lib.isCoordinated(public.definition.modpack) then
            SetupRunData()
        end
    end)
end)

local uiCallback = lib.standaloneUI(public.definition, config, apply, revert)
rom.gui.add_to_menu_bar(uiCallback)
