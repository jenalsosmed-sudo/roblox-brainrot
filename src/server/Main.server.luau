-- Main: the server of Pasar Malam Brainrot. It owns every rule and every number.
-- State lives in one place (the `players` table and the `belt` list); the client only asks
-- and displays. Money, income, buying, stealing, locks, mutations, rebirths, the raid and
-- the runaway cart are all decided here, so a client can never lie about them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local BrainrotFactory = require(script.Parent:WaitForChild("BrainrotFactory"))

local GameEvent = Instance.new("RemoteEvent")
GameEvent.Name = "GameEvent"
GameEvent.Parent = ReplicatedStorage

-- One entry per player. brainrots is a list of owned brainrots, each { uid, id, mutation, slot, model, refresh }.
local players = {}
-- Brainrots walking the conveyor: { uid, id, model, x, size, refresh }.
local belt = {}
-- Brainrots being carried away by a thief, keyed by uid: { thief, owner, deadline }.
local carried = {}
local uidCounter = 0
local cart = nil -- the runaway cart, when one is crossing the plaza
local cartKnockAt = {} -- player -> last knock time, to debounce the cart's touch

local function nextUid()
	uidCounter += 1
	return uidCounter
end

local function now()
	return os.clock()
end

-- The eight slots of a base, in a 4 by 2 grid around the base's centre.
local function slotPosition(baseIndex, slot)
	local base = BrainrotData.BASES[baseIndex]
	local col = (slot - 1) % 4
	local row = math.floor((slot - 1) / 4)
	return base.position + Vector3.new(-6 + col * 4, 0, -4 + row * 8)
end

local function freeSlot(data)
	local used = {}
	for _, b in ipairs(data.brainrots) do
		used[b.slot] = true
	end
	for slot = 1, BrainrotData.BASE_SLOTS do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

local function incomeOf(entry, data)
	local def = BrainrotData.getBrainrot(entry.id)
	local mult = 1
	if entry.mutation then
		local m = BrainrotData.getMutation(entry.mutation)
		if m then
			mult = m.multiplier
		end
	end
	return def.income * mult * BrainrotData.rebirthMultiplier(data.rebirths)
end

local function totalIncome(data)
	local sum = 0
	for _, entry in ipairs(data.brainrots) do
		sum += incomeOf(entry, data)
	end
	return sum
end

local function sendState(player)
	local data = players[player]
	if not data then
		return
	end
	GameEvent:FireClient(player, "state", {
		rebirths = data.rebirths,
		multiplier = BrainrotData.rebirthMultiplier(data.rebirths),
		rebirthCost = BrainrotData.rebirthCost(data.rebirths),
		lockUntil = data.lockUntil,
		lockCooldownUntil = data.lockCooldownUntil,
		lockSeconds = BrainrotData.LOCK_SECONDS,
		income = totalIncome(data),
	})
end

local function sendBelt()
	local list = {}
	for _, item in ipairs(belt) do
		local def = BrainrotData.getBrainrot(item.id)
		table.insert(list, {
			uid = item.uid,
			id = item.id,
			name = def.name,
			rarity = def.rarity,
			cost = def.cost,
			income = def.income,
		})
	end
	GameEvent:FireAllClients("belt", list)
end

local function notify(player, text)
	GameEvent:FireClient(player, "notify", text)
end

local function notifyAll(text)
	GameEvent:FireAllClients("notify", text)
end

-- Put a brainrot model on a player's base slot and record it as owned.
local function placeOnBase(player, entry)
	local data = players[player]
	local model = entry.model
	BrainrotFactory.placeAt(model, slotPosition(data.baseIndex, entry.slot))
	model:SetAttribute("Owner", player.Name)
	model:SetAttribute("Uid", entry.uid)
end

-- Return a brainrot to its owner's base (after a failed steal, a timeout or a knock).
local function returnToOwner(uid)
	local carry = carried[uid]
	if not carry then
		return
	end
	carried[uid] = nil
	local owner = carry.owner
	local data = players[owner]
	if not data then
		return
	end
	-- Find the entry (it is still in the owner's list, flagged as carried).
	for _, entry in ipairs(data.brainrots) do
		if entry.uid == uid then
			local slot = freeSlot(data)
			if slot then
				entry.slot = slot
				placeOnBase(owner, entry)
			end
			break
		end
	end
end

-- Take a brainrot off the conveyor and give it to a player. Returns true on success.
local function tryBuy(player, uid)
	local data = players[player]
	if not data then
		return false
	end
	local index = nil
	for i, item in ipairs(belt) do
		if item.uid == uid then
			index = i
			break
		end
	end
	if not index then
		notify(player, "Brainrot itu sudah tidak ada di conveyor.")
		return false
	end
	local item = belt[index]
	local def = BrainrotData.getBrainrot(item.id)
	if data.money < def.cost then
		notify(player, "Uang lo kurang! Butuh " .. BrainrotData.formatMoney(def.cost) .. ".")
		return false
	end
	local slot = freeSlot(data)
	if not slot then
		notify(player, "Base lo penuh! Rebirth dulu biar lapang.")
		return false
	end
	data.money -= def.cost
	table.remove(belt, index)
	local entry = { uid = item.uid, id = item.id, mutation = nil, slot = slot, model = item.model, refresh = item.refresh }
	table.insert(data.brainrots, entry)
	placeOnBase(player, entry)
	entry.refresh(nil, incomeOf(entry, data))
	data.leaderstats.Money.Value = math.floor(data.money + 0.5)
	notify(player, "Dibeli: " .. def.name .. " (" .. def.rarity .. ")! Menghasilkan $" .. tostring(def.income) .. "/dtk.")
	sendBelt()
	return true
end

-- Start carrying a brainrot off someone else's base. Returns true when the steal begins.
local function trySteal(player, uid)
	local data = players[player]
	if not data then
		return false
	end
	if data.carrying then
		notify(player, "Lo sudah bawa satu brainrot! Bawa pulang dulu.")
		return false
	end
	for other, otherData in pairs(players) do
		if other ~= player then
			for _, entry in ipairs(otherData.brainrots) do
				if entry.uid == uid then
					if now() < otherData.lockUntil then
						notify(player, "Base " .. other.Name .. " terkunci! Tunggu gemboknya habis.")
						return false
					end
					entry.slot = 0 -- off the base while carried
					carried[uid] = { thief = player, owner = other, deadline = now() + BrainrotData.CARRY_SECONDS }
					data.carrying = uid
					notify(player, "LARI! Bawa pulang ke base lo sebelum ketahuan!")
					notify(other, "MALING! " .. player.Name .. " bawa kabur brainrot lo! Klik brainrotnya buat rebut balik!")
					return true
				end
			end
		end
	end
	notify(player, "Brainrot itu tidak bisa dicuri.")
	return false
end

-- The owner clicks their own carried brainrot to snatch it back, if close enough to the thief.
local function tryRecall(player, uid)
	local carry = carried[uid]
	if not carry or carry.owner ~= player then
		return false
	end
	local thief = carry.thief
	local thiefChar = thief.Character
	local ownerChar = player.Character
	if not thiefChar or not ownerChar then
		return false
	end
	local thiefRoot = thiefChar:FindFirstChild("HumanoidRootPart")
	local ownerRoot = ownerChar:FindFirstChild("HumanoidRootPart")
	if not thiefRoot or not ownerRoot then
		return false
	end
	if (thiefRoot.Position - ownerRoot.Position).Magnitude > 20 then
		notify(player, "Kejauhan! Kejar dulu malingnya.")
		return false
	end
	local data = players[player]
	data.carrying = nil
	local thiefData = players[thief]
	if thiefData then
		thiefData.carrying = nil
	end
	returnToOwner(uid)
	notify(player, "Berhasil direbut balik!")
	notify(thief, "Ketahuan! Brainrotnya direbut balik.")
	return true
end

-- A click on a brainrot model: buy it off the belt, steal it off a rival base, or recall it.
local function onBrainrotClicked(player, model)
	local uid = model:GetAttribute("Uid")
	if not uid then
		return
	end
	-- On the belt: buy.
	for _, item in ipairs(belt) do
		if item.uid == uid then
			tryBuy(player, uid)
			return
		end
	end
	-- Carried: the owner recalls it, anyone else watches.
	local carry = carried[uid]
	if carry then
		if carry.owner == player then
			tryRecall(player, uid)
		end
		return
	end
	-- Owned by someone: steal it, or read your own.
	for other, otherData in pairs(players) do
		for _, entry in ipairs(otherData.brainrots) do
			if entry.uid == uid then
				if other == player then
					local def = BrainrotData.getBrainrot(entry.id)
					notify(player, def.name .. " (" .. def.rarity .. "): $" .. tostring(math.floor(incomeOf(entry, otherData) + 0.5)) .. "/dtk.")
				else
					trySteal(player, uid)
				end
				return
			end
		end
	end
end

-- Wire a brainrot model's ClickDetector to the click handler above.
local function wireClick(model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local click = body:FindFirstChild("Click")
	if click then
		click.MouseClick:Connect(function(player)
			onBrainrotClicked(player, model)
		end)
	end
end

-- Spawn one brainrot on the conveyor and walk it along the belt.
local function spawnBeltBrainrot()
	if #belt >= BrainrotData.BELT_MAX then
		return
	end
	local bestRebirth = 0
	for _, data in pairs(players) do
		bestRebirth = math.max(bestRebirth, data.rebirths)
	end
	local def = BrainrotData.rollBrainrot(bestRebirth)
	local model, refresh = BrainrotFactory.build(def, Vector3.new(BrainrotData.BELT_START_X, 0.5, BrainrotData.BELT_Z), nil, def.income)
	model:SetAttribute("Uid", nextUid())
	model.Parent = Workspace
	wireClick(model)
	table.insert(belt, { uid = model:GetAttribute("Uid"), id = def.id, model = model, x = BrainrotData.BELT_START_X, size = def.size, refresh = refresh })
	sendBelt()
end

-- The runaway cart: a market cart that tears across the plaza and knocks players over.
local function spawnCart()
	if cart then
		return
	end
	local lanes = { -20, 0, 20 }
	local lane = lanes[math.random(1, #lanes)]
	local model = Instance.new("Model")
	model.Name = "Gerobak Liar"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4, 2, 3)
	body.Color = Color3.fromRGB(200, 60, 60)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.new(-95, 1.5, lane)
	body.Parent = model
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Size = Vector3.new(3, 1.5, 0.2)
	sign.Color = Color3.fromRGB(255, 220, 60)
	sign.Material = Enum.Material.Neon
	sign.Anchored = true
	sign.CanCollide = false
	sign.CFrame = CFrame.new(-95, 3.5, lane)
	sign.Parent = model
	model.PrimaryPart = body
	model.Parent = Workspace
	cart = { model = model, x = -95, lane = lane }
	notifyAll("AWAS! Gerobak liar melintas! Jangan sampai ketabrak!")
	body.Touched:Connect(function(other)
		local character = other.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local last = cartKnockAt[player]
		if last and now() - last < 2 then
			return
		end
		cartKnockAt[player] = now()
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			-- Knock the player sideways and briefly stop them.
			root.CFrame = root.CFrame + Vector3.new(0, 0, 10)
			humanoid.WalkSpeed = 0
			task.delay(1, function()
				if humanoid.Parent then
					humanoid.WalkSpeed = 16
				end
			end)
			notify(player, "Ketabrak gerobak liar!")
		end
		-- A hit drops whatever the player is carrying.
		local data = players[player]
		if data and data.carrying then
			local uid = data.carrying
			data.carrying = nil
			returnToOwner(uid)
			notify(player, "Brainrot curian lo jatuh!")
		end
	end)
end

-- The Satpol PP raid: confiscate the belt and send everyone home.
local function runRaid()
	notifyAll("RAZIA SATPOL PP! Semua brainrot di conveyor disita! Lari ke base lo!")
	for _, item in ipairs(belt) do
		item.model:Destroy()
	end
	belt = {}
	sendBelt()
	for player, data in pairs(players) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local base = BrainrotData.BASES[data.baseIndex]
			if (root.Position - base.position).Magnitude > 12 then
				root.CFrame = CFrame.new(base.position + Vector3.new(0, 3, 0))
			end
		end
	end
	task.wait(1)
	notifyAll("Razia selesai. Conveyor mulai jalan lagi!")
end

-- One heartbeat drives the belt, the carried brainrots, the cart and the steal timer.
RunService.Heartbeat:Connect(function(dt)
	-- The belt walks its brainrots toward the exit.
	for i = #belt, 1, -1 do
		local item = belt[i]
		item.x += BrainrotData.BELT_SPEED * dt
		if item.x > BrainrotData.BELT_END_X then
			item.model:Destroy()
			table.remove(belt, i)
			sendBelt()
		else
			BrainrotFactory.placeAt(item.model, Vector3.new(item.x, 0.5, BrainrotData.BELT_Z))
		end
	end
	-- Carried brainrots hover over the thief and finish when the thief reaches home.
	for uid, carry in pairs(carried) do
		local thief = carry.thief
		local owner = carry.owner
		local thiefData = players[thief]
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not thiefData or not root then
			returnToOwner(uid)
		elseif now() > carry.deadline then
			returnToOwner(uid)
			notify(thief, "Kelamaan! Brainrotnya balik ke pemiliknya.")
			notify(owner, "Brainrot lo balik sendiri. Malingnya kelamaan.")
		else
			-- Find the model and hold it over the thief's head.
			local model = nil
			for _, entry in ipairs(players[owner].brainrots) do
				if entry.uid == uid then
					model = entry.model
					break
				end
			end
			if model then
				BrainrotFactory.placeAt(model, root.Position + Vector3.new(0, 4, 0))
			end
			-- Home: the thief's own base claims the brainrot.
			local base = BrainrotData.BASES[thiefData.baseIndex]
			if (root.Position - base.position).Magnitude < 10 then
				local entry = nil
				for _, e in ipairs(players[owner].brainrots) do
					if e.uid == uid then
						entry = e
						break
					end
				end
				if entry then
					-- Move the entry from the owner's list to the thief's.
					for i, e in ipairs(players[owner].brainrots) do
						if e.uid == uid then
							table.remove(players[owner].brainrots, i)
							break
						end
					end
					carried[uid] = nil
					thiefData.carrying = nil
					local slot = freeSlot(thiefData)
					if slot then
						entry.slot = slot
						table.insert(thiefData.brainrots, entry)
						placeOnBase(thief, entry)
						entry.refresh(entry.mutation, incomeOf(entry, thiefData))
						notify(thief, "BERHASIL! Brainrot curian jadi milik lo!")
						notify(owner, "Brainrot lo DICURI " .. thief.Name .. "!")
					else
						-- No room: it goes back to the owner instead of vanishing.
						returnToOwner(uid)
						notify(thief, "Base lo penuh, curiannya balik ke pemiliknya.")
					end
				end
			end
		end
	end
	-- The cart tears across the plaza.
	if cart then
		cart.x += 40 * dt
		if cart.x > 95 then
			cart.model:Destroy()
			cart = nil
		else
			cart.model:PivotTo(CFrame.new(cart.x, 1.5, cart.lane))
		end
	end
end)

-- Money ticks once a second for every player.
task.spawn(function()
	while true do
		task.wait(1)
		for player, data in pairs(players) do
			local gain = totalIncome(data)
			if gain > 0 then
				data.money += gain
				data.leaderstats.Money.Value = math.floor(data.money + 0.5)
				GameEvent:FireClient(player, "income", gain)
			end
		end
	end
end)

-- A new brainrot rolls onto the belt every few seconds.
task.spawn(function()
	while true do
		task.wait(BrainrotData.BELT_SPAWN_SECONDS)
		spawnBeltBrainrot()
	end
end)

-- The runaway cart crosses the plaza on a timer.
task.spawn(function()
	while true do
		task.wait(BrainrotData.CART_EVERY_SECONDS)
		spawnCart()
	end
end)

-- The raid: warn, then sweep.
task.spawn(function()
	while true do
		task.wait(BrainrotData.RAID_EVERY_SECONDS - BrainrotData.RAID_WARN_SECONDS)
		GameEvent:FireAllClients("raid", BrainrotData.RAID_WARN_SECONDS)
		task.wait(BrainrotData.RAID_WARN_SECONDS)
		runRaid()
	end
end)

-- Client requests: buy, steal, lock, mutate, rebirth.
GameEvent.OnServerEvent:Connect(function(player, action, arg)
	local data = players[player]
	if not data then
		return
	end
	if action == "buy" then
		tryBuy(player, arg)
	elseif action == "steal" then
		trySteal(player, arg)
	elseif action == "lock" then
		if now() < data.lockCooldownUntil then
			notify(player, "Gembok masih cooldown (" .. tostring(math.ceil(data.lockCooldownUntil - now())) .. " dtk).")
		else
			data.lockUntil = now() + BrainrotData.LOCK_SECONDS
			data.lockCooldownUntil = now() + BrainrotData.LOCK_COOLDOWN
			notify(player, "Base lo terkunci " .. tostring(BrainrotData.LOCK_SECONDS) .. " detik! Maling nggak bisa masuk.")
			sendState(player)
		end
	elseif action == "mutate" then
		-- arg is a brainrot uid, or nil for a random one of the player's.
		local entry = nil
		if arg then
			for _, e in ipairs(data.brainrots) do
				if e.uid == arg then
					entry = e
					break
				end
			end
		elseif #data.brainrots > 0 then
			entry = data.brainrots[math.random(1, #data.brainrots)]
		end
		if not entry then
			notify(player, "Lo belum punya brainrot buat dimutasi.")
			return
		end
		if data.money < BrainrotData.MUTATION_COST then
			notify(player, "Mutasi butuh " .. BrainrotData.formatMoney(BrainrotData.MUTATION_COST) .. ".")
			return
		end
		data.money -= BrainrotData.MUTATION_COST
		local mutation = BrainrotData.rollMutation()
		entry.mutation = mutation.name
		entry.refresh(mutation.name, incomeOf(entry, data))
		data.leaderstats.Money.Value = math.floor(data.money + 0.5)
		notify(player, "Mutasi " .. mutation.name .. " (x" .. tostring(mutation.multiplier) .. ")! Income brainrot itu naik!")
	elseif action == "rebirth" then
		local cost = BrainrotData.rebirthCost(data.rebirths)
		if data.money < cost then
			notify(player, "Rebirth butuh " .. BrainrotData.formatMoney(cost) .. ". Kumpulin dulu!")
			return
		end
		for _, entry in ipairs(data.brainrots) do
			entry.model:Destroy()
		end
		data.brainrots = {}
		data.money = 0
		data.rebirths += 1
		data.leaderstats.Money.Value = 0
		data.leaderstats.Rebirths.Value = data.rebirths
		notify(player, "REBIRTH! Income lo sekarang x" .. string.format("%.2f", BrainrotData.rebirthMultiplier(data.rebirths)) .. ". Rarity baru terbuka!")
		sendState(player)
	end
end)

-- A player joins: give them money, a base, leaderstats and the first state.
local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local moneyValue = Instance.new("IntValue")
	moneyValue.Name = "Money"
	moneyValue.Value = BrainrotData.START_MONEY
	moneyValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = 0
	rebirthValue.Parent = leaderstats

	-- First free base; if all are taken, share the least crowded one.
	local used = {}
	for _, data in pairs(players) do
		used[data.baseIndex] = (used[data.baseIndex] or 0) + 1
	end
	local baseIndex = 1
	for i = 1, #BrainrotData.BASES do
		if not used[i] then
			baseIndex = i
			break
		end
	end
	if used[baseIndex] then
		local fewest = math.huge
		for i = 1, #BrainrotData.BASES do
			if (used[i] or 0) < fewest then
				fewest = used[i] or 0
				baseIndex = i
			end
		end
	end

	players[player] = {
		money = BrainrotData.START_MONEY,
		rebirths = 0,
		baseIndex = baseIndex,
		brainrots = {},
		lockUntil = 0,
		lockCooldownUntil = 0,
		carrying = nil,
		leaderstats = leaderstats,
	}
	-- A floating label over the base shows whose stall it is.
	local base = BrainrotData.BASES[baseIndex]
	local anchor = Instance.new("Part")
	anchor.Name = "BaseLabelAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CFrame = CFrame.new(base.position + Vector3.new(0, 6, 0))
	anchor.Parent = Workspace
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BaseLabel"
	billboard.Size = UDim2.fromOffset(240, 48)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BASE " .. player.Name
	label.TextColor3 = base.color
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = billboard
	players[player].baseLabel = anchor

	sendState(player)
	sendBelt()
	notify(player, "Selamat datang di Pasar Malam Brainrot! Beli brainrot di conveyor, taruh di base lo, dan jangan sampai dicuri!")
end

local function onPlayerRemoving(player)
	local data = players[player]
	if not data then
		return
	end
	for _, entry in ipairs(data.brainrots) do
		entry.model:Destroy()
	end
	if data.baseLabel then
		data.baseLabel:Destroy()
	end
	players[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

print("Pasar Malam Brainrot: server jalan. Conveyor, base, razia dan gerobak liar aktif.")
