local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
	vu:CaptureController()
	vu:ClickButton2(Vector2.new())
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FIREBASE_BASE_URL = "https://leaderboard-fetcher-default-rtdb.firebaseio.com/leaderboards"
local updateEvent = ReplicatedStorage.Remotes.UpdateLeaderboards

local function processData(data)
	for categoryName, categoryData in pairs(data) do
		task.spawn(function()
			local leaderboardArray = {}

			if #categoryData > 0 then
				for rank, entry in ipairs(categoryData) do
					local keyParts = entry.key:split('_')
					local username = keyParts[3]
					local value = entry.value
					
					if username and value then
						local formattedValue = value
						if typeof(value) == "number" and value > 9e15 then
							formattedValue = string.format("%.0f", value)
						end

						local playerData = {
							rank = rank,
							username = username,
							value = formattedValue
						}
						table.insert(leaderboardArray, playerData)
					end
				end
			end
			
			local finalPayload = {
				lastUpdated = os.date("%Y-%m-%d %I:%M:%S %p"),
				data = leaderboardArray
			}

			local categoryUrl = FIREBASE_BASE_URL .. "/" .. categoryName .. ".json"
			local success, encodedJson = pcall(HttpService.JSONEncode, HttpService, finalPayload)
			if not success then
				return
			end
			
			pcall(function()
				request({
					Url = categoryUrl,
					Method = "PUT",
					Headers = {["Content-Type"] = "application/json"},
					Body = encodedJson
				})
			end)
		end)
	end
end

updateEvent.OnClientEvent:Connect(processData)

task.spawn(function()
	while true do
		task.wait(5)
		updateEvent:FireServer()
	end
end)

updateEvent:FireServer()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("Main")

local FIREBASE_URL = "https://game-stock-data-default-rtdb.firebaseio.com/"

local activeEvents = {}
local seedsScrolling
local gearsScrolling

local function isIgnored(inst)
	if not inst or inst.Name == "Padding" then
		return true
	end
	local c = inst.ClassName
	return c == "UIPadding" or c == "UIListLayout"
end

local function findStockLabel(frame)
	for _, v in ipairs(frame:GetDescendants()) do
		if v:IsA("TextLabel") and v.Text and v.Text:lower():find("in stock") then
			return v
		end
	end
	return nil
end

local function findEventTimerLabel(frame)
	for _, v in ipairs(frame:GetDescendants()) do
		if v:IsA("TextLabel") and v.Text and v.Text:find(":") then
			return v
		end
	end
	return nil
end

local function parseStock(text)
	if not text then
		return 0
	end
	local n = text:match("x%s*(%d+)") or text:match("(%d+)")
	return tonumber(n) or 0
end

local function parseTimeToSeconds(text)
	if not text then
		return 0
	end
	local mm, ss = text:match("(%d+):(%d+)")
	if mm and ss then
		return tonumber(mm) * 60 + tonumber(ss)
	end
	local ssOnly = text:match("(%d+)")
	return tonumber(ssOnly) or 0
end

local function getStockFromFrame(scrollingFrame)
	local stockItems = {}
	if not scrollingFrame then
		return stockItems
	end
	for _, itemFrame in ipairs(scrollingFrame:GetChildren()) do
		if not isIgnored(itemFrame) then
			local stockLabel = findStockLabel(itemFrame)
			if stockLabel and stockLabel.Text then
				local stockCount = parseStock(stockLabel.Text)
				if stockCount > 0 then
					local cleanName = itemFrame.Name:gsub("%s*Seed$", "")
					stockItems[cleanName] = "x" .. tostring(stockCount)
				end
			end
		end
	end
	return stockItems
end

local function sendLogData()
	local plantItems = getStockFromFrame(seedsScrolling)
	local gearItems = getStockFromFrame(gearsScrolling)

	local eventsPayload
	if next(activeEvents) == nil then
		eventsPayload = "none"
	else
		eventsPayload = activeEvents
	end

	local newLogEntry = {
		timestamp = os.date("%Y-%m-%d %I:%M:%S %p"),
		items = {
			plants = plantItems,
			gears = gearItems
		},
		events = eventsPayload
	}

	local success, encodedJson = pcall(HttpService.JSONEncode, HttpService, newLogEntry)
	if not success then
		return
	end

	local fullUrl = FIREBASE_URL .. "latest_stock.json"
	
	pcall(function()
		request({
			Url = fullUrl,
			Method = "PUT",
			Headers = {["Content-Type"] = "application/json"},
			Body = encodedJson
		})
	end)
end

local function runLogger()
	local seedsGui = mainGui:WaitForChild("Seeds", 5)
	local gearsGui = mainGui:WaitForChild("Gears", 5)
	local effectsFrame = mainGui:WaitForChild("Effects", 5)
	
	if not (seedsGui or effectsFrame) then
		return
	end

	if seedsGui then
		seedsScrolling = seedsGui.Frame:WaitForChild("ScrollingFrame", 5)
		local restockLabel = seedsGui:WaitForChild("Restock", 5)

		if restockLabel and seedsScrolling then
			local lastSeconds = parseTimeToSeconds(restockLabel.Text)
			restockLabel:GetPropertyChangedSignal("Text"):Connect(function()
				local s = parseTimeToSeconds(restockLabel.Text)
				if s > lastSeconds then
					task.wait(0.5)
					sendLogData()
				end
				lastSeconds = s
			end)
		end
	end

	if gearsGui then
		gearsScrolling = gearsGui.Frame:WaitForChild("Frame", 5) and gearsGui.Frame:WaitForChild("ScrollingFrame", 5)
	end

	if effectsFrame then
		effectsFrame.ChildAdded:Connect(function(child)
			if child:IsA("Frame") then
				local timerLabel = findEventTimerLabel(child)
				if timerLabel then
					local eventName = child.Name
					local timeLeft = parseTimeToSeconds(timerLabel.Text)
					activeEvents[eventName] = timeLeft
					sendLogData()
				end
			end
		end)

		effectsFrame.ChildRemoving:Connect(function(child)
			if activeEvents[child.Name] then
				activeEvents[child.Name] = nil
				sendLogData()
			end
		end)
	end

	task.wait(1)
	sendLogData()
end

coroutine.wrap(runLogger)()

task.spawn(function()
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
end)
