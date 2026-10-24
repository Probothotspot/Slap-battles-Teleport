-- NPC GeneralHit v1.0.2 | Probothotspot
-- One global 1..100 calls/s budget, round-robin living Humanoid NPCs.
-- FireServer returning does not acknowledge damage or bypass server validation.
local Core={}
local REMOTE_PATH='ReplicatedStorage.Remotes.GeneralHit'
function Core.new(c)
    local clock=c.Clock or os.clock
    local self={Enabled=false,Destroyed=false,Rate=10,Sent=0,Failures=0,Cursor=0,NextCall=0,
        List={},Index={},Pending=setmetatable({},{__mode='k'}),Stack={{Node=c.World}},Ready=false,
        RemotePath=REMOTE_PATH,Scanned=0,NextSweep=0,Sending=false,Times={},StatusCode='off',Message='OFF — готов к запуску'}
    local function note(message)
        if self.Message==message then return end
        self.Message=message;if c.Log then c.Log(message) end
    end
    function self:isNPC(humanoid)
        local model=humanoid.Parent
        if not model or not model:IsA('Model') or not model:IsDescendantOf(c.World) then return false end
        if c.Players:GetPlayerFromCharacter(model) then return false end
        for _,player in ipairs(c.Players:GetPlayers()) do
            if player.Character and (model==player.Character or model:IsDescendantOf(player.Character)) then return false end
        end
        return true
    end
    function self:add(object)
        if self.Destroyed or not object:IsA('Humanoid') or self.Index[object] or not self:isNPC(object) then return end
        self.List[#self.List+1]=object;self.Index[object]=#self.List
    end
    function self:remove(object)
        self.Pending[object]=nil
        local i=self.Index[object];if not i then return end
        local last=table.remove(self.List);self.Index[object]=nil
        if i<=#self.List then self.List[i]=last;self.Index[last]=i end
        if self.Cursor>=i then self.Cursor=math.max(0,self.Cursor-1) end
    end
    function self:added(object)
        if not self.Destroyed and object:IsA('Humanoid') then self.Pending[object]=true end
    end
    function self:indexStep()
        if self.Destroyed then return end
        local started=clock();local steps=0;local pending=0
        for object in pairs(self.Pending) do
            if pending>=32 or clock()-started>=.002 then break end
            self.Pending[object]=nil;self:add(object);pending=pending+1
        end
        if #self.Stack==0 and started>=self.NextSweep then self.Stack={{Node=c.World}};self.NextSweep=math.huge end
        local hadWork=#self.Stack>0
        while #self.Stack>0 and steps<512 and clock()-started<.002 do
            steps=steps+1
            local frame=self.Stack[#self.Stack]
            if not frame.Children then
                frame.Children=frame.Node:GetChildren();frame.Position=1
            elseif frame.Position>#frame.Children then table.remove(self.Stack)
            else
                local object=frame.Children[frame.Position];frame.Position=frame.Position+1
                self.Scanned=self.Scanned+1
                if object:IsDescendantOf(c.World) then
                    self:add(object);self.Stack[#self.Stack+1]={Node=object}
                end
            end
        end
        if hadWork and #self.Stack==0 then self.Ready=true;self.NextSweep=clock()+5 end
    end
    function self:part(humanoid)
        if not self:isNPC(humanoid) or humanoid.Health<=0 then return nil end
        local model=humanoid.Parent
        for _,name in ipairs({'Right Arm','RightHand','RightLowerArm','RightUpperArm','HumanoidRootPart','Torso','UpperTorso','Head'}) do
            local part=model:FindFirstChild(name)
            if part and part:IsA('BasePart') and part:IsDescendantOf(c.World) then return part end
        end
    end
    function self:nextTarget()
        for _=1,math.min(#self.List,128) do
            if #self.List==0 then return nil end
            self.Cursor=self.Cursor%#self.List+1
            local h=self.List[self.Cursor]
            if not h:IsDescendantOf(c.World) or not self:isNPC(h) then
                self:remove(h)
            else
                local part=self:part(h)
                if part then return part,h.Parent.Name,h end
            end
        end
    end
    function self:setRate(value)
        if type(value)~='number' or value~=value or value%1~=0 or value<1 or value>100 then return false end
        self.Rate=value;self.NextCall=clock()+1/value
        return true
    end
    function self:setEnabled(value)
        if self.Destroyed then return end
        self.Enabled=value==true;self.NextCall=clock()
        self.StatusCode=self.Enabled and 'finding_npc' or 'off'
        note(self.Enabled and 'ON — поиск живых NPC' or 'OFF — остановлено')
    end
    function self:actualRate()
        local cutoff=clock()-1;local kept={}
        for _,time in ipairs(self.Times) do if time>cutoff then kept[#kept+1]=time end end
        self.Times=kept;return #kept
    end
    function self:step()
        if self.Destroyed or self.Sending then return end
        self:indexStep()
        if not self.Enabled then return end
        local now=clock();local count=0
        -- At most two calls/frame; dropped frames never produce an unbounded catch-up burst.
        while self.Enabled and not self.Destroyed and now>=self.NextCall and count<2 do
            local part,name,humanoid=self:nextTarget()
            if not part then
                self.StatusCode=self.Ready and 'no_npc' or 'indexing'
                self.NextCall=now+.1;note(self.Ready and 'Нет живых NPC с доступной частью тела' or 'Поиск NPC в фоне…');break
            end
            self.NextCall=self.NextCall+1/self.Rate
            if now-self.NextCall>.1 then self.NextCall=now+1/self.Rate end
            self.Sending=true
            local stage='target'
            local ok,result=pcall(function()
                -- Fresh validation immediately before dispatch; no saved Skeleton/arm reference.
                assert(self:part(humanoid)==part,'Цель изменилась')
                -- Same receiver and one-argument packet as ReplicatedStorage.Remotes.GeneralHit:FireServer(...).
                -- No class-name gate or wait loop: try the actual call and surface its error.
                stage='remote'
                local remote=c.Storage.Remotes.GeneralHit
                assert(remote,REMOTE_PATH..' отсутствует')
                stage='fireserver'
                local args={[1]=part}
                if c.Fire then return c.Fire(remote,part) end
                return remote:FireServer(table.unpack(args))
            end)
            self.Sending=false
            if self.Destroyed then return end
            if ok and result~=false then
                self.Sent=self.Sent+1;self.LastTarget=name;self.LastError=nil
                if self.Enabled then self.StatusCode='sent' end
                self.Times[#self.Times+1]=now
                if #self.Times>200 then table.remove(self.Times,1) end
                if self.Enabled then self.Message='ON — '..tostring(name)..' | вызов отправлен' end
            else
                self.Failures=self.Failures+1;self.LastError=tostring(result)
                self.StatusCode=stage=='remote' and 'remote_missing' or stage=='target' and 'target_changed' or 'invoke_error'
                self.NextCall=now+(stage=='remote' and .25 or .5)
                note((stage=='remote' and REMOTE_PATH..': ' or stage=='target' and 'NPC: ' or 'GeneralHit:FireServer: ')..self.LastError);break
            end
            count=count+1
        end
    end
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true;self.Enabled=false;self.List={};self.Index={};self.Pending={};self.Stack={};self.Times={}
    end
    return self
end
-- BEGIN ROBLOX CLIENT
local Players=game:GetService('Players')
local player=Players.LocalPlayer;assert(player,'NPC GeneralHit: требуется клиент')
local env=_G
if type(getgenv)=='function' then local ok,v=pcall(getgenv);if ok and type(v)=='table' then env=v end end
local KEY='ProbothotspotNPCGeneralHit'
local previous=env[KEY]
if type(previous)=='table' and type(previous.Destroy)=='function' then previous:Destroy() end
local playerGui=player:WaitForChild('PlayerGui',10);assert(playerGui,'NPC GeneralHit: PlayerGui не готов')
local Tween=game:GetService('TweenService');local Input=game:GetService('UserInputService')
local connections,tweens,channels={},{},{}
local handle={Version='1.0.2',JobId=game.JobId,Destroyed=false}
env[KEY]=handle
local gui,engine
local function connect(signal,fn)local connection=signal:Connect(fn);connections[#connections+1]=connection;return connection end
function handle:Destroy()
    if self.Destroyed then return end;self.Destroyed=true
    if engine then engine:Destroy() end
    for _,connection in ipairs(connections) do connection:Disconnect() end
    for _,tween in ipairs(tweens) do pcall(function()tween:Cancel()end) end
    if gui then gui:Destroy() end
    if env[KEY]==self then env[KEY]=nil end
end
local function make(class,props,parent)
    local object=Instance.new(class)
    for key,value in pairs(props) do object[key]=value end
    object.Parent=parent;return object
end
local function round(object,radius)make('UICorner',{CornerRadius=UDim.new(0,radius or 10)},object)end
local function animate(object,key,props,seconds)
    channels[object]=channels[object] or {}
    local old=channels[object][key];if old then old:Cancel() end
    local tween=Tween:Create(object,TweenInfo.new(seconds or .15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
    channels[object][key]=tween;tweens[#tweens+1]=tween;tween:Play()
    -- Bound retained animation handles across frequent interactions.
    if #tweens>96 then
        local active={}
        for _,byKey in pairs(channels) do for _,current in pairs(byKey) do active[#active+1]=current end end
        tweens=active
    end
end
local ok,why=pcall(function()
    gui=make('ScreenGui',{Name='NPCGeneralHitGUI',ResetOnSpawn=false,DisplayOrder=1200,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
    handle.Gui=gui
    local safe=make('Frame',{Name='SafeArea',Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
    local window=make('CanvasGroup',{Name='Window',Size=UDim2.fromOffset(340,366),Position=UDim2.new(.5,-170,.5,-183),
        BackgroundColor3=Color3.fromRGB(137,75,194),BorderSizePixel=0,GroupTransparency=1,ClipsDescendants=true,Active=true},safe)
    round(window,15)
    local gradient=make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(106,48,161)),
        ColorSequenceKeypoint.new(.5,Color3.fromRGB(173,95,220)),ColorSequenceKeypoint.new(1,Color3.fromRGB(112,58,180))}),Rotation=15},window)
    make('UIStroke',{Color=Color3.fromRGB(219,175,255),Thickness=1.2,Transparency=.3},window)
    local scale=make('UIScale',{Scale=1},window)
    local function label(name,text,x,y,w,h,size,parent)
        return make('TextLabel',{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,
            TextColor3=Color3.fromRGB(250,239,255),Font=Enum.Font.Gotham,TextSize=size or 12,TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true},parent)
    end
    local function button(name,text,x,y,w,h,parent)
        local base=Color3.fromRGB(177,105,226)
        local b=make('TextButton',{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            BackgroundColor3=base,BorderSizePixel=0,AutoButtonColor=false,TextColor3=Color3.fromRGB(255,246,255),Font=Enum.Font.GothamBold,TextSize=13},parent)
        round(b,9)
        connect(b.MouseEnter,function()if not handle.Destroyed then animate(b,'hover',{BackgroundColor3=Color3.fromRGB(199,137,242)},.12)end end)
        connect(b.MouseLeave,function()if not handle.Destroyed then animate(b,'hover',{BackgroundColor3=base},.12)end end)
        return b
    end
    local header=make('Frame',{Name='Header',Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,Active=true},window)
    local title=label('Title','NPC GeneralHit 1.0.2',15,0,230,44,16,header);title.Font=Enum.Font.GothamBold
    local collapse=button('Collapse','−',260,8,28,28,header)
    local close=button('Close','×',295,8,28,28,header)
    local body=make('Frame',{Name='Body',Position=UDim2.fromOffset(0,44),Size=UDim2.new(1,0,1,-44),BackgroundTransparency=1},window)
    label('RateLabel','Вызовов в секунду — всего для всех NPC',15,4,310,25,12,body)
    local minus=button('Minus','−',15,35,42,36,body)
    local rateBox=make('TextBox',{Name='Rate',Text='10',PlaceholderText='1–100',Position=UDim2.fromOffset(64,35),Size=UDim2.fromOffset(212,36),
        ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(104,49,155),BorderSizePixel=0,TextColor3=Color3.fromRGB(255,244,255),
        Font=Enum.Font.GothamBold,TextSize=17},body);round(rateBox,9)
    local plus=button('Plus','+',283,35,42,36,body)
    local toggle=button('Toggle','OFF',15,81,310,38,body)
    local state=label('State','OFF — готов к запуску',15,127,310,35,12,body)
    local stats=label('Stats','NPC в индексе: 0 | Отправлено: 0',15,164,310,22,11,body)
    label('Note','Вызов GeneralHit не подтверждает урон. Игроки исключены.',15,190,310,29,10,body)
    local logs=make('ScrollingFrame',{Name='Logs',Position=UDim2.fromOffset(15,226),Size=UDim2.fromOffset(310,65),
        BackgroundColor3=Color3.fromRGB(102,49,151),BackgroundTransparency=.12,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,65)},body)
    round(logs,8)
    local logText=label('LogText','',8,5,292,55,10,logs);logText.TextYAlignment=Enum.TextYAlignment.Top
    label('Credit','By: Probothotspot',15,297,310,15,10,body)
    local lines={}
    local function log(message)
        lines[#lines+1]=tostring(message);if #lines>8 then table.remove(lines,1) end
        logText.Text=table.concat(lines,'\n')
        local wrapped=0
        for _,line in ipairs(lines) do
            for segment in (line..'\n'):gmatch('(.-)\n') do
                local length=utf8 and utf8.len(segment) or #segment
                wrapped=wrapped+math.max(1,math.ceil((length or #segment)/42))
            end
        end
        local h=math.max(55,wrapped*14)
        logText.Size=UDim2.fromOffset(292,h);logs.CanvasSize=UDim2.fromOffset(0,h+10)
        logs.CanvasPosition=Vector2.new(0,math.max(0,h-55))
    end
    engine=Core.new({World=workspace,Players=Players,Storage=game:GetService('ReplicatedStorage'),Log=log})
    handle.Engine=engine
    local collapsed=false;local dragging,dragPoint,dragOrigin
    local function fit()
        local area=safe.AbsoluteSize;if area.X<=0 or area.Y<=0 then return end
        scale.Scale=math.max(.1,math.min(1,(area.X-16)/340,(area.Y-16)/(collapsed and 44 or 366)))
        local x=window.Position.X.Scale*area.X+window.Position.X.Offset
        local y=window.Position.Y.Scale*area.Y+window.Position.Y.Offset
        window.Position=UDim2.fromOffset(math.clamp(x,0,math.max(0,area.X-340*scale.Scale)),
            math.clamp(y,0,math.max(0,area.Y-(collapsed and 44 or 366)*scale.Scale)))
    end
    connect(safe:GetPropertyChangedSignal('AbsoluteSize'),fit);fit()
    local function applyRate(value)
        if not engine:setRate(value) then log('Введи целое число от 1 до 100') end
        rateBox.Text=tostring(engine.Rate)
    end
    connect(rateBox.FocusLost,function()applyRate(tonumber(rateBox.Text:match('^%s*(.-)%s*$')))end)
    connect(minus.Activated,function()applyRate(math.max(1,engine.Rate-1))end)
    connect(plus.Activated,function()applyRate(math.min(100,engine.Rate+1))end)
    connect(toggle.Activated,function()
        engine:setEnabled(not engine.Enabled);toggle.Text=engine.Enabled and 'ON' or 'OFF';state.Text=engine.Message
    end)
    connect(close.Activated,function()handle:Destroy()end)
    connect(collapse.Activated,function()
        collapsed=not collapsed;body.Visible=not collapsed;collapse.Text=collapsed and '+' or '−'
        animate(window,'size',{Size=UDim2.fromOffset(340,collapsed and 44 or 366)},.18);fit()
    end)
    connect(header.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=input;dragPoint=input.Position;dragOrigin=window.Position
        end
    end)
    connect(Input.InputChanged,function(input)
        if not dragging then return end
        if input~=dragging and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local delta=input.Position-dragPoint
        window.Position=UDim2.fromOffset(dragOrigin.X.Offset+delta.X,dragOrigin.Y.Offset+delta.Y);fit()
    end)
    connect(Input.InputEnded,function(input)if input==dragging then dragging=nil end end)
    connect(workspace.DescendantAdded,function(object)engine:added(object)end)
    connect(workspace.DescendantRemoving,function(object)engine:remove(object)end)
    connect(gui.Destroying,function()handle:Destroy()end)
    local nextUI=0
    connect(game:GetService('RunService').Heartbeat,function()
        if handle.Destroyed then return end
        if env[KEY]~=handle or game.JobId~=handle.JobId or gui.Parent~=player:FindFirstChild('PlayerGui') then handle:Destroy();return end
        local good,problem=pcall(function()engine:step()end)
        if not good then engine:setEnabled(false);log('Ошибка: '..tostring(problem)) end
        if handle.Destroyed or os.clock()<nextUI then return end;nextUI=os.clock()+.25
        toggle.Text=engine.Enabled and 'ON' or 'OFF';state.Text=engine.Message
        stats.Text='NPC: '..#engine.List..' | За 1 с: '..engine:actualRate()..' | Всего: '..engine.Sent
    end)
    log('Путь вызова: '..engine.RemotePath)
    log('GeneralHit: цели выбираются заново, NPC распределяются по кругу')
    log('Частота 1–100/с общая; при низком FPS фактическая частота ниже')
    animate(window,'fade',{GroupTransparency=0},.22)
    local shimmer=Tween:Create(gradient,TweenInfo.new(9,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,false),{Rotation=375})
    channels[gradient]={shimmer=shimmer};tweens[#tweens+1]=shimmer;shimmer:Play()
end)
if not ok then handle:Destroy();error('[NPC GeneralHit] '..tostring(why)) end
return handle
