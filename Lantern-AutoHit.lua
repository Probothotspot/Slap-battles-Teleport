-- Lantern AutoHit 1.0.0 | Probothotspot
-- Observed packet: LocalPlayer.Character.Lantern.Network:FireServer("Hit", NPC.CandyCorn)
-- A returned FireServer is a sent request, never an acknowledgement of server damage.
local Core={}
function Core.boxDistance(part,point)
    local p=part.CFrame:PointToObjectSpace(point);local half=part.Size*.5
    local dx=math.max(0,math.abs(p.X)-half.X)
    local dy=math.max(0,math.abs(p.Y)-half.Y)
    local dz=math.max(0,math.abs(p.Z)-half.Z)
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end
function Core.new(c)
    local clock=c.Clock or os.clock
    local self={Enabled=false,Destroyed=false,Rate=4,Range=8,Swing=true,Sent=0,Failures=0,Swings=0,ObservedHPLoss=0,
        List={},Index={},Pending=setmetatable({},{__mode='k'}),Stack={{Node=c.World}},Scanned=0,Ready=false,NextSweep=0,
        LastHit=setmetatable({},{__mode='k'}),Watches={},Times={},NextCall=0,NextSwing=0,LastSwing=-math.huge,
        ScanCursor=0,Busy=false,NextSense=0,StatusCode='off',Message='OFF — экипируй Lantern',RemotePath='LocalPlayer.Character.Lantern.Network'}
    local function note(code,message)
        self.StatusCode=code
        if message~=self.Message then self.Message=message;if c.Log then c.Log(message)end end
    end
    function self:humanoid(part)
        if not part:IsA('BasePart') or not part:IsDescendantOf(c.World)then return nil end
        if part.Name~='CandyCorn' and part:GetAttribute('slappable')~=true then return nil end
        local p=part.Parent;local depth=0
        while p and p~=c.World and depth<64 do
            if p:IsA('Model')then
                local h=p:FindFirstChildOfClass('Humanoid')
                if h then
                    if c.Players:GetPlayerFromCharacter(p)then return nil end
                    for _,player in ipairs(c.Players:GetPlayers())do
                        if player.Character and (p==player.Character or p:IsDescendantOf(player.Character))then return nil end
                    end
                    if h.Health>0 then return h end;return nil
                end
            end
            p=p.Parent;depth=depth+1
        end
    end
    function self:add(object)
        if self.Destroyed or self.Index[object]or not self:humanoid(object)then return end
        self.List[#self.List+1]=object;self.Index[object]=#self.List
    end
    function self:remove(object)
        self.Pending[object]=nil
        local index=self.Index[object];if not index then return end
        local last=table.remove(self.List);self.Index[object]=nil
        if index<=#self.List then self.List[index]=last;self.Index[last]=index end
    end
    function self:added(object)
        if self.Destroyed then return end
        if object:IsA('Humanoid')or object:IsA('BasePart')then self.Pending[object]=true end
    end
    function self:indexStep()
        local started=clock();local pending=0;local steps=0
        for object in pairs(self.Pending)do
            if pending>=32 or clock()-started>=.002 then break end
            self.Pending[object]=nil;pending=pending+1
            if object:IsA('Humanoid')and object.Parent then
                for i,child in ipairs(object.Parent:GetChildren())do if i>64 then break end;self:add(child)end
            else self:add(object)end
        end
        if #self.Stack==0 and started>=self.NextSweep then self.Stack={{Node=c.World}};self.NextSweep=math.huge end
        local working=#self.Stack>0
        while #self.Stack>0 and steps<512 and clock()-started<.002 do
            steps=steps+1;local frame=self.Stack[#self.Stack]
            if not frame.Children then frame.Children=frame.Node:GetChildren();frame.Position=1
            elseif frame.Position>#frame.Children then table.remove(self.Stack)
            else
                local object=frame.Children[frame.Position];frame.Position=frame.Position+1;self.Scanned=self.Scanned+1
                if object:IsDescendantOf(c.World)then
                    self:add(object)
                    -- Animation poses named CandyCorn are not physical targets. Skip their trees altogether.
                    if not object:IsA('KeyframeSequence')and not object:IsA('Pose')then self.Stack[#self.Stack+1]={Node=object}end
                end
            end
        end
        if working and #self.Stack==0 then self.Ready=true;self.NextSweep=clock()+5 end
    end
    function self:release()
        local tool=self.OwnedTool;self.OwnedTool=nil;self.ReleaseAt=nil
        if tool then pcall(function()if c.Deactivate then c.Deactivate(tool)else tool:Deactivate()end end)end
    end
    function self:setEnabled(value)
        if self.Destroyed then return end
        self.Enabled=value==true;self.NextCall=clock();self.NextSense=0;self.NextSwing=0;self.LastSwing=-math.huge
        if not self.Enabled then self:release()end
        note(self.Enabled and 'waiting' or 'off',self.Enabled and 'ON — ожидание ближайшего NPC' or 'OFF — остановлено')
    end
    function self:setRate(value)
        if type(value)~='number'or value~=value or value%1~=0 or value<1 or value>20 then return false end
        self.Rate=value;self.NextCall=clock()+1/value;return true
    end
    function self:setRange(value)
        if type(value)~='number'or value~=value or value<1 or value>30 then return false end
        self.Range=value;return true
    end
    function self:setSwing(value)
        self.Swing=value==true;self:release();self.NextSwing=0;self.LastSwing=-math.huge
    end
    function self:equipment()
        local char=c.Character()
        if not char or not char:IsDescendantOf(c.World)then return nil,'Персонаж ещё не появился' end
        local human=char:FindFirstChildOfClass('Humanoid')
        if not human or human.Health<=0 then return nil,'Персонаж погиб — ожидание возрождения' end
        local tool=char:FindFirstChild('Lantern')
        if not tool or not tool:IsA('Tool')then return nil,'Экипируй Lantern — используется только твой текущий Tool' end
        local remote=tool:FindFirstChild('Network')
        if not remote or not remote:IsA('RemoteEvent')then return nil,'У текущего Lantern пока нет RemoteEvent Network' end
        local origin=tool:FindFirstChild('Handle')
        if not origin or not origin:IsA('BasePart')then origin=char:FindFirstChild('HumanoidRootPart')end
        if not origin or not origin:IsA('BasePart')then return nil,'Нет Handle / HumanoidRootPart для дистанции' end
        return tool,remote,origin.Position
    end
    function self:pick(origin,now)
        local best,bestHuman,bestDistance,bestTime
        local started=clock();local count=math.min(#self.List,128)
        for _=1,count do
            if #self.List==0 or clock()-started>=.001 then break end
            self.ScanCursor=self.ScanCursor%#self.List+1
            local part=self.List[self.ScanCursor];local human=self:humanoid(part)
            if not human then self:remove(part)
            else
                local distance=Core.boxDistance(part,origin);local last=self.LastHit[human]or -math.huge
                -- Per-rig cooldown prevents sending multiple body parts as separate enemies.
                if distance<=self.Range and now-last>=.2 and (not best or last<bestTime or last==bestTime and distance<bestDistance)then
                    best,bestHuman,bestDistance,bestTime=part,human,distance,last
                end
            end
        end
        return best,bestHuman,bestDistance
    end
    function self:sampleHealth(now)
        for human,watch in pairs(self.Watches)do
            if not human.Parent or not human:IsDescendantOf(c.World)or now-watch.At>2 then self.Watches[human]=nil
            else
                local health=human.Health
                if health<watch.Last then self.ObservedHPLoss=self.ObservedHPLoss+watch.Last-health end
                watch.Last=health
            end
        end
    end
    function self:actualRate()
        local kept={};for _,at in ipairs(self.Times)do if at>clock()-1 then kept[#kept+1]=at end end
        self.Times=kept;return #kept
    end
    function self:tick()
        local now=clock()
        if self.ReleaseAt and now>=self.ReleaseAt then self:release()end
        self:sampleHealth(now);self:indexStep()
        if not self.Enabled or now<self.NextSense then return end
        local tool,remote,origin=self:equipment()
        if not tool then self:release();self.LastTool=nil;self.NextSense=now+.15;note('waiting_tool',remote);return end
        if tool~=self.LastTool then self:release();self.LastTool=tool;self.LastSwing=-math.huge;self.NextSwing=0 end
        self.RemotePath=remote:GetFullName();self.AttackActive=tool:GetAttribute('AttackActive')
        local part,human,distance=self:pick(origin,now)
        if not part then self.NextSense=now+.05;note('waiting_npc',self.Ready and 'Ожидание NPC в заданном радиусе' or 'NPC индексируются в фоне…');return end
        self.NextSense=now+.025
        self.LastTarget=part:GetFullName();self.LastDistance=distance;self.LastSize={X=part.Size.X,Y=part.Size.Y,Z=part.Size.Z}
        if self.Swing then
            if now>=self.NextSwing and self.AttackActive~=true and tool.Enabled~=false then
                self.NextSwing=now+.55;self.LastSwing=now;self.OwnedTool=tool;self.ReleaseAt=now+.06
                local ok,why=pcall(function()if c.Activate then c.Activate(tool)else tool:Activate()end end)
                if self.Destroyed or not self.Enabled then return end
                if not ok then self.LastError=tostring(why);self.Failures=self.Failures+1;note('swing_error','Tool:Activate: '..self.LastError);return end
                self.Swings=self.Swings+1;self.AttackActive=tool:GetAttribute('AttackActive')
            end
            local elapsed=now-self.LastSwing
            local active=self.AttackActive==true
            -- If the attribute is absent, try a short unverified timing window after our own swing.
            if self.AttackActive==nil then active=elapsed>=.06 and elapsed<=.4 end
            if not active then note('waiting_swing','Ожидание активного взмаха (AttackActive)');return end
        end
        if now<self.NextCall then return end
        -- Re-resolve character, tool, Network, NPC and size immediately before dispatch.
        local currentTool,currentRemote,currentOrigin=self:equipment()
        if currentTool~=tool or currentRemote~=remote or self:humanoid(part)~=human or Core.boxDistance(part,currentOrigin)>self.Range then
            self.NextSense=now+.05;return
        end
        if not self.Enabled or self.Destroyed then return end
        self.NextCall=now+1/self.Rate;self.LastHit[human]=now
        if not self.Watches[human]then
            local count=0;for _ in pairs(self.Watches)do count=count+1 end
            if count<64 then self.Watches[human]={Last=human.Health,At=now}end
        else self.Watches[human].At=now end
        local ok,result=pcall(function()
            if c.Fire then return c.Fire(remote,'Hit',part)end
            return remote:FireServer('Hit',part)
        end)
        if self.Destroyed then return end
        if ok and result~=false then
            self.Sent=self.Sent+1;self.Times[#self.Times+1]=now;self.LastError=nil
            if #self.Times>80 then table.remove(self.Times,1)end
            if self.Enabled then
                self.StatusCode='sent';self.Message=string.format('ON — %s | до границ %.1f ст.',human.Parent and human.Parent.Name or 'NPC',distance)
            end
        else
            self.Failures=self.Failures+1;self.LastError=tostring(result);self.NextCall=now+.5;self.NextSense=now+.5
            if self.Enabled then note('fire_error','Lantern.Network:FireServer: '..self.LastError)end
        end
    end
    function self:step()
        if self.Destroyed or self.Busy then return end
        self.Busy=true;local ok,why=pcall(self.tick,self);self.Busy=false
        if not ok and not self.Destroyed then self.LastError=tostring(why);self.Failures=self.Failures+1;self:setEnabled(false);note('error','Ошибка цикла: '..self.LastError)end
    end
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true;self.Enabled=false;self:release();self.List={};self.Index={};self.Pending={};self.Stack={};self.Watches={};self.Times={}
    end
    return self
end
-- BEGIN ROBLOX CLIENT
local Players=game:GetService('Players')
local player=Players.LocalPlayer;assert(player,'Lantern AutoHit: требуется клиент')
local env=_G
if type(getgenv)=='function' then local ok,v=pcall(getgenv);if ok and type(v)=='table' then env=v end end
local KEY='ProbothotspotLanternAutoHit'
local previous=env[KEY]
if type(previous)=='table' and type(previous.Destroy)=='function' then previous:Destroy() end
local playerGui=player:WaitForChild('PlayerGui',10);assert(playerGui,'Lantern AutoHit: PlayerGui не готов')
local Tween=game:GetService('TweenService');local Input=game:GetService('UserInputService')
local connections,tweens,channels={},{},{}
local handle={Version='1.0.0',JobId=game.JobId,Destroyed=false}
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
    gui=make('ScreenGui',{Name='LanternAutoHitGUI',ResetOnSpawn=false,DisplayOrder=1200,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
    handle.Gui=gui
    local safe=make('Frame',{Name='SafeArea',Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
    local window=make('CanvasGroup',{Name='Window',Size=UDim2.fromOffset(340,460),Position=UDim2.new(.5,-170,.5,-230),
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
    local title=label('Title','Lantern AutoHit 1.0.0',15,0,230,44,16,header);title.Font=Enum.Font.GothamBold
    local collapse=button('Collapse','−',260,8,28,28,header)
    local close=button('Close','×',295,8,28,28,header)
    local body=make('Frame',{Name='Body',Position=UDim2.fromOffset(0,44),Size=UDim2.new(1,0,1,-44),BackgroundTransparency=1},window)
    label('RateLabel','Лимит Hit/с — общий для ближайших NPC',15,4,310,25,12,body)
    local minus=button('Minus','−',15,35,42,36,body)
    local rateBox=make('TextBox',{Name='Rate',Text='4',PlaceholderText='1–20',Position=UDim2.fromOffset(64,35),Size=UDim2.fromOffset(212,36),
        ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(104,49,155),BorderSizePixel=0,TextColor3=Color3.fromRGB(255,244,255),
        Font=Enum.Font.GothamBold,TextSize=17},body);round(rateBox,9)
    local plus=button('Plus','+',283,35,42,36,body)
    label('RangeLabel','До границ части, ст. (1–30)',15,78,310,20,11,body)
    local rangeBox=make('TextBox',{Name='Range',Text='8',PlaceholderText='1–30',Position=UDim2.fromOffset(15,101),Size=UDim2.fromOffset(145,31),
        ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(104,49,155),BorderSizePixel=0,TextColor3=Color3.fromRGB(255,244,255),
        Font=Enum.Font.GothamBold,TextSize=15},body);round(rangeBox,9)
    local swingButton=button('Swing','Взмах: ON',171,101,154,31,body)
    local toggle=button('Toggle','OFF',15,141,310,38,body)
    local state=label('State','OFF — готов к запуску',15,184,310,35,12,body)
    local stats=label('Stats','NPC в индексе: 0 | Отправлено: 0',15,222,310,34,11,body)
    label('Note','HP↓ — наблюдение, причина урона не доказана. Игроки исключены.',15,258,310,28,10,body)
    local logs=make('ScrollingFrame',{Name='Logs',Position=UDim2.fromOffset(15,291),Size=UDim2.fromOffset(310,65),
        BackgroundColor3=Color3.fromRGB(102,49,151),BackgroundTransparency=.12,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,65)},body)
    round(logs,8)
    local logText=label('LogText','',8,5,292,55,10,logs);logText.TextYAlignment=Enum.TextYAlignment.Top
    local copy=button('Copy','Копировать диагностику',15,365,310,28,body)
    label('Credit','By: Probothotspot',15,398,310,15,10,body)
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
    engine=Core.new({World=workspace,Players=Players,Character=function()return player.Character end,Log=log})
    handle.Engine=engine
    local collapsed=false;local dragging,dragPoint,dragOrigin
    local function fit()
        local area=safe.AbsoluteSize;if area.X<=0 or area.Y<=0 then return end
        scale.Scale=math.max(.1,math.min(1,(area.X-16)/340,(area.Y-16)/(collapsed and 44 or 460)))
        local x=window.Position.X.Scale*area.X+window.Position.X.Offset
        local y=window.Position.Y.Scale*area.Y+window.Position.Y.Offset
        window.Position=UDim2.fromOffset(math.clamp(x,0,math.max(0,area.X-340*scale.Scale)),
            math.clamp(y,0,math.max(0,area.Y-(collapsed and 44 or 460)*scale.Scale)))
    end
    connect(safe:GetPropertyChangedSignal('AbsoluteSize'),fit);fit()
    local function applyRate(value)
        if not engine:setRate(value) then log('Введи целое число от 1 до 20') end
        rateBox.Text=tostring(engine.Rate)
    end
    connect(rateBox.FocusLost,function()applyRate(tonumber(rateBox.Text:match('^%s*(.-)%s*$')))end)
    connect(minus.Activated,function()applyRate(math.max(1,engine.Rate-1))end)
    connect(plus.Activated,function()applyRate(math.min(20,engine.Rate+1))end)
    connect(rangeBox.FocusLost,function()
        if not engine:setRange(tonumber(rangeBox.Text:match('^%s*(.-)%s*$')))then log('Дистанция: число от 1 до 30')end
        rangeBox.Text=tostring(engine.Range)
    end)
    connect(swingButton.Activated,function()
        engine:setSwing(not engine.Swing);swingButton.Text=engine.Swing and 'Взмах: ON' or 'Взмах: OFF'
        log(engine.Swing and 'Взмах ON: Tool:Activate + AttackActive' or 'Взмах OFF: только Network:FireServer; сервер может игнорировать')
    end)
    connect(copy.Activated,function()
        local snapshot={Version=handle.Version,PlaceId=game.PlaceId,JobId=game.JobId,Enabled=engine.Enabled,RateLimit=engine.Rate,RangeToBox=engine.Range,
            Swing=engine.Swing,AttackActive=engine.AttackActive,Remote=engine.RemotePath,Target=engine.LastTarget,LastBoxDistance=engine.LastDistance,
            TargetSize=engine.LastSize,SentRequests=engine.Sent,Swings=engine.Swings,ObservedHPLoss=engine.ObservedHPLoss,
            Failures=engine.Failures,LastError=engine.LastError,Status=engine.StatusCode,Message=engine.Message,IndexedParts=#engine.List,
            IndexReady=engine.Ready,Scanned=engine.Scanned,Logs=lines,
            Observation='Sent requests are not acknowledged hits. Observed HP loss may have other causes; no remote or attribute is altered.'}
        local ok,text=pcall(function()return game:GetService('HttpService'):JSONEncode(snapshot)end)
        if not ok then log('JSON: '..tostring(text));return end
        handle.CopyText=text
        local clip=type(setclipboard)=='function'and setclipboard or type(env.setclipboard)=='function'and env.setclipboard
            or type(toclipboard)=='function'and toclipboard or type(env.toclipboard)=='function'and env.toclipboard
        local copied,result=false,nil;if clip then copied,result=pcall(clip,text)end
        if copied and result~=false then log('Диагностика скопирована')
        else
            local export=body:FindFirstChild('Export')
            if not export then export=make('TextBox',{Name='Export',Size=UDim2.fromOffset(310,65),Position=UDim2.fromOffset(15,291),
                BackgroundColor3=Color3.fromRGB(95,43,145),TextColor3=Color3.fromRGB(255,244,255),TextSize=11,Font=Enum.Font.Code,
                MultiLine=true,TextWrapped=true,ClearTextOnFocus=false,ZIndex=5},body)end
            export.Text=text;export:CaptureFocus();export.CursorPosition=1;export.SelectionStart=#text+1
            log('Текст выделен для ручного копирования')
        end
    end)
    connect(toggle.Activated,function()
        engine:setEnabled(not engine.Enabled);toggle.Text=engine.Enabled and 'ON' or 'OFF';state.Text=engine.Message
    end)
    connect(close.Activated,function()handle:Destroy()end)
    connect(collapse.Activated,function()
        collapsed=not collapsed;body.Visible=not collapsed;collapse.Text=collapsed and '+' or '−'
        animate(window,'size',{Size=UDim2.fromOffset(340,collapsed and 44 or 460)},.18);fit()
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
        stats.Text='Частей: '..#engine.List..' | Hit/с: '..engine:actualRate()..' | Отправлено: '..engine.Sent..'\nВзмахов: '..engine.Swings..' | HP↓ (набл.): '..engine.ObservedHPLoss
    end)
    log('Путь вызова: '..engine.RemotePath)
    log('Точный пакет: текущий Lantern.Network:FireServer("Hit", part)')
    log('Радиус учитывает Size/CFrame; CanQuery=false не мешает индексу')
    log('Взмах ON по умолчанию. При отсутствии HP↓ скопируй диагностику')
    animate(window,'fade',{GroupTransparency=0},.22)
    local shimmer=Tween:Create(gradient,TweenInfo.new(9,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,false),{Rotation=375})
    channels[gradient]={shimmer=shimmer};tweens[#tweens+1]=shimmer;shimmer:Play()
end)
if not ok then handle:Destroy();error('[Lantern AutoHit] '..tostring(why)) end
return handle
