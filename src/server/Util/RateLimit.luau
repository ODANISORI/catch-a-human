--!strict
-- Per-player token bucket. Rejects requests faster than a human could make them.

local Players = game:GetService("Players")

local RateLimit = {}

type Bucket = { tokens: number, last: number }

local buckets: { [string]: { [Player]: Bucket } } = {}

-- Returns true when the request may go ahead.
function RateLimit.allow(player: Player, name: string, perSecond: number): boolean
	local byPlayer = buckets[name]
	if not byPlayer then
		byPlayer = {}
		buckets[name] = byPlayer
	end
	local now = os.clock()
	local bucket = byPlayer[player]
	if not bucket then
		bucket = { tokens = perSecond, last = now }
		byPlayer[player] = bucket
	end
	bucket.tokens = math.min(perSecond, bucket.tokens + (now - bucket.last) * perSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	for _, byPlayer in buckets do
		byPlayer[player] = nil
	end
end)

return RateLimit
