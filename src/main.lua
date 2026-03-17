local mods = rom.mods
mods['SGG_Modding-ENVY'].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods['SGG_Modding-ModUtil']
chalk = mods['SGG_Modding-Chalk']
reload = mods['SGG_Modding-ReLoad']
local lib = mods['adamant-Modpack_Lib'].public

config = chalk.auto('config.lua')
public.config = config

local backup, restore = lib.createBackupSystem()

-- =============================================================================
-- MODULE DEFINITION
-- =============================================================================

public.definition = {
    id       = "EscalatingFigLeaf",
    name     = "Incrementing Fig Leaf",
    category = "RunModifiers",
    group    = "World & Combat Tweaks",
    tooltip  = "Dionysus Skip Chance starts at default value and increases by 13% after every encounter, resetting on biome start.",
    default  = false,
    dataMutation = false,
}

-- =============================================================================
-- MODULE LOGIC
-- =============================================================================

local function apply()
end

local function registerHooks()
    modutil.mod.Path.Wrap("DionysusSkipTrait", function(baseFunc, args, traitData)
        if not config.Enabled then return baseFunc(args, traitData) end
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
        if not config.Enabled then return baseFunc(currentRun, currentRoom, currentEncounter) end
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
        if not config.Enabled then return baseFunc(currentRun, currentRoom) end
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

public.definition.enable = apply
public.definition.disable = restore

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(function()
        import_as_fallback(rom.game)
        registerHooks()
        if config.Enabled then apply() end
        if public.definition.dataMutation and not mods['adamant-Core'] then
            SetupRunData()
        end
    end)
end)

lib.standaloneUI(public.definition, config, apply, restore)
