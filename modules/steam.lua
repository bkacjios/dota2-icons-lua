local lower = string.lower
local concat = table.concat
local pairs = pairs
local ipairs = ipairs
local insert = table.insert
local remove = table.remove
local tonumber = tonumber
local type = type

module(...)

function VDFToTable(str, lower_or_modify_keys, preprocess)
	if not str or str == "" then return nil, "data is empty" end
	if lower_or_modify_keys == true then lower_or_modify_keys = lower end

	str = str:gsub("http://", "___L_O_L___")
	str = str:gsub("https://", "___L_O_L_2___")

	str = str:gsub("//.-\n", "")

	str = str:gsub("___L_O_L___", "http://")
	str = str:gsub("___L_O_L_2___", "https://")

	str = str:gsub("(%b\"\"%s-)%[$(%S-)%](%s-%b{})", function(start, def, stop)
		if def ~= "WIN32" then
			return ""
		end

		return start .. stop
	end)

	str = str:gsub("(%b\"\"%s-)(%b\"\"%s-)%[$(%S-)%]", function(start, stop, def)
		if def ~= "WIN32" then
			return ""
		end
		return start .. stop
	end)


	local tbl = {}

	for uchar in str:gmatch("([%z\1-\127\194-\244][\128-\191]*)") do
		tbl[#tbl + 1] = uchar
	end

	local in_string = false
	local capture = {}
	local no_quotes = false

	local out = {}
	local current = out
	local stack = {current}

	local key, val

	for i = 1, #tbl do
		local char = tbl[i]

		if (char == [["]] or (no_quotes and char:find("%s"))) and tbl[i-1] ~= "\\" then
			if in_string then

				if key then
					if lower_or_modify_keys then
						key = lower_or_modify_keys(key)
					end

					local val = concat(capture, "")

					if preprocess and val:find("|") then
						for k, v in pairs(preprocess) do
							val = val:gsub("|" .. k .. "|", v)
						end
					end

					if val:lower() == "false" then
						val = false
					elseif val:lower() ==  "true" then
						val =  true
					elseif val:find("%b{}") then
						local values = val:match("{(.+)}"):trim():split(" ")
						if #values == 3 or #values == 4 then
							val = {r=tonumber(values[1]), g=tonumber(values[2]), b=tonumber(values[3]), a=values[4] or 255}
						end
					elseif val:find("%b[]") then
						local values = val:match("%[(.+)%]"):trim():split(" ")
						if #values == 3 and tonumber(values[1]) and tonumber(values[2]) and tonumber(values[3]) then
							val = Vec3(tonumber(values[1]), tonumber(values[2]), tonumber(values[3]))
						end
					else
						val = tonumber(val) or val
					end

					if type(current[key]) == "table" then
						insert(current[key], val)
					elseif current[key] then
						current[key] = {current[key], val}
					else
						if key:find("+", nil, true) then
							for i, key in ipairs(key:explode("+")) do
								if type(current[key]) == "table" then
									insert(current[key], val)
								elseif current[key] then
									current[key] = {current[key], val}
								else
									current[key] = val
								end

							end
						else
							current[key] = val
						end
					end

					key = nil
				else
					key = concat(capture, "")
				end

				in_string = false
				no_quotes = false
				capture = {}
			else
				in_string = true
			end
		else
			if in_string then
				insert(capture, char)
			elseif char == [[{]] then
				if key then
					if lower_or_modify_keys then
						key = lower_or_modify_keys(key)
					end

					insert(stack, current)
					current[key] = {}
					current = current[key]
					key = nil
				else
					return nil, "stack imbalance"
				end
			elseif char == [[}]] then
				current = remove(stack) or out
			elseif not char:find("%s") then
				in_string = true
				no_quotes = true
				insert(capture, char)
			end
		end
	end

	return out
end