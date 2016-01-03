function string.trim(self, char)
    char = char or "%s"
    return (self:gsub("^"..char.."*(.-)"..char.."*$", "%1" ))
end

function string.GetPathFromFilename(path)
	return path:match( "^(.*[/\\])[^/\\]-$" ) or ""
end

local pattern_escape_replacements = {
	["("] = "%(",
	[")"] = "%)",
	["."] = "%.",
	["%"] = "%%",
	["+"] = "%+",
	["-"] = "%-",
	["*"] = "%*",
	["?"] = "%?",
	["["] = "%[",
	["]"] = "%]",
	["^"] = "%^",
	["$"] = "%$",
	["\0"] = "%z"
}

local totable = string.ToTable
local string_sub = string.sub
local string_gsub = string.gsub
local string_gmatch = string.gmatch
function string.split(str, separator, withpattern)
	if (separator == "") then return totable( str ) end
	 
	local ret = {}
	local index,lastPosition = 1,1
	 
	-- Escape all magic characters in separator
	if not withpattern then separator = separator:gsub( ".", pattern_escape_replacements ) end
	 
	-- Find the parts
	for startPosition,endPosition in string_gmatch( str, "()" .. separator.."()" ) do
		ret[index] = string_sub( str, lastPosition, startPosition-1)
		index = index + 1
		 
		-- Keep track of the position
		lastPosition = endPosition
	end
	 
	-- Add last part by using the position we stored
	ret[index] = string_sub( str, lastPosition)
	return ret
end

function string.ExtensionFromFile( path )
	return path:match( "%.([^%.]+)$" )
end

function string.StripExtension( path )
	local i = path:match( ".+()%.%w+$" )
	if ( i ) then return path:sub(1, i-1) end
	return path
end