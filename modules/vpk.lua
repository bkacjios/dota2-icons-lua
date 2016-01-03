require("string.util")

local lfs = require("lfs")
local ffi = require("ffi")
local crc32 = require("crc32")

local error = error
local pairs = pairs
local assert = assert
local setmetatable = setmetatable
local tonumber = tonumber

local open = io.open
local insert = table.insert
local getn = table.getn
local len = string.len
local format = string.format
local find = string.find
local sub = string.sub
local gsub = string.gsub
local max = math.max
local min = math.min
local concat = table.concat
local StripExtension = string.StripExtension
local ExtensionFromFile = string.ExtensionFromFile
local match = string.match
local type = type
local unpack = unpack

module("vpk")

ffi.cdef[[
#pragma pack(1)

typedef struct {
	// A 32bit CRC of the file's data.
	unsigned int crc32;

	// The number of bytes contained in the index file.
	unsigned short preload_size;

	// A zero based index of the archive this file's data is contained in.
	// If 0x7fff, the data follows the directory.
	unsigned short archive_index;

	// If ArchiveIndex is 0x7fff, the offset of the file data relative to the end of the directory (see the header for more details).
	// Otherwise, the offset of the data from the start of the specified archive.
	unsigned int archive_offset;

	// If zero, the entire file is stored in the preload data.
	// Otherwise, the number of bytes stored starting at EntryOffset.
	unsigned int file_size;

	// End of entry
	unsigned short terminator;

} VPKDirectoryEntry;

typedef struct
{
	unsigned int signature;
	unsigned int version;

	// The size, in bytes, of the directory tree
	unsigned int tree_size;
} VPKHeader;

struct
{
	// How many bytes of file content are stored in this VPK file (0 in CSGO)
	unsigned int filedata_size;
 
	// The size, in bytes, of the section containing MD5 checksums for external archive content
	unsigned int archiveMD5_size;
 
	// The size, in bytes, of the section containing MD5 checksums for content in this file (should always be 48)
	unsigned int otherMD5_size;
 
	// The size, in bytes, of the section containing the public key and signature. This is either 0 (CSGO & The Ship) or 296 (HL2, HL2:DM, HL2:EP1, HL2:EP2, HL2:LC, TF2, DOD:S & CS:S)
	unsigned int signature_size;
} VPKHeaderV2;
]]

local VPK = {}
VPK.__index = VPK

local VPKFile = {}
VPKFile.__index = VPKFile

function new()
	return setmetatable({
		signature = 0x55aa1234,
		version = 1,
		tree_size = 0,
		header_size = ffi.sizeof("VPKHeader"),
		tree = {},
		directory = {},
		vpk_path = nil, -- Gets set if saved
	}, VPK)
end

function load(path)
	local pak = setmetatable({
		signature = 0x55aa1234,
		version = 1,
		tree_size = 0,
		header_size = ffi.sizeof("VPKHeader"),
		tree = {},
		directory = {},
		vpk_path = path,
	}, VPK)
	pak:readTree()
	return pak
end

function VPK:readHeader()
	local f = assert(open(self.vpk_path, "rb"))

	local size = ffi.sizeof("VPKHeader")
	local header = ffi.cast("VPKHeader*", f:read(size))

	self.signature = header.signature
	self.version = header.version
	self.tree_size = header.tree_size

	-- Original format - headerless
	if self.signature ~= 0x55aa1234 then
		self.signature = 0
		self.version = 0
		self.tree_size = 0
	-- Version 1
	elseif self.version == 1 then
		self.header_size = size
	elseif version == 2 then
		local size2 = ffi.sizeof("VPKHeaderV2")
		local extended = ffi.cast("VPKHeaderV2*", f:read(size2))

		-- TODO: Handle the extended V2 header info
		self.header_size = size + size2
	else
		return error("Unsupported VPK version: " .. self.version)
	end
	f:close()
end

function VPK:getTree()
	return self.tree
end

function VPK:readTree()
	self:readHeader()

	self.tree = {}

	local f = assert(open(self.vpk_path, "rb"))

	f:seek("set", self.header_size)

	while true do
		if self.version > 0 and f:seek() > self.tree_size + self.header_size then
			return error("Error parsing archive tree (header out of bounds)")
		end

		local ext = self:_read_tree(f)

		if ext == '' then break end

		while true do
			local path = self:_read_tree(f)

			if path == '' then break end

			if path == ' ' then
				path = ''
			else
				path = path .. '/'
			end

			while true do
				local name = self:_read_tree(f)

				if name == "" then break end

				local data = ffi.cast("VPKDirectoryEntry*", f:read(ffi.sizeof("VPKDirectoryEntry")))

				if data.archive_index == 0x7fff then
					data.archive_offset = data.archive_offset + self.header_size + self.tree_size
				end

				local metadata = {
					preload_data = f:read(data.preload_size),
					crc32 = data.crc32,
					preload_size = data.preload_size,
					archive_index = data.archive_index,
					archive_offset = data.archive_offset,
					file_size = data.file_size,
				}

				if not self.tree[ext] then
					self.tree[ext] = {}
				end
				if not self.tree[ext][path] then
					self.tree[ext][path] = {}
				end
				if not self.tree[ext][path][name] then
					self.tree[ext][path][name] = metadata
				end

				local filepath = path .. name .. (ext ~= " " and ("." .. ext) or "")

				self.directory[filepath] = metadata
			end
		end
	end
	f:close()
end

function VPK:_read_tree(f)
	local data = {}
	local chunk

	while true do
		chunk = f:read(64)
		if not chunk then break end

		local pos = find(chunk,"\0")
		if pos then
			insert(data, sub(chunk,1,pos-1))
			f:seek("set", f:seek()-(len(chunk) - pos))
			break
		end
		insert(data, chunk)
	end
	return concat(data)
end

function VPK:addFiles(root, overwrite, vpk_path)
	overwrite = overwrite or false
	vpk_path = vpk_path or root

	local relative_path = vpk_path:gsub(root, "")

	for file in lfs.dir(vpk_path) do
		if file ~= "." and file ~= ".." then
			local fullpath = vpk_path .. (vpk_path ~= " " and "/" or "") .. file

			local mode = lfs.attributes(fullpath, "mode")

			if mode == "directory" then
				self:addFiles(root, overwrite, fullpath)
			elseif mode == "file" then
				local filename = StripExtension(file)
				local ext = ExtensionFromFile(file)

				if not ext then ext = " " end

				local relative_path = vpk_path:gsub(match(vpk_path, root .. "/?"),"")
				if relative_path == "" then relative_path = " " end

				if not self.tree[ext] then
					self.tree[ext] = {}
				end
				if not self.tree[ext][relative_path] then
					self.tree[ext][relative_path] = {}
				end
				if not self.tree[ext][relative_path][filename] or overwrite then
					self.tree[ext][relative_path][filename] = fullpath
				end
			end
		end
	end
end

function VPK:calculateTreeLength()
	local tree_size = 0
	for ext in pairs(self.tree) do
		tree_size = tree_size + len(ext) + 2
		for relpath in pairs(self.tree[ext]) do
			tree_size = tree_size + len(relpath) + 2
			for filename,filepath in pairs(self.tree[ext][relpath]) do
				tree_size = tree_size + len(filename) + 1 + 18
			end
		end
	end
	return tree_size + 1
end

function VPK:save(outFile)
	self.tree_size = self:calculateTreeLength()

	local f = assert(open(outFile, "wb"))

	local header = ffi.new("VPKHeader", self.signature, self.version, self.tree_size)

	f:write(ffi.string(header, ffi.sizeof(header)))

	self.header_size = f:seek()

	local data_offset = self.header_size + self.tree_size

	for ext in pairs(self.tree) do
		f:write(ext .. "\0")

		for relpath in pairs(self.tree[ext]) do
			f:write(relpath .. "\0")

			for filename,filepath in pairs(self.tree[ext][relpath]) do
				f:write(filename .. "\0")

				local metadata_offset = f:seek()
				local file_offset = data_offset

				local checksum = 0
				f:seek("set", data_offset)

				local pakFile = assert(open(filepath, "rb"))

				while true do
					local chunk = pakFile:read(1024)
					if not chunk then break end
					checksum = crc32(chunk, nil, checksum)
					f:write(chunk)
				end

				pakFile:close()

				data_offset = f:seek()
				local file_size = f:seek() - file_offset
				f:seek("set", metadata_offset)

				local entry = ffi.new("VPKDirectoryEntry", checksum, 0, 0x7fff, file_offset - self.tree_size - self.header_size, file_size, 0xffff)

				f:write(ffi.string(entry, ffi.sizeof(entry)))
			end
			f:write("\0")
		end
		f:write("\0")
	end
	f:write("\0")
	f:close()

	self.vpk_path = outFile
	self:readTree()
end

function VPK:getFileMetadata(path)
	local metadata = self.directory[path]

	if not metadata then
		return false, format("file not found in VPK tree (%s) ", path)
	end

	return {
		preload_data = metadata.preload_data,
		crc32 = metadata.crc32,
		preload_size = metadata.preload_size,
		archive_index = metadata.archive_index,
		archive_offset = metadata.archive_offset,
		file_size = metadata.file_size,
	}
end

function VPK:search(pattern)
	local matched = {}
	for path,metadata in pairs(self.directory) do
		if find(path,pattern) ~= nil then
			insert(matched, path)
		end
	end
	return matched
end

function VPK:getFile(path)
	local metadata, err = self:getFileMetadata(path)

	if not metadata then return false, err end

	metadata.vpk = self
	metadata.offset = 0

	if metadata.file_size <= 0 then
		return false, format("file has no length (%s)", path)
	end

	local path = self.vpk_path
	if metadata.archive_index ~= 0x7fff then
		path = gsub(path, "dir.", format("%03d.", metadata.archive_index))
	end

	local f, err = open(path, "rb")

	if not f then return false, err end

	metadata.archive = f
	metadata.archive:seek("set", metadata.archive_offset)

	return setmetatable(metadata,VPKFile)
end

function VPK:hasFile(path)
	return self.directory[path] and true or false
end

--------------------------------
-- VPK FILE METATABLE METHODS --
--------------------------------

function VPKFile:save(path)
	local pos = self:seek()
	self:seek("set")

	local f, err = open(path, "wb")

	if not f then return false, err end

	while true do
		local chunk = self:read(1024)
		if not chunk then break end
		f:write(chunk)
	end

	f:close()

	self:seek("set",pos)
	return true
end

function VPKFile:seek(whence, offset)
	whence = whence or "cur"
	offset = offset or 0
	if whence == "cur" then
		self.offset = self.offset + offset
	elseif whence == "set" then
		self.offset = offset
	elseif whence == "end" then
		self.offset = self.file_size + offset
	end

	self.archive:seek("set", self.archive_offset + self.offset)
	return self.offset
end

function VPKFile:lines()
	return function()
		return self:read("*line") 
	end
end

do

local function read(file, buffer, length)
	local left = 0
	local readlen = 0

	if file.offset < file.preload_size then
		left = file.preload_size - file.offset
		readlen = min(left, length)
		insert(buffer, sub(file.preload_data, file.offset, file.offset + readlen))
		file.offset = file.offset + readlen
		length = max(length - readlen, 0)
	end

	if file.file_size > 0 and file.offset >= file.preload_size and file.offset < file.file_size then
		left = file.file_size - (file.offset - file.preload_size)
		readlen = min(left, length)
		insert(buffer, file.archive:read(readlen))
		file.offset = file.offset + readlen
	end

	return readlen
end

local function readLine(file, buffer)
	local buff = {}
	local startpos, endpos, readpos, done, raw

	while true do
		readpos = file:seek()

		if read(file, buff, 1024) <= 0 then return end

		raw = concat(buff)
		startpos, endpos = raw:find("\r?\n")

		if startpos and endpos then
			raw = sub(raw, 1, startpos-1)
			file.offset = readpos + endpos
			done = true
		end

		insert(buffer,raw)

		if done then break end
	end
end

function VPKFile:read(...)
	local args = {...}

	if getn(args) <= 0 then
		local buffer = {}
		readLine(self, buffer)
		return concat(buffer)
	end

	local returns = {}

	for n,arg in pairs(args) do
		local buffer = {}
		if type(arg) == "string" then
			if arg:sub(1,2) == "*a" then
				while read(self, buffer, 1024) > 0 do end
			elseif arg:sub(1,2) == "*l" then
				readLine(self, buffer)
			else
				return error(format("bad argument #%i to 'read' (invalid format)",n))
			end
		elseif arg > 0 and self.offset < self.preload_size + self.file_size then
			read(self, buffer, arg)
		end
		if getn(buffer) > 0 then
			insert(returns, concat(buffer))
		end
	end

	if getn(returns) > 0 then
		return unpack(returns)
	end

	return nil
end

end

function VPKFile:close()
	return self.archive:close()
end

function VPKFile:verify()
	local pos = self:seek()
	self:seek("set")

	local checksum = 0
	local chunk

	while true do
		chunk = self:read(1024)
		if not chunk then break end
		checksum = crc32(chunk, nil, checksum)
	end

	self:seek("set", pos)

	return tonumber(ffi.cast("unsigned int", checksum)) == self.crc32
end