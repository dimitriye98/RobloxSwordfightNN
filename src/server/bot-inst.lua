local botInst = {}

function botInst:computeNNInputs(botOppSpace)
    -- Calculate the lookvector of the bot's torso relative to that cframe, same for opponent
    local botFace = botOppSpace:VectorToObjectSpace(self.bot.Torso.CFrame.lookVector)
    botFace = botFace * Vector3.new(1, 0, 1).Unit
    local oppFace = botOppSpace:VectorToObjectSpace(self.opp.Torso.CFrame.lookVector)
    oppFace = oppFace * Vector3.new(1, 0, 1).Unit
    -- Calculate the position of the opponent relative to that cframe
    local oppPos = botOppSpace:PointToObjectSpace(self.opp.Position)
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
    local botOppSpace = CFrame.new(self.bot.Position, self.opp.Position - Vector3.new(0, self.opp.Position.Y, 0))

    local inputs = self:computeNNInputs(botOppSpace)
    local outputs = self.net(inputs)

    table.insert(self.input_record, inputs)
    table.insert(self.output_record, outputs)

    local move_sigma = math.sqrt(outputs.move_param_x^2 + outputs.move_param_z^2)
    local move_mu_theta = math.atan2(outputs.move_param_x / move_sigma, outputs.move_param_z / move_sigma)
    -- Convert r to a normal distribution sample
    local move_theta = move_mu_theta + move_sigma
            * math.sqrt(-2 * math.log(math.random())) * math.cos(2 * math.pi * math.random())

    local move = Vector3.new(math.sin(move_theta), 0, math.cos(move_theta))

    local mapped_swing = (outputs.swing + 1) / 2
    local mapped_jump = (outputs.jump + 1) / 2

    self.bot.Humanoid:Move(move)
    if math.random() < mapped_swing then
        self.bot.Humanoid.Sword.ActivationEvent:Fire()
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
    setmetatable(o, self)
    self.__index = self
    return o
end

return botInst