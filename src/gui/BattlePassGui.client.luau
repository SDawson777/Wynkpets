--[[
    BattlePassGui.client.luau
    Season 1: Origins — Battle Pass UI.

    Layout:
        • Header — season name, timer countdown, premium unlock button
        • XP bar  — current tier progress fill
        • Tier track (scrollable, horizontal) — 30 cells, free/premium reward per cell
        • Reward tooltip — expands on hover/click showing exact amounts

    Network events:
        RequestBattlePassData  Client → Server  (refresh on open)
        PurchaseBattlePass     Client → Server  (buy premium track)
        BattlePassData         Server → Client  full snapshot
        BattlePassXPGained     Server → Client  { XP, Tier, Added, Source }
        BattlePassTierUp       Server → Client  { NewTier, Source }
]]

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared        = ReplicatedStorage:WaitForChild("Shared")

local Network          = require(Shared:WaitForChild("Network"))
local LaunchConfig     = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Constants ────────────────────────────────────────────────────────────────

local TIER_CELL_W   = 90   -- px per tier cell
local TIER_CELL_H   = 155  -- total height of tier column
local MAX_TIERS     = 30
local FREE_ROW_H    = 65
local PREM_ROW_H    = 65
local TRACK_PAD     = 10

local COL_LOCKED    = Color3.fromRGB(40, 40, 60)
local COL_UNLOCKED  = Color3.fromRGB(50, 80, 55)
local COL_CURRENT   = Color3.fromRGB(60, 130, 80)
local COL_PREMIUM   = Color3.fromRGB(90, 40, 120)
local COL_PREM_OWN  = Color3.fromRGB(110, 55, 160)
local COL_CLAIMED   = Color3.fromRGB(35, 35, 35)
local COL_XP_FILL   = Color3.fromRGB(80, 200, 100)
local COL_XP_BG     = Color3.fromRGB(30, 30, 50)
local COL_FREE_HDR  = Color3.fromRGB(50, 170, 90)
local COL_PREM_HDR  = Color3.fromRGB(140, 70, 200)

local RARITY_COLORS = {
    Coins  = Color3.fromRGB(255, 210, 50),
    Gems   = Color3.fromRGB(100, 200, 255),
    Pet    = Color3.fromRGB(255, 120, 200),
    EvolutionMaterial = Color3.fromRGB(180, 130, 255),
    Badge  = Color3.fromRGB(255, 200, 80),
}

local REWARD_ICONS = {
    Coins  = "🪙",
    Gems   = "💎",
    Pet    = "🐾",
    EvolutionMaterial = "✨",
    Badge  = "🏆",
}

-- ── State ────────────────────────────────────────────────────────────────────

local passData = nil  -- last snapshot from server
local tierCells = {}  -- [tier] = { freeLabel, premLabel, tierNumLabel, ... }

-- ── Screen GUI ───────────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BattlePassGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 820, 0, 480)
mainFrame.Position = UDim2.new(0.5, -410, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 18)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(140, 70, 200)
mfStroke.Thickness = 2.5
mfStroke.Parent = mainFrame

-- ── Header ───────────────────────────────────────────────────────────────────

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = Color3.fromRGB(25, 15, 40)
header.BorderSizePixel = 0
header.Parent = mainFrame

local hStroke = Instance.new("UIStroke")
hStroke.Color = Color3.fromRGB(140, 70, 200)
hStroke.Thickness = 1
hStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
hStroke.Parent = header

local seasonLabel = Instance.new("TextLabel")
seasonLabel.Size = UDim2.new(0.5, 0, 0.6, 0)
seasonLabel.Position = UDim2.new(0, 16, 0, 8)
seasonLabel.BackgroundTransparency = 1
seasonLabel.Text = "⚔️ Season 1: Origins"
seasonLabel.TextColor3 = Color3.fromRGB(220, 170, 255)
seasonLabel.Font = Enum.Font.GothamBlack
seasonLabel.TextSize = 22
seasonLabel.TextXAlignment = Enum.TextXAlignment.Left
seasonLabel.Parent = header

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(0.5, -80, 0, 22)
timerLabel.Position = UDim2.new(0, 16, 0.62, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "⏳ Season ends in --d --h"
timerLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 13
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Parent = header

-- Premium button (right side of header)
local premBtn = Instance.new("TextButton")
premBtn.Size = UDim2.new(0, 180, 0, 44)
premBtn.Position = UDim2.new(1, -200, 0.5, -22)
premBtn.BackgroundColor3 = Color3.fromRGB(130, 60, 190)
premBtn.Text = "⭐ Get Premium — 300 R$"
premBtn.TextColor3 = Color3.new(1, 1, 1)
premBtn.Font = Enum.Font.GothamBlack
premBtn.TextSize = 13
premBtn.BorderSizePixel = 0
premBtn.Parent = header

local pbCorner = Instance.new("UICorner")
pbCorner.CornerRadius = UDim.new(0, 10)
pbCorner.Parent = premBtn

local pbStroke = Instance.new("UIStroke")
pbStroke.Color = Color3.fromRGB(200, 130, 255)
pbStroke.Thickness = 1.5
pbStroke.Parent = premBtn

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -44, 0, 20)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 80)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 8)
cbCorner.Parent = closeBtn

-- ── XP Bar ───────────────────────────────────────────────────────────────────

local xpSection = Instance.new("Frame")
xpSection.Size = UDim2.new(1, -32, 0, 44)
xpSection.Position = UDim2.new(0, 16, 0, 80)
xpSection.BackgroundTransparency = 1
xpSection.Parent = mainFrame

local xpBg = Instance.new("Frame")
xpBg.Size = UDim2.new(1, 0, 0, 22)
xpBg.Position = UDim2.new(0, 0, 0, 18)
xpBg.BackgroundColor3 = COL_XP_BG
xpBg.BorderSizePixel = 0
xpBg.Parent = xpSection

local xpBgCorner = Instance.new("UICorner")
xpBgCorner.CornerRadius = UDim.new(0, 11)
xpBgCorner.Parent = xpBg

local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = COL_XP_FILL
xpFill.BorderSizePixel = 0
xpFill.Parent = xpBg

local xpFillCorner = Instance.new("UICorner")
xpFillCorner.CornerRadius = UDim.new(0, 11)
xpFillCorner.Parent = xpFill

local xpLabel = Instance.new("TextLabel")
xpLabel.Size = UDim2.new(1, 0, 1, 0)
xpLabel.BackgroundTransparency = 1
xpLabel.Text = "0 / 1000 XP — Tier 0"
xpLabel.TextColor3 = Color3.new(1, 1, 1)
xpLabel.Font = Enum.Font.GothamBold
xpLabel.TextSize = 12
xpLabel.ZIndex = 2
xpLabel.Parent = xpBg

local xpTierLabel = Instance.new("TextLabel")
xpTierLabel.Size = UDim2.new(1, 0, 0, 18)
xpTierLabel.BackgroundTransparency = 1
xpTierLabel.Text = "Tier 0 of 30"
xpTierLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
xpTierLabel.Font = Enum.Font.Gotham
xpTierLabel.TextSize = 12
xpTierLabel.TextXAlignment = Enum.TextXAlignment.Right
xpTierLabel.Parent = xpSection

-- ── Row Labels (Free / Premium) ───────────────────────────────────────────────

local rowLabelFrame = Instance.new("Frame")
rowLabelFrame.Size = UDim2.new(0, 70, 0, TIER_CELL_H)
rowLabelFrame.Position = UDim2.new(0, 0, 0, 128)
rowLabelFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
rowLabelFrame.BorderSizePixel = 0
rowLabelFrame.Parent = mainFrame

local freeRowLabel = Instance.new("TextLabel")
freeRowLabel.Size = UDim2.new(1, 0, 0, FREE_ROW_H)
freeRowLabel.Position = UDim2.new(0, 0, 0, TRACK_PAD + 25)
freeRowLabel.BackgroundColor3 = COL_FREE_HDR
freeRowLabel.Text = "FREE"
freeRowLabel.TextColor3 = Color3.new(1, 1, 1)
freeRowLabel.Font = Enum.Font.GothamBlack
freeRowLabel.TextSize = 14
freeRowLabel.BorderSizePixel = 0
freeRowLabel.Parent = rowLabelFrame

local flCorner = Instance.new("UICorner")
flCorner.CornerRadius = UDim.new(0, 8)
flCorner.Parent = freeRowLabel

local premRowLabel = Instance.new("TextLabel")
premRowLabel.Size = UDim2.new(1, 0, 0, PREM_ROW_H)
premRowLabel.Position = UDim2.new(0, 0, 0, TRACK_PAD + FREE_ROW_H + 30)
premRowLabel.BackgroundColor3 = COL_PREM_HDR
premRowLabel.Text = "PREM"
premRowLabel.TextColor3 = Color3.new(1, 1, 1)
premRowLabel.Font = Enum.Font.GothamBlack
premRowLabel.TextSize = 14
premRowLabel.BorderSizePixel = 0
premRowLabel.Parent = rowLabelFrame

local plCorner = Instance.new("UICorner")
plCorner.CornerRadius = UDim.new(0, 8)
plCorner.Parent = premRowLabel

-- ── Tier Track (Scrollable) ───────────────────────────────────────────────────

local trackScroll = Instance.new("ScrollingFrame")
trackScroll.Size = UDim2.new(1, -76, 0, TIER_CELL_H + 20)
trackScroll.Position = UDim2.new(0, 74, 0, 128)
trackScroll.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
trackScroll.BorderSizePixel = 0
trackScroll.ScrollBarThickness = 6
trackScroll.ScrollBarImageColor3 = Color3.fromRGB(140, 70, 200)
trackScroll.ScrollingDirection = Enum.ScrollingDirection.X
trackScroll.CanvasSize = UDim2.new(0, MAX_TIERS * TIER_CELL_W + 20, 0, 0)
trackScroll.Parent = mainFrame

-- Connector line between free/premium (drawn as a thin frame behind cells)
local connectorLine = Instance.new("Frame")
connectorLine.Size = UDim2.new(0, MAX_TIERS * TIER_CELL_W, 0, 4)
connectorLine.Position = UDim2.new(0, 10, 0, TRACK_PAD + FREE_ROW_H + 13)
connectorLine.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
connectorLine.BorderSizePixel = 0
connectorLine.ZIndex = 0
connectorLine.Parent = trackScroll

local function makeRewardText(reward)
    if not reward then return "—" end
    local icon = REWARD_ICONS[reward.Type] or "?"
    if reward.Type == "Pet" then
        return icon .. " " .. (reward.Label or reward.PetId or "Pet")
    elseif reward.Type == "EvolutionMaterial" then
        return icon .. " +" .. (reward.Amount or 1) .. " Shard"
    else
        return icon .. " " .. (reward.Amount or "?")
    end
end

local function makeRewardColor(reward)
    if not reward then return Color3.fromRGB(80, 80, 80) end
    return RARITY_COLORS[reward.Type] or Color3.fromRGB(180, 180, 180)
end

-- Build the 30 tier cells (populated once on first BattlePassData receipt)
local tierConfig = {} -- filled from snapshot
local cellsBuilt = false

local function buildCells(snapshot)
    if cellsBuilt then return end
    cellsBuilt = true

    for t = 1, MAX_TIERS do
        local x = (t - 1) * TIER_CELL_W + 10

        -- Tier number header
        local numLabel = Instance.new("TextLabel")
        numLabel.Size = UDim2.new(0, TIER_CELL_W - 4, 0, 22)
        numLabel.Position = UDim2.new(0, x + 2, 0, TRACK_PAD)
        numLabel.BackgroundTransparency = 1
        numLabel.Text = "T" .. t
        numLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        numLabel.Font = Enum.Font.GothamBold
        numLabel.TextSize = 11
        numLabel.TextXAlignment = Enum.TextXAlignment.Center
        numLabel.Parent = trackScroll

        -- Free reward cell
        local freeCell = Instance.new("Frame")
        freeCell.Name = "Free_" .. t
        freeCell.Size = UDim2.new(0, TIER_CELL_W - 6, 0, FREE_ROW_H)
        freeCell.Position = UDim2.new(0, x + 3, 0, TRACK_PAD + 24)
        freeCell.BackgroundColor3 = COL_LOCKED
        freeCell.BorderSizePixel = 0
        freeCell.Parent = trackScroll

        local fcCorner = Instance.new("UICorner")
        fcCorner.CornerRadius = UDim.new(0, 8)
        fcCorner.Parent = freeCell

        local freeLabel = Instance.new("TextLabel")
        freeLabel.Size = UDim2.new(1, -4, 1, 0)
        freeLabel.Position = UDim2.new(0, 2, 0, 0)
        freeLabel.BackgroundTransparency = 1
        freeLabel.Text = "—"
        freeLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
        freeLabel.Font = Enum.Font.GothamBold
        freeLabel.TextSize = 11
        freeLabel.TextWrapped = true
        freeLabel.TextXAlignment = Enum.TextXAlignment.Center
        freeLabel.Parent = freeCell

        -- Premium reward cell
        local premCell = Instance.new("Frame")
        premCell.Name = "Prem_" .. t
        premCell.Size = UDim2.new(0, TIER_CELL_W - 6, 0, PREM_ROW_H)
        premCell.Position = UDim2.new(0, x + 3, 0, TRACK_PAD + FREE_ROW_H + 30)
        premCell.BackgroundColor3 = COL_PREMIUM
        premCell.BorderSizePixel = 0
        premCell.Parent = trackScroll

        local pcCorner = Instance.new("UICorner")
        pcCorner.CornerRadius = UDim.new(0, 8)
        pcCorner.Parent = premCell

        local premLabel = Instance.new("TextLabel")
        premLabel.Size = UDim2.new(1, -4, 1, 0)
        premLabel.Position = UDim2.new(0, 2, 0, 0)
        premLabel.BackgroundTransparency = 1
        premLabel.Text = "🔒"
        premLabel.TextColor3 = Color3.fromRGB(160, 100, 200)
        premLabel.Font = Enum.Font.GothamBold
        premLabel.TextSize = 11
        premLabel.TextWrapped = true
        premLabel.TextXAlignment = Enum.TextXAlignment.Center
        premLabel.Parent = premCell

        tierCells[t] = {
            Num     = numLabel,
            FreeCell = freeCell,
            FreeLbl  = freeLabel,
            PremCell = premCell,
            PremLbl  = premLabel,
        }

        -- Populate from snapshot's tier config if available
        if snapshot.TierDefs and snapshot.TierDefs[t] then
            local def = snapshot.TierDefs[t]
            freeLabel.Text = makeRewardText(def.FreeReward)
            freeLabel.TextColor3 = makeRewardColor(def.FreeReward)
            premLabel.Text = makeRewardText(def.PremiumReward)
            premLabel.TextColor3 = makeRewardColor(def.PremiumReward)
        end
    end
end

-- Update cell visual states from current passData
local function refreshCells()
    if not passData then return end
    local currentTier = passData.Tier or 0
    local premium     = passData.Premium or false
    local claimedF    = passData.TiersClaimedFree or {}
    local claimedP    = passData.TiersClaimedPrem or {}

    -- Update XP bar
    local xp     = passData.XP or 0
    local xpPer  = passData.XPPerTier or 1000
    local pct    = math.clamp(xp / xpPer, 0, 1)
    TweenService:Create(xpFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
        { Size = UDim2.new(pct, 0, 1, 0) }):Play()

    local displayTier = math.min(currentTier + 1, passData.MaxTier or MAX_TIERS)
    xpLabel.Text = string.format("%d / %d XP", xp, xpPer)
    xpTierLabel.Text = string.format("Tier %d of %d", currentTier, passData.MaxTier or MAX_TIERS)

    -- Update premium button
    if premium then
        premBtn.Text = "✅ Premium Unlocked"
        premBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 60)
        premBtn.Active = false
    else
        premBtn.Text = "⭐ Get Premium — 300 R$"
        premBtn.BackgroundColor3 = Color3.fromRGB(130, 60, 190)
        premBtn.Active = true
    end

    for t, cell in pairs(tierCells) do
        local reached  = t <= currentTier
        local isCurrent = t == currentTier + 1

        -- Free cell color
        if claimedF[t] then
            cell.FreeCell.BackgroundColor3 = COL_CLAIMED
            cell.FreeLbl.TextColor3 = Color3.fromRGB(80, 120, 80)
        elseif reached then
            cell.FreeCell.BackgroundColor3 = COL_UNLOCKED
        elseif isCurrent then
            cell.FreeCell.BackgroundColor3 = COL_CURRENT
        else
            cell.FreeCell.BackgroundColor3 = COL_LOCKED
        end

        -- Premium cell color
        if claimedP[t] then
            cell.PremCell.BackgroundColor3 = COL_CLAIMED
            cell.PremLbl.TextColor3 = Color3.fromRGB(100, 60, 120)
        elseif premium then
            cell.PremCell.BackgroundColor3 = reached and COL_PREM_OWN or Color3.fromRGB(75, 35, 100)
        else
            cell.PremCell.BackgroundColor3 = COL_PREMIUM
        end

        -- Lock icon on premium cells if not premium owner
        if not premium and not claimedP[t] then
            cell.PremLbl.Text = "🔒"
        end

        -- Tier number highlight for current tier
        cell.Num.TextColor3 = isCurrent
            and Color3.fromRGB(100, 255, 140)
            or (reached and Color3.fromRGB(200, 200, 220) or Color3.fromRGB(100, 100, 120))
    end

    -- Auto-scroll to center current tier
    local scrollTarget = math.max(0, (passData.Tier or 0) * TIER_CELL_W - 300)
    trackScroll.CanvasPosition = Vector2.new(scrollTarget, 0)
end

-- ── Season Countdown Timer ────────────────────────────────────────────────────

local function formatCountdown(seconds: number): string
    if seconds <= 0 then return "Season ended" end
    local days    = math.floor(seconds / 86400)
    local hours   = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then
        return string.format("⏳ %dd %dh remaining", days, hours)
    else
        return string.format("⏳ %dh %dm remaining", hours, minutes)
    end
end

RunService.Heartbeat:Connect(function()
    if not screenGui.Enabled or not passData then return end
    if passData.SeasonEndTime then
        local remaining = passData.SeasonEndTime - os.time()
        timerLabel.Text = formatCountdown(remaining)
    end
end)

-- ── Tier-Up Fanfare ───────────────────────────────────────────────────────────

local function playTierUpEffect(newTier: number)
    local fanfare = Instance.new("Frame")
    fanfare.Size = UDim2.new(1, 0, 0, 50)
    fanfare.Position = UDim2.new(0, 0, 0.5, -25)
    fanfare.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
    fanfare.BackgroundTransparency = 0.3
    fanfare.BorderSizePixel = 0
    fanfare.ZIndex = 20
    fanfare.Parent = mainFrame

    local fLabel = Instance.new("TextLabel")
    fLabel.Size = UDim2.new(1, 0, 1, 0)
    fLabel.BackgroundTransparency = 1
    fLabel.Text = "🎉 TIER " .. newTier .. " UNLOCKED!"
    fLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
    fLabel.Font = Enum.Font.GothamBlack
    fLabel.TextSize = 28
    fLabel.ZIndex = 21
    fLabel.Parent = fanfare

    task.delay(2, function()
        TweenService:Create(fanfare, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(fLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        task.delay(0.5, function() fanfare:Destroy() end)
    end)
end

-- ── Open / Close ─────────────────────────────────────────────────────────────

local function open()
    if not LaunchConfig.IsFeatureEnabled("BattlePass") then
        -- Not yet live — show teaser
        local toast = Instance.new("ScreenGui")
        toast.DisplayOrder = 100
        toast.Parent = playerGui
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 360, 0, 48)
        lbl.Position = UDim2.new(0.5, -180, 0.8, 0)
        lbl.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
        lbl.TextColor3 = Color3.fromRGB(200, 160, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 15
        lbl.Text = "⚔️ Battle Pass unlocks April 29!"
        lbl.BorderSizePixel = 0
        lbl.Parent = toast
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = lbl
        task.delay(3, function() toast:Destroy() end)
        return
    end

    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 820, 0, 480),
        Position = UDim2.new(0.5, -410, 0.5, -240),
    }):Play()
    Network.FireServer("RequestBattlePassData")
end

local function close()
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    tween:Play()
    tween.Completed:Wait()
    screenGui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(close)
overlay.MouseButton1Click:Connect(close)

premBtn.MouseButton1Click:Connect(function()
    if passData and not passData.Premium then
        Network.FireServer("PurchaseBattlePass")
    end
end)

-- ── Network Handlers ─────────────────────────────────────────────────────────

Network.OnClientEvent("BattlePassData", function(snapshot)
    passData = snapshot
    if snapshot.SeasonName then
        seasonLabel.Text = "⚔️ " .. snapshot.SeasonName
    end
    buildCells(snapshot)
    refreshCells()
end)

Network.OnClientEvent("BattlePassXPGained", function(info)
    if not passData then return end
    passData.XP   = info.XP
    passData.Tier = info.Tier
    if screenGui.Enabled then refreshCells() end
end)

Network.OnClientEvent("BattlePassTierUp", function(info)
    if not passData then return end
    passData.Tier = info.NewTier
    if screenGui.Enabled then
        refreshCells()
        playTierUpEffect(info.NewTier)
    end
end)

-- Also refresh on purchase confirmation (snapshot re-sent by server)
Network.OnClientEvent("PlayerDataLoaded", function(data)
    -- Pull initial pass state (Season/Tier/XP/Premium/Claimed) from full data load
    if data.BattlePassSeason ~= nil then
        passData = passData or {}
        passData.Tier    = data.BattlePassTier    or 0
        passData.XP      = data.BattlePassXP      or 0
        passData.Premium = data.BattlePassPremium or false
        passData.TiersClaimedFree = data.BattlePassTiersClaimedF or {}
        passData.TiersClaimedPrem = data.BattlePassTiersClaimedP or {}
        passData.XPPerTier  = 1000
        passData.MaxTier    = 30
        passData.SeasonName = "Season 1: Origins"
        passData.SeasonEndTime = 1747094400
    end
end)

-- ── Side Button Wiring ────────────────────────────────────────────────────────

task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if not mainHud then return end
    local sideButtons = mainHud:WaitForChild("SideButtons", 10)
    if not sideButtons then return end
    local btn = sideButtons:FindFirstChild("BattlePassButton")
    if btn then
        btn.MouseButton1Click:Connect(open)
    end
end)

print("[GUI] BattlePassGui loaded")
