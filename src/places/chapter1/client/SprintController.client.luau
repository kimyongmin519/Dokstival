--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- 달리기 조절값입니다. 숫자만 바꾸면 됩니다.
local WALK_SPEED = 16
local RUN_SPEED = 24
local ACCELERATION_TIME = 1.0
local DECELERATION_TIME = 0.45
local MAX_STAMINA = 100
local STAMINA_DRAIN_PER_SECOND = 22
local STAMINA_RECOVERY_PER_SECOND = 18
local STAMINA_RECOVERY_DELAY = 0.4
local STAMINA_TO_RESUME = 25

local humanoid: Humanoid? = nil
local shiftHeld = false
local exhausted = false
local stamina = MAX_STAMINA
local currentSpeed = WALK_SPEED
local timeSinceSprinting = STAMINA_RECOVERY_DELAY
local uiVisibility = 0

local function moveTowards(current: number, target: number, maximumChange: number): number
	if current < target then
		return math.min(current + maximumChange, target)
	end
	return math.max(current - maximumChange, target)
end

local function smooth(current: number, target: number, speed: number, deltaTime: number): number
	return current + (target - current) * (1 - math.exp(-speed * deltaTime))
end

local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local oldGui = playerGui:FindFirstChild("SprintGui")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SprintGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.AnchorPoint = Vector2.new(0.5, 1)
background.Position = UDim2.new(0.5, 0, 1, -42)
background.Size = UDim2.fromOffset(180, 4)
background.BorderSizePixel = 0
background.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
background.BackgroundTransparency = 1
background.ClipsDescendants = true
background.Parent = screenGui

local backgroundCorner = Instance.new("UICorner")
backgroundCorner.CornerRadius = UDim.new(1, 0)
backgroundCorner.Parent = background

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BorderSizePixel = 0
fill.BackgroundColor3 = Color3.fromRGB(224, 224, 216)
fill.BackgroundTransparency = 1
fill.Parent = background

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local function onCharacterAdded(character: Model): ()
	local foundHumanoid = character:WaitForChild("Humanoid")
	if not foundHumanoid:IsA("Humanoid") then
		return
	end

	humanoid = foundHumanoid
	shiftHeld = false
	exhausted = false
	stamina = MAX_STAMINA
	currentSpeed = WALK_SPEED
	timeSinceSprinting = STAMINA_RECOVERY_DELAY
	uiVisibility = 0
	foundHumanoid.WalkSpeed = WALK_SPEED

	foundHumanoid.Died:Connect(function()
		if humanoid == foundHumanoid then
			shiftHeld = false
		end
	end)
end

local function canMove(currentHumanoid: Humanoid): boolean
	local state = currentHumanoid:GetState()
	return currentHumanoid.Health > 0
		and currentHumanoid.MoveDirection.Magnitude > 0.05
		and not currentHumanoid.Sit
		and not currentHumanoid.PlatformStand
		and state ~= Enum.HumanoidStateType.Dead
		and state ~= Enum.HumanoidStateType.Seated
		and state ~= Enum.HumanoidStateType.Climbing
		and state ~= Enum.HumanoidStateType.Swimming
end

local function update(deltaTime: number): ()
	local currentHumanoid = humanoid
	if not currentHumanoid or currentHumanoid.Parent == nil then
		return
	end

	local moving = canMove(currentHumanoid)
	local sprinting = shiftHeld and moving and not exhausted

	if sprinting then
		timeSinceSprinting = 0
		stamina = math.max(stamina - STAMINA_DRAIN_PER_SECOND * deltaTime, 0)
		if stamina <= 0 then
			exhausted = true
			sprinting = false
		end
	else
		timeSinceSprinting += deltaTime
		if timeSinceSprinting >= STAMINA_RECOVERY_DELAY then
			stamina = math.min(stamina + STAMINA_RECOVERY_PER_SECOND * deltaTime, MAX_STAMINA)
		end
		if exhausted and stamina >= STAMINA_TO_RESUME then
			exhausted = false
		end
	end

	local targetSpeed = if sprinting then RUN_SPEED else WALK_SPEED
	local speedRange = math.max(RUN_SPEED - WALK_SPEED, 0)
	local changeTime = if targetSpeed > currentSpeed then ACCELERATION_TIME else DECELERATION_TIME
	local speedChange = if changeTime > 0 then speedRange / changeTime * deltaTime else speedRange
	currentSpeed = moveTowards(currentSpeed, targetSpeed, speedChange)
	currentHumanoid.WalkSpeed = currentSpeed

	-- 기본 R6 Animate는 Humanoid의 실제 이동 속도를 받아 걷기/달리기를 재생합니다.
	local staminaRatio = math.clamp(stamina / MAX_STAMINA, 0, 1)
	fill.Size = UDim2.fromScale(staminaRatio, 1)
	local shouldShow = sprinting or stamina < MAX_STAMINA - 0.01
	uiVisibility = smooth(uiVisibility, if shouldShow then 1 else 0, 8, deltaTime)
	background.BackgroundTransparency = 1 - uiVisibility * 0.65
	fill.BackgroundTransparency = 1 - uiVisibility * 0.92
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if input.KeyCode == Enum.KeyCode.LeftShift
		and not gameProcessed
		and UserInputService:GetFocusedTextBox() == nil
	then
		shiftHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		shiftHeld = false
	end
end)

-- 채팅 입력 또는 창 전환 중 Shift가 눌린 채로 남는 일을 막습니다.
UserInputService.TextBoxFocused:Connect(function()
	shiftHeld = false
end)
UserInputService.WindowFocusReleased:Connect(function()
	shiftHeld = false
end)

player.CharacterAdded:Connect(onCharacterAdded)
local initialCharacter = player.Character
if initialCharacter then
	task.spawn(onCharacterAdded, initialCharacter)
end

RunService.Heartbeat:Connect(update)
