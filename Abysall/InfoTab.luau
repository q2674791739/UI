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
    
    local InfoTab = Window:AddTab("信息", "user")

    local User = InfoTab:AddLeftGroupbox("用户信息")
    local ImageSize = Enum.ThumbnailSize.Size420x420
    local ImageType = Enum.ThumbnailType.HeadShot
    local Content = Services.Players:GetUserThumbnailAsync(Abysall.Interface.Library.LocalPlayer.UserId, ImageType, ImageSize)
    
    User:AddImage("UserIcon", { Image = Content })
    User:AddLabel("ID: " .. Abysall.Interface.Library.LocalPlayer.Name, true)
    User:AddLabel("总执行次数: " .. (Abysall.TotalExecutions and Abysall.TotalExecutions or "N/A"), true)

    local Changelog = InfoTab:AddRightGroupbox("更新日志")
    local LatestChangelog = {
        "2026/7/11",
        "<font color='rgb(0, 255, 0)'>+ 新增实体 ESP 选择</font>",
        "<font color='rgb(0, 255, 0)'>+ 新增物品通知器</font>",
        "<font color='rgb(0, 255, 0)'>+ 新增移除 Surge</font>",
        "<font color='rgb(0, 255, 0)'>+ 新增死亡刷取</font>",
        "<font color='rgb(0, 255, 0)'>+ 修复一些损坏的功能（绕过 Eyes 等）</font>",
    }
    for Index, Change in pairs(LatestChangelog) do
        Changelog:AddLabel(Change, true)
    end

    local Name, Version = Abysall.Environment.identifyexecutor()
    local Executor = InfoTab:AddRightGroupbox("执行器信息")
    Executor:AddLabel("名称: " .. Name, true)
    Executor:AddLabel("版本: " .. (Version and Version or "N/A"), true)
    Executor:AddDivider()
    Executor:AddLabel("测试结果: ", true)

    for Index, Result in pairs(Abysall.Environment.Results) do
        Result = Result:gsub("<", "(")
        Result = Result:gsub(">", ")")
        Executor:AddLabel(Result, true)
    end

    local Community = InfoTab:AddLeftGroupbox("社区")
    Community:AddButton("复制 Discord 邀请", function()
        toclipboard("https://dsc.gg/abysallhub")
        Library:Notify("Discord 邀请已复制")
    end)
end
