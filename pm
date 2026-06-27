print("Press P to start making a preset")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local CONFIG = {
    MESH_ID       = "http://www.roblox.com/asset/?id=212302951",
    TEXTURE_ID    = "http://www.roblox.com/asset/?id=212303049",
    SCALE         = Vector3.new(4, 4, 4),
    VERTEX_COLOR  = Vector3.new(1, 1, 1),
    ROTATOR_COLOR = Color3.fromRGB(90, 255, 150),
    EDITOR_Y      = 2000,
}

local isEditing, isRunning, selectedPart, editorFloor, originalPos = false, false, nil, nil, nil
local lastDist, lastAngle, idCounter, previewStartTime = 0, 0, 0, 0

local ghostFolder = Instance.new("Folder", workspace); ghostFolder.Name = "OpenViz_Ghosts"
local visFolder   = Instance.new("Folder", workspace); visFolder.Name   = "OpenViz_Preview"

local gui = Instance.new("ScreenGui", (gethui and gethui()) or player:WaitForChild("PlayerGui"))
gui.Name, gui.Enabled = "OpenViz_Architect", false

local function makeDraggable(frame, topbar)
    local dragging, dragStart, startPos
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPos = true, input.Position, frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function createPanel(name, iconId, size, pos)
    local f = Instance.new("Frame", gui)
    f.Size, f.Position, f.BackgroundColor3, f.BorderSizePixel = size, pos, Color3.fromRGB(20,20,25), 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,6)
    local s = Instance.new("UIStroke", f); s.Color = Color3.fromRGB(40,40,50); s.Thickness = 1

    local t = Instance.new("Frame", f)
    t.Size, t.BackgroundColor3, t.BorderSizePixel = UDim2.new(1,0,0,30), Color3.fromRGB(15,15,18), 0
    Instance.new("UICorner", t).CornerRadius = UDim.new(0,6)
    local fix = Instance.new("Frame", t)
    fix.Size, fix.Position, fix.BackgroundColor3, fix.BorderSizePixel = UDim2.new(1,0,0,5), UDim2.new(0,0,1,-5), Color3.fromRGB(15,15,18), 0

    local lbl = Instance.new("TextLabel", t)
    lbl.BackgroundTransparency, lbl.Text, lbl.TextColor3 = 1, name, Color3.fromRGB(200,200,200)
    lbl.Font, lbl.TextSize, lbl.TextXAlignment = Enum.Font.GothamMedium, 13, Enum.TextXAlignment.Left

    if iconId then
        lbl.Size, lbl.Position = UDim2.new(1,-32,1,0), UDim2.new(0,32,0,0)
        local ic = Instance.new("ImageLabel", t)
        ic.Size, ic.Position, ic.BackgroundTransparency = UDim2.new(0,18,0,18), UDim2.new(0,8,0.5,-9), 1
        ic.Image = "rbxassetid://" .. iconId
    else
        lbl.Size, lbl.Position = UDim2.new(1,-10,1,0), UDim2.new(0,10,0,0)
    end
    makeDraggable(f, t)
    return f, t
end

local function makeBox(parent, text, pos, ph)
    local b = Instance.new("TextBox", parent)
    b.Size, b.Position, b.Text, b.PlaceholderText = UDim2.new(0.9,0,0,28), pos, text, ph
    b.BackgroundColor3, b.TextColor3, b.ClearTextOnFocus = Color3.fromRGB(30,30,35), Color3.fromRGB(220,220,220), false
    b.Font, b.TextSize = Enum.Font.Gotham, 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
    return b
end

local function makeBtn(parent, txt, pos, col, cb)
    local b = Instance.new("TextButton", parent)
    b.Size, b.Position, b.BackgroundColor3, b.Text, b.TextColor3 = UDim2.new(0.9,0,0,28), pos, col, txt, Color3.new(1,1,1)
    b.Font, b.TextSize = Enum.Font.GothamBold, 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
    b.MouseButton1Click:Connect(cb)
    return b
end

-- Panels
local mainPanel = createPanel("NodeGraph Editor", "1283965824", UDim2.new(0,220,0,345), UDim2.new(0,260,0.5,-190))
local propPanel = createPanel("Rotator Props", "12690726311", UDim2.new(0,180,0,120), UDim2.new(1,-200,0.5,-60))
local listPanel = createPanel("Explorer", "11956055886", UDim2.new(0,200,0,300), UDim2.new(0,20,0.5,-150))
local codePanel = createPanel("Script Preset Maker", "11956055886", UDim2.new(0, 450, 0, 380), UDim2.new(0.5, -225, 0.5, -190))
propPanel.Visible = false

-- Explorer List
local scrollList = Instance.new("ScrollingFrame", listPanel)
scrollList.Size, scrollList.Position, scrollList.BackgroundTransparency = UDim2.new(1,0,1,-35), UDim2.new(0,0,0,35), 1
scrollList.CanvasSize, scrollList.ScrollBarThickness = UDim2.new(0,0,0,0), 4
local listLayout = Instance.new("UIListLayout", scrollList); listLayout.Padding = UDim.new(0,2)

-- NodeGraph UI
local nameB     = makeBox(mainPanel, "", UDim2.new(0.05,0,0,40),  "Preset Name")
local moveSnapB = makeBox(mainPanel, "", UDim2.new(0.05,0,0,73),  "Move Snap (Studs)")
local rotSnapB  = makeBox(mainPanel, "", UDim2.new(0.05,0,0,106), "Rotation Degrees")
local speedB    = makeBox(propPanel, "", UDim2.new(0.05,0,0,40),  "Speed")
local sensB     = makeBox(propPanel, "", UDim2.new(0.05,0,0,75),  "Music Sens (0-100)")

-- Script Editor UI
local codePanel = createPanel("                                                 code yo thing", "11348555035", UDim2.new(0, 450, 0, 400), UDim2.new(0.5, -225, 0.5, -200))

local linkBox = Instance.new("TextBox", codePanel)
linkBox.Size = UDim2.new(0.9, 0, 0, 20)
linkBox.Position = UDim2.new(0.05, 0, 0, 40)

linkBox.BackgroundTransparency = 1
linkBox.Text = "Examples: https://pastefy.app/MHWAyi9F"
linkBox.TextColor3 = Color3.fromRGB(100, 150, 255)
linkBox.Font = Enum.Font.Gotham
linkBox.TextSize = 12
linkBox.TextXAlignment = Enum.TextXAlignment.Left

linkBox.ClearTextOnFocus = false
linkBox.MultiLine = false

local codeBox = Instance.new("TextBox", codePanel)
codeBox.Size = UDim2.new(0.9, 0, 1, -130) -- Resized to prevent overflow
codeBox.Position = UDim2.new(0.05, 0, 0, 65)
codeBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
codeBox.TextColor3 = Color3.fromRGB(200, 255, 200)
codeBox.Font = Enum.Font.Code
codeBox.TextSize = 14
codeBox.TextXAlignment = Enum.TextXAlignment.Left
codeBox.TextYAlignment = Enum.TextYAlignment.Top
codeBox.ClipsDescendants = true
codeBox.MultiLine = true
codeBox.ClearTextOnFocus = false
Instance.new("UICorner", codeBox).CornerRadius = UDim.new(0, 4)
codeBox.Text = [[-- Return a function(i, total, t, hrp, audioPulse, size, height, speed)
return function(i, total, t, hrp, audioPulse, size, height, speed)
    local angle = (math.pi * 2 / total) * (i - 1) + (t * speed)
    local radius = size + audioPulse
    local x = math.cos(angle) * radius
    local z = math.sin(angle) * radius
    local y = height + math.sin(t * 2 + i) * 2
    
    local pos = hrp.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
    local rot = CFrame.lookAt(pos, hrp.Position)
    return pos, rot
end]]

local scriptNameB = Instance.new("TextBox", codePanel)
scriptNameB.Size = UDim2.new(0.4, 0, 0, 28)
scriptNameB.Position = UDim2.new(0.05, 0, 1, -45)
scriptNameB.Text = ""
scriptNameB.PlaceholderText = "Script Preset Name"
scriptNameB.BackgroundColor3 = Color3.fromRGB(30,30,35)
scriptNameB.TextColor3 = Color3.fromRGB(220,220,220)
scriptNameB.ClearTextOnFocus = false
scriptNameB.Font = Enum.Font.Gotham
scriptNameB.TextSize = 12
Instance.new("UICorner", scriptNameB).CornerRadius = UDim.new(0, 4)

local saveBtn = Instance.new("TextButton", codePanel)
saveBtn.Size = UDim2.new(0.45, 0, 0, 28)
saveBtn.Position = UDim2.new(0.5, 0, 1, -45)
saveBtn.BackgroundColor3 = Color3.fromRGB(44, 115, 78)
saveBtn.Text = "Save Script Preset"
saveBtn.TextColor3 = Color3.new(1, 1, 1)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 12
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 4)

saveBtn.MouseButton1Click:Connect(function()
    local name = scriptNameB.Text
    if name == "" then return end
    if writefile then
        if not isfolder("OpenViz") then makefolder("OpenViz") end
        writefile("OpenViz/" .. name .. ".preset", codeBox.Text)
        print("Architect: Saved -> OpenViz/" .. name .. ".preset")
    end
end)

-- Handles
local moveHandles = Instance.new("Handles", gui)
moveHandles.Style, moveHandles.Color3 = Enum.HandlesStyle.Movement, Color3.fromRGB(90,160,255)
local rotHandles = Instance.new("ArcHandles", gui)
rotHandles.Color3 = Color3.fromRGB(200,100,255)

-- Node Graph Logic
local function findNodeByID(id)
    for _, v in ipairs(ghostFolder:GetChildren()) do if v:GetAttribute("ID") == id then return v end end
    return nil
end

local function getParentWorldCF(node)
    local pid = node:GetAttribute("ParentID")
    if pid == "HRP" then
        local char = player.Character
        return (char and char:FindFirstChild("HumanoidRootPart")) and char.HumanoidRootPart.CFrame or CFrame.new()
    end
    local parentNode = findNodeByID(pid)
    return parentNode and parentNode.CFrame or CFrame.new()
end

local function updateRelativeOffsets()
    for _, p in ipairs(ghostFolder:GetChildren()) do
        local relCF = getParentWorldCF(p):ToObjectSpace(p.CFrame)
        local rx, ry, rz = relCF:ToEulerAnglesXYZ()
        p:SetAttribute("RelPosX", relCF.Position.X); p:SetAttribute("RelPosY", relCF.Position.Y); p:SetAttribute("RelPosZ", relCF.Position.Z)
        p:SetAttribute("RelRotX", rx); p:SetAttribute("RelRotY", ry); p:SetAttribute("RelRotZ", rz)
    end
end

local function drawBeams()
    for _, p in ipairs(ghostFolder:GetChildren()) do
        if p:FindFirstChild("LinkBeam") then p.LinkBeam:Destroy() end
        if p:FindFirstChild("Att0")     then p.Att0:Destroy()     end
        if p:FindFirstChild("Att1")     then p.Att1:Destroy()     end
    end
    for _, p in ipairs(ghostFolder:GetChildren()) do
        local parentNode = findNodeByID(p:GetAttribute("ParentID"))
        if parentNode then
            local a0 = Instance.new("Attachment", p); a0.Name = "Att0"
            local a1 = Instance.new("Attachment", parentNode); a1.Name = "Att1"
            local beam = Instance.new("Beam", p); beam.Name = "LinkBeam"
            beam.Attachment0, beam.Attachment1, beam.FaceCamera = a0, a1, true
            beam.Width0, beam.Width1, beam.Color = 0.1, 0.1, ColorSequence.new(Color3.fromRGB(90,160,255))
            beam.Transparency = NumberSequence.new(0.5)
        end
    end
end

local function refreshExplorer()
    for _, c in ipairs(scrollList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local count = 0
    for _, p in ipairs(ghostFolder:GetChildren()) do
        local typ = p:GetAttribute("Type")
        local b = Instance.new("TextButton", scrollList)
        b.Size, b.BackgroundColor3 = UDim2.new(1,-8,0,22), (p == selectedPart) and Color3.fromRGB(60,60,100) or Color3.fromRGB(30,30,35)
        b.Text, b.TextColor3 = " " .. typ .. " [" .. p:GetAttribute("ID") .. "]", (typ == "Rotator") and CONFIG.ROTATOR_COLOR or Color3.new(1,1,1)
        b.Font, b.TextSize, b.TextXAlignment = Enum.Font.Gotham, 11, Enum.TextXAlignment.Left
        b.MouseButton1Click:Connect(function() _G.SelectPart(p) end)
        count = count + 1
    end
    scrollList.CanvasSize = UDim2.new(0,0,0,count * 24)
end

_G.SelectPart = function(part)
    if isRunning then return end
    selectedPart, moveHandles.Adornee, rotHandles.Adornee = part, part, part
    if part and part:GetAttribute("Type") == "Rotator" then
        propPanel.Visible, speedB.Text, sensB.Text = true, tostring(part:GetAttribute("Speed")), tostring(part:GetAttribute("Sens"))
    else
        propPanel.Visible = false
    end
    refreshExplorer()
end

speedB.FocusLost:Connect(function() if selectedPart then selectedPart:SetAttribute("Speed", tonumber(speedB.Text) or 0) end end)
sensB.FocusLost:Connect(function()  if selectedPart then selectedPart:SetAttribute("Sens",  tonumber(sensB.Text)  or 0) end end)

moveHandles.MouseButton1Down:Connect(function() lastDist  = 0 end)
rotHandles.MouseButton1Down:Connect(function()  lastAngle = 0 end)

moveHandles.MouseDrag:Connect(function(face, distance)
    if not selectedPart then return end
    local snap = tonumber(moveSnapB.Text) or 0
    local delta = distance - lastDist
    if snap > 0 then
        local snapped = math.floor(distance / snap) * snap
        delta = snapped - lastDist
        if delta == 0 then return end
        lastDist = snapped
    else lastDist = distance end
    selectedPart.CFrame = selectedPart.CFrame * CFrame.new(Vector3.FromNormalId(face) * delta)
    updateRelativeOffsets(); drawBeams()
end)

rotHandles.MouseDrag:Connect(function(axis, angle)
    if not selectedPart then return end
    local snap = tonumber(rotSnapB.Text) or 0
    local delta = angle - lastAngle
    if snap > 0 then
        local radSnap = math.rad(snap)
        local snapped = math.floor(angle / radSnap) * radSnap
        delta = snapped - lastAngle
        if delta == 0 then return end
        lastAngle = snapped
    else lastAngle = angle end
    selectedPart.CFrame = selectedPart.CFrame * CFrame.fromAxisAngle(Vector3.FromAxis(axis), delta)
    updateRelativeOffsets()
end)

local function createNode(typ, startCf)
    idCounter = idCounter + 1
    local part = Instance.new("Part", ghostFolder)
    part.Size, part.Anchored, part.CanCollide, part.Transparency = Vector3.new(1,1,1), true, false, 0.4
    part.CFrame = startCf or player.Character.HumanoidRootPart.CFrame
    part:SetAttribute("Type", typ); part:SetAttribute("ID", tostring(idCounter)); part:SetAttribute("ParentID", "HRP")

    if typ == "Boombox" then
        local mesh = Instance.new("SpecialMesh", part)
        mesh.MeshType, mesh.MeshId, mesh.TextureId = Enum.MeshType.FileMesh, CONFIG.MESH_ID, CONFIG.TEXTURE_ID
        mesh.Scale, mesh.VertexColor = CONFIG.SCALE, CONFIG.VERTEX_COLOR
    elseif typ == "Rotator" then
        part.Shape, part.Size, part.Material, part.Color = Enum.PartType.Block, Vector3.new(1.5, 1.5, 1.5), Enum.Material.Neon, CONFIG.ROTATOR_COLOR
        part:SetAttribute("Speed", 2); part:SetAttribute("Sens", 50)
    end
    updateRelativeOffsets(); drawBeams(); refreshExplorer(); _G.SelectPart(part)
    return part
end

makeBtn(mainPanel, "Add Rotator",    UDim2.new(0.05,0,0,144), Color3.fromRGB(29,105,75),   function() createNode("Rotator") end)
makeBtn(mainPanel, "Add BB at part", UDim2.new(0.05,0,0,177), Color3.fromRGB(31,39,128), function()
    if selectedPart and not isRunning then
        local p = createNode("Boombox", selectedPart.CFrame)
        p:SetAttribute("ParentID", selectedPart:GetAttribute("ParentID"))
        updateRelativeOffsets(); drawBeams()
    end
end)
makeBtn(mainPanel, "Copy Selected",  UDim2.new(0.05,0,0,210), Color3.fromRGB(128,76,31), function()
    if not selectedPart or isRunning then return end
    local selTyp = selectedPart:GetAttribute("Type")
    local newNode = createNode(selTyp, selectedPart.CFrame)
    newNode:SetAttribute("ParentID", "HRP")
    if selTyp == "Rotator" then
        newNode:SetAttribute("Speed", selectedPart:GetAttribute("Speed")); newNode:SetAttribute("Sens", selectedPart:GetAttribute("Sens"))
        local oldID, newID = selectedPart:GetAttribute("ID"), newNode:GetAttribute("ID")
        for _, v in ipairs(ghostFolder:GetChildren()) do
            if v:GetAttribute("ParentID") == oldID then
                local cc = createNode(v:GetAttribute("Type"), v.CFrame)
                cc:SetAttribute("ParentID", newID)
            end
        end
    end
    updateRelativeOffsets(); drawBeams()
end)
makeBtn(mainPanel, "Delete Selected",UDim2.new(0.05,0,0,243), Color3.fromRGB(160,50,50), function()
    if not selectedPart or isRunning then return end
    local delID = selectedPart:GetAttribute("ID")
    for _, v in ipairs(ghostFolder:GetChildren()) do if v:GetAttribute("ParentID") == delID then v:Destroy() end end
    selectedPart:Destroy(); _G.SelectPart(nil); drawBeams(); refreshExplorer()
end)
makeBtn(mainPanel, "Toggle Preview", UDim2.new(0.05,0,0,276), Color3.fromRGB(59,3,133), function()
    isRunning = not isRunning; _G.SelectPart(nil)
    if isRunning then
        previewStartTime, moveHandles.Adornee, rotHandles.Adornee = tick(), nil, nil
        for _, p in ipairs(ghostFolder:GetChildren()) do p.Transparency = 1 end
        visFolder:ClearAllChildren()
        for _, p in ipairs(ghostFolder:GetChildren()) do
            if p:GetAttribute("Type") == "Boombox" then
                local v = Instance.new("Part", visFolder)
                v.Anchored, v.CanCollide, v.Size = true, false, Vector3.new(1,1,1)
                v:SetAttribute("SourceID", p:GetAttribute("ID"))
                local m = Instance.new("SpecialMesh", v)
                m.MeshType, m.MeshId, m.TextureId, m.Scale, m.VertexColor = Enum.MeshType.FileMesh, CONFIG.MESH_ID, CONFIG.TEXTURE_ID, CONFIG.SCALE, CONFIG.VERTEX_COLOR
            end
        end
    else
        visFolder:ClearAllChildren()
        for _, p in ipairs(ghostFolder:GetChildren()) do p.Transparency = 0.4 end
        drawBeams()
    end
end)
makeBtn(mainPanel, "Save Node Preset", UDim2.new(0.05,0,0,309), Color3.fromRGB(44,115,78), function()
    updateRelativeOffsets()
    local data = { Name = nameB.Text, Type = "NodeGraph", Nodes = {}, Tools = {} }
    for _, p in ipairs(ghostFolder:GetChildren()) do
        local item = {
            ID = p:GetAttribute("ID"), ParentID = p:GetAttribute("ParentID"),
            pos = { x = p:GetAttribute("RelPosX"), y = p:GetAttribute("RelPosY"), z = p:GetAttribute("RelPosZ") },
            rot = { x = p:GetAttribute("RelRotX"), y = p:GetAttribute("RelRotY"), z = p:GetAttribute("RelRotZ") },
        }
        if p:GetAttribute("Type") == "Rotator" then
            item.Speed, item.Sens = p:GetAttribute("Speed"), p:GetAttribute("Sens")
            table.insert(data.Nodes, item)
        else table.insert(data.Tools, item) end
    end
    if writefile then
        if not isfolder("OpenViz") then makefolder("OpenViz") end
        writefile("OpenViz/" .. nameB.Text .. ".json", HttpService:JSONEncode(data))
        print("Architect: Saved -> OpenViz/" .. nameB.Text .. ".json")
    end
end)

local function getSimCF(nodeID, t, memo)
    if memo[nodeID] then return memo[nodeID] end
    if nodeID == "HRP" then
        local char = player.Character
        local cf = (char and char:FindFirstChild("HumanoidRootPart")) and char.HumanoidRootPart.CFrame or CFrame.new()
        memo[nodeID] = cf; return cf
    end
    local node = findNodeByID(nodeID)
    if not node then memo[nodeID] = CFrame.new(); return CFrame.new() end

    local parentCF = getSimCF(node:GetAttribute("ParentID"), t, memo)
    local relCF = CFrame.new(node:GetAttribute("RelPosX"), node:GetAttribute("RelPosY"), node:GetAttribute("RelPosZ")) 
                * CFrame.Angles(node:GetAttribute("RelRotX"), node:GetAttribute("RelRotY"), node:GetAttribute("RelRotZ"))

    local worldCF = (node:GetAttribute("Type") == "Rotator") 
        and (parentCF * relCF * CFrame.Angles(0, t * (node:GetAttribute("Speed") or 2), 0)) 
        or (parentCF * relCF)

    memo[nodeID] = worldCF; return worldCF
end

RunService.Heartbeat:Connect(function()
    if not isRunning then return end
    local t, memo = tick() - previewStartTime, {}
    for _, v in ipairs(visFolder:GetChildren()) do
        local srcID = v:GetAttribute("SourceID")
        if srcID then v.CFrame = getSimCF(srcID, t, memo) end
    end
end)

local function toggleEditor(state)
    isEditing, gui.Enabled = state, state
    local char = player.Character; if not char then return end
    local hum, hrp = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if state then
        originalPos, hrp.CFrame, hrp.AssemblyLinearVelocity = hrp.CFrame, CFrame.new(0, CONFIG.EDITOR_Y, 0), Vector3.zero
        if hum then hum.WalkSpeed = 0 end
        editorFloor = Instance.new("Part", workspace)
        editorFloor.Size, editorFloor.Position, editorFloor.Anchored, editorFloor.Transparency, editorFloor.Color, editorFloor.Material = Vector3.new(400, 1, 400), Vector3.new(0, CONFIG.EDITOR_Y - 5, 0), true, 0.8, Color3.fromRGB(20,20,25), Enum.Material.Neon
        updateRelativeOffsets(); drawBeams()
    else
        if editorFloor then editorFloor:Destroy(); editorFloor = nil end
        ghostFolder:ClearAllChildren(); visFolder:ClearAllChildren()
        isRunning = false; _G.SelectPart(nil)
        if hum then hum.WalkSpeed = 16 end
        if originalPos then hrp.CFrame = originalPos end
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.P then toggleEditor(not isEditing); return end
    if not isEditing or isRunning then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local target = mouse.Target
        if target and target.Parent == ghostFolder then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and selectedPart and selectedPart ~= target and target:GetAttribute("Type") == "Rotator" then
                selectedPart:SetAttribute("ParentID", target:GetAttribute("ID"))
                updateRelativeOffsets(); drawBeams()
            else _G.SelectPart(target) end
        else _G.SelectPart(nil) end
    end
end)
