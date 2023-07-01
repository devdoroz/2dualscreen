--[[
	2dualscreen (QBA)
		@author 2ds
--]]

do --//
	local coreGui = game:GetService("CoreGui")
	local contentProvider = game:GetService('ContentProvider')
	local tbl = {}
	
	for index, descendant in pairs(coreGui:GetDescendants()) do
		if descendant:IsA("ImageLabel") and string.find(descendant.Image, "rbxasset://") then
			table.insert(tbl, descendant.Image)
		end
	end
	
	local preloadAsync; preloadAsync = hookfunction(contentProvider.PreloadAsync, function(self, ...)
		local args = {...}
		if not checkcaller() and type(args[1]) == "table" and table.find(args[1], coreGui) then
			args[1] = tbl
			return preloadAsync(self, unpack(args))
		end
		return preloadAsync(self, ...)
	end)
	
	local function compareMethod(m1, m2)
		return string.lower(m1) == string.lower(m2)
	end
	
	local __namecall; __namecall = hookmetamethod(game, "__namecall", function(self, ...)
		local args = {...}
		local method = getnamecallmethod()
		if not checkcaller() and type(args[1]) == "table" and table.find(args[1], coreGui) and self == contentProvider and compareMethod("PreloadAsync", method) then
			args[1] = tbl
			return __namecall(self, unpack(args))
		end
		return __namecall(self, ...)
	end)
end

local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local player = players.LocalPlayer
local gui = game:GetObjects("rbxassetid://13738372093")[1]
local mouse = loadstring(game:HttpGet("https://raw.githubusercontent.com/devdoroz/better-roblox-mouse/main/main.lua"))()
local locked = false
local enabled = true
local target = nil
local part = Instance.new("Part"); part.Parent = workspace; part.Anchored = true part.Size = Vector3.new(3, 1.5, 3); part.CanCollide = false
local beam = Instance.new("Beam"); beam.Parent = workspace.Terrain
local highlight = Instance.new("Highlight")
highlight.FillColor = Color3.fromRGB(246, 65, 97)
highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment"); a0.Parent = workspace.Terrain; a1.Parent = workspace.Terrain
beam.Width0 = 0.5
beam.Width1 = 0.5
beam.Transparency = NumberSequence.new(0)
beam.Color = ColorSequence.new(Color3.fromRGB(246, 65, 97))
beam.Attachment0 = a0
beam.Segments = 3000
beam.Attachment1 = a1
local data = {
	Angle = 40,
	Power = 0,
	Direction = Vector3.new(0, 0, 0)
}
local passTypeLeads = {
	["Dime"] = 1,
	["Jump"] = 6,
	["Mag"] = 12,
	["Slant"] = 3,
}
local passTypeSwitch = {
	["Dime"] = "Jump",
	["Jump"] = "Mag",
	["Mag"] = "Slant",
	["Slant"] = "Dime"
}
local passType = "Dime"

do -- mouse stuff
	local whitelistedMousePart = Instance.new("Part")
	whitelistedMousePart.Size = Vector3.new(2048, 1, 2048)
	whitelistedMousePart.Anchored = true
	whitelistedMousePart.Transparency = 1
	whitelistedMousePart.Position = player.Character.HumanoidRootPart.Position - Vector3.new(0, 4, 0)
	whitelistedMousePart.CanCollide = false
	whitelistedMousePart.Parent = workspace
	local mouseRaycastParams = RaycastParams.new()
	mouseRaycastParams.FilterType = Enum.RaycastFilterType.Include
	mouseRaycastParams.FilterDescendantsInstances = {whitelistedMousePart}
	mouse:SetRaycastParams(mouseRaycastParams)
end

local function inverseCosine(degrees)
	return math.cos(math.rad(degrees))
end

local function calculateTimeToPeak(from, to, height)
	local g = Vector3.new(0, -28, 0)
	local conversionFactor = 4
	local xMeters = height * conversionFactor

	local a = 0.5 * g.Y
	local b = to.Y - from.Y
	local c = xMeters - from.Y

	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return nil
	end

	local t1 = (-b + math.sqrt(discriminant)) / (2 * a)
	local t2 = (-b - math.sqrt(discriminant)) / (2 * a)

	local t = math.max(t1, t2)
	return t
end

local function calculateLanding(power, direction)
	local origin = player.Character.Head.Position + direction * 5
	local velocity = power * direction
	local t = (velocity.Y / 28) * 2
	return origin + Vector3.new(velocity.X * t, 0, velocity.Z * t), t
end

local function findPossibleCatchers(power, direction)
	local velocity = power * direction
	local landing, airtime = calculateLanding(power, direction)
	local catchers = {}
	for index, player in pairs(players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - landing).Magnitude
			if distance < (20 * airtime) + 10 then
				catchers[#catchers + 1] = player
			end
		end
	end
	return catchers
end

local function calculatePeakHeight(from, to, angle)
	local unitY = 1 - inverseCosine(angle)
	local distance = (from - to).Magnitude
	return unitY * distance
end

local function calculateVelocity(from, to, time)
	local g = Vector3.new(0, -28, 0)
	local v0 = (to - from - 0.5*g*time*time)/time;
	local dir = ((from + v0) - from).Unit
	local power = v0.Y / dir.Y
	return v0, dir, math.clamp(math.round(power), 0, 95)
end

local function findTarget()
	local np = nil
	local nm = math.huge
	local s = {workspace}
	if workspace:FindFirstChild("npcwr") then
		table.insert(s, workspace.npcwr.a)
		table.insert(s, workspace.npcwr.b)
	end
	for i, p in pairs(s) do
		for i, c in pairs(p:GetChildren()) do
			if c:FindFirstChildWhichIsA("Humanoid") and c:FindFirstChild("HumanoidRootPart") then
				local plr = players:GetPlayerFromCharacter(c)
				if plr == player then continue end
				if not plr and game.PlaceId ~= 8206123457 then continue end
				if not player.Neutral then
					if plr.Team ~= player.Team then
						continue
					end
				end
				local d = (c.HumanoidRootPart.Position - mouse.Hit.Position).Magnitude
				if d < nm then
					nm = d
					np = c
				end	
			end
		end
	end
	return np
end

local function getMoveDirection(target)
	if players:GetPlayerFromCharacter(target) then
		return target.Humanoid.MoveDirection
	else
		return (target.Humanoid.WalkToPoint - target.Head.Position).Unit
	end
end

local __namecall; __namecall = hookmetamethod(game, "__namecall", function(self, ...)
	local method = getnamecallmethod()
	local args = {...}
	if args[1] == "Clicked" and enabled then
		local nwArgs = {"Clicked", player.Character.Head.Position, player.Character.Head.Position + data.Direction * 10000, (game.PlaceId == 8206123457 and data.Power) or 60, data.Power}
		return __namecall(self, unpack(nwArgs))	
	end
	return __namecall(self, ...)
end)

userInputService.InputBegan:Connect(function(input, gp)
	if not gp and player.PlayerGui:FindFirstChild("BallGui") then
		if input.KeyCode == Enum.KeyCode.R then
			while userInputService:IsKeyDown(Enum.KeyCode.R) do
				data.Angle += 5
				data.Angle = math.clamp(data.Angle, 5, 90)
				task.wait(1/6)
			end
		elseif input.KeyCode == Enum.KeyCode.F then
			while userInputService:IsKeyDown(Enum.KeyCode.F) do
				data.Angle -= 5
				data.Angle = math.clamp(data.Angle, 5, 90)
				task.wait(1/6)
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			locked = not locked
		elseif input.KeyCode == Enum.KeyCode.Z then
			passType = passTypeSwitch[passType]
		end
	end
end)

local function beamProjectile(g, v0, x0, t1)
	local c = 0.5*0.5*0.5;
	local p3 = 0.5*g*t1*t1 + v0*t1 + x0;
	local p2 = p3 - (g*t1*t1 + v0*t1)/3;
	local p1 = (c*g*t1*t1 + 0.5*v0*t1 + x0 - c*(x0+p3))/(3*c) - p2;

	local curve0 = (p1 - x0).Magnitude;
	local curve1 = (p2 - p3).Magnitude;

	local b = (x0 - p3).Unit;
	local r1 = (p1 - x0).Unit;
	local u1 = r1:Cross(b).Unit;
	local r2 = (p2 - p3).Unit;
	local u2 = r2:Cross(b).Unit;
	b = u1:Cross(r1).Unit;

	local cf1 = CFrame.new(
		x0.x, x0.y, x0.z,
		r1.x, u1.x, b.x,
		r1.y, u1.y, b.y,
		r1.z, u1.z, b.z
	)

	local cf2 = CFrame.new(
		p3.x, p3.y, p3.z,
		r2.x, u2.x, b.x,
		r2.y, u2.y, b.y,
		r2.z, u2.z, b.z
	)

	return curve0, -curve1, cf1, cf2;
end

gui.Enabled = false
gui.Parent = game:GetService("CoreGui"):FindFirstChild("RobloxGui")

while true do
	task.wait()
	if not locked then
		target = findTarget()
	end
	if target and enabled and player.PlayerGui:FindFirstChild("BallGui") and player.Character:FindFirstChild("Head") and target:FindFirstChild("HumanoidRootPart") then
		gui.Enabled = true
		local moveDirection = getMoveDirection(target)
		local angleAddition = (moveDirection.Magnitude > 0 and 5) or 0
		local leadDistance = passTypeLeads[passType]
		local peakHeight = calculatePeakHeight(player.Character.Head.Position, target.HumanoidRootPart.Position + (moveDirection * leadDistance), data.Angle + angleAddition)
		local t = calculateTimeToPeak(player.Character.Head.Position, target.HumanoidRootPart.Position + (moveDirection * leadDistance), peakHeight) or 0.5
		local vel, direction, power = calculateVelocity(player.Character.Head.Position, target.HumanoidRootPart.Position + (moveDirection * 20 * t) + (moveDirection * leadDistance), t)
		local catchers = findPossibleCatchers(power, direction)
		local landing, airtime = calculateLanding(power, direction)
		local c0, c1, cf1, cf2 = beamProjectile(Vector3.new(0, -28, 0), power * direction, player.Character.Head.Position + (direction * 5), airtime)
		local isInterceptable = false
		for index, catcher in pairs(catchers) do
			local team = catcher.Team
			if team ~= player.Team then
				isInterceptable = true
				break
			end
		end
		part.Position = landing
		beam.CurveSize0 = c0
		beam.CurveSize1 = c1
		a0.CFrame = a0.Parent.CFrame:Inverse() * cf1
		a1.CFrame = a1.Parent.CFrame:Inverse() * cf2
		data.Direction = direction; data.Power = power
		highlight.Parent = target
		gui.Frame.PowerCard.Power.Text = power
		gui.Frame.AngleCard.Angle.Text = data.Angle
		gui.Frame.CatchableCard.Catchable.Text = (#catchers > 0 and "Yes") or "No"
		gui.Frame.InterceptableCard.Interceptable.Text = (isInterceptable and "Yes") or "No"
		gui.Frame.PassTypeCard.Type.Text = passType
	else
		gui.Enabled = false
		highlight.Parent = nil
	end
end
