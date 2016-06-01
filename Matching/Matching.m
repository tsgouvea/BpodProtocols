function Matching
% Reproduction on Bpod of protocol used in the PatonLab, MATCHINGvFix

global BpodSystem
%% Task parameters
TaskParameters = BpodSystem.ProtocolSettings;
if isempty(fieldnames(TaskParameters))
    TaskParameters.GUI.pHi =  40; % 0-100% Higher reward probability
    TaskParameters.GUI.pLo =  10; % 0-100% Lower reward probability
    TaskParameters.GUI.blockLenMin = 50;
    TaskParameters.GUI.blockLenMax = 150;
    TaskParameters.GUI.iti = 0; % (s)
    TaskParameters.GUI.rewardAmount = 3;
    %TaskParameters.GUI.ChoiceDeadLine = 5;
    TaskParameters.GUI.timeOut = 5; % (s)
    %TaskParameters.GUI.rwdDelay = 0; % (s)
    TaskParameters.GUI.waitTarget = 3;% Time (s) the animal is required to wait at the center poke
    TaskParameters.GUI.waitMin = .005;
    TaskParameters.GUI.waitIncr = .020;
    TaskParameters.GUI.waitDecr = .010;
    TaskParameters.GUI = orderfields(TaskParameters.GUI);
end
BpodParameterGUI('init', TaskParameters);

%% Initializing data (trial type) vectors

BpodSystem.Data.Custom.Baited.Left = true;
BpodSystem.Data.Custom.Baited.Right = true;
BpodSystem.Data.Custom.Wait = TaskParameters.GUI.waitMin;
BpodSystem.Data.Custom.OutcomeRecord = nan;
BpodSystem.Data.Custom.TrialValid = true;
BpodSystem.Data.Custom.BlockNumber = 1;
BpodSystem.Data.Custom.LeftHi = rand>.5;
BpodSystem.Data.Custom.BlockLen = drawBlockLen(TaskParameters);
BpodSystem.Data.Custom.ChoiceLeft = NaN;
BpodSystem.Data.Custom.Rewarded = NaN;
if BpodSystem.Data.Custom.LeftHi
    BpodSystem.Data.Custom.CumpL = TaskParameters.GUI.pHi/100;
    BpodSystem.Data.Custom.CumpR = TaskParameters.GUI.pLo/100;
else
    BpodSystem.Data.Custom.CumpL = TaskParameters.GUI.pLo/100;
    BpodSystem.Data.Custom.CumpR = TaskParameters.GUI.pHi/100;
end
BpodSystem.Data.Custom = orderfields(BpodSystem.Data.Custom);

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
Matching_PlotSideOutcome(BpodSystem.GUIHandles.SideOutcomePlot,'init',BpodSystem.Data.Custom.Baited);
BpodNotebook('init');

%% Main loop
RunSession = true;
iTrial = 1;

while RunSession
    TaskParameters = BpodParameterGUI('sync', TaskParameters);
    
    sma = stateMatrix(TaskParameters);
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        SaveBpodSessionData;
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
    
    updateCustomDataFields(TaskParameters)
    iTrial = iTrial + 1;
    Matching_PlotSideOutcome(BpodSystem.GUIHandles.SideOutcomePlot,'update',iTrial);
end
end

function sma = stateMatrix(TaskParameters)
global BpodSystem
ValveTimes  = GetValveTimes(TaskParameters.GUI.rewardAmount, [1 3]);
LeftValveTime = ValveTimes(1);
RightValveTime = ValveTimes(2);
clear ValveTimes

if BpodSystem.Data.Custom.Baited.Left(end)
    LeftPokeAction = 'rewarded_Lin';
else
    LeftPokeAction = 'unrewarded_Lin';
end
if BpodSystem.Data.Custom.Baited.Right(end)
    RightPokeAction = 'rewarded_Rin';
else
    RightPokeAction = 'unrewarded_Rin';
end

sma = NewStateMatrix();
sma = AddState(sma, 'Name', 'state_0',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'wait_Cin'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'wait_Cin',...
    'Timer', 0,...
    'StateChangeConditions', {'Port2In', 'stay_Cin'},...
    'OutputActions', {'PWM2',255});
sma = AddState(sma, 'Name', 'wait_Sin',...
    'Timer',0,...
    'StateChangeConditions', {'Port1In',LeftPokeAction,'Port3In',RightPokeAction},...
    'OutputActions',{'PWM1',255,'PWM3',255});
sma = AddState(sma, 'Name', 'rewarded_Lin',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','water_L'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'rewarded_Rin',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','water_R'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'unrewarded_Lin',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'unrewarded_Rin',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'water_L',...
    'Timer', LeftValveTime,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {'ValveState', 1});
sma = AddState(sma, 'Name', 'water_R',...
    'Timer', RightValveTime,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {'ValveState', 4});
sma = AddState(sma, 'Name', 'ITI',...
    'Timer',TaskParameters.GUI.iti,...
    'StateChangeConditions',{'Tup','exit'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'stay_Cin',...
    'Timer', BpodSystem.Data.Custom.Wait(end),...
    'StateChangeConditions', {'Port2Out','broke_fixation','Tup', 'wait_Sin'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'broke_fixation',...
    'Timer',0,...
    'StateChangeConditions',{'Tup','time_out'},...
    'OutputActions',{}); %figure out how to add a noise tone
sma = AddState(sma, 'Name', 'time_out',...
    'Timer',TaskParameters.GUI.timeOut,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',{});
%     sma = AddState(sma, 'Name', 'state_name',...
%         'Timer', 0,...
%         'StateChangeConditions', {},...
%         'OutputActions', {});
end

function updateCustomDataFields(TaskParameters)
global BpodSystem
%% OutcomeRecord
temp = BpodSystem.Data.RawData.OriginalStateData{end};
temp =  temp(temp>=4&temp<=7|temp==12);
if ~isempty(temp)
    BpodSystem.Data.Custom.OutcomeRecord(end) = temp;
end
clear temp
if BpodSystem.Data.Custom.OutcomeRecord(end) == 4 || BpodSystem.Data.Custom.OutcomeRecord(end) == 6
    BpodSystem.Data.Custom.ChoiceLeft(end) = 1;
elseif BpodSystem.Data.Custom.OutcomeRecord(end) == 5 || BpodSystem.Data.Custom.OutcomeRecord(end) == 7
    BpodSystem.Data.Custom.ChoiceLeft(end) = 0;
end
if BpodSystem.Data.Custom.OutcomeRecord(end) == 4 || BpodSystem.Data.Custom.OutcomeRecord(end) == 5
    BpodSystem.Data.Custom.Rewarded(end) = 1;
elseif BpodSystem.Data.Custom.OutcomeRecord(end) == 6 || BpodSystem.Data.Custom.OutcomeRecord(end) == 7
    BpodSystem.Data.Custom.Rewarded(end) = 0;
end
if BpodSystem.Data.Custom.OutcomeRecord(end)==12
    BpodSystem.Data.Custom.TrialValid(end) = false;
end
BpodSystem.Data.Custom.OutcomeRecord(end+1) = nan;
BpodSystem.Data.Custom.ChoiceLeft(end+1) = NaN;
BpodSystem.Data.Custom.Rewarded(end+1) = NaN;
BpodSystem.Data.Custom.TrialValid(end+1) = true;

%% Waiting (fixation) time
if BpodSystem.Data.Custom.TrialValid(end-1)
    BpodSystem.Data.Custom.Wait(end+1) = BpodSystem.Data.Custom.Wait(end)+TaskParameters.GUI.waitIncr;
    BpodSystem.Data.Custom.Wait(end) = min(BpodSystem.Data.Custom.Wait(end),TaskParameters.GUI.waitTarget);
else
    BpodSystem.Data.Custom.Wait(end+1) = BpodSystem.Data.Custom.Wait(end)-TaskParameters.GUI.waitDecr;
    BpodSystem.Data.Custom.Wait(end) = max(BpodSystem.Data.Custom.Wait(end),0);
end

%% Block count
nTrialsThisBlock = sum(BpodSystem.Data.Custom.BlockNumber == BpodSystem.Data.Custom.BlockNumber(end));
if nTrialsThisBlock >= TaskParameters.GUI.blockLenMax
    % If current block len exceeds new max block size, will transition
    BpodSystem.Data.Custom.BlockLen(end) = nTrialsThisBlock;
end
if nTrialsThisBlock >= BpodSystem.Data.Custom.BlockLen(end)
    BpodSystem.Data.Custom.BlockNumber(end+1) = BpodSystem.Data.Custom.BlockNumber(end)+1;
    BpodSystem.Data.Custom.BlockLen(end+1) = drawBlockLen(TaskParameters);
    BpodSystem.Data.Custom.LeftHi(end+1) = ~BpodSystem.Data.Custom.LeftHi(end);
else
    BpodSystem.Data.Custom.BlockNumber(end+1) = BpodSystem.Data.Custom.BlockNumber(end);
    BpodSystem.Data.Custom.LeftHi(end+1) = BpodSystem.Data.Custom.LeftHi(end);
end
%display(BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.RawData.OriginalStateData{end}))

%% Baiting
if BpodSystem.Data.Custom.LeftHi(end)
    pL = TaskParameters.GUI.pHi/100;
    pR = TaskParameters.GUI.pLo/100;
else
    pL = TaskParameters.GUI.pLo/100;
    pR = TaskParameters.GUI.pHi/100;
end
if BpodSystem.Data.Custom.ChoiceLeft(end-1) == 1
    BpodSystem.Data.Custom.CumpL(end+1) = pL;
    BpodSystem.Data.Custom.CumpR(end+1) = BpodSystem.Data.Custom.CumpR(end) + (1-BpodSystem.Data.Custom.CumpR(end))*pR;
elseif BpodSystem.Data.Custom.ChoiceLeft(end-1) == 0
    BpodSystem.Data.Custom.CumpL(end+1) = BpodSystem.Data.Custom.CumpL(end) + (1-BpodSystem.Data.Custom.CumpL(end))*pL;
    BpodSystem.Data.Custom.CumpR(end+1) = pR;
else
    BpodSystem.Data.Custom.CumpL(end+1) = BpodSystem.Data.Custom.CumpL(end);
    BpodSystem.Data.Custom.CumpR(end+1) = BpodSystem.Data.Custom.CumpR(end);
end
if BpodSystem.Data.Custom.TrialValid(end-1) &&...
        (~BpodSystem.Data.Custom.Baited.Left(end) || BpodSystem.Data.Custom.OutcomeRecord(end-1)==4)
    BpodSystem.Data.Custom.Baited.Left(end+1) = rand<pL;
else
    BpodSystem.Data.Custom.Baited.Left(end+1) = BpodSystem.Data.Custom.Baited.Left(end);
end
if BpodSystem.Data.Custom.TrialValid(end-1) &&...
        (~BpodSystem.Data.Custom.Baited.Right(end) || BpodSystem.Data.Custom.OutcomeRecord(end-1)==5)
    BpodSystem.Data.Custom.Baited.Right(end+1) = rand<pR;
else
    BpodSystem.Data.Custom.Baited.Right(end+1) = BpodSystem.Data.Custom.Baited.Right(end);
end
end

function BlockLen = drawBlockLen(TaskParameters)
BlockLen = 0;
while BlockLen < TaskParameters.GUI.blockLenMin || BlockLen > TaskParameters.GUI.blockLenMax
    BlockLen = ceil(exprnd(sqrt(TaskParameters.GUI.blockLenMin*TaskParameters.GUI.blockLenMax)));
end
end