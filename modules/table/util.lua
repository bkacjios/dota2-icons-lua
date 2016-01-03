function table.merge(first, second)
	for k,v in pairs(second) do
		first[k] = v
	end
end

function table.HasValue(tbl, val)
	for key, value in pairs(tbl) do
		if (value == val) then return true, key end
	end
	return false
end

function table.Print(tbl, indent, done)
	done = done or {[tbl] = true}
	indent = indent or 0
   
	for k, v in pairs(tbl) do
		if (type(v) == "table" and not done[v]) then
			print(string.rep("\t", indent) .. string.format("%q", tostring(k)))
			done[v] = true
			table.Print(v, indent + 2, done)
		else
			print(string.rep("\t", indent) .. string.format("%q", tostring(k)) .. "\t=\t" .. string.format("%q", tostring(v)))
		end
	end
end

PrintTable = table.Print

function table.Copy(object)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

-- declare local variables
--// exportstring( string )
--// returns a "Lua" portable version of the string
local function exportstring( s )
	return string.format("%q", s)
end

--// The Save Function
function table.save(  tbl,filename )
	local charS,charE = "   ","\n"
	local file,err = io.open( filename, "wb" )
	if err then return err end

	-- initiate variables for save procedure
	local tables,lookup = { tbl },{ [tbl] = 1 }
	file:write( "return {"..charE )

	for idx,t in ipairs( tables ) do
		file:write( "-- Table: {"..idx.."}"..charE )
		file:write( "{"..charE )
		local thandled = {}

		for i,v in ipairs( t ) do
			thandled[i] = true
			local stype = type( v )
			-- only handle value
			if stype == "table" then
				if not lookup[v] then
					table.insert( tables, v )
					lookup[v] = #tables
				end
				file:write( charS.."{"..lookup[v].."},"..charE )
			elseif stype == "string" then
				file:write(  charS..exportstring( v )..","..charE )
			elseif stype == "number" then
				file:write(  charS..tostring( v )..","..charE )
			end
		end

		for i,v in pairs( t ) do
			-- escape handled values
			if (not thandled[i]) then
			
				local str = ""
				local stype = type( i )
				-- handle index
				if stype == "table" then
					if not lookup[i] then
						table.insert( tables,i )
						lookup[i] = #tables
					end
					str = charS.."[{"..lookup[i].."}]="
				elseif stype == "string" then
					str = charS.."["..exportstring( i ).."]="
				elseif stype == "number" then
					str = charS.."["..tostring( i ).."]="
				end
			
				if str ~= "" then
					stype = type( v )
					-- handle value
					if stype == "table" then
						if not lookup[v] then
							table.insert( tables,v )
							lookup[v] = #tables
						end
						file:write( str.."{"..lookup[v].."},"..charE )
					elseif stype == "string" then
						file:write( str..exportstring( v )..","..charE )
					elseif stype == "number" then
						file:write( str..tostring( v )..","..charE )
					end
				end
			end
		end
		file:write( "},"..charE )
	end
	file:write( "}" )
	file:close()
end

--// The Load Function
function table.load( sfile )
	local ftables,err = loadfile( sfile )
	if err then return _,err end
	local tables = ftables()
	for idx = 1,#tables do
		local tolinki = {}
		for i,v in pairs( tables[idx] ) do
			if type( v ) == "table" then
				tables[idx][i] = tables[v[1]]
			end
			if type( i ) == "table" and tables[i[1]] then
				table.insert( tolinki,{ i,tables[i[1]] } )
			end
		end
		-- link indices
		for _,v in ipairs( tolinki ) do
			tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
		end
	end
	return tables[1]
end