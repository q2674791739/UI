-- Entertainment.luau
return function(Window)
    local Library = Abysall.Interface.Library
    local Toggles = Library.Toggles
    local Options = Library.Options

    local EntertainmentTab = Window:AddTab("娱乐", "music")
    local MusicBox = EntertainmentTab:AddLeftGroupbox("音乐播放器")

    MusicBox:AddDropdown("SelectMusicDropdown", {
        Text = "选择胜利音乐",
        Values = {"Win (胜利)", "MusicRanked (排位结算)"},
        Default = 1,
        Multi = false,
        Callback = function(Value)
            if Toggles.PlayMusicToggle and Toggles.PlayMusicToggle.Value then
                Toggles.PlayMusicToggle:SetValue(false)
                task.wait(0.1)
                Toggles.PlayMusicToggle:SetValue(true)
            end
        end
    })

    MusicBox:AddToggle("PlayMusicToggle", {
        Text = "播放选中音乐",
        Default = false,
    })
end
