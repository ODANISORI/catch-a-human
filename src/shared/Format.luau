--!strict

local Format = {}

-- 1234567 -> "1,234,567"
function Format.number(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then
		sign = "-"
		s = string.sub(s, 2)
	end
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return sign .. out
end

-- 2500 -> "$2.5K", 1200000 -> "$1.2M"
function Format.cash(n: number): string
	local abs = math.abs(n)
	local function short(v: number, suffix: string): string
		local text = string.format("%.1f", v)
		text = string.gsub(text, "%.0$", "")
		return "$" .. text .. suffix
	end
	if abs >= 1e9 then
		return short(n / 1e9, "B")
	elseif abs >= 1e6 then
		return short(n / 1e6, "M")
	elseif abs >= 1e4 then
		return short(n / 1e3, "K")
	end
	return "$" .. Format.number(n)
end

function Format.kg(w: number): string
	return string.format("%.1f kg", w)
end

return Format
