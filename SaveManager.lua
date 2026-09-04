-- 原作者: deividcomsono (https://github.com/deividcomsono/Obsidian) 汉化修改版本
local cloneref = (cloneref or clonereference or function(instance) return instance end)
local clonefunction = (clonefunction or copyfunction or function(func) return func end)
local HttpService = cloneref(game:GetService("HttpService"))

local isfolder, isfile, listfiles = isfolder, isfile, listfiles
local isfolder_copy, isfile_copy, listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)
local isfolder_success, isfolder_error = pcall(function() return isfolder_copy("test" .. tostring(math.random(1000000, 9999999))) end)
if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
    isfolder = function(folder) local success, data = pcall(isfolder_copy, folder) return (if success then data else false) end
    isfile = function(file) local success, data = pcall(isfile_copy, file) return (if success then data else false) end
    listfiles = function(folder) local success, data = pcall(listfiles_copy, folder) return (if success then data else {}) end
end

SaveManager = {
    Library = nil,
    Folder = "ObsidianLibSettings",
    SubFolder = "",
    Ignore = {},
    LoadingOrder = {},
    UseLoadingOrder = false,
    AutoloadConfig = nil
}

function SaveManager:SetLibrary(Library) SaveManager.Library = Library end

local SpecialValueParser = {
    UDim2 = {
        Encode = function(Value) return { X = { Scale = Value.X.Scale, Offset = Value.X.Offset }, Y = { Scale = Value.Y.Scale, Offset = Value.Y.Offset } } end,
        Decode = function(Data) local DataType = typeof(Data) if DataType == "table" then return UDim2.new(Data.X.Scale, Data.X.Offset, Data.Y.Scale, Data.Y.Offset) elseif DataType == "UDim2" then return Data end return nil end
    }
}

local ElementParser = {}; do
    local function CreateParser(ElementType, LibaryIndex, Save, Load, CustomElementFetcher)
        ElementParser[ElementType] = {
            Save = function(Index, Element, ...) local Data = Save(Index, Element, ...) Data.type = ElementType Data.idx = Index return Data end,
            Load = function(Index, Data) if CustomElementFetcher == true then return Load(nil, Data) end local Elements = SaveManager.Library and SaveManager.Library[LibaryIndex] local Element = Elements and Elements[Index] return Load(Element, Data) end
        }
    end

    CreateParser("Toggle", "Toggles",
        function(Index, Toggle) return { value = Toggle.Value } end,
        function(Element, Data) if not Element then return end if Element.Value == Data.value then Element:RunChanged() return end Element:SetValue(Data.value) end
    )

    CreateParser("Slider", "Options",
        function(Index, Slider) return { value = tostring(Slider.Value) } end,
        function(Element, Data) if not Element then return end if Element.Value == Data.value then Element:RunChanged() return end Element:SetValue(Data.value) end
    )

    CreateParser("Dropdown", "Options",
        function(Index, Dropdown) return { value = Dropdown.Value, multi = Dropdown.Multi } end,
        function(Element, Data) if not Element then return end if Element.Value == Data.value then Element:RunChanged() return end Element:SetValue(Data.value) end
    )

    CreateParser("ColorPicker", "Options",
        function(Index, ColorPicker) return { value = ColorPicker.Value:ToHex(), transparency = ColorPicker.Transparency } end,
        function(Element, Data) if not Element then return end Element:SetValueRGB(Color3.fromHex(Data.value), Data.transparency) end
    )

    CreateParser("KeyPicker", "Options",
        function(Index, KeyPicker) return { mode = KeyPicker.Mode, key = KeyPicker.Value, modifiers = KeyPicker.Modifiers, toggled = KeyPicker.Toggled } end,
        function(Element, Data) if not Element then return end Element:SetValue({ Data.key, Data.mode, Data.modifiers }) if Data.mode == "Toggle" and Data.toggled ~= nil then Element.Toggled = Data.toggled Element:Update() end end
    )

    CreateParser("Input", "Options",
        function(Index, Input) return { text = Input.Value } end,
        function(Element, Data) if not Element then return end if typeof(Data.text) ~= "string" then return end if Element.Value == Data.text then Element:RunChanged() return end Element:SetValue(Data.text) end
    )

    CreateParser("Groupbox", "Tabs",
        function(Index, Groupbox, TabIndex) return { tabIdx = TabIndex, collapsed = Groupbox.Collapsed, poppedOut = Groupbox.PoppedOut == true, popoutPos = if Groupbox.PoppedOut and Groupbox.PopOutFloat then SpecialValueParser.UDim2.Encode(Groupbox.PopOutFloat.Position) else nil end } end,
        function(_, Data) local TabIndex, Index = Data.tabIdx, Data.idx if typeof(TabIndex) ~= "string" or typeof(Index) ~= "string" then return end local Tabs = SaveManager.Library and SaveManager.Library.Tabs local Tab = Tabs and Tabs[TabIndex] if not Tab then return end local Groupbox = Tab.Groupboxes[Index] if not Groupbox then return end if Groupbox.Collapsed ~= Data.collapsed then Groupbox:SetCollapsed(Data.collapsed == true) end if Groupbox.PopOutEnabled then if Data.poppedOut == true then local Position = SpecialValueParser.UDim2.Decode(Data.popoutPos) Groupbox:SetPoppedOut(true, Position) elseif Groupbox.PoppedOut then Groupbox:SetPoppedOut(false) end end end,
        true
    )

    CreateParser("Tabbox", "Tabs",
        function(Index, Tabbox, TabIndex) return { tabIdx = TabIndex, poppedOut = Tabbox.PoppedOut == true, popoutPos = if Tabbox.PoppedOut and Tabbox.PopOutFloat then SpecialValueParser.UDim2.Encode(Tabbox.PopOutFloat.Position) else nil end } end,
        function(_, Data) local TabIndex, Index = Data.tabIdx, Data.idx if typeof(TabIndex) ~= "string" or typeof(Index) ~= "string" then return end local Tabs = SaveManager.Library and SaveManager.Library.Tabs local Tab = Tabs and Tabs[TabIndex] if not Tab then return end local Tabbox = Tab.Tabboxes and Tab.Tabboxes[Index] if not Tabbox then return end if Tabbox.PopOutEnabled then if Data.poppedOut == true then local Position = SpecialValueParser.UDim2.Decode(Data.popoutPos) Tabbox:SetPoppedOut(true, Position) elseif Tabbox.PoppedOut then Tabbox:SetPoppedOut(false) end end end,
        true
    )
end
local function Trim(Text) return Text:match("^%s*(.-)%s*$") end
local function IsStringEmpty(String) return if typeof(String) == "string" then Trim(String) == "" else true end
local function IsValidFolderPath(Name) return typeof(Name) == "string" and (Trim(Name) ~= "" and not Name:match("^%s*$") and not Name:find('[<>:"|%?%*%z]')) end

local function SplitPath(Path) local Result = {} local Current = "" for Part in string.gmatch(Path, "[^/]+") do Current = if Current == "" then Part else (Current .. "/" .. Part) table.insert(Result, Current) end return Result end
local function GetFolderPath() if IsStringEmpty(SaveManager.Folder) then return false end return string.format("%s/settings", SaveManager.Folder) end
local function GetSubFolderPath() if IsStringEmpty(SaveManager.Folder) or IsStringEmpty(SaveManager.SubFolder) then return false end return string.format("%s/settings/%s", SaveManager.Folder, SaveManager.SubFolder) end
local function GetCurrentSettingsPath() local SubFolderPath = GetSubFolderPath() return if SubFolderPath == false then GetFolderPath() else SubFolderPath end

local function GetConfigPath(ConfigName) local CurrentSettingsPath = GetCurrentSettingsPath() return if CurrentSettingsPath == false then false else string.format("%s/%s.json", CurrentSettingsPath, ConfigName) end
local function DoesConfigExist(ConfigName) local ConfigPath = GetConfigPath(ConfigName) return if ConfigPath == false then false else isfile(ConfigPath) end
local function GetAutoloadPath() local CurrentSettingsPath = GetCurrentSettingsPath() return if CurrentSettingsPath == false then false else string.format("%s/autoload.txt", CurrentSettingsPath) end

function SaveManager:SetLoadingOrder(Enabled, Order) SaveManager.UseLoadingOrder = Enabled == true SaveManager.LoadingOrder = typeof(Order) == "table" and Order or SaveManager.LoadingOrder end
function SaveManager:SetIgnoreIndexes(Indexes) assert(typeof(Indexes) == "table", "Expected table, got " .. typeof(Indexes)) for _, Index in Indexes do SaveManager.Ignore[Index] = true end end
function SaveManager:IgnoreThemeSettings() SaveManager:SetIgnoreIndexes({ "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", "FontFace", "BackgroundImage", "ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName", "ThemeManager_ThemeJSON" }) end

function SaveManager:GetPaths() local SubFolderPath = GetSubFolderPath() if SubFolderPath == false then local FolderPath = GetFolderPath() return if FolderPath == false then {} else SplitPath(FolderPath) end return SplitPath(SubFolderPath) end
function SaveManager:BuildFolderTree(SkipWhenCreated) local Paths = SaveManager:GetPaths() if #Paths == 0 then return false end if SkipWhenCreated == true then if isfolder(Paths[1]) then return true end end for _, Path in Paths do if isfolder(Path) then continue end makefolder(Path) end return true end
function SaveManager:CheckFolderTree() return SaveManager:BuildFolderTree(true) end
function SaveManager:CheckSubFolder(CreateFolder) local SubFolderPath = GetSubFolderPath() if SubFolderPath == false then return false end local FolderExists = isfolder(SubFolderPath) if not CreateFolder then return FolderExists end makefolder(SubFolderPath) return true end
function SaveManager:SetFolder(Folder) assert(IsValidFolderPath(Folder), "提供的路径无效") SaveManager.Folder = Folder SaveManager:BuildFolderTree() end
function SaveManager:SetSubFolder(SubFolder) assert(IsValidFolderPath(SubFolder), "提供的路径无效") SaveManager.SubFolder = SubFolder SaveManager:BuildFolderTree() end
function SaveManager:RefreshConfigList()
    local SettingsPath = GetCurrentSettingsPath()
    if SettingsPath == false then return {} end
    local SuccessList, Files = pcall(listfiles, SettingsPath)
    if not (SuccessList and typeof(Files) == "table") then SaveManager.Library:Notify(string.format("加载配置列表失败：%s", tostring(Files))) return {} end
    local FileNames = {}
    for _, FilePath in Files do
        local RawFileName = FilePath:match("(.+)%..+$")
        if not RawFileName then continue end
        local Position = RawFileName:gsub("\\", "/"):find("/[^/]*$")
        local FileName = Position and RawFileName:sub(Position + 1) or RawFileName
        if not FileName or FileName == "autoload" then continue end
        table.insert(FileNames, FileName)
    end
    return FileNames
end

function SaveManager:SaveJSON(ConfigName)
    local Library = SaveManager.Library
    local IgnoreIndexes = SaveManager.Ignore
    local CurrentData = {
        timestamp = os.date("%d.%m.%Y %H:%M:%S"),
        name = ConfigName or "",
        objects = {},
        keybindMenu = if Library.KeybindFrame then { visible = Library.KeybindFrame.Visible, position = SpecialValueParser.UDim2.Encode(Library.KeybindFrame.Position) } else nil
    }
    for Index, Toggle in Library.Toggles do if not Toggle.Type then continue end if IgnoreIndexes[Index] then continue end local Parser = ElementParser[Toggle.Type] if not Parser then continue end table.insert(CurrentData.objects, Parser.Save(Index, Toggle)) end
    for Index, Option in Library.Options do if not Option.Type then continue end if IgnoreIndexes[Index] then continue end local Parser = ElementParser[Option.Type] if not Parser then continue end table.insert(CurrentData.objects, Parser.Save(Index, Option)) end
    for TabIndex, Tab in Library.Tabs do
        if Tab.Groupboxes then for Index, Groupbox in Tab.Groupboxes do if typeof(Index) ~= "string" or IgnoreIndexes[Index] then continue end local Parser = ElementParser.Groupbox if not Parser then continue end table.insert(CurrentData.objects, Parser.Save(Index, Groupbox, TabIndex)) end end
        if Tab.Tabboxes then for Index, Tabbox in Tab.Tabboxes do if typeof(Index) ~= "string" or IgnoreIndexes[Index] then continue end local Parser = ElementParser.Tabbox if not Parser then continue end table.insert(CurrentData.objects, Parser.Save(Index, Tabbox, TabIndex)) end end
    end
    local SuccessEncode, EncodedData = pcall(HttpService.JSONEncode, HttpService, CurrentData)
    if not SuccessEncode then return "", false, "编码数据失败" end
    return EncodedData, true
end

function SaveManager:Save(ConfigName)
    if IsStringEmpty(ConfigName) then return false, "提供的配置名称无效" end
    if string.lower(ConfigName) == "autoload" then return false, "提供的配置名称无效" end
    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false then return false, "提供的配置名称无效" end
    SaveManager:CheckFolderTree()
    local EncodedData, SuccessEncode, EncodeErrorMessage = SaveManager:SaveJSON(ConfigName)
    if not SuccessEncode then return false, EncodeErrorMessage end
    local SuccessWrite, ErrorMessage = pcall(writefile, ConfigPath, EncodedData)
    if not SuccessWrite then return false, "写入配置文件失败：" .. tostring(ErrorMessage) end
    return true
end
function SaveManager:LoadJSON(Content)
    if IsStringEmpty(Content) then return false, "未提供 JSON" end
    local SuccessDecode, Decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not SuccessDecode or typeof(Decoded) ~= "table" or typeof(Decoded.objects) ~= "table" then return false, "解码配置数据失败" end
    local Library = SaveManager.Library
    local LoadingOrder = SaveManager.LoadingOrder
    local IgnoreIndexes = SaveManager.Ignore
    if SaveManager.UseLoadingOrder == true and typeof(LoadingOrder) == "table" then
        table.sort(Decoded.objects, function(a, b) local aIndex = table.find(LoadingOrder, a.type) or math.huge local bIndex = table.find(LoadingOrder, b.type) or math.huge return aIndex < bIndex end)
    end
    if Library.KeybindFrame and typeof(Decoded.keybindMenu) == "table" then
        local KeybindFrameData = Decoded.keybindMenu
        local IsVisible = KeybindFrameData.visible == true
        local Position = SpecialValueParser.UDim2.Decode(KeybindFrameData.position)
        Library.KeybindFrame.Visible = IsVisible
        Library.KeybindFrame.Position = Position or Library.KeybindFrame.Position
        local KeybindMenuToggle = Library.Options and Library.Options.KeybindMenuOpen
        if KeybindMenuToggle then KeybindMenuToggle:SetValue(IsVisible) end
    end
    for _, Option in Decoded.objects do
        if not Option.type then continue end
        if IgnoreIndexes[Option.idx] then continue end
        local Parser = ElementParser[Option.type]
        if not Parser then continue end
        task.defer(Parser.Load, Option.idx, Option)
    end
    return true
end

function SaveManager:Load(ConfigName)
    if IsStringEmpty(ConfigName) then return false, "未选择配置" end
    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false or not isfile(ConfigPath) then return false, "配置文件不存在" end
    local SuccessRead, Content = pcall(readfile, ConfigPath)
    if not SuccessRead then return false, "读取配置文件失败" end
    return SaveManager:LoadJSON(Content)
end

function SaveManager:Delete(ConfigName)
    if IsStringEmpty(ConfigName) then return false, "未选择配置" end
    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false or not isfile(ConfigPath) then return false, "配置文件不存在" end
    local SuccessDelete, ErrorMessage = pcall(delfile, ConfigPath)
    if not SuccessDelete then return false, "删除配置文件失败：" .. tostring(ErrorMessage) end
    if ConfigName == SaveManager.AutoloadConfig then SaveManager:DeleteAutoLoadConfig() end
    return true
end
function SaveManager:GetAutoloadConfig()
    SaveManager:CheckFolderTree()
    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then return "none", false, "提供的路径无效" end
    if not isfile(AutoloadPath) then return "none", false, "未设置自动加载配置" end
    local SuccessRead, AutoloadConfigName = pcall(readfile, AutoloadPath)
    if not (SuccessRead and typeof(AutoloadConfigName) == "string") then return "none", false, AutoloadConfigName end
    local ConfigExists = DoesConfigExist(AutoloadConfigName)
    if not ConfigExists then return "none", false, "配置文件未找到" end
    SaveManager.AutoloadConfig = AutoloadConfigName
    return AutoloadConfigName, true
end

function SaveManager:SaveAutoloadConfig(ConfigName)
    if IsStringEmpty(ConfigName) then return false, "未选择配置" end
    SaveManager:CheckFolderTree()
    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then return false, "提供的路径无效" end
    if not DoesConfigExist(ConfigName) then return false, "配置不存在" end
    local SuccessWrite, ErrorMessage = pcall(writefile, AutoloadPath, ConfigName)
    if not SuccessWrite then return false, ErrorMessage end
    SaveManager.AutoloadConfig = ConfigName
    return true
end

function SaveManager:LoadAutoloadConfig()
    local ConfigName, Success, FetchErrorMessage = SaveManager:GetAutoloadConfig()
    if not Success or FetchErrorMessage then
        if FetchErrorMessage ~= "未设置自动加载配置" then SaveManager.Library:Notify(string.format("加载自动加载配置失败：%s", FetchErrorMessage)) end
        return
    end
    local SuccessLoad, LoadErrorMessage = SaveManager:Load(ConfigName)
    if not SuccessLoad then SaveManager.Library:Notify(string.format("加载自动加载配置失败：%s", LoadErrorMessage)) return end
    SaveManager.Library:Notify(string.format("成功加载自动加载配置 %q", ConfigName))
end

function SaveManager:DeleteAutoLoadConfig()
    SaveManager:CheckFolderTree()
    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then return false, "提供的路径无效" end
    if not isfile(AutoloadPath) then return false, "未设置自动加载配置" end
    local SuccessDelete, ErrorMessage = pcall(delfile, AutoloadPath)
    if not SuccessDelete then return false, ErrorMessage end
    SaveManager.AutoloadConfig = nil
    return true
end
local function ShowDialog(Condition, Index, Title, Description, DestructiveText, DestructiveAction)
    if Condition() == false then return DestructiveAction() end
    return SaveManager.Library.Window:AddDialog(Index, {
        Title = Title,
        Description = Description,
        AutoDismiss = false,
        FooterButtons = {
            Cancel = { Title = "取消", Variant = "Ghost", Order = 1, Callback = function(Dialog) Dialog:Dismiss() end },
            DestructiveAction = { Title = DestructiveText, Variant = "Destructive", Order = 2, Callback = function(Dialog) Dialog:Dismiss() DestructiveAction() end }
        }
    })
end

function SaveManager:BuildConfigSection(Tab, IconName)
    assert(SaveManager.Library, "未设置 Library，请先调用 SaveManager:SetLibrary(Library)。")
    local ConfigurationBox = Tab:AddGroupbox({ Side = "Right", Name = "配置", IconName = IconName or "folder-cog" })
    local ConfigNameInput, ConfigList, ConfigJSONInput, AutoloadConfigLabel
    local function RefreshList() ConfigList:SetValues(SaveManager:RefreshConfigList()) ConfigList:SetValue(nil) end
    local function RefreshAutoloadConfigLabel()
        local AutoloadConfigName, _Success, _ErrorMessage = SaveManager:GetAutoloadConfig()
        AutoloadConfigLabel:SetText(string.format("当前自动加载配置：%s", AutoloadConfigName))
        if ConfigList then RefreshList() end
    end

    ConfigurationBox:AddInput("SaveManager_ConfigName", { Text = "配置名称" })
    ConfigurationBox:AddButton("创建配置", function()
        local ConfigName = ConfigNameInput.Value
        if IsStringEmpty(ConfigName) then SaveManager.Library:Notify("配置名称不能为空。") return end
        if string.lower(ConfigName) == "autoload" then SaveManager.Library:Notify("提供的配置名称无效。") return end
        ShowDialog(
            function() return DoesConfigExist(ConfigName) end,
            "SaveManager_CreateConfig", "配置已存在",
            string.format("名为 %q 的配置已存在。覆盖将用当前设置替换它。", ConfigName),
            "覆盖",
            function()
                local Success, ErrorMessage = SaveManager:Save(ConfigName)
                if not Success then SaveManager.Library:Notify(string.format("创建配置 %q 失败：%s", ConfigName, ErrorMessage)) return end
                SaveManager.Library:Notify(string.format("成功创建配置 %q", ConfigName))
                RefreshList()
            end
        )
    end)
    ConfigurationBox:AddDivider()

    ConfigurationBox:AddDropdown("SaveManager_ConfigList", {
        Text = "配置列表",
        Values = SaveManager:RefreshConfigList(),
        AllowNull = true,
        Multi = false,
        FormatDisplayValue = function(Value) if Value == SaveManager.AutoloadConfig then return string.format("%s (自动加载)", Value) end return Value end,
        FormatListValue = function(Value) if Value == SaveManager.AutoloadConfig then return string.format("%s (自动加载)", Value) end return Value end
    })
    ConfigurationBox:AddButton({ Text = "加载配置", DoubleClick = false, Func = function()
        local ConfigName = ConfigList.Value
        if IsStringEmpty(ConfigName) then SaveManager.Library:Notify("请先选择一个配置。") return end
        ShowDialog(
            function() return true end,
            "SaveManager_LoadConfig", "加载配置",
            string.format("确定要加载 %q 吗？当前设置将被覆盖。", ConfigName),
            "加载",
            function()
                local Success, ErrorMessage = SaveManager:Load(ConfigName)
                if not Success then SaveManager.Library:Notify(string.format("加载配置 %q 失败：%s", ConfigName, ErrorMessage)) return end
                SaveManager.Library:Notify(string.format("成功加载配置 %q", ConfigName))
            end
        )
    end })
    ConfigurationBox:AddButton({ Text = "覆盖配置", DoubleClick = false, Func = function()
        local ConfigName = ConfigList.Value
        if IsStringEmpty(ConfigName) then SaveManager.Library:Notify("请先选择一个配置。") return end
        ShowDialog(
            function() return true end,
            "SaveManager_OverwriteConfig", "覆盖配置",
            string.format("确定要用当前设置覆盖 %q 吗？此操作不可撤销。", ConfigName),
            "覆盖",
            function()
                local Success, ErrorMessage = SaveManager:Save(ConfigName)
                if not Success then SaveManager.Library:Notify(string.format("覆盖配置 %q 失败：%s", ConfigName, ErrorMessage)) return end
                SaveManager.Library:Notify(string.format("成功覆盖配置 %q", ConfigName))
            end
        )
    end })
    ConfigurationBox:AddButton({ Text = "删除配置", DoubleClick = false, Func = function()
        local ConfigName = ConfigList.Value
        if IsStringEmpty(ConfigName) then SaveManager.Library:Notify("请先选择一个配置。") return end
        ShowDialog(
            function() return true end,
            "SaveManager_DeleteConfig", "删除配置",
            string.format("确定要删除 %q 吗？此操作不可撤销。", ConfigName),
            "删除",
            function()
                local Success, ErrorMessage = SaveManager:Delete(ConfigName)
                if not Success then SaveManager.Library:Notify(string.format("删除配置 %q 失败：%s", ConfigName, ErrorMessage)) return end
                SaveManager.Library:Notify(string.format("成功删除配置 %q", ConfigName))
                RefreshAutoloadConfigLabel()
            end
        )
    end })
    ConfigurationBox:AddButton("刷新列表", RefreshList)

    ConfigurationBox:AddButton({ Text = "设为自动加载", DoubleClick = false, Func = function()
        local ConfigName = ConfigList.Value
        if IsStringEmpty(ConfigName) then SaveManager.Library:Notify("请先选择一个配置。") return end
        local Success, ErrorMessage = SaveManager:SaveAutoloadConfig(ConfigName)
        if not Success then SaveManager.Library:Notify(string.format("设置自动加载配置 %q 失败：%s", ConfigName, ErrorMessage)) return end
        SaveManager.Library:Notify(string.format("成功设置自动加载配置为 %q", ConfigName))
        RefreshAutoloadConfigLabel()
    end })
    ConfigurationBox:AddButton({ Text = "重置自动加载", DoubleClick = false, Func = function()
        ShowDialog(
            function() return true end,
            "SaveManager_ResetAutoload", "重置自动加载配置",
            "确定要清除自动加载配置吗？下次启动将不会自动加载任何配置。",
            "重置",
            function()
                local Success, ErrorMessage = SaveManager:DeleteAutoLoadConfig()
                if not Success then SaveManager.Library:Notify(string.format("重置自动加载配置失败：%s", ErrorMessage)) return end
                SaveManager.Library:Notify("成功重置自动加载配置。")
                RefreshAutoloadConfigLabel()
            end
        )
    end })
    AutoloadConfigLabel = ConfigurationBox:AddLabel("当前自动加载配置：...", true)
    ConfigurationBox:AddDivider()

    ConfigurationBox:AddInput("SaveManager_JSON", { Text = "配置 JSON" })
    ConfigurationBox:AddButton("导入配置", function()
        local ConfigJSON = ConfigJSONInput.Value
        if IsStringEmpty(ConfigJSON) then SaveManager.Library:Notify("配置 JSON 不能为空") return end
        ShowDialog(
            function() return true end,
            "SaveManager_ImportConfig", "导入配置",
            "确定要导入此配置吗？当前设置将被覆盖。",
            "导入",
            function()
                local Success, ErrorMessage = SaveManager:LoadJSON(ConfigJSON)
                if not Success then SaveManager.Library:Notify(string.format("导入配置失败：%s", ErrorMessage)) return end
                SaveManager.Library:Notify("成功导入配置")
            end
        )
    end)
    ConfigurationBox:AddButton("导出当前配置", function()
        local EncodedData, Success, ErrorMessage = SaveManager:SaveJSON()
        if not Success then SaveManager.Library:Notify(ErrorMessage) return end
        ConfigJSONInput:SetValue(EncodedData)
        if setclipboard then setclipboard(EncodedData) SaveManager.Library:Notify("已复制配置到剪贴板") end
    end)

    ConfigNameInput, ConfigList, ConfigJSONInput = SaveManager.Library.Options.SaveManager_ConfigName, SaveManager.Library.Options.SaveManager_ConfigList, SaveManager.Library.Options.SaveManager_JSON
    RefreshAutoloadConfigLabel()
    SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName", "SaveManager_JSON" })
    return ConfigurationBox
end

SaveManager:BuildFolderTree()
