local addonName, addon = ...
local E = addon:Eve()

local CACHE_TIMEOUT = 5

local print = function()
end
local GuidCache = {}
local ActiveGUID
local ScannedGUID
local INSPECT_TIMEOUT = 1.5

local LOADING_ILVL = RETRIEVING_DATA
local ILVL_PENDING = format("%s %s", INSPECT, strlower(CLUB_FINDER_PENDING or "Pending"))

local CovenantCache = {}
local CovenantColors = {
    [1] = "e6e0e7",
    [2] = "f71010",
    [3] = "41fafe",
    [4] = "18efa5"
}

local CovenantIcons = {
    [1] = 3586266,
    [2] = 3586270,
    [3] = 3586268,
    [4] = 3586267
}
local CovenantSpells = {
    [324739] = 1,
    [312202] = 1,
    [306830] = 1,
    [326434] = 1,
    [308491] = 1,
    [307443] = 1,
    [310454] = 1,
    [304971] = 1,
    [325013] = 1,
    [323547] = 1,
    [324386] = 1,
    [312321] = 1,
    [307865] = 1,
    [328266] = 1,
    [333950] = 1,
    [329791] = 1,
    [300728] = 2,
    [311648] = 2,
    [317009] = 2,
    [323546] = 2,
    [326860] = 2,
    [314793] = 2,
    [316958] = 2,
    [323673] = 2,
    [323654] = 2,
    [320674] = 2,
    [321792] = 2,
    [317320] = 2,
    [324149] = 2,
    [340159] = 2,
    [331586] = 2,
    [336239] = 2,
    [310143] = 3,
    [324128] = 3,
    [323639] = 3,
    [323764] = 3,
    [328231] = 3,
    [314791] = 3,
    [327104] = 3,
    [328620] = 3,
    [327661] = 3,
    [328305] = 3,
    [328923] = 3,
    [325640] = 3,
    [325886] = 3,
    [319217] = 3,
    [325066] = 3,
    [322721] = 3,
    [324701] = 3,
    [324631] = 4,
    [315443] = 4,
    [329554] = 4,
    [325727] = 4,
    [325028] = 4,
    [324220] = 4,
    [325216] = 4,
    [328204] = 4,
    [324724] = 4,
    [328547] = 4,
    [326059] = 4,
    [325289] = 4,
    [324143] = 4,
    [323074] = 4,
    [342156] = 4,
    [326514] = 4
}

local function GetUnitIDFromGUID(guid)
    local _, _, _, _, _, name = GetPlayerInfoByGUID(guid)
    if UnitExists(name) then
        return name, name
    elseif UnitGUID("mouseover") == guid then
        return "mouseover", name
    elseif UnitGUID("target") == guid then
        return "target", name
    elseif GetCVar("nameplateShowFriends") == "1" then
        for i = 1, 30 do
            local unitID = "nameplate" .. i
            local nameplateGUID = UnitGUID(unitID)
            if nameplateGUID then
                if nameplateGUID == guid then
                    return unitID, name
                end
            else
                break
            end
        end
    else
        local numMembers = GetNumGroupMembers()
        if numMembers > 0 then
            local unitPrefix = IsInRaid() and "raid" or "party"
            if unitPrefix == "party" then
                numMembers = numMembers - 1
            end
            for i = 1, numMembers do
                local unitID = unitPrefix .. i .. "-target"
                local targetGUID = UnitGUID(unitID)
                if targetGUID == guid then
                    return unitID, name
                end
            end
        end
    end
    return nil, name
end

local function ColorGradient(perc, r1, g1, b1, r2, g2, b2)
    if perc >= 1 then
        local r, g, b = r2, g2, b2
        return r, g, b
    elseif perc <= 0 then
        local r, g, b = r1, g1, b1
        return r, g, b
    end
    return r1 + (r2 - r1) * perc, g1 + (g2 - g1) * perc, b1 + (b2 - b1) * perc
end

local function ColorDiff(a, b)
    local diff = a - b
    local perc = diff / 30

    local r, g, b
    if perc < 0 then
        perc = perc * -1
        r, g, b = ColorGradient(perc, 1, 1, 0, 0, 1, 0)
    else
        r, g, b = ColorGradient(perc, 1, 1, 0, 1, 0, 0)
    end
    return r, g, b
end

local ItemLevelPattern1 = ITEM_LEVEL:gsub("%%d", "(%%d+)")
local ItemLevelPattern2 = ITEM_LEVEL_ALT:gsub("([()])", "%%%1"):gsub("%%d", "(%%d+)")

local TwoHanders = {
    ["INVTYPE_RANGED"] = true,
    ["INVTYPE_RANGEDRIGHT"] = true,
    ["INVTYPE_2HWEAPON"] = true
}

local InventorySlots = {}
for i = 1, 17 do
    if i ~= 4 then
        tinsert(InventorySlots, i)
    end
end

local function IsArtifact(itemLink)
    return itemLink:find("|cffe6cc80")
end

local function IsLegendary(itemLink)
    return itemLink:find('|cffff8000')
end

local function IsCached(itemLink)
    local cached = true
    local _, itemID, _, relic1, relic2, relic3 = strsplit(":", itemLink)
    print(strsplit(":", itemLink))
    if not GetDetailedItemLevelInfo(itemID) then
        cached = false
    end
    if IsArtifact(itemLink) then
        if relic1 and relic1 ~= "" and not GetDetailedItemLevelInfo(relic1) then
            cached = false
        end
        if relic2 and relic2 ~= "" and not GetDetailedItemLevelInfo(relic2) then
            cached = false
        end
        if relic3 and relic3 ~= "" and not GetDetailedItemLevelInfo(relic3) then
            cached = false
        end
    end
    print(cached)
    return cached
end

local Sekret = "|Hilvl|h"
local function AddLine(sekret, leftText, rightText, r1, g1, b1, r2, g2, b2, dontShow)
    if not r1 then
        r1, g1, b1, r2, g2, b2 = 1, 1, 0, 1, 1, 0
    end
    leftText = sekret .. leftText
    for i = 2, GameTooltip:NumLines() do
        local leftStr = _G["GameTooltipTextLeft" .. i]
        local text = leftStr and leftStr:IsShown() and leftStr:GetText()
        if text and text:find(sekret) then
            local rightStr = _G['GameTooltipTextRight' .. i]
            leftStr:SetText(leftText)
            rightStr:SetText(rightText)
            if r1 and g1 and b1 then
                leftStr:SetTextColor(r1, g1, b1)
            end
            if r2 and g2 and b2 then
                rightStr:SetTextColor(r2, g2, b2)
            end
            return
        end
    end
    if not dontShow or GameTooltip:IsShown() then
        GameTooltip:AddDoubleLine(leftText, rightText, r1, g1, b1, r2, g2, b2)
        GameTooltip:Show()
    end
end

local SlotCache = {}
local ItemCache = {}
local TestTips = {}
for i, slot in pairs({}) do
    local tip = CreateFrame("GameTooltip", "FastItemLevelTooltip" .. slot, nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    TestTips[slot] = tip
    tip.slot = slot
    tip:SetScript("OnTooltipSetItem", function(self)
        local slot = self.slot
        local _, itemLink = self:GetItem()
        local tipName = self:GetName()
        if self.itemLink then
            itemLink = self.itemLink
        end
        if itemLink then
            local isCached = IsCached(itemLink)
            if isCached then
                for i = 2, self:NumLines() do
                    local str = _G[tipName .. "TextLeft" .. i]
                    local text = str and str:GetText()
                    if text then
                        local ilevel = text:match(ItemLevelPattern1)
                        if not ilevel then
                            ilevel = text:match(ItemLevelPattern2)
                        end
                        if ilevel then
                            SlotCache[slot] = tonumber(ilevel)
                            ItemCache[slot] = itemLink
                        end
                    end
                end
            end
        end

        local finished = true
        local totalItemLevel = 0
        for slot, ilevel in pairs(SlotCache) do
            if not ilevel then
                finished = false
                break
            else
                if slot ~= 16 and slot ~= 17 then
                    totalItemLevel = totalItemLevel + ilevel
                end
            end
        end

        if finished then
            local weaponLevel = 0
            local isDual = false
            if SlotCache[16] and SlotCache[17] then
                isDual = true
                if IsArtifact(ItemCache[16]) or IsArtifact(ItemCache[17]) then
                    local ilevelMain = SlotCache[16]
                    local ilevelOff = SlotCache[17]
                    weaponLevel = ilevelMain > ilevelOff and ilevelMain or ilevelOff
                    totalItemLevel = totalItemLevel + (weaponLevel * 2)
                else
                    local ilevelMain = SlotCache[16]
                    local ilevelOff = SlotCache[17]
                    totalItemLevel = totalItemLevel + ilevelMain + ilevelOff
                    if ilevelMain > ilevelOff then
                        weaponLevel = ilevelMain
                    else
                        weaponLevel = ilevelOff
                    end
                end
            elseif SlotCache[16] then
                local _, _, _, weaponType = GetItemInfoInstant(ItemCache[16])
                local ilevelMain = SlotCache[16]
                weaponLevel = ilevelMain
                if TwoHanders[weaponType] then
                    totalItemLevel = totalItemLevel + (ilevelMain * 2)
                else
                    totalItemLevel = totalItemLevel + ilevelMain
                end
            elseif SlotCache[17] then
                local ilevelOff = SlotCache[17]
                totalItemLevel = totalItemLevel + ilevelOff
                weaponLevel = ilevelOff
            end

            if weaponLevel >= 900 and ScannedGUID ~= UnitGUID("player") then
                weaponLevel = weaponLevel + 15
                if isDual then
                    totalItemLevel = totalItemLevel + 15
                else
                    totalItemLevel = totalItemLevel + 30
                end
            end

            local fastItemLevel = totalItemLevel / 16
            local guid = ScannedGUID
            if not GuidCache[guid] then
                GuidCache[guid] = {}
            end
            GuidCache[guid].ilevel = fastItemLevel
            GuidCache[guid].weaponLevel = weaponLevel
            GuidCache[guid].neckLevel = SlotCache[2]
            GuidCache[guid].timestamp = GetTime()
            wipe(GuidCache[guid].legos)
            for slot, link in pairs(ItemCache) do
                if IsLegendary(link) then
                    tinsert(GuidCache[guid].legos, link)
                end
            end

            E("ItemScanComplete", guid, GuidCache[guid])
        end
    end)
end

local function GetTooltipGUID()
    local _, unitID = GameTooltip:GetUnit()
    local guid = unitID and UnitGUID(unitID)
    if UnitIsPlayer(unitID) and CanInspect(unitID) then
        return guid
    end
end

local f = CreateFrame("frame", nil, GameTooltip)
local ShouldInspect = false
local LastInspect = 0
local FailTimeout = 1
f:SetScript("OnUpdate", function(self, elapsed)
    local _, unitID = GameTooltip:GetUnit()
    local guid = unitID and UnitGUID(unitID)
    if not guid or (InspectFrame and InspectFrame:IsVisible()) then
        return
    end
    local timeSince = GetTime() - LastInspect
    if ShouldInspect and (ActiveGUID == guid or (timeSince >= INSPECT_TIMEOUT)) then
        ShouldInspect = false
        if ActiveGUID ~= guid then
            local cache = GuidCache[guid]
            if cache and GetTime() - cache.timestamp <= CACHE_TIMEOUT then
                print("Still cached")
            elseif CanInspect(unitID) then
                NotifyInspect(unitID)
            end
        end
    elseif ShouldInspect and (timeSince < INSPECT_TIMEOUT) then
        if unitID and UnitIsPlayer(unitID) and CanInspect(unitID) and not GuidCache[guid] then
            AddLine(Sekret, ILVL_PENDING, format('%.1fs', INSPECT_TIMEOUT - (GetTime() - LastInspect)), 0.6, 0.6, 0.6,
                0.6, 0.6, 0.6)
        end
    else
        if ActiveGUID then
            if guid == ActiveGUID then
                if timeSince <= FailTimeout then
                    AddLine(Sekret, LOADING_ILVL, format('%d%%', timeSince / FailTimeout * 100), 0.6, 0.6, 0.6, 0.6,
                        0.6, 0.6)
                else
                    AddLine(Sekret, LOADING_ILVL, FAILED or 'Failed', 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
                    ActiveGUID = nil
                end
            else
                ActiveGUID = nil
                if timeSince > FailTimeout and CanInspect(unitID) then
                    NotifyInspect(unitID)
                end
            end
        end
    end
end)

hooksecurefunc("NotifyInspect", function(unitID)
    print("NotifyInspect!", unitID, UnitGUID(unitID), (select(6, GetPlayerInfoByGUID(UnitGUID(unitID)))))
    if not GuidCache[UnitGUID(unitID)] then
        ActiveGUID = UnitGUID(unitID)
    end
    LastInspect = GetTime()
end)

hooksecurefunc("ClearInspectPlayer", function()
    ActiveGUID = nil
end)

local function DoInspect()
    ShouldInspect = true
end

local function DecorateTooltip(guid)
    local cache = GuidCache[guid]
    if not cache then
        print("no cache?")
        return
    end
    if GetTooltipGUID() == guid then
        local ourMaxItemLevel, ourEquippedItemLevel = GetAverageItemLevel()

        local fastItemLevel = (cache.ilevel or 0) > 0 and cache.ilevel or cache.itemLevel or 0
        local r1, g1, b1 = ColorDiff(ourEquippedItemLevel, fastItemLevel)
        AddLine(Sekret, cache.specName and cache.specName or " ",
            format("%s %.1f", ITEM_LEVEL_ABBR or "iLvl", fastItemLevel), r1, g1, b1, r1, g1, b1)

        if CovenantCache[guid] then
            local covenantID = CovenantCache[guid]
            local covenantData = C_Covenants.GetCovenantData(covenantID)
            local covenantColor = CovenantColors[covenantID]
            local covenantIcon = CovenantIcons[covenantID]
            AddLine("|Hcovenant|h",
                format("%s |cff%s%s|r", CreateTextureMarkup(covenantIcon, 64, 64, 16, 16, 0.05, 0.95, 0.05, 0.95),
                    covenantColor, covenantData.name), " ")
        end

        local mythicScore = cache.mythicPlus and cache.mythicPlus.currentSeasonScore and
                                cache.mythicPlus.currentSeasonScore or 0
        if mythicScore > 0 then
            local mythicLabel = mythicScore
            local bestRun = 0
            for _, run in pairs(cache.mythicPlus.runs or {}) do
                if run.finishedSuccess and run.bestRunLevel > bestRun then
                    bestRun = run.bestRunLevel
                end
            end

            if bestRun > 0 then
                mythicLabel = mythicScore .. " " .. "|c00ffff99+" .. bestRun .. "|r"
            end

            local color = C_ChallengeMode.GetDungeonScoreRarityColor(mythicScore) or HIGHLIGHT_FONT_COLOR
            AddLine("|HmythicPlus|h", DUNGEON_SCORE, mythicLabel, 1, 1, 0.6, color:GetRGB())
        else
        end
    else
        print("tooltip GUID does not match expected guid")
    end
end

local function ScanUnit(unitID)
    print("SCANNING UNIT", unitID)
    ScannedGUID = UnitGUID(unitID)
    wipe(SlotCache)
    wipe(ItemCache)
    wipe(GuidCache[ScannedGUID].legos)
    local numEquipped = 0
    for i, slot in pairs(InventorySlots) do
        if GetInventoryItemTexture(unitID, slot) then
            SlotCache[slot] = false
            print("GetInventoryItemTexture", slot, GetInventoryItemTexture(unitID, slot))
            numEquipped = numEquipped + 1
        end
    end

    if numEquipped > 0 then
        for slot in pairs(SlotCache) do
        end
    else
        local guid = ScannedGUID
        if not GuidCache[guid] then
            GuidCache[guid] = {}
        end
        GuidCache[guid].ilevel = 0
        GuidCache[guid].weaponLevel = 0
        GuidCache[guid].timestamp = GetTime()
        E("ItemScanComplete", guid, GuidCache[guid])
    end
end

function E:INSPECT_READY(guid)
    print("INSPECT_READY")
    ActiveGUID = nil
    local unitID, name = GetUnitIDFromGUID(guid)
    if unitID then
        print("INSPECT_READY", unitID, name)
        local classDisplayName, class = UnitClass(unitID)
        local colors = class and RAID_CLASS_COLORS[class]
        local specID = GetInspectSpecialization(unitID)
        local specName, role, _
        if not specName and specID and specID ~= 0 then
            specID, specName, _, _, role = GetSpecializationInfoByID(specID, UnitSex(unitID))
            if not specName or specName == "" then
                specName = classDisplayName
            end
            if colors then
                specName = "|c" .. colors.colorStr .. specName .. "|r"
            end
            if role then
                local roleTexture
                if role == "TANK" then
                    roleTexture = CreateAtlasMarkup("roleicon-tiny-tank")
                elseif role == "DAMAGER" then
                    roleTexture = CreateAtlasMarkup("roleicon-tiny-dps")
                elseif role == "HEALER" then
                    roleTexture = CreateAtlasMarkup("roleicon-tiny-healer")
                end
                if roleTexture then
                    specName = format("%s %s", roleTexture, specName)
                end
            end
        end

        if not GuidCache[guid] then
            GuidCache[guid] = {
                ilevel = 0,
                weaponLevel = 0,
                timestamp = 0,
                legos = {},
                mythicPlus = {}
            }
        end
        local cache = GuidCache[guid]
        cache.specID = specID
        cache.class = class
        cache.classDisplayName = classDisplayName
        cache.specName = specName
        cache.itemLevel = C_PaperDollInfo.GetInspectItemLevel(unitID)
        cache.mythicPlus = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unitID) or {}

        ScanUnit(unitID)
    end
end

function E:ItemScanComplete(guid, cache)
    print("ItemScanComplete", guid, cache)
    DecorateTooltip(guid)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self)
    print("OnTooltipSetUnit")
    local _, unitID = self:GetUnit()
    local guid = unitID and UnitGUID(unitID)
    if guid and UnitIsPlayer(unitID) then
        print("OnTooltipSetUnit", guid, UnitName(unitID))
        local cache = GuidCache[guid]
        if cache then
            DecorateTooltip(guid)
        end
        if CanInspect(unitID) then
            DoInspect()
        end
    end
end)

local function COMBAT_LOG_EVENT_UNFILTERED(timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
    destGUID, destName, destFlags, destRaidFlags, spellID, spellName, ...)
    local covenantID = CovenantSpells[spellID]
    if covenantID then
        CovenantCache[sourceGUID] = covenantID
    end
end

function E:COMBAT_LOG_EVENT_UNFILTERED()
    COMBAT_LOG_EVENT_UNFILTERED(CombatLogGetCurrentEventInfo())
end
