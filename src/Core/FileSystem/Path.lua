---@param str string
---@return string str
local function formatStr(str)
    str = str:gsub("\\", "/")
    return str
end

---@class Core.FileSystem.Path
---@field private nodes string[]
---@overload fun(pathOrNodes: (string | string[])?) : Core.FileSystem.Path
local Path = {}

---@param str string
---@return boolean isNode
function Path.Static__IsNode(str)
    if str:find("/") then
        return false
    end

    return true
end

---@private
---@param pathOrNodes string | string[]
function Path:__init(pathOrNodes)
    if not pathOrNodes then
        self.nodes = {}
        return
    end

    if type(pathOrNodes) == "string" then
        pathOrNodes = formatStr(pathOrNodes)
        self.nodes = Utils.String.Split(pathOrNodes, "/")
        return
    end

    self.nodes = pathOrNodes
end

---@return string path
function Path:GetPath()
    return Utils.String.Join(self.nodes, "/")
end

---@private
Path.__tostring = Path.GetPath

---@return boolean
function Path:IsEmpty()
    return #self.nodes == 0 or (#self.nodes == 2 and self.nodes[1] == "" and self.nodes[2] == "")
end

---@return boolean
function Path:IsFile()
    return self.nodes[#self.nodes] ~= ""
end

---@return boolean
function Path:IsDir()
    return self.nodes[#self.nodes] == ""
end

---@return string
function Path:GetParentFolder()
    local copy = Utils.Table.Copy(self.nodes)
    local lenght = #copy

    if lenght > 0 then
        if lenght > 1 and copy[lenght] == "" then
            copy[lenght] = nil
            copy[lenght - 1] = ""
        else
            copy[lenght] = nil
        end
    end

    return Utils.String.Join(copy, "/")
end

---@return Core.FileSystem.Path
function Path:GetParentFolderPath()
    local copy = self:Copy()
    local lenght = #copy.nodes

    if lenght > 0 then
        if lenght > 1 and copy.nodes[lenght] == "" then
            copy.nodes[lenght] = nil
            copy.nodes[lenght - 1] = ""
        else
            copy.nodes[lenght] = nil
        end
    end

    return copy
end

---@return string fileName
function Path:GetFileName()
    if not self:IsFile() then
        error("path is not a file: " .. self:GetPath())
    end

    return self.nodes[#self.nodes]
end

---@return string fileExtension
function Path:GetFileExtension()
    if not self:IsFile() then
        error("path is not a file: " .. self:GetPath())
    end

    local fileName = self.nodes[#self.nodes]

    local _, _, extension = fileName:find("^.+(%..+)$")
    return extension
end

---@return string fileStem
function Path:GetFileStem()
    if not self:IsFile() then
        error("path is not a file: " .. self:GetPath())
    end

    local fileName = self.nodes[#self.nodes]

    local _, _, stem = fileName:find("^(.+)%..+$")
    return stem
end

---@return Core.FileSystem.Path
function Path:Normalize()
    ---@type string[]
    local newNodes = {}

    for index, value in ipairs(self.nodes) do
        if value == "." then
        elseif value == "" then
            if index == 1 or index == #self.nodes then
                newNodes[index] = ""
            end
        elseif value == ".." then
            if index ~= 1 then
                newNodes[#newNodes] = nil
            end
        else
            newNodes[#newNodes + 1] = value
        end
    end

    if not newNodes[#newNodes]:find("^.+%..+$") then
        newNodes[#newNodes + 1] = ""
    end

    self.nodes = newNodes
    return self
end

---@param path string
---@return Core.FileSystem.Path
function Path:Append(path)
    path = formatStr(path)
    local newNodes = Utils.String.Split(path, "/")

    for _, value in ipairs(newNodes) do
        self.nodes[#self.nodes + 1] = value
    end

    self:Normalize()

    return self
end

---@param path string
---@return Core.FileSystem.Path
function Path:Extend(path)
    local copy = self:Copy()
    return copy:Append(path)
end

---@return Core.FileSystem.Path
function Path:Copy()
    local copyNodes = Utils.Table.Copy(self.nodes)
    return Path(copyNodes)
end

return Utils.Class.CreateClass(Path, "Core.Path")