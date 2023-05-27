--****************************************************************************
--**  Summary: Manage structures for a location
--****************************************************************************

local BuilderManager = import("/lua/aibrains/managers/builder-manager.lua").AIBuilderManager

local TableGetSize = table.getsize

local WeakValues = { __mode = 'v' }

--- Table of stringified categories to help determine
---@type AIStructureBuilderTypes[]
StructureBuilderTypes = {
    'FACTORY',
    'MASSEXTRACTION',
    'ENERGYPRODUCTION',
    'RADAR',
    'SONAR',
    'MASSSTORAGE',
    'ENERGYSTORAGE',
    'SHIELD',
}

---@alias AIStructureBuilderTypes 'FACTORY' | 'MASSEXTRACTION' | 'ENERGYPRODUCTION' | 'RADAR' | 'SONAR' | 'MASSSTORAGE' | 'ENERGYSTORAGE' | 'SHIELD'

---@class AIStructureManagerReferences 
---@field TECH1 table<EntityId, Unit>
---@field TECH2 table<EntityId, Unit>
---@field TECH3 table<EntityId, Unit>
---@field EXPERIMENTAL table<EntityId, Unit>

---@class AIStructureManagerCounts
---@field TECH1 number
---@field TECH2 number
---@field TECH3 number
---@field EXPERIMENTAL number

---@class AIStructureManager : AIBuilderManager
---@field BuilderData table<AIStructureBuilderTypes, AIBuilderManagerData>   # Array table of builders
---@field Structures AIStructureManagerReferences
---@field StructuresBeingBuilt AIStructureManagerReferences     
---@field StructureCount AIStructureManagerCounts               # Recomputed every 10 ticks
---@field StructureBeingBuiltCount AIStructureManagerCounts     # Recomputed every 10 ticks
AIStructureManager = Class(BuilderManager) {

    ManagerName = "StructureManager",

    ---@param self AIStructureManager
    ---@param brain AIBrain
    ---@param base AIBase
    Create = function(self, brain, base, locationType)
        BuilderManager.Create(self, brain, base, locationType)
        self.Identifier = 'AIStructureManager at ' .. locationType

        self.Structures = {
            TECH1 = setmetatable({}, WeakValues),
            TECH2 = setmetatable({}, WeakValues),
            TECH3 = setmetatable({}, WeakValues),
            EXPERIMENTAL = setmetatable({}, WeakValues),
        }

        self.StructureCount = {
            TECH1 = 0,
            TECH2 = 0,
            TECH3 = 0,
            EXPERIMENTAL = 0,
        }

        self.StructuresBeingBuilt = {
            TECH1 = setmetatable({}, WeakValues),
            TECH2 = setmetatable({}, WeakValues),
            TECH3 = setmetatable({}, WeakValues),
            EXPERIMENTAL = setmetatable({}, WeakValues),
        }

        self.StructureBeingBuiltCount = {
            TECH1 = 0,
            TECH2 = 0,
            TECH3 = 0,
            EXPERIMENTAL = 0,
        }

        -- TODO: refactor this to base class?
        self.Trash:Add(ForkThread(self.UpdateStructureThread, self))
    end,

    --------------------------------------------------------------------------------------------
    -- manager interface

    ---@param self AIStructureManager
    UpdateStructureThread = function(self)
        while true do
            local total = 0
            local engineers = self.Structures
            local engineerCount = self.StructureCount
            for tech, _ in engineerCount do
                local count = TableGetSize(engineers[tech])
                engineerCount[tech] = count
                total = total + count
            end

            local StructureBeingBuilt = self.StructuresBeingBuilt
            local StructureBeingBuiltCount = self.StructureBeingBuiltCount
            for tech, _ in StructureBeingBuiltCount do
                local count = TableGetSize(StructureBeingBuilt[tech])
                StructureBeingBuiltCount[tech] = count
                total = total + count
            end
            WaitTicks(10)
        end
    end,

    --------------------------------------------------------------------------------------------
    -- unit events

    --- Called by a unit as it starts being built
    ---@param self AIStructureManager
    ---@param unit Unit
    ---@param builder Unit
    ---@param layer Layer
    OnUnitStartBeingBuilt = function(self, unit, builder, layer)
        local blueprint = unit.Blueprint
        if blueprint.CategoriesHash['STRUCTURE'] then
            local tech = blueprint.TechCategory
            local id = unit.EntityId
            self.StructuresBeingBuilt[tech][id] = unit
        end
    end,

    --- Called by a unit as it is finished being built
    ---@param self AIStructureManager
    ---@param unit Unit
    ---@param builder Unit
    ---@param layer Layer
    OnUnitStopBeingBuilt = function(self, unit, builder, layer)
        local blueprint = unit.Blueprint
        if blueprint.CategoriesHash['STRUCTURE'] then
            local tech = blueprint.TechCategory
            local id = unit.EntityId
            self.StructuresBeingBuilt[tech][id] = nil
            self.Structures[tech][id] = unit

            -- create the platoon and start the behavior
            local brain = self.Brain
            local platoon = brain:MakePlatoon('', '') --[[@as AIPlatoonSimpleStructure]]
            platoon.Brain = self.Brain
            platoon.Base = self.Base
            
            setmetatable(platoon, import("/lua/aibrains/platoons/platoon-simple-structure.lua").AIPlatoonSimpleStructure)
            brain:AssignUnitsToPlatoon(platoon, {unit}, 'Unassigned', 'None')
            ChangeState(platoon, platoon.Start)
        end
    end,

    --- Called by a unit as it is destroyed
    ---@param self AIStructureManager
    ---@param unit Unit
    OnUnitDestroyed = function(self, unit)
        local blueprint = unit.Blueprint
        if blueprint.CategoriesHash['STRUCTURE'] then
            local tech = blueprint.TechCategory
            local id = unit.EntityId
            self.StructuresBeingBuilt[tech][id] = nil
            self.Structures[tech][id] = nil
        end
    end,

    --- Called by a unit as it starts building
    ---@param self BuilderManager
    ---@param unit Unit
    ---@param built Unit
    OnUnitStartBuilding = function(self, unit, built)
    end,

    --- Called by a unit as it stops building
    ---@param self BuilderManager
    ---@param unit Unit
    ---@param built Unit
    OnUnitStopBuilding = function(self, unit, built)
    end,

    --------------------------------------------------------------------------------------------
    -- unit interface

    --- Add a unit, similar to calling `OnUnitStopBeingBuilt`
    ---@param self AIStructureManager
    ---@param unit Unit
    AddUnit = function(self, unit)
        self:OnUnitStopBeingBuilt(unit, nil, unit.Layer)
    end,

    --- Remove a unit, similar to calling `OnUnitDestroyed`
    ---@param self AIStructureManager
    ---@param unit Unit
    RemoveUnit = function(self, unit)
        self:OnUnitDestroyed(unit)
    end,
}

---@param brain AIBrain
---@param base AIBase
---@param locationType LocationType
---@return AIStructureManager
function CreateStructureManager(brain, base, locationType)
    local manager = AIStructureManager()
    manager:Create(brain, base, locationType)
    return manager
end
