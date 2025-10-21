local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local FIREBASE_URL = "https://daily-rewards-5a54c-default-rtdb.firebaseio.com/"

local function prettyEncode(data, indentLevel)
	indentLevel = indentLevel or 1
	local indent = string.rep("  ", indentLevel)
	local nextIndent = string.rep("  ", indentLevel + 1)
	local output = {}

	if type(data) == "table" then
		if #data > 0 then
			table.insert(output, "[\n")
			for i, v in ipairs(data) do
				table.insert(output, nextIndent .. prettyEncode(v, indentLevel + 1))
				if i < #data then
					table.insert(output, ",\n")
				else
					table.insert(output, "\n")
				end
			end
			table.insert(output, indent .. "]")
		else
			table.insert(output, "{\n")
			local keys = {}
			for k in pairs(data) do
				table.insert(keys, k)
			end
			table.sort(keys)
			for i, k in ipairs(keys) do
				local v = data[k]
				local keyStr = string.format("\"%s\"", k)
				table.insert(output, string.format("%s%s: %s", nextIndent, keyStr, prettyEncode(v, indentLevel + 1)))
				if i < #keys then
					table.insert(output, ",\n")
				else
					table.insert(output, "\n")
				end
			end
			table.insert(output, indent .. "}")
		end
	elseif type(data) == "string" then
		return string.format("\"%s\"", data)
	else
		return tostring(data)
	end

	return table.concat(output)
end

local function scrapeAndSendData()
	local finalData = {
		timeLeft = "Not Found",
		rewards = {},
		brainrotRequirements = {}
	}

	pcall(function()
		local textLabel = Workspace.ScriptedMap.Dailys.DailyIsland.DailySign.BillboardGui.TextLabel
		local matchedTime = textLabel.Text:match("Daily Resets: (.+)")
		if matchedTime then
			finalData.timeLeft = matchedTime
		end
	end)

	pcall(function()
		local rewardsContainer = Workspace.ScriptedMap.Dailys.DailyIsland.Main.SurfaceGui.Content.Rewards
		for _, rewardFrame in ipairs(rewardsContainer:GetChildren()) do
			if rewardFrame:IsA("Frame") and rewardFrame.Name ~= "Template" then
				local content = rewardFrame:FindFirstChild("Content")
				if content then
					local icon = content:FindFirstChild("Icon")
					local amount = content:FindFirstChild("Amount")
					local title = content:FindFirstChild("Title")
					if icon and amount and title then
						table.insert(finalData.rewards, {
							icon = icon.Image,
							amount = amount.Text,
							title = title.Text
						})
					end
				end
			end
		end
	end)

	pcall(function()
		local plotsFolder = Workspace.Plots
		if plotsFolder and LocalPlayer then
			for _, plot in ipairs(plotsFolder:GetChildren()) do
				if plot:GetAttribute("Owner") == LocalPlayer.Name then
					local eventPlatforms = plot:FindFirstChild("EventPlatforms")
					if eventPlatforms then
						local tempBrainrots = {}
						for _, platform in ipairs(eventPlatforms:GetChildren()) do
							if platform:IsA("Model") then
								local brainrotName = platform:GetAttribute("VisualBrainrot")
								local orderNum = tonumber(platform.Name:match("-?(%d+)"))
								if brainrotName and orderNum then
									table.insert(tempBrainrots, {order = orderNum, name = brainrotName})
								end
							end
						end
						
						table.sort(tempBrainrots, function(a, b) return a.order < b.order end)
						
						for _, data in ipairs(tempBrainrots) do
							table.insert(finalData.brainrotRequirements, data.name)
						end
					end
					break
				end
			end
		end
	end)

	local prettyJson = prettyEncode(finalData)
	
	pcall(function()
		request({
			Url = FIREBASE_URL .. "daily_data.json",
			Method = "PUT",
			Headers = {["Content-Type"] = "application/json"},
			Body = prettyJson
		})
	end)
end

while true do
	scrapeAndSendData()
	task.wait(1)
end
