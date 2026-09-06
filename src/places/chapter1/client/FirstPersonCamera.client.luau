--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- 머리 시점을 기준으로 한 카메라 위치입니다.
-- X: 수평 좌우, Y: 항상 위아래, Z: 수평 앞뒤입니다. 음수 Z는 앞쪽입니다.
local CAMERA_POSITION_OFFSET = Vector3.new(0, 0.2, -1)

-- 카메라 효과 강도입니다. 모두 작게 유지해 멀미와 조작 방해를 줄입니다.
local BREATH_HEIGHT = 0.018
local BREATH_PITCH = math.rad(0.1)
local WALK_HEIGHT = 0.022
local WALK_ROLL = math.rad(0.12)
local MAX_LEAN = math.rad(1.25)
local MAX_ROTATION_INERTIA = math.rad(0.7)
local LANDING_THRESHOLD = 20
local MAX_LANDING_KICK = 0.075

local R6_BODY_PARTS = {
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

local character: Model? = nil
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil

local breathTime = 0
local walkTime = 0
local walkBlend = 0
local lean = 0
local rotationPitch = 0
local rotationRoll = 0
local landingOffset = 0
local landingVelocity = 0
local lowestVerticalVelocity = 0
local wasGrounded = true

local function smooth(current: number, target: number, speed: number, deltaTime: number): number
	return current + (target - current) * (1 - math.exp(-speed * deltaTime))
end

local function updateLocalVisibility(currentCharacter: Model): ()
	-- Roblox 기본 1인칭은 몸도 숨기므로 R6 몸통·팔·다리만 다시 보이게 합니다.
	for _, partName in R6_BODY_PARTS do
		local bodyPart = currentCharacter:FindFirstChild(partName)
		if bodyPart and bodyPart:IsA("BasePart") then
			bodyPart.LocalTransparencyModifier = 0
		end
	end

	local head = currentCharacter:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		head.LocalTransparencyModifier = 1
	end

	-- 액세서리는 카메라 앞을 가릴 수 있으므로 이 플레이어 화면에서만 숨깁니다.
	for _, child in currentCharacter:GetChildren() do
		if child:IsA("Accessory") then
			for _, descendant in child:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

local function resetMotion(): ()
	breathTime = 0
	walkTime = 0
	walkBlend = 0
	lean = 0
	rotationPitch = 0
	rotationRoll = 0
	landingOffset = 0
	landingVelocity = 0
	lowestVerticalVelocity = 0
	wasGrounded = true
end

local function onCharacterAdded(newCharacter: Model): ()
	character = newCharacter
	humanoid = nil
	rootPart = nil
	resetMotion()

	local foundHumanoid = newCharacter:WaitForChild("Humanoid")
	local foundRoot = newCharacter:WaitForChild("HumanoidRootPart")
	if character ~= newCharacter then
		return
	end
	if not foundHumanoid:IsA("Humanoid") or not foundRoot:IsA("BasePart") then
		return
	end

	humanoid = foundHumanoid
	rootPart = foundRoot
	if foundHumanoid.RigType ~= Enum.HumanoidRigType.R6 then
		warn("Chapter 1 first-person camera expects an R6 avatar")
	end
end

local function updateCamera(deltaTime: number): ()
	local currentCharacter = character
	local currentHumanoid = humanoid
	local currentRoot = rootPart
	local camera = workspace.CurrentCamera
	if not currentCharacter or not currentHumanoid or not currentRoot or not camera then
		return
	end

	updateLocalVisibility(currentCharacter)
	if currentHumanoid.Health <= 0 then
		return
	end

	-- 큰 프레임 지연 뒤 효과가 튀지 않도록 계산 간격을 제한합니다.
	local dt = math.min(deltaTime, 1 / 20)
	local velocity = currentRoot.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local grounded = currentHumanoid.FloorMaterial ~= Enum.Material.Air

	local walkTarget = if grounded
		then math.clamp(horizontalSpeed / math.max(currentHumanoid.WalkSpeed, 1), 0, 1)
		else 0
	walkBlend = smooth(walkBlend, walkTarget, 10, dt)
	walkTime += dt * (8 + horizontalSpeed * 0.3)
	breathTime += dt * math.pi * 2 * 1.1

	local moveRight = currentHumanoid.MoveDirection:Dot(currentRoot.CFrame.RightVector)
	lean = smooth(lean, -moveRight * MAX_LEAN, 8, dt)

	-- 추가 Yaw는 이동 중 몸 회전과 충돌하므로 사용하지 않습니다.
	-- 좌우 회전 관성은 이동 방향에 영향을 주지 않는 작은 Roll로 표현합니다.
	local mouseDelta = UserInputService:GetMouseDelta()
	local targetPitch = math.clamp(-mouseDelta.Y * 0.00045, -MAX_ROTATION_INERTIA, MAX_ROTATION_INERTIA)
	local targetRoll = math.clamp(mouseDelta.X * 0.00045, -MAX_ROTATION_INERTIA, MAX_ROTATION_INERTIA)
	rotationPitch = smooth(rotationPitch, targetPitch, 12, dt)
	rotationRoll = smooth(rotationRoll, targetRoll, 12, dt)

	if grounded then
		if not wasGrounded then
			local impact = math.clamp(
				(-lowestVerticalVelocity - LANDING_THRESHOLD) / 55,
				0,
				1
			)
			landingVelocity -= impact * 1.4
		end
		lowestVerticalVelocity = 0
	else
		lowestVerticalVelocity = math.min(lowestVerticalVelocity, velocity.Y)
	end
	wasGrounded = grounded

	-- 착지 충격은 아래로 눌린 뒤 스프링처럼 원위치로 돌아옵니다.
	landingVelocity += (-landingOffset * 90 - landingVelocity * 16) * dt
	landingOffset += landingVelocity * dt
	landingOffset = math.clamp(landingOffset, -MAX_LANDING_KICK, MAX_LANDING_KICK)

	local breathY = math.sin(breathTime) * BREATH_HEIGHT
	local breathPitch = math.cos(breathTime) * BREATH_PITCH
	local walkY = math.cos(walkTime * 2) * WALK_HEIGHT * walkBlend
	local walkRoll = math.sin(walkTime) * WALK_ROLL * walkBlend

	-- 카메라 Pitch를 위치축에 사용하면 아래를 볼 때 Z 이동도 아래로 기울어집니다.
	-- 따라서 머리 시점의 수평 방향만 사용하고, Y는 월드 높이로 따로 더합니다.
	local baseCamera = camera.CFrame
	local horizontalForward = Vector3.new(baseCamera.LookVector.X, 0, baseCamera.LookVector.Z)
	if horizontalForward.Magnitude < 0.001 then
		local rootForward = currentRoot.CFrame.LookVector
		horizontalForward = Vector3.new(rootForward.X, 0, rootForward.Z)
	end
	horizontalForward = horizontalForward.Unit
	local horizontalRight = horizontalForward:Cross(Vector3.yAxis)
	local basePositionOffset = horizontalRight * CAMERA_POSITION_OFFSET.X
		+ Vector3.yAxis * CAMERA_POSITION_OFFSET.Y
		- horizontalForward * CAMERA_POSITION_OFFSET.Z
	local verticalMotion = Vector3.yAxis * (breathY + walkY + landingOffset)
	local cameraRotation = baseCamera.Rotation
	local effectRotation = CFrame.Angles(
		breathPitch + rotationPitch,
		0,
		lean + walkRoll + rotationRoll
	)
	camera.CFrame = CFrame.new(baseCamera.Position + basePositionOffset + verticalMotion)
		* cameraRotation
		* effectRotation
end

player.CameraMode = Enum.CameraMode.LockFirstPerson
player.CharacterAdded:Connect(onCharacterAdded)
local initialCharacter = player.Character
if initialCharacter then
	task.spawn(onCharacterAdded, initialCharacter)
end

RunService:BindToRenderStep(
	"DokstivalChapterFirstPersonCamera",
	Enum.RenderPriority.Camera.Value + 1,
	updateCamera
)
