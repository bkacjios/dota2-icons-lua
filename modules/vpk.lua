
require("modules.string")
require("modules.table")

local lfs = require("lfs")
local ffi = require("ffi")
local crc32 = require("modules.crc32")

local error = error
local pairs = pairs
local assert = assert
local setmetatable = setmetatable
local tonumber = tonumber

local open = io.open
local insert = table.insert
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

module(...)

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
		header_size = 4*3,
		tree = {},
		directory = {},
		vpk_path = nil, -- Gets set if saved
	}, VPK)
end

function load(path)
	local pak = setmetatable({
		signature = 0,
		version = 0,
		tree_size = 0,
		header_size = 0,
		tree = {},
		directory = {},
		vpk_path = path,
	}, VPK)
	pak:readTree()
	return pak
end

function VPK:readHeader()
	local f = assert(open(self.vpk_path, "rb"))

	local header = ffi.cast("VPKHeader*", f:read(3*4))

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
		self.header_size = 4*3
	elseif version == 2 then
		local extended = ffi.cast("VPKHeaderV2*", f:read(4*4))

		-- TODO: Handle the extended V2 header info
		self.header_size = 4*7
	else
		error("Unsupported VPK version: " .. self.version)
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
			error("Error parsing index (out of bounds)")
		end

		local ext = self:_read_tree(f)

		if ext == '' then break end

		while true do
			local path = self:_read_tree(f)

			if path == '' then break end

			if path ~= ' ' then
				path = path .. '/'
			else
				path = ''
			end

			while true do
				local name = self:_read_tree(f)

				if name == "" then break end

				local metadata = ffi.cast("VPKDirectoryEntry*", f:read(18))

				if metadata.archive_index == 0x7fff then
					metadata.archive_offset = metadata.archive_offset + self.header_size + self.tree_size
				end

				metadata = {
					crc32 = metadata.crc32,
					preload_size = metadata.preload_size,
					archive_index = metadata.archive_index,
					archive_offset = metadata.archive_offset,
					file_size = metadata.file_size,
				}

				metadata.preload_data = f:read(metadata.preload_size)

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
	local buf = {}
	local chunk

	while true do
		chunk = f:read(64)

		if not chunk then break end

		local pos = find(chunk,"\0")

		if pos then
			insert(buf, sub(chunk,1,pos-1))
			f:seek("set", f:seek()-(len(chunk) - pos))
			break
		end

		insert(buf, chunk)
	end
	return concat(buf)
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
				if relative_path == "" then relative_path = " " end -- volvo

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

	local header = ffi.new("VPKHeader")
	header.signature = self.signature
	header.version = self.version
	header.tree_size = self.tree_size

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
				local real_filename = (ext ~= " " and format("%s.%s", filename, ext) or filename)

				local checksum = 0
				f:seek("set", data_offset)

				local pakFile = assert(open(filepath, "rb"))

				while true do
					local chunk = pakFile:read(1024)
					if not chunk then break end
					checksum = crc32(chunk, nil, checksum)
					f:write(chunk)
				end

				data_offset = f:seek()
				local file_size = f:seek() - file_offset
				f:seek("set", metadata_offset)

				local entry = ffi.new("VPKDirectoryEntry")
				entry.crc32 = checksum
				entry.preload_size = 0
				entry.archive_index = 0x7fff
				entry.archive_offset = file_offset - self.tree_size - self.header_size
				entry.file_size = file_size
				entry.terminator = 0xffff

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
		return false, format("File (%q) not found in VPK tree", path)
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

	if metadata.file_size == 0 then
		return false, format("File (%q) has a length of zero", path)
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
	local pos = self.archive:seek()

	self.offset = 0
	self.archive:seek("set", self.archive_offset)

	local f = assert(open(path, "wb"))

	while true do
		local chunk = self:read(1024)
		if not chunk then break end
		f:write(chunk)
	end

	f:close()

	self.archive:seek("set",pos)
end

do
	local left = 0
	local readlen = 0
	local data = ""

	function VPKFile:read(length)
		length = length or -1

		if length == 0 or self.offset >= self.preload_size + self.file_size then
			return
		end

		data = ""

		if self.offset <= self.preload_size then
			data = data .. sub(self.preload_data, self.offset, (length > -1 and self.offset + length or nil))
			self.offset = self.offset + len(data)
			if length > 0 then
				length = max(length - len(data), 0)
			end
		end

		if self.file_size > 0 and self.offset >= self.preload_size then
			left = self.file_size - (self.offset - self.preload_size)
			readlen = length == -1 and left or min(left, length)
			data = data .. self.archive:read(readlen)
			self.offset = self.offset + readlen
		end

		return data
	end
end

function VPKFile:readAll()
	local pos = self.archive:seek()

	self.offset = 0
	self.archive:seek("set", self.archive_offset)

	local data = {}
	local chunk

	while true do
		chunk = self:read(1024)
		if not chunk then break end
		insert(data,chunk)
	end

	self.archive:seek("set",pos)

	return concat(data)
end

function VPKFile:close()
	return self.archive:close()
end

function VPKFile:verify()
	local pos = self.archive:seek()

	self.offset = 0
	self.archive:seek("set", self.archive_offset)

	local checksum = 0
	local chunk

	while true do
		chunk = self:read(1024)
		if not chunk then break end
		checksum = crc32(chunk, nil, checksum)
	end

	self.archive:seek("set",pos)

	return tonumber(ffi.cast("unsigned int", checksum)) == self.crc32
end