local addonName = ...

MTG = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
MTG.L = LibStub("AceLocale-3.0"):GetLocale("MTG")
MTG.Version = "1.0.2"
MTG.Setting = MTGSetting

local showReq = true                    -- 显示每个项目的要求。
local showAllButNotOnlyMeetsReq = false -- 显示每个项目，但不是仅显示当前要求。

local sortType = 1                      -- 按以下方式对buyString进行排序：1个NPC优先。2稀有优先
local merchantShowDelay = 0.5           -- 延迟

local valueableList = {}

local fullNPC = {
    [151950] = true,
    [151951] = true,
    [151952] = true,
    [151953] = true,
    [152084] = true
}
local replaceList = {
    [167923] = 167916
}

local NPCRaidTargetIndex = {
    [151950] = 6,
    [151951] = 5,
    [151952] = 1,
    [151953] = 3,
    [152084] = 2
}

local itemIDs = { 168053, 168091, 168092, 168093, 168094, 168095, 168096, 168097, 170152, 170153, 170157, 169202, 170158 }


local NPCNameList = {
    [152084] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2:26|t " .. MTG.L["Mrrl"],
    [151952] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1:26|t " .. MTG.L["Flrgrrl"],
    [151953] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3:26|t " .. MTG.L["Hurlgrl"],
    [151950] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6:26|t " .. MTG.L["Mrrglrlr"],
    [151951] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5:26|t " .. MTG.L["Grrmrlg"]
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        return self[event](self, event, ...)
    end
end)

local debug = {
    forceValueablePurchase = false, -- # open up this to test under item daily locked.
    showCapeTacoTidestallion = false,
    showValueableList = false
}

local isWearingCape = function()
    return (GetInventoryItemID("player", 15) == 169489) and true or false
end

local learnedCrimsonTidestallion = function()
    for k, v in pairs(C_MountJournal.GetMountIDs()) do
        local _, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(v)
        if spellID == 300153 then
            return isCollected
        end
    end
    return false -- # incorrectly not scanned (maybe in some case?) return as unlearned
end

local initializeValueableList = function(itemID, isNeedTaco)
    local isWearingCape = isWearingCape
    local hasTaco = (C_Item.GetItemCount(170100, true) > 0) and true or false

    if debug.showCapeTacoTidestallion then
        print("player is wearing cape - ", isWearingCape)
        print("player has taco - ", hasTaco)
        print("player learned CrimsonTidestallion - ", learnedCrimsonTidestallion())
    end

    local buyNormalItems = (MTG.Setting:getBuyNormalItemOption() == 1) and 1 or 0
    local buyRareItemsNoTaco = (MTG.Setting:getBuyRareItemOption() <= 2) and isWearingCape and 1 or 0
    local buyRareItemsWithTaco = (MTG.Setting:getBuyRareItemOption() == 2) and isWearingCape and
        ((not MTG.Setting:getCheckTacoFirst()) or hasTaco) and 1 or 0

    valueableList = {
        [168053] = buyNormalItems,
        [168091] = buyNormalItems,
        [168092] = buyNormalItems,
        [168093] = buyNormalItems,
        [168094] = buyNormalItems,
        [168095] = buyNormalItems,
        [168096] = buyNormalItems,
        [168097] = buyNormalItems,
        -- ## the following items require Azsh'ari Stormsurger Cape
        -- ## as the wowhead data is not completed yet, some might skip taco check
        [170159] = buyRareItemsNoTaco,
        [170152] = buyRareItemsNoTaco,
        [170153] = buyRareItemsWithTaco,
        [170157] = buyRareItemsNoTaco,
        [170161] = buyRareItemsWithTaco,
        [170162] = buyRareItemsNoTaco, -- # no need taco
        [170101] = buyRareItemsNoTaco,
        [169202] = buyRareItemsWithTaco,
        [170158] = buyRareItemsWithTaco
    }
    if debug.showValueableList or true then
        for k, v in pairs(valueableList) do
            -- print(k, GetItemInfo(k), v)
            C_Item.GetItemInfo(k)
        end
    end

    if valueableList[itemID] == nil then
        return
    end

    if isNeedTaco and valueableList[itemID] == buyRareItemsNoTaco then
        valueableList[itemID] = buyRareItemsWithTaco
        print(itemID, MTG.L["This item wants a Taco cake"])
    elseif not isNeedTaco and valueableList[itemID] == buyRareItemsWithTaco then
        valueableList[itemID] = buyRareItemsNoTaco
        print(itemID, MTG.L["This item doesn't need Taco cake"])
    end
end

local everGenerated = false

-- # Don't touch anything below!

local name, realm = UnitFullName("player")
if not realm or realm == "" then
    if not PLAYER_REALM or PLAYER_REALM == "" then
        PLAYER_REALM = GetRealmName()
    end
    realm = PLAYER_REALM
end
local playerFullName = name .. "-" .. realm

local talkedNPC = {}


local buyList = {}
local buyLists = {}
local GetItemID = function(itemLink)
    if not itemLink then
        return nil
    end
    local itemID = string.match(itemLink, "item:(%d+):")
    return itemID and tonumber(itemID) or nil
end

local getItemLink = function(itemID)
    if not itemID then
        return nil
    end

    name = select(2, C_Item.GetItemInfo(itemID)) -- /run print(select(2,GetItemInfo(167905)))
    return name
end

local function loadMerchantItemList() -- 加载物品列表，解决function_***.lua:***: bad argument #2 to '***' (string expected, got nil)错误
    for _, itemBuyInfo in pairs(MerchantItemList) do
        for _, req in pairs(itemBuyInfo.Req) do
            getItemLink(req.item)
        end
    end
end

local GetNPCID = function(unit)
    if not unit then
        return nil
    end
    local id = UnitGUID(unit)
    id = string.match(id, "-(%d+)-%x+$")
    return tonumber(id, 10)
end

local isSetContain = function(s1, s2)
    for k, v in pairs(s2) do
        if (not s1[k]) then
            return false
        end
    end
    return true
end

local queueBuyMerchantItem = function(itemIndex, amount)
    local amountLeft = amount

    local max = math.min(GetMerchantItemMaxStack(itemIndex), 255)
    while amountLeft > 0 do
        BuyMerchantItem(itemIndex, min(amountLeft, max))
        amountLeft = amountLeft - min(amountLeft, max)
    end
end

GenerateBuyList = function(amount, itemID)
    if not MerchantItemList[itemID] or MTG.Setting.getReward(itemID) == false then
        return
    end

    local currentItemReq, currentItemNPC = MerchantItemList[itemID].Req, MerchantItemList[itemID].NPC
    local currentNeedAmount
    if buyList[itemID] then
        currentNeedAmount = amount + buyList[itemID].amount
    else
        currentNeedAmount = amount - C_Item.GetItemCount(itemID) -- # delete the num on player on first look
    end

    if currentNeedAmount > 0 then
        for k, req in pairs(currentItemReq) do
            if req.item ~= "c" then
                if buyList[itemID] then
                    GenerateBuyList(amount * req.amount, replaceList[req.item] or req.item)
                else
                    GenerateBuyList(currentNeedAmount * req.amount, replaceList[req.item] or req.item)
                end
            end
        end
    end

    buyList[itemID] = {
        amount = currentNeedAmount,
        NPC = currentItemNPC
    }
    buyLists[itemID] = {
        amount = currentNeedAmount,
        NPC = currentItemNPC
    }

    return
end

local meetsReq = function(itemID)
    if not buyList[itemID] then
        return false
    end
    if not MerchantItemList[itemID] then
        return false
    end
    local currentItemReq = MerchantItemList[itemID].Req
    local amount = buyList[itemID].amount
    for k, req in pairs(currentItemReq) do
        if (req.item ~= "c") and (C_Item.GetItemCount(req.item) < amount * req.amount) then
            return false
        end
    end
    return true
end

local generateBuyListFromValueable = function()
    for itemID, itemNum in pairs(valueableList) do
        if itemNum > 0 then
            GenerateBuyList(itemNum, itemID)
        end

        if buyList[itemID] then
            valueableList[itemID] = valueableList[itemID] - buyList[itemID].amount
        end
    end
end

local generatebuyString = function()
    local compare
    if sortType == 1 then
        compare = function(a, b)
            if a.NPC < b.NPC then
                return true
            elseif a.NPC > b.NPC then
                return false
            elseif a.rarity < b.rarity then
                return true
            elseif a.rarity > b.rarity then
                return false
            elseif a.itemID < b.itemID then
                return true
            elseif a.itemID > b.itemID then
                return false
            end
        end
    elseif sortType == 2 then
        compare = function(a, b)
            if a.rarity < b.rarity then
                return true
            elseif a.rarity > b.rarity then
                return false
            elseif a.NPC < b.NPC then
                return true
            elseif a.NPC > b.NPC then
                return false
            elseif a.itemID < b.itemID then
                return true
            elseif a.itemID > b.itemID then
                return false
            end
        end
    end

    local tempStrnSet = {}

    for itemID, itemBuyInfo in pairs(buyList) do
        local ReqStrn = showReq and string.format(" (%s)", GenerateReqString(itemID)) or ""
        local strn
        if meetsReq(itemID) or showAllButNotOnlyMeetsReq then -- 满足要求
            if itemBuyInfo.amount > 1 then
                strn = string.format(" %s %s %sx%d%s", NPCNameList[itemBuyInfo.NPC], MTG.L["buy"], getItemLink(itemID),
                    itemBuyInfo.amount, ReqStrn)
            elseif itemBuyInfo.amount > 0 then
                strn =
                    string.format(" %s %s %s%s", NPCNameList[itemBuyInfo.NPC], MTG.L["buy"], getItemLink(itemID), ReqStrn)
            end

            table.insert(tempStrnSet, {
                itemID = itemID,
                strn = strn,
                NPC = itemBuyInfo.NPC,
                rarity = MerchantItemList[itemID].rarity
            })
        end
    end

    table.sort(tempStrnSet, compare)

    local retStrn = ""
    for k, v in pairs(tempStrnSet) do
        if v.strn then
            retStrn = retStrn .. v.strn .. "\n"
        end
    end

    return retStrn
end

local checkDealReplacementString = function()
    local strn = ""

    for _, itemID in pairs(replaceList) do
        if C_Item.GetItemCount(itemID) >= 1 then
            strn = string.format("%s %s %s", strn, MTG.L["Use it manually in the water"], getItemLink(itemID))
        end
    end

    return strn
end

GenerateReqString = function(itemID)
    if not buyList[itemID] then
        return false
    end
    if not MerchantItemList[itemID] then
        return false
    end
    local Req = MerchantItemList[itemID].Req
    local Amount = buyList[itemID].amount
    local strn = ""
    if Amount > 0 then
        for k, req in pairs(Req) do
            if req.item == "c" then
                strn = C_CurrencyInfo.GetCoinText(Amount * req.amount, "+")
                break
            else
                if strn == "" then
                    strn = (Amount * req.amount > 1) and
                        string.format("%sx%d", getItemLink(req.item), Amount * req.amount) or
                        string.format("%s", getItemLink(req.item))
                else
                    strn = (Amount * req.amount > 1) and
                        string.format("%s+%sx%d", strn, getItemLink(req.item), Amount * req.amount) or
                        string.format("%s+%s", strn, getItemLink(req.item))
                end
            end
        end
    end
    return strn
end

function CheckTableIn(tbl, value)
    for k, v in pairs(tbl) do
        if v.item == value then
            return true
        end
    end
    return false
end

local getRewardText = function(itemID)
    local idRelationTable = {
        [170161] = 168053,
        [170159] = 168093,
        [170162] = 168096,
        [170101] = 168097,
    }

    local realID = itemID
    if idRelationTable[realID] then
        realID = idRelationTable[realID]
    end

    if rawget(MTG.L, realID) == nil then
        return ""
    end
    return MTG.L[realID]
end

function MRRL_DELAYED_MERCHANT_SHOW()
    local NPCID, NPCname = GetNPCID("target"), UnitName("target")
    if NPCRaidTargetIndex[NPCID] and not GetRaidTargetIndex("target") then
        SetRaidTarget("target", NPCRaidTargetIndex[NPCID])
    end

    if NPCID and fullNPC[NPCID] then
        loadMerchantItemList()
        for itemIndex = 1, GetMerchantNumItems() do
            local currentItem = GetMerchantItemLink(itemIndex)

            if currentItem then
                local currentItemID = GetItemID(currentItem)
                local currentItemReq = {}

                if (NPCID == 152084) and (not talkedNPC[NPCID]) then
                    if not valueableList[currentItemID] then
                        valueableList[currentItemID] = 1
                    end
                end

                --# 满足需求检查购买列表。这是自动购买功能，并且只有在生成买单后才会使用。
                if meetsReq(currentItemID) then
                    if buyList[currentItemID].amount > 0 then
                        if getItemLink(currentItemID) == nil then return end
                        queueBuyMerchantItem(itemIndex, buyList[currentItemID].amount)
                    end
                end

                local _, _, price, _, _, isPurchasable = C_MerchantFrame.GetItemInfo(itemIndex)
                if isPurchasable or debug.forceValueablePurchase then
                    if price == 0 then --# 这件物品是用货币买的。
                        for currencyIndex = 1, GetMerchantItemCostInfo(itemIndex) do
                            local _, currentCurrencyNum, currentCurrency = GetMerchantItemCostItem(itemIndex,
                                currencyIndex)

                            currentItemReq[currencyIndex] = {
                                amount = currentCurrencyNum,
                                item = GetItemID(currentCurrency),
                            }
                        end
                    else --# 这件东西是用钱买的
                        currentItemReq[1] = {
                            amount = price,
                            item = "c",
                        }
                    end

                    local _, _, rarity = C_Item.GetItemInfo(currentItemID)
                    MerchantItemList[currentItemID] = {
                        Req = currentItemReq,
                        NPC = NPCID,
                        rarity = rarity,
                    }


                    if (NPCID == 152084) then --更新数据表
                        if CheckTableIn(currentItemReq, 170100) then
                            initializeValueableList(currentItemID, true)
                        else
                            initializeValueableList(currentItemID, false)
                        end
                    end
                end
                if not talkedNPC[NPCID] then
                    print(L["Detected"], NPCname, currentItem, getRewardText(GetItemID(currentItem)))
                end
            else
                print(string.format("|cff999900未扫描物品信息. 重新和 %s 对话!", NPCname))
                return false
            end
        end
        talkedNPC[NPCID] = true
    end

    if isSetContain(talkedNPC, fullNPC) or talkedNPC[152084] then -- or talkedNPC[152084]
        if everGenerated == false then
            generateBuyListFromValueable()                        -- 从Valuable生成购买列表
            everGenerated = true
        end
    end
    if fullNPC[NPCID] then
        C_Timer.After(1, function()
            DBM_Purchase_prompt(string.format("%s%s", generatebuyString(), checkDealReplacementString()), 5.0, false)
        end)
    end
    return true
end

function frame:MERCHANT_SHOW(event, ...)
    C_Timer.After(merchantShowDelay, MRRL_DELAYED_MERCHANT_SHOW)
end

function frame:MERCHANT_CLOSED(event, ...)
    -- if C_AddOns.IsAddOnLoaded("WeakAuras") then
    --     if WeakAuras.loaded["Mrrl's trade game"] then
    --         frame:UnregisterEvent("MERCHANT_SHOW")
    --         frame:UnregisterEvent("MERCHANT_CLOSED")
    --         frame:UnregisterEvent("CHAT_MSG_LOOT")
    --         DBM_Purchase_prompt(
    --             L
    --             ["Detected that you have loaded WeakAuras's Mrrl's trade game, to avoid repeated purchases, the MTG addon has been automatically closed, followed by WeakAuras's Mrrl's trade game purchase"],
    --             5.0, false)
    --     end
    -- end
    return true
end

local buyitems = ""
function frame:CHAT_MSG_LOOT(event, ...)
    local line, _, _, _, unit = ...
    if unit == playerFullName then
        for itemID, _ in pairs(buyList) do
            local item = C_Item.GetItemInfo(itemID)
            if item == nil and itemID ~= 167916 and itemID ~= 170100 and MerchantItemList[itemID] then
                print(DBM_Purchase_prompt(itemID .. "发生了一些错误,/RL后重新购买.", 5.0, false))
            end
            if item ~= nil and string.match(line, item) then
                local lootAmount = string.match(line, item .. "]|h|rx(%d+)") or 1
                buyitems = buyitems .. itemID .. "(" .. lootAmount .. ")" .. unit .. "】【"
                buyList[itemID].amount = buyList[itemID].amount - lootAmount
                if valueableList[itemID] ~= nil then
                    LootAlertSystem:AddAlert(itemID)
                    -- LootAlertSystem:AddAlert(itemLink, quantity, rollType, roll, nil, nil, nil, nil, nil, isUpgraded);--获得物品
                    -- LegendaryItemAlertSystem:AddAlert(select(2,GetItemInfo(itemID))) --获得传说物品
                end
                break
            end
        end
        MTGDB = {
            ["talkedNPC"] = talkedNPC,
            ["NPCNameList"] = NPCNameList,
            ["merchantItemList"] = MerchantItemList,
            ["buyList"] = buyList,
            ["buyLists"] = buyLists,
            ["购买详情"] = buyitems
        }
    end
    return true
end

function DBM_Purchase_prompt(message, duration, clear)
    -- center-screen raid notice is easy
    if (clear) then
        RaidNotice_Clear(RaidBossEmoteFrame)
    end
    RaidNotice_AddMessage(RaidBossEmoteFrame, message, ChatTypeInfo["RAID_BOSS_EMOTE"], duration)
    -- chat messages are trickier
    local i
    for i = 1, NUM_CHAT_WINDOWS do
        local chatframes = { GetChatWindowMessages(i) }
        local v
        for _, v in ipairs(chatframes) do
            if v == "MONSTER_BOSS_EMOTE" then
                local frame = 'ChatFrame' .. i
                if _G[frame] then
                    _G[frame]:AddMessage(message, 1.0, 1.0, 0.0, GetChatTypeIndex(ChatTypeInfo["RAID_BOSS_EMOTE"].id))
                end
                break
            end
        end
    end
end

function frame:GET_ITEM_INFO_RECEIVED(event, ...)
    local itemID, success = ...
    if itemID ~= 0 and not success then
        if MerchantItemList[itemID] then
            print(itemID, "未成功地从服务器查询该项")
            loadMerchantItemList() -- 加载物品列表
            C_Timer.After(3, function()
                frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
            end) -- 3秒后自动关闭未加载物品提示,防止死循环
        end
    end
end

function frame:ADDON_LOADED(event, ...)
    MTG.Setting:checkReward(itemIDs)

    if MTG_CheckTacoFirst == nil then
        MTG_CheckTacoFirst = true
    end

    if MTG_BuyNormalItemOption == nil then
        MTG_BuyNormalItemOption = 1
    end

    if MTG_BuyRareItemOption == nil then
        MTG_BuyRareItemOption = 2
    end

    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    initializeValueableList()
    loadMerchantItemList() -- 加载物品列表
end

local MTG_Options = {
    type = "group",
    name = MTG.L["Mrrl's trade game"],
    order = 1,
    args = {
        -- viewSetting = {
        --     order = 1,
        --     name = MTG.L["View Setting"],
        --     type = "header",
        --     width = "full",
        -- },
        -- markersize = {
        --     order = 2,
        --     name = MTG.L["Marker Size"],
        --     desc = MTG.L["Adjust Marker Size"],
        --     type = "range",
        --     width = "normal",
        --     min = 20,
        --     max = 40,
        --     softMin = 20,
        --     softMax = 40,
        --     step = 1,
        --     bigStep = 1,
        --     isPercent = false,
        --     set = function(info, val)
        --         MTG.Setting:setMarkersize(val);
        --     end,
        --     get = function(info)
        --         return MTG.Setting:getMarkersize();
        --     end,
        -- },
        -- spacer1 = {
        --     order = 2.5,
        --     cmdHidden = true,
        --     name = "",
        --     type = "description",
        --     width = "half",
        -- },
        -- defaultOpacity = {
        --     order = 3,
        --     name = MTG.L["Reset Markersize"],
        --     desc = MTG.L["Reset to default Markersize"],
        --     width = "normal",
        --     type = "execute",
        --     func = function()
        --         MTG.Setting.setMarkersize(26);
        --     end
        -- },
        buyOption = {
            order = 4,
            name = MTG.L["Buy Option"],
            type = "header",
            width = "full",
        },
        buyOptionSelect = {
            order = 5,
            type = "select",
            name = MTG.L["Normal Item"],
            width = "normal",
            desc = MTG.L["Buy Normal Item Option"],
            values = { MTG.L["Buy normal items"], MTG.L["Don't buy normal items"] },
            set = function(info, val)
                MTG.Setting:setBuyNormalItemOption(val);
            end,
            get = function(info)
                return MTG.Setting:getBuyNormalItemOption();
            end,
            style = "dropdown", -- This ensures it uses a dropdown menu for selection
        },
        spacer2 = {
            order = 5.5,
            cmdHidden = true,
            name = "",
            type = "description",
            width = "half",
        },
        buyRareOptionSelect = {
            order = 6,
            type = "select",
            name = MTG.L["Rare Item"],
            width = "normal",
            desc = MTG.L["Buy Rare Item Option"],
            values = { MTG.L["buy cape items that don't need taco"], MTG.L["buy every cape items"], MTG.L["Don't buy cape items"] },
            set = function(info, val)
                MTG.Setting:setBuyRareItemOption(val);
            end,
            get = function(info)
                return MTG.Setting:getBuyRareItemOption();
            end,
            style = "dropdown", -- This ensures it uses a dropdown menu for selection
        },
        checkTacoFirst = {
            order = 7,
            name = MTG.L["Check taco before buying rare items with taco"],
            desc = MTG.L["Check taco before buying rare items with taco"],
            type = "toggle",
            width = "full",
            set = function(info, val)
                MTG.Setting:setCheckTacoFirst(val);
            end,
            get = function(info)
                return MTG.Setting:getCheckTacoFirst();
            end,
        },
        contentOption = {
            order = 8,
            name = MTG.L["Buy Content"],
            type = "header",
            width = "full",
        },
    }
}

local initOrder = 8
for key, itemID in ipairs(itemIDs) do
    local optionKey = 'buyOption' .. itemID
    MTG_Options.args[optionKey] = {
        order = initOrder + key,
        name = "|cFF00FF00" .. MTG.L[itemID],
        desc = MTG.L[itemID],
        type = "toggle",
        width = "full",
        get = function(info)
            return MTG.Setting:getReward(itemID);
        end,
        set = function(info, val)
            MTG.Setting:setReward(itemID, val);
        end,

    }
end


LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, MTG_Options, {});
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonName, nil);

SLASH_MTG1 = "/mtg"
function SlashCmdList.MTG()
    Settings.OpenToCategory(addonName)
end
