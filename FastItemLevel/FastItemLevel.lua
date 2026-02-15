local f = CreateFrame("Frame")

local pendingInspects = {}
local cachedItemLevels = {}
local cachedMythicScores = {}
local cachedSpecs = {}
local cachedKeystones = {}

-- WoW kann in "secure" Tooltips/Events sogenannte "secret" string values liefern.
-- Auf diesen dürfen Addons keine String-Methoden (z.B. :match) anwenden und sie
-- teils auch nicht direkt vergleichen. Lösung: immer in einen normalen String
-- umwandeln, bevor damit gearbeitet wird.
local function SafeToString(v)
    if v == nil then return nil end
    return tostring(v)
end

FIL_Config = FIL_Config or {
    showKeystones = true,
    showMythicScore = true, -- Option für Mythic+-Score
    showSpec = true,        -- Option für Spezialisierung
    colorItemLevel = true   -- Option für farbiges Item-Level
}

-- Lokalisierungstabelle
local L = {
    ["deDE"] = {
        ["config_title"] = "FastItemLevel Konfiguration",
        ["show_keystones"] = "Beste M+ Schlüsselsteine anzeigen",
        ["show_mythic_score"] = "M+ Wertung anzeigen",
        ["show_spec"] = "Spezialisierung anzeigen",
        ["color_item_level"] = "Itemlevel-Farben aktivieren",
        ["close_button"] = "Schließen",
        ["reading_info"] = "Lese Informationen aus",
        ["item_level"] = "Itemlevel",
        ["mythic_rating"] = "M+ Wertung",
        ["spec"] = "Spezialisierung",
        ["mythic_info"] = "Mythic+ Info",
        ["total_mplus_score"] = "Gesamt M+ Wertung"
    },
    ["enUS"] = {
        ["config_title"] = "FastItemLevel Configuration",
        ["show_keystones"] = "Show Best M+ Keystones",
        ["show_mythic_score"] = "Show M+ Score",
        ["show_spec"] = "Show Specialization",
        ["color_item_level"] = "Enable Item Level Colors",
        ["close_button"] = "Close",
        ["reading_info"] = "Retrieving information",
        ["item_level"] = "Item Level",
        ["mythic_rating"] = "M+ Rating",
        ["spec"] = "Specialization",
        ["mythic_info"] = "Mythic+ Info",
        ["total_mplus_score"] = "Total M+ Score"
    },
    ["frFR"] = {
        ["config_title"] = "Configuration de FastItemLevel",
        ["show_keystones"] = "Afficher les meilleures pierres angulaires M+",
        ["show_mythic_score"] = "Afficher la note M+",
        ["show_spec"] = "Afficher la spécialisation",
        ["color_item_level"] = "Activer les couleurs de niveau d'objet",
        ["close_button"] = "Fermer",
        ["reading_info"] = "Récupération des informations",
        ["item_level"] = "Niveau d'objet",
        ["mythic_rating"] = "Note M+",
        ["spec"] = "Spécialisation",
        ["mythic_info"] = "Info Mythic+",
        ["total_mplus_score"] = "Score total M+"
    },
    ["esES"] = {
        ["config_title"] = "Configuración de FastItemLevel",
        ["show_keystones"] = "Mostrar las mejores piedras angulares M+",
        ["show_mythic_score"] = "Mostrar puntuación M+",
        ["show_spec"] = "Mostrar especialización",
        ["color_item_level"] = "Habilitar colores del nivel de objeto",
        ["close_button"] = "Cerrar",
        ["reading_info"] = "Recuperando información",
        ["item_level"] = "Nivel de objeto",
        ["mythic_rating"] = "Puntuación M+",
        ["spec"] = "Especialización",
        ["mythic_info"] = "Información de M+",
        ["total_mplus_score"] = "Puntuación total M+"
    },
    ["itIT"] = {
        ["config_title"] = "Configurazione di FastItemLevel",
        ["show_keystones"] = "Mostra le migliori pietre angolari M+",
        ["show_mythic_score"] = "Mostra il punteggio M+",
        ["show_spec"] = "Mostra specializzazione",
        ["color_item_level"] = "Abilita i colori del livello dell'oggetto",
        ["close_button"] = "Chiudi",
        ["reading_info"] = "Recupero delle informazioni",
        ["item_level"] = "Livello dell'oggetto",
        ["mythic_rating"] = "Punteggio M+",
        ["spec"] = "Specializzazione",
        ["mythic_info"] = "Info Mythic+",
        ["total_mplus_score"] = "Punteggio totale M+"
    },
    ["ruRU"] = {
        ["config_title"] = "Конфигурация FastItemLevel",
        ["show_keystones"] = "Показать лучшие ключи M+",
        ["show_mythic_score"] = "Показать M+ рейтинг",
        ["show_spec"] = "Показать специализацию",
        ["color_item_level"] = "Включить цвета уровня предмета",
        ["close_button"] = "Закрыть",
        ["reading_info"] = "Получение информации",
        ["item_level"] = "Уровень предмета",
        ["mythic_rating"] = "M+ рейтинг",
        ["spec"] = "Специализация",
        ["mythic_info"] = "Информация о M+",
        ["total_mplus_score"] = "Общий рейтинг M+"
    },
    ["zhCN"] = {
        ["config_title"] = "FastItemLevel 配置",
        ["show_keystones"] = "显示最佳 M+ 钥石",
        ["show_mythic_score"] = "显示 M+ 评分",
        ["show_spec"] = "显示专精",
        ["color_item_level"] = "启用物品等级颜色",
        ["close_button"] = "关闭",
        ["reading_info"] = "正在获取信息",
        ["item_level"] = "物品等级",
        ["mythic_rating"] = "M+ 评分",
        ["spec"] = "专精",
        ["mythic_info"] = "M+ 信息",
        ["total_mplus_score"] = "总 M+ 评分"
    }
}

-- Ermitteln der aktuellen Sprache
local locale = GetLocale()
local lang = L[locale] or L["enUS"]

local function SaveConfig()
    FastItemLevelDB = FIL_Config
end

local function LoadConfig()
    if FastItemLevelDB then
        for k, v in pairs(FastItemLevelDB) do
            FIL_Config[k] = v
        end
    end
end

local function CreateConfigMenu()
    local frame = CreateFrame("Frame", "FILConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(300, 200)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText(lang["config_title"])

    local showKeystonesCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    showKeystonesCheckbox:SetPoint("TOPLEFT", 20, -40)
    showKeystonesCheckbox.text = showKeystonesCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showKeystonesCheckbox.text:SetPoint("LEFT", showKeystonesCheckbox, "RIGHT", 5, 0)
    showKeystonesCheckbox.text:SetText(lang["show_keystones"])
    showKeystonesCheckbox:SetScript("OnClick", function(self)
        FIL_Config.showKeystones = self:GetChecked()
        SaveConfig()
    end)

    local showMythicScoreCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    showMythicScoreCheckbox:SetPoint("TOPLEFT", 20, -70)
    showMythicScoreCheckbox.text = showMythicScoreCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showMythicScoreCheckbox.text:SetPoint("LEFT", showMythicScoreCheckbox, "RIGHT", 5, 0)
    showMythicScoreCheckbox.text:SetText(lang["show_mythic_score"])
    showMythicScoreCheckbox:SetScript("OnClick", function(self)
        FIL_Config.showMythicScore = self:GetChecked()
        SaveConfig()
    end)

    local showSpecCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    showSpecCheckbox:SetPoint("TOPLEFT", 20, -100)
    showSpecCheckbox.text = showSpecCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showSpecCheckbox.text:SetPoint("LEFT", showSpecCheckbox, "RIGHT", 5, 0)
    showSpecCheckbox.text:SetText(lang["show_spec"])
    showSpecCheckbox:SetScript("OnClick", function(self)
        FIL_Config.showSpec = self:GetChecked()
        SaveConfig()
    end)

    local colorItemLevelCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    colorItemLevelCheckbox:SetPoint("TOPLEFT", 20, -130)
    colorItemLevelCheckbox.text = colorItemLevelCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorItemLevelCheckbox.text:SetPoint("LEFT", colorItemLevelCheckbox, "RIGHT", 5, 0)
    colorItemLevelCheckbox.text:SetText(lang["color_item_level"])
    colorItemLevelCheckbox:SetScript("OnClick", function(self)
        FIL_Config.colorItemLevel = self:GetChecked()
        SaveConfig()
    end)

    frame:SetScript("OnShow", function()
        showKeystonesCheckbox:SetChecked(FIL_Config.showKeystones)
        showMythicScoreCheckbox:SetChecked(FIL_Config.showMythicScore)
        showSpecCheckbox:SetChecked(FIL_Config.showSpec)
        colorItemLevelCheckbox:SetChecked(FIL_Config.colorItemLevel)
    end)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 22)
    closeButton:SetPoint("BOTTOM", 0, 10)
    closeButton:SetText(lang["close_button"])
    closeButton:SetScript("OnClick", function() frame:Hide() end)

    return frame
end

local configFrame = CreateConfigMenu()

SLASH_FIL1 = "/fil"
SlashCmdList["FIL"] = function(msg)
    if msg == "config" then
        configFrame:Show()
    end
end

local function CalculateAverageItemLevel(unit)
    -- 1) Player: nimm den Blizzard-Wert (equipped)
    if UnitIsUnit(unit, "player") then
        local overall, equipped = GetAverageItemLevel()
        if equipped and equipped > 0 then
            return equipped
        end
    end

    -- 2) Andere: nach INSPECT_READY am besten Blizzard Inspect-API nutzen
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel and CanInspect(unit) then
        local ilvl = C_PaperDollInfo.GetInspectItemLevel(unit)
        if ilvl and ilvl > 0 then
            return ilvl
        end
    end

    -- 3) Fallback: manuelle Berechnung
    local total, count = 0, 0
    for i = 1, 17 do
        if i ~= 4 then -- Shirt-Slot ignorieren
            local itemLink = GetInventoryItemLink(unit, i)
            if itemLink then
                local itemLevel = GetEffectiveItemLevel(itemLink)
                if itemLevel and itemLevel > 0 then
                    total = total + itemLevel
                    count = count + 1
                end
            end
        end
    end

    if count > 0 then
        return total / count
    end

    return nil
end

-- Itemlevel-Farben (Passe an, falls Blizzard verschiebt)
local ILVL_ORANGE = 180
local ILVL_PURPLE = 170
local ILVL_BLUE   = 160

local function GetItemLevelColor(itemLevel)
    if not itemLevel then return 1, 1, 1 end

    if itemLevel >= ILVL_ORANGE then
        return 1, 0.5, 0
    elseif itemLevel >= ILVL_PURPLE then
        return 0.8, 0.3, 0.8
    elseif itemLevel >= ILVL_BLUE then
        return 0, 0.5, 1
    else
        return 0, 1, 0
    end
end

local function GetKeystoneInfo(unit)
    local keystones = {}
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        if summary then
            local overallScore = summary.currentSeasonScore or 0
            table.insert(keystones, {
                name = lang["total_mplus_score"],
                level = overallScore,
                time = ""
            })

            if UnitIsUnit(unit, "player") and C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap then
                local mapIDs = C_ChallengeMode.GetMapTable()
                for _, mapID in ipairs(mapIDs) do
                    local mapInfo = C_ChallengeMode.GetMapUIInfo(mapID)
                    local affixScores = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
                    if affixScores and #affixScores > 0 then
                        local bestRun = affixScores[1]
                        local level = bestRun.level or 0
                        local durationSec = bestRun.durationSec or 0
                        local minutes = math.floor(durationSec / 60)
                        local seconds = durationSec % 60
                        table.insert(keystones, {
                            name = mapInfo,
                            level = level,
                            time = string.format("%d:%02d", minutes, seconds)
                        })
                    end
                end
            elseif summary.runs then
                for _, run in ipairs(summary.runs) do
                    local mapInfo = C_ChallengeMode.GetMapUIInfo(run.challengeModeID)
                    if mapInfo then
                        table.insert(keystones, {
                            name = mapInfo,
                            level = run.bestRunLevel,
                            time = ""
                        })
                    end
                end
            end
        end
    end
    return keystones
end

-- ✅ FIX: Player nicht durch CanInspect blocken + sauberes Inspect-Handling
local function GetItemLevelAndInfo(unit, callback)
    local guid = SafeToString(UnitGUID(unit))
    if not guid then
        callback(nil, nil, nil, nil)
        return
    end

    local keystones = GetKeystoneInfo(unit)

    -- ✅ Player: kein Inspect nötig
    if UnitIsUnit(unit, "player") then
        local avgItemLevel = CalculateAverageItemLevel(unit)

        local mythicScore = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        mythicScore = mythicScore and mythicScore.currentSeasonScore or nil

        local spec = nil
        if GetSpecialization and GetSpecializationInfo then
            local specIndex = GetSpecialization()
            if specIndex then
                local _, specName = GetSpecializationInfo(specIndex)
                spec = specName
            end
        end

        callback(avgItemLevel, mythicScore, spec, keystones)
        return
    end

    if cachedItemLevels[guid] and cachedMythicScores[guid] and cachedSpecs[guid] then
        callback(cachedItemLevels[guid], cachedMythicScores[guid], cachedSpecs[guid], keystones)
        return
    end

    if not CanInspect(unit) then
        callback(nil, nil, nil, nil)
        return
    end

    pendingInspects[guid] = callback

    -- NotifyInspect kann in manchen Situationen nil/blocked sein -> sicher aufrufen
    if NotifyInspect then
        NotifyInspect(unit)
    end

    callback("reading", "reading", "reading", keystones)
end

local function AddInfoToTooltip(tooltip, unit)
    GetItemLevelAndInfo(unit, function(avgItemLevel, mythicScore, spec, keystones)
        if not tooltip or not tooltip.AddLine then return end

		-- Entferne alte Zeilen, falls vorhanden
		for i = tooltip:NumLines(), 1, -1 do
			local line = _G[tooltip:GetName().."TextLeft"..i]
			local text = line and line.GetText and SafeToString(line:GetText())
			if text and (
				string.match(text, "^"..lang["item_level"]..":") or
				string.match(text, "^"..lang["mythic_rating"]..":") or
				string.match(text, "^"..lang["spec"]..":") or
				string.match(text, "^"..lang["mythic_info"]..":") or
				text == lang["reading_info"]
			) then
				line:SetText(nil)
			end
		end

        if avgItemLevel == "reading" then
            tooltip:AddLine(lang["reading_info"], 1, 1, 1)
        else
            if avgItemLevel then
                if FIL_Config.colorItemLevel then
                    local r, g, b = GetItemLevelColor(avgItemLevel)
                    tooltip:AddLine(lang["item_level"] .. ": " .. string.format("%.2f", avgItemLevel), r, g, b)
                else
                    tooltip:AddLine(lang["item_level"] .. ": " .. string.format("%.2f", avgItemLevel), 1, 1, 1)
                end
            end

            if FIL_Config.showSpec and spec then
                tooltip:AddLine(lang["spec"] .. ": " .. spec, 0, 1, 1)
            end

            if keystones and #keystones > 0 and (FIL_Config.showMythicScore or FIL_Config.showKeystones) then
                tooltip:AddLine(lang["mythic_info"] .. ":", 1, 1, 0)

                if FIL_Config.showMythicScore then
                    for _, keystone in ipairs(keystones) do
                        if keystone.name == lang["total_mplus_score"] then
                            tooltip:AddLine(string.format(" %s: %d", keystone.name, keystone.level), 1, .5, .0)
                            break
                        end
                    end
                end

                if FIL_Config.showKeystones then
                    for _, keystone in ipairs(keystones) do
                        if keystone.name ~= lang["total_mplus_score"] then
                            if keystone.time ~= "" then
                                tooltip:AddLine(string.format(" %s: +%d (%s)", keystone.name, keystone.level, keystone.time), .8, .8, .8)
                            else
                                tooltip:AddLine(string.format(" %s: +%d", keystone.name, keystone.level), .8, .8, .8)
                            end
                        end
                    end
                end
            end
        end

        tooltip:Show()
    end)
end

-- ✅ FIX: In Delves/secure Tooltips kann tooltip:GetUnit() ein "secret value" liefern.
-- Deshalb: niemals den zurückgegebenen "unit" vergleichen/UnitExists() darauf ausführen.
-- Stattdessen: über tooltipData.guid auf bekannte UnitTokens mappen.
local function ResolveUnitFromTooltip(tooltip, tooltipData)
	local guid = SafeToString(tooltipData and tooltipData.guid)
    if not guid then return nil end

    local function TryUnit(unitToken)
		if UnitExists(unitToken) and SafeToString(UnitGUID(unitToken)) == guid then
            return unitToken
        end
        return nil
    end

    -- Häufige Tokens zuerst
    local unit = TryUnit("mouseover") or TryUnit("target") or TryUnit("focus") or TryUnit("player")
    if unit then return unit end

    -- Party/Raid
    for i = 1, 4 do
        unit = TryUnit("party"..i)
        if unit then return unit end
    end
    for i = 1, 40 do
        unit = TryUnit("raid"..i)
        if unit then return unit end
    end

    -- Weitere gängige Tokens (Boss/Arena/Nameplates)
    for i = 1, 8 do
        unit = TryUnit("boss"..i)
        if unit then return unit end
    end
    for i = 1, 5 do
        unit = TryUnit("arena"..i)
        if unit then return unit end
    end
    for i = 1, 40 do
        unit = TryUnit("nameplate"..i)
        if unit then return unit end
    end

    return nil
end

local function HookTooltip()
    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.Unit,
        function(tooltip, tooltipData)
            if not tooltipData then return end
            local unit = ResolveUnitFromTooltip(tooltip, tooltipData)
            if unit and UnitIsPlayer(unit) then
                AddInfoToTooltip(tooltip, unit)
            end
        end
    )
end

local function InitializeTooltipHooks()
    HookTooltip()
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        LoadConfig()
        InitializeTooltipHooks()

    elseif event == "INSPECT_READY" then
		local guid = SafeToString(...)
        if pendingInspects[guid] then
            local unit = nil

			for _, unitType in ipairs({ "player", "target", "mouseover", "focus" }) do
				if UnitExists(unitType) and SafeToString(UnitGUID(unitType)) == guid then
                    unit = unitType
                    break
                end
            end

            -- ✅ FIX: party korrekt (1-4), raid korrekt (1-40)
            if not unit then
                for i = 1, 4 do
                    local partyUnit = "party" .. i
					if UnitExists(partyUnit) and SafeToString(UnitGUID(partyUnit)) == guid then
                        unit = partyUnit
                        break
                    end
                end
            end

            if not unit then
                for i = 1, 40 do
                    local raidUnit = "raid" .. i
					if UnitExists(raidUnit) and SafeToString(UnitGUID(raidUnit)) == guid then
                        unit = raidUnit
                        break
                    end
                end
            end

            if unit then
                local avgItemLevel = CalculateAverageItemLevel(unit)

                local mythicScore = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
                mythicScore = mythicScore and mythicScore.currentSeasonScore or nil

                local spec = nil
                if GetInspectSpecialization and GetSpecializationInfoByID then
                    local specID = GetInspectSpecialization(unit)
                    local _, specName = GetSpecializationInfoByID(specID)
                    spec = specName
                end

                local keystones = GetKeystoneInfo(unit)

                cachedItemLevels[guid] = avgItemLevel
                cachedMythicScores[guid] = mythicScore
                cachedSpecs[guid] = spec
                cachedKeystones[guid] = keystones

                pendingInspects[guid](avgItemLevel, mythicScore, spec, keystones)
            end

            pendingInspects[guid] = nil

            -- ✅ FIX: Inspect freigeben
            if ClearInspectPlayer then
                ClearInspectPlayer()
            end
        end
    end
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("INSPECT_READY")

local function ClearCache()
    wipe(cachedItemLevels)
    wipe(cachedMythicScores)
    wipe(cachedSpecs)
    wipe(cachedKeystones)
end

C_Timer.NewTicker(300, ClearCache)
