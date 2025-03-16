MTGSetting = {}

function MTGSetting:bind(DB)
    MTGSetting["db"] = DB
end

function MTGSetting:check(itemIDs)
    if MTGSetting["db"]["reward"] ~= nil then
        return
    end

    MTGSetting:resetDefault(itemIDs)
end

function MTGSetting:resetDefault(itemIDs)
    for _, v in pairs(itemIDs) do
        if MTGSetting:getReward(v) == nil then
            MTGSetting:setReward(v, true)
        end
    end

    if MTGSetting:getMarkersize() == nil then
        MTGSetting:setMarkersize(26)
    end
    if MTGSetting:getMarkersize() == nil then
        MTGSetting:setMarkersize(26)
    end
    if MTGSetting:getBuyRareItemOption() == nil then
        MTGSetting:setBuyRareItemOption(2)
    end
    if MTGSetting:getBuyNormalItemOption() == nil then
        MTGSetting:setBuyNormalItemOption(1)
    end
end

function MTGSetting:initReward()
    if MTGSetting["db"]["reward"] == nil then
        MTGSetting["db"]["reward"] = {}
    end
end

function MTGSetting:setReward(itemID, val)
    print(itemID, val)
    MTGSetting:initReward()
    -- 168053 
    -- 170161
    if itemID == 168053 then
        MTGSetting["db"]["reward"][170161] = val
    end
    -- 168093
    -- 170159
    if itemID == 168093 then
        MTGSetting["db"]["reward"][170159] = val
    end
    -- 168096
    -- 170162
    if itemID == 168096 then
        MTGSetting["db"]["reward"][170162] = val
    end
    -- 168097
    -- 170101
    if itemID == 168097 then
        MTGSetting["db"]["reward"][170101] = val
    end

    MTGSetting["db"]["reward"][itemID] = val
end

--- @return boolean checked
function MTGSetting:getReward(itemID)
    MTGSetting:initReward()
    return MTGSetting["db"]["reward"][itemID]
end

function MTGSetting:setBuyNormalItemOption(val)
    MTGSetting["db"]["buy_normal"] = val
end

---@return integer option
function MTGSetting:getBuyNormalItemOption()
    return MTGSetting["db"]["buy_normal"] or 1
end

function MTGSetting:setBuyRareItemOption(val)
    MTGSetting["db"]["buy_rare"] = val
end

---@return integer option
function MTGSetting:getBuyRareItemOption()
    return MTGSetting["db"]["buy_rare"] or 2
end

function MTGSetting:setCheckTacoFirst(val)
    MTGSetting["db"]["check_taco_first"] = val
end

---@return boolean check
function MTGSetting:getCheckTacoFirst()
    return MTGSetting["db"]["check_taco_first"]
end

function MTGSetting:setMarkersize(size)
    MTGSetting["db"]["marker_size"] = size
end

---@return integer markersize
function MTGSetting:getMarkersize()
    return MTGSetting["db"]["marker_size"] or 26
end