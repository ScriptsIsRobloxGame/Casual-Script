local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CAS = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Characters = workspace:WaitForChild("Characters")

local karambitcamera = RS.Assets.Weapons:WaitForChild("Karambit"):WaitForChild("Camera")
karambitcamera:WaitForChild("ViewmodelLight").Transparency = 1

local knives = {
    ["Karambit"] = {Offset = CFrame.new(0, -1.5, 1.5)},
    ["Butterfly Knife"] = {Offset = CFrame.new(0, -1.5, 1.5)},
    ["M9 Bayonet"] = {Offset = CFrame.new(0, -1.5, 1)},
    ["Flip Knife"] = {Offset = CFrame.new(0, -1.5, 1.25)},
    ["Gut Knife"] = {Offset = CFrame.new(0, -1.5, 0.5)},
}

local selectedKnife = "Butterfly Knife"
local tweenSpeed = 0.2
local vm
local animator
local equipAnim, idleAnim, inspectAnim
local HeavySwingAnim, Swing1Anim, Swing2Anim
local spawned = false
local inspecting = false
local swinging = false
local lastAttackTime = 0
local ATTACK_COOLDOWN = 1
local ACTION_INSPECT = "InspectKnifeAction"
local ACTION_ATTACK = "AttackKnifeAction"
local running = true

local function isAlive()
    local t = Characters:FindFirstChild("Terrorists")
    local ct = Characters:FindFirstChild("Counter-Terrorists")
    local myModel = (t and t:FindFirstChild(player.Name)) or (ct and ct:FindFirstChild(player.Name))
    return myModel
end

local function getKnifeInCamera()
    return camera:FindFirstChild("T Knife") or camera:FindFirstChild("CT Knife")
end

local function cleanPart(part)
    if part:IsA("BasePart") then
        part.CanCollide = false
        part.Anchored = false
        part.CastShadow = false
        part.CanTouch = false
        part.CanQuery = false
    end
end

local function disableCollisions(model)
    for _, part in ipairs(model:GetDescendants()) do
        cleanPart(part)
    end
end

local function hideOriginalKnife(knife)
    for _, part in ipairs(knife:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("MeshPart") then
            part.Transparency = 1
        end
    end
end

local function playSound(folder, name)
    local weaponSounds = RS.Sounds:FindFirstChild(selectedKnife)
    if not weaponSounds then return end
    local sound = weaponSounds:WaitForChild(folder):WaitForChild(name):Clone()
    sound.Parent = camera
    sound:Play()
    sound.Ended:Once(function() sound:Destroy() end)
    return sound
end

local function attachAsset(folder, armPartName, assetModelName, finalName, offset)
    local targetArm = vm:FindFirstChild(armPartName)
    if not targetArm then return end
    if targetArm:FindFirstChild(finalName) then return end

    local assetMesh = folder:WaitForChild(assetModelName):Clone()
    cleanPart(assetMesh)
    assetMesh.Name = finalName
    assetMesh.Parent = targetArm
    
    local motor = Instance.new("Motor6D")
    motor.Part0 = targetArm
    motor.Part1 = assetMesh
    motor.C0 = offset
    motor.Parent = targetArm
end

local function handleAction(actionName, inputState, inputObject)
    if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
    if not spawned or not animator or not isAlive() then return Enum.ContextActionResult.Pass end
    local isEquipping = equipAnim and equipAnim.IsPlaying
    if actionName == ACTION_INSPECT then
        if isEquipping or inspecting or swinging then return Enum.ContextActionResult.Pass end
        inspecting = true
        if idleAnim then idleAnim:Stop() end
        inspectAnim:Play()
        inspectAnim.Stopped:Once(function() inspecting = false end)
    elseif actionName == ACTION_ATTACK then
        local currentTime = os.clock()
        if isEquipping or (currentTime - lastAttackTime < ATTACK_COOLDOWN) then return Enum.ContextActionResult.Pass end
        lastAttackTime = currentTime
        if inspecting then
            inspecting = false
            if inspectAnim then inspectAnim:Stop() end
        end
        swinging = true
        if idleAnim then idleAnim:Stop() end
        local anims = {HeavySwingAnim, Swing1Anim, Swing2Anim}
        local chosenAnim = anims[math.random(1, #anims)]
        local soundFolder = (chosenAnim == HeavySwingAnim and "HitOne") or (chosenAnim == Swing1Anim and "HitTwo") or "HitThree"
        chosenAnim:Play()
        local s = playSound(soundFolder, "1")
        if s then s.Volume = 5 end
        chosenAnim.Stopped:Once(function() swinging = false end)
    end
    return Enum.ContextActionResult.Pass
end

local function spawnViewmodel(knife)
    if spawned or not running then return end
    local myModel = isAlive()
    if not myModel then return end
    
    spawned = true
    local knifeTemplate = RS.Assets.Weapons:WaitForChild(selectedKnife)
    local knifeOffset = knives[selectedKnife].Offset
    vm = knifeTemplate:WaitForChild("Camera"):Clone()
    vm.Name = selectedKnife
    vm.Parent = camera
    disableCollisions(vm)
    hideOriginalKnife(knife)

    local leftArm = vm:FindFirstChild("Left Arm")
    local rightArm = vm:FindFirstChild("Right Arm")
    
    local sleeveC0 = CFrame.new(0, 0, 0.5)
    local gloveC0 = CFrame.new(0, 0, -1.5)

    if myModel.Parent.Name == "Terrorists" then
        local tGloves = RS.Assets.Weapons:WaitForChild("T Glove")
        attachAsset(tGloves, "Left Arm", "Left Arm", "Glove", gloveC0)
        attachAsset(tGloves, "Right Arm", "Right Arm", "Glove", gloveC0)
    else
        local sleeves = RS.Assets.Sleeves:WaitForChild("IDF")
        local ctGloves = RS.Assets.Weapons:WaitForChild("CT Glove")
        attachAsset(sleeves, "Left Arm", "Left Arm", "Sleeve", sleeveC0) 
        attachAsset(ctGloves, "Left Arm", "Left Arm", "Glove", gloveC0)
        
        attachAsset(sleeves, "Right Arm", "Right Arm", "Sleeve", sleeveC0) 
        attachAsset(ctGloves, "Right Arm", "Right Arm", "Glove", gloveC0)
    end

    local animController = vm:FindFirstChildOfClass("AnimationController") or vm:FindFirstChildOfClass("Animator")
    animator = animController:FindFirstChildWhichIsA("Animator") or animController
    local animFolder = RS.Assets.WeaponAnimations:WaitForChild(selectedKnife):WaitForChild("CameraAnimations")
    equipAnim = animator:LoadAnimation(animFolder:WaitForChild("Equip"))
    idleAnim = animator:LoadAnimation(animFolder:WaitForChild("Idle"))
    inspectAnim = animator:LoadAnimation(animFolder:WaitForChild("Inspect"))
    HeavySwingAnim = animator:LoadAnimation(animFolder:WaitForChild("Heavy Swing"))
    Swing1Anim = animator:LoadAnimation(animFolder:WaitForChild("Swing1"))
    Swing2Anim = animator:LoadAnimation(animFolder:WaitForChild("Swing2"))

    vm:SetPrimaryPartCFrame(camera.CFrame * CFrame.new(0, -1.5, 5))
    TweenService:Create(vm.PrimaryPart, TweenInfo.new(tweenSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = camera.CFrame * knifeOffset}):Play()
    equipAnim:Play()
    playSound("Equip", "1")
    CAS:BindAction(ACTION_INSPECT, handleAction, false, Enum.KeyCode.F)
    CAS:BindAction(ACTION_ATTACK, handleAction, false, Enum.UserInputType.MouseButton1)
end

local function removeViewmodel()
    if not spawned then return end
    spawned = false
    CAS:UnbindAction(ACTION_INSPECT)
    CAS:UnbindAction(ACTION_ATTACK)
    if vm then vm:Destroy() vm = nil end
    animator = nil
    inspecting = false
    swinging = false
end

CAS:BindAction("StopKnifeScript", function(name, state)
    if state == Enum.UserInputState.Begin then
        running = false
        removeViewmodel()
    end
end, false, Enum.KeyCode.L)

RunService.RenderStepped:Connect(function()
    if not running or not vm or not vm.PrimaryPart then return end
    local knifeOffset = knives[selectedKnife].Offset
    vm.PrimaryPart.CFrame = camera.CFrame * knifeOffset
    local isEquipping = equipAnim and equipAnim.IsPlaying
    if not isEquipping and not inspecting and not swinging then
        if idleAnim and not idleAnim.IsPlaying then
            idleAnim:Play()
        end
    end
end)

while running do
    local living = isAlive()
    local currentKnife = getKnifeInCamera()
    if living and currentKnife and not spawned then
        spawnViewmodel(currentKnife)
    elseif (not currentKnife or not living) and spawned then
        removeViewmodel()
    end
    task.wait(0.1)
end

Rayfield:LoadConfiguration()
