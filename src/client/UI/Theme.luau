--!strict
-- Placeholder look for the first playable. The UI builder replaces this.

local Theme = {}

Theme.colors = {
	panel = Color3.fromRGB(20, 60, 90),
	panelDark = Color3.fromRGB(12, 40, 62),
	stroke = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(190, 220, 235),
	cash = Color3.fromRGB(120, 240, 120),
	accent = Color3.fromRGB(255, 200, 50),
	button = Color3.fromRGB(40, 170, 90),
	buttonOff = Color3.fromRGB(90, 100, 110),
	bad = Color3.fromRGB(255, 110, 110),
	progress = Color3.fromRGB(80, 220, 120),
	tension = Color3.fromRGB(255, 90, 70),
}

Theme.font = Font.fromEnum(Enum.Font.FredokaOne)

function Theme.create(className: string, props: { [any]: any }): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props do
		if typeof(key) == "number" then
			value.Parent = inst
		elseif key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Theme.corner(radius: number): UICorner
	return Theme.create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Theme.stroke(thickness: number?): UIStroke
	return Theme.create("UIStroke", {
		Color = Theme.colors.stroke,
		Thickness = thickness or 2,
		Transparency = 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.label(props: { [any]: any }): TextLabel
	local defaults: { [any]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.font,
		TextColor3 = Theme.colors.text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Theme.create("TextLabel", defaults)
end

function Theme.button(props: { [any]: any }): TextButton
	local defaults: { [any]: any } = {
		BackgroundColor3 = Theme.colors.button,
		FontFace = Theme.font,
		TextColor3 = Theme.colors.text,
		TextSize = 18,
		AutoButtonColor = true,
		Theme.corner(10),
		Theme.stroke(),
	}
	for key, value in props do
		defaults[key] = value
	end
	return Theme.create("TextButton", defaults)
end

return Theme
