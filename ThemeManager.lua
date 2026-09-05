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

local ContrastWarnThreshold = 4.5
local SrgbLinearThreshold = 0.03928
local SrgbLinearDivisor = 12.92
local SrgbGammaOffset = 0.055
local SrgbGammaScale = 1.055
local SrgbGammaExponent = 2.4
local LuminanceRedWeight, LuminanceGreenWeight, LuminanceBlueWeight = 0.2126, 0.7152, 0.0722
local ContrastRatioOffset = 0.05

local SchemeIndexes = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }

ThemeManager = {
    Library = nil,
    Folder = "ObsidianLibSettings",
    AppliedToTab = false,
    DefaultThemeName = nil,
    ContrastLabel = nil,
    ContrastWasPoor = false,
    BuiltInThemes = {
        ["Default"] = { 1, { FontColor = "ffffff", MainColor = "191919", AccentColor = "7d55ff", BackgroundColor = "0f0f0f", OutlineColor = "282828", BackgroundImage = "" } },
        ["BBot"] = { 2, { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414", BackgroundImage = "" } },
        ["Fatality"] = { 3, { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d", BackgroundImage = "" } },
        ["Jester"] = { 4, { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737", BackgroundImage = "" } },
        ["Mint"] = { 5, { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737", BackgroundImage = "" } },
        ["Tokyo Night"] = { 6, { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232", BackgroundImage = "" } },
        ["Ubuntu"] = { 7, { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919", BackgroundImage = "" } },
        ["Quartz"] = { 8, { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f", BackgroundImage = "" } },
        ["Nord"] = { 9, { FontColor = "eceff4", MainColor = "3b4252", AccentColor = "88c0d0", BackgroundColor = "2e3440", OutlineColor = "4c566a", BackgroundImage = "" } },
        ["Dracula"] = { 10, { FontColor = "f8f8f2", MainColor = "44475a", AccentColor = "ff79c6", BackgroundColor = "282a36", OutlineColor = "6272a4", BackgroundImage = "" } },
        ["Monokai"] = { 11, { FontColor = "f8f8f2", MainColor = "272822", AccentColor = "f92672", BackgroundColor = "1e1f1c", OutlineColor = "49483e", BackgroundImage = "" } },
        ["Gruvbox"] = { 12, { FontColor = "ebdbb2", MainColor = "3c3836", AccentColor = "fb4934", BackgroundColor = "282828", OutlineColor = "504945", BackgroundImage = "" } },
        ["Solarized"] = { 13, { FontColor = "839496", MainColor = "073642", AccentColor = "cb4b16", BackgroundColor = "002b36", OutlineColor = "586e75", BackgroundImage = "" } },
        ["Catppuccin"] = { 14, { FontColor = "d9e0ee", MainColor = "302d41", AccentColor = "f5c2e7", BackgroundColor = "1e1e2e", OutlineColor = "575268", BackgroundImage = "" } },
        ["One Dark"] = { 15, { FontColor = "abb2bf", MainColor = "282c34", AccentColor = "c678dd", BackgroundColor = "21252b", OutlineColor = "5c6370", BackgroundImage = "" } },
        ["Cyberpunk"] = { 16, { FontColor = "f9f9f9", MainColor = "262335", AccentColor = "00ff9f", BackgroundColor = "1a1a2e", OutlineColor = "413c5e", BackgroundImage = "" } },
        ["Oceanic Next"] = { 17, { FontColor = "d8dee9", MainColor = "1b2b34", AccentColor = "6699cc", BackgroundColor = "16232a", OutlineColor = "343d46", BackgroundImage = "" } },
        ["Material"] = { 18, { FontColor = "eeffff", MainColor = "212121", AccentColor = "82aaff", BackgroundColor = "151515", OutlineColor = "424242", BackgroundImage = "" } }
    }
            }
function ThemeManager:SetLibrary(Library) ThemeManager.Library = Library end

local function Trim(Text) return Text:match("^%s*(.-)%s*$") end
local function IsStringEmpty(String) return if typeof(String) == "string" then Trim(String) == "" else true end
local function IsValidFolderPath(Name) return typeof(Name) == "string" and (Trim(Name) ~= "" and not Name:match("^%s*$") and not Name:find('[<>:"|%?%*%z]')) end

local function LinearizeChannel(Channel) if Channel <= SrgbLinearThreshold then return Channel / SrgbLinearDivisor end return ((Channel + SrgbGammaOffset) / SrgbGammaScale) ^ SrgbGammaExponent end
local function GetRelativeLuminance(Color) local R = LinearizeChannel(Color.R) local G = LinearizeChannel(Color.G) local B = LinearizeChannel(Color.B) return LuminanceRedWeight * R + LuminanceGreenWeight * G + LuminanceBlueWeight * B end
local function GetContrastRatio(ColorA, ColorB) local LuminanceA = GetRelativeLuminance(ColorA) local LuminanceB = GetRelativeLuminance(ColorB) local Lighter = math.max(LuminanceA, LuminanceB) local Darker = math.min(LuminanceA, LuminanceB) return (Lighter + ContrastRatioOffset) / (Darker + ContrastRatioOffset) end
local function IsValidThemeData(Data) if typeof(Data) ~= "table" then return false end for _, SchemeIndex in SchemeIndexes do if typeof(Data[SchemeIndex]) ~= "string" then return false end end return true end

local function SplitPath(Path) local Result = {} local Current = "" for Part in string.gmatch(Path, "[^/]+") do Current = if Current == "" then Part else (Current .. "/" .. Part) table.insert(Result, Current) end return Result end
local function GetFolderPath() if IsStringEmpty(ThemeManager.Folder) then return false end return string.format("%s/themes", ThemeManager.Folder) end
local GetCurrentThemesPath = GetFolderPath
local function GetThemePath(ThemeName) local CurrentThemesPath = GetCurrentThemesPath() return if CurrentThemesPath == false then false else string.format("%s/%s.json", CurrentThemesPath, ThemeName) end
local function DoesThemeExist(ThemeName, IncludeBuiltIn) if ThemeManager.BuiltInThemes[ThemeName] then return true end local ThemePath = GetThemePath(ThemeName) return if ThemePath == false then false else isfile(ThemePath) end
local function GetDefaultThemePath() local CurrentThemesPath = GetCurrentThemesPath() return if CurrentThemesPath == false then false else string.format("%s/default.txt", CurrentThemesPath) end

function ThemeManager:GetPaths() local FolderPath = GetFolderPath() return if FolderPath == false then {} else SplitPath(FolderPath) end
function ThemeManager:BuildFolderTree(SkipWhenCreated) local Paths = ThemeManager:GetPaths() if #Paths == 0 then return false end if SkipWhenCreated == true then if isfolder(Paths[1]) then return true end end for _, Path in Paths do if isfolder(Path) then continue end makefolder(Path) end return true end
function ThemeManager:CheckFolderTree() return ThemeManager:BuildFolderTree(true) end
function ThemeManager:SetFolder(Folder) assert(IsValidFolderPath(Folder), "提供的路径无效") ThemeManager.Folder = Folder ThemeManager:BuildFolderTree() end
function ThemeManager:ReloadCustomThemes()
    local SettingsPath = GetCurrentThemesPath()
    if SettingsPath == false then return {} end
    local SuccessList, Files = pcall(listfiles, SettingsPath)
    if not (SuccessList and typeof(Files) == "table") then ThemeManager.Library:Notify(string.format("加载主题列表失败：%s", tostring(Files))) return {} end
    local FileNames = {}
    for _, FilePath in Files do
        local RawFileName = FilePath:match("(.+)%..+$")
        if not RawFileName then continue end
        local Position = RawFileName:gsub("\\", "/"):find("/[^/]*$")
        local FileName = Position and RawFileName:sub(Position + 1) or RawFileName
        if not FileName or FileName == "default" then continue end
        table.insert(FileNames, FileName)
    end
    return FileNames
end

function ThemeManager:GetCustomTheme(ThemeName)
    if IsStringEmpty(ThemeName) then return nil end
    local ThemePath = GetThemePath(ThemeName)
    if ThemePath == false or not isfile(ThemePath) then return nil end
    local SuccessRead, Content = pcall(readfile, ThemePath)
    if not SuccessRead then return nil end
    local SuccessDecode, Decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not SuccessDecode or typeof(Decoded) ~= "table" then return nil end
    return Decoded
end

local function BuildCurrentThemeData()
    local Library = ThemeManager.Library
    local ThemeData = { FontFace = Library.Options.FontFace.Value, BackgroundImage = Library.Options.BackgroundImage.Value }
    for _, SchemeIndex in SchemeIndexes do ThemeData[SchemeIndex] = Library.Options[SchemeIndex].Value:ToHex() end
    return ThemeData
end

function ThemeManager:SaveCustomTheme(ThemeName)
    if IsStringEmpty(ThemeName) then return false, "提供的主题名称无效" end
    if string.lower(ThemeName) == "default" then return false, "提供的主题名称无效" end
    local ThemePath = GetThemePath(ThemeName)
    if ThemePath == false then return false, "提供的主题名称无效" end
    ThemeManager:CheckFolderTree()
    local EncodedData, SuccessEncode, EncodeErrorMessage = ThemeManager:SaveJSON()
    if not SuccessEncode then return false, EncodeErrorMessage end
    local SuccessWrite, ErrorMessage = pcall(writefile, ThemePath, EncodedData)
    if not SuccessWrite then return false, "写入主题文件失败：" .. tostring(ErrorMessage) end
    return true
end

function ThemeManager:Delete(ThemeName)
    if IsStringEmpty(ThemeName) then return false, "未选择主题" end
    local ThemePath = GetThemePath(ThemeName)
    if ThemePath == false or not isfile(ThemePath) then return false, "主题文件不存在" end
    local SuccessDelete, ErrorMessage = pcall(delfile, ThemePath)
    if not SuccessDelete then return false, "删除主题文件失败：" .. tostring(ErrorMessage) end
    if ThemeName == ThemeManager.DefaultThemeName then ThemeManager:DeleteDefaultTheme() end
    return true
                                    end
function ThemeManager:GetDefaultTheme()
    ThemeManager:CheckFolderTree()
    local DefaultThemePath = GetDefaultThemePath()
    if DefaultThemePath == false then return "none", false, "提供的路径无效" end
    if not isfile(DefaultThemePath) then return "none", false, "未设置默认主题" end
    local SuccessRead, DefaultThemeName = pcall(readfile, DefaultThemePath)
    if not (SuccessRead and typeof(DefaultThemeName) == "string") then return "none", false, DefaultThemeName end
    local ConfigExists = DoesThemeExist(DefaultThemeName, true)
    if not ConfigExists then return "none", false, "主题文件未找到" end
    ThemeManager.DefaultThemeName = DefaultThemeName
    return DefaultThemeName, true
end

function ThemeManager:SetDefaultTheme(Theme)
    assert(ThemeManager.Library, "未设置 Library，请先调用 ThemeManager:SetLibrary(Library)。")
    assert(not ThemeManager.AppliedToTab, "无法在将 ThemeManager 应用到选项卡后设置默认主题！")
    local Library = ThemeManager.Library
    local DefaultThemeData = ThemeManager.BuiltInThemes["Default"][2]
    local LibraryScheme = {}
    local FinalTheme = {}
    for _, SchemeIndex in SchemeIndexes do
        local IndexData = Theme[SchemeIndex]
        local IndexType = typeof(IndexData)
        if IndexType == "Color3" then
            LibraryScheme[SchemeIndex] = IndexData
            FinalTheme[SchemeIndex] = string.format("#%s", IndexData:ToHex())
        elseif IndexType == "string" then
            LibraryScheme[SchemeIndex] = Color3.fromHex(IndexData)
            FinalTheme[SchemeIndex] = if IndexData:sub(1, 1) == "#" then IndexData else string.format("#%s", IndexData)
        else
            local Value = DefaultThemeData[SchemeIndex]
            LibraryScheme[SchemeIndex] = Color3.fromHex(Value)
            FinalTheme[SchemeIndex] = Value
        end
    end
    local FontFace = Theme["FontFace"]
    local FontFaceType = typeof(FontFace)
    if FontFaceType == "EnumItem" then
        LibraryScheme.Font = Font.fromEnum(FontFace)
        FinalTheme.FontFace = FontFace.Name
    elseif FontFaceType == "string" then
        LibraryScheme.Font = Font.fromEnum(Enum.Font[FontFace])
        FinalTheme.FontFace = FontFace
    else
        LibraryScheme.Font = Font.fromEnum(Enum.Font.Code)
        FinalTheme.FontFace = "Code"
    end
    for _, DefaultSchemeColor in { "RedColor", "DestructiveColor", "DarkColor", "WhiteColor" } do
        LibraryScheme[DefaultSchemeColor] = Library.Scheme[DefaultSchemeColor]
    end
    Library.Scheme = LibraryScheme
    ThemeManager.BuiltInThemes["Default"] = { 1, FinalTheme }
    Library:UpdateColorsUsingRegistry()
end

function ThemeManager:SaveDefault(ThemeName)
    if IsStringEmpty(ThemeName) then return false, "未选择主题" end
    ThemeManager:CheckFolderTree()
    local DefaultThemePath = GetDefaultThemePath()
    if DefaultThemePath == false then return false, "提供的路径无效" end
    if not DoesThemeExist(ThemeName, true) then return false, "主题不存在" end
    local SuccessWrite, ErrorMessage = pcall(writefile, DefaultThemePath, ThemeName)
    if not SuccessWrite then return false, ErrorMessage end
    ThemeManager.DefaultThemeName = ThemeName
    return true
end

function ThemeManager:LoadDefault()
    local ThemeName, Success, FetchErrorMessage = ThemeManager:GetDefaultTheme()
    if not Success or FetchErrorMessage then
        if FetchErrorMessage ~= "未设置默认主题" then ThemeManager.Library:Notify(string.format("应用默认主题失败：%s", FetchErrorMessage)) end
        return
    end
    if not ThemeManager:GetCustomTheme(ThemeName) then
        ThemeManager.Library.Options.ThemeManager_ThemeList:SetValue(ThemeName)
        return
    end
    local SuccessLoad, LoadErrorMessage = ThemeManager:ApplyTheme(ThemeName)
    if not SuccessLoad then ThemeManager.Library:Notify(string.format("应用默认主题失败：%s", LoadErrorMessage)) return end
    ThemeManager.Library:Notify(string.format("成功应用默认主题 %q", ThemeName))
end

function ThemeManager:DeleteDefaultTheme()
    ThemeManager:CheckFolderTree()
    local DefaultThemePath = GetDefaultThemePath()
    if DefaultThemePath == false then return false, "提供的路径无效" end
    if not isfile(DefaultThemePath) then return false, "未设置默认主题" end
    local SuccessDelete, ErrorMessage = pcall(delfile, DefaultThemePath)
    if not SuccessDelete then return false, ErrorMessage end
    ThemeManager.DefaultThemeName = nil
    return true
                                        end
function ThemeManager:GetContrastReport()
    local Library = ThemeManager.Library
    local FontColorOption = Library.Options.FontColor
    local BackgroundColorOption = Library.Options.BackgroundColor
    local MainColorOption = Library.Options.MainColor
    if not (FontColorOption and BackgroundColorOption and MainColorOption) then return { Ratio = math.huge, PairName = "", Passes = true } end
    local FontColor = FontColorOption.Value
    local Surfaces = {
        { Name = "字体颜色与背景颜色", Color = BackgroundColorOption.Value },
        { Name = "字体颜色与主颜色", Color = MainColorOption.Value },
    }
    local WorstRatio, WorstName = math.huge, ""
    for _, Surface in Surfaces do
        local Ratio = GetContrastRatio(FontColor, Surface.Color)
        if Ratio < WorstRatio then WorstRatio = Ratio WorstName = Surface.Name end
    end
    return { Ratio = WorstRatio, PairName = WorstName, Passes = WorstRatio >= ContrastWarnThreshold }
end

function ThemeManager:UpdateContrastWarning()
    local ContrastLabel = ThemeManager.ContrastLabel
    if not ContrastLabel or ContrastLabel.Destroyed then return end
    local Library = ThemeManager.Library
    local Report = ThemeManager:GetContrastReport()
    local TextLabel = ContrastLabel.TextLabel
    if not Library.Registry[TextLabel] then Library:AddToRegistry(TextLabel, {}) end
    if Report.Passes then
        ContrastLabel:SetText(string.format("对比度检查：良好 (%.1f:1)", Report.Ratio))
        TextLabel.TextColor3 = Library.Scheme.FontColor
        Library.Registry[TextLabel].TextColor3 = "FontColor"
    else
        ContrastLabel:SetText(string.format("对比度低 (%.1f:1)，在 %s 之间。目标至少 %.1f:1 以便文本保持可读。", Report.Ratio, Report.PairName, ContrastWarnThreshold))
        TextLabel.TextColor3 = Library.Scheme.RedColor
        Library.Registry[TextLabel].TextColor3 = "RedColor"
    end
    ThemeManager.ContrastWasPoor = not Report.Passes
end

function ThemeManager:ThemeUpdate()
    local Library = ThemeManager.Library
    for _, SchemeIndex in SchemeIndexes do local Element = Library.Options[SchemeIndex] if not Element then continue end Library.Scheme[SchemeIndex] = Element.Value end
    Library:UpdateColorsUsingRegistry()
    ThemeManager:UpdateContrastWarning()
end

function ThemeManager:ApplyThemeData(ThemeData)
    if typeof(ThemeData) ~= "table" then return false, "无效的主题数据" end
    local Library = ThemeManager.Library
    for Index, Value in ThemeData do
        if Index == "VideoLink" then continue end
        local Element = Library.Options[Index]
        local FinalValue = Value
        if Index == "FontFace" then
            if typeof(Value) ~= "string" or not Enum.Font[Value] then continue end
            ThemeManager.Library:SetFont(Enum.Font[Value])
        elseif Index == "BackgroundImage" then
            if typeof(Value) ~= "string" then continue end
            ThemeManager.Library:SetBackgroundImage(Value)
        elseif table.find(SchemeIndexes, Index) then
            local SuccessColor, Color = pcall(Color3.fromHex, Value)
            if not SuccessColor then continue end
            FinalValue = Color
            Library.Scheme[Index] = FinalValue
        else
            continue
        end
        if Element then Element:SetValue(FinalValue) end
    end
    ThemeManager:ThemeUpdate()
    return true
end

function ThemeManager:ApplyTheme(ThemeName)
    if IsStringEmpty(ThemeName) then return false, "未选择主题" end
    local CustomThemeData = ThemeManager:GetCustomTheme(ThemeName)
    local Data = CustomThemeData or ThemeManager.BuiltInThemes[ThemeName]
    if not Data then return false, "未找到主题" end
    local ThemeData = CustomThemeData or Data[2]
    return ThemeManager:ApplyThemeData(ThemeData)
end

function ThemeManager:SaveJSON()
    local ThemeData = BuildCurrentThemeData()
    local SuccessEncode, EncodedData = pcall(HttpService.JSONEncode, HttpService, ThemeData)
    if not SuccessEncode then return "", false, "编码数据失败" end
    return EncodedData, true
end

function ThemeManager:LoadJSON(Content)
    if IsStringEmpty(Content) then return false, "未提供 JSON" end
    local SuccessDecode, Decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not SuccessDecode or not IsValidThemeData(Decoded) then return false, "解码主题数据失败" end
    return ThemeManager:ApplyThemeData(Decoded)
                                        end
local function ShowDialog(Condition, Index, Title, Description, DestructiveText, DestructiveAction)
    if Condition() == false then return DestructiveAction() end
    return ThemeManager.Library.Window:AddDialog(Index, {
        Title = Title,
        Description = Description,
        AutoDismiss = false,
        FooterButtons = {
            Cancel = { Title = "取消", Variant = "Ghost", Order = 1, Callback = function(Dialog) Dialog:Dismiss() end },
            DestructiveAction = { Title = DestructiveText, Variant = "Destructive", Order = 2, Callback = function(Dialog) Dialog:Dismiss() DestructiveAction() end }
        }
    })
end

function ThemeManager:CreateThemeManager(Themesbox)
    assert(ThemeManager.Library, "未设置 Library，请先调用 ThemeManager:SetLibrary(Library)。")
    local BuiltInThemesNames = {}
    for Name, _ThemeData in ThemeManager.BuiltInThemes do table.insert(BuiltInThemesNames, Name) end
    local CustomThemeList, CustomThemeName, ThemeList, FontFace, BackgroundImage, DefaultThemeLabel, ThemeJSONInput
    local function RefreshList() CustomThemeList:SetValues(ThemeManager:ReloadCustomThemes()) CustomThemeList:SetValue(nil) ThemeList:SetValues(BuiltInThemesNames) end
    local function RefreshDefaultThemeLabel() local DefaultThemeName, _Success, _ErrorMessage = ThemeManager:GetDefaultTheme() DefaultThemeLabel:SetText(string.format("当前默认主题：%s", DefaultThemeName)) if CustomThemeList then RefreshList() end end
    table.sort(BuiltInThemesNames, function(IndexA, IndexB) return ThemeManager.BuiltInThemes[IndexA][1] < ThemeManager.BuiltInThemes[IndexB][1] end)

    local function CreateColorOption(Text, SchemeIndex) Themesbox:AddLabel(Text):AddColorPicker(SchemeIndex, { Default = ThemeManager.Library.Scheme[SchemeIndex] }) return ThemeManager.Library.Options[SchemeIndex] end
    local BackgroundColor = CreateColorOption("背景颜色", "BackgroundColor")
    local MainColor = CreateColorOption("按钮颜色", "MainColor")
    local AccentColor = CreateColorOption("图标颜色", "AccentColor")
    local OutlineColor = CreateColorOption("轮廓颜色", "OutlineColor")
    local FontColor = CreateColorOption("字体颜色", "FontColor")

    ThemeManager.ContrastLabel = Themesbox:AddLabel({ Text = "对比度检查：无", DoesWrap = true })
    Themesbox:AddDropdown("FontFace", { Text = "字体", Default = "Code", Values = { "BuilderSans", "Code", "Fantasy", "Gotham", "Jura", "Roboto", "RobotoMono", "SourceSans" }, AllowNull = false, Multi = false })
    Themesbox:AddInput("BackgroundImage", { Text = "背景图片", Default = "", Finished = true, ClearTextOnFocus = false, ClearTextOnBlur = false })
    Themesbox:AddDivider()

    Themesbox:AddDropdown("ThemeManager_ThemeList", {
        Text = "主题列表",
        Values = BuiltInThemesNames,
        AllowNull = true,
        Multi = false,
        FormatDisplayValue = function(Value) if Value ~= "Default" and Value == ThemeManager.DefaultThemeName then return string.format("%s (默认)", Value) end return Value end,
        FormatListValue = function(Value) if Value ~= "Default" and Value == ThemeManager.DefaultThemeName then return string.format("%s (默认)", Value) end return Value end
    })

    Themesbox:AddButton("设为默认", function() local ThemeName = ThemeList.Value ThemeManager:SaveDefault(ThemeName) ThemeManager.Library:Notify(string.format("成功设置默认主题为 %q", ThemeName)) RefreshDefaultThemeLabel() end)
    Themesbox:AddDivider()
    CustomThemeName = Themesbox:AddInput("ThemeManager_CustomThemeName", { Text = "自定义主题名称" })

    local function SaveThemeWithContrastCheck(Name, SuccessMessage, OnSaved)
        local function DoSave()
            local Success, ErrorMessage = ThemeManager:SaveCustomTheme(Name)
            if not Success then ThemeManager.Library:Notify(string.format("保存主题 %q 失败：%s", Name, ErrorMessage)) return end
            ThemeManager.Library:Notify(string.format(SuccessMessage, Name))
            if OnSaved then OnSaved() end
        end
        local Report = ThemeManager:GetContrastReport()
        if Report.Passes then DoSave() return end
        ShowDialog(
            function() return true end,
            "ThemeManager_LowContrastSave", "低对比度主题",
            string.format("此主题的对比度为 %.1f:1（在 %s 之间），低于建议的 %.1f:1。文本可能难以阅读。仍然保存吗？", Report.Ratio, Report.PairName, ContrastWarnThreshold),
            "仍然保存", DoSave
        )
    end

    Themesbox:AddButton("创建主题", function()
        local Name = CustomThemeName.Value
        if IsStringEmpty(Name) then ThemeManager.Library:Notify("主题名称不能为空。") return end
        if string.lower(Name) == "default" then ThemeManager.Library:Notify("提供的主题名称无效。") return end
        ShowDialog(
            function() return ThemeManager:GetCustomTheme(Name) ~= nil end,
            "ThemeManager_CreateTheme", "主题已存在",
            string.format("名为 %q 的自定义主题已存在。覆盖将用当前颜色替换它。", Name),
            "覆盖",
            function() SaveThemeWithContrastCheck(Name, "成功创建主题 %q", RefreshList) end
        )
    end)
    Themesbox:AddDivider()

    CustomThemeList = Themesbox:AddDropdown("ThemeManager_CustomThemeList", {
        Text = "自定义主题",
        Values = ThemeManager:ReloadCustomThemes(),
        AllowNull = true,
        Multi = false,
        FormatDisplayValue = function(Value) if Value == ThemeManager.DefaultThemeName then return string.format("%s (默认)", Value) end return Value end,
        FormatListValue = function(Value) if Value == ThemeManager.DefaultThemeName then return string.format("%s (默认)", Value) end return Value end
    })

    Themesbox:AddButton("加载主题", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then ThemeManager.Library:Notify("请先选择一个主题。") return end
        ThemeManager:ApplyTheme(Name)
        ThemeManager.Library:Notify(string.format("成功加载主题 %q", Name))
    end)

    Themesbox:AddButton("覆盖主题", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then ThemeManager.Library:Notify("请先选择一个主题。") return end
        ShowDialog(
            function() return true end,
            "ThemeManager_OverwriteTheme", "覆盖主题",
            string.format("确定要用当前颜色覆盖 %q 吗？此操作不可撤销。", Name),
            "覆盖",
            function() SaveThemeWithContrastCheck(Name, "成功覆盖主题 %q") end
        )
    end)
    Themesbox:AddButton("删除主题", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then ThemeManager.Library:Notify("请先选择一个主题。") return end
        ShowDialog(
            function() return true end,
            "ThemeManager_DeleteTheme", "删除主题",
            string.format("确定要删除 %q 吗？此操作不可撤销。", Name),
            "删除",
            function()
                local Success, ErrorMessage = ThemeManager:Delete(Name)
                if not Success then ThemeManager.Library:Notify(string.format("删除主题失败：%s", ErrorMessage)) return end
                ThemeManager.Library:Notify(string.format("成功删除主题 %q", Name))
                RefreshDefaultThemeLabel()
            end
        )
    end)

    Themesbox:AddButton("刷新列表", RefreshList)
    Themesbox:AddButton("设为默认", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then ThemeManager.Library:Notify("请先选择一个主题。") return end
        ThemeManager:SaveDefault(Name)
        ThemeManager.Library:Notify(string.format("成功设置默认主题为 %q", Name))
        RefreshDefaultThemeLabel()
    end)

    Themesbox:AddButton("重置默认", function()
        ShowDialog(
            function() return true end,
            "ThemeManager_ResetDefault", "重置默认主题",
            "确定要清除默认主题吗？下次加载将恢复为内置默认主题。",
            "重置",
            function()
                local Success, ErrorMessage = ThemeManager:DeleteDefaultTheme()
                if not Success then ThemeManager.Library:Notify(string.format("重置默认主题失败：%s", ErrorMessage)) return end
                ThemeManager.Library:Notify("成功重置默认主题。")
                RefreshDefaultThemeLabel()
            end
        )
    end)
    DefaultThemeLabel = Themesbox:AddLabel("当前默认主题：...", true)
    Themesbox:AddDivider()

    Themesbox:AddInput("ThemeManager_ThemeJSON", { Text = "主题 JSON" })
    Themesbox:AddButton("导入主题", function()
        local ThemeJSON = ThemeJSONInput.Value
        if IsStringEmpty(ThemeJSON) then ThemeManager.Library:Notify("主题 JSON 不能为空") return end
        ShowDialog(
            function() return true end,
            "ThemeManager_ImportTheme", "导入主题",
            "确定要导入此主题吗？当前颜色将被覆盖。",
            "导入",
            function()
                local Success, ErrorMessage = ThemeManager:LoadJSON(ThemeJSON)
                if not Success then ThemeManager.Library:Notify(string.format("导入主题失败：%s", ErrorMessage)) return end
                ThemeManager.Library:Notify("成功导入主题")
            end
        )
    end)
    Themesbox:AddButton("导出当前主题", function()
        local EncodedData, Success, ErrorMessage = ThemeManager:SaveJSON()
        if not Success then ThemeManager.Library:Notify(ErrorMessage) return end
        ThemeJSONInput:SetValue(EncodedData)
        if setclipboard then setclipboard(EncodedData) ThemeManager.Library:Notify("已复制主题到剪贴板") end
    end)

    CustomThemeList, CustomThemeName, ThemeList, FontFace, BackgroundImage, ThemeJSONInput =
        ThemeManager.Library.Options.ThemeManager_CustomThemeList,
        ThemeManager.Library.Options.ThemeManager_CustomThemeName,
        ThemeManager.Library.Options.ThemeManager_ThemeList,
        ThemeManager.Library.Options.FontFace,
        ThemeManager.Library.Options.BackgroundImage,
        ThemeManager.Library.Options.ThemeManager_ThemeJSON

    ThemeList:OnChanged(function() ThemeManager:ApplyTheme(ThemeList.Value) end)
    local function UpdateTheme() ThemeManager:ThemeUpdate() end
    BackgroundColor:OnChanged(UpdateTheme)
    MainColor:OnChanged(UpdateTheme)
    AccentColor:OnChanged(UpdateTheme)
    OutlineColor:OnChanged(UpdateTheme)
    FontColor:OnChanged(UpdateTheme)
    FontFace:OnChanged(function(Value) ThemeManager.Library:SetFont(Enum.Font[Value]) end)
    BackgroundImage:OnChanged(function(Value) ThemeManager.Library:SetBackgroundImage(Value) end)

    ThemeManager:LoadDefault()
    ThemeManager:UpdateContrastWarning()
    ThemeManager.AppliedToTab = true
    RefreshDefaultThemeLabel()
    return Themesbox
end

function ThemeManager:CreateGroupBox(Tab, IconName) return Tab:AddGroupbox({ Side = "Left", Name = "主题", IconName = IconName or "palette", }) end
function ThemeManager:ApplyToTab(Tab, IconName) local Groupbox = ThemeManager:CreateGroupBox(Tab, IconName) return ThemeManager:CreateThemeManager(Groupbox) end
function ThemeManager:ApplyToGroupbox(Groupbox) return ThemeManager:CreateThemeManager(Groupbox) end
getgenv().ObsidianThemeManager = ThemeManager
return ThemeManager
