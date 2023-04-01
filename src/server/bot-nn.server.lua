local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Package = ReplicatedStorage.NNLibrary
local FeedforwardNetwork = require(Package.NeuralNetwork.FeedforwardNetwork)
local Momentum = require(Package.Optimizer.Momentum)
local FightEngine = require(ServerScriptService["bot-fight"])

local setting = {
    --We will set the optimizer to Momentum because it seems to work the best for this experiment.
    Optimizer = Momentum.new();
    --We want to accept negative inputs so a LeakyReLU will do.
    HiddenActivationName = "LeakyReLU";
    --We use a Tanh activation function as we need
    --negative outputs on the movement parameters, and it can neatly
    --be mapped to [0, 1] for the swing and jump parameters.
    OutputActivationName = "Tanh";
    LearningRate = 0.1;
}

local actor = FeedforwardNetwork.new(
	{ "opp_z", "opp_y",
		"bot_face_x", "bot_face_z", "opp_face_x", "opp_face_z",
		"bot_tss", "opp_tss",
		"bot_tsj", "opp_tsj",
		"bot_lunge", "opp_lunge" },
	2,
	10,
	{"move_param_x", "move_param_z", "pswing", "pjump"},
	setting)

actor:RandomizeWeights()

local critic = FeedforwardNetwork.new(
	{ "opp_z", "opp_y",
		"bot_face_x", "bot_face_z", "opp_face_x", "opp_face_z",
		"bot_tss", "opp_tss",
		"bot_tsj", "opp_tsj",
		"bot_lunge", "opp_lunge" },
	2,
	10,
	{"state_value"},
	setting)

critic:RandomizeWeights()

-- Outline:
-- 1. Run several fights
-- 2. Have the critic analyze each fight
-- 3. Train actor with critic's analysis
-- 4. Train critic with final result of fight
-- 5. Repeat

local actorBackProp = actor:GetBackPropagator()
local criticBackProp = critic:GetBackPropagator()

function calculateReward(healthDiff, interbotDistance, won)
	local reward = healthDiff - ((won or healthDiff < 0) and 0 or interbotDistance)
	return reward
end

function trainActor(reward, inputs, outputs)
	local eval = critic(inputs[1]).state_value
	for i = 1, #inputs - 1 do
		local nextEval = critic(inputs[i + 1]).state_value
		local output = outputs[i]
		local correctedOutput = {}
		local reinforce = nextEval - eval > 0 and 1 or -1
		for k, v in pairs(output) do
			correctedOutput[k] = v * reinforce
 		end
		actorBackProp:CalculateCost(inputs[i], correctedOutput)
		actorBackProp:Learn()
	end
	for i = 1, #inputs - 1 do
		criticBackProp:CalculateCost(inputs[i], {state_value = reward})
		criticBackProp:Learn()
	end
end

local TRAINING_ITERATIONS = 100
local EARLY_FIGHTS_PER_ITERATION = 100
local LATE_FIGHTS_PER_ITERATION = 10
local EARLY_ITERATIONS = 30
local EARLY_TIMEOUT = 10
local LATE_TIMEOUT = 30

for i = 1, TRAINING_ITERATIONS do
	local fightsPerIteration = i < EARLY_ITERATIONS and EARLY_FIGHTS_PER_ITERATION or LATE_FIGHTS_PER_ITERATION
	print("Training iteration " .. i .. " of " .. TRAINING_ITERATIONS .. " (" .. fightsPerIteration .. " fights)...")
	local timeout = i < EARLY_ITERATIONS and EARLY_TIMEOUT or LATE_TIMEOUT
    local results = FightEngine(fightsPerIteration, actor, timeout)
	local rewards = {}

	for j, result in ipairs(results) do
		print("Training on fight " .. j .. " of " .. #results .. "...")
		local bot1Health = result[1]
		local bot2Health = result[2]
		local interbotDistance = result[3]
		local bot1 = result[4]
		local bot2 = result[5]

		local reward1 = calculateReward(bot1Health - bot2Health, interbotDistance, bot2Health <= 0)
		local reward2 = calculateReward(bot2Health - bot1Health, interbotDistance, bot1Health <= 0)
		table.insert(rewards, reward1)
		table.insert(rewards, reward2)
		trainActor(reward1, bot1.input_record, bot1.output_record)
		trainActor(reward2, bot2.input_record, bot2.output_record)
		task.wait()
	end

	local totalReward = 0
	for _, reward in ipairs(rewards) do
		totalReward = totalReward + reward
	end
	local meanReward = totalReward / #rewards
	local totalSquaredError = 0
	for _, reward in ipairs(rewards) do
		totalSquaredError = totalSquaredError + (reward - meanReward) ^ 2
	end
	local stdDev = math.sqrt(totalSquaredError / #rewards)
	print("Mean reward: " .. meanReward .. ", standard deviation: " .. stdDev)
end
