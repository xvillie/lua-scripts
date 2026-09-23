if not game:IsLoaded() then
    game.Loaded:Wait()
end

local workspace = game:GetService("Workspace")
local plrs = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")

local lp = plrs.LocalPlayer
local mouse = lp:GetMouse()
local camera = workspace.CurrentCamera

local handler = require(game:GetService("ReplicatedStorage").Modules.GunHandler)
local oldfunction = handler.getAim

local config = {
    ["silent"] = {
        ["enabled"] = false,
        ["part"] = "Head",
        ["fov"] = 100
    },
    ["checks"] = {
        ["Knocked"] = false,
        ["K.O"] = false,
        ["Dead"] = false,
        ["Wall"] = false
    },
    ["speed"] = {
        ["enabled"] = false,
        ["state"] = false, -- dont touch
        ["value"] = 16,
        ["mode"] = "Hold",
        ["keybind"] = "C"
    }
}

local script_obj = {
    ["functions"] = {},
    ["connections"] = {}
}

script_obj.functions.setwalkspeed = function(value)
    local char = lp.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = value
    end
end

script_obj.functions.isKO = function(plr)
    local char = plr.Character
    local bf = char and char:FindFirstChild("BodyEffects")
    return bf and bf:FindFirstChild("K.O") and bf["K.O"].Value
end

script_obj.functions.isknocked = function(plr)
    local char = plr.Character
    local bf = char and char:FindFirstChild("BodyEffects")
    return bf and bf:FindFirstChild("Knocked") and bf.Knocked.Value
end

script_obj.functions.isdead = function(plr)
    local char = plr.Character
    local bf = char and char:FindFirstChild("BodyEffects")
    return bf and bf:FindFirstChild("Dead") and bf.Dead.Value
end

script_obj.functions.validate = function(plr)
    if not plr or not plr.Character then return false end
    local char = plr.Character
    local humanoid = char:FindFirstChild("Humanoid")

    if not char:FindFirstChild("Head") or not humanoid or humanoid.Health <= 0 then
        return false
    end

    if config.checks["K.O"] and script_obj.functions.isKO(plr) then return false end
    if config.checks["Knocked"] and script_obj.functions.isknocked(plr) then return false end
    if config.checks["Dead"] and script_obj.functions.isdead(plr) then return false end

    return true
end

local sa = {
    ["target"] = {
        ["player"] = nil,
        ["part"] = nil
    },
    ["hooked"] = false
}

local TARGET_PARTS = {"Head", "UpperTorso", "LowerTorso", "LeftHand", "RightHand"}

script_obj.functions.getclosestpart = function(character, screenpos)
    local closestpart = nil
    local shortestdistance = math.huge

    if not character then return nil, math.huge end
    for _, partname in ipairs(TARGET_PARTS) do
        local part = character:FindFirstChild(partname)
        if part and part:IsA("BasePart") then
            -- Fixed 'Camera' to 'camera'
            local vector, onscreen = camera:WorldToScreenPoint(part.Position) 
            
            if onscreen then
                local partscreenpos = Vector2.new(vector.X, vector.Y)
                local distance = (partscreenpos - screenpos).Magnitude

                if distance < shortestdistance then
                    shortestdistance = distance
                    closestpart = part
                end
            end
        end
    end

    return closestpart, shortestdistance
end

script_obj.functions.getclosestplr = function()
    if not config.silent.enabled then return nil, nil end

    local mp = Vector2.new(mouse.X, mouse.Y)
    local bestplayer = nil
    local bestpart = nil
    local bdist = config.silent.fov

    for _, v in pairs(plrs:GetPlayers()) do
        if v ~= lp and script_obj.functions.validate(v) then
            local part = nil
            local dist = nil

            if config.silent.part == "Closest Part" then
                part, dist = script_obj.functions.getclosestpart(v.Character, mp)
            else
                local static_part = v.Character:FindFirstChild(config.silent.part)
                if static_part then
                    local screenpos, onscreen = camera:WorldToScreenPoint(static_part.Position)
                    if onscreen then
                        part = static_part
                        dist = (Vector2.new(screenpos.X, screenpos.Y) - mp).Magnitude
                    end
                end
            end

            if part and dist and dist < bdist then
                if config.checks.Wall then
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = {lp.Character, camera}
                    
                    local result = workspace:Raycast(camera.CFrame.Position, (part.Position - camera.CFrame.Position).Unit * 500, params)
                    if result and result.Instance:IsDescendantOf(v.Character) then
                        bdist = dist
                        bestplayer = v
                        bestpart = part
                    end
                else
                    bdist = dist
                    bestplayer = v
                    bestpart = part
                end
            end
        end
    end
    return bestplayer, bestpart
end

handler.getAim = function(origin, maxDist)
    if sa.target.part and sa.target.player then
        local direction = (sa.target.part.Position - origin).Unit
        local distance = (sa.target.part.Position - origin).Magnitude
        return direction, math.min(distance, maxDist or 200)
    end
    return oldfunction(origin, maxDist) 
end

local idx
idx = hookmetamethod(game, "__index", function(self, key)
    if not checkcaller() and self == mouse and config.silent.enabled and sa.target.part then
        if key == "Hit" then
            return sa.target.part.CFrame
        elseif key == "Target" then
            return sa.target.part
        end
    end
    return idx(self, key)
end)

sa.hooked = true

script_obj.connections.Began = uis.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode[config.speed.keybind] then
        if config.speed.enabled then
            if config.speed.mode == "Toggle" then
                config.speed.state = not config.speed.state
            elseif config.speed.mode == "Hold" then
                config.speed.state = true
            end
        end
    end
end)

script_obj.connections.Ended = uis.InputEnded:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode[config.speed.keybind] then
        if config.speed.enabled and config.speed.mode == "Hold" then
            config.speed.state = false
        end
    end
end)

local function cache()
    sa.target.player, sa.target.part = script_obj.functions.getclosestplr()

    if config.speed.enabled and config.speed.state then
        script_obj.functions.setwalkspeed(config.speed.value)
    end
end

script_obj.connections.Render = rs.RenderStepped:Connect(cache)
