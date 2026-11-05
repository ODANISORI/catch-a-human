--!strict
-- Fishing input and the placeholder fishing bar.
-- PC: click the beach to cast, click on a bite to hook, hold the mouse to reel.
-- Phone/tablet: one big action button (Cast / Hook / Reel); casting aims at the
-- middle of the screen. The camera is Roblox's default third-person camera and
-- is never moved or shaken by this script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Strings = require(ReplicatedStorage.Shared.Strings)
local Theme = require(script.Parent.Parent.UI.Theme)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CastRequest = Remotes:WaitForChild("CastRequest") :: RemoteFunction
local HookRequest = Remotes:WaitForChild("HookRequest") :: RemoteEvent
local ReelInput = Remotes:WaitForChild("ReelInput") :: RemoteEvent
local CancelCast = Remotes:WaitForChild("CancelCast") :: RemoteEvent
local FishingState = Remotes:WaitForChild("FishingState") :: RemoteEvent

local player = Players.LocalPlayer

local FishingController = {}

local state = "idle"
local holding = false
local casting = false
local toast: (string, Color3?) -> ()

local RESULT_TEXT: { [string]: string } = {
	escaped = "result.escaped",
	snapped = "result.snapped",
	missed = "result.missed",
	no_bite = "result.no_bite",
}

local function setHolding(value: boolean)
	if holding == value then
		return
	end
	holding = value
	if state == "reeling" then
		ReelInput:FireServer(value)
	end
end

local function aimPoint(screen: Vector2): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _, name in { "Humans", "Baits" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	return hit and hit.Position
end

local function cast(screen: Vector2)
	if casting then
		return
	end
	local point = aimPoint(screen)
	if not point then
		toast(Strings.code("no_zone"), Theme.colors.bad)
		return
	end
	casting = true
	local ok, res = pcall(function()
		return CastRequest:InvokeServer(point)
	end)
	casting = false
	if ok and res and not res.ok then
		toast(Strings.code(res.code), Theme.colors.bad)
	end
end

-- One "press" from mouse, touch button or gamepad.
local function press(screen: Vector2)
	if state == "idle" then
		task.spawn(cast, screen)
	elseif state == "waiting" then
		CancelCast:FireServer()
	elseif state == "bite" then
		HookRequest:FireServer()
		state = "reeling"
		holding = true -- the server starts the reel as holding
	elseif state == "reeling" then
		setHolding(true)
	end
end

local function release()
	setHolding(false)
end

function FishingController.start(toastFn: (string, Color3?) -> ())
	toast = toastFn
	local touch = UserInputService.TouchEnabled

	local gui = Theme.create("ScreenGui", {
		Name = "Fishing",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local status = Theme.label({
		Name = "Status",
		Text = Strings.get(if touch then "fish.cast_hint_touch" else "fish.cast_hint"),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.new(0.8, 0, 0, 28),
		Parent = gui,
	})

	local barFrame = Theme.create("Frame", {
		Name = "Bars",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(320, 56),
		BackgroundColor3 = Theme.colors.panelDark,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
		Theme.corner(10),
		Theme.stroke(),
	})
	local function bar(y: number, color: Color3): Frame
		local back = Theme.create("Frame", {
			Position = UDim2.new(0, 10, 0, y),
			Size = UDim2.new(1, -20, 0, 16),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			Parent = barFrame,
			Theme.corner(6),
		})
		return Theme.create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = color,
			Parent = back,
			Theme.corner(6),
		})
	end
	local progressFill = bar(10, Theme.colors.progress)
	local tensionFill = bar(32, Theme.colors.tension)

	local actionButton = Theme.button({
		Name = "Action",
		Text = Strings.get("fish.btn_cast"),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -150),
		Size = UDim2.fromOffset(110, 110),
		TextSize = 26,
		Visible = touch,
		Parent = gui,
		Theme.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})

	local function center(): Vector2
		local camera = Workspace.CurrentCamera
		return if camera then camera.ViewportSize / 2 else Vector2.zero
	end

	actionButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			press(center())
		end
	end)
	actionButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			release()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = UserInputService:GetMouseLocation()
			press(pos)
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			press(center())
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			release()
		end
	end)

	local function show(newState: string)
		state = newState
		barFrame.Visible = newState == "reeling"
		if newState == "idle" then
			actionButton.Text = Strings.get("fish.btn_cast")
			actionButton.BackgroundColor3 = Theme.colors.button
			status.Text = Strings.get(if touch then "fish.cast_hint_touch" else "fish.cast_hint")
			status.TextColor3 = Theme.colors.text
		elseif newState == "waiting" then
			actionButton.Text = Strings.get("fish.btn_cancel")
			actionButton.BackgroundColor3 = Theme.colors.buttonOff
			status.Text = Strings.get("fish.waiting")
			status.TextColor3 = Theme.colors.text
		elseif newState == "bite" then
			actionButton.Text = Strings.get("fish.btn_hook")
			actionButton.BackgroundColor3 = Theme.colors.accent
			status.Text = Strings.get(if touch then "fish.bite_touch" else "fish.bite")
			status.TextColor3 = Theme.colors.accent
		elseif newState == "reeling" then
			actionButton.Text = Strings.get("fish.btn_reel")
			actionButton.BackgroundColor3 = Theme.colors.button
		end
	end

	FishingState.OnClientEvent:Connect(function(payload)
		local s = payload.state
		if s == "idle" then
			show("idle")
			holding = false
			local key = payload.result and RESULT_TEXT[payload.result]
			if key then
				toast(Strings.get(key), Theme.colors.bad)
			end
		elseif s == "waiting" or s == "bite" then
			show(s)
		elseif s == "reeling" then
			if state ~= "reeling" or not barFrame.Visible then
				show("reeling")
				-- Tell the server what we're actually doing right now.
				ReelInput:FireServer(holding)
			end
			progressFill.Size = UDim2.fromScale(math.clamp(payload.p, 0, 1), 1)
			tensionFill.Size = UDim2.fromScale(math.clamp(payload.tn, 0, 1), 1)
			if payload.thrash then
				status.Text = Strings.get("fish.thrash")
				status.TextColor3 = Theme.colors.bad
			elseif payload.warn then
				status.Text = "!!!"
				status.TextColor3 = Theme.colors.accent
			else
				status.Text = Strings.get("fish.reeling")
				status.TextColor3 = Theme.colors.text
			end
		end
	end)

end

return FishingController
