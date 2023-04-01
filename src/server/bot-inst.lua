local botInst = {}

local MOVE_PARAM_SCALING = 100

function botInst:computeNNInputs(botOppSpace)
    -- Calculate the lookvector of the bot's torso relative to that cframe, same for opponent
    local botFace = botOppSpace:VectorToObjectSpace(self.bot.PrimaryPart.CFrame.lookVector)
    botFace = botFace * Vector3.new(1, 0, 1).Unit
    local oppFace = botOppSpace:VectorToObjectSpace(self.opp.PrimaryPart.CFrame.lookVector)
    oppFace = oppFace * Vector3.new(1, 0, 1).Unit
    -- Calculate the position of the opponent relative to that cframe
    local oppPos = botOppSpace:PointToObjectSpace(self.opp.PrimaryPart.Position)
    -- The x component of this vector is by definition zero, so we only need the y and z components
    local oppY = oppPos.Y
    local oppZ = oppPos.Z

    return {
        opp_z = oppZ,
        opp_y = oppY,
        bot_face_x = botFace.X,
        bot_face_z = botFace.Z,
        opp_face_x = oppFace.X,
        opp_face_z = oppFace.Z,
        bot_tss = time() - self.tos,
        opp_tss = time() - self.oppTos,
        bot_tsj = time() - self.toj,
        opp_tsj = time() - self.oppToj,
        bot_lunge = self.lunge and 1 or 0,
        opp_lunge = self.oppLunge and 1 or 0
    }
end

function botInst:runTick()
    -- Calculate the cframe at the bot's position but facing the opponent on the xz plane
    local botOppSpace = CFrame.new(self.bot.PrimaryPart.Position, self.opp.PrimaryPart.Position - Vector3.new(0, self.opp.PrimaryPart.Position.Y, 0))

    local inputs = self:computeNNInputs(botOppSpace)
    local outputs = self.net(inputs)

    table.insert(self.input_record, inputs)
    table.insert(self.output_record, outputs)

    -- In order to avoid wrapping issues with an angular output from the model,
    -- we instead within the model encode the x and y components of a unit vector
    -- multiplied by the inverse of the standard distribution.
    -- Thus, as the magnitude of the vector approaches zero, the standard deviation
    -- approaches infinity, and the distribution approaches a uniform distribution.
    -- This lends itself well to training as reinforcing the opposing vector
    -- increases the probability of all other actions relative to the current one.
    local move_param_x, move_param_z = outputs.move_param_x * MOVE_PARAM_SCALING, outputs.move_param_z * MOVE_PARAM_SCALING
    local move_param_magnitude = math.sqrt(move_param_x^2 + move_param_z^2)
    local move_mu_theta = math.atan2(move_param_x / move_param_magnitude, move_param_z / move_param_magnitude)
    local move_sigma = 1 / move_param_magnitude
    -- print(move_mu_theta, move_sigma)
    -- Convert r to a normal distribution sample
    local move_theta = move_mu_theta + move_sigma
            -- Sample the normal distribution via the Box-Muller transform
            * math.sqrt(-2 * math.log(math.random())) * math.cos(2 * math.pi * math.random())

    local move = Vector3.new(math.sin(move_theta), 0, math.cos(move_theta))
    move = botOppSpace:VectorToWorldSpace(move)

    local mapped_swing = (outputs.pswing + 1) / 2
    local mapped_jump = (outputs.pjump + 1) / 2

    self.bot.Humanoid:Move(move)
    if math.random() < mapped_swing then
        self.bot.Sword.ActivationEvent:Fire()
    end
    if math.random() < mapped_jump then
        self.bot.Humanoid.Jump = true
    end
end

function botInst:new(bot, opp, net)
    local o = {
        input_record = {},
        output_record = {},
        bot = bot,
        opp = opp,
        net = net,
        tos = time(),
        oppTos = time(),
        toj = time(),
        oppToj = time(),
        lunge = false,
        oppLunge = false
    }

    bot.Sword.ActivationEvent.Event:Connect(function()
        o.lunge = false
        o.tos = time()
    end)

    bot.Sword.LungeEvent.Event:Connect(function()
        o.lunge = true
        o.tos = time()
    end)

    bot.Humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if bot.Humanoid.Jump then
            o.toj = time()
        end
    end)

    opp.Sword.ActivationEvent.Event:Connect(function()
        o.oppLunge = false
        o.oppTos = time()
    end)

    opp.Sword.LungeEvent.Event:Connect(function()
        o.oppLunge = true
        o.oppTos = time()
    end)

    opp.Humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if opp.Humanoid.Jump then
            o.oppToj = time()
        end
    end)

    setmetatable(o, self)
    self.__index = self
    return o
end

return botInst