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
		gearsScrolling = gearsGui:WaitForChild("Frame", 5) and gearsGui.Frame:WaitForChild("ScrollingFrame", 5)
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
