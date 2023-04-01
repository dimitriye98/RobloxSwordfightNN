local botInst = require(game.ServerScriptService:WaitForChild("bot-inst"))

local FIGHT_HEIGHT_DIFF = 50

function initFight(loc, net)
    local arena = game.ServerStorage:FindFirstChild("Arena"):Clone()
    arena.Parent = game.Workspace
    -- print(loc)
    arena:MoveTo(loc)
    local spawn1 = arena.PrimaryPart.CFrame:PointToWorldSpace(arena:FindFirstChild("Spawn1").Value)
    local spawn2 = arena.PrimaryPart.CFrame:PointToWorldSpace(arena:FindFirstChild("Spawn2").Value)

    local botChar1 = game.ServerStorage:FindFirstChild("Bot"):Clone()
    local botChar2 = game.ServerStorage:FindFirstChild("Bot"):Clone()
    botChar1.Parent = game.Workspace
    botChar2.Parent = game.Workspace
    botChar1:MoveTo(spawn1)
    botChar2:MoveTo(spawn2)

    local bot1 = botInst:new(botChar1, botChar2, net)
    local bot2 = botInst:new(botChar2, botChar1, net)

    return arena, bot1, bot2
end

function cleanupFight(arena, bot1, bot2)
    bot1.bot:Destroy()
    bot2.bot:Destroy()
    arena:Destroy()
end

function runFight(loc, net, timeout)
    local arena, bot1, bot2 = initFight(loc, net)

    local fightGoing = true
    bot1.bot.Humanoid.Died:Connect(function()
        fightGoing = false
    end)
    bot2.bot.Humanoid.Died:Connect(function()
        fightGoing = false
    end)
    task.delay(timeout, function()
        fightGoing = false
    end)

    while fightGoing do
        bot1:runTick()
        bot2:runTick()
        task.wait()
    end

    local bot1Health = bot1.bot.Humanoid.Health
    local bot2Health = bot2.bot.Humanoid.Health
    local interbotDistance = (bot1.bot.PrimaryPart.Position - bot2.bot.PrimaryPart.Position).magnitude

    cleanupFight(arena, bot1, bot2)

    return bot1Health, bot2Health, interbotDistance, bot1, bot2
end

function runNFights(n, net, timeout)
    local fightResults = {}
    for i = 1, n do
        task.spawn(function()
            local results = {runFight(Vector3.new(0, i * FIGHT_HEIGHT_DIFF, 0), net, timeout)}
            fightResults[i] = results
        end)
    end
    while #fightResults < n do
        task.wait()
    end
    return fightResults
end

return runNFights