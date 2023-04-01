local botInst = require(game.ServerScriptService:WaitForChild("bot-inst"))
local botNN = require(game.ServerScriptService:WaitForChild("bot-nn"))

function runFight(loc)
    local arena = game.ServerStorage:FindFirstChild("Arena"):Clone()
    arena:MoveTo(loc)
    local spawn1 = arena.PrimaryPart.CFrame:PointToWorldSpace(arena:FindFirstChild("Spawn1").Value)
    local spawn2 = arena.PrimaryPart.CFrame:PointToWorldSpace(arena:FindFirstChild("Spawn2").Value)

    local botChar1 = game.ServerStorage:FindFirstChild("Bot"):Clone()
    local botChar2 = game.ServerStorage:FindFirstChild("Bot"):Clone()
    botChar1:MoveTo(spawn1)
    botChar2:MoveTo(spawn2)

    local bot1 = botInst:new(botChar1, botChar2, botNN:new())
    local bot2 = botInst:new(botChar2, botChar1, botNN:new())
end