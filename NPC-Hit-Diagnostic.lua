-- NPC Hit Diagnostic v1.0.0 | Probothotspot
-- Observes outgoing client calls; never replays a call or confirms server damage.
local Diagnostic={}
local function finite(n)return n==n and n~=math.huge and n~=-math.huge end
local function clip(text,limit)
    local out=text:sub(1,limit)
    if utf8 and utf8.len then
        while #out>0 and not utf8.len(out)do out=out:sub(1,-2)end
    end
    return out
end
function Diagnostic.new(c)
    local clock=c.Clock or os.clock
    local self={Recording=true,Destroyed=false,Reports={},Sequence=0,Revision=0,Dropped=0,CaptureCredit=8,BudgetAt=clock(),BroadUntil=0}
    local function snapshot(v,ctx,depth)
        ctx.Nodes=ctx.Nodes+1
        if ctx.Nodes>180 or depth>5 or clock()-ctx.Started>.003 then ctx.Truncated=true;return{Type='truncated'} end
        local kind=c.Kind(v)
        if kind=='nil' then return{Type='nil'} end
        if kind=='number' then
            if finite(v) then return{Type='number',Value=v} end
            ctx.Truncated=true;return{Type='number',NonFinite=tostring(v)}
        end
        if kind=='boolean' then return{Type=kind,Value=v} end
        if kind=='string' then
            if utf8 and not utf8.len(v) then
                ctx.Truncated=true
                return{Type=kind,Encoding='hex',Value=(v:sub(1,512):gsub('.',function(char)return string.format('%02x',string.byte(char))end)),OriginalBytes=#v,Truncated=true}
            end
            if #v>2048 then ctx.Truncated=true;return{Type=kind,Value=clip(v,2048),OriginalBytes=#v,Truncated=true}end
            return{Type=kind,Value=v}
        end
        if kind=='Instance' then
            local existing=ctx.Instances[v];if existing then return existing end
            local good,data=pcall(c.Describe,v)
            if not good then ctx.Truncated=true;return{Type=kind,DescriptionError=tostring(data)} end
            data.Type=kind;ctx.Instances[v]=data
            if data.Target and data.Target.Kind=='NPC' and #ctx.Targets<8 then ctx.Targets[#ctx.Targets+1]=data.Target end
            return data
        end
        if kind=='table' then
            if ctx.Seen[v] then return{Type='reference',TableId=ctx.Seen[v]} end
            ctx.TableId=ctx.TableId+1;ctx.Seen[v]=ctx.TableId
            local out={Type='table',TableId=ctx.TableId,Entries={}}
            local i=0
            for key,value in pairs(v) do
                if i>=30 or ctx.Nodes>=180 or clock()-ctx.Started>.003 then out.Truncated=true;ctx.Truncated=true;break end
                i=i+1;out.Entries[i]={Key=snapshot(key,ctx,depth+1),Value=snapshot(value,ctx,depth+1)}
            end
            return out
        end
        local good,data=pcall(c.Value,v,kind)
        if good and data then data.Type=kind;return data end
        ctx.Truncated=true;return{Type=kind,Unsupported=true}
    end
    local function code(v)
        if v.Type=='nil' then return 'nil' end
        if v.Type=='string' then if v.Truncated then return nil end;return string.format('%q',v.Value) end
        if v.Type=='number' then return v.Value and tostring(v.Value) or nil end
        if v.Type=='boolean' then return tostring(v.Value) end
        if v.Type=='Instance' then return v.Expression end
        if v.Code then return v.Code end
        if v.Type=='table' and not v.Truncated then
            local entries={}
            for _,entry in ipairs(v.Entries)do
                local key,value=code(entry.Key),code(entry.Value);if not key or not value then return nil end
                entries[#entries+1]='['..key..']='..value
            end
            return '{'..table.concat(entries,', ')..'}'
        end
    end
    function self:capture(remote,method,args,origin)
        if self.Destroyed or not self.Recording or self.Capturing then return end
        if method~='FireServer' and method~='InvokeServer' then return end
        if origin=='executor' then return end
        local now=clock()
        self.CaptureCredit=math.min(8,self.CaptureCredit+math.max(0,now-self.BudgetAt)*20);self.BudgetAt=now
        if self.CaptureCredit<1 then self.Dropped=self.Dropped+1;return end
        self.Capturing=true
        local ok,why=pcall(function()
            local ctx={Nodes=0,Started=now,Truncated=false,Seen={},Instances={},Targets={},TableId=0}
            local remoteInfo=c.Describe(remote)
            local values={};local n=args.n or #args
            for i=1,math.min(n,16) do values[i]=snapshot(args[i],ctx,0) end
            if n>16 then ctx.Truncated=true end
            local name=(remoteInfo.Name or ''):lower()
            local hitName=name:find('hit',1,true) or name:find('slap',1,true) or name:find('attack',1,true) or name:find('damage',1,true)
            local broad=now<self.BroadUntil
            if #ctx.Targets==0 and not hitName and not broad then return end
            local initiator,stack=c.Caller()
            local context
            if c.Context then local good,v=pcall(c.Context);context=good and v or {Error=tostring(v)}end
            self.Sequence=self.Sequence+1
            local report={Schema=1,Version='1.0.0',Id=self.Sequence,Time=c.Epoch(),LocalClock=now,PlaceId=c.PlaceId,JobId=c.JobId,
                Method=method,Origin=origin or 'unknown',Remote=remoteInfo,ArgumentCount=n,Arguments=values,Targets=ctx.Targets,
                Match=broad and '10-second broad capture' or #ctx.Targets>0 and 'NPC instance argument' or 'hit-like remote name; NPC not proven',
                Initiator=initiator,Stack=stack,LocalCharacter=context,Truncated=ctx.Truncated,Dropped=self.Dropped,Capabilities=c.Capabilities,
                Observation='Outgoing client request only; server response/damage not observed'}
            local parts={};local reproducible=not ctx.Truncated and remoteInfo.Expression~=nil
            for _,value in ipairs(values)do local part=code(value);if not part then reproducible=false;break end;parts[#parts+1]=part end
            if reproducible then report.CallPreview=remoteInfo.Expression..':'..method..'('..table.concat(parts,', ')..')'
            else report.CallPreview='Unavailable: arguments/path truncated or unsupported; do not treat this as a complete replay' end
            self.Reports[#self.Reports+1]=report
            if #self.Reports>12 then table.remove(self.Reports,1) end
            self.CaptureCredit=self.CaptureCredit-1;self.Revision=self.Revision+1
        end)
        self.Capturing=false
        if not ok then self.LastError=tostring(why);self.Revision=self.Revision+1 end
    end
    function self:Destroy()self.Destroyed=true;self.Recording=false end
    return self
end
function Diagnostic.install(c)
    local state=c.Existing
    if type(state)=='table' and state.Kind=='NPCHitHook-v1' and state.Runtime==c.Game and state.Ready then return state end
    state={Kind='NPCHitHook-v1',Runtime=c.Game,Ready=false,Modes={},Errors={}}
    local function notify(remote,method,args)
        local listener=state.Listener
        if listener then pcall(listener,remote,method,args) end
    end
    if type(c.HookMetamethod)=='function' and type(c.GetNamecallMethod)=='function' then
        local old
        local wrapper=function(remote,...)
            if not state.Listener then return old(remote,...)end
            local good,method=pcall(c.GetNamecallMethod)
            if good and (method=='FireServer' or method=='InvokeServer') then notify(remote,method,table.pack(...)) end
            return old(remote,...)
        end
        if c.NewCClosure then local good,v=pcall(c.NewCClosure,wrapper);if good then wrapper=v end end
        local good,result=pcall(c.HookMetamethod,c.Game,'__namecall',wrapper)
        if good and type(result)=='function' then
            old=result;state.Ready=true;state.Modes[1]='__namecall (colon calls)';return state
        end
        state.Errors[#state.Errors+1]='hookmetamethod: '..tostring(result)
    end
    if type(c.HookFunction)=='function' then
        for _,method in ipairs({'FireServer','InvokeServer'})do
            local good,result=pcall(function()
                local target=c.MethodFunction(method)
                local old
                local wrapper=function(remote,...)if state.Listener then notify(remote,method,table.pack(...))end;return old(remote,...)end
                if c.NewCClosure then local good,v=pcall(c.NewCClosure,wrapper);if good then wrapper=v end end
                old=c.HookFunction(target,wrapper)
                assert(type(old)=='function','hookfunction did not return the original function')
            end)
            if good then state.Ready=true;state.Modes[#state.Modes+1]='hookfunction '..method
            else state.Errors[#state.Errors+1]=method..': '..tostring(result)end
        end
    end
    if not state.Ready then state.Errors[#state.Errors+1]='No supported interception API; presence alone does not prove working capture' end
    return state
end
-- BEGIN ROBLOX CLIENT
local Players=game:GetService('Players');local player=Players.LocalPlayer
assert(player,'NPC Hit Diagnostic requires a client player')
local env=_G
if type(getgenv)=='function' then local ok,v=pcall(getgenv);if ok and type(v)=='table' then env=v end end
local KEY,HOOK='ProbothotspotNPCHitDiagnostic','ProbothotspotNPCHitHook'
local previous=env[KEY];if type(previous)=='table' and type(previous.Destroy)=='function' then previous:Destroy() end
local pg=player:WaitForChild('PlayerGui',10);assert(pg,'PlayerGui unavailable')
local connections,tweens={},{};local gui,engine,dispatcher,listener
local handle={Version='1.0.0',JobId=game.JobId,Destroyed=false};env[KEY]=handle
local function connect(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
function handle:Destroy()
    if self.Destroyed then return end;self.Destroyed=true
    if engine then engine:Destroy() end
    if dispatcher and dispatcher.Listener==listener then dispatcher.Listener=nil end
    for _,c in ipairs(connections)do c:Disconnect()end
    for _,t in ipairs(tweens)do pcall(function()t:Cancel()end)end
    if gui then gui:Destroy()end
    if env[KEY]==self then env[KEY]=nil end
end
local function api(name)
    local direct={hookmetamethod=hookmetamethod,getnamecallmethod=getnamecallmethod,hookfunction=hookfunction,
        newcclosure=newcclosure,checkcaller=checkcaller,getcallingscript=getcallingscript,setclipboard=setclipboard,
        identifyexecutor=identifyexecutor,toclipboard=toclipboard}
    if type(direct[name])=='function' then return direct[name]end
    if type(env[name])=='function' then return env[name]end
    if type(_G[name])=='function' then return _G[name]end
end
local function path(object)
    local names={};local p=object;local depth=0
    while p and p~=game and depth<128 do names[#names+1]=p.Name;p=p.Parent;depth=depth+1 end
    local expression
    if p==game then
        expression='game'
        for i=#names,1,-1 do
            if i==#names and (names[i]=='Workspace' or names[i]=='ReplicatedStorage' or names[i]=='Players') then
                expression=expression..':GetService('..string.format('%q',names[i])..')'
            else expression=expression..'['..string.format('%q',names[i])..']'end
        end
    end
    local good,full=pcall(function()return object:GetFullName()end)
    return good and full or table.concat(names,' / '),expression
end
local function vector(v)if not v then return nil end;return{X=v.X,Y=v.Y,Z=v.Z}end
local function targetInfo(object)
    if not object:IsDescendantOf(workspace) then return nil end
    local p=object;local depth=0;local fallback
    while p and p~=workspace and depth<64 do
        if p:IsA('Model') then
            local human=p:FindFirstChildOfClass('Humanoid')
            local owner=Players:GetPlayerFromCharacter(p)
            for _,candidate in ipairs(Players:GetPlayers())do
                if candidate.Character and (p==candidate.Character or p:IsDescendantOf(candidate.Character))then owner=candidate;break end
            end
            if human then
                local full,expression=path(p)
                local result={Kind=owner and 'Player' or 'NPC',Name=p.Name,FullPath=full,Expression=expression,
                    HumanoidPath=path(human),Health=human.Health,MaxHealth=human.MaxHealth,RigType=tostring(human.RigType)}
                local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
                if root and object:IsA('BasePart') then result.DistanceFromLocalPlayer=(root.Position-object.Position).Magnitude end
                return result
            end
            local enemies=workspace:FindFirstChild('Enemies')
            if enemies and p:IsDescendantOf(enemies) and not fallback then
                local full,expression=path(p);fallback={Kind='NPC',Inferred=true,Reason='Model under Workspace.Enemies without Humanoid',Name=p.Name,FullPath=full,Expression=expression}
            end
        end
        p=p.Parent;depth=depth+1
    end
    return fallback
end
local function describe(object)
    local full,expression=path(object)
    local d={Name=object.Name,ClassName=object.ClassName,FullPath=full,Expression=expression,InWorkspace=object:IsDescendantOf(workspace),Target=targetInfo(object)}
    if object.Parent then d.ParentPath=path(object.Parent)end
    if object:IsA('BasePart')then
        d.Position=vector(object.Position);d.Size=vector(object.Size);d.Anchored=object.Anchored
        d.CanCollide=object.CanCollide;d.CanTouch=object.CanTouch;d.Transparency=object.Transparency
    end
    return d
end
local capabilities={}
for _,name in ipairs({'hookmetamethod','getnamecallmethod','hookfunction','newcclosure','checkcaller','getcallingscript','setclipboard'})do capabilities[name]=api(name)~=nil end
local identify=api('identifyexecutor')
if identify then local good,name,version=pcall(identify);if good then capabilities.Executor=tostring(name);capabilities.ExecutorVersion=tostring(version or '')end end
local function caller()
    local initiator={Available=false,Reason='getcallingscript unavailable'}
    local fn=api('getcallingscript')
    if fn then
        local good,script=pcall(fn)
        if good and typeof(script)=='Instance' then initiator={Available=true,FullPath=path(script),ClassName=script.ClassName}
        else initiator={Available=false,Reason=good and 'origin script unknown' or tostring(script)}end
    end
    local stack={Available=false,Reason='debug.traceback unavailable'}
    if type(debug)=='table' and type(debug.traceback)=='function' then
        local good,text=pcall(debug.traceback,'',3)
        if good then stack={Available=true,Text=clip(tostring(text),4096),Truncated=#tostring(text)>4096}end
    end
    return initiator,stack
end
local function value(v,kind)
    if kind=='Vector3' or kind=='Vector2' then
        local numbers=kind=='Vector3' and {v.X,v.Y,v.Z} or {v.X,v.Y}
        local words={};for _,n in ipairs(numbers)do if not finite(n)then return nil end;words[#words+1]=tostring(n)end
        return{Components=numbers,Code=kind..'.new('..table.concat(words,', ')..')'}
    end
    if kind=='Color3' then return{R=v.R,G=v.G,B=v.B,Code='Color3.new('..v.R..','..v.G..','..v.B..')'}end
    if kind=='CFrame' then
        local components={v:GetComponents()};local words={}
        for _,n in ipairs(components)do if not finite(n)then return nil end;words[#words+1]=tostring(n)end
        return{Components=components,Code='CFrame.new('..table.concat(words,', ')..')'}
    end
    if kind=='EnumItem' then return{Value=tostring(v),Code=tostring(v)}end
end
local function make(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function round(o)make('UICorner',{CornerRadius=UDim.new(0,10)},o)end
local ok,why=pcall(function()
    gui=make('ScreenGui',{Name='NPCHitDiagnosticGUI',ResetOnSpawn=false,DisplayOrder=1400,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg);handle.Gui=gui
    local safe=make('Frame',{Name='SafeArea',Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
    local window=make('Frame',{Name='Window',Size=UDim2.fromOffset(360,480),Position=UDim2.new(.5,-180,.5,-240),
        BackgroundColor3=Color3.fromRGB(132,68,189),BorderSizePixel=0,ClipsDescendants=true,Active=true},safe);round(window)
    local gradient=make('UIGradient',{Rotation=15,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(103,47,159)),
        ColorSequenceKeypoint.new(.5,Color3.fromRGB(171,92,220)),ColorSequenceKeypoint.new(1,Color3.fromRGB(119,58,181))})},window)
    local scale=make('UIScale',{Scale=1},window)
    local function label(name,text,x,y,w,h,size,parent)
        return make('TextLabel',{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,
            TextColor3=Color3.fromRGB(253,241,255),TextSize=size or 12,Font=Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},parent)
    end
    local function button(name,text,x,y,w,h)
        local b=make('TextButton',{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=Color3.fromRGB(177,108,223),
            BorderSizePixel=0,TextColor3=Color3.fromRGB(255,244,255),Font=Enum.Font.GothamBold,TextSize=12},window);round(b);return b
    end
    local header=make('Frame',{Name='Header',Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,Active=true},window)
    local title=label('Title','NPC Hit Diagnostic 1.0.0',14,0,290,44,15,header);title.Font=Enum.Font.GothamBold
    local close=button('Close','×',316,8,28,28)
    label('Instructions','Запись включена. Ударь NPC вручную и скопируй отчёт.',15,47,330,34,12,window)
    local status=label('Status','Установка наблюдения…',15,82,330,34,11,window)
    local count=label('Count','Записей: 0',15,119,250,20,11,window)
    local prev=button('Previous','<',280,118,28,22);local nextButton=button('Next','>',316,118,28,22)
    local scroll=make('ScrollingFrame',{Name='ReportScroll',Position=UDim2.fromOffset(15,146),Size=UDim2.fromOffset(330,225),
        BackgroundColor3=Color3.fromRGB(92,42,139),BackgroundTransparency=.12,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,225)},window);round(scroll)
    local box=make('TextBox',{Name='Report',Text='',Position=UDim2.fromOffset(7,6),Size=UDim2.fromOffset(312,215),BackgroundTransparency=1,
        TextColor3=Color3.fromRGB(253,239,255),Font=Enum.Font.Code,TextSize=11,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,ClearTextOnFocus=false,MultiLine=true,TextEditable=true},scroll)
    local toggle=button('Record','Запись: ON',15,383,158,34);local copy=button('Copy','Копировать всё',187,383,158,34)
    local broad=button('Broad','Поймать все Remote на 10 секунд',15,425,330,30)
    label('Credit','By: Probothotspot | Ничего не отправляет повторно',15,460,330,14,9,window)
    engine=Diagnostic.new({Kind=typeof,Describe=describe,Value=value,Caller=caller,Capabilities=capabilities,Epoch=os.time,
        PlaceId=game.PlaceId,JobId=game.JobId,Context=function()
            local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
            local human=char and char:FindFirstChildOfClass('Humanoid');local tool=char and char:FindFirstChildOfClass('Tool')
            local stats=player:FindFirstChild('leaderstats');local glove=stats and stats:FindFirstChild('Glove')
            return{CharacterPath=char and path(char),Position=root and vector(root.Position),Health=human and human.Health,
                EquippedTool=tool and tool.Name,ToolPath=tool and path(tool),
                Glove=glove and glove:IsA('StringValue') and glove.Value or nil}
        end});handle.Engine=engine
    local oldAuto=env.ProbothotspotNPCGeneralHit or _G.ProbothotspotNPCGeneralHit
    if type(oldAuto)=='table' and oldAuto.JobId==game.JobId and oldAuto.Engine and oldAuto.Engine.Enabled then
        oldAuto.Engine:setEnabled(false);capabilities.PausedNPCGeneralHit=true
    end
    dispatcher=Diagnostic.install({Existing=env[HOOK],Game=game,HookMetamethod=api('hookmetamethod'),GetNamecallMethod=api('getnamecallmethod'),
        HookFunction=api('hookfunction'),NewCClosure=api('newcclosure'),MethodFunction=function(method)
            local sample=Instance.new(method=='FireServer' and 'RemoteEvent' or 'RemoteFunction')
            local fn=sample[method];sample:Destroy();return fn
        end})
    env[HOOK]=dispatcher;capabilities.Installed=dispatcher.Ready;capabilities.Modes=dispatcher.Modes;capabilities.InstallErrors=dispatcher.Errors
    listener=function(remote,method,args)
        if handle.Destroyed or game.JobId~=handle.JobId then return end
        local origin='unknown';local check=api('checkcaller')
        if check then local good,isExecutor=pcall(check);if good then origin=isExecutor and 'executor' or 'game' end end
        engine:capture(remote,method,args,origin)
    end
    dispatcher.Listener=listener
    local http=game:GetService('HttpService');local selected
    local function current()
        for _,report in ipairs(engine.Reports)do if report.Id==selected then return report end end
        return engine.Reports[#engine.Reports]
    end
    local function render()
        local report=current()
        local data=report or {Status=dispatcher.Ready and 'Waiting for an observed call' or 'Interception unavailable',Capabilities=capabilities,
            Instructions='Hit an NPC manually. Missing hook APIs cannot be replaced by finding GeneralHit. No server calls are generated.',LastError=engine.LastError}
        local good,json=pcall(function()return http:JSONEncode(data)end)
        local text
        if report then
            local paths={}
            for i,arg in ipairs(report.Arguments)do
                if arg.Type=='Instance' then paths[#paths+1]='arg['..i..']: '..tostring(arg.FullPath)..' ('..tostring(arg.ClassName)..')'end
            end
            for _,target in ipairs(report.Targets)do paths[#paths+1]='NPC: '..tostring(target.FullPath)..' | Health: '..tostring(target.Health)end
            text='=== OBSERVED NPC HIT / CLIENT CALL ===\nRemote: '..tostring(report.Remote.FullPath)..'\nClass: '..tostring(report.Remote.ClassName)..
                '\nMethod: '..report.Method..'\nArgs: '..report.ArgumentCount..'\nMatch: '..report.Match..'\n'..table.concat(paths,'\n')..'\n\n'..report.CallPreview..'\n\nJSON:\n'..(good and json or tostring(json))
        else text=good and json or tostring(json) end
        handle.ReportText=text;box.Text=text
        local lines=0;for segment in (text..'\n'):gmatch('(.-)\n')do lines=lines+math.max(1,math.ceil((utf8.len(segment) or #segment)/44))end
        local h=math.max(215,lines*14);box.Size=UDim2.fromOffset(312,h);scroll.CanvasSize=UDim2.fromOffset(0,h+12)
        count.Text='Записей: '..#engine.Reports..' | Выбрана: '..tostring(report and report.Id or '—')
        toggle.Text=engine.Recording and 'Запись: ON' or 'Запись: OFF'
        if not dispatcher.Ready then status.Text='Перехват недоступен. Скопируй отчёт возможностей.'
        elseif engine.LastError then status.Text='Ошибка записи: '..engine.LastError
        elseif report then status.Text=report.Method..': '..report.Remote.Name..' | NPC в аргументах: '..#report.Targets
        else status.Text='Hook установлен; ожидается реальный вызов. Пока ничего не перехвачено.'end
    end
    connect(toggle.Activated,function()engine.Recording=not engine.Recording;dispatcher.Listener=engine.Recording and listener or nil;render()end)
    connect(broad.Activated,function()engine.Recording=true;dispatcher.Listener=listener;engine.BroadUntil=os.clock()+10;render()end)
    connect(prev.Activated,function()
        local report=current();for i,item in ipairs(engine.Reports)do if report and item.Id==report.Id then selected=engine.Reports[math.max(1,i-1)].Id;break end end;render()
    end)
    connect(nextButton.Activated,function()
        local report=current();for i,item in ipairs(engine.Reports)do if report and item.Id==report.Id then selected=i<#engine.Reports and engine.Reports[i+1].Id or nil;break end end;render()
    end)
    connect(copy.Activated,function()
        render()
        local report=current()
        local good,all=pcall(function()return http:JSONEncode({Schema=1,Version='1.0.0',Capabilities=capabilities,
            SelectedId=report and report.Id,Reports=engine.Reports,TotalObserved=engine.Sequence,Dropped=engine.Dropped,LastError=engine.LastError})end)
        local text=handle.ReportText..'\n\nJSON ALL:\n'..(good and all or tostring(all))
        handle.CopyText=text
        local fn=api('setclipboard') or api('toclipboard')
        if fn then local copied,result=pcall(fn,text);if copied and result~=false then status.Text='Все записи скопированы';return end end
        box.Text=text
        box:CaptureFocus();box.CursorPosition=1;box.SelectionStart=#box.Text+1
        status.Text='Буфер недоступен: текст выделен для ручного копирования'
    end)
    connect(close.Activated,function()handle:Destroy()end)
    connect(gui.Destroying,function()handle:Destroy()end)
    local dragging,start,origin
    local function fit()
        local area=safe.AbsoluteSize;if area.X<=0 or area.Y<=0 then return end
        scale.Scale=math.max(.1,math.min(1,(area.X-16)/360,(area.Y-16)/480))
        local x=window.Position.X.Scale*area.X+window.Position.X.Offset;local y=window.Position.Y.Scale*area.Y+window.Position.Y.Offset
        window.Position=UDim2.fromOffset(math.clamp(x,0,math.max(0,area.X-360*scale.Scale)),math.clamp(y,0,math.max(0,area.Y-480*scale.Scale)))
    end
    connect(safe:GetPropertyChangedSignal('AbsoluteSize'),fit);fit()
    connect(header.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=input;start=input.Position;origin=window.Position end
    end)
    connect(game:GetService('UserInputService').InputChanged,function(input)
        if dragging and (input==dragging or input.UserInputType==Enum.UserInputType.MouseMovement)then
            local delta=input.Position-start;window.Position=UDim2.fromOffset(origin.X.Offset+delta.X,origin.Y.Offset+delta.Y);fit()
        end
    end)
    connect(game:GetService('UserInputService').InputEnded,function(input)if input==dragging then dragging=nil end end)
    local revision=-1;local nextUI=0
    connect(game:GetService('RunService').Heartbeat,function()
        if env[KEY]~=handle or game.JobId~=handle.JobId or gui.Parent~=player:FindFirstChild('PlayerGui')then handle:Destroy();return end
        if os.clock()<nextUI then return end;nextUI=os.clock()+.1
        broad.Text=os.clock()<engine.BroadUntil and ('Все Remote: '..math.ceil(engine.BroadUntil-os.clock())..' с') or 'Поймать все Remote на 10 секунд'
        if revision~=engine.Revision then revision=engine.Revision;render()end
    end)
    local tween=game:GetService('TweenService'):Create(gradient,TweenInfo.new(10,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,false),{Rotation=375})
    tweens[#tweens+1]=tween;tween:Play();render()
end)
if not ok then handle:Destroy();error('[NPC Hit Diagnostic] '..tostring(why))end
return handle
