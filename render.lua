local vpk = require("modules.vpk")
local steam = require("modules.steam")
local benchmark = require("modules.benchmark")

local imlib2 = require("modules.imlib2")

local dota = {
	vpk_dir = "/media/jake/storage/Games/SteamApps/common/dota 2 beta/game/dota/pak01_dir.vpk",
	vpk_output = "/media/jake/storage/Games/SteamApps/common/dota 2 beta/game/dota_mods/pak01_dir.vpk",

	vpk_image_dir = "resource/flash3/images",
	vpk_items_dir = "scripts/npc/items.txt",
	vpk_cosmetic_dir = "scripts/items/items_game.txt",
	vpk_abilities_dir = "scripts/npc/npc_abilities.txt",
	vpk_itemicons_dir = "resource/flash3/images/items",
	vpk_spellicons_dir = "resource/flash3/images/spellicons",

	prerendered_items_dir = "prerendered_items",

	output_dir = "rendered_icons",

	fill_blue = imlib2.color(0,138,230,100),
	fill_green = imlib2.color(105,215,20,100),
	fill_gold = imlib2.color(252,188,62,100),
	fill_black = imlib2.color(0,0,0,255),
	fill_shadow = imlib2.color(0,0,0,150),
	fill_white = imlib2.color(255,255,255,255),

	font = imlib2.font("Hypatia-Sans-Pro/11"),

	dmg_type_color = {
	    DAMAGE_TYPE_PHYSICAL = imlib2.color(128,128,128,255), -- #808080
	    DAMAGE_TYPE_MAGICAL = imlib2.color(0,127,255,255), -- #007FFF
	    DAMAGE_TYPE_PURE = imlib2.color(255,0,0,255), -- #DAA520
	}
}

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function dota.mkdir(path)
	path = string.GetPathFromFilename(path)
	local folders = string.split(path, "/")

	local dir = ""
	for _,folder in pairs(folders) do
		if folder ~= "" then
			dir = (dir == "" and dir or dir .. "/") .. folder
			if not file_exists(dir) then
				lfs.mkdir(dir)
			end
		end
	end
end

benchmark.start()
local pak = vpk.load(dota.vpk_dir)
benchmark.finish("Loaded %q in {time} seconds",dota.vpk_dir)

local cosmetics_file = assert(pak:getFile(dota.vpk_cosmetic_dir))

benchmark.start()
local cosmetic_data = steam.VDFToTable(cosmetics_file:readAll())["items_game"]
cosmetics_file:close()
benchmark.finish("Parsed %q in {time} seconds", dota.vpk_cosmetic_dir)

local items_file = assert(pak:getFile(dota.vpk_items_dir))

benchmark.start()
local item_data = steam.VDFToTable(items_file:readAll())['DOTAAbilities']
items_file:close()
benchmark.finish("Parsed %q in {time} seconds", dota.vpk_items_dir)

local abilities_file = assert(pak:getFile(dota.vpk_abilities_dir))

benchmark.start()
local ability_data = steam.VDFToTable(abilities_file:readAll())["DOTAAbilities"]
abilities_file:close()
benchmark.finish("Parsed %q in {time} seconds", dota.vpk_abilities_dir)

local items_rendered = 0
local abilities_rendered = 0

function dota.renderSpellIcon(name,color)
	local spell_icon = string.format("%s/%s.png", dota.vpk_spellicons_dir, name)

	if not pak:hasFile(spell_icon) then	return end

	local vpkrendered_icon = string.format("%s/%s/%s.png", dota.output_dir, dota.vpk_spellicons_dir, name)
	dota.mkdir(vpkrendered_icon)

	local f = assert(pak:getFile(spell_icon))
	f:save(vpkrendered_icon)
	f:close()

	local back_poly = imlib2.poly()
	back_poly:addPoint(128-42, 0)
	back_poly:addPoint(128, 0)
	back_poly:addPoint(128, 42)

	local color_poly = imlib2.poly()
	color_poly:addPoint(128-36, 0)
	color_poly:addPoint(128, 0)
	color_poly:addPoint(128, 36)

	local img = imlib2.image(vpkrendered_icon)
	img:fillPoly(back_poly, dota.fill_black)
	img:fillPoly(color_poly, color)
	img:save(vpkrendered_icon)
	img:free()

	color_poly:free()
	back_poly:free()

	abilities_rendered = abilities_rendered + 1
end

function dota.renderItemIcon(name,manacost,color)
	name = name:sub(6)

	if name:sub(1,7) == "mystery" then return end

	local item_icon = string.format("%s/%s.png", dota.vpk_itemicons_dir, name)

	if not pak:hasFile(item_icon) then print("SKIPPING", name, item_icon) return end

	local vpkrendered_icon = string.format("%s/%s/%s.png", dota.output_dir, dota.vpk_itemicons_dir, name)
	dota.mkdir(vpkrendered_icon)

	local prerendered_icon = string.format("%s/%s.png", dota.prerendered_items_dir, name)
	local use_prerendered = false

	if file_exists(prerendered_icon) then
		use_prerendered = true
	else
		local f = assert(pak:getFile(item_icon))
		f:save(vpkrendered_icon)
		f:close()
	end

	local width, height = dota.font:getSize(manacost)

	local img = imlib2.image(use_prerendered and prerendered_icon or vpkrendered_icon)
	img:fillElipse(0, 64, (width+6), height, color)
	img:drawText(dota.font, manacost, 5, 66 - height, dota.fill_shadow)
	img:drawText(dota.font, manacost, 3, 64 - height, dota.fill_white)
	img:save(vpkrendered_icon)
	img:free()

	items_rendered = items_rendered + 1
end

function dota.parseItemIcons()
	local cosmetic_item_icons = {}

	for name,cosmetic in pairs(cosmetic_data["items"]) do
		if cosmetic["visuals"] then
			for vistype,visual in pairs(cosmetic["visuals"]) do
				if string.find(vistype, "asset_modifier") == 1 and visual["type"] == "icon_replacement" then
					if not cosmetic_item_icons[visual['asset']] then
						cosmetic_item_icons[visual['asset']] = {}
					end
					table.insert(cosmetic_item_icons[visual['asset']], visual['modifier'])
				end
			end
		end
	end

	for name, custom_icons in pairs(cosmetic_item_icons) do
		local item = item_data["item_" .. name]
		if item and item["AbilityManaCost"] then
			for _,custom_icon in pairs(custom_icons) do
				local manacost = item["AbilityManaCost"]
				dota.renderItemIcon("item_" .. custom_icon,manacost,dota.fill_blue)
			end
		end
	end

	for name, info in pairs(item_data) do
		local color = dota.fill_blue
		if name ~= "Version" and info["AbilityManaCost"] then
			local manacost = info["AbilityManaCost"]
			if manacost == 0 and info['AbilitySpecial'] then
				for _,value in pairs(info['AbilitySpecial']) do
					if value["health_sacrifice"] then
						manacost = value['health_sacrifice']
						color = dota.fill_green
					end
				end
			end
			if manacost ~= 0 then
				dota.renderItemIcon(name,manacost,color)
			end
		end
	end
end

function dota.parseAbilityIcons()

	for name, info in pairs(ability_data) do
		if name ~= "Version" and info["AbilityUnitDamageType"] and dota.dmg_type_color[info["AbilityUnitDamageType"]] then
			local color = dota.dmg_type_color[info["AbilityUnitDamageType"]]
			dota.renderSpellIcon(name,color)
		end
	end

	------------------------
	-- Cosmetic Abilities --
	------------------------

	local cosmetic_ability_icons = {}

	for name,cosmetic in pairs(cosmetic_data["items"]) do
		if cosmetic["visuals"] then
			for vistype,visual in pairs(cosmetic["visuals"]) do
				if string.find(vistype, "asset_modifier") == 1 and visual["type"] == "ability_icon" then
					if not cosmetic_ability_icons[visual['asset']] then
						cosmetic_ability_icons[visual['asset']] = {}
					end
					table.insert(cosmetic_ability_icons[visual['asset']],visual['modifier'])
				end
			end
		end
	end

	for name,cosmetic in pairs(cosmetic_data["asset_modifiers"]) do
		for _,visual in pairs(cosmetic) do
			if type(visual) == "table" and visual["type"] == "ability_icon" then
				if not cosmetic_ability_icons[visual['asset']] then
					cosmetic_ability_icons[visual['asset']] = {}
				end
				table.insert(cosmetic_ability_icons[visual['asset']],visual['modifier'])
			end
		end
	end

	for name, custom_icons in pairs(cosmetic_ability_icons) do
		local info = ability_data[name]
		if info and info["AbilityUnitDamageType"] and dota.dmg_type_color[info["AbilityUnitDamageType"]] then
			local color = dota.dmg_type_color[info["AbilityUnitDamageType"]]
			for _,custom_icon in pairs(custom_icons) do
				dota.renderSpellIcon(custom_icon,color)
			end
		end
	end
end

function dota.removeAll(path)
	if not file_exists(path) then return end
	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." then
			local fullpath = path .. "/" .. file
			local mode = lfs.attributes(fullpath, "mode")
			if mode == "file" then
				assert(os.remove(fullpath))
			elseif mode == "directory" then
				dota.removeAll(fullpath)
			end
		end
	end
	assert(os.remove(path))
end

dota.removeAll(dota.output_dir)

benchmark.start()
dota.parseItemIcons()
benchmark.finish("Parsed %i item icons in {time} seconds", items_rendered)

benchmark.start()
dota.parseAbilityIcons()
benchmark.finish("Parsed %i ability icons in {time} seconds", abilities_rendered)

benchmark.start()
local pak = vpk.new()
pak:addFiles("rendered_icons")
pak:addFiles("my_mods")
pak:save("pak01_dir.vpk")
benchmark.finish("Created pak01_dir.vpk in {time} seconds")

assert(os.rename("pak01_dir.vpk", dota.vpk_output))