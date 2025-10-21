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
