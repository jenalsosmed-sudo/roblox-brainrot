-- BrainrotFactory: builds the 3D model of one brainrot from its data row.
-- One job only: turn a BrainrotData row into a Model the world can show, move and sell.
-- The model is a chunky toy figure (body + head + one signature accessory) with a floating
-- label that reads its name, rarity and money per second, and a ClickDetector the server
-- uses for buying and stealing. No game rules live here; the server owns those.

local BrainrotFactory = {}

local function makePart(name, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- One signature accessory per character, built from plain parts so the game ships no assets.
local function buildAccessory(kind, size, color)
	local parts = {}
	if kind == "cup" then
		-- A tall drink cup with a straw.
		local cup = makePart("Cup", Vector3.new(0.7 * size, 1.1 * size, 0.7 * size), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		local straw = makePart("Straw", Vector3.new(0.15 * size, 1.0 * size, 0.15 * size), Color3.fromRGB(255, 80, 80), Enum.Material.SmoothPlastic)
		straw.CFrame = CFrame.new(0.25 * size, 0.8 * size, 0)
		table.insert(parts, cup)
		table.insert(parts, straw)
	elseif kind == "hat" then
		-- A wide-brimmed market hat.
		local brim = makePart("Brim", Vector3.new(2.2 * size, 0.2 * size, 2.2 * size), Color3.fromRGB(240, 220, 160), Enum.Material.SmoothPlastic)
		local top = makePart("Top", Vector3.new(1.0 * size, 0.7 * size, 1.0 * size), Color3.fromRGB(200, 170, 110), Enum.Material.SmoothPlastic)
		top.CFrame = CFrame.new(0, 0.45 * size, 0)
		table.insert(parts, brim)
		table.insert(parts, top)
	elseif kind == "wings" then
		-- Two flat wings, one each side.
		for _, side in ipairs({ -1, 1 }) do
			local wing = makePart("Wing", Vector3.new(1.4 * size, 0.15 * size, 0.9 * size), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
			wing.CFrame = CFrame.new(side * 1.4 * size, 0.2 * size, 0) * CFrame.Angles(0, 0, side * 0.5)
			table.insert(parts, wing)
		end
	elseif kind == "crown" then
		-- A golden crown.
		local band = makePart("Band", Vector3.new(1.5 * size, 0.5 * size, 1.5 * size), Color3.fromRGB(255, 215, 0), Enum.Material.Neon)
		local point = makePart("Point", Vector3.new(0.4 * size, 0.6 * size, 0.4 * size), Color3.fromRGB(255, 215, 0), Enum.Material.Neon)
		point.CFrame = CFrame.new(0, 0.5 * size, 0)
		table.insert(parts, band)
		table.insert(parts, point)
	elseif kind == "spoon" then
		-- A giant spoon held upright.
		local handle = makePart("Handle", Vector3.new(0.25 * size, 1.6 * size, 0.25 * size), Color3.fromRGB(220, 220, 220), Enum.Material.SmoothPlastic)
		local bowl = makePart("Bowl", Vector3.new(0.8 * size, 0.9 * size, 0.2 * size), Color3.fromRGB(220, 220, 220), Enum.Material.SmoothPlastic)
		bowl.CFrame = CFrame.new(0, 1.1 * size, 0)
		table.insert(parts, handle)
		table.insert(parts, bowl)
	elseif kind == "pan" then
		-- A frying pan (tukang bakso's wok).
		local pan = makePart("Pan", Vector3.new(1.8 * size, 0.3 * size, 1.8 * size), Color3.fromRGB(60, 60, 60), Enum.Material.SmoothPlastic)
		local handle = makePart("Handle", Vector3.new(1.2 * size, 0.25 * size, 0.25 * size), Color3.fromRGB(120, 80, 40), Enum.Material.SmoothPlastic)
		handle.CFrame = CFrame.new(1.4 * size, 0, 0)
		table.insert(parts, pan)
		table.insert(parts, handle)
	end
	return parts
end

-- The floating label over a brainrot: name, rarity colour, income per second, mutation.
local function buildLabel(data, mutationName, incomePerSecond)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 72)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Parent = gui

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.Position = UDim2.new(0, 0, 0.45, 0)
	infoLabel.Size = UDim2.new(1, 0, 0.55, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextStrokeTransparency = 0
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.Parent = gui

	-- Rebuild the info line whenever the brainrot changes (bought, mutated, stolen).
	local function refresh(mutation, income)
		local rarity = data.rarity
		if mutation then
			rarity = rarity .. " " .. mutation
		end
		infoLabel.Text = rarity .. "  •  $" .. tostring(math.floor(income + 0.5)) .. "/dtk"
		infoLabel.TextColor3 = Color3.fromRGB(140, 255, 140)
	end
	refresh(mutationName, incomePerSecond)

	return gui, refresh
end

-- Build the model at a position. Returns the model and a refresh function for its label.
function BrainrotFactory.build(data, position, mutationName, incomePerSecond)
	local size = data.size
	local model = Instance.new("Model")
	model.Name = data.name

	local body = makePart("Body", Vector3.new(2 * size, 2 * size, 2 * size), data.color, Enum.Material.SmoothPlastic)
	body.CFrame = CFrame.new(position + Vector3.new(0, 1 * size, 0))
	body.CanCollide = false
	body.Parent = model

	local head = makePart("Head", Vector3.new(1.5 * size, 1.5 * size, 1.5 * size), data.color, Enum.Material.SmoothPlastic)
	head.CFrame = CFrame.new(position + Vector3.new(0, 2.7 * size, 0))
	head.CanCollide = false
	head.Parent = model

	-- Two eyes so the figure reads as a character, not a box.
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Vector3.new(0.3 * size, 0.4 * size, 0.2 * size), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
		eye.CFrame = CFrame.new(position + Vector3.new(side * 0.4 * size, 2.8 * size, 0.8 * size))
		eye.Parent = model
	end

	-- The accessory rides on top of the head: each part's CFrame is its offset from the
	-- head top, so adding the head-top position places the whole accessory at once.
	local headTop = position + Vector3.new(0, 3.8 * size, 0)
	for _, part in ipairs(buildAccessory(data.accessory, size, data.color)) do
		part.CFrame = CFrame.new(headTop) * part.CFrame
		part.Parent = model
	end

	model:SetAttribute("Size", size)

	local label, refresh = buildLabel(data, mutationName, incomePerSecond)
	label.Parent = body

	local click = Instance.new("ClickDetector")
	click.Name = "Click"
	click.MaxActivationDistance = 40
	click.Parent = body

	model.PrimaryPart = body
	return model, refresh
end

-- Move the whole model so its feet sit on the ground at a position.
function BrainrotFactory.placeAt(model, position)
	local size = model:GetAttribute("Size") or 1
	local body = model.PrimaryPart
	if body then
		local current = body.Position
		local delta = Vector3.new(position.X - current.X, (position.Y + 1 * size) - current.Y, position.Z - current.Z)
		model:PivotTo(model:GetPivot() + delta)
	end
end

return BrainrotFactory
