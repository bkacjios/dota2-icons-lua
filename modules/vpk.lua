
require("modules.string")
require("modules.table")

local lfs = require("lfs")
local crc32 = require("modules.crc32")
local struct = require("struct")

local band = bit.band
local error = error
local pairs = pairs
local assert = assert
local setmetatable = setmetatable
local collectgarbage = collectgarbage

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

local print = print
local printTable = table.Print

module("modules.vpk")

local VPK = {}
VPK.__index = VPK

local VPKFile = {}
VPKFile.__index = VPKFile

function new()
	return setmetatable({
		signature = 0x55aa1234,
		version = 1,
		tree_length = 0,
		header_length = 4*3,
		tree = {},
		directory = {},
		vpk_path = nil, -- Gets set if saved
	}, VPK)
end

function load(path)
	local pak = setmetatable({
		signature = 0,
		version = 0,
		tree_length = 0,
		header_length = 0,
		tree = {},
		directory = {},
		vpk_path = path,
	}, VPK)
	pak:readTree()
	return pak
end

function VPK:readHeader()
	local f = assert(open(self.vpk_path, "rb"))

	self.signature, self.version, self.tree_length = struct.unpack("III", f:read(3*4))

	-- Original format - headerless
	if self.signature ~= 0x55aa1234 then
		self.signature = 0
		self.version = 0
		self.tree_length = 0
	-- Version 1
	elseif self.version == 1 then
		self.header_length = 4*3
	elseif version == 2 then
		self.embed_chunk_length,
		self.chunk_hashes_length,
		self.self_hashes_length,
		self.signature_length = struct.unpack("IIII", f:read(4*4))
		self.header_length = 4*7
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
	f:seek("set", self.header_length)

	while true do
		if self.version > 0 and f:seek() > self.tree_length + self.header_length then
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

				local metadata = {struct.unpack("IHHII", f:read(16))}

				if struct.unpack("H", f:read(2)) ~= 0xffff then
					error("Error while parsing index")
				end

				if metadata[3] == 0x7fff then
					metadata[4] = metadata[4] + self.header_length + self.tree_length
				end

				insert(metadata, 1, f:read(metadata[2]))

				if not self.tree[ext] then
					self.tree[ext] = {}
				end
				if not self.tree[ext][path] then
					self.tree[ext][path] = {}
				end
				if not self.tree[ext][path][name] then
					self.tree[ext][path][name] = metadata
				end

				local filepath = format("%s%s.%s", path, name, ext)
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
	local tree_length = 0
	for ext in pairs(self.tree) do
		tree_length = tree_length + len(ext) + 2
		for relpath in pairs(self.tree[ext]) do
			tree_length = tree_length + len(relpath) + 2
			for filename,filepath in pairs(self.tree[ext][relpath]) do
				tree_length = tree_length + len(filename) + 1 + 18
			end
		end
	end
	return tree_length + 1
end

function VPK:save(outFile)
	self.tree_length = self:calculateTreeLength()

	local f = assert(open(outFile, "wb"))

	f:write(struct.pack("III", self.signature, self.version, self.tree_length))

	self.header_length = f:seek()

	local data_offset = self.header_length + self.tree_length

	for ext in pairs(self.tree) do
		f:write(ext .. "\0")

		for relpath in pairs(self.tree[ext]) do
			f:write(relpath .. "\0")

			for filename,filepath in pairs(self.tree[ext][relpath]) do
				f:write(filename .. "\0")

				local metadata_offset = f:seek()
				local file_offset = data_offset
				local real_filename = format("%s.%s", filename, ext)
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
				local file_length = f:seek() - file_offset
				f:seek("set", metadata_offset)

				f:write(struct.pack("IHHIIH",	band(checksum, 0xFFffFFff),
												0,
												0x7fff,
												file_offset - self.tree_length - self.header_length,
												file_length,
												0xffff
												))
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
		preload = metadata[1],
		crc32 = metadata[2],
		preload_length = metadata[3],
		archive_index = metadata[4],
		archive_offset = metadata[5],
		file_length = metadata[6],
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

	if metadata.preload ~= "" then
		metadata.preload = "..."
	end

	metadata.length = metadata.preload_length + metadata.file_length
	metadata.offset = 0

	if metadata.file_length == 0 then
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

		if length == 0 or self.offset >= self.length then
			return
		end

		data = ""

		if self.offset <= self.preload_length then
			data = data .. sub(self.preload, self.offset, (length > -1 and self.offset + length or nil))
			self.offset = self.offset + len(data)
			if length > 0 then
				length = max(length - len(data), 0)
			end
		end

		if self.file_length > 0 and self.offset >= self.preload_length then
			left = self.file_length - (self.offset - self.preload_length)
			readlen = length == -1 and left or min(left, length)
			data = data .. self.archive:read(readlen)
			self.offset = self.offset + readlen
		end

		return data
	end
end

function VPKFile:readAll()
	local pos = self.archive:seek()

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
	self.archive:seek("set", self.archive_offset)

	local checksum = 0
	local chunk

	while true do
		chunk = self:read(1024)
		if not chunk then break end
		checksum = crc32(chunk, nil, checksum)
	end

	self.archive:seek("set",pos)

	return struct.unpack("I",struct.pack("I", checksum)) == self.crc32
end