-- Entertainment.luau
return function(Window)
    local Library = Abysall.Interface.Library
    local Toggles = Library.Toggles
    local Options = Library.Options
    local Globals = getgenv().Globals
    
    local EntertainmentTab = Window:AddTab("娱乐", "music")
    local MusicBox = EntertainmentTab:AddLeftGroupbox("音乐播放器")

    -- 1. 下拉列表（覆盖后，这个一定会存在）
    MusicBox:AddDropdown("SelectMusicDropdown", {
        Text = "选择音乐",
        Values = {"Win (胜利)", "MusicRanked (排位结算)", "EndMusic (电梯结束音乐)", "Ringing (耳鸣音效)"},
        Default = 1,
        Multi = false,
    })

    -- 2. 播放按钮
    MusicBox:AddButton({
        Text = "播放选中音乐",
        Func = function()
            if Globals.CurrentMusic then
                Globals.CurrentMusic:Destroy()
                Globals.CurrentMusic = nil
            end

            local selected = Options.SelectMusicDropdown.Value
            local mainGame = Globals.MainUI.Initiator.Main_Game
            local targetSound = nil

            if selected == "Win (胜利)" then
                targetSound = mainGame.PreRun:FindFirstChild("Win")
            elseif selected == "MusicRanked (排位结算)" then
                targetSound = mainGame.PreRun:FindFirstChild("MusicRanked")
            elseif selected == "EndMusic (电梯结束音乐)" then
                targetSound = mainGame:FindFirstChild("EndMusic", true)
            elseif selected == "Ringing (耳鸣音效)" then
                targetSound = mainGame.Health:FindFirstChild("Ringing")
            end

            if targetSound then
                local clonedSound = targetSound:Clone()
                clonedSound.Looped = true
                clonedSound.Volume = 2
                clonedSound.Parent = game:GetService("SoundService")
                clonedSound:Play()
                Globals.CurrentMusic = clonedSound
                Functions.Notify({ Title = "正在播放: " .. selected })
            else
                Functions.Notify({ Title = "找不到音乐: " .. selected })
            end
        end
    })

    -- 3. 暂停按钮
    MusicBox:AddButton({
        Text = "暂停播放音乐",
        Func = function()
            if Globals.CurrentMusic and Globals.CurrentMusic.Playing then
                Globals.CurrentMusic:Pause()
                Functions.Notify({ Title = "音乐已暂停" })
            end
        end
    })

    -- 4. 继续按钮
    MusicBox:AddButton({
        Text = "开始/继续播放",
        Func = function()
            if Globals.CurrentMusic and not Globals.CurrentMusic.Playing then
                Globals.CurrentMusic:Play()
                Functions.Notify({ Title = "音乐已继续" })
            end
        end
    })

    MusicBox:AddButton({
        Text = "重新播放当前音乐",
        Func = function()
            if Globals.CurrentMusic then
                Globals.CurrentMusic.TimePosition = 0
                Globals.CurrentMusic:Play()
                Functions.Notify({ Title = "音乐已重新播放" })
            end
        end
    })
end
