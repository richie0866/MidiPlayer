-- Start of Rostruct v0.1.4-alpha

--[[
	Originally RuntimeLib.lua supplied by roblox-ts, modified for use when bundled.
]]

local TS = {
	_G = {};
}

setmetatable(TS, {
	__index = function(self, k)
		if k == "Promise" then
			self.Promise = TS.initialize("packages", "Promise")
			return self.Promise
		end
	end
})

-- Runtime classes
local FilePtr
do
	FilePtr = {}
	FilePtr.__index = FilePtr

	function FilePtr.new(path)
		local fileName, slash = string.match(path, "([^/]+)(/*)$")
		return setmetatable({
			name = fileName,
			path = string.sub(path, 1, -#fileName - (slash ~= "" and 2 or 1)),
		}, FilePtr)
	end

	function FilePtr:__index(k)
		if k == "Parent" then
			return FilePtr.new(self.path)
		end
	end

end

local Module
do
	Module = {}
	Module.__index = Module

	function Module.new(path, name, func)
		return setmetatable({
			-- Init files are representations of their parent directory,
			-- so if it's an init file, we trim the "/init.lua" off of
			-- the file path.
			path = name ~= "init"
				and path
				or  FilePtr.new(path).path,
			name = name,
			func = func,
			data = nil;
		}, Module)
	end

	function Module:__index(k)
		if Module[k] then
			return Module[k]
		elseif k == "Parent" then
			return FilePtr.new(self.path)
		elseif k == "Name" then
			return self.path
		end
	end

	function Module:require()
		if self.func then
			self.data = self.func()
			self.func = nil
		end
		return self.data
	end

	function Module:GetFullName()
		return self.path
	end

end

local Symbol
do
	Symbol = {}
	Symbol.__index = Symbol
	setmetatable(
		Symbol,
		{
			__call = function(_, description)
				local self = setmetatable({}, Symbol)
				self.description = "Symbol(" .. (description or "") .. ")"
				return self
			end,
		}
	)

	local symbolRegistry = setmetatable(
		{},
		{
			__index = function(self, k)
				self[k] = Symbol(k)
				return self[k]
			end,
		}
	)

	function Symbol:toString()
		return self.description
	end

	Symbol.__tostring = Symbol.toString

	-- Symbol.for
	function Symbol.getFor(key)
		return symbolRegistry[key]
	end

	function Symbol.keyFor(goalSymbol)
		for key, symbol in pairs(symbolRegistry) do
			if symbol == goalSymbol then
				return key
			end
		end
	end
end

TS.Symbol = Symbol
TS.Symbol_iterator = Symbol("Symbol.iterator")

-- Provides a way to attribute modules to files.
local modulesByPath = {}
local modulesByName = {}

-- Bundle compatibility
function TS.register(path, name, func)
	local module = Module.new(path, name, func)
	modulesByPath[path] = module
	modulesByName[name] = module
	return module
end

function TS.get(path)
	return modulesByPath[path]
end

function TS.initialize(...)
	local symbol = setmetatable({}, {__tostring = function()
		return "root"
	end})
	local caller = TS.register(symbol, symbol)
	return TS.import(caller, { path = "out/" }, ...)
end

-- module resolution
function TS.getModule(_object, _moduleName)
	return error("TS.getModule is not supported", 2)
end

-- This is a hash which TS.import uses as a kind of linked-list-like history of [Script who Loaded] -> Library
local currentlyLoading = {}
local registeredLibraries = {}

function TS.import(caller, parentPtr, ...)
	-- Because 'Module.Parent' returns a FilePtr, the module handles the indexing.
	-- Getting 'parentPtr.path' will return the result of FilePtr.Parent.Parent...
	local modulePath = parentPtr.path .. table.concat({...}, "/") .. ".lua"
	local module = assert(
		modulesByPath[modulePath] or modulesByPath[parentPtr.path .. table.concat({...}, "/") .. "/init.lua"],
		"No module exists at path '" .. modulePath .. "'"
	)

	currentlyLoading[caller] = module

	-- Check to see if a case like this occurs:
	-- module -> Module1 -> Module2 -> module

	-- WHERE currentlyLoading[module] is Module1
	-- and currentlyLoading[Module1] is Module2
	-- and currentlyLoading[Module2] is module

	local currentModule = module
	local depth = 0

	while currentModule do
		depth = depth + 1
		currentModule = currentlyLoading[currentModule]

		if currentModule == module then
			local str = currentModule.name -- Get the string traceback

			for _ = 1, depth do
				currentModule = currentlyLoading[currentModule]
				str ..= " => " .. currentModule.name
			end

			error("Failed to import! Detected a circular dependency chain: " .. str, 2)
		end
	end

	if not registeredLibraries[module] then
		if TS._G[module] then
			error(
				"Invalid module access! Do you have two TS runtimes trying to import this? " .. module.path,
				2
			)
		end

		TS._G[module] = TS
		registeredLibraries[module] = true -- register as already loaded for subsequent calls
	end

	local data = module:require()

	if currentlyLoading[caller] == module then -- Thread-safe cleanup!
		currentlyLoading[caller] = nil
	end

	return data
end

-- general utility functions
function TS.async(callback)
	local Promise = TS.Promise
	return function(...)
		local n = select("#", ...)
		local args = { ... }
		return Promise.new(function(resolve, reject)
			coroutine.wrap(function()
				local ok, result = pcall(callback, unpack(args, 1, n))
				if ok then
					resolve(result)
				else
					reject(result)
				end
			end)()
		end)
	end
end

function TS.await(promise)
	local Promise = TS.Promise
	if not Promise.is(promise) then
		return promise
	end

	local status, value = promise:awaitStatus()
	if status == Promise.Status.Resolved then
		return value
	elseif status == Promise.Status.Rejected then
		error(value, 2)
	else
		error("The awaited Promise was cancelled", 2)
	end
end

-- out/core/Reconciler/init.lua:
TS.register("out/core/Reconciler/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/core/Reconciler/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	--[[
		* File: index.ts
		* File Created: Friday, 4th June 2021 1:52:37 am
		* Author: richard
		* Description: Transforms files into Roblox objects.
	]]
	local transformDirectory = TS.import(script, script, "transformDirectory")
	local VirtualScript = TS.import(script, script.Parent, "VirtualScript").VirtualScript
	local globals = TS.import(script, script.Parent.Parent, "globals").globals
	-- * Class used to transform files into a Roblox instance tree.
	local Reconciler
	do
		Reconciler = setmetatable({}, {
			__tostring = function()
				return "Reconciler"
			end,
		})
		Reconciler.__index = Reconciler
		function Reconciler.new(...)
			local self = setmetatable({}, Reconciler)
			self:constructor(...)
			return self
		end
		function Reconciler:constructor(target)
			self.target = target
			local _0 = globals.currentScope
			globals.currentScope += 1
			self.scope = _0
		end
		function Reconciler:reify(parent)
			local directory = transformDirectory(self.target, self.scope)
			directory.Parent = parent
			return directory
		end
		function Reconciler:deployWorker()
			local runtimeJobs = {}
			local virtualScripts = VirtualScript:getVirtualScriptsOfScope(self.scope)
			local _0 = virtualScripts
			assert(_0, "Cannot deploy project with no scripts!")
			for _, v in ipairs(virtualScripts) do
				if v.instance:IsA("LocalScript") then
					local _1 = runtimeJobs
					local _2 = v:deferExecutor():andThen(function()
						return v.instance
					end)
					-- ▼ Array.push ▼
					_1[#_1 + 1] = _2
					-- ▲ Array.push ▲
				end
			end
			-- Define as constant because the typing for 'Promise.all' is faulty
			local runtimeWorker = TS.Promise.all(runtimeJobs)
			return runtimeWorker
		end
	end
	return {
		Reconciler = Reconciler,
	}

    -- End of init

end)

-- out/core/Reconciler/transformDirectory.lua:
TS.register("out/core/Reconciler/transformDirectory.lua", "transformDirectory", function()

    -- Setup
    local script = TS.get("out/core/Reconciler/transformDirectory.lua")

    -- Start of transformDirectory

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	--[[
		* File: transformDirectory.ts
		* File Created: Friday, 4th June 2021 12:36:38 am
		* Author: richard
		* Description: Turns a folder directory into a Roblox instance.
	]]
	local Make = TS.import(script, script.Parent.Parent.Parent, "packages", "make")
	local HttpService = TS.import(script, script.Parent.Parent.Parent, "packages", "services").HttpService
	local _0 = TS.import(script, script.Parent.Parent.Parent, "utils", "filesystem")
	local Directory = _0.Directory
	local File = _0.File
	local transformFile = TS.import(script, script.Parent, "transformFile")
	-- * A list of file names that should not become files.
	local RESERVED_NAMES = {
		["init.lua"] = true,
		["init.server.lua"] = true,
		["init.client.lua"] = true,
		["init.meta.json"] = true,
	}
	-- * Interface for `init.meta.json` data.
	--[[
		*
		* Creates an instance from the given metadata.
		* @param metadata The init.meta.json data.
		* @param name The name of the instance.
		* @returns A new instance.
	]]
	local function makeFromMetadata(metadata, name)
		-- Create the instance first to ensure 'className' is always
		-- prioritized, even if there are no properties set.
		local instance = Make(metadata.className or "Folder", {
			Name = name,
		})
		-- Currently, only primitive types can be defined.
		if metadata.properties then
			for key, value in pairs(metadata.properties) do
				instance[key] = value
			end
		end
		return instance
	end
	--[[
		*
		* Creates an Instance for the given folder.
		* [Some files](https://rojo.space/docs/6.x/sync-details/#scripts) can modify the class and properties during creation.
		* @param dir The directory to make an Instance from.
		* @param parent Optional parent of the Instance.
		* @returns THe instance created for the folder.
	]]
	local function transformDirectory(dir, scope)
		local instance
		-- Check if the directory contains a special init file.
		-- https://rojo.space/docs/6.x/sync-details/#scripts
		-- https://rojo.space/docs/6.x/sync-details/#meta-files
		local init = dir.locateFiles("init.lua", "init.server.lua", "init.client.lua", "init.meta.json")
		-- Turns the directory into a script instance using the init file.
		local _1 = init
		if _1 ~= nil then
			_1 = _1.extension
		end
		if _1 == "lua" then
			instance = transformFile(init, scope, dir.name)
		else
			local _2 = init
			if _2 ~= nil then
				_2 = _2.extension
			end
			if _2 == "json" then
				instance = makeFromMetadata(HttpService:JSONDecode(readfile(init.location)), dir.name)
			else
				instance = Make("Folder", {
					Name = dir.name,
				})
			end
		end
		-- Scan the file to descend the instance tree.
		for _, f in ipairs(listfiles(dir.location)) do
			local fileName = (string.match(f, "([^/]+)$"))
			-- Make sure the file is not reserved for special use
			local _2 = RESERVED_NAMES
			local _3 = fileName
			if _2[_3] ~= nil then
				continue
			end
			if isfile(f) then
				local obj = transformFile(File(f, dir.origin), scope)
				if obj then
					obj.Parent = instance
				end
			else
				transformDirectory(Directory(f, dir.origin), scope).Parent = instance
			end
		end
		-- An instance definitely exists! if there is no special file present, the
		-- folder is made (see 'else' condition above).
		return instance
	end
	return transformDirectory

    -- End of transformDirectory

end)

-- out/core/Reconciler/transformFile.lua:
TS.register("out/core/Reconciler/transformFile.lua", "transformFile", function()

    -- Setup
    local script = TS.get("out/core/Reconciler/transformFile.lua")

    -- Start of transformFile

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	--[[
		* File: transformFile.ts
		* File Created: Thursday, 3rd June 2021 11:13:25 pm
		* Author: richard
		* Description: Turns a file into a Roblox instance.
	]]
	local generateAssetId = TS.import(script, script.Parent.Parent.Parent, "globals").generateAssetId
	local Make = TS.import(script, script.Parent.Parent.Parent, "packages", "make")
	local VirtualScript = TS.import(script, script.Parent.Parent, "VirtualScript").VirtualScript
	local HttpService = TS.import(script, script.Parent.Parent.Parent, "packages", "services").HttpService
	--[[
		*
		* Creates an Instance using the given file information.
		* If the object was a script, a reference to the file path is stored in the `Source` parameter.
		* @param file The file to make an Instance from.
		* @param name Optional name of the instance.
		* @param parent Optional parent of the Instance.
		* @returns A new Instance if possible.
	]]
	local function transformFile(file, scope, name)
		local _0 = file.extension
		repeat
			if _0 == ("lua") then
				local luaObj
				local _1 = file.type
				repeat
					if _1 == ("server.lua") then
						local _2 = {}
						local _3 = "Name"
						local _4 = name
						if _4 == nil then
							_4 = file.shortName
						end
						_2[_3] = _4
						_2.Source = file.location
						luaObj = Make("Script", _2)
						break
					end
					if _1 == ("client.lua") then
						local _2 = {}
						local _3 = "Name"
						local _4 = name
						if _4 == nil then
							_4 = file.shortName
						end
						_2[_3] = _4
						_2.Source = file.location
						luaObj = Make("LocalScript", _2)
						break
					end
					local _2 = {}
					local _3 = "Name"
					local _4 = name
					if _4 == nil then
						_4 = file.extendedName
					end
					_2[_3] = _4
					_2.Source = file.location
					luaObj = Make("ModuleScript", _2)
				until true
				VirtualScript.new(luaObj, file, scope)
				return luaObj
			end
			if _0 == ("json") then
				local _1 = {}
				local _2 = "Name"
				local _3 = name
				if _3 == nil then
					_3 = file.extendedName
				end
				_1[_2] = _3
				local jsonObj = Make("ModuleScript", _1)
				VirtualScript.new(jsonObj, file, scope):setExecutor(function()
					return HttpService:JSONDecode(readfile(file.location))
				end)
				return jsonObj
			end
			if _0 == ("txt") then
				local _1 = {}
				local _2 = "Name"
				local _3 = name
				if _3 == nil then
					_3 = file.extendedName
				end
				_1[_2] = _3
				_1.Value = readfile(file.location)
				local txtObj = Make("StringValue", _1)
				return txtObj
			end
			if _0 == ("rbxm") then
				local _1 = generateAssetId
				local _2 = "This exploit does not support rbxasset:// generation! (" .. file.location .. ")"
				assert(_1 ~= 0 and _1 == _1 and _1 ~= "" and _1, _2)
				return game:GetObjects(generateAssetId(file.location))[1]
			end
			if _0 == ("rbxmx") then
				local _1 = generateAssetId
				local _2 = "This exploit does not support rbxasset:// generation! (" .. file.location .. ")"
				assert(_1 ~= 0 and _1 == _1 and _1 ~= "" and _1, _2)
				return game:GetObjects(generateAssetId(file.location))[1]
			end
			break
		until true
	end
	return transformFile

    -- End of transformFile

end)

-- out/core/VirtualScript.lua:
TS.register("out/core/VirtualScript.lua", "VirtualScript", function()

    -- Setup
    local script = TS.get("out/core/VirtualScript.lua")

    -- Start of VirtualScript

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	--[[
		* File: VirtualScript.ts
		* File Created: Tuesday, 1st June 2021 8:58:51 pm
		* Author: richard
		* Description: Execute files as Roblox instances.
	]]
	local HttpService = TS.import(script, script.Parent.Parent, "packages", "services").HttpService
	-- * Class used to execute files in a Roblox instance context.
	local VirtualScript
	do
		VirtualScript = setmetatable({}, {
			__tostring = function()
				return "VirtualScript"
			end,
		})
		VirtualScript.__index = VirtualScript
		function VirtualScript.new(...)
			local self = setmetatable({}, VirtualScript)
			self:constructor(...)
			return self
		end
		function VirtualScript:constructor(instance, file, scope)
			self.instance = instance
			self.file = file
			self.scope = scope
			self.id = "VirtualScript-" .. HttpService:GenerateGUID(false)
			self.jobComplete = false
			local _0 = file.origin
			local _1 = "VirtualScript file must have an origin (" .. file.location .. ")"
			assert(_0 ~= "" and _0, _1)
			self.env = {
				script = instance,
				require = function(obj)
					return VirtualScript:require(obj)
				end,
				_PATH = file.location,
				_ROOT = file.origin,
			}
			-- Initialize a scope array if it does not already exist.
			local _2 = VirtualScript.virtualScriptsOfScope
			local _3 = scope
			if not (_2[_3] ~= nil) then
				local _4 = VirtualScript.virtualScriptsOfScope
				local _5 = scope
				local _6 = { self }
				-- ▼ Map.set ▼
				_4[_5] = _6
				-- ▲ Map.set ▲
			else
				local _4 = VirtualScript.virtualScriptsOfScope
				local _5 = scope
				local _6 = _4[_5]
				local _7 = self
				-- ▼ Array.push ▼
				_6[#_6 + 1] = _7
				-- ▲ Array.push ▲
			end
			-- Tracks this VirtualScript for external use.
			local _4 = VirtualScript.virtualScriptsByInstance
			local _5 = instance
			local _6 = self
			-- ▼ Map.set ▼
			_4[_5] = _6
			-- ▲ Map.set ▲
		end
		function VirtualScript:getFromInstance(obj)
			local _0 = self.virtualScriptsByInstance
			local _1 = obj
			return _0[_1]
		end
		function VirtualScript:getVirtualScriptsOfScope(scope)
			local _0 = self.virtualScriptsOfScope
			local _1 = scope
			return _0[_1]
		end
		function VirtualScript:require(obj)
			local _0 = self.virtualScriptsByInstance
			local _1 = obj
			local virtualScript = _0[_1]
			if virtualScript then
				return virtualScript:runExecutor()
			else
				return require(obj)
			end
		end
		function VirtualScript:getSource()
			return "setfenv(1, setmetatable(..., { __index = getfenv(0) }));" .. readfile(self.file.location)
		end
		function VirtualScript:setExecutor(exec)
			local _0 = self.jobComplete == false
			assert(_0, "Cannot set executor after script was executed")
			self.executor = exec
		end
		function VirtualScript:createExecutor()
			local _0 = self.executor
			if _0 ~= 0 and _0 == _0 and _0 ~= "" and _0 then
				return self.executor
			end
			local f, err = loadstring(self:getSource(), "=" .. self.file.location)
			local _1 = f
			local _2 = err
			assert(_1 ~= 0 and _1 == _1 and _1 ~= "" and _1, _2)
			self.executor = f
			return self.executor
		end
		function VirtualScript:runExecutor()
			if self.jobComplete then
				return self.result
			end
			local result = self:createExecutor()(self.env)
			-- Modules must return a value.
			if self.instance:IsA("ModuleScript") then
				local _0 = result
				local _1 = "Module '" .. self.file.location .. "' did not return any value"
				assert(_0 ~= 0 and _0 == _0 and _0 ~= "" and _0, _1)
			end
			self.jobComplete = true
			self.result = result
			return self.result
		end
		function VirtualScript:deferExecutor()
			return TS.Promise.defer(function(resolve)
				return resolve(self:runExecutor())
			end):timeout(30, "Script " .. self.file.location .. " reached execution timeout! Try not to yield the main thread in LocalScripts.")
		end
		VirtualScript.virtualScriptsByInstance = {}
		VirtualScript.virtualScriptsOfScope = {}
	end
	return {
		VirtualScript = VirtualScript,
	}

    -- End of VirtualScript

end)

-- out/core/buildProject.lua:
TS.register("out/core/buildProject.lua", "buildProject", function()

    -- Setup
    local script = TS.get("out/core/buildProject.lua")

    -- Start of buildProject

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local Directory = TS.import(script, script.Parent.Parent, "utils", "filesystem").Directory
	local Reconciler = TS.import(script, script.Parent, "Reconciler").Reconciler
	local VirtualScript = TS.import(script, script.Parent, "VirtualScript").VirtualScript
	--[[
		*
		* Builds the given project as a Roblox Instance tree.
		* @param target The target files to build.
		* @param parent Optional parent of the Instance tree.
		* @returns A project interface.
	]]
	local function buildProject(target, parent)
		local directory = Directory(target, target)
		local reconciler = Reconciler.new(directory)
		return {
			Instance = reconciler:reify(parent),
			Location = directory.location,
		}
	end
	--[[
		*
		* Builds the given project and executes every tracked LocalScript.
		* @param target The target files to build.
		* @param parent Optional parent of the Instance tree.
		* @returns A project interface.
	]]
	local function deployProject(target, parent)
		local directory = Directory(target, target)
		local reconciler = Reconciler.new(directory)
		local instance = reconciler:reify(parent)
		return {
			Instance = instance,
			Location = directory.location,
			RuntimeWorker = reconciler:deployWorker(),
		}
	end
	--[[
		*
		* Builds the given project and executes every tracked LocalScript.
		* @param target The target files to build.
		* @param parent Optional parent of the Instance tree.
		* @returns A project interface.
	]]
	local function requireProject(target, parent)
		local directory = Directory(target, target)
		local reconciler = Reconciler.new(directory)
		local instance = reconciler:reify(parent)
		local _0 = instance:IsA("LuaSourceContainer")
		local _1 = "Failed to require " .. directory.location .. " (Project is not a module)"
		assert(_0, _1)
		return {
			Instance = instance,
			Location = directory.location,
			RuntimeWorker = reconciler:deployWorker(),
			Module = VirtualScript:getFromInstance(instance):deferExecutor(),
		}
	end
	return {
		buildProject = buildProject,
		deployProject = deployProject,
		requireProject = requireProject,
	}

    -- End of buildProject

end)

-- out/core/downloadAsset.lua:
TS.register("out/core/downloadAsset.lua", "downloadAsset", function()

    -- Setup
    local script = TS.get("out/core/downloadAsset.lua")

    -- Start of downloadAsset

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local http = TS.import(script, script.Parent.Parent, "utils", "common", "http")
	local makeFile = TS.import(script, script.Parent.Parent, "utils", "filesystem").makeFile
	local extract = TS.import(script, script.Parent.Parent, "utils", "common", "extract").extract
	--[[
		*
		* Downloads the asset file for a release.
		* @param release The release to get the asset from.
		* @param assetName Optional name of the asset. If not provided, the function returns the zipball URL.
		* @returns The file data for an asset.
	]]
	local downloadAsset = TS.async(function(release, path, assetName)
		local assetUrl
		if assetName ~= nil then
			local _0 = release.assets
			local _1 = function(asset)
				return asset.name == assetName
			end
			-- ▼ ReadonlyArray.find ▼
			local _2 = nil
			for _3, _4 in ipairs(_0) do
				if _1(_4, _3 - 1, _0) == true then
					_2 = _4
					break
				end
			end
			-- ▲ ReadonlyArray.find ▲
			local asset = _2
			local _3 = asset
			local _4 = "Release '" .. release.name .. "' does not have asset '" .. assetName .. "'"
			assert(_3, _4)
			assetUrl = asset.browser_download_url
		else
			assetUrl = release.zipball_url
		end
		local response = TS.await(http.request({
			Url = assetUrl,
			Headers = {
				["User-Agent"] = "rostruct",
			},
		}))
		local _0 = response.Success
		local _1 = response.StatusMessage
		assert(_0, _1)
		local _2
		if assetName ~= nil and (string.match(assetName, "([^%.]+)$")) ~= "zip" then
			_2 = makeFile(path .. assetName, response.Body)
		else
			_2 = extract(response.Body, path, assetName == nil)
		end
	end)
	return {
		downloadAsset = downloadAsset,
	}

    -- End of downloadAsset

end)

-- out/core/downloadRelease.lua:
TS.register("out/core/downloadRelease.lua", "downloadRelease", function()

    -- Setup
    local script = TS.get("out/core/downloadRelease.lua")

    -- Start of downloadRelease

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local openJson = TS.import(script, script.Parent.Parent, "utils", "common", "openJson").openJson
	local _0 = TS.import(script, script.Parent.Parent, "utils", "github-release")
	local getLatestRelease = _0.getLatestRelease
	local getRelease = _0.getRelease
	local identify = _0.identify
	local downloadAsset = TS.import(script, script.Parent, "downloadAsset").downloadAsset
	local fileManager = TS.import(script, script.Parent, "file-manager")
	local cacheObject = openJson(fileManager.lintPath("rostruct/cache/release_tags.json"))
	--[[
		*
		* Downloads a release from the given repository. If `assetName` is undefined, it downloads
		* the source zip files and extracts them. Automatically extracts .zip files.
		* This function does not download prereleases or drafts.
		* @param owner The owner of the repository.
		* @param repo The name of the repository.
		* @param tag The release tag to download.
		* @param assetName Optional asset to download. Defaults to the source files.
		* @returns A download result interface.
	]]
	local downloadRelease = TS.async(function(owner, repo, tag, assetName)
		local id = identify(owner, repo, tag, assetName)
		local path = fileManager.lintPath("rostruct/cache/releases/", id) .. "/"
		-- If the path is taken, don't download it again
		if isfolder(path) then
			return TS.Promise.resolve({
				Location = path,
				Tag = tag,
				Updated = false,
			})
		end
		local release = TS.await(getRelease(owner, repo, tag))
		TS.await(downloadAsset(release, path, assetName))
		return {
			Location = path,
			Tag = tag,
			Updated = true,
		}
	end)
	--[[
		*
		* Downloads the latest release from the given repository. If `assetName` is undefined,
		* it downloads the source zip files and extracts them. Automatically extracts .zip files.
		* This function does not download prereleases or drafts.
		* @param owner The owner of the repository.
		* @param repo The name of the repository.
		* @param assetName Optional asset to download. Defaults to the source files.
		* @returns A download result interface.
	]]
	local downloadLatestRelease = TS.async(function(owner, repo, assetName)
		local id = identify(owner, repo, nil, assetName)
		local path = fileManager.lintPath("rostruct/cache/releases/", id) .. "/"
		local release = TS.await(getLatestRelease(owner, repo))
		local cacheData = cacheObject:load()
		-- Check if the cache is up-to-date
		if cacheData[id] == release.tag_name and isfolder(path) then
			return {
				Location = path,
				Tag = release.tag_name,
				Updated = false,
			}
		end
		-- Update the cache with the new tag
		cacheData[id] = release.tag_name
		cacheObject:save()
		-- Make sure nothing is at the path before downloading!
		if isfolder(path) then
			delfolder(path)
		end
		-- Download the asset to the cache
		TS.await(downloadAsset(release, path, assetName))
		return {
			Location = path,
			Tag = release.tag_name,
			Updated = true,
		}
	end)
	-- * Clears the release cache.
	local function clearReleaseCache()
		delfolder(fileManager.lintPath("rostruct/cache/releases/"))
		makefolder(fileManager.lintPath("rostruct/cache/releases/"))
		writefile(fileManager.lintPath("rostruct/cache/release_tags.json"), "{}")
	end
	return {
		downloadRelease = downloadRelease,
		downloadLatestRelease = downloadLatestRelease,
		clearReleaseCache = clearReleaseCache,
	}

    -- End of downloadRelease

end)

-- out/core/file-manager.lua:
TS.register("out/core/file-manager.lua", "file-manager", function()

    -- Setup
    local script = TS.get("out/core/file-manager.lua")

    -- Start of file-manager

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local makeFiles = TS.import(script, script.Parent.Parent, "utils", "filesystem").makeFiles
	-- * Maps a list of files that handle Rostruct file storage.
	local fileArray = { { "rostruct/", "" }, { "rostruct/cache/", "" }, { "rostruct/cache/releases/", "" }, { "rostruct/cache/release_tags.json", "{}" } }
	--[[
		*
		* Gets the value of `dir .. file`. Mainly used with linting to flag unchanged files when changing paths.
		* Might be bad practice! Let me know of better ways to do this.
		* @param start The directory to index.
		* @param path The local path.
		* @returns A reference to the file.
	]]
	local function lintPath(start, path)
		return path ~= nil and start .. path or start
	end
	-- * Initializes the file structure for Rostruct.
	local function init()
		makeFiles(fileArray)
	end
	return {
		lintPath = lintPath,
		init = init,
	}

    -- End of file-manager

end)

-- out/core/init.lua:
TS.register("out/core/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/core/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	for _0, _1 in pairs(TS.import(script, script, "VirtualScript")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "Reconciler")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "buildProject")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "downloadRelease")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "file-manager")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "types")) do
		exports[_0] = _1
	end
	return exports

    -- End of init

end)

-- out/core/types.lua:
TS.register("out/core/types.lua", "types", function()

    -- Setup
    local script = TS.get("out/core/types.lua")

    -- Start of types

    -- Compiled with roblox-ts v1.1.1
	-- * A function that gets called when a VirtualScript is executed.
	-- * Base environment for VirtualScript instances.
	-- * Stores the results of project building functions.
	-- * Information about the release being downloaded.
	-- * Prevent the transpiled Lua code from returning nil!
	local _ = nil
	return {
		_ = _,
	}

    -- End of types

end)

-- out/globals/compatibility.lua:
TS.register("out/globals/compatibility.lua", "compatibility", function()

    -- Setup
    local script = TS.get("out/globals/compatibility.lua")

    -- Start of compatibility

    -- Compiled with roblox-ts v1.1.1
	--[[
		* File: api.ts
		* File Created: Tuesday, 1st June 2021 9:01:33 pm
		* Author: richard
		* Description: Manages compatibility between exploits.
	]]
	local _0 = getcustomasset
	if not (_0 ~= 0 and _0 == _0 and _0 ~= "" and _0) then
		_0 = getsynasset
	end
	local generateAssetId = _0
	local _1 = request
	if not (_1 ~= 0 and _1 == _1 and _1 ~= "" and _1) then
		_1 = syn.request
	end
	local httpRequest = _1
	return {
		generateAssetId = generateAssetId,
		httpRequest = httpRequest,
	}

    -- End of compatibility

end)

-- out/globals/init.lua:
TS.register("out/globals/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/globals/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	for _0, _1 in pairs(TS.import(script, script, "compatibility")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "rostruct-globals")) do
		exports[_0] = _1
	end
	return exports

    -- End of init

end)

-- out/globals/rostruct-globals.lua:
TS.register("out/globals/rostruct-globals.lua", "rostruct-globals", function()

    -- Setup
    local script = TS.get("out/globals/rostruct-globals.lua")

    -- Start of rostruct-globals

    -- Compiled with roblox-ts v1.1.1
	--[[
		* File: reserved.ts
		* File Created: Tuesday, 1st June 2021 8:58:07 pm
		* Author: richard
	]]
	-- * Global environment reserved for Rostruct.
	-- * Global environment reserved for Rostruct.
	local globals = (getgenv().Rostruct) or {
		currentScope = 0,
	}
	getgenv().Rostruct = globals
	return {
		globals = globals,
	}

    -- End of rostruct-globals

end)

-- out/init.lua:
TS.register("out/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	-- Setup
	local init = TS.import(script, script, "core").init
	init()
	-- Core
	local _0 = TS.import(script, script, "core")
	exports.Build = _0.buildProject
	exports.Deploy = _0.deployProject
	exports.Require = _0.requireProject
	exports.DownloadRelease = _0.downloadRelease
	exports.DownloadLatestRelease = _0.downloadLatestRelease
	exports.ClearReleaseCache = _0.clearReleaseCache
	exports.Reconciler = _0.Reconciler
	exports.VirtualScript = _0.VirtualScript
	-- Packages
	local Promise = TS.import(script, script, "packages", "Promise")
	return exports

    -- End of init

end)

-- out/packages/Promise/init.lua:
TS.register("out/packages/Promise/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/packages/Promise/init.lua")

    -- Start of init

    --[[
		An implementation of Promises similar to Promise/A+.
	]]
	
	local ERROR_NON_PROMISE_IN_LIST = "Non-promise value passed into %s at index %s"
	local ERROR_NON_LIST = "Please pass a list of promises to %s"
	local ERROR_NON_FUNCTION = "Please pass a handler function to %s!"
	local MODE_KEY_METATABLE = {__mode = "k"}
	
	--[[
		Creates an enum dictionary with some metamethods to prevent common mistakes.
	]]
	local function makeEnum(enumName, members)
		local enum = {}
	
		for _, memberName in ipairs(members) do
			enum[memberName] = memberName
		end
	
		return setmetatable(enum, {
			__index = function(_, k)
				error(string.format("%s is not in %s!", k, enumName), 2)
			end,
			__newindex = function()
				error(string.format("Creating new members in %s is not allowed!", enumName), 2)
			end,
		})
	end
	
	--[[
		An object to represent runtime errors that occur during execution.
		Promises that experience an error like this will be rejected with
		an instance of this object.
	]]
	local Error do
		Error = {
			Kind = makeEnum("Promise.Error.Kind", {
				"ExecutionError",
				"AlreadyCancelled",
				"NotResolvedInTime",
				"TimedOut",
			}),
		}
		Error.__index = Error
	
		function Error.new(options, parent)
			options = options or {}
			return setmetatable({
				error = tostring(options.error) or "[This error has no error text.]",
				trace = options.trace,
				context = options.context,
				kind = options.kind,
				parent = parent,
				createdTick = os.clock(),
				createdTrace = debug.traceback(),
			}, Error)
		end
	
		function Error.is(anything)
			if type(anything) == "table" then
				local metatable = getmetatable(anything)
	
				if type(metatable) == "table" then
					return rawget(anything, "error") ~= nil and type(rawget(metatable, "extend")) == "function"
				end
			end
	
			return false
		end
	
		function Error.isKind(anything, kind)
			assert(kind ~= nil, "Argument #2 to Promise.Error.isKind must not be nil")
	
			return Error.is(anything) and anything.kind == kind
		end
	
		function Error:extend(options)
			options = options or {}
	
			options.kind = options.kind or self.kind
	
			return Error.new(options, self)
		end
	
		function Error:getErrorChain()
			local runtimeErrors = { self }
	
			while runtimeErrors[#runtimeErrors].parent do
				table.insert(runtimeErrors, runtimeErrors[#runtimeErrors].parent)
			end
	
			return runtimeErrors
		end
	
		function Error:__tostring()
			local errorStrings = {
				string.format("-- Promise.Error(%s) --", self.kind or "?"),
			}
	
			for _, runtimeError in ipairs(self:getErrorChain()) do
				table.insert(errorStrings, table.concat({
					runtimeError.trace or runtimeError.error,
					runtimeError.context,
				}, "\n"))
			end
	
			return table.concat(errorStrings, "\n")
		end
	end
	
	--[[
		Packs a number of arguments into a table and returns its length.
	
		Used to cajole varargs without dropping sparse values.
	]]
	local function pack(...)
		return select("#", ...), { ... }
	end
	
	--[[
		Returns first value (success), and packs all following values.
	]]
	local function packResult(success, ...)
		return success, select("#", ...), { ... }
	end
	
	
	local function makeErrorHandler(traceback)
		assert(traceback ~= nil)
	
		return function(err)
			-- If the error object is already a table, forward it directly.
			-- Should we extend the error here and add our own trace?
	
			if type(err) == "table" then
				return err
			end
	
			return Error.new({
				error = err,
				kind = Error.Kind.ExecutionError,
				trace = debug.traceback(tostring(err), 2),
				context = "Promise created at:\n\n" .. traceback,
			})
		end
	end
	
	--[[
		Calls a Promise executor with error handling.
	]]
	local function runExecutor(traceback, callback, ...)
		return packResult(xpcall(callback, makeErrorHandler(traceback), ...))
	end
	
	--[[
		Creates a function that invokes a callback with correct error handling and
		resolution mechanisms.
	]]
	local function createAdvancer(traceback, callback, resolve, reject)
		return function(...)
			local ok, resultLength, result = runExecutor(traceback, callback, ...)
	
			if ok then
				resolve(unpack(result, 1, resultLength))
			else
				reject(result[1])
			end
		end
	end
	
	local function isEmpty(t)
		return next(t) == nil
	end
	
	local Promise = {
		Error = Error,
		Status = makeEnum("Promise.Status", {"Started", "Resolved", "Rejected", "Cancelled"}),
		_getTime = os.clock,
		_timeEvent = game:GetService("RunService").Heartbeat,
	}
	Promise.prototype = {}
	Promise.__index = Promise.prototype
	
	--[[
		Constructs a new Promise with the given initializing callback.
	
		This is generally only called when directly wrapping a non-promise API into
		a promise-based version.
	
		The callback will receive 'resolve' and 'reject' methods, used to start
		invoking the promise chain.
	
		Second parameter, parent, is used internally for tracking the "parent" in a
		promise chain. External code shouldn't need to worry about this.
	]]
	function Promise._new(traceback, callback, parent)
		if parent ~= nil and not Promise.is(parent) then
			error("Argument #2 to Promise.new must be a promise or nil", 2)
		end
	
		local self = {
			-- Used to locate where a promise was created
			_source = traceback,
	
			_status = Promise.Status.Started,
	
			-- A table containing a list of all results, whether success or failure.
			-- Only valid if _status is set to something besides Started
			_values = nil,
	
			-- Lua doesn't like sparse arrays very much, so we explicitly store the
			-- length of _values to handle middle nils.
			_valuesLength = -1,
	
			-- Tracks if this Promise has no error observers..
			_unhandledRejection = true,
	
			-- Queues representing functions we should invoke when we update!
			_queuedResolve = {},
			_queuedReject = {},
			_queuedFinally = {},
	
			-- The function to run when/if this promise is cancelled.
			_cancellationHook = nil,
	
			-- The "parent" of this promise in a promise chain. Required for
			-- cancellation propagation upstream.
			_parent = parent,
	
			-- Consumers are Promises that have chained onto this one.
			-- We track them for cancellation propagation downstream.
			_consumers = setmetatable({}, MODE_KEY_METATABLE),
		}
	
		if parent and parent._status == Promise.Status.Started then
			parent._consumers[self] = true
		end
	
		setmetatable(self, Promise)
	
		local function resolve(...)
			self:_resolve(...)
		end
	
		local function reject(...)
			self:_reject(...)
		end
	
		local function onCancel(cancellationHook)
			if cancellationHook then
				if self._status == Promise.Status.Cancelled then
					cancellationHook()
				else
					self._cancellationHook = cancellationHook
				end
			end
	
			return self._status == Promise.Status.Cancelled
		end
	
		coroutine.wrap(function()
			local ok, _, result = runExecutor(
				self._source,
				callback,
				resolve,
				reject,
				onCancel
			)
	
			if not ok then
				reject(result[1])
			end
		end)()
	
		return self
	end
	
	function Promise.new(executor)
		return Promise._new(debug.traceback(nil, 2), executor)
	end
	
	function Promise:__tostring()
		return string.format("Promise(%s)", self:getStatus())
	end
	
	--[[
		Promise.new, except pcall on a new thread is automatic.
	]]
	function Promise.defer(callback)
		local traceback = debug.traceback(nil, 2)
		local promise
		promise = Promise._new(traceback, function(resolve, reject, onCancel)
			local connection
			connection = Promise._timeEvent:Connect(function()
				connection:Disconnect()
				local ok, _, result = runExecutor(traceback, callback, resolve, reject, onCancel)
	
				if not ok then
					reject(result[1])
				end
			end)
		end)
	
		return promise
	end
	
	-- Backwards compatibility
	Promise.async = Promise.defer
	
	--[[
		Create a promise that represents the immediately resolved value.
	]]
	function Promise.resolve(...)
		local length, values = pack(...)
		return Promise._new(debug.traceback(nil, 2), function(resolve)
			resolve(unpack(values, 1, length))
		end)
	end
	
	--[[
		Create a promise that represents the immediately rejected value.
	]]
	function Promise.reject(...)
		local length, values = pack(...)
		return Promise._new(debug.traceback(nil, 2), function(_, reject)
			reject(unpack(values, 1, length))
		end)
	end
	
	--[[
		Runs a non-promise-returning function as a Promise with the
	  given arguments.
	]]
	function Promise._try(traceback, callback, ...)
		local valuesLength, values = pack(...)
	
		return Promise._new(traceback, function(resolve)
			resolve(callback(unpack(values, 1, valuesLength)))
		end)
	end
	
	--[[
		Begins a Promise chain, turning synchronous errors into rejections.
	]]
	function Promise.try(...)
		return Promise._try(debug.traceback(nil, 2), ...)
	end
	
	--[[
		Returns a new promise that:
			* is resolved when all input promises resolve
			* is rejected if ANY input promises reject
	]]
	function Promise._all(traceback, promises, amount)
		if type(promises) ~= "table" then
			error(string.format(ERROR_NON_LIST, "Promise.all"), 3)
		end
	
		-- We need to check that each value is a promise here so that we can produce
		-- a proper error rather than a rejected promise with our error.
		for i, promise in pairs(promises) do
			if not Promise.is(promise) then
				error(string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.all", tostring(i)), 3)
			end
		end
	
		-- If there are no values then return an already resolved promise.
		if #promises == 0 or amount == 0 then
			return Promise.resolve({})
		end
	
		return Promise._new(traceback, function(resolve, reject, onCancel)
			-- An array to contain our resolved values from the given promises.
			local resolvedValues = {}
			local newPromises = {}
	
			-- Keep a count of resolved promises because just checking the resolved
			-- values length wouldn't account for promises that resolve with nil.
			local resolvedCount = 0
			local rejectedCount = 0
			local done = false
	
			local function cancel()
				for _, promise in ipairs(newPromises) do
					promise:cancel()
				end
			end
	
			-- Called when a single value is resolved and resolves if all are done.
			local function resolveOne(i, ...)
				if done then
					return
				end
	
				resolvedCount = resolvedCount + 1
	
				if amount == nil then
					resolvedValues[i] = ...
				else
					resolvedValues[resolvedCount] = ...
				end
	
				if resolvedCount >= (amount or #promises) then
					done = true
					resolve(resolvedValues)
					cancel()
				end
			end
	
			onCancel(cancel)
	
			-- We can assume the values inside `promises` are all promises since we
			-- checked above.
			for i, promise in ipairs(promises) do
				newPromises[i] = promise:andThen(
					function(...)
						resolveOne(i, ...)
					end,
					function(...)
						rejectedCount = rejectedCount + 1
	
						if amount == nil or #promises - rejectedCount < amount then
							cancel()
							done = true
	
							reject(...)
						end
					end
				)
			end
	
			if done then
				cancel()
			end
		end)
	end
	
	function Promise.all(promises)
		return Promise._all(debug.traceback(nil, 2), promises)
	end
	
	function Promise.fold(list, callback, initialValue)
		assert(type(list) == "table", "Bad argument #1 to Promise.fold: must be a table")
		assert(type(callback) == "function", "Bad argument #2 to Promise.fold: must be a function")
	
		local accumulator = Promise.resolve(initialValue)
		return Promise.each(list, function(resolvedElement, i)
			accumulator = accumulator:andThen(function(previousValueResolved)
				return callback(previousValueResolved, resolvedElement, i)
			end)
		end):andThenReturn(accumulator)
	end
	
	function Promise.some(promises, amount)
		assert(type(amount) == "number", "Bad argument #2 to Promise.some: must be a number")
	
		return Promise._all(debug.traceback(nil, 2), promises, amount)
	end
	
	function Promise.any(promises)
		return Promise._all(debug.traceback(nil, 2), promises, 1):andThen(function(values)
			return values[1]
		end)
	end
	
	function Promise.allSettled(promises)
		if type(promises) ~= "table" then
			error(string.format(ERROR_NON_LIST, "Promise.allSettled"), 2)
		end
	
		-- We need to check that each value is a promise here so that we can produce
		-- a proper error rather than a rejected promise with our error.
		for i, promise in pairs(promises) do
			if not Promise.is(promise) then
				error(string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.allSettled", tostring(i)), 2)
			end
		end
	
		-- If there are no values then return an already resolved promise.
		if #promises == 0 then
			return Promise.resolve({})
		end
	
		return Promise._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
			-- An array to contain our resolved values from the given promises.
			local fates = {}
			local newPromises = {}
	
			-- Keep a count of resolved promises because just checking the resolved
			-- values length wouldn't account for promises that resolve with nil.
			local finishedCount = 0
	
			-- Called when a single value is resolved and resolves if all are done.
			local function resolveOne(i, ...)
				finishedCount = finishedCount + 1
	
				fates[i] = ...
	
				if finishedCount >= #promises then
					resolve(fates)
				end
			end
	
			onCancel(function()
				for _, promise in ipairs(newPromises) do
					promise:cancel()
				end
			end)
	
			-- We can assume the values inside `promises` are all promises since we
			-- checked above.
			for i, promise in ipairs(promises) do
				newPromises[i] = promise:finally(
					function(...)
						resolveOne(i, ...)
					end
				)
			end
		end)
	end
	
	--[[
		Races a set of Promises and returns the first one that resolves,
		cancelling the others.
	]]
	function Promise.race(promises)
		assert(type(promises) == "table", string.format(ERROR_NON_LIST, "Promise.race"))
	
		for i, promise in pairs(promises) do
			assert(Promise.is(promise), string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.race", tostring(i)))
		end
	
		return Promise._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
			local newPromises = {}
			local finished = false
	
			local function cancel()
				for _, promise in ipairs(newPromises) do
					promise:cancel()
				end
			end
	
			local function finalize(callback)
				return function (...)
					cancel()
					finished = true
					return callback(...)
				end
			end
	
			if onCancel(finalize(reject)) then
				return
			end
	
			for i, promise in ipairs(promises) do
				newPromises[i] = promise:andThen(finalize(resolve), finalize(reject))
			end
	
			if finished then
				cancel()
			end
		end)
	end
	
	--[[
		Iterates serially over the given an array of values, calling the predicate callback on each before continuing.
		If the predicate returns a Promise, we wait for that Promise to resolve before continuing to the next item
		in the array. If the Promise the predicate returns rejects, the Promise from Promise.each is also rejected with
		the same value.
	
		Returns a Promise containing an array of the return values from the predicate for each item in the original list.
	]]
	function Promise.each(list, predicate)
		assert(type(list) == "table", string.format(ERROR_NON_LIST, "Promise.each"))
		assert(type(predicate) == "function", string.format(ERROR_NON_FUNCTION, "Promise.each"))
	
		return Promise._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
			local results = {}
			local promisesToCancel = {}
	
			local cancelled = false
	
			local function cancel()
				for _, promiseToCancel in ipairs(promisesToCancel) do
					promiseToCancel:cancel()
				end
			end
	
			onCancel(function()
				cancelled = true
	
				cancel()
			end)
	
			-- We need to preprocess the list of values and look for Promises.
			-- If we find some, we must register our andThen calls now, so that those Promises have a consumer
			-- from us registered. If we don't do this, those Promises might get cancelled by something else
			-- before we get to them in the series because it's not possible to tell that we plan to use it
			-- unless we indicate it here.
	
			local preprocessedList = {}
	
			for index, value in ipairs(list) do
				if Promise.is(value) then
					if value:getStatus() == Promise.Status.Cancelled then
						cancel()
						return reject(Error.new({
							error = "Promise is cancelled",
							kind = Error.Kind.AlreadyCancelled,
							context = string.format(
								"The Promise that was part of the array at index %d passed into Promise.each was already cancelled when Promise.each began.\n\nThat Promise was created at:\n\n%s",
								index,
								value._source
							),
						}))
					elseif value:getStatus() == Promise.Status.Rejected then
						cancel()
						return reject(select(2, value:await()))
					end
	
					-- Chain a new Promise from this one so we only cancel ours
					local ourPromise = value:andThen(function(...)
						return ...
					end)
	
					table.insert(promisesToCancel, ourPromise)
					preprocessedList[index] = ourPromise
				else
					preprocessedList[index] = value
				end
			end
	
			for index, value in ipairs(preprocessedList) do
				if Promise.is(value) then
					local success
					success, value = value:await()
	
					if not success then
						cancel()
						return reject(value)
					end
				end
	
				if cancelled then
					return
				end
	
				local predicatePromise = Promise.resolve(predicate(value, index))
	
				table.insert(promisesToCancel, predicatePromise)
	
				local success, result = predicatePromise:await()
	
				if not success then
					cancel()
					return reject(result)
				end
	
				results[index] = result
			end
	
			resolve(results)
		end)
	end
	
	--[[
		Is the given object a Promise instance?
	]]
	function Promise.is(object)
		if type(object) ~= "table" then
			return false
		end
	
		local objectMetatable = getmetatable(object)
	
		if objectMetatable == Promise then
			-- The Promise came from this library.
			return true
		elseif objectMetatable == nil then
			-- No metatable, but we should still chain onto tables with andThen methods
			return type(object.andThen) == "function"
		elseif
			type(objectMetatable) == "table"
			and type(rawget(objectMetatable, "__index")) == "table"
			and type(rawget(rawget(objectMetatable, "__index"), "andThen")) == "function"
		then
			-- Maybe this came from a different or older Promise library.
			return true
		end
	
		return false
	end
	
	--[[
		Converts a yielding function into a Promise-returning one.
	]]
	function Promise.promisify(callback)
		return function(...)
			return Promise._try(debug.traceback(nil, 2), callback, ...)
		end
	end
	
	--[[
		Creates a Promise that resolves after given number of seconds.
	]]
	do
		-- uses a sorted doubly linked list (queue) to achieve O(1) remove operations and O(n) for insert
	
		-- the initial node in the linked list
		local first
		local connection
	
		function Promise.delay(seconds)
			assert(type(seconds) == "number", "Bad argument #1 to Promise.delay, must be a number.")
			-- If seconds is -INF, INF, NaN, or less than 1 / 60, assume seconds is 1 / 60.
			-- This mirrors the behavior of wait()
			if not (seconds >= 1 / 60) or seconds == math.huge then
				seconds = 1 / 60
			end
	
			return Promise._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
				local startTime = Promise._getTime()
				local endTime = startTime + seconds
	
				local node = {
					resolve = resolve,
					startTime = startTime,
					endTime = endTime,
				}
	
				if connection == nil then -- first is nil when connection is nil
					first = node
					connection = Promise._timeEvent:Connect(function()
						local threadStart = Promise._getTime()
	
						while first ~= nil and first.endTime < threadStart do
							local current = first
							first = current.next
	
							if first == nil then
								connection:Disconnect()
								connection = nil
							else
								first.previous = nil
							end
	
							current.resolve(Promise._getTime() - current.startTime)
						end
					end)
				else -- first is non-nil
					if first.endTime < endTime then -- if `node` should be placed after `first`
						-- we will insert `node` between `current` and `next`
						-- (i.e. after `current` if `next` is nil)
						local current = first
						local next = current.next
	
						while next ~= nil and next.endTime < endTime do
							current = next
							next = current.next
						end
	
						-- `current` must be non-nil, but `next` could be `nil` (i.e. last item in list)
						current.next = node
						node.previous = current
	
						if next ~= nil then
							node.next = next
							next.previous = node
						end
					else
						-- set `node` to `first`
						node.next = first
						first.previous = node
						first = node
					end
				end
	
				onCancel(function()
					-- remove node from queue
					local next = node.next
	
					if first == node then
						if next == nil then -- if `node` is the first and last
							connection:Disconnect()
							connection = nil
						else -- if `node` is `first` and not the last
							next.previous = nil
						end
						first = next
					else
						local previous = node.previous
						-- since `node` is not `first`, then we know `previous` is non-nil
						previous.next = next
	
						if next ~= nil then
							next.previous = previous
						end
					end
				end)
			end)
		end
	end
	
	--[[
		Rejects the promise after `seconds` seconds.
	]]
	function Promise.prototype:timeout(seconds, rejectionValue)
		local traceback = debug.traceback(nil, 2)
	
		return Promise.race({
			Promise.delay(seconds):andThen(function()
				return Promise.reject(rejectionValue == nil and Error.new({
					kind = Error.Kind.TimedOut,
					error = "Timed out",
					context = string.format(
						"Timeout of %d seconds exceeded.\n:timeout() called at:\n\n%s",
						seconds,
						traceback
					),
				}) or rejectionValue)
			end),
			self,
		})
	end
	
	function Promise.prototype:getStatus()
		return self._status
	end
	
	--[[
		Creates a new promise that receives the result of this promise.
	
		The given callbacks are invoked depending on that result.
	]]
	function Promise.prototype:_andThen(traceback, successHandler, failureHandler)
		self._unhandledRejection = false
	
		-- Create a new promise to follow this part of the chain
		return Promise._new(traceback, function(resolve, reject)
			-- Our default callbacks just pass values onto the next promise.
			-- This lets success and failure cascade correctly!
	
			local successCallback = resolve
			if successHandler then
				successCallback = createAdvancer(
					traceback,
					successHandler,
					resolve,
					reject
				)
			end
	
			local failureCallback = reject
			if failureHandler then
				failureCallback = createAdvancer(
					traceback,
					failureHandler,
					resolve,
					reject
				)
			end
	
			if self._status == Promise.Status.Started then
				-- If we haven't resolved yet, put ourselves into the queue
				table.insert(self._queuedResolve, successCallback)
				table.insert(self._queuedReject, failureCallback)
			elseif self._status == Promise.Status.Resolved then
				-- This promise has already resolved! Trigger success immediately.
				successCallback(unpack(self._values, 1, self._valuesLength))
			elseif self._status == Promise.Status.Rejected then
				-- This promise died a terrible death! Trigger failure immediately.
				failureCallback(unpack(self._values, 1, self._valuesLength))
			elseif self._status == Promise.Status.Cancelled then
				-- We don't want to call the success handler or the failure handler,
				-- we just reject this promise outright.
				reject(Error.new({
					error = "Promise is cancelled",
					kind = Error.Kind.AlreadyCancelled,
					context = "Promise created at\n\n" .. traceback,
				}))
			end
		end, self)
	end
	
	function Promise.prototype:andThen(successHandler, failureHandler)
		assert(
			successHandler == nil or type(successHandler) == "function",
			string.format(ERROR_NON_FUNCTION, "Promise:andThen")
		)
		assert(
			failureHandler == nil or type(failureHandler) == "function",
			string.format(ERROR_NON_FUNCTION, "Promise:andThen")
		)
	
		return self:_andThen(debug.traceback(nil, 2), successHandler, failureHandler)
	end
	
	--[[
		Used to catch any errors that may have occurred in the promise.
	]]
	function Promise.prototype:catch(failureCallback)
		assert(
			failureCallback == nil or type(failureCallback) == "function",
			string.format(ERROR_NON_FUNCTION, "Promise:catch")
		)
		return self:_andThen(debug.traceback(nil, 2), nil, failureCallback)
	end
	
	--[[
		Like andThen, but the value passed into the handler is also the
		value returned from the handler.
	]]
	function Promise.prototype:tap(tapCallback)
		assert(type(tapCallback) == "function", string.format(ERROR_NON_FUNCTION, "Promise:tap"))
		return self:_andThen(debug.traceback(nil, 2), function(...)
			local callbackReturn = tapCallback(...)
	
			if Promise.is(callbackReturn) then
				local length, values = pack(...)
				return callbackReturn:andThen(function()
					return unpack(values, 1, length)
				end)
			end
	
			return ...
		end)
	end
	
	--[[
		Calls a callback on `andThen` with specific arguments.
	]]
	function Promise.prototype:andThenCall(callback, ...)
		assert(type(callback) == "function", string.format(ERROR_NON_FUNCTION, "Promise:andThenCall"))
		local length, values = pack(...)
		return self:_andThen(debug.traceback(nil, 2), function()
			return callback(unpack(values, 1, length))
		end)
	end
	
	--[[
		Shorthand for an andThen handler that returns the given value.
	]]
	function Promise.prototype:andThenReturn(...)
		local length, values = pack(...)
		return self:_andThen(debug.traceback(nil, 2), function()
			return unpack(values, 1, length)
		end)
	end
	
	--[[
		Cancels the promise, disallowing it from rejecting or resolving, and calls
		the cancellation hook if provided.
	]]
	function Promise.prototype:cancel()
		if self._status ~= Promise.Status.Started then
			return
		end
	
		self._status = Promise.Status.Cancelled
	
		if self._cancellationHook then
			self._cancellationHook()
		end
	
		if self._parent then
			self._parent:_consumerCancelled(self)
		end
	
		for child in pairs(self._consumers) do
			child:cancel()
		end
	
		self:_finalize()
	end
	
	--[[
		Used to decrease the number of consumers by 1, and if there are no more,
		cancel this promise.
	]]
	function Promise.prototype:_consumerCancelled(consumer)
		if self._status ~= Promise.Status.Started then
			return
		end
	
		self._consumers[consumer] = nil
	
		if next(self._consumers) == nil then
			self:cancel()
		end
	end
	
	--[[
		Used to set a handler for when the promise resolves, rejects, or is
		cancelled. Returns a new promise chained from this promise.
	]]
	function Promise.prototype:_finally(traceback, finallyHandler, onlyOk)
		if not onlyOk then
			self._unhandledRejection = false
		end
	
		-- Return a promise chained off of this promise
		return Promise._new(traceback, function(resolve, reject)
			local finallyCallback = resolve
			if finallyHandler then
				finallyCallback = createAdvancer(
					traceback,
					finallyHandler,
					resolve,
					reject
				)
			end
	
			if onlyOk then
				local callback = finallyCallback
				finallyCallback = function(...)
					if self._status == Promise.Status.Rejected then
						return resolve(self)
					end
	
					return callback(...)
				end
			end
	
			if self._status == Promise.Status.Started then
				-- The promise is not settled, so queue this.
				table.insert(self._queuedFinally, finallyCallback)
			else
				-- The promise already settled or was cancelled, run the callback now.
				finallyCallback(self._status)
			end
		end, self)
	end
	
	function Promise.prototype:finally(finallyHandler)
		assert(
			finallyHandler == nil or type(finallyHandler) == "function",
			string.format(ERROR_NON_FUNCTION, "Promise:finally")
		)
		return self:_finally(debug.traceback(nil, 2), finallyHandler)
	end
	
	--[[
		Calls a callback on `finally` with specific arguments.
	]]
	function Promise.prototype:finallyCall(callback, ...)
		assert(type(callback) == "function", string.format(ERROR_NON_FUNCTION, "Promise:finallyCall"))
		local length, values = pack(...)
		return self:_finally(debug.traceback(nil, 2), function()
			return callback(unpack(values, 1, length))
		end)
	end
	
	--[[
		Shorthand for a finally handler that returns the given value.
	]]
	function Promise.prototype:finallyReturn(...)
		local length, values = pack(...)
		return self:_finally(debug.traceback(nil, 2), function()
			return unpack(values, 1, length)
		end)
	end
	
	--[[
		Similar to finally, except rejections are propagated through it.
	]]
	function Promise.prototype:done(finallyHandler)
		assert(
			finallyHandler == nil or type(finallyHandler) == "function",
			string.format(ERROR_NON_FUNCTION, "Promise:done")
		)
		return self:_finally(debug.traceback(nil, 2), finallyHandler, true)
	end
	
	--[[
		Calls a callback on `done` with specific arguments.
	]]
	function Promise.prototype:doneCall(callback, ...)
		assert(type(callback) == "function", string.format(ERROR_NON_FUNCTION, "Promise:doneCall"))
		local length, values = pack(...)
		return self:_finally(debug.traceback(nil, 2), function()
			return callback(unpack(values, 1, length))
		end, true)
	end
	
	--[[
		Shorthand for a done handler that returns the given value.
	]]
	function Promise.prototype:doneReturn(...)
		local length, values = pack(...)
		return self:_finally(debug.traceback(nil, 2), function()
			return unpack(values, 1, length)
		end, true)
	end
	
	--[[
		Yield until the promise is completed.
	
		This matches the execution model of normal Roblox functions.
	]]
	function Promise.prototype:awaitStatus()
		self._unhandledRejection = false
	
		if self._status == Promise.Status.Started then
			local bindable = Instance.new("BindableEvent")
	
			self:finally(function()
				bindable:Fire()
			end)
	
			bindable.Event:Wait()
			bindable:Destroy()
		end
	
		if self._status == Promise.Status.Resolved then
			return self._status, unpack(self._values, 1, self._valuesLength)
		elseif self._status == Promise.Status.Rejected then
			return self._status, unpack(self._values, 1, self._valuesLength)
		end
	
		return self._status
	end
	
	local function awaitHelper(status, ...)
		return status == Promise.Status.Resolved, ...
	end
	
	--[[
		Calls awaitStatus internally, returns (isResolved, values...)
	]]
	function Promise.prototype:await()
		return awaitHelper(self:awaitStatus())
	end
	
	local function expectHelper(status, ...)
		if status ~= Promise.Status.Resolved then
			error((...) == nil and "Expected Promise rejected with no value." or (...), 3)
		end
	
		return ...
	end
	
	--[[
		Calls await and only returns if the Promise resolves.
		Throws if the Promise rejects or gets cancelled.
	]]
	function Promise.prototype:expect()
		return expectHelper(self:awaitStatus())
	end
	
	-- Backwards compatibility
	Promise.prototype.awaitValue = Promise.prototype.expect
	
	--[[
		Intended for use in tests.
	
		Similar to await(), but instead of yielding if the promise is unresolved,
		_unwrap will throw. This indicates an assumption that a promise has
		resolved.
	]]
	function Promise.prototype:_unwrap()
		if self._status == Promise.Status.Started then
			error("Promise has not resolved or rejected.", 2)
		end
	
		local success = self._status == Promise.Status.Resolved
	
		return success, unpack(self._values, 1, self._valuesLength)
	end
	
	function Promise.prototype:_resolve(...)
		if self._status ~= Promise.Status.Started then
			if Promise.is((...)) then
				(...):_consumerCancelled(self)
			end
			return
		end
	
		-- If the resolved value was a Promise, we chain onto it!
		if Promise.is((...)) then
			-- Without this warning, arguments sometimes mysteriously disappear
			if select("#", ...) > 1 then
				local message = string.format(
					"When returning a Promise from andThen, extra arguments are " ..
					"discarded! See:\n\n%s",
					self._source
				)
				warn(message)
			end
	
			local chainedPromise = ...
	
			local promise = chainedPromise:andThen(
				function(...)
					self:_resolve(...)
				end,
				function(...)
					local maybeRuntimeError = chainedPromise._values[1]
	
					-- Backwards compatibility < v2
					if chainedPromise._error then
						maybeRuntimeError = Error.new({
							error = chainedPromise._error,
							kind = Error.Kind.ExecutionError,
							context = "[No stack trace available as this Promise originated from an older version of the Promise library (< v2)]",
						})
					end
	
					if Error.isKind(maybeRuntimeError, Error.Kind.ExecutionError) then
						return self:_reject(maybeRuntimeError:extend({
							error = "This Promise was chained to a Promise that errored.",
							trace = "",
							context = string.format(
								"The Promise at:\n\n%s\n...Rejected because it was chained to the following Promise, which encountered an error:\n",
								self._source
							),
						}))
					end
	
					self:_reject(...)
				end
			)
	
			if promise._status == Promise.Status.Cancelled then
				self:cancel()
			elseif promise._status == Promise.Status.Started then
				-- Adopt ourselves into promise for cancellation propagation.
				self._parent = promise
				promise._consumers[self] = true
			end
	
			return
		end
	
		self._status = Promise.Status.Resolved
		self._valuesLength, self._values = pack(...)
	
		-- We assume that these callbacks will not throw errors.
		for _, callback in ipairs(self._queuedResolve) do
			coroutine.wrap(callback)(...)
		end
	
		self:_finalize()
	end
	
	function Promise.prototype:_reject(...)
		if self._status ~= Promise.Status.Started then
			return
		end
	
		self._status = Promise.Status.Rejected
		self._valuesLength, self._values = pack(...)
	
		-- If there are any rejection handlers, call those!
		if not isEmpty(self._queuedReject) then
			-- We assume that these callbacks will not throw errors.
			for _, callback in ipairs(self._queuedReject) do
				coroutine.wrap(callback)(...)
			end
		else
			-- At this point, no one was able to observe the error.
			-- An error handler might still be attached if the error occurred
			-- synchronously. We'll wait one tick, and if there are still no
			-- observers, then we should put a message in the console.
	
			local err = tostring((...))
	
			coroutine.wrap(function()
				Promise._timeEvent:Wait()
	
				-- Someone observed the error, hooray!
				if not self._unhandledRejection then
					return
				end
	
				-- Build a reasonable message
				local message = string.format(
					"Unhandled Promise rejection:\n\n%s\n\n%s",
					err,
					self._source
				)
	
				if Promise.TEST then
					-- Don't spam output when we're running tests.
					return
				end
	
				warn(message)
			end)()
		end
	
		self:_finalize()
	end
	
	--[[
		Calls any :finally handlers. We need this to be a separate method and
		queue because we must call all of the finally callbacks upon a success,
		failure, *and* cancellation.
	]]
	function Promise.prototype:_finalize()
		for _, callback in ipairs(self._queuedFinally) do
			-- Purposefully not passing values to callbacks here, as it could be the
			-- resolved values, or rejected errors. If the developer needs the values,
			-- they should use :andThen or :catch explicitly.
			coroutine.wrap(callback)(self._status)
		end
	
		self._queuedFinally = nil
		self._queuedReject = nil
		self._queuedResolve = nil
	
		-- Clear references to other Promises to allow gc
		if not Promise.TEST then
			self._parent = nil
			self._consumers = nil
		end
	end
	
	--[[
		Chains a Promise from this one that is resolved if this Promise is
		resolved, and rejected if it is not resolved.
	]]
	function Promise.prototype:now(rejectionValue)
		local traceback = debug.traceback(nil, 2)
		if self:getStatus() == Promise.Status.Resolved then
			return self:_andThen(traceback, function(...)
				return ...
			end)
		else
			return Promise.reject(rejectionValue == nil and Error.new({
				kind = Error.Kind.NotResolvedInTime,
				error = "This Promise was not resolved in time for :now()",
				context = ":now() was called at:\n\n" .. traceback,
			}) or rejectionValue)
		end
	end
	
	--[[
		Retries a Promise-returning callback N times until it succeeds.
	]]
	function Promise.retry(callback, times, ...)
		assert(type(callback) == "function", "Parameter #1 to Promise.retry must be a function")
		assert(type(times) == "number", "Parameter #2 to Promise.retry must be a number")
	
		local args, length = {...}, select("#", ...)
	
		return Promise.resolve(callback(...)):catch(function(...)
			if times > 0 then
				return Promise.retry(callback, times - 1, unpack(args, 1, length))
			else
				return Promise.reject(...)
			end
		end)
	end
	
	--[[
		Converts an event into a Promise with an optional predicate
	]]
	function Promise.fromEvent(event, predicate)
		predicate = predicate or function()
			return true
		end
	
		return Promise._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
			local connection
			local shouldDisconnect = false
	
			local function disconnect()
				connection:Disconnect()
				connection = nil
			end
	
			-- We use shouldDisconnect because if the callback given to Connect is called before
			-- Connect returns, connection will still be nil. This happens with events that queue up
			-- events when there's nothing connected, such as RemoteEvents
	
			connection = event:Connect(function(...)
				local callbackValue = predicate(...)
	
				if callbackValue == true then
					resolve(...)
	
					if connection then
						disconnect()
					else
						shouldDisconnect = true
					end
				elseif type(callbackValue) ~= "boolean" then
					error("Promise.fromEvent predicate should always return a boolean")
				end
			end)
	
			if shouldDisconnect and connection then
				return disconnect()
			end
	
			onCancel(function()
				disconnect()
			end)
		end)
	end
	
	return Promise

    -- End of init

end)

-- out/packages/make/init.lua:
TS.register("out/packages/make/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/packages/make/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	--[[
		*
		* Returns a table wherein an object's writable properties can be specified,
		* while also allowing functions to be passed in which can be bound to a RBXScriptSignal.
	]]
	--[[
		*
		* Instantiates a new Instance of `className` with given `settings`,
		* where `settings` is an object of the form { [K: propertyName]: value }.
		*
		* `settings.Children` is an array of child objects to be parented to the generated Instance.
		*
		* Events can be set to a callback function, which will be connected.
		*
		* `settings.Parent` is always set last.
	]]
	local function Make(className, settings)
		local _0 = settings
		local children = _0.Children
		local parent = _0.Parent
		local instance = Instance.new(className)
		for setting, value in pairs(settings) do
			if setting ~= "Children" and setting ~= "Parent" then
				local _1 = instance
				local prop = _1[setting]
				local _2 = prop
				if typeof(_2) == "RBXScriptSignal" then
					prop:Connect(value)
				else
					instance[setting] = value
				end
			end
		end
		if children then
			for _, child in ipairs(children) do
				child.Parent = instance
			end
		end
		instance.Parent = parent
		return instance
	end
	return Make

    -- End of init

end)

-- out/packages/object-utils/init.lua:
TS.register("out/packages/object-utils/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/packages/object-utils/init.lua")

    -- Start of init

    local HttpService = game:GetService("HttpService")
	
	local Object = {}
	
	function Object.keys(object)
		local result = table.create(#object)
		for key in pairs(object) do
			result[#result + 1] = key
		end
		return result
	end
	
	function Object.values(object)
		local result = table.create(#object)
		for _, value in pairs(object) do
			result[#result + 1] = value
		end
		return result
	end
	
	function Object.entries(object)
		local result = table.create(#object)
		for key, value in pairs(object) do
			result[#result + 1] = { key, value }
		end
		return result
	end
	
	function Object.assign(toObj, ...)
		for i = 1, select("#", ...) do
			local arg = select(i, ...)
			if type(arg) == "table" then
				for key, value in pairs(arg) do
					toObj[key] = value
				end
			end
		end
		return toObj
	end
	
	function Object.copy(object)
		local result = table.create(#object)
		for k, v in pairs(object) do
			result[k] = v
		end
		return result
	end
	
	local function deepCopyHelper(object, encountered)
		local result = table.create(#object)
		encountered[object] = result
	
		for k, v in pairs(object) do
			if type(k) == "table" then
				k = encountered[k] or deepCopyHelper(k, encountered)
			end
	
			if type(v) == "table" then
				v = encountered[v] or deepCopyHelper(v, encountered)
			end
	
			result[k] = v
		end
	
		return result
	end
	
	function Object.deepCopy(object)
		return deepCopyHelper(object, {})
	end
	
	function Object.deepEquals(a, b)
		-- a[k] == b[k]
		for k in pairs(a) do
			local av = a[k]
			local bv = b[k]
			if type(av) == "table" and type(bv) == "table" then
				local result = Object.deepEquals(av, bv)
				if not result then
					return false
				end
			elseif av ~= bv then
				return false
			end
		end
	
		-- extra keys in b
		for k in pairs(b) do
			if a[k] == nil then
				return false
			end
		end
	
		return true
	end
	
	function Object.toString(data)
		return HttpService:JSONEncode(data)
	end
	
	function Object.isEmpty(object)
		return next(object) == nil
	end
	
	function Object.fromEntries(entries)
		local entriesLen = #entries
	
		local result = table.create(entriesLen)
		if entries then
			for i = 1, entriesLen do
				local pair = entries[i]
				result[pair[1]] = pair[2]
			end
		end
		return result
	end
	
	return Object

    -- End of init

end)

-- out/packages/services/init.lua:
TS.register("out/packages/services/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/packages/services/init.lua")

    -- Start of init

    return setmetatable({}, {
		__index = function(self, serviceName)
			local service = game:GetService(serviceName)
			self[serviceName] = service
			return service
		end,
	})

    -- End of init

end)

-- out/packages/zzlib/init.lua:
TS.register("out/packages/zzlib/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/packages/zzlib/init.lua")

    -- Start of init

    -- zzlib - zlib decompression in Lua - Implementation-independent code
	
	-- Copyright (c) 2016-2020 Francois Galea <fgalea at free.fr>
	-- This program is free software. It comes without any warranty, to
	-- the extent permitted by applicable law. You can redistribute it
	-- and/or modify it under the terms of the Do What The Fuck You Want
	-- To Public License, Version 2, as published by Sam Hocevar. See
	-- the COPYING file or http://www.wtfpl.net/ for more details.
	
	
	local unpack = unpack
	local result
	
	local infl do
		local inflate = {}
		
		local bit = bit32
		
		inflate.band = bit.band
		inflate.rshift = bit.rshift
		
		function inflate.bitstream_init(file)
			local bs = {
				file = file,  -- the open file handle
				buf = nil,    -- character buffer
				len = nil,    -- length of character buffer
				pos = 1,      -- position in char buffer
				b = 0,        -- bit buffer
				n = 0,        -- number of bits in buffer
			}
			-- get rid of n first bits
			function bs:flushb(n)
				self.n = self.n - n
				self.b = bit.rshift(self.b,n)
			end
			-- peek a number of n bits from stream
			function bs:peekb(n)
				while self.n < n do
					if self.pos > self.len then
						self.buf = self.file:read(4096)
						self.len = self.buf:len()
						self.pos = 1
					end
					self.b = self.b + bit.lshift(self.buf:byte(self.pos),self.n)
					self.pos = self.pos + 1
					self.n = self.n + 8
				end
				return bit.band(self.b,bit.lshift(1,n)-1)
			end
			-- get a number of n bits from stream
			function bs:getb(n)
				local ret = bs:peekb(n)
				self.n = self.n - n
				self.b = bit.rshift(self.b,n)
				return ret
			end
			-- get next variable-size of maximum size=n element from stream, according to Huffman table
			function bs:getv(hufftable,n)
				local e = hufftable[bs:peekb(n)]
				local len = bit.band(e,15)
				local ret = bit.rshift(e,4)
				self.n = self.n - len
				self.b = bit.rshift(self.b,len)
				return ret
			end
			function bs:close()
				if self.file then
					self.file:close()
				end
			end
			if type(file) == "string" then
				bs.file = nil
				bs.buf = file
			else
				bs.buf = file:read(4096)
			end
			bs.len = bs.buf:len()
			return bs
		end
		
		local function hufftable_create(depths)
			local nvalues = #depths
			local nbits = 1
			local bl_count = {}
			local next_code = {}
			for i=1,nvalues do
				local d = depths[i]
				if d > nbits then
					nbits = d
				end
				bl_count[d] = (bl_count[d] or 0) + 1
			end
			local table = {}
			local code = 0
			bl_count[0] = 0
			for i=1,nbits do
				code = (code + (bl_count[i-1] or 0)) * 2
				next_code[i] = code
			end
			for i=1,nvalues do
				local len = depths[i] or 0
				if len > 0 then
					local e = (i-1)*16 + len
					local code = next_code[len]
					local rcode = 0
					for j=1,len do
						rcode = rcode + bit.lshift(bit.band(1,bit.rshift(code,j-1)),len-j)
					end
					for j=0,2^nbits-1,2^len do
						table[j+rcode] = e
					end
					next_code[len] = next_code[len] + 1
				end
			end
			return table,nbits
		end
		
		local function block_loop(out,bs,nlit,ndist,littable,disttable)
			local lit
			repeat
				lit = bs:getv(littable,nlit)
				if lit < 256 then
					table.insert(out,lit)
				elseif lit > 256 then
					local nbits = 0
					local size = 3
					local dist = 1
					if lit < 265 then
						size = size + lit - 257
					elseif lit < 285 then
						nbits = bit.rshift(lit-261,2)
						size = size + bit.lshift(bit.band(lit-261,3)+4,nbits)
					else
						size = 258
					end
					if nbits > 0 then
						size = size + bs:getb(nbits)
					end
					local v = bs:getv(disttable,ndist)
					if v < 4 then
						dist = dist + v
					else
						nbits = bit.rshift(v-2,1)
						dist = dist + bit.lshift(bit.band(v,1)+2,nbits)
						dist = dist + bs:getb(nbits)
					end
					local p = #out-dist+1
					while size > 0 do
						table.insert(out,out[p])
						p = p + 1
						size = size - 1
					end
				end
			until lit == 256
		end
		
		local function block_dynamic(out,bs)
			local order = { 17, 18, 19, 1, 9, 8, 10, 7, 11, 6, 12, 5, 13, 4, 14, 3, 15, 2, 16 }
			local hlit = 257 + bs:getb(5)
			local hdist = 1 + bs:getb(5)
			local hclen = 4 + bs:getb(4)
			local depths = {}
			for i=1,hclen do
				local v = bs:getb(3)
				depths[order[i]] = v
			end
			for i=hclen+1,19 do
				depths[order[i]] = 0
			end
			local lengthtable,nlen = hufftable_create(depths)
			local i=1
			while i<=hlit+hdist do
				local v = bs:getv(lengthtable,nlen)
				if v < 16 then
					depths[i] = v
					i = i + 1
				elseif v < 19 then
					local nbt = {2,3,7}
					local nb = nbt[v-15]
					local c = 0
					local n = 3 + bs:getb(nb)
					if v == 16 then
						c = depths[i-1]
					elseif v == 18 then
						n = n + 8
					end
					for j=1,n do
						depths[i] = c
						i = i + 1
					end
				else
					error("wrong entry in depth table for literal/length alphabet: "..v);
				end
			end
			local litdepths = {} for i=1,hlit do table.insert(litdepths,depths[i]) end
			local littable,nlit = hufftable_create(litdepths)
			local distdepths = {} for i=hlit+1,#depths do table.insert(distdepths,depths[i]) end
			local disttable,ndist = hufftable_create(distdepths)
			block_loop(out,bs,nlit,ndist,littable,disttable)
		end
		
		local function block_static(out,bs)
			local cnt = { 144, 112, 24, 8 }
			local dpt = { 8, 9, 7, 8 }
			local depths = {}
			for i=1,4 do
				local d = dpt[i]
				for j=1,cnt[i] do
					table.insert(depths,d)
				end
			end
			local littable,nlit = hufftable_create(depths)
			depths = {}
			for i=1,32 do
				depths[i] = 5
			end
			local disttable,ndist = hufftable_create(depths)
			block_loop(out,bs,nlit,ndist,littable,disttable)
		end
		
		local function block_uncompressed(out,bs)
			bs:flushb(bit.band(bs.n,7))
			local len = bs:getb(16)
			if bs.n > 0 then
				error("Unexpected.. should be zero remaining bits in buffer.")
			end
			local nlen = bs:getb(16)
			if bit.bxor(len,nlen) ~= 65535 then
				error("LEN and NLEN don't match")
			end
			for i=bs.pos,bs.pos+len-1 do
				table.insert(out,bs.buf:byte(i,i))
			end
			bs.pos = bs.pos + len
		end
		
		function inflate.main(bs)
			local last,type
			local output = {}
			repeat
				local block
				last = bs:getb(1)
				type = bs:getb(2)
				if type == 0 then
					block_uncompressed(output,bs)
				elseif type == 1 then
					block_static(output,bs)
				elseif type == 2 then
					block_dynamic(output,bs)
				else
					error("unsupported block type")
				end
			until last == 1
			bs:flushb(bit.band(bs.n,7))
			return output
		end
		
		local crc32_table
		function inflate.crc32(s,crc)
			if not crc32_table then
				crc32_table = {}
				for i=0,255 do
					local r=i
					for j=1,8 do
						r = bit.bxor(bit.rshift(r,1),bit.band(0xedb88320,bit.bnot(bit.band(r,1)-1)))
					end
					crc32_table[i] = r
				end
			end
			crc = bit.bnot(crc or 0)
			for i=1,#s do
				local c = s:byte(i)
				crc = bit.bxor(crc32_table[bit.bxor(c,bit.band(crc,0xff))],bit.rshift(crc,8))
			end
			crc = bit.bnot(crc)
			if crc<0 then
				-- in Lua < 5.2, sign extension was performed
				crc = crc + 4294967296
			end
			return crc
		end
		
		infl = inflate
	end
	
	local zzlib = {}
	
	local function arraytostr(array)
		local tmp = {}
		local size = #array
		local pos = 1
		local imax = 1
		while size > 0 do
			local bsize = size>=2048 and 2048 or size
			local s = string.char(unpack(array,pos,pos+bsize-1))
			pos = pos + bsize
			size = size - bsize
			local i = 1
			while tmp[i] do
				s = tmp[i]..s
				tmp[i] = nil
				i = i + 1
			end
			if i > imax then
				imax = i
			end
			tmp[i] = s
		end
		local str = ""
		for i=1,imax do
			if tmp[i] then
				str = tmp[i]..str
			end
		end
		return str
	end
	
	local function inflate_gzip(bs)
		local id1,id2,cm,flg = bs.buf:byte(1,4)
		if id1 ~= 31 or id2 ~= 139 then
			error("invalid gzip header")
		end
		if cm ~= 8 then
			error("only deflate format is supported")
		end
		bs.pos=11
		if infl.band(flg,4) ~= 0 then
			local xl1,xl2 = bs.buf.byte(bs.pos,bs.pos+1)
			local xlen = xl2*256+xl1
			bs.pos = bs.pos+xlen+2
		end
		if infl.band(flg,8) ~= 0 then
			local pos = bs.buf:find("\0",bs.pos)
			bs.pos = pos+1
		end
		if infl.band(flg,16) ~= 0 then
			local pos = bs.buf:find("\0",bs.pos)
			bs.pos = pos+1
		end
		if infl.band(flg,2) ~= 0 then
			-- TODO: check header CRC16
			bs.pos = bs.pos+2
		end
		local result = arraytostr(infl.main(bs))
		local crc = bs:getb(8)+256*(bs:getb(8)+256*(bs:getb(8)+256*bs:getb(8)))
		bs:close()
		if crc ~= infl.crc32(result) then
			error("checksum verification failed")
		end
		return result
	end
	
	-- compute Adler-32 checksum
	local function adler32(s)
		local s1 = 1
		local s2 = 0
		for i=1,#s do
			local c = s:byte(i)
			s1 = (s1+c)%65521
			s2 = (s2+s1)%65521
		end
		return s2*65536+s1
	end
	
	local function inflate_zlib(bs)
		local cmf = bs.buf:byte(1)
		local flg = bs.buf:byte(2)
		if (cmf*256+flg)%31 ~= 0 then
			error("zlib header check bits are incorrect")
		end
		if infl.band(cmf,15) ~= 8 then
			error("only deflate format is supported")
		end
		if infl.rshift(cmf,4) ~= 7 then
			error("unsupported window size")
		end
		if infl.band(flg,32) ~= 0 then
			error("preset dictionary not implemented")
		end
		bs.pos=3
		local result = arraytostr(infl.main(bs))
		local adler = ((bs:getb(8)*256+bs:getb(8))*256+bs:getb(8))*256+bs:getb(8)
		bs:close()
		if adler ~= adler32(result) then
			error("checksum verification failed")
		end
		return result
	end
	
	function zzlib.gunzipf(filename)
		local file,err = io.open(filename,"rb")
		if not file then
			return nil,err
		end
		return inflate_gzip(infl.bitstream_init(file))
	end
	
	function zzlib.gunzip(str)
		return inflate_gzip(infl.bitstream_init(str))
	end
	
	function zzlib.inflate(str)
		return inflate_zlib(infl.bitstream_init(str))
	end
	
	local function int2le(str,pos)
		local a,b = str:byte(pos,pos+1)
		return b*256+a
	end
	
	local function int4le(str,pos)
		local a,b,c,d = str:byte(pos,pos+3)
		return ((d*256+c)*256+b)*256+a
	end
	
	function zzlib.unzip(buf)
		local p = #buf-21 - #("00bd21b8cc3a2e233276f5a70b57ca7347fdf520")
		local quit = false
		local fileMap = {}
		if int4le(buf,p) ~= 0x06054b50 then
			-- not sure there is a reliable way to locate the end of central directory record
			-- if it has a variable sized comment field
			error(".ZIP file comments not supported")
		end
		local cdoffset = int4le(buf,p+16)
		local nfiles = int2le(buf,p+10)
		p = cdoffset+1
		for i=1,nfiles do
			if int4le(buf,p) ~= 0x02014b50 then
				error("invalid central directory header signature")
			end
			local flag = int2le(buf,p+8)
			local method = int2le(buf,p+10)
			local crc = int4le(buf,p+16)
			local namelen = int2le(buf,p+28)
			local name = buf:sub(p+46,p+45+namelen)
			if true then
				local headoffset = int4le(buf,p+42)
				local p = 1+headoffset
				if int4le(buf,p) ~= 0x04034b50 then
					error("invalid local header signature")
				end
				local csize = int4le(buf,p+18)
				local extlen = int2le(buf,p+28)
				p = p+30+namelen+extlen
				if method == 0 then
					-- no compression
					result = buf:sub(p,p+csize-1)
					fileMap[name] = result
				else
					-- DEFLATE compression
					local bs = infl.bitstream_init(buf)
					bs.pos = p
					result = arraytostr(infl.main(bs))
					fileMap[name] = result
				end
				if crc ~= infl.crc32(result) then
					error("checksum verification failed")
				end
			end
			p = p+46+namelen+int2le(buf,p+30)+int2le(buf,p+32)
		end
		return fileMap
	end
	
	return zzlib

    -- End of init

end)

-- out/utils/common/extract.lua:
TS.register("out/utils/common/extract.lua", "extract", function()

    -- Setup
    local script = TS.get("out/utils/common/extract.lua")

    -- Start of extract

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local zzlib = TS.import(script, script.Parent.Parent.Parent, "packages", "zzlib")
	local _0 = TS.import(script, script.Parent.Parent, "filesystem")
	local formatPath = _0.formatPath
	local makeFiles = _0.makeFiles
	--[[
		*
		* Extracts files from raw zip data.
		* @param rawData Raw zip data.
		* @param target The directory to extract files to.
		* @param ungroup
		* If the zip file contains a single directory with everthing in it, it may be useful to
		* extract data excluding the folder. This parameter controls whether the top directory
		* is ignored when extracting.
	]]
	local function extract(rawData, target, ungroup)
		local zipData = zzlib.unzip(rawData)
		local fileArray = {}
		-- Convert the path-content map to a file array
		for path, contents in pairs(zipData) do
			local _1 = fileArray
			local _2 = { path, contents }
			-- ▼ Array.push ▼
			_1[#_1 + 1] = _2
			-- ▲ Array.push ▲
		end
		-- Make the files at the given target.
		-- If 'ungroup' is true, excludes the first folder.
		makeFiles(fileArray, function(path)
			return formatPath(target) .. (ungroup and ((string.gsub(path, "^([^/]*/)", ""))) or path)
		end)
	end
	return {
		extract = extract,
	}

    -- End of extract

end)

-- out/utils/common/http.lua:
TS.register("out/utils/common/http.lua", "http", function()

    -- Setup
    local script = TS.get("out/utils/common/http.lua")

    -- Start of http

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	--[[
		* File: http.ts
		* File Created: Wednesday, 2nd June 2021 6:43:27 pm
		* Author: richard
	]]
	local httpRequest = TS.import(script, script.Parent.Parent.Parent, "globals").httpRequest
	-- * Sends an HTTP GET request.
	local get = TS.Promise.promisify(function(url)
		return game:HttpGetAsync(url)
	end)
	-- * Sends an HTTP POST request.
	local post = TS.Promise.promisify(function(url)
		return game:HttpPostAsync(url)
	end)
	-- * Makes an HTTP request.
	local request = TS.Promise.promisify(function(options)
		return httpRequest(options)
	end)
	return {
		get = get,
		post = post,
		request = request,
	}

    -- End of http

end)

-- out/utils/common/openJson.lua:
TS.register("out/utils/common/openJson.lua", "openJson", function()

    -- Setup
    local script = TS.get("out/utils/common/openJson.lua")

    -- Start of openJson

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local HttpService = TS.import(script, script.Parent.Parent.Parent, "packages", "services").HttpService
	local makeFile = TS.import(script, script.Parent.Parent, "filesystem").makeFile
	-- * An object to read and write to JSON files.
	--[[
		*
		* Creates an object to read and write JSON data in an easier way.
		* @param file The JSON file to open.
		* @returns A JSON data object.
	]]
	local function openJson(file)
		return {
			file = file,
			data = nil,
			save = function(self)
				if self.data ~= nil then
					makeFile(file, HttpService:JSONEncode(self.data))
				end
			end,
			load = function(self)
				local data = HttpService:JSONDecode(readfile(file))
				self.data = data
				return data
			end,
		}
	end
	return {
		openJson = openJson,
	}

    -- End of openJson

end)

-- out/utils/filesystem/Directory.lua:
TS.register("out/utils/filesystem/Directory.lua", "Directory", function()

    -- Setup
    local script = TS.get("out/utils/filesystem/Directory.lua")

    -- Start of Directory

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local File = TS.import(script, script.Parent, "File").File
	local formatPath = TS.import(script, script.Parent, "makeFiles").formatPath
	-- * Describes directory metadata based on a given file location.
	-- * Creates a new Directory object.
	local function Directory(location, origin)
		-- Add a trailing slash if missing
		location = formatPath(location)
		return {
			descriptorType = "Directory",
			location = location,
			origin = origin,
			name = (string.match(location, "([^/]+)/*$")),
			locateFiles = function(...)
				local files = { ... }
				for _, file in ipairs(files) do
					local target = location .. file
					if isfile(target) then
						return File(target, origin)
					end
				end
			end,
		}
	end
	return {
		Directory = Directory,
	}

    -- End of Directory

end)

-- out/utils/filesystem/File.lua:
TS.register("out/utils/filesystem/File.lua", "File", function()

    -- Setup
    local script = TS.get("out/utils/filesystem/File.lua")

    -- Start of File

    -- Compiled with roblox-ts v1.1.1
	-- * Describes file metadata based on a given file location.
	-- * Creates a new File object.
	local function File(location, origin)
		-- * **script.client.lua**
		local name = (string.match(location, "([^/]+)/*$"))
		-- * **script**.client.lua
		local _0 = ((string.match(name, "^([^%.]+)")))
		if _0 == nil then
			_0 = ""
		end
		local shortName = _0
		-- * script.client.**lua**
		local extension = (string.match(name, "%.([^%.]+)$"))
		-- * **script.client**.lua
		local _1
		if extension ~= nil then
			local _2 = name
			local _3 = -#extension - 2
			_1 = string.sub(_2, 1, _3)
		else
			_1 = name
		end
		local extendedName = _1
		-- * script.**client.lua**
		local fileType = (string.match(name, "%.(.*)"))
		return {
			descriptorType = "File",
			location = location,
			origin = origin,
			name = (string.match(location, "([^/]+)/*$")),
			shortName = shortName,
			extendedName = extendedName,
			extension = extension,
			type = fileType,
		}
	end
	return {
		File = File,
	}

    -- End of File

end)

-- out/utils/filesystem/init.lua:
TS.register("out/utils/filesystem/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/utils/filesystem/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	for _0, _1 in pairs(TS.import(script, script, "Directory")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "File")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "makeFiles")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "types")) do
		exports[_0] = _1
	end
	return exports

    -- End of init

end)

-- out/utils/filesystem/makeFiles.lua:
TS.register("out/utils/filesystem/makeFiles.lua", "makeFiles", function()

    -- Setup
    local script = TS.get("out/utils/filesystem/makeFiles.lua")

    -- Start of makeFiles

    -- Compiled with roblox-ts v1.1.1
	-- * Adds a trailing slash if there is no extension.
	local function formatPath(path)
		path = (string.gsub(path, "\\", "/"))
		if (string.match(path, "%.([^%./]+)$")) == nil and string.sub(path, -1) ~= "/" then
			return path .. "/"
		else
			return path
		end
	end
	-- * Append a file with no extension with `.file`.
	local function addMissingExtension(file)
		local hasExtension = (string.match(string.reverse(file), "^([^%./]+%.)")) ~= nil
		if not hasExtension then
			return file .. ".file"
		else
			return file
		end
	end
	--[[
		*
		* Safely makes a folder by creating every parent before the final directory.
		* Ignores the final file if there is no trailing slash.
		* @param location The path of the directory to make.
	]]
	local function makeFolder(location)
		local absolutePath = ""
		for name in string.gmatch(location, "[^/]*/") do
			absolutePath ..= tostring(name)
			makefolder(absolutePath)
		end
	end
	--[[
		*
		* Safely makes a file by creating every parent before the file.
		* Adds a `.file` extension if there is no extension.
		* @param location The path of the file to make.
		* @param content Optional file contents.
	]]
	local function makeFile(file, content)
		makeFolder(file)
		local _0 = addMissingExtension(file)
		local _1 = content
		if _1 == nil then
			_1 = ""
		end
		writefile(_0, _1)
	end
	-- * Creates files from a list of paths.
	local function makeFiles(fileArray, map)
		-- Create the files and directories. No sorts need to be performed because parent folders
		-- in each path are made before the file/folder itself.
		for _, _0 in ipairs(fileArray) do
			local path = _0[1]
			local contents = _0[2]
			if string.sub(path, -1) == "/" and not isfolder(path) then
				local _1
				if map then
					_1 = makeFolder(map(path))
				else
					_1 = makeFolder(path)
				end
			elseif string.sub(path, -1) ~= "/" and not isfile(path) then
				local _1
				if map then
					_1 = makeFile(map(path), contents)
				else
					_1 = makeFile(path, contents)
				end
			end
		end
	end
	return {
		formatPath = formatPath,
		addMissingExtension = addMissingExtension,
		makeFolder = makeFolder,
		makeFile = makeFile,
		makeFiles = makeFiles,
	}

    -- End of makeFiles

end)

-- out/utils/filesystem/types.lua:
TS.register("out/utils/filesystem/types.lua", "types", function()

    -- Setup
    local script = TS.get("out/utils/filesystem/types.lua")

    -- Start of types

    -- Compiled with roblox-ts v1.1.1
	--[[
		*
		* File types that can be attributed to file descriptors.
		* Enums add extra functionaliy that goes unused when transpiled.
	]]
	-- * Base interface for file descriptors.
	-- * Data used to construct files and directories.
	-- * Prevent the transpiled Lua code from returning nil!
	local _ = nil
	return {
		_ = _,
	}

    -- End of types

end)

-- out/utils/github-release/getRelease.lua:
TS.register("out/utils/github-release/getRelease.lua", "getRelease", function()

    -- Setup
    local script = TS.get("out/utils/github-release/getRelease.lua")

    -- Start of getRelease

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local HttpService = TS.import(script, script.Parent.Parent.Parent, "packages", "services").HttpService
	local http = TS.import(script, script.Parent.Parent, "common", "http")
	--[[
		*
		* Gets a list of releases for the Github repository.
		* Automatically excludes drafts, but excluding prereleases is optional.
		* @param owner The owner of the repository.
		* @param repo The repository name.
		* @param filterRelease Function to filter the release list.
		* @returns A list of Releases for the Github repository.
	]]
	local getReleases = TS.async(function(owner, repo, filterRelease)
		if filterRelease == nil then
			filterRelease = function(release)
				return not release.draft
			end
		end
		local response = TS.await(http.request({
			Url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/releases",
			Headers = {
				["User-Agent"] = "rostruct",
			},
		}))
		local _0 = response.Success
		local _1 = response.StatusMessage
		assert(_0, _1)
		local releases = HttpService:JSONDecode(response.Body)
		local _2 = releases
		local _3 = filterRelease
		-- ▼ ReadonlyArray.filter ▼
		local _4 = {}
		local _5 = 0
		for _6, _7 in ipairs(_2) do
			if _3(_7, _6 - 1, _2) == true then
				_5 += 1
				_4[_5] = _7
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		return _4
	end)
	--[[
		*
		* Gets a specific release for the given repository.
		* This function does not get prereleases!
		* @param owner The owner of the repository.
		* @param repo The repository name.
		* @param tag The release tag to retrieve.
		* @returns A list of Releases for the Github repository.
	]]
	local getRelease = TS.async(function(owner, repo, tag)
		local response = TS.await(http.request({
			Url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/releases/tags/" .. tag,
			Headers = {
				["User-Agent"] = "rostruct",
			},
		}))
		local _0 = response.Success
		local _1 = response.StatusMessage
		assert(_0, _1)
		return HttpService:JSONDecode(response.Body)
	end)
	--[[
		*
		* Gets the latest release for the given repository.
		* This function does not get prereleases!
		* @param owner The owner of the repository.
		* @param repo The repository name.
		* @returns A list of Releases for the Github repository.
	]]
	local getLatestRelease = TS.async(function(owner, repo)
		local response = TS.await(http.request({
			Url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/releases/latest",
			Headers = {
				["User-Agent"] = "rostruct",
			},
		}))
		local _0 = response.Success
		local _1 = response.StatusMessage
		assert(_0, _1)
		return HttpService:JSONDecode(response.Body)
	end)
	return {
		getReleases = getReleases,
		getRelease = getRelease,
		getLatestRelease = getLatestRelease,
	}

    -- End of getRelease

end)

-- out/utils/github-release/identify.lua:
TS.register("out/utils/github-release/identify.lua", "identify", function()

    -- Setup
    local script = TS.get("out/utils/github-release/identify.lua")

    -- Start of identify

    -- Compiled with roblox-ts v1.1.1
	--[[
		*
		* Creates a string identifier for the given download configuration.
		* @param owner The owner of the repository.
		* @param repo The repository name.
		* @param tag Optional release tag. Defaults to `"LATEST"`.
		* @param asset Optional release asset file. Defaults to `"ZIPBALL"`.
		* @returns An identifier for the given parameters.
	]]
	local function identify(owner, repo, tag, asset)
		local template = "%s-%s-%s-%s"
		local _0 = template
		local _1 = string.lower(owner)
		local _2 = string.lower(repo)
		local _3 = tag ~= nil and string.lower(tag) or "LATEST"
		local _4 = asset ~= nil and string.lower(asset) or "ZIPBALL"
		return string.format(_0, _1, _2, _3, _4)
	end
	return {
		identify = identify,
	}

    -- End of identify

end)

-- out/utils/github-release/init.lua:
TS.register("out/utils/github-release/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/utils/github-release/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	for _0, _1 in pairs(TS.import(script, script, "getRelease")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "identify")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "types")) do
		exports[_0] = _1
	end
	return exports

    -- End of init

end)

-- out/utils/github-release/types.lua:
TS.register("out/utils/github-release/types.lua", "types", function()

    -- Setup
    local script = TS.get("out/utils/github-release/types.lua")

    -- Start of types

    -- Compiled with roblox-ts v1.1.1
	--[[
		*
		* Information about the latest release of a given Github repository.
		* See this [example](https://api.github.com/repos/Roblox/roact/releases/latest).
	]]
	-- * Prevent the transpiled Lua code from returning nil!
	local _ = nil
	return {
		_ = _,
	}

    -- End of types

end)

-- End of Rostruct v0.1.4-alpha

local Rostruct = TS.initialize("init")

-- Download the latest release to local files:
Rostruct.DownloadLatestRelease("richie0866", "MidiPlayer")
    :andThen(function(download)
        -- Require and set up:
        local project = Rostruct.Deploy(download.Location .. "src/")
        project.Instance.Name = "MidiPlayer"
    end)
