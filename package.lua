--[[
	Originally RuntimeLib.lua supplied by roblox-ts, modified for use when bundled.
	The original source of this module can be found in the link below, as well as the license:

	https://github.com/roblox-ts/roblox-ts/blob/master/lib/RuntimeLib.lua
	https://github.com/roblox-ts/roblox-ts/blob/master/LICENSE
]]

local TS = {
	_G = {};
}

setmetatable(TS, {
	__index = function(self, k)
		if k == "Promise" then
			self.Promise = TS.initialize("modules", "Promise")
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
	local moduleInit = parentPtr.path .. table.concat({...}, "/") .. "/init.lua"
	local module = assert(
		modulesByPath[modulePath] or modulesByPath[moduleInit],
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

-- opcall

function TS.opcall(func, ...)
	local success, valueOrErr = pcall(func, ...)
	if success then
		return {
			success = true,
			value = valueOrErr,
		}
	else
		return {
			success = false,
			error = valueOrErr,
		}
	end
end

-- out/bootstrap.lua:
TS.register("out/bootstrap.lua", "bootstrap", function()

    -- Setup
    local script = TS.get("out/bootstrap.lua")

    -- Start of bootstrap

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local makeUtils = TS.import(script, script.Parent, "utils", "file-utils").makeUtils
	-- * Assigns common folders to a keyword.
	local Shortcut = {
		ROOT = "rostruct/",
		CACHE = "rostruct/cache/",
		RELEASE_CACHE = "rostruct/cache/releases/",
		RELEASE_TAGS = "rostruct/cache/release_tags.json",
	}
	-- * Gets a Rostruct path from a keyword.
	local getRostructPath = function(keyword)
		return Shortcut[keyword]
	end
	-- * Sets up core files for Rostruct.
	local bootstrap = function()
		return makeUtils.makeFiles({ { "rostruct/cache/releases/", "" }, { "rostruct/cache/release_tags.json", "{}" } })
	end
	return {
		getRostructPath = getRostructPath,
		bootstrap = bootstrap,
	}

    -- End of bootstrap

end)

-- out/init.lua:
TS.register("out/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	--[[
		*
		* Build your Lua projects from the filesystem.
		* @author 0866
	]]
	local bootstrap = TS.import(script, script, "bootstrap").bootstrap
	local Package = TS.import(script, script, "Package").Package
	local _0 = TS.import(script, script, "utils", "fetch-github-release")
	local clearReleaseCache = _0.clearReleaseCache
	local downloadLatestRelease = _0.downloadLatestRelease
	local downloadRelease = _0.downloadRelease
	bootstrap()
	-- * Clears the GitHub Release cache.
	local clearCache = function()
		return clearReleaseCache()
	end
	--[[
		*
		* Creates a new Rostruct Package.
		* @param root A path to the project directory.
		* @returns A new Package object.
	]]
	local open = function(root)
		return Package.new(root)
	end
	--[[
		*
		* Downloads and builds a release from the given repository.
		* If `asset` is undefined, it downloads source files through the zipball URL.
		* Automatically extracts .zip files.
		*
		* @param owner The owner of the repository.
		* @param repo The name of the repository.
		* @param tag The tag version to download.
		* @param asset Optional asset to download; If not specified, it downloads the source files.
		*
		* @returns A promise that resolves with a Package object, with the `fetchInfo` field.
	]]
	local fetch = TS.async(function(...)
		local args = { ... }
		return Package.fromFetch(TS.await(downloadRelease(unpack(args))))
	end)
	--[[
		*
		* Downloads and builds a release from the given repository.
		* If `asset` is undefined, it downloads source files through the zipball URL.
		* Automatically extracts .zip files.
		*
		* @param owner The owner of the repository.
		* @param repo The name of the repository.
		* @param tag The tag version to download.
		* @param asset Optional asset to download; If not specified, it downloads the source files.
		*
		* @returns A new Package object, with the `fetchInfo` field.
	]]
	local fetchAsync = function(...)
		local args = { ... }
		return Package.fromFetch(downloadRelease(unpack(args)):expect())
	end
	--[[
		*
		* **This function does not download prereleases or drafts.**
		*
		* Downloads and builds the latest release release from the given repository.
		* If `asset` is undefined, it downloads source files through the zipball URL.
		* Automatically extracts .zip files.
		*
		* @param owner The owner of the repository.
		* @param repo The name of the repository.
		* @param asset Optional asset to download; If not specified, it downloads the source files.
		*
		* @returns A promise that resolves with a Package object, with the `fetchInfo` field.
	]]
	local fetchLatest = TS.async(function(...)
		local args = { ... }
		return Package.fromFetch(TS.await(downloadLatestRelease(unpack(args))))
	end)
	--[[
		*
		* **This function does not download prereleases or drafts.**
		*
		* Downloads and builds the latest release release from the given repository.
		* If `asset` is undefined, it downloads source files through the zipball URL.
		* Automatically extracts .zip files.
		*
		* @param owner The owner of the repository.
		* @param repo The name of the repository.
		* @param asset Optional asset to download; If not specified, it downloads the source files.
		*
		* @returns A new Package object, with the `fetchInfo` field.
	]]
	local fetchLatestAsync = function(...)
		local args = { ... }
		return Package.fromFetch(downloadLatestRelease(unpack(args)):expect())
	end
	return {
		clearCache = clearCache,
		open = open,
		fetch = fetch,
		fetchAsync = fetchAsync,
		fetchLatest = fetchLatest,
		fetchLatestAsync = fetchLatestAsync,
	}

    -- End of init

end)

-- out/Package.lua:
TS.register("out/Package.lua", "Package", function()

    -- Setup
    local script = TS.get("out/Package.lua")

    -- Start of Package

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local _0 = TS.import(script, script.Parent, "core")
	local Session = _0.Session
	local VirtualScript = _0.VirtualScript
	local pathUtils = TS.import(script, script.Parent, "utils", "file-utils").pathUtils
	local Make = TS.import(script, script.Parent, "modules", "make")
	-- * Transforms files into Roblox objects and handles runtime.
	local Package
	do
		Package = setmetatable({}, {
			__tostring = function()
				return "Package"
			end,
		})
		Package.__index = Package
		function Package.new(...)
			local self = setmetatable({}, Package)
			self:constructor(...)
			return self
		end
		function Package:constructor(root, fetchInfo)
			self.tree = Make("Folder", {
				Name = "Tree",
			})
			local _1 = type(root) == "string"
			assert(_1, "(Package) The path must be a string")
			local _2 = isfolder(root)
			local _3 = "(Package) The path '" .. root .. "' must be a valid directory"
			assert(_2, _3)
			self.root = pathUtils.formatPath(root)
			self.session = Session.new(root)
			self.fetchInfo = fetchInfo
		end
		function Package:build(fileOrFolder, props)
			if fileOrFolder == nil then
				fileOrFolder = ""
			end
			local _1 = isfile(self.root .. fileOrFolder) or isfolder(self.root .. fileOrFolder)
			local _2 = "(Package.build) The path '" .. self.root .. fileOrFolder .. "' must be a file or folder"
			assert(_1, _2)
			local instance = self.session:build(fileOrFolder)
			-- Set object properties
			if props ~= nil then
				for property, value in pairs(props) do
					instance[property] = value
				end
			end
			instance.Parent = self.tree
			return instance
		end
		function Package:start()
			return self.session:simulate()
		end
		Package.require = TS.async(function(self, module)
			local _1 = module
			local _2 = _1.ClassName == "ModuleScript"
			local _3 = "(Package.require) '" .. tostring(module) .. "' must be a module"
			assert(_2, _3)
			local _4 = module:IsDescendantOf(self.tree)
			local _5 = "(Package.require) '" .. tostring(module) .. "' must be a descendant of Package.tree"
			assert(_4, _5)
			return VirtualScript:requireFromInstance(module)
		end)
		function Package:requireAsync(module)
			return self:require(module):expect()
		end
		Package.fromFetch = function(fetchInfo)
			return Package.new(fetchInfo.location, fetchInfo)
		end
	end
	return {
		Package = Package,
	}

    -- End of Package

end)

-- out/api/compatibility.lua:
TS.register("out/api/compatibility.lua", "compatibility", function()

    -- Setup
    local script = TS.get("out/api/compatibility.lua")

    -- Start of compatibility

    -- Compiled with roblox-ts v1.1.1
	-- Makes an HTTP request
	local _0 = request
	if not (_0 ~= 0 and _0 == _0 and _0 ~= "" and _0) then
		_0 = syn.request
	end
	local httpRequest = _0
	-- Gets an asset by moving it to Roblox's content folder
	local _1 = getcustomasset
	if not (_1 ~= 0 and _1 == _1 and _1 ~= "" and _1) then
		_1 = getsynasset
	end
	local getContentId = _1
	return {
		httpRequest = httpRequest,
		getContentId = getContentId,
	}

    -- End of compatibility

end)

-- out/api/init.lua:
TS.register("out/api/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/api/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	for _0, _1 in pairs(TS.import(script, script, "compatibility")) do
		exports[_0] = _1
	end
	return exports

    -- End of init

end)

-- out/core/init.lua:
TS.register("out/core/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/core/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	exports.build = TS.import(script, script, "build").build
	exports.Store = TS.import(script, script, "Store").Store
	exports.Session = TS.import(script, script, "Session").Session
	exports.VirtualScript = TS.import(script, script, "VirtualScript").VirtualScript
	return exports

    -- End of init

end)

-- out/core/Session.lua:
TS.register("out/core/Session.lua", "Session", function()

    -- Setup
    local script = TS.get("out/core/Session.lua")

    -- Start of Session

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local Store = TS.import(script, script.Parent, "Store").Store
	local HttpService = TS.import(script, script.Parent.Parent, "modules", "services").HttpService
	local buildRoblox = TS.import(script, script.Parent, "build").build
	-- * Class used to transform files into a Roblox instance tree.
	local Session
	do
		Session = setmetatable({}, {
			__tostring = function()
				return "Session"
			end,
		})
		Session.__index = Session
		function Session.new(...)
			local self = setmetatable({}, Session)
			self:constructor(...)
			return self
		end
		function Session:constructor(root)
			self.root = root
			self.sessionId = HttpService:GenerateGUID(false)
			self.virtualScripts = {}
			local _0 = Session.sessions
			local _1 = self.sessionId
			local _2 = self
			-- ▼ Map.set ▼
			_0[_1] = _2
			-- ▲ Map.set ▲
		end
		function Session:fromSessionId(sessionId)
			local _0 = self.sessions
			local _1 = sessionId
			return _0[_1]
		end
		function Session:virtualScriptAdded(virtualScript)
			local _0 = self.virtualScripts
			local _1 = virtualScript
			-- ▼ Array.push ▼
			_0[#_0 + 1] = _1
			-- ▲ Array.push ▲
		end
		function Session:build(dir)
			if dir == nil then
				dir = ""
			end
			local _0 = isfile(self.root .. dir) or isfolder(self.root .. dir)
			local _1 = "The path '" .. self.root .. dir .. "' must be a file or folder"
			assert(_0, _1)
			-- 'buildRoblox' should always return an Instance because 'dir' is a directory
			return buildRoblox(self, self.root .. dir)
		end
		function Session:simulate()
			local executingPromises = {}
			local _0 = #self.virtualScripts > 0
			assert(_0, "This session cannot start because no LocalScripts were found.")
			for _, v in ipairs(self.virtualScripts) do
				if v.instance:IsA("LocalScript") then
					local _1 = executingPromises
					local _2 = v:deferExecutor():andThenReturn(v.instance)
					-- ▼ Array.push ▼
					_1[#_1 + 1] = _2
					-- ▲ Array.push ▲
				end
			end
			-- Define as constant because the typing for 'Promise.all' is funky
			local promise = TS.Promise.all(executingPromises):timeout(10)
			return promise
		end
		Session.sessions = Store:getStore("Sessions")
	end
	return {
		Session = Session,
	}

    -- End of Session

end)

-- out/core/Store.lua:
TS.register("out/core/Store.lua", "Store", function()

    -- Setup
    local script = TS.get("out/core/Store.lua")

    -- Start of Store

    -- Compiled with roblox-ts v1.1.1
	-- Ensures that stores persist between sessions.
	local _0
	if getgenv().RostructStore ~= nil then
		_0 = (getgenv().RostructStore)
	else
		local _1 = getgenv()
		_1.RostructStore = {}
		_0 = (_1.RostructStore)
	end
	local stores = _0
	-- * Stores persistent data between sessions.
	local Store = {
		getStore = function(self, storeName)
			local _1 = stores
			local _2 = storeName
			if _1[_2] ~= nil then
				local _3 = stores
				local _4 = storeName
				return _3[_4]
			end
			local store = {}
			local _3 = stores
			local _4 = storeName
			local _5 = store
			-- ▼ Map.set ▼
			_3[_4] = _5
			-- ▲ Map.set ▲
			return store
		end,
	}
	return {
		Store = Store,
	}

    -- End of Store

end)

-- out/core/types.lua:
TS.register("out/core/types.lua", "types", function()

    -- Setup
    local script = TS.get("out/core/types.lua")

    -- Start of types

    -- Compiled with roblox-ts v1.1.1
	-- * A function that gets called when a VirtualScript is executed.
	-- * Base environment for VirtualScript instances.
	return nil

    -- End of types

end)

-- out/core/VirtualScript.lua:
TS.register("out/core/VirtualScript.lua", "VirtualScript", function()

    -- Setup
    local script = TS.get("out/core/VirtualScript.lua")

    -- Start of VirtualScript

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local Store = TS.import(script, script.Parent, "Store").Store
	local HttpService = TS.import(script, script.Parent.Parent, "modules", "services").HttpService
	-- * Maps scripts to the module they're loading, like a history of `[Id of script who loaded]: Id of module`
	local currentlyLoading = {}
	--[[
		*
		* Gets the dependency chain of the VirtualScript.
		* @param module The starting VirtualScript.
		* @param depth The depth of the cyclic reference.
		* @returns A string containing the paths of all VirtualScripts required until `currentModule`.
	]]
	local function getTraceback(module, depth)
		local traceback = module:getPath()
		do
			local _0 = 0
			while _0 < depth do
				local i = _0
				-- Because the references are cyclic, there will always be
				-- a module loading in 'module'.
				local _1 = currentlyLoading
				local _2 = module
				module = _1[_2]
				traceback ..= "\n\t\t⇒ " .. module:getPath()
				_0 = i
				_0 += 1
			end
		end
		return traceback
	end
	--[[
		*
		* Check to see if the module is part of a a circular reference.
		* @param module The starting VirtualScript.
		* @returns Whether the dependency chain is recursive, and the depth.
	]]
	local function checkTraceback(module)
		local currentModule = module
		local depth = 0
		while currentModule do
			depth += 1
			local _0 = currentlyLoading
			local _1 = currentModule
			currentModule = _0[_1]
			-- If the loop reaches 'module' again, there is a circular reference.
			if module == currentModule then
				error(("Requested module '" .. module:getPath() .. "' was required recursively!\n\n" .. "\tChain: " .. getTraceback(module, depth)))
			end
		end
	end
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
		function VirtualScript:constructor(instance, path, root, rawSource)
			if rawSource == nil then
				rawSource = readfile(path)
			end
			self.instance = instance
			self.path = path
			self.root = root
			self.rawSource = rawSource
			self.id = "VirtualScript-" .. HttpService:GenerateGUID(false)
			self.jobComplete = false
			-- Initialize property members
			self.scriptEnvironment = {
				script = instance,
				require = function(obj)
					return VirtualScript:loadModule(obj, self)
				end,
				_PATH = path,
				_ROOT = root,
			}
			local _0 = VirtualScript.fromInstance
			local _1 = instance
			local _2 = self
			-- ▼ Map.set ▼
			_0[_1] = _2
			-- ▲ Map.set ▲
		end
		function VirtualScript:getFromInstance(obj)
			local _0 = self.fromInstance
			local _1 = obj
			return _0[_1]
		end
		function VirtualScript:requireFromInstance(object)
			local module = self:getFromInstance(object)
			local _0 = module
			local _1 = "Failed to get VirtualScript for Instance '" .. object:GetFullName() .. "'"
			assert(_0, _1)
			return module:runExecutor()
		end
		function VirtualScript:loadModule(object, caller)
			local _0 = self.fromInstance
			local _1 = object
			local module = _0[_1]
			if not module then
				return require(object)
			end
			local _2 = currentlyLoading
			local _3 = caller
			local _4 = module
			-- ▼ Map.set ▼
			_2[_3] = _4
			-- ▲ Map.set ▲
			-- Check to see if this is a cyclic reference
			checkTraceback(module)
			local result = module:runExecutor()
			-- Thread-safe cleanup avoids overwriting other loading modules
			local _5 = caller
			if _5 then
				local _6 = currentlyLoading
				local _7 = caller
				_5 = _6[_7] == module
			end
			if _5 then
				local _6 = currentlyLoading
				local _7 = caller
				-- ▼ Map.delete ▼
				_6[_7] = nil
				-- ▲ Map.delete ▲
			end
			return result
		end
		function VirtualScript:getPath()
			local _0 = self.path
			local _1 = #self.root + 1
			local file = string.sub(_0, _1)
			return "@" .. file .. " (" .. self.instance:GetFullName() .. ")"
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
			local f, err = loadstring(self:getSource(), "=" .. self:getPath())
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
			local result = self:createExecutor()(self.scriptEnvironment)
			-- Modules must return a value.
			if self.instance:IsA("ModuleScript") then
				local _0 = result
				local _1 = "Module '" .. self:getPath() .. "' did not return any value"
				assert(_0 ~= 0 and _0 == _0 and _0 ~= "" and _0, _1)
			end
			self.jobComplete = true
			self.result = result
			return self.result
		end
		function VirtualScript:deferExecutor()
			return TS.Promise.defer(function(resolve)
				return resolve(self:runExecutor())
			end):timeout(30, "Script " .. self:getPath() .. " reached execution timeout! Try not to yield the main thread in LocalScripts.")
		end
		function VirtualScript:getSource()
			return "setfenv(1, setmetatable(..., { __index = getfenv(0), __metatable = 'This metatable is locked' }));" .. self.rawSource
		end
		VirtualScript.fromInstance = Store:getStore("VirtualScriptStore")
	end
	return {
		VirtualScript = VirtualScript,
	}

    -- End of VirtualScript

end)

-- out/core/build/csv.lua:
TS.register("out/core/build/csv.lua", "csv", function()

    -- Setup
    local script = TS.get("out/core/build/csv.lua")

    -- Start of csv

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local Make = TS.import(script, script.Parent.Parent.Parent, "modules", "make")
	local pathUtils = TS.import(script, script.Parent.Parent.Parent, "utils", "file-utils").pathUtils
	local fileMetadata = TS.import(script, script.Parent, "metadata").fileMetadata
	local settableEntryPropertyNames = { "Context", "Example", "Key", "Source" }
	-- * Reads a CSV file and turns it into an array of `LocalizationEntries`.
	local CsvReader
	do
		CsvReader = setmetatable({}, {
			__tostring = function()
				return "CsvReader"
			end,
		})
		CsvReader.__index = CsvReader
		function CsvReader.new(...)
			local self = setmetatable({}, CsvReader)
			self:constructor(...)
			return self
		end
		function CsvReader:constructor(raw, buffer)
			if buffer == nil then
				buffer = string.split(raw, "\n")
			end
			self.raw = raw
			self.buffer = buffer
			self.entries = {}
			self.keys = {}
		end
		function CsvReader:read()
			-- (i === 1) since otherwise transpiled to (i == 0)
			for i, line in ipairs(self.buffer) do
				if i == 1 then
					self:readHeader(line)
				else
					self:readEntry(line)
				end
			end
			return self.entries
		end
		function CsvReader:readHeader(currentLine)
			self.keys = string.split(currentLine, ",")
		end
		function CsvReader:validateEntry(entry)
			return entry.Context ~= nil and entry.Key ~= nil and entry.Source ~= nil and entry.Values ~= nil
		end
		function CsvReader:readEntry(currentLine)
			local entry = {
				Values = {},
			}
			-- (i - 1) since otherwise transpiled to (i + 1)
			for i, value in ipairs(string.split(currentLine, ",")) do
				local key = self.keys[i - 1 + 1]
				-- If 'key' is a property of the entry, then set it to value.
				-- Otherwise, add it to the 'Values' map for locale ids.
				local _0 = settableEntryPropertyNames
				local _1 = key
				if table.find(_0, _1) ~= nil then
					entry[key] = value
				else
					local _2 = entry.Values
					local _3 = key
					local _4 = value
					-- ▼ Map.set ▼
					_2[_3] = _4
					-- ▲ Map.set ▲
				end
			end
			if self:validateEntry(entry) then
				local _0 = self.entries
				local _1 = entry
				-- ▼ Array.push ▼
				_0[#_0 + 1] = _1
				-- ▲ Array.push ▲
			end
		end
	end
	--[[
		*
		* Transforms a CSV file into a Roblox LocalizationTable.
		* @param path A path to the CSV file.
		* @param name The name of the instance.
		* @returns A LocalizationTable with entries configured.
	]]
	local function makeLocalizationTable(path, name)
		local csvReader = CsvReader.new(readfile(path))
		local locTable = Make("LocalizationTable", {
			Name = name,
		})
		locTable:SetEntries(csvReader:read())
		-- Applies an adjacent meta file if it exists.
		local metaPath = tostring(pathUtils.getParent(path)) .. name .. ".meta.json"
		if isfile(metaPath) then
			fileMetadata(metaPath, locTable)
		end
		return locTable
	end
	return {
		makeLocalizationTable = makeLocalizationTable,
	}

    -- End of csv

end)

-- out/core/build/dir.lua:
TS.register("out/core/build/dir.lua", "dir", function()

    -- Setup
    local script = TS.get("out/core/build/dir.lua")

    -- Start of dir

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local Make = TS.import(script, script.Parent.Parent.Parent, "modules", "make")
	local pathUtils = TS.import(script, script.Parent.Parent.Parent, "utils", "file-utils").pathUtils
	local directoryMetadata = TS.import(script, script.Parent, "metadata").directoryMetadata
	--[[
		*
		* Transforms a directory into a Roblox folder.
		* If an `init.meta.json` file exists, create an Instance from the file.
		* @param path A path to the directory.
		* @returns A Folder object, or an object created by a meta file.
	]]
	local function makeDir(path)
		local metaPath = path .. "init.meta.json"
		if isfile(metaPath) then
			return directoryMetadata(metaPath, pathUtils.getName(path))
		end
		return Make("Folder", {
			Name = pathUtils.getName(path),
		})
	end
	return {
		makeDir = makeDir,
	}

    -- End of dir

end)

-- out/core/build/init.lua:
TS.register("out/core/build/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/core/build/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local pathUtils = TS.import(script, script.Parent.Parent, "utils", "file-utils").pathUtils
	local makeLocalizationTable = TS.import(script, script, "csv").makeLocalizationTable
	local makeDir = TS.import(script, script, "dir").makeDir
	local makeJsonModule = TS.import(script, script, "json").makeJsonModule
	local makeJsonModel = TS.import(script, script, "json-model").makeJsonModel
	local _0 = TS.import(script, script, "lua")
	local makeLua = _0.makeLua
	local makeLuaInit = _0.makeLuaInit
	local makeRobloxModel = TS.import(script, script, "rbx-model").makeRobloxModel
	local makePlainText = TS.import(script, script, "txt").makePlainText
	--[[
		*
		* Tries to turn the file or directory at `path` into an Instance. This function is recursive!
		* @param session The current Session.
		* @param path The file to turn into an object.
		* @returns The Instance made from the file.
	]]
	local function build(session, path)
		if isfolder(path) then
			local instance
			local luaInitPath = pathUtils.locateFiles(path, { "init.lua", "init.server.lua", "init.client.lua" })
			if luaInitPath ~= nil then
				instance = makeLuaInit(session, path .. luaInitPath)
			else
				instance = makeDir(path)
			end
			-- Populate the instance here! This is a workaround for a possible
			-- cyclic reference when attempting to call 'makeObject' from another
			-- file.
			for _, child in ipairs(listfiles(path)) do
				local childInstance = build(session, pathUtils.addTrailingSlash(child))
				if childInstance then
					childInstance.Parent = instance
				end
			end
			return instance
		elseif isfile(path) then
			local name = pathUtils.getName(path)
			-- Lua script
			-- https://rojo.space/docs/6.x/sync-details/#scripts
			if (string.match(name, "(%.lua)$")) ~= nil and (string.match(name, "^(init%.)")) == nil then
				return makeLua(session, path)
			elseif (string.match(name, "(%.meta.json)$")) ~= nil then
				return nil
			elseif (string.match(name, "(%.model.json)$")) ~= nil then
				return makeJsonModel(path, (string.match(name, "^(.*)%.model.json$")))
			elseif (string.match(name, "(%.project.json)$")) ~= nil then
				warn("Project files are not supported (" .. path .. ")")
			elseif (string.match(name, "(%.json)$")) ~= nil then
				return makeJsonModule(session, path, (string.match(name, "^(.*)%.json$")))
			elseif (string.match(name, "(%.csv)$")) ~= nil then
				return makeLocalizationTable(path, (string.match(name, "^(.*)%.csv$")))
			elseif (string.match(name, "(%.txt)$")) ~= nil then
				return makePlainText(path, (string.match(name, "^(.*)%.txt$")))
			elseif (string.match(name, "(%.rbxm)$")) ~= nil then
				return makeRobloxModel(session, path, (string.match(name, "^(.*)%.rbxm$")))
			elseif (string.match(name, "(%.rbxmx)$")) ~= nil then
				return makeRobloxModel(session, path, (string.match(name, "^(.*)%.rbxmx$")))
			end
		end
	end
	return {
		build = build,
	}

    -- End of init

end)

-- out/core/build/json.lua:
TS.register("out/core/build/json.lua", "json", function()

    -- Setup
    local script = TS.get("out/core/build/json.lua")

    -- Start of json

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local VirtualScript = TS.import(script, script.Parent.Parent, "VirtualScript").VirtualScript
	local Make = TS.import(script, script.Parent.Parent.Parent, "modules", "make")
	local HttpService = TS.import(script, script.Parent.Parent.Parent, "modules", "services").HttpService
	local pathUtils = TS.import(script, script.Parent.Parent.Parent, "utils", "file-utils").pathUtils
	local fileMetadata = TS.import(script, script.Parent, "metadata").fileMetadata
	--[[
		*
		* Transforms a JSON file into a Roblox module.
		* @param session The current session.
		* @param path A path to the JSON file.
		* @param name The name of the instance.
		* @returns A ModuleScript with a VirtualScript binding.
	]]
	local function makeJsonModule(session, path, name)
		local instance = Make("ModuleScript", {
			Name = name,
		})
		-- Creates and tracks a VirtualScript object for this file.
		-- The VirtualScript returns the decoded JSON data when required.
		local virtualScript = VirtualScript.new(instance, path, session.root)
		virtualScript:setExecutor(function()
			return HttpService:JSONDecode(virtualScript.rawSource)
		end)
		session:virtualScriptAdded(virtualScript)
		-- Applies an adjacent meta file if it exists.
		local metaPath = tostring(pathUtils.getParent(path)) .. name .. ".meta.json"
		if isfile(metaPath) then
			fileMetadata(metaPath, instance)
		end
		return instance
	end
	return {
		makeJsonModule = makeJsonModule,
	}

    -- End of json

end)

-- out/core/build/json-model.lua:
TS.register("out/core/build/json-model.lua", "json-model", function()

    -- Setup
    local script = TS.get("out/core/build/json-model.lua")

    -- Start of json-model

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local Make = TS.import(script, script.Parent.Parent.Parent, "modules", "make")
	local HttpService = TS.import(script, script.Parent.Parent.Parent, "modules", "services").HttpService
	local EncodedValue = TS.import(script, script.Parent, "EncodedValue")
	--[[
		*
		* Recursively generates Roblox instances from the given model data.
		* @param modelData The properties and children of the model.
		* @param path A path to the model file for debugging.
		* @param name The name of the model file, for the top-level instance only.
		* @returns An Instance created with the model data.
	]]
	local function jsonModel(modelData, path, name)
		-- The 'Name' field is required for all other instances.
		local _0 = name
		if _0 == nil then
			_0 = modelData.Name
		end
		local _1 = "A child in the model file '" .. path .. "' is missing a Name field"
		assert(_0 ~= "" and _0, _1)
		if name ~= nil and modelData.Name ~= nil and modelData.Name ~= name then
			warn("The name of the model file at '" .. path .. "' (" .. name .. ") does not match the Name field '" .. modelData.Name .. "'")
		end
		-- The 'ClassName' field is required.
		local _2 = modelData.ClassName ~= nil
		local _3 = "An object in the model file '" .. path .. "' is missing a ClassName field"
		assert(_2, _3)
		local _4 = modelData.ClassName
		local _5 = {}
		local _6 = "Name"
		local _7 = name
		if _7 == nil then
			_7 = modelData.Name
		end
		_5[_6] = _7
		local obj = Make(_4, _5)
		if modelData.Properties then
			EncodedValue.setModelProperties(obj, modelData.Properties)
		end
		if modelData.Children then
			for _, entry in ipairs(modelData.Children) do
				local child = jsonModel(entry, path)
				child.Parent = obj
			end
		end
		return obj
	end
	--[[
		*
		* Transforms a JSON model file into a Roblox object.
		* @param path A path to the JSON file.
		* @param name The name of the instance.
		* @returns An Instance created from the JSON model file.
	]]
	local function makeJsonModel(path, name)
		return jsonModel(HttpService:JSONDecode(readfile(path)), path, name)
	end
	return {
		makeJsonModel = makeJsonModel,
	}

    -- End of json-model

end)

-- out/core/build/lua.lua:
TS.register("out/core/build/lua.lua", "lua", function()

    -- Setup
    local script = TS.get("out/core/build/lua.lua")

    -- Start of lua

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local VirtualScript = TS.import(script, script.Parent.Parent, "VirtualScript").VirtualScript
	local Make = TS.import(script, script.Parent.Parent.Parent, "modules", "make")
	local replace = TS.import(script, script.Parent.Parent.Parent, "utils", "replace").replace
	local pathUtils = TS.import(script, script.Parent.Parent.Parent, "utils", "file-utils").pathUtils
	local fileMetadata = TS.import(script, script.Parent, "metadata").fileMetadata
	local TRAILING_TO_CLASS = {
		[".server.lua"] = "Script",
		[".client.lua"] = "LocalScript",
		[".lua"] = "ModuleScript",
	}
	--[[
		*
		* Transforms a Lua file into a Roblox script.
		* @param session The current session.
		* @param path A path to the Lua file.
		* @param name The name of the instance.
		* @returns A Lua script with a VirtualScript binding.
	]]
	local function makeLua(session, path, nameOverride)
		local fileName = pathUtils.getName(path)
		-- Look for a name and file type that fits:
		local _0 = replace(fileName, "(%.client%.lua)$", "") or replace(fileName, "(%.server%.lua)$", "") or replace(fileName, "(%.lua)$", "") or error("Invalid Lua file at " .. path)
		local name = _0[1]
		local match = _0[2]
		-- Creates an Instance for the preceding match.
		-- If an error was not thrown, this line should always succeed.
		local _1 = TRAILING_TO_CLASS[match]
		local _2 = {}
		local _3 = "Name"
		local _4 = nameOverride
		if _4 == nil then
			_4 = name
		end
		_2[_3] = _4
		local instance = Make(_1, _2)
		-- Create and track a VirtualScript object for this file:
		session:virtualScriptAdded(VirtualScript.new(instance, path, session.root))
		-- Applies an adjacent meta file if it exists.
		-- This includes init.meta.json files!
		local metaPath = tostring(pathUtils.getParent(path)) .. name .. ".meta.json"
		if isfile(metaPath) then
			fileMetadata(metaPath, instance)
		end
		return instance
	end
	--[[
		*
		* Transforms the parent directory into a Roblox script.
		* @param session The current session.
		* @param path A path to the `init.*.lua` file.
		* @param name The name of the instance.
		* @returns A Lua script with a VirtualScript binding.
	]]
	local function makeLuaInit(session, path)
		-- The parent directory will always exist for an init file.
		local parentDir = pathUtils.getParent(path)
		local instance = makeLua(session, path, pathUtils.getName(parentDir))
		return instance
	end
	return {
		makeLua = makeLua,
		makeLuaInit = makeLuaInit,
	}

    -- End of lua

end)

-- out/core/build/metadata.lua:
TS.register("out/core/build/metadata.lua", "metadata", function()

    -- Setup
    local script = TS.get("out/core/build/metadata.lua")

    -- Start of metadata

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local Make = TS.import(script, script.Parent.Parent.Parent, "modules", "make")
	local HttpService = TS.import(script, script.Parent.Parent.Parent, "modules", "services").HttpService
	local EncodedValue = TS.import(script, script.Parent, "EncodedValue")
	--[[
		*
		* Applies the given `*.meta.json` file to the `instance`.
		*
		* Note that init scripts call this function if there is
		* an `init.meta.json` present.
		*
		* @param metaPath A path to the meta file.
		* @param instance The instance to apply properties to.
	]]
	local function fileMetadata(metaPath, instance)
		local metadata = HttpService:JSONDecode(readfile(metaPath))
		-- Cannot modify the className of an existing instance:
		local _0 = metadata.className == nil
		assert(_0, "className can only be specified in init.meta.json files if the parent directory would turn into a Folder!")
		-- Uses Rojo's decoder to set properties from metadata.
		if metadata.properties ~= nil then
			EncodedValue.setProperties(instance, metadata.properties)
		end
	end
	--[[
		*
		* Creates an Instance from the given `init.meta.json` file.
		*
		* Note that this function does not get called for directories
		* that contain init scripts. We can assume that there are no
		* init scripts present.
		*
		* @param metaPath A path to the meta file.
		* @param name The name of the folder.
		* @returns A new Instance.
	]]
	local function directoryMetadata(metaPath, name)
		local metadata = HttpService:JSONDecode(readfile(metaPath))
		-- If instance isn't provided, className is never undefined.
		local instance = Make(metadata.className, {
			Name = name,
		})
		-- Uses Rojo's decoder to set properties from metadata.
		if metadata.properties ~= nil then
			EncodedValue.setProperties(instance, metadata.properties)
		end
		return instance
	end
	return {
		fileMetadata = fileMetadata,
		directoryMetadata = directoryMetadata,
	}

    -- End of metadata

end)

-- out/core/build/rbx-model.lua:
TS.register("out/core/build/rbx-model.lua", "rbx-model", function()

    -- Setup
    local script = TS.get("out/core/build/rbx-model.lua")

    -- Start of rbx-model

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local getContentId = TS.import(script, script.Parent.Parent.Parent, "api").getContentId
	local VirtualScript = TS.import(script, script.Parent.Parent, "VirtualScript").VirtualScript
	--[[
		*
		* Transforms a `.rbxm` or `.rbxmx` file into a Roblox object.
		* @param path A path to the model file.
		* @param name The name of the instance.
		* @returns The result of `game.GetObjects(getContentId(path))`.
	]]
	local function makeRobloxModel(session, path, name)
		local _0 = getContentId
		local _1 = "'" .. path .. "' could not be loaded; No way to get a content id"
		assert(_0 ~= 0 and _0 == _0 and _0 ~= "" and _0, _1)
		-- A neat trick to load model files is to generate a content ID, which
		-- moves it to Roblox's content folder, and then use it as the asset id for
		-- for GetObjects:
		local tree = game:GetObjects(getContentId(path))
		local _2 = #tree == 1
		local _3 = "'" .. path .. "' could not be loaded; Only one top-level instance is supported"
		assert(_2, _3)
		local model = tree[1]
		model.Name = name
		-- Create VirtualScript objects for all scripts in the model
		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA("LuaSourceContainer") then
				session:virtualScriptAdded(VirtualScript.new(obj, path, session.root, obj.Source))
			end
		end
		if model:IsA("LuaSourceContainer") then
			session:virtualScriptAdded(VirtualScript.new(model, path, session.root, model.Source))
		end
		return model
	end
	return {
		makeRobloxModel = makeRobloxModel,
	}

    -- End of rbx-model

end)

-- out/core/build/txt.lua:
TS.register("out/core/build/txt.lua", "txt", function()

    -- Setup
    local script = TS.get("out/core/build/txt.lua")

    -- Start of txt

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local Make = TS.import(script, script.Parent.Parent.Parent, "modules", "make")
	local pathUtils = TS.import(script, script.Parent.Parent.Parent, "utils", "file-utils").pathUtils
	local fileMetadata = TS.import(script, script.Parent, "metadata").fileMetadata
	--[[
		*
		* Transforms a plain text file into a Roblox StringValue.
		* @param path A path to the text file.
		* @param name The name of the instance.
		* @returns A StringValue object.
	]]
	local function makePlainText(path, name)
		local stringValue = Make("StringValue", {
			Name = name,
			Value = readfile(path),
		})
		-- Applies an adjacent meta file if it exists.
		local metaPath = tostring(pathUtils.getParent(path)) .. name .. ".meta.json"
		if isfile(metaPath) then
			fileMetadata(metaPath, stringValue)
		end
		return stringValue
	end
	return {
		makePlainText = makePlainText,
	}

    -- End of txt

end)

-- out/core/build/EncodedValue/init.lua:
TS.register("out/core/build/EncodedValue/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/core/build/EncodedValue/init.lua")

    -- Start of init

    --[[
		This module was modified to handle results of the 'typeof' function, to be more lightweight.
		The original source of this module can be found in the link below, as well as the license:
	
		https://github.com/rojo-rbx/rojo/blob/master/plugin/rbx_dom_lua/EncodedValue.lua
		https://github.com/rojo-rbx/rojo/blob/master/plugin/rbx_dom_lua/base64.lua
		https://github.com/rojo-rbx/rojo/blob/master/LICENSE.txt
	--]]
	
	local base64
	do
		-- Thanks to Tiffany352 for this base64 implementation!
	
		local floor = math.floor
		local char = string.char
	
		local function encodeBase64(str)
			local out = {}
			local nOut = 0
			local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
			local strLen = #str
	
			-- 3 octets become 4 hextets
			for i = 1, strLen - 2, 3 do
				local b1, b2, b3 = str:byte(i, i + 3)
				local word = b3 + b2 * 256 + b1 * 256 * 256
	
				local h4 = word % 64 + 1
				word = floor(word / 64)
				local h3 = word % 64 + 1
				word = floor(word / 64)
				local h2 = word % 64 + 1
				word = floor(word / 64)
				local h1 = word % 64 + 1
	
				out[nOut + 1] = alphabet:sub(h1, h1)
				out[nOut + 2] = alphabet:sub(h2, h2)
				out[nOut + 3] = alphabet:sub(h3, h3)
				out[nOut + 4] = alphabet:sub(h4, h4)
				nOut = nOut + 4
			end
	
			local remainder = strLen % 3
	
			if remainder == 2 then
				-- 16 input bits -> 3 hextets (2 full, 1 partial)
				local b1, b2 = str:byte(-2, -1)
				-- partial is 4 bits long, leaving 2 bits of zero padding ->
				-- offset = 4
				local word = b2 * 4 + b1 * 4 * 256
	
				local h3 = word % 64 + 1
				word = floor(word / 64)
				local h2 = word % 64 + 1
				word = floor(word / 64)
				local h1 = word % 64 + 1
	
				out[nOut + 1] = alphabet:sub(h1, h1)
				out[nOut + 2] = alphabet:sub(h2, h2)
				out[nOut + 3] = alphabet:sub(h3, h3)
				out[nOut + 4] = "="
			elseif remainder == 1 then
				-- 8 input bits -> 2 hextets (2 full, 1 partial)
				local b1 = str:byte(-1, -1)
				-- partial is 2 bits long, leaving 4 bits of zero padding ->
				-- offset = 16
				local word = b1 * 16
	
				local h2 = word % 64 + 1
				word = floor(word / 64)
				local h1 = word % 64 + 1
	
				out[nOut + 1] = alphabet:sub(h1, h1)
				out[nOut + 2] = alphabet:sub(h2, h2)
				out[nOut + 3] = "="
				out[nOut + 4] = "="
			end
			-- if the remainder is 0, then no work is needed
	
			return table.concat(out, "")
		end
	
		local function decodeBase64(str)
			local out = {}
			local nOut = 0
			local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
			local strLen = #str
			local acc = 0
			local nAcc = 0
	
			local alphabetLut = {}
			for i = 1, #alphabet do
				alphabetLut[alphabet:sub(i, i)] = i - 1
			end
	
			-- 4 hextets become 3 octets
			for i = 1, strLen do
				local ch = str:sub(i, i)
				local byte = alphabetLut[ch]
				if byte then
					acc = acc * 64 + byte
					nAcc = nAcc + 1
				end
	
				if nAcc == 4 then
					local b3 = acc % 256
					acc = floor(acc / 256)
					local b2 = acc % 256
					acc = floor(acc / 256)
					local b1 = acc % 256
	
					out[nOut + 1] = char(b1)
					out[nOut + 2] = char(b2)
					out[nOut + 3] = char(b3)
					nOut = nOut + 3
					nAcc = 0
					acc = 0
				end
			end
	
			if nAcc == 3 then
				-- 3 hextets -> 16 bit output
				acc = acc * 64
				acc = floor(acc / 256)
				local b2 = acc % 256
				acc = floor(acc / 256)
				local b1 = acc % 256
	
				out[nOut + 1] = char(b1)
				out[nOut + 2] = char(b2)
			elseif nAcc == 2 then
				-- 2 hextets -> 8 bit output
				acc = acc * 64
				acc = floor(acc / 256)
				acc = acc * 64
				acc = floor(acc / 256)
				local b1 = acc % 256
	
				out[nOut + 1] = char(b1)
			elseif nAcc == 1 then
				error("Base64 has invalid length")
			end
	
			return table.concat(out, "")
		end
	
		base64 = {
			decode = decodeBase64,
			encode = encodeBase64,
		}
	end
	
	local function identity(...)
		return ...
	end
	
	local function unpackDecoder(f)
		return function(value)
			return f(unpack(value))
		end
	end
	
	local function serializeFloat(value)
		-- TODO: Figure out a better way to serialize infinity and NaN, neither of
		-- which fit into JSON.
		if value == math.huge or value == -math.huge then
			return 999999999 * math.sign(value)
		end
	
		return value
	end
	
	local ALL_AXES = {"X", "Y", "Z"}
	local ALL_FACES = {"Right", "Top", "Back", "Left", "Bottom", "Front"}
	
	local types
	types = {
		boolean = {
			fromPod = identity,
			toPod = identity,
		},
	
		number = {
			fromPod = identity,
			toPod = identity,
		},
	
		string = {
			fromPod = identity,
			toPod = identity,
		},
	
		EnumItem = {
			fromPod = identity,
	
			toPod = function(roblox)
				-- FIXME: More robust handling of enums
				if typeof(roblox) == "number" then
					return roblox
				else
					return roblox.Value
				end
			end,
		},
	
		Axes = {
			fromPod = function(pod)
				local axes = {}
	
				for index, axisName in ipairs(pod) do
					axes[index] = Enum.Axis[axisName]
				end
	
				return Axes.new(unpack(axes))
			end,
	
			toPod = function(roblox)
				local json = {}
	
				for _, axis in ipairs(ALL_AXES) do
					if roblox[axis] then
						table.insert(json, axis)
					end
				end
	
				return json
			end,
		},
	
		BinaryString = {	
			fromPod = base64.decode,	
			toPod = base64.encode,	
		},
	
		Bool = {	
			fromPod = identity,	
			toPod = identity,	
		},
	
		BrickColor = {
			fromPod = function(pod)
				return BrickColor.new(pod)
			end,
	
			toPod = function(roblox)
				return roblox.Number
			end,
		},
	
		CFrame = {
			fromPod = function(pod)
				local pos = pod.Position
				local orient = pod.Orientation
	
				return CFrame.new(
					pos[1], pos[2], pos[3],
					orient[1][1], orient[1][2], orient[1][3],
					orient[2][1], orient[2][2], orient[2][3],
					orient[3][1], orient[3][2], orient[3][3]
				)
			end,
	
			toPod = function(roblox)
				local x, y, z,
					r00, r01, r02,
					r10, r11, r12,
					r20, r21, r22 = roblox:GetComponents()
	
				return {
					Position = {x, y, z},
					Orientation = {
						{r00, r01, r02},
						{r10, r11, r12},
						{r20, r21, r22},
					},
				}
			end,
		},
	
		Color3 = {
			fromPod = unpackDecoder(Color3.new),
	
			toPod = function(roblox)
				return {roblox.r, roblox.g, roblox.b}
			end,
		},
	
		Color3uint8 = {	
			fromPod = unpackDecoder(Color3.fromRGB),	
			toPod = function(roblox)	
				return {	
					math.round(roblox.R * 255),	
					math.round(roblox.G * 255),	
					math.round(roblox.B * 255),	
				}	
			end,	
		},
	
		ColorSequence = {
			fromPod = function(pod)
				local keypoints = {}
	
				for index, keypoint in ipairs(pod.Keypoints) do
					keypoints[index] = ColorSequenceKeypoint.new(
						keypoint.Time,
						types.Color3.fromPod(keypoint.Color)
					)
				end
	
				return ColorSequence.new(keypoints)
			end,
	
			toPod = function(roblox)
				local keypoints = {}
	
				for index, keypoint in ipairs(roblox.Keypoints) do
					keypoints[index] = {
						Time = keypoint.Time,
						Color = types.Color3.toPod(keypoint.Value),
					}
				end
	
				return {
					Keypoints = keypoints,
				}
			end,
		},
	
		Content = {	
			fromPod = identity,	
			toPod = identity,	
		},
	
		Faces = {
			fromPod = function(pod)
				local faces = {}
	
				for index, faceName in ipairs(pod) do
					faces[index] = Enum.NormalId[faceName]
				end
	
				return Faces.new(unpack(faces))
			end,
	
			toPod = function(roblox)
				local pod = {}
	
				for _, face in ipairs(ALL_FACES) do
					if roblox[face] then
						table.insert(pod, face)
					end
				end
	
				return pod
			end,
		},
	
		Float32 = {	
			fromPod = identity,	
			toPod = serializeFloat,	
		},
	
		Float64 = {	
			fromPod = identity,	
			toPod = serializeFloat,	
		},
	
		Int32 = {	
			fromPod = identity,	
			toPod = identity,	
		},
	
		Int64 = {	
			fromPod = identity,	
			toPod = identity,	
		},
	
		NumberRange = {
			fromPod = unpackDecoder(NumberRange.new),
	
			toPod = function(roblox)
				return {roblox.Min, roblox.Max}
			end,
		},
	
		NumberSequence = {
			fromPod = function(pod)
				local keypoints = {}
	
				for index, keypoint in ipairs(pod.Keypoints) do
					keypoints[index] = NumberSequenceKeypoint.new(
						keypoint.Time,
						keypoint.Value,
						keypoint.Envelope
					)
				end
	
				return NumberSequence.new(keypoints)
			end,
	
			toPod = function(roblox)
				local keypoints = {}
	
				for index, keypoint in ipairs(roblox.Keypoints) do
					keypoints[index] = {
						Time = keypoint.Time,
						Value = keypoint.Value,
						Envelope = keypoint.Envelope,
					}
				end
	
				return {
					Keypoints = keypoints,
				}
			end,
		},
	
		PhysicalProperties = {
			fromPod = function(pod)
				if pod == "Default" then
					return nil
				else
					return PhysicalProperties.new(
						pod.Density,
						pod.Friction,
						pod.Elasticity,
						pod.FrictionWeight,
						pod.ElasticityWeight
					)
				end
			end,
	
			toPod = function(roblox)
				if roblox == nil then
					return "Default"
				else
					return {
						Density = roblox.Density,
						Friction = roblox.Friction,
						Elasticity = roblox.Elasticity,
						FrictionWeight = roblox.FrictionWeight,
						ElasticityWeight = roblox.ElasticityWeight,
					}
				end
			end,
		},
	
		Ray = {
			fromPod = function(pod)
				return Ray.new(
					types.Vector3.fromPod(pod.Origin),
					types.Vector3.fromPod(pod.Direction)
				)
			end,
	
			toPod = function(roblox)
				return {
					Origin = types.Vector3.toPod(roblox.Origin),
					Direction = types.Vector3.toPod(roblox.Direction),
				}
			end,
		},
	
		Rect = {
			fromPod = function(pod)
				return Rect.new(
					types.Vector2.fromPod(pod[1]),
					types.Vector2.fromPod(pod[2])
				)
			end,
	
			toPod = function(roblox)
				return {
					types.Vector2.toPod(roblox.Min),
					types.Vector2.toPod(roblox.Max),
				}
			end,
		},
	
		Instance = {
			fromPod = function(_pod)
				error("Ref cannot be decoded on its own")
			end,
	
			toPod = function(_roblox)
				error("Ref can not be encoded on its own")
			end,
		},
	
		Ref = {
			fromPod = function(_pod)
				error("Ref cannot be decoded on its own")
			end,
			toPod = function(_roblox)
				error("Ref can not be encoded on its own")
			end,
		},
	
		Region3 = {
			fromPod = function(pod)
				error("Region3 is not implemented")
			end,
	
			toPod = function(roblox)
				error("Region3 is not implemented")
			end,
		},
	
		Region3int16 = {
			fromPod = function(pod)
				return Region3int16.new(
					types.Vector3int16.fromPod(pod[1]),
					types.Vector3int16.fromPod(pod[2])
				)
			end,
	
			toPod = function(roblox)
				return {
					types.Vector3int16.toPod(roblox.Min),
					types.Vector3int16.toPod(roblox.Max),
				}
			end,
		},	
	
		SharedString = {	
			fromPod = function(pod)	
				error("SharedString is not supported")	
			end,	
			toPod = function(roblox)	
				error("SharedString is not supported")	
			end,	
		},
	
		String = {	
			fromPod = identity,	
			toPod = identity,	
		},
	
		UDim = {
			fromPod = unpackDecoder(UDim.new),
	
			toPod = function(roblox)
				return {roblox.Scale, roblox.Offset}
			end,
		},
	
		UDim2 = {
			fromPod = function(pod)
				return UDim2.new(
					types.UDim.fromPod(pod[1]),
					types.UDim.fromPod(pod[2])
				)
			end,
	
			toPod = function(roblox)
				return {
					types.UDim.toPod(roblox.X),
					types.UDim.toPod(roblox.Y),
				}
			end,
		},
	
		Vector2 = {
			fromPod = unpackDecoder(Vector2.new),
	
			toPod = function(roblox)
				return {
					serializeFloat(roblox.X),
					serializeFloat(roblox.Y),
				}
			end,
		},
	
		Vector2int16 = {
			fromPod = unpackDecoder(Vector2int16.new),
	
			toPod = function(roblox)
				return {roblox.X, roblox.Y}
			end,
		},
	
		Vector3 = {
			fromPod = unpackDecoder(Vector3.new),
	
			toPod = function(roblox)
				return {
					serializeFloat(roblox.X),
					serializeFloat(roblox.Y),
					serializeFloat(roblox.Z),
				}
			end,
		},
	
		Vector3int16 = {
			fromPod = unpackDecoder(Vector3int16.new),
	
			toPod = function(roblox)
				return {roblox.X, roblox.Y, roblox.Z}
			end,
		},
	}
	
	local EncodedValue = {}
	
	function EncodedValue.decode(dataType, encodedValue)
		local typeImpl = types[dataType]
		if typeImpl == nil then
			return false, "Couldn't decode value " .. tostring(dataType)
		end
	
		return true, typeImpl.fromPod(encodedValue)
	end
	
	function EncodedValue.setProperty(obj, property, encodedValue, dataType)
		dataType = dataType or typeof(obj[property])
		local success, result = EncodedValue.decode(dataType, encodedValue)
		if success then
			obj[property] = result
		else
			warn("Could not set property " .. property .. " of " .. obj.GetFullName() .. "; " .. result)
		end
	end
	
	function EncodedValue.setProperties(obj, properties)
		for property, encodedValue in pairs(properties) do
			EncodedValue.setProperty(obj, property, encodedValue)
		end
	end
	
	function EncodedValue.setModelProperties(obj, properties)
		for property, encodedValue in pairs(properties) do
			EncodedValue.setProperty(obj, property, encodedValue.Value, encodedValue.Type)
		end
	end
	
	return EncodedValue

    -- End of init

end)

-- out/modules/make/init.lua:
TS.register("out/modules/make/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/modules/make/init.lua")

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

-- out/modules/object-utils/init.lua:
TS.register("out/modules/object-utils/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/modules/object-utils/init.lua")

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

-- out/modules/Promise/init.lua:
TS.register("out/modules/Promise/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/modules/Promise/init.lua")

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

-- out/modules/services/init.lua:
TS.register("out/modules/services/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/modules/services/init.lua")

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

-- out/modules/zzlib/init.lua:
TS.register("out/modules/zzlib/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/modules/zzlib/init.lua")

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

-- out/utils/extract.lua:
TS.register("out/utils/extract.lua", "extract", function()

    -- Setup
    local script = TS.get("out/utils/extract.lua")

    -- Start of extract

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local zzlib = TS.import(script, script.Parent.Parent, "modules", "zzlib")
	local _0 = TS.import(script, script.Parent, "file-utils")
	local makeUtils = _0.makeUtils
	local pathUtils = _0.pathUtils
	--[[
		*
		* Extracts files from raw zip data.
		* @param rawData Raw zip data.
		* @param target The directory to extract files to.
		* @param ungroup
		* If the zip file contains a single directory, it may be useful to ungroup the files inside.
		* This parameter controls whether the top-level directory is ignored.
	]]
	local function extract(rawData, target, ungroup)
		local zipData = zzlib.unzip(rawData)
		local fileArray = {}
		-- Convert the path-content map to a file array
		for path, contents in pairs(zipData) do
			local _1
			if ungroup then
				local _2 = fileArray
				local _3 = { pathUtils.addTrailingSlash(target) .. tostring((string.match(path, "^[^/]*/(.*)$"))), contents }
				-- ▼ Array.push ▼
				local _4 = #_2
				_2[_4 + 1] = _3
				-- ▲ Array.push ▲
				_1 = _4 + 1
			else
				local _2 = fileArray
				local _3 = { pathUtils.addTrailingSlash(target) .. path, contents }
				-- ▼ Array.push ▼
				local _4 = #_2
				_2[_4 + 1] = _3
				-- ▲ Array.push ▲
				_1 = _4 + 1
			end
		end
		-- Make the files at the given target
		makeUtils.makeFiles(fileArray)
	end
	return {
		extract = extract,
	}

    -- End of extract

end)

-- out/utils/http.lua:
TS.register("out/utils/http.lua", "http", function()

    -- Setup
    local script = TS.get("out/utils/http.lua")

    -- Start of http

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local httpRequest = TS.import(script, script.Parent.Parent, "api").httpRequest
	-- * Sends an HTTP GET request.
	local get = TS.Promise.promisify(function(url)
		return game:HttpGetAsync(url)
	end)
	-- * Sends an HTTP POST request.
	local post = TS.Promise.promisify(function(url)
		return game:HttpPostAsync(url)
	end)
	-- * Makes an HTTP request.
	local request = TS.Promise.promisify(httpRequest)
	return {
		get = get,
		post = post,
		request = request,
	}

    -- End of http

end)

-- out/utils/JsonStore.lua:
TS.register("out/utils/JsonStore.lua", "JsonStore", function()

    -- Setup
    local script = TS.get("out/utils/JsonStore.lua")

    -- Start of JsonStore

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local HttpService = TS.import(script, script.Parent.Parent, "modules", "services").HttpService
	-- * An object to read and write to JSON files.
	local JsonStore
	do
		JsonStore = setmetatable({}, {
			__tostring = function()
				return "JsonStore"
			end,
		})
		JsonStore.__index = JsonStore
		function JsonStore.new(...)
			local self = setmetatable({}, JsonStore)
			self:constructor(...)
			return self
		end
		function JsonStore:constructor(file)
			self.file = file
			local _0 = isfile(file)
			local _1 = "File '" .. file .. "' must be a valid JSON file"
			assert(_0, _1)
		end
		function JsonStore:get(key)
			local _0 = self.state
			assert(_0 ~= 0 and _0 == _0 and _0 ~= "" and _0, "The JsonStore must be open to read from it")
			return self.state[key]
		end
		function JsonStore:set(key, value)
			local _0 = self.state
			assert(_0 ~= 0 and _0 == _0 and _0 ~= "" and _0, "The JsonStore must be open to write to it")
			self.state[key] = value
		end
		function JsonStore:open()
			local _0 = self.state == nil
			assert(_0, "Attempt to open an active JsonStore")
			local state = HttpService:JSONDecode(readfile(self.file))
			TS.Promise.defer(function(_, reject)
				if self.state == state then
					self:close()
					reject("JsonStore was left open; was the thread blocked before it could close?")
				end
			end)
			self.state = state
		end
		function JsonStore:close()
			local _0 = self.state
			assert(_0 ~= 0 and _0 == _0 and _0 ~= "" and _0, "Attempt to close an inactive JsonStore")
			writefile(self.file, HttpService:JSONEncode(self.state))
			self.state = nil
		end
	end
	return {
		JsonStore = JsonStore,
	}

    -- End of JsonStore

end)

-- out/utils/replace.lua:
TS.register("out/utils/replace.lua", "replace", function()

    -- Setup
    local script = TS.get("out/utils/replace.lua")

    -- Start of replace

    -- Compiled with roblox-ts v1.1.1
	--[[
		*
		* Replaces an instance of `pattern` in `str` with `replacement`.
		* @param str The string to match against.
		* @param pattern The pattern to match.
		* @param repl What to replace the first instance of `pattern` with.
		* @returns The result of global substitution, the string matched, and the position of it.
	]]
	local function replace(str, pattern, repl)
		local _0 = str
		local _1 = pattern
		local _2 = repl
		local output, count = string.gsub(_0, _1, _2, 1)
		if count > 0 then
			local _3 = str
			local _4 = pattern
			local i, j = string.find(_3, _4)
			local _5 = str
			local _6 = i
			local _7 = j
			return { output, string.sub(_5, _6, _7), i, j }
		end
	end
	return {
		replace = replace,
	}

    -- End of replace

end)

-- out/utils/fetch-github-release/downloadAsset.lua:
TS.register("out/utils/fetch-github-release/downloadAsset.lua", "downloadAsset", function()

    -- Setup
    local script = TS.get("out/utils/fetch-github-release/downloadAsset.lua")

    -- Start of downloadAsset

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local http = TS.import(script, script.Parent.Parent, "http")
	local makeUtils = TS.import(script, script.Parent.Parent, "file-utils").makeUtils
	local extract = TS.import(script, script.Parent.Parent, "extract").extract
	--[[
		*
		* Downloads the asset file for a release.
		* @param release The release to get the asset from.
		* @param asset Optional name of the asset. If not provided, the function returns the zipball URL.
		* @returns The file data for an asset.
	]]
	local downloadAsset = TS.async(function(release, path, asset)
		local assetUrl
		-- If 'asset' is specified, get the URL of the asset.
		if asset ~= nil then
			local _0 = release.assets
			local _1 = function(a)
				return a.name == asset
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
			local releaseAsset = _2
			local _3 = releaseAsset
			local _4 = "Release '" .. release.name .. "' does not have asset '" .. asset .. "'"
			assert(_3, _4)
			assetUrl = releaseAsset.browser_download_url
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
		if asset ~= nil and (string.match(asset, "([^%.]+)$")) ~= "zip" then
			_2 = makeUtils.makeFile(path .. asset, response.Body)
		else
			_2 = extract(response.Body, path, asset == nil)
		end
	end)
	return {
		downloadAsset = downloadAsset,
	}

    -- End of downloadAsset

end)

-- out/utils/fetch-github-release/downloadRelease.lua:
TS.register("out/utils/fetch-github-release/downloadRelease.lua", "downloadRelease", function()

    -- Setup
    local script = TS.get("out/utils/fetch-github-release/downloadRelease.lua")

    -- Start of downloadRelease

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local JsonStore = TS.import(script, script.Parent.Parent, "JsonStore").JsonStore
	local downloadAsset = TS.import(script, script.Parent, "downloadAsset").downloadAsset
	local _0 = TS.import(script, script.Parent.Parent.Parent, "bootstrap")
	local bootstrap = _0.bootstrap
	local getRostructPath = _0.getRostructPath
	local identify = TS.import(script, script.Parent, "identify").identify
	local _1 = TS.import(script, script.Parent, "getReleases")
	local getLatestRelease = _1.getLatestRelease
	local getRelease = _1.getRelease
	-- * Object used to modify the JSON file with decoded JSON data.
	local savedTags = JsonStore.new(getRostructPath("RELEASE_TAGS"))
	--[[
		*
		* Downloads a release from the given repository. If `asset` is undefined, it downloads
		* the source zip files and extracts them. Automatically extracts .zip files.
		* This function does not download prereleases or drafts.
		* @param owner The owner of the repository.
		* @param repo The name of the repository.
		* @param tag The release tag to download.
		* @param asset Optional asset to download. Defaults to the source files.
		* @returns A download result interface.
	]]
	local downloadRelease = TS.async(function(owner, repo, tag, asset)
		-- Type assertions:
		local _2 = type(owner) == "string"
		assert(_2, "Argument 'owner' must be a string")
		local _3 = type(repo) == "string"
		assert(_3, "Argument 'repo' must be a string")
		local _4 = type(tag) == "string"
		assert(_4, "Argument 'tag' must be a string")
		local _5 = asset == nil or type(asset) == "string"
		assert(_5, "Argument 'asset' must be a string or nil")
		local id = identify(owner, repo, tag, asset)
		local path = getRostructPath("RELEASE_CACHE") .. id .. "/"
		-- If the path is taken, don't download it again
		if isfolder(path) then
			local _6 = {
				location = path,
				owner = owner,
				repo = repo,
				tag = tag,
			}
			local _7 = "asset"
			local _8 = asset
			if _8 == nil then
				_8 = "Source code"
			end
			_6[_7] = _8
			_6.updated = false
			return _6
		end
		local release = TS.await(getRelease(owner, repo, tag))
		TS.await(downloadAsset(release, path, asset))
		local _6 = {
			location = path,
			owner = owner,
			repo = repo,
			tag = tag,
		}
		local _7 = "asset"
		local _8 = asset
		if _8 == nil then
			_8 = "Source code"
		end
		_6[_7] = _8
		_6.updated = true
		return _6
	end)
	--[[
		*
		* Downloads the latest release from the given repository. If `asset` is undefined,
		* it downloads the source zip files and extracts them. Automatically extracts .zip files.
		* This function does not download prereleases or drafts.
		* @param owner The owner of the repository.
		* @param repo The name of the repository.
		* @param asset Optional asset to download. Defaults to the source files.
		* @returns A download result interface.
	]]
	local downloadLatestRelease = TS.async(function(owner, repo, asset)
		-- Type assertions:
		local _2 = type(owner) == "string"
		assert(_2, "Argument 'owner' must be a string")
		local _3 = type(repo) == "string"
		assert(_3, "Argument 'repo' must be a string")
		local _4 = asset == nil or type(asset) == "string"
		assert(_4, "Argument 'asset' must be a string or nil")
		local id = identify(owner, repo, nil, asset)
		local path = getRostructPath("RELEASE_CACHE") .. id .. "/"
		local release = TS.await(getLatestRelease(owner, repo))
		savedTags:open()
		-- Check if the cache is up-to-date
		if savedTags:get(id) == release.tag_name and isfolder(path) then
			savedTags:close()
			local _5 = {
				location = path,
				owner = owner,
				repo = repo,
				tag = release.tag_name,
			}
			local _6 = "asset"
			local _7 = asset
			if _7 == nil then
				_7 = "Source code"
			end
			_5[_6] = _7
			_5.updated = false
			return _5
		end
		-- Update the cache with the new tag
		savedTags:set(id, release.tag_name)
		savedTags:close()
		-- Make sure nothing is at the path before downloading!
		if isfolder(path) then
			delfolder(path)
		end
		-- Download the asset to the cache
		TS.await(downloadAsset(release, path, asset))
		local _5 = {
			location = path,
			owner = owner,
			repo = repo,
			tag = release.tag_name,
		}
		local _6 = "asset"
		local _7 = asset
		if _7 == nil then
			_7 = "Source code"
		end
		_5[_6] = _7
		_5.updated = true
		return _5
	end)
	-- * Clears the release cache.
	local function clearReleaseCache()
		delfolder(getRostructPath("RELEASE_CACHE"))
		bootstrap()
	end
	return {
		downloadRelease = downloadRelease,
		downloadLatestRelease = downloadLatestRelease,
		clearReleaseCache = clearReleaseCache,
	}

    -- End of downloadRelease

end)

-- out/utils/fetch-github-release/getReleases.lua:
TS.register("out/utils/fetch-github-release/getReleases.lua", "getReleases", function()

    -- Setup
    local script = TS.get("out/utils/fetch-github-release/getReleases.lua")

    -- Start of getReleases

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local HttpService = TS.import(script, script.Parent.Parent.Parent, "modules", "services").HttpService
	local http = TS.import(script, script.Parent.Parent, "http")
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

    -- End of getReleases

end)

-- out/utils/fetch-github-release/identify.lua:
TS.register("out/utils/fetch-github-release/identify.lua", "identify", function()

    -- Setup
    local script = TS.get("out/utils/fetch-github-release/identify.lua")

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

-- out/utils/fetch-github-release/init.lua:
TS.register("out/utils/fetch-github-release/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/utils/fetch-github-release/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	for _0, _1 in pairs(TS.import(script, script, "getReleases")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "downloadRelease")) do
		exports[_0] = _1
	end
	for _0, _1 in pairs(TS.import(script, script, "identify")) do
		exports[_0] = _1
	end
	return exports

    -- End of init

end)

-- out/utils/fetch-github-release/types.lua:
TS.register("out/utils/fetch-github-release/types.lua", "types", function()

    -- Setup
    local script = TS.get("out/utils/fetch-github-release/types.lua")

    -- Start of types

    -- Compiled with roblox-ts v1.1.1
	-- * Information about the release being downloaded.
	--[[
		*
		* Information about the latest release of a given Github repository.
		* See this [example](https://api.github.com/repos/Roblox/roact/releases/latest).
	]]
	return nil

    -- End of types

end)

-- out/utils/file-utils/init.lua:
TS.register("out/utils/file-utils/init.lua", "init", function()

    -- Setup
    local script = TS.get("out/utils/file-utils/init.lua")

    -- Start of init

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local exports = {}
	exports.makeUtils = TS.import(script, script, "make-utils")
	exports.pathUtils = TS.import(script, script, "path-utils")
	return exports

    -- End of init

end)

-- out/utils/file-utils/make-utils.lua:
TS.register("out/utils/file-utils/make-utils.lua", "make-utils", function()

    -- Setup
    local script = TS.get("out/utils/file-utils/make-utils.lua")

    -- Start of make-utils

    -- Compiled with roblox-ts v1.1.1
	local TS = TS._G[script]
	local pathUtils = TS.import(script, script.Parent, "path-utils")
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
		local _0 = pathUtils.addExtension(file)
		local _1 = content
		if _1 == nil then
			_1 = ""
		end
		writefile(_0, _1)
	end
	--[[
		*
		* Safely creates files from the given list of paths.
		* The first string in the file array element is the path,
		* and the second string is the optional file contents.
		* @param fileArray A list of files to create and their contents.
	]]
	local function makeFiles(fileArray)
		-- Create the files and directories. No sorts need to be performed because parent folders
		-- in each path are made before the file/folder itself.
		for _, _0 in ipairs(fileArray) do
			local path = _0[1]
			local contents = _0[2]
			if string.sub(path, -1) == "/" and not isfolder(path) then
				makeFolder(path)
			elseif string.sub(path, -1) ~= "/" and not isfile(path) then
				makeFile(path, contents)
			end
		end
	end
	return {
		makeFolder = makeFolder,
		makeFile = makeFile,
		makeFiles = makeFiles,
	}

    -- End of make-utils

end)

-- out/utils/file-utils/path-utils.lua:
TS.register("out/utils/file-utils/path-utils.lua", "path-utils", function()

    -- Setup
    local script = TS.get("out/utils/file-utils/path-utils.lua")

    -- Start of path-utils

    -- Compiled with roblox-ts v1.1.1
	-- * Formats the given path. **The path must be a real file or folder!**
	local function formatPath(path)
		local _0 = isfile(path) or isfolder(path)
		local _1 = "'" .. path .. "' does not point to a folder or file"
		assert(_0, _1)
		-- Replace all slashes with forward slashes
		path = (string.gsub(path, "\\", "/"))
		-- Add a trailing slash
		if isfolder(path) then
			if string.sub(path, -1) ~= "/" then
				path ..= "/"
			end
		end
		return path
	end
	-- * Adds a trailing slash if there is no extension.
	local function addTrailingSlash(path)
		path = (string.gsub(path, "\\", "/"))
		if (string.match(path, "%.([^%./]+)$")) == nil and string.sub(path, -1) ~= "/" then
			return path .. "/"
		else
			return path
		end
	end
	-- * Appends a file with no extension with `.file`.
	local function addExtension(file)
		local hasExtension = (string.match(string.reverse(file), "^([^%./]+%.)")) ~= nil
		if not hasExtension then
			return file .. ".file"
		else
			return file
		end
	end
	-- * Gets the name of a file or folder.
	local function getName(path)
		return (string.match(path, "([^/]+)/*$"))
	end
	-- * Returns the parent directory.
	local function getParent(path)
		return (string.match(path, "^(.*[/])[^/]+"))
	end
	-- * Returns the first file that exists in the directory.
	local function locateFiles(dir, files)
		local _0 = files
		local _1 = function(file)
			return isfile(dir .. file)
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
		return _2
	end
	return {
		formatPath = formatPath,
		addTrailingSlash = addTrailingSlash,
		addExtension = addExtension,
		getName = getName,
		getParent = getParent,
		locateFiles = locateFiles,
	}

    -- End of path-utils

end)

-- out/utils/file-utils/types.lua:
TS.register("out/utils/file-utils/types.lua", "types", function()

    -- Setup
    local script = TS.get("out/utils/file-utils/types.lua")

    -- Start of types

    -- Compiled with roblox-ts v1.1.1
	-- * Data used to construct files and directories.
	return nil

    -- End of types

end)

local Rostruct = TS.initialize("init")

-- Download the latest release to local files
return Rostruct.fetchLatest("richie0866", "MidiPlayer")
    -- Then, build and start all scripts
    :andThen(function(package)
        package:build("src/")
        package:start()
        return package
    end)
    -- Finally, wait until the Promise is done
    :expect()
