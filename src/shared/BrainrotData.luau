-- BrainrotData: the single source of truth for every number in Pasar Malam Brainrot.
-- Both the server (prices, income, rarities) and the client (the shop list, the HUD)
-- read from this one module, so the two sides can never disagree about a brainrot.
-- Every character here is original: Indonesian night-market absurdity, invented for this
-- game, not a copy of any character from Steal a Brainrot or any other game.

local BrainrotData = {}

-- Rarity ladder, rarest last. weight is the spawn chance on the conveyor.
BrainrotData.RARITIES = {
	{ name = "Biasa", color = Color3.fromRGB(180, 180, 180), weight = 55, minRebirth = 0 },
	{ name = "Langka", color = Color3.fromRGB(80, 170, 255), weight = 25, minRebirth = 0 },
	{ name = "Epik", color = Color3.fromRGB(190, 100, 255), weight = 12, minRebirth = 0 },
	{ name = "Legendaris", color = Color3.fromRGB(255, 170, 40), weight = 5, minRebirth = 0 },
	{ name = "Mitos", color = Color3.fromRGB(255, 70, 70), weight = 2, minRebirth = 1 },
	{ name = "Dewa", color = Color3.fromRGB(80, 230, 200), weight = 1, minRebirth = 2 },
}

-- accessory kinds the factory knows how to build: cup, hat, wings, crown, spoon, pan.
-- size scales the whole model; income is money earned per second on a base.
BrainrotData.BRAINROTS = {
	{ id = "ayam_geprek", name = "Ayam Geprek Terbang", rarity = "Biasa", cost = 60, income = 3, color = Color3.fromRGB(255, 200, 90), size = 1.0, accessory = "wings" },
	{ id = "es_teh", name = "Es Teh Manis 5000", rarity = "Biasa", cost = 80, income = 4, color = Color3.fromRGB(255, 140, 60), size = 0.9, accessory = "cup" },
	{ id = "kucing_oren", name = "Kucing Oren Bar-Bar", rarity = "Biasa", cost = 120, income = 5, color = Color3.fromRGB(255, 150, 40), size = 1.0, accessory = "crown" },
	{ id = "gorengan_alien", name = "Gorengan Alien", rarity = "Langka", cost = 300, income = 12, color = Color3.fromRGB(120, 220, 90), size = 1.1, accessory = "hat" },
	{ id = "tukang_bakso", name = "Tukang Bakso Raksasa", rarity = "Langka", cost = 450, income = 18, color = Color3.fromRGB(200, 170, 120), size = 1.4, accessory = "pan" },
	{ id = "odong_hantu", name = "Odong-Odong Hantu", rarity = "Epik", cost = 900, income = 35, color = Color3.fromRGB(170, 120, 255), size = 1.3, accessory = "wings" },
	{ id = "nasi_padang", name = "Nasi Padang Terbang", rarity = "Epik", cost = 1200, income = 48, color = Color3.fromRGB(255, 220, 130), size = 1.2, accessory = "spoon" },
	{ id = "kopi_galon", name = "Kopi Susu Galon", rarity = "Legendaris", cost = 2800, income = 120, color = Color3.fromRGB(120, 80, 40), size = 1.5, accessory = "cup" },
	{ id = "satpam_galak", name = "Satpam Galak 24 Jam", rarity = "Legendaris", cost = 3500, income = 150, color = Color3.fromRGB(60, 90, 160), size = 1.5, accessory = "hat" },
	{ id = "kuntilanak_kopi", name = "Kuntilanak Kopi", rarity = "Mitos", cost = 9000, income = 400, color = Color3.fromRGB(230, 230, 240), size = 1.4, accessory = "crown" },
	{ id = "pocong_kelapa", name = "Pocong Es Kelapa", rarity = "Mitos", cost = 12000, income = 550, color = Color3.fromRGB(200, 240, 220), size = 1.4, accessory = "cup" },
	{ id = "dewa_indomie", name = "Dewa Indomie Goreng", rarity = "Dewa", cost = 30000, income = 1500, color = Color3.fromRGB(255, 215, 0), size = 1.8, accessory = "crown" },
}

-- Mutations: a paid roll that multiplies one brainrot's income. weight is the roll chance.
BrainrotData.MUTATIONS = {
	{ name = "Emas", multiplier = 2, color = Color3.fromRGB(255, 215, 0), weight = 50 },
	{ name = "Hantu", multiplier = 3, color = Color3.fromRGB(200, 220, 255), weight = 25 },
	{ name = "Api", multiplier = 4, color = Color3.fromRGB(255, 90, 30), weight = 15 },
	{ name = "Pelangi", multiplier = 5, color = Color3.fromRGB(255, 100, 200), weight = 10 },
}
BrainrotData.MUTATION_COST = 200

-- Rebirth: reset money and brainrots for a permanent income multiplier.
BrainrotData.REBIRTH_BASE_COST = 10000
BrainrotData.REBIRTH_BONUS = 0.25 -- +25% income per rebirth

BrainrotData.START_MONEY = 150
BrainrotData.BELT_SPAWN_SECONDS = 4
BrainrotData.BELT_MAX = 6
BrainrotData.BELT_SPEED = 6 -- studs per second along the belt
BrainrotData.BELT_START_X = -70
BrainrotData.BELT_END_X = 70
BrainrotData.BELT_Z = -40
BrainrotData.BASE_SLOTS = 8
BrainrotData.LOCK_SECONDS = 30
BrainrotData.LOCK_COOLDOWN = 60
BrainrotData.CARRY_SECONDS = 20
BrainrotData.RAID_EVERY_SECONDS = 150
BrainrotData.RAID_WARN_SECONDS = 10
BrainrotData.CART_EVERY_SECONDS = 45

-- Six stall bases around the plaza. Each is a platform the server assigns to a player.
BrainrotData.BASES = {
	{ position = Vector3.new(-60, 0.5, 40), color = Color3.fromRGB(255, 100, 100) },
	{ position = Vector3.new(-20, 0.5, 40), color = Color3.fromRGB(100, 200, 255) },
	{ position = Vector3.new(20, 0.5, 40), color = Color3.fromRGB(120, 230, 120) },
	{ position = Vector3.new(60, 0.5, 40), color = Color3.fromRGB(255, 200, 60) },
	{ position = Vector3.new(-80, 0.5, -10), color = Color3.fromRGB(200, 120, 255) },
	{ position = Vector3.new(80, 0.5, -10), color = Color3.fromRGB(255, 140, 200) },
}

function BrainrotData.getRarity(name)
	for _, r in ipairs(BrainrotData.RARITIES) do
		if r.name == name then
			return r
		end
	end
	return BrainrotData.RARITIES[1]
end

function BrainrotData.getBrainrot(id)
	for _, b in ipairs(BrainrotData.BRAINROTS) do
		if b.id == id then
			return b
		end
	end
	return nil
end

function BrainrotData.getMutation(name)
	for _, m in ipairs(BrainrotData.MUTATIONS) do
		if m.name == name then
			return m
		end
	end
	return nil
end

-- Weighted pick of a rarity the player has unlocked (Mitos needs 1 rebirth, Dewa 2).
function BrainrotData.rollRarity(rebirths)
	local total = 0
	for _, r in ipairs(BrainrotData.RARITIES) do
		if rebirths >= r.minRebirth then
			total += r.weight
		end
	end
	local roll = math.random(1, total)
	for _, r in ipairs(BrainrotData.RARITIES) do
		if rebirths >= r.minRebirth then
			roll -= r.weight
			if roll <= 0 then
				return r.name
			end
		end
	end
	return "Biasa"
end

function BrainrotData.rollBrainrot(rebirths)
	local rarity = BrainrotData.rollRarity(rebirths)
	local pool = {}
	for _, b in ipairs(BrainrotData.BRAINROTS) do
		if b.rarity == rarity then
			table.insert(pool, b)
		end
	end
	if #pool == 0 then
		return BrainrotData.BRAINROTS[1]
	end
	return pool[math.random(1, #pool)]
end

function BrainrotData.rollMutation()
	local total = 0
	for _, m in ipairs(BrainrotData.MUTATIONS) do
		total += m.weight
	end
	local roll = math.random(1, total)
	for _, m in ipairs(BrainrotData.MUTATIONS) do
		roll -= m.weight
		if roll <= 0 then
			return m
		end
	end
	return BrainrotData.MUTATIONS[1]
end

function BrainrotData.rebirthCost(rebirths)
	return BrainrotData.REBIRTH_BASE_COST * (rebirths + 1)
end

function BrainrotData.rebirthMultiplier(rebirths)
	return 1 + BrainrotData.REBIRTH_BONUS * rebirths
end

-- Short money text: 1500 -> "$1.5K", 2500000 -> "$2.5M".
function BrainrotData.formatMoney(n)
	n = math.floor(n + 0.5)
	if n >= 1000000 then
		return "$" .. string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return "$" .. string.format("%.1fK", n / 1000)
	else
		return "$" .. tostring(n)
	end
end

return BrainrotData
