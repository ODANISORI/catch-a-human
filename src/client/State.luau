--!strict
-- Latest copy of this player's data as sent by the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local State = {}

State.data = nil :: { [string]: any }?

local changedEvent = Instance.new("BindableEvent")
State.Changed = changedEvent.Event

local function set(snapshot: { [string]: any })
	State.data = snapshot
	changedEvent:Fire(snapshot)
end

function State.start()
	(Remotes:WaitForChild("DataChanged") :: RemoteEvent).OnClientEvent:Connect(set)
	task.spawn(function()
		local ok, snapshot = pcall(function()
			return (Remotes:WaitForChild("GetData") :: RemoteFunction):InvokeServer()
		end)
		if ok and snapshot and not State.data then
			set(snapshot)
		end
	end)
end

return State
