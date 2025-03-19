MTGSetting = {}

function MTGSetting:checkReward(itemIDs)
    if MTG_RewardSetting == nil then
        MTG_RewardSetting = {}
    end

    for _, v in pairs(itemIDs) do
        if MTGSetting:getReward(v) == nil then
            MTGSetting:setReward(v, true)
        end
    end
end

function MTGSetting:setReward(itemID, val)
    -- 168053
    -- 170161
    if itemID == 168053 then
        MTG_RewardSetting[170161] = val
    end
    -- 168093
    -- 170159
    if itemID == 168093 then
        MTG_RewardSetting[170159] = val
    end
    -- 168096
    -- 170162
    if itemID == 168096 then
        MTG_RewardSetting[170162] = val
    end
    -- 168097
    -- 170101
    if itemID == 168097 then
        MTG_RewardSetting[170101] = val
    end

    MTG_RewardSetting[itemID] = val
end

--- @return boolean checked
function MTGSetting:getReward(itemID)
    return MTG_RewardSetting[itemID]
end

function MTGSetting:setBuyNormalItemOption(val)
    MTG_BuyNormalItemOption = val
end

---@return integer option
function MTGSetting:getBuyNormalItemOption()
    return MTG_BuyNormalItemOption or 1
end

function MTGSetting:setBuyRareItemOption(val)
    MTG_BuyRareItemOption = val
end

---@return integer option
function MTGSetting:getBuyRareItemOption()
    return MTG_BuyRareItemOption or 2
end

function MTGSetting:setCheckTacoFirst(val)
    MTG_CheckTacoFirst = val
end

---@return boolean check
function MTGSetting:getCheckTacoFirst()
    return MTG_CheckTacoFirst or false
end

function MTGSetting:setMarkersize(size)
    MTG_MarkerSize = size
end

---@return integer markersize
function MTGSetting:getMarkersize()
    return MTG_MarkerSize or 26
end
