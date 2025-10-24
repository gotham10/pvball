local HttpService = game:GetService("HttpService")
local workspace = game.Workspace

local FIREBASE_BASE_URL = "https://pvb-data-default-rtdb.firebaseio.com/"
local NODE_PATH = "attributes.json"

local ATTRIBUTES_TO_WATCH = {
	ActiveEvents = true,
	AdminLuck = true,
	ServerLuck = true
}

local function sendAttributeData()
	local attributeValues = {
		ActiveEvents = workspace:GetAttribute("ActiveEvents"),
		AdminLuck = workspace:GetAttribute("AdminLuck"),
		ServerLuck = workspace:GetAttribute("ServerLuck")
	}

	local encodeSuccess, encodedJson = pcall(HttpService.JSONEncode, HttpService, attributeValues)
	
	if not encodeSuccess then
		warn("Failed to encode attributes to JSON:", encodedJson)
		return
	end

	local fullUrl = FIREBASE_BASE_URL .. NODE_PATH

	local requestData = {
		Url = fullUrl,
		Method = "PUT",
		Headers = {["Content-Type"] = "application/json"},
		Body = encodedJson
	}

	local requestSuccess, errorMessage = pcall(request, requestData)

	if not requestSuccess then
		warn("HTTP request to Firebase failed:", errorMessage)
	end
end

workspace.AttributeChanged:Connect(function(attributeName)
	if ATTRIBUTES_TO_WATCH[attributeName] then
		task.spawn(sendAttributeData)
	end
end)

task.spawn(sendAttributeData)
