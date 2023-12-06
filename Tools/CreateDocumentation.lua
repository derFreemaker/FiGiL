local FileSystem = require("Tools.FileSystem")

local args = { ... }
if #args < 3 then
    error("not all args given")
end

local DocUpdater = args[1]
local ApiDocumentationSource = FileSystem.Path(args[2])
local ApiDocumentationOutput = FileSystem.Path(args[3])

local docSourceFolders = FileSystem.GetDirectories(ApiDocumentationSource:GetPath())
for _, sourceFolder in pairs(docSourceFolders) do
    local folderPath = ApiDocumentationSource:Extend(sourceFolder):Extend("Doc")
    if not folderPath:Exists() then
        goto continue
    end

    local docSourceFiles = FileSystem.GetFiles(folderPath:GetPath())
    for _, file in pairs(docSourceFiles) do
        local filePath = folderPath:Extend(file)
        local outputFilePath = ApiDocumentationOutput
            :Extend(sourceFolder)
            :Extend(FileSystem.Path(file):GetFileStem() .. ".md")

        local command = DocUpdater .. " -s \"" .. filePath:GetPath() .. "\" -o \"" .. outputFilePath:GetPath() .. "\""
        os.execute(command)
    end

    ::continue::
end
