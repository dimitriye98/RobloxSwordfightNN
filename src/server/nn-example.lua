--Whenever using math.random() for small experiments like this, you should set a random seed
--in order to not get the same results every time.
math.randomseed(os.clock()+os.time())

--For this experiment, I placed the library package in ReplicatedStorage.
local Package = game:GetService("ReplicatedStorage").NNLibrary
local FeedforwardNetwork = require(Package.NeuralNetwork.FeedforwardNetwork)
local Momentum = require(Package.Optimizer.Momentum)

--If the training/testing is intensive, we will want to setup automatic wait() statements
--in order to avoid a timeout. This can be done with os.clock().
local clock = os.clock()


----------------<<MAIN SETTINGS>>---------------------------------------------------------------


--This setting dictionary contains whatever customizations you want on your neural network.
--Each setting has it's own default and is completely optional.
local setting = {
    --We will set the optimizer to Momentum because it seems to work the best for this experiment.
    Optimizer = Momentum.new();
    --We want to accept negative inputs so a LeakyReLU will do.
    HiddenActivationName = "LeakyReLU";
    --We use a Tanh activation function as we need
    --negative outputs on the movement parameters, and it can neatly
    --be mapped to [0, 1] for the swing and jump parameters.
    OutputActivationName = "Tanh";
    LearningRate = 0.3;
}
--Number of generations for the training.
local generations = 200000
--Number of generations that need to pass before we backpropagate the network.
local numOfGenerationsBeforeLearning = 1


----------------<<END OF MAIN SETTINGS>>---------------------------------------------------------------


--This is the statement that creates the network. Only the most basic settings are used here.
--The rest are in the 'setting' dictionary. In this case, the network has 2 inputs 'x' and 'y',
--2 layers with 2 nodes each, and 1 output 'out'.
local net = FeedforwardNetwork.new(
	{ "opp_z", "opp_y",
		"bot_face_x", "bot_face_z", "opp_face_x", "opp_face_z",
		"bot_tss", "opp_tss",
		"bot_tsj", "opp_tsj",
		"bot_lunge", "opp_lunge" },
	2,
	10,
	{"move_param_x", "move_param_z", "pswing", "pjump"},
	setting)
--To backpropagate, you need to get the network's backpropagator.
local backProp = net:GetBackPropagator()

--This function determines what mathematical function we want to test the network with
--and if the given coordinates are above (1) or below (0) the function.
--For this experiment, a simple cubic will do.
function isAboveFunction(x,y)
    if x^3 + 2*x^2 < y then
        return 0
    end
    return 1
end

for generation = 1, generations do
    --Both input and outputs are dictionaries where the key (index) is the name of the input/output,
    --while the value is it's associated value. This is why 'coords' has x and y, while 'correctAnswer'
    --has out.
    local coords = {x = math.random(-400,400)/100, y = math.random(-400,400)/100}

    local correctAnswer = {out = isAboveFunction(coords.x,coords.y)}
    --Here, we calculate the cost of the network with the given inputs and correct outputs. Basically,
    --we calculate how wrong/right the network currently is.
    backProp:CalculateCost(coords,correctAnswer)
    --The automated wait() and print() statements that give the computer a break every 0.1 seconds and
    --give us an update as to how much of training is left.
    if os.clock()-clock >= 0.1 then
        clock = os.clock()
        wait()
        print(generation/generations*(100).."% trained. Cost: "..backProp:GetTotalCost())
    end
    --If time is of the essence, you can have the backpropagator save the costs of multiple generations
    --before actually training the network. This results in less effective training, but is way faster.
    if generation % numOfGenerationsBeforeLearning == 0 then
        backProp:Learn()
    end
end
--Total number of test runs.
local totalRuns = 0
--The number of runs that were deemed correct.
local wins = 0

--Lua is dumb and counts -400 to 400 as 801 runs instead of 800
for x = -400, 399 do
    for y = -400, 399 do

        local coords = {x = x/100, y = y/100}
        --Now, you can get the output of a network by just calling it like a function.
        local output = net(coords)

        local correctAnswer = isAboveFunction(coords.x,coords.y)
        --I will call it correct if the difference between the correct answer and the network's output
        --is less than or equal to 0.3.
        if math.abs(output.out - correctAnswer) <= 0.3 then
            wins += 1
        end
        totalRuns += 1
    end

    if os.clock()-clock >= 0.1 then
        clock = os.clock()
        wait()
        print("Testing... "..(x+400)/(8).."%")
    end
end

print(wins/totalRuns*(100).."% correct!")