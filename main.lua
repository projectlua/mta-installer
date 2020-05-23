local resourceFileCache = {}
local resourceName = getResourceName(getThisResource())
local cfgDir = "resource.cfg"
local resourceTag = "[projectlua]"

function check()
    return license
end

function updateResource()
    local meta = xmlLoadFile("update-meta.xml")
    local metaData = xmlNodeGetChildren(meta)
    if metaData then
        for index, node in ipairs(metaData) do
            local fileType = xmlNodeGetName(node)
            local fileLocation = xmlNodeGetAttribute(node, "src")
            if fileType == "script" or fileType == "file" then
                resourceFileCache[#resourceFileCache + 1] = fileLocation
            end
        end
    end
    xmlUnloadFile(meta)
    
    resourceFileCount = 1
    downloadFile()
end

function completeResource()
    fileDelete("meta.xml")
    fileRename("update-meta.xml", "meta.xml")

    fileDelete(cfgDir)
    local file = fileCreate(cfgDir)
    fileWrite(file, toJSON(targetResourceData))
    fileClose(file)
    restartResource(getThisResource())
end

function downloadFile()
    if not resourceFileCache[resourceFileCount] then
        completeResource()
        return
    end
    fetchRemote("https://raw.githubusercontent.com/projectlua/installer/master/"..resourceFileCache[resourceFileCount],
        function(data, err, path)
            if err == 0 then
                local size = 0
                if fileExists(path) then
                    fileDelete(path)
                end
                local file = fileCreate(path)
                fileWrite(file, data)
                fileClose(file)
            else
                print("projectlua/"..resourceName.."/"..path.." > download failed")
            end
            if resourceFileCache[resourceFileCount+1] then
                resourceFileCount = resourceFileCount + 1
                downloadFile()
            else
                completeResource()
            end
        end,
    "", false, resourceFileCache[resourceFileCount])
end

function downloadResources()
    print("projectlua > could not find resources, downloading now...")
    print("projectlua > please wait, don't turn off the server")
    fetchRemote(EncryptModule.getLink().."resourcelist.cfg",
        function(data, err)
            if err == 0 then
                print("projectlua > started downloading resources (0/"..#fromJSON(tostring(data))..")")
                local loadedResource = 0
                for i, resourceDir in ipairs(fromJSON(tostring(data))) do
                    if not getResourceFromName(resourceDir) then
                        local resourceElement = createResource(resourceDir, resourceTag)

                        fileCopy("file/updater.lua", ":"..resourceDir.."/updater.lua")
                        fileCopy("file/resource.cfg", ":"..resourceDir.."/resource.cfg")
                        fileCopy("modules/encode.lua", ":"..resourceDir.."/encode.lua")

                        local meta = xmlLoadFile(":"..resourceDir.."/meta.xml")
                        if meta then
                            xmlCreateChild(meta, "oop").value = "true"
                            local updaterChild = xmlCreateChild(meta, "script")
                            updaterChild:setAttribute("src", "updater.lua")
                            updaterChild:setAttribute("type", "server")

                            local updaterChild = xmlCreateChild(meta, "script")
                            updaterChild:setAttribute("src", "encode.lua")
                            updaterChild:setAttribute("type", "server")

                            xmlSaveFile(meta)
                            xmlUnloadFile(meta)
                        end
                        print("projectlua/"..resourceDir.." > downloaded resource ("..loadedResource.."/"..#fromJSON(tostring(data))..")")
                        loadedResource = loadedResource + 1
                    end
                end
                prepareSetup()

                print("projectlua > downloaded "..loadedResource.." resource, waiting for update...")
            else
                print("projectlua > could not load the remote server")
            end
        end
    )
end

addEventHandler("onResourceStart", resourceRoot,
    function()
        if fileExists(cfgDir) then
            local resourceFile = fileOpen(cfgDir)
            resourceData = fromJSON(fileRead(resourceFile, fileGetSize(resourceFile)))
            currentVersion = resourceData.version
            fileClose(resourceFile)

            fetchRemote("https://raw.githubusercontent.com/projectlua/installer/master/resource.cfg",
                function(data, err)
                    if err == 0 then
                        targetResourceData = fromJSON(data) or false
                        if targetResourceData then
                            local newestVersion = targetResourceData.version
                            if newestVersion > currentVersion then
                                print("projectlua/"..resourceName.." > Updating resource..")

                                fetchRemote("https://raw.githubusercontent.com/projectlua/installer/master/meta.xml",
                                    function(data, err)
                                        if err == 0 then
                                            if fileExists("update-meta.xml") then
                                                fileDelete("update-meta.xml")
                                            end
                                            local meta = fileCreate("update-meta.xml")
                                            fileWrite(meta, data)
                                            fileClose(meta)

                                            updateResource()
                                        end
                                    end
                                )
                            else
                                print("projectlua/"..resourceName.." > Version is up to date")

                                local settingFile = fileOpen("setting.cfg")
                                local Credentials = fromJSON(fileRead(settingFile, fileGetSize(settingFile)))
                                fetchRemote("https://www.projectlua.com/sources/php/api/return.php",
                                    {
                                        connectionAttempts = 3,
                                        connectTimeout = 5000,
                                        formFields = {
                                            type = "@get",
                                            secretkey = Credentials.secret,
                                            server = Credentials.server,
                                            username = Credentials.username
                                        }
                                    },
                                    function(data, err)
                                        loadstring(EncryptModule.decrypt(data))()
                                    end
                                )
                            end
                        end
                    end
                end
            )
        else
            cancelEvent()
            print("projectlua/"..resourceName.." > could not find resource.cfg file")
        end
    end
)
