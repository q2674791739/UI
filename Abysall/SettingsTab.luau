return function(Window)
    local function CloneReference(Object)
        if Abysall and Abysall.Environment.cloneref then
            return Abysall.Environment.cloneref(Object)
        else
            return Object
        end
    end
    
    local Services = setmetatable({}, {
        __index = function(self, Name)
            return CloneReference(game:GetService(Name))
        end
    })

    local Library = Abysall.Interface.Library
    local SaveManager = Abysall.Interface.SaveManager
    local ThemeManager = Abysall.Interface.ThemeManager
    
    local Toggles = Library.Toggles
    local Options = Library.Options
    
    local SettingsTab = Window:AddTab("设置", "settings")
    local MenuGroup = SettingsTab:AddLeftGroupbox("菜单")
    
    MenuGroup:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame.Visible,
        Text = "打开快捷键菜单",
        Callback = function(value)
            Library.KeybindFrame.Visible = value
        end,
    })
    MenuGroup:AddToggle("ShowCustomCursor", {
        Text = "自定义光标",
        Default = false,
        Callback = function(Value)
            Library.ShowCustomCursor = Value
        end,
    })

    MenuGroup:AddDropdown("UILibrary", {
    Text = "UI 风格",
    Values = { "Obsidian", "Linoria" },
    Default = (Abysall.UILibrary == "Linoria" and 2 or 1),
    Callback = function(Value)
        if Abysall.Environment.writefile and Abysall.Environment.readfile then
            if not Abysall.Environment.isfile("Abysall/UserData.json") then
                Abysall.Environment.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode({TotalExecutions = 0, UILibrary = "Obsidian"}))
            end
            local Data = Abysall.Environment.readfile("Abysall/UserData.json")
            local Decoded = Services.HttpService:JSONDecode(Data)
            Decoded.UILibrary = Value
            Abysall.UILibrary = Decoded.UILibrary
            Abysall.Environment.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode(Decoded))
        end
        Library:Notify("已切换为 " .. Value .. "，请大退游戏后重新进以生效", 4)
    end,
})
    
    MenuGroup:AddDropdown("DPIDropdown", {
        Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
        Default = "100%",
        Text = "DPI 缩放",
        Callback = function(Value)
            Value = Value:gsub("%%", "")
            local DPI = tonumber(Value)
            Library:SetDPIScale(DPI)
        end,
    })
    MenuGroup:AddDivider()
    MenuGroup:AddLabel("菜单绑定"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "菜单快捷键" })
    
    MenuGroup:AddButton("复制 Discord 邀请", function()
        toclipboard("https://dsc.gg/abysallhub")
        Library:Notify("Discord 邀请已复制")
    end)
    
    MenuGroup:AddButton("卸载脚本", function()
        Library:Unload()
    end)
    
    Library.ToggleKeybind = Options.MenuKeybind
    
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({"UILibrary"})
    ThemeManager:SetFolder("Abysall")
    SaveManager:SetFolder("Abysall/" .. Abysall.SavePath)
    SaveManager:BuildConfigSection(SettingsTab)
    ThemeManager:ApplyToTab(SettingsTab)
    SaveManager:LoadAutoloadConfig()
end
