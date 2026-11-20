-- Game: the client of Pasar Malam Brainrot. It only shows and asks; the server decides.
-- It builds the ScreenGui over the 3D world: money, the conveyor shop, the lock / mutate /
-- rebirth buttons, the raid banner and the notifications. Money is read from the player's
-- leaderstats (the server writes it every second); everything else arrives on GameEvent.
-- Roblox's own menu sits over the top-left corner, so nothing important lives there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local GameEvent = ReplicatedStorage:WaitForChild("GameEvent")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local leaderstats = player:WaitForChild("leaderstats")
local moneyValue = leaderstats:WaitForChild("Money")
local rebirthValue = leaderstats:WaitForChild("Rebirths")

local gui = Instance.new("ScreenGui")
gui.Name = "PasarMalamGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function makeLabel(parent, name, text, size, position, anchor)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.AnchorPoint = anchor or Vector2.new(0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, size, position, anchor, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.AnchorPoint = anchor or Vector2.new(0, 0)
	button.BackgroundColor3 = color
	button.BorderColor3 = Color3.fromRGB(20, 20, 20)
	button.BorderSizePixel = 2
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	return button
end

-- Money, big and top-centre (clear of Roblox's own menu at the top-left).
local moneyLabel = makeLabel(gui, "Money", "$150", UDim2.fromOffset(320, 56), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
moneyLabel.Font = Enum.Font.GothamBlack

-- Stats: rebirths, multiplier and income per second, top-right.
local statsLabel = makeLabel(gui, "Stats", "Rebirth: 0  •  x1.00  •  $0/dtk", UDim2.fromOffset(300, 32), UDim2.new(1, -12, 0, 70), Vector2.new(1, 0))

-- The raid banner, hidden until a raid is coming.
local banner = makeLabel(gui, "Banner", "", UDim2.fromOffset(520, 48), UDim2.new(0.5, 0, 0, 72), Vector2.new(0.5, 0))
banner.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
banner.BackgroundTransparency = 0.2
banner.TextColor3 = Color3.fromRGB(255, 230, 60)
banner.Font = Enum.Font.GothamBlack
banner.Visible = false

-- Notifications, centre screen, fading after a few seconds.
local notifyLabel = makeLabel(gui, "Notify", "", UDim2.fromOffset(560, 40), UDim2.new(0.5, 0, 0.45, 0), Vector2.new(0.5, 0))
notifyLabel.TextColor3 = Color3.fromRGB(255, 240, 150)
notifyLabel.Visible = false
local notifyToken = 0

local function showNotify(text)
	notifyToken += 1
	local token = notifyToken
	notifyLabel.Text = text
	notifyLabel.Visible = true
	task.delay(4, function()
		if token == notifyToken then
			notifyLabel.Visible = false
		end
	end)
end

-- The conveyor shop, right side: every brainrot currently on the belt, with a buy button.
local shopFrame = Instance.new("Frame")
shopFrame.Name = "Shop"
shopFrame.AnchorPoint = Vector2.new(1, 0)
shopFrame.Position = UDim2.new(1, -12, 0, 112)
shopFrame.Size = UDim2.fromOffset(300, 330)
shopFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
shopFrame.BackgroundTransparency = 0.25
shopFrame.BorderColor3 = Color3.fromRGB(255, 200, 60)
shopFrame.BorderSizePixel = 2
shopFrame.Parent = gui

local shopTitle = makeLabel(shopFrame, "Title", "CONVEYOR — KLIK BELI!", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 0))
shopTitle.TextColor3 = Color3.fromRGB(255, 200, 60)
shopTitle.Font = Enum.Font.GothamBlack

local shopList = Instance.new("ScrollingFrame")
shopList.Name = "List"
shopList.Position = UDim2.new(0, 0, 0, 40)
shopList.Size = UDim2.new(1, 0, 1, -40)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 6
shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.Parent = shopFrame

local function rebuildShop(belt)
	for _, child in ipairs(shopList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if #belt == 0 then
		local empty = makeLabel(shopList, "Empty", "Conveyor kosong... tunggu brainrot baru!", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 0))
		empty.TextColor3 = Color3.fromRGB(200, 200, 200)
		return
	end
	local y = 0
	for _, item in ipairs(belt) do
		local row = Instance.new("Frame")
		row.Name = "Row" .. tostring(item.uid)
		row.Position = UDim2.new(0, 0, 0, y)
		row.Size = UDim2.new(1, 0, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.Parent = shopList
		y += 68

		local rarity = BrainrotData.getRarity(item.rarity)
		local nameLabel = makeLabel(row, "Name", item.name, UDim2.new(1, -76, 0, 28), UDim2.new(0, 6, 0, 4))
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = rarity.color
		local infoLabel = makeLabel(row, "Info", item.rarity .. "  •  $" .. tostring(item.income) .. "/dtk", UDim2.new(1, -76, 0, 24), UDim2.new(0, 6, 0, 32))
		infoLabel.TextXAlignment = Enum.TextXAlignment.Left
		infoLabel.TextColor3 = Color3.fromRGB(140, 255, 140)

		local buy = makeButton(row, "Buy", BrainrotData.formatMoney(item.cost), UDim2.fromOffset(64, 48), UDim2.new(1, -70, 0, 8), Vector2.new(0, 0), Color3.fromRGB(40, 180, 80))
		buy.MouseButton1Click:Connect(function()
			GameEvent:FireServer("buy", item.uid)
		end)
	end
end

-- Action buttons, bottom-right: lock the base, roll a mutation, rebirth.
local actionsFrame = Instance.new("Frame")
actionsFrame.Name = "Actions"
actionsFrame.AnchorPoint = Vector2.new(1, 1)
actionsFrame.Position = UDim2.new(1, -12, 1, -12)
actionsFrame.Size = UDim2.fromOffset(300, 150)
actionsFrame.BackgroundTransparency = 1
actionsFrame.Parent = gui

local lockButton = makeButton(actionsFrame, "Lock", "GEMBOK BASE (30 dtk)", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 0), nil, Color3.fromRGB(70, 110, 200))
local mutateButton = makeButton(actionsFrame, "Mutate", "MUTASI ACAK ($200)", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 52), nil, Color3.fromRGB(170, 80, 200))
local rebirthButton = makeButton(actionsFrame, "Rebirth", "REBIRTH", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 104), nil, Color3.fromRGB(200, 140, 30))

lockButton.MouseButton1Click:Connect(function()
	GameEvent:FireServer("lock")
end)
mutateButton.MouseButton1Click:Connect(function()
	GameEvent:FireServer("mutate")
end)
rebirthButton.MouseButton1Click:Connect(function()
	GameEvent:FireServer("rebirth")
end)

-- A hint at the bottom, so a new player knows what to do.
local hint = makeLabel(gui, "Hint", "Beli brainrot di conveyor, taruh di base lo, kumpulin duit, awas maling & razia!", UDim2.fromOffset(640, 28), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
hint.TextColor3 = Color3.fromRGB(220, 220, 220)

-- Money follows the leaderstats the server writes every second.
local function refreshMoney()
	moneyLabel.Text = BrainrotData.formatMoney(moneyValue.Value)
end
moneyValue.Changed:Connect(refreshMoney)
refreshMoney()

-- Floating "+$X" text whenever income lands.
local function floatIncome(amount)
	local label = Instance.new("TextLabel")
	label.Text = "+" .. BrainrotData.formatMoney(amount)
	label.Size = UDim2.fromOffset(160, 36)
	label.Position = UDim2.new(0.5, math.random(-80, 80), 0, 70)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(120, 255, 120)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	local tween = TweenService:Create(label, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, label.Position.X.Offset, 0, 10),
		TextTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

GameEvent.OnClientEvent:Connect(function(action, payload)
	if action == "state" then
		statsLabel.Text = "Rebirth: " .. tostring(payload.rebirths)
			.. "  •  x" .. string.format("%.2f", payload.multiplier)
			.. "  •  $" .. tostring(math.floor(payload.income + 0.5)) .. "/dtk"
		rebirthButton.Text = "REBIRTH (" .. BrainrotData.formatMoney(payload.rebirthCost) .. ")"
		if payload.lockUntil and payload.lockUntil > 0 then
			lockButton.Text = "BASE TERKUNCI"
			lockButton.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
		else
			lockButton.Text = "GEMBOK BASE (30 dtk)"
			lockButton.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
		end
	elseif action == "belt" then
		rebuildShop(payload)
	elseif action == "notify" then
		showNotify(payload)
	elseif action == "income" then
		floatIncome(payload)
	elseif action == "raid" then
		local seconds = payload
		banner.Visible = true
		task.spawn(function()
			for left = seconds, 1, -1 do
				banner.Text = "RAZIA SATPOL PP DALAM " .. tostring(left) .. " DETIK! LARI KE BASE LO!"
				task.wait(1)
			end
			banner.Visible = false
		end)
	end
end)

print("Pasar Malam Brainrot: client jalan. HUD, shop dan tombol aksi aktif.")
