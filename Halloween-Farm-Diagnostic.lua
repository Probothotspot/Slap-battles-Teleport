-- Halloween Farm Diagnostic v1.0.0 | Probothotspot
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
                Match=broad and '30-second broad capture' or #ctx.Targets>0 and 'NPC instance argument' or 'hit-like remote name; NPC not proven',
                Initiator=initiator,Stack=stack,LocalCharacter=context,Truncated=ctx.Truncated,Dropped=self.Dropped,Capabilities=c.Capabilities,
                Observation='Outgoing client request only; server response/damage not observed'}
            local parts={};local reproducible=not ctx.Truncated and remoteInfo.Expression~=nil
            for _,value in ipairs(values)do local part=code(value);if not part then reproducible=false;break end;parts[#parts+1]=part end
            if reproducible then report.CallPreview=remoteInfo.Expression..':'..method..'('..table.concat(parts,', ')..')'
            else report.CallPreview='Unavailable: arguments/path truncated or unsupported; do not treat this as a complete replay' end
            self.Reports[#self.Reports+1]=report
            if #self.Reports>32 then table.remove(self.Reports,1) end
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
-- Bounded client-state recorder; no teleport, input simulation or server requests.
local Monitor={}
local categories={UI=700,State=350,Door=250,Prompt=200,NPC=64,CandyHint=160}
local function signature(v)
    if type(v)~='table'then return type(v)..':'..tostring(v)end
    local keys={};for k in pairs(v)do keys[#keys+1]=k end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local out={};for _,k in ipairs(keys)do out[#out+1]=signature(k)..'='..signature(v[k])end
    return '{'..table.concat(out,';')..'}'
end
function Monitor.parse(text)
    text=tostring(text or ''):gsub('<[^>]->','');local lower=text:lower();local out={}
    local round=lower:match('round%s*[:#%-]?%s*(%d+)')
    local collect=lower:match('collect%s+([%d,%s%.]+)%s+candy')
    local first,second=lower:match('(%d[%d,%s]*)%s*/%s*(%d[%d,%s]*)')
    local function number(s)return s and tonumber((s:gsub('[,%s]','')))end
    if round then out.Round=tonumber(round)end
    if collect then out.CollectionGoal=number(collect)end
    if first then out.Ratio={Current=number(first),Goal=number(second),Meaning='Unassigned; denominator is NOT confirmed backpack capacity'}end
    if lower:match('^%s*%d+%s*$')then out.NumericLabel=number(lower)end
    if lower:find('accept candy',1,true)then out.AcceptCandy=true end
    if lower:find('full',1,true)then out.FullTextHint=true end
    return out
end
function Monitor.new(c)
    local clock=c.Clock or os.clock
    local self={Destroyed=false,Buckets={},Events={},EventCount=0,EventDropped=0,Snapshots={},SnapshotCount=0,
        Dirty={},Stack={},Ready=false,Scanned=0,NextSweep=math.huge,NextPoll=0,Poll={},PollIndex=1,Revision=0,
        Ids=setmetatable({},{__mode='k'}),NextId=0,LastChange=setmetatable({},{__mode='k'}),DroppedChanges=0}
    for name,limit in pairs(categories)do self.Buckets[name]={Order={},Index={},Data={},Signs={},Limit=limit,Overflow=0}end
    local function resetScan()
        self.Stack={};local roots=c.Roots();for i=#roots,1,-1 do self.Stack[#self.Stack+1]={Node=roots[i]}end
    end
    resetScan()
    function self:event(kind,data)
        if self.Destroyed then return end
        self.EventCount=self.EventCount+1
        self.Events[#self.Events+1]={Id=self.EventCount,After=clock()-c.Started,Kind=kind,Data=data}
        if #self.Events>180 then table.remove(self.Events,1);self.EventDropped=self.EventDropped+1 end
        self.Revision=self.Revision+1
    end
    function self:id(object)
        if not self.Ids[object]then self.NextId=self.NextId+1;self.Ids[object]=self.NextId end
        return self.Ids[object]
    end
    function self:add(object)
        if self.Destroyed or c.Skip(object)then return end
        local good,names=pcall(c.Classify,object)
        if not good then self.LastError=tostring(names);return end
        local accepted=false
        for _,name in ipairs(names)do
            local b=self.Buckets[name]
            if b and not b.Index[object]then
                if #b.Order>=b.Limit then b.Overflow=b.Overflow+1
                else b.Order[#b.Order+1]=object;b.Index[object]=#b.Order;accepted=true end
            end
        end
        if accepted then self:dirty(object);if c.Track then pcall(c.Track,object,names)end end
    end
    function self:dirty(object)
        if not self.Destroyed then self.Dirty[object]=true end
    end
    function self:remove(object)
        self.Dirty[object]=nil
        for name,b in pairs(self.Buckets)do
            local i=b.Index[object]
            if i then
                local last=b.Data[object]
                if last and self.Ready then self:event('Removed '..name,{ObjectId=last.ObjectId,FullPath=last.FullPath,Note='Disappearance is not proof of a kill or collection'})end
                local tail=table.remove(b.Order);b.Index[object]=nil;b.Data[object]=nil;b.Signs[object]=nil
                if i<=#b.Order then b.Order[i]=tail;b.Index[tail]=i end
            end
        end
        if c.Untrack then pcall(c.Untrack,object)end
    end
    function self:read(object)
        if not c.Alive(object)then self:remove(object);return end
        for name,b in pairs(self.Buckets)do if b.Index[object]then
            local ok,data=pcall(c.Read,object,name)
            if ok and data then
                data.ObjectId=self:id(object);data.SampledAfter=clock()-c.Started
                local sign=signature(c.ChangeKey(name,data));local before=b.Data[object]
                if b.Signs[object]and b.Signs[object]~=sign then
                    local now=clock();local last=self.LastChange[object]or -math.huge
                    if name~='UI' or now-last>=.25 then
                        self:event('Changed '..name,{Before=before,After=data});self.LastChange[object]=now
                    else self.DroppedChanges=self.DroppedChanges+1 end
                elseif not before and self.Ready and name~='UI'and name~='State'then self:event('Found '..name,data)end
                b.Data[object]=data;b.Signs[object]=sign
            elseif not ok then self.LastError=tostring(data)end
        end end
    end
    function self:request(reason)
        if self.Destroyed then return end
        if self.SnapshotTask then self.PendingSnapshot=reason;return end
        self.SnapshotCount=self.SnapshotCount+1
        local snapshot={Id=self.SnapshotCount,Reason=reason,StartedAfter=clock()-c.Started,Categories={},State='Collecting'}
        self.SnapshotTask=coroutine.create(function()
            for name,b in pairs(self.Buckets)do
                local rows={};snapshot.Categories[name]={Items=rows,Limit=b.Limit,OverflowAttempts=b.Overflow}
                local objects={table.unpack(b.Order)}
                for _,object in ipairs(objects)do
                    if not self.Destroyed and c.Alive(object)then
                        local ok,data=pcall(c.Read,object,name)
                        if ok and data then data.ObjectId=self:id(object);data.SampledAfter=clock()-c.Started;rows[#rows+1]=data
                        elseif not ok then snapshot.ReadErrors=(snapshot.ReadErrors or 0)+1 end
                    end
                    coroutine.yield()
                end
            end
            snapshot.Context=c.Context();snapshot.IndexReady=self.Ready;snapshot.Scanned=self.Scanned
            snapshot.FinishedAfter=clock()-c.Started;snapshot.State='Complete'
            self.Snapshots[#self.Snapshots+1]=snapshot
            -- Keep the initial snapshot plus the five most recent marked states.
            if #self.Snapshots>6 then table.remove(self.Snapshots,2)end
            self:event('Snapshot complete',{Id=snapshot.Id,Reason=reason,IndexReady=snapshot.IndexReady})
        end)
        self.SnapshotInProgress=snapshot;self.Revision=self.Revision+1
    end
    function self:step()
        if self.Destroyed then return end
        local started=clock();local steps=0
        if #self.Stack==0 and started>=self.NextSweep then resetScan();self.NextSweep=math.huge end
        while #self.Stack>0 and steps<384 and clock()-started<.0015 do
            steps=steps+1;local frame=self.Stack[#self.Stack]
            if not frame.Children then local ok,children=pcall(c.Children,frame.Node);frame.Children=ok and children or {};frame.Position=1
            elseif frame.Position>#frame.Children then table.remove(self.Stack)
            else
                local object=frame.Children[frame.Position];frame.Position=frame.Position+1;self.Scanned=self.Scanned+1
                if c.Alive(object)and not c.Skip(object)then self:add(object);self.Stack[#self.Stack+1]={Node=object}end
            end
        end
        if #self.Stack==0 and self.NextSweep==math.huge then
            local first=not self.Ready;self.Ready=true;self.NextSweep=clock()+5
            if first then self:request('Initial indexed state')end
        end
        local processed=0;started=clock()
        for object in pairs(self.Dirty)do
            if processed>=40 or clock()-started>=.0015 then break end
            self.Dirty[object]=nil;self:read(object);processed=processed+1
        end
        if self.PollIndex>#self.Poll and clock()>=self.NextPoll then
            self.Poll={};local seen={}
            for _,name in ipairs({'UI','State','Prompt','NPC','Door','CandyHint'})do
                for _,object in ipairs(self.Buckets[name].Order)do if not seen[object]then seen[object]=true;self.Poll[#self.Poll+1]=object end end
            end
            self.PollIndex=1;self.NextPoll=clock()+.5
        end
        processed=0;started=clock()
        while self.PollIndex<=#self.Poll and processed<32 and clock()-started<.0015 do
            local object=self.Poll[self.PollIndex];self.PollIndex=self.PollIndex+1;self:read(object);processed=processed+1
        end
        if self.SnapshotTask then
            processed=0;started=clock()
            while self.SnapshotTask and processed<24 and clock()-started<.0015 do
                processed=processed+1;local ok,why=coroutine.resume(self.SnapshotTask)
                if not ok then self.LastError=tostring(why);self.SnapshotInProgress.State='Error';self.SnapshotInProgress.Error=tostring(why);self.SnapshotTask=nil
                elseif coroutine.status(self.SnapshotTask)=='dead'then self.SnapshotTask=nil;self.SnapshotInProgress=nil end
            end
            if not self.SnapshotTask and self.PendingSnapshot then local reason=self.PendingSnapshot;self.PendingSnapshot=nil;self:request(reason)end
        end
    end
    function self:export()
        local function thinUI(d)
            if not d then return nil end
            local p=d.Properties or {}
            return{ObjectId=d.ObjectId,FullPath=d.FullPath,ClassName=d.ClassName,SampledAfter=d.SampledAfter,
                Properties={Text=p.Text,Image=p.Image,Enabled=p.Enabled},EffectiveVisible=d.EffectiveVisible,Parsed=d.Parsed,BagPathHint=d.BagPathHint}
        end
        local function archive(snapshot)
            local out={};for key,value in pairs(snapshot)do if key~='Categories'then out[key]=value end end
            out.Categories={}
            for name,b in pairs(snapshot.Categories or {})do
                local rows={};out.Categories[name]={Items=rows,Limit=b.Limit,OverflowAttempts=b.OverflowAttempts}
                for _,d in ipairs(b.Items)do
                    if name=='UI'then rows[#rows+1]=thinUI(d)
                    elseif (name=='Door'or name=='CandyHint')and snapshot.Id~=1 then
                        rows[#rows+1]={ObjectId=d.ObjectId,FullPath=d.FullPath,SampledAfter=d.SampledAfter}
                    else rows[#rows+1]=d end
                end
            end
            return out
        end
        local latest={}
        for name,b in pairs(self.Buckets)do
            latest[name]={Items={},Limit=b.Limit,OverflowAttempts=b.Overflow}
            for _,object in ipairs(b.Order)do if b.Data[object]then latest[name].Items[#latest[name].Items+1]=b.Data[object]end end
        end
        local snapshots={};for _,s in ipairs(self.Snapshots)do snapshots[#snapshots+1]=archive(s)end
        local events={};for _,e in ipairs(self.Events)do
            if e.Kind=='Changed UI'then events[#events+1]={Id=e.Id,After=e.After,Kind=e.Kind,Data={Before=thinUI(e.Data.Before),After=thinUI(e.Data.After)}}
            else events[#events+1]=e end
        end
        return{IndexReady=self.Ready,Scanned=self.Scanned,Latest=latest,Snapshots=snapshots,SnapshotInProgress=self.SnapshotInProgress and archive(self.SnapshotInProgress),
            HistoryFormat='UI history omits repeated layout fields; full layout in Latest. Door/candy geometry is stored in initial snapshot and Latest; later snapshots reference ObjectId/FullPath.',
            PendingSnapshot=self.PendingSnapshot,Events=events,EventCount=self.EventCount,EventDropped=self.EventDropped,
            CoalescedUIChanges=self.DroppedChanges,LastError=self.LastError,
            Interpretation='Round/collection goals/ratios are separate observations. Backpack capacity, kill credit and reward attribution are not automatically inferred.',
            Scope='Only replicated client-visible objects. Streaming may hide doors/NPCs. Snapshots span multiple frames and are not atomic.'}
    end
    function self:Destroy()self.Destroyed=true;self.Stack={};self.Dirty={};self.Poll={};self.SnapshotTask=nil;self.PendingSnapshot=nil end
    return self
end

-- BEGIN ROBLOX CLIENT
local Players=game:GetService('Players');local player=Players.LocalPlayer
assert(player,'Halloween Farm Diagnostic requires a client player')
local env=_G
if type(getgenv)=='function' then local ok,v=pcall(getgenv);if ok and type(v)=='table' then env=v end end
local KEY,HOOK='ProbothotspotHalloweenFarmDiagnostic','ProbothotspotNPCHitHook'
local previousDiagnostic=env.ProbothotspotNPCHitDiagnostic
if type(previousDiagnostic)=='table'and type(previousDiagnostic.Destroy)=='function'then previousDiagnostic:Destroy()end
local previous=env[KEY];if type(previous)=='table' and type(previous.Destroy)=='function' then previous:Destroy() end
local pg=player:WaitForChild('PlayerGui',10);assert(pg,'PlayerGui unavailable')
local connections,tweens={},{};local cleanupObjects;local gui,engine,dispatcher,listener,monitor
local handle={Version='1.0.0',JobId=game.JobId,Destroyed=false};env[KEY]=handle
local function connect(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
function handle:Destroy()
    if self.Destroyed then return end;self.Destroyed=true
    if engine then engine:Destroy() end
    if monitor then monitor:Destroy()end
    if cleanupObjects then cleanupObjects()end
    if dispatcher and dispatcher.Listener==listener then dispatcher.Listener=nil end
    for _,c in ipairs(connections)do c:Disconnect()end
    for _,t in ipairs(tweens)do pcall(function()t:Cancel()end)end
    if gui then gui:Destroy()end
    if env[KEY]==self then env[KEY]=nil end
end
local function api(name)
    local direct={hookmetamethod=hookmetamethod,getnamecallmethod=getnamecallmethod,hookfunction=hookfunction,
        newcclosure=newcclosure,checkcaller=checkcaller,getcallingscript=getcallingscript,setclipboard=setclipboard,
        identifyexecutor=identifyexecutor,toclipboard=toclipboard,fireproximityprompt=fireproximityprompt,
        firesignal=firesignal,firetouchinterest=firetouchinterest,getconnections=getconnections}
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
local started=os.clock();local objectConnections={};local promptShown=setmetatable({},{__mode='k'})
local function packed(v)
    local kind=typeof(v)
    if kind=='nil'then return nil end
    if kind=='number'then return finite(v)and v or tostring(v)end
    if kind=='boolean'then return v end
    if kind=='string'then
        if utf8 and not utf8.len(v)then return{Encoding='hex',Value=(v:sub(1,128):gsub('.',function(ch)return string.format('%02x',string.byte(ch))end)),Truncated=true}end
        return #v>768 and {Text=clip(v,768),Truncated=true,OriginalBytes=#v}or v
    end
    if kind=='Instance'then return{FullPath=path(v),ClassName=v.ClassName}end
    if kind=='Vector3'then return vector(v)end
    if kind=='Vector2'then return{X=v.X,Y=v.Y}end
    if kind=='CFrame'then return{Components={v:GetComponents()}}end
    if kind=='Color3'then return{R=v.R,G=v.G,B=v.B}end
    return tostring(v)
end
local function props(object,names)
    local data={}
    for _,name in ipairs(names)do local ok,v=pcall(function()return packed(object[name])end);if ok and v~=nil then data[name]=v end end
    return data
end
local function attributes(object)
    local ok,values=pcall(function()return object:GetAttributes()end);if not ok then return{ReadError=clip(tostring(values),150)}end
    local out={};local count=0
    for key,v in pairs(values)do count=count+1;if count>40 then out.__Truncated=true;break end
        local good,plain=pcall(packed,v);if good then out[key]=plain end
    end
    return out
end
local function semantic(text)
    text=text:lower()
    for _,word in ipairs({'round','wave','candy','corn','bag','backpack','capacity','carry','goal','consum','halloween','boss','progress','inventory','eventdata','gamedata','full'})do
        if text:find(word,1,true)then return true end
    end
    return false
end
local function ownUI(object)return gui and (object==gui or object:IsDescendantOf(gui))end
local function skip(object)
    if ownUI(object)or object:IsA('KeyframeSequence')or object:IsA('Pose')then return true end
    -- Do not collect chat transcripts from custom chat GUIs.
    if object:IsDescendantOf(pg)then
        local p=object
        for _=1,64 do
            if not p or p==pg then break end
            if p.Name:lower():find('chat',1,true)then return true end
            p=p.Parent
        end
    end
    return false
end
local function npcHuman(human)
    local model=human.Parent
    if not model or not model:IsA('Model')or not model:IsDescendantOf(workspace)then return nil end
    for _,candidate in ipairs(Players:GetPlayers())do
        if candidate.Character and (model==candidate.Character or model:IsDescendantOf(candidate.Character))then return nil end
    end
    return model
end
local function ancestorHuman(object)
    local p=object.Parent;local depth=0
    while p and p~=workspace and depth<64 do
        if p:IsA('Model')then local h=p:FindFirstChildOfClass('Humanoid');if h then return h end end
        p=p.Parent;depth=depth+1
    end
end
local function doorAncestor(object)
    local p=object.Parent
    for _=1,16 do if not p or p==workspace then return end;if p.Name=='Door'then return p end;p=p.Parent end
end
local function classify(object)
    local out={};local full=path(object)
    if object:IsDescendantOf(pg)and (object:IsA('GuiObject')or object:IsA('ScreenGui'))then out[#out+1]='UI'end
    if object==player or object==workspace or object==game:GetService('ReplicatedStorage')or object==player.Character
        or semantic(object.Name)or object:IsA('ValueBase')and (object:IsDescendantOf(player)or semantic(full))then out[#out+1]='State'end
    if object:IsA('BasePart')and (object.Name=='CollisionBox'or object.Name=='DoorInnerTouch')and doorAncestor(object)then out[#out+1]='Door'end
    if object:IsA('ProximityPrompt')then out[#out+1]='Prompt'end
    if object:IsA('Humanoid')and npcHuman(object)then out[#out+1]='NPC'end
    if object:IsA('BasePart')and object.Name:lower():find('candy',1,true)and not ancestorHuman(object)then out[#out+1]='CandyHint'end
    return out
end
local function effectiveVisible(object)
    local p=object
    for _=1,64 do
        if not p or p==game then return true end
        if p:IsA('GuiObject')and not p.Visible then return false end
        if p:IsA('ScreenGui')and not p.Enabled then return false end
        if p:IsA('CanvasGroup')and p.GroupTransparency>=.99 then return false end
        p=p.Parent
    end
    return false
end
local function common(object)
    local full,expression=path(object)
    return{Name=object.Name,ClassName=object.ClassName,FullPath=full,Expression=expression,ParentPath=object.Parent and path(object.Parent)}
end
local function readUI(object)
    local d=common(object);d.Properties=props(object,{'Text','Image','Visible','Enabled','Active','Interactable','Selectable','AbsolutePosition','AbsoluteSize','Position','Size','AnchorPoint','ZIndex','DisplayOrder','GroupTransparency','TextTransparency','ImageTransparency'})
    d.EffectiveVisible=effectiveVisible(object);d.VisibilityNote='Ancestor visibility only; clipping/overlays/occlusion not tested'
    if type(d.Properties.Text)=='string'then d.Parsed=Monitor.parse(d.Properties.Text)end
    d.BagPathHint=d.FullPath:lower():find('backpack',1,true)~=nil or d.FullPath:lower():find('capacity',1,true)~=nil
    return d
end
local function readObject(object,category)
    local d=common(object)
    if category=='UI'then return readUI(object)end
    d.Attributes=attributes(object)
    if category=='State'then
        if object:IsA('ValueBase')then d.Properties=props(object,{'Value'})end
        d.SemanticHint=semantic(d.FullPath);d.Meaning='Candidate data source; field semantics require comparison with gameplay'
    elseif category=='Door'then
        local parent=doorAncestor(object);d.DoorPath=parent and path(parent)
        d.Properties=props(object,{'CFrame','Position','Size','Anchored','CanCollide','CanTouch','CanQuery','Transparency'})
        d.ThinAxis=object.Size.X<object.Size.Z and 'X'or 'Z'
        d.Note='Door candidate by physical class/name/ancestry; neither color nor fixed coordinates. Front/outside direction not established.'
        d.ParentChildren={};if parent then for i,child in ipairs(parent:GetChildren())do if i>20 then break end;d.ParentChildren[#d.ParentChildren+1]=common(child)end end
    elseif category=='Prompt'then
        d.Properties=props(object,{'Enabled','ActionText','ObjectText','HoldDuration','MaxActivationDistance','RequiresLineOfSight','KeyboardKeyCode','GamepadKeyCode','Style','Exclusivity'})
        local parent=doorAncestor(object);d.DoorPath=parent and path(parent);d.PromptShownObserved=promptShown[object]==true
    elseif category=='NPC'then
        local model=npcHuman(object);if not model then return end
        d.ModelPath=path(model);d.ModelAttributes=attributes(model);d.Properties=props(object,{'Health','MaxHealth','WalkSpeed','HipHeight','RigType','MoveDirection'})
        local ok,tags=pcall(function()return model:GetTags()end);if ok then d.Tags={};for i=1,math.min(#tags,32)do d.Tags[i]=tags[i]end end
        d.Parts={}
        for _,child in ipairs(model:GetChildren())do
            if child:IsA('BasePart')and (#d.Parts<16)then
                local part=common(child);part.Attributes=attributes(child);part.Properties=props(child,{'Position','Size','CFrame','CanCollide','CanTouch','CanQuery','Transparency'})
                d.Parts[#d.Parts+1]=part
            end
        end
    elseif category=='CandyHint'then
        d.Properties=props(object,{'Position','Size','CanTouch','CanCollide','CanQuery','Transparency'})
        d.Note='Name-based loose-candy candidate without a currently visible Humanoid; pickup mechanism/reward not confirmed'
    end
    return d
end
local function changeKey(category,d)
    local p=d.Properties or {}
    if category=='UI'then return{Text=p.Text,Image=p.Image,Visible=d.EffectiveVisible,Enabled=p.Enabled}end
    if category=='NPC'then return{HP=p.Health,Max=p.MaxHealth,Attributes=d.ModelAttributes}end
    if category=='Prompt'then return{Enabled=p.Enabled,Action=p.ActionText,Object=p.ObjectText,Shown=d.PromptShownObserved,Attributes=d.Attributes}end
    if category=='State'then return{Properties=d.Properties,Attributes=d.Attributes}end
    return{Attributes=d.Attributes,CanTouch=p.CanTouch,CanCollide=p.CanCollide,Size=p.Size}
end
local function untrack(object)
    local list=objectConnections[object];if list then for _,conn in ipairs(list)do conn:Disconnect()end;objectConnections[object]=nil end
end
local function track(object,names)
    if objectConnections[object]then return end
    local list={};objectConnections[object]=list
    local function watch(signal,fn)local ok,conn=pcall(function()return signal:Connect(fn)end);if ok then list[#list+1]=conn end end
    local function property(name)
        local ok,signal=pcall(function()return object:GetPropertyChangedSignal(name)end)
        if ok then watch(signal,function()if monitor then monitor:dirty(object)end end)end
    end
    for _,name in ipairs(names)do
        if name=='UI'then
            if object:IsA('GuiObject')then property('Visible')end
            if object:IsA('ScreenGui')then property('Enabled')end
            if object:IsA('TextLabel')or object:IsA('TextButton')or object:IsA('TextBox')then property('Text')end
            if object:IsA('ImageLabel')or object:IsA('ImageButton')then property('Image')end
            if object:IsA('GuiButton')then watch(object.Activated,function()
                if not monitor or monitor.Destroyed then return end
                local details=readUI(object);details.Neighbours={}
                if object.Parent then for i,child in ipairs(object.Parent:GetChildren())do
                    if i>20 then break end
                    if child:IsA('GuiObject')then details.Neighbours[#details.Neighbours+1]=readUI(child)end
                end end
                monitor:event('Manual GUI activation',details);monitor:dirty(object)
            end)end
        elseif name=='State'then
            if object:IsA('ValueBase')then property('Value')end
            local ok,signal=pcall(function()return object.AttributeChanged end);if ok and signal then watch(signal,function()if monitor then monitor:dirty(object)end end)end
        elseif name=='NPC'then property('Health')end
    end
end
local firstPosition
local function context()
    local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
    local human=char and char:FindFirstChildOfClass('Humanoid')
    if not firstPosition and root then firstPosition=props(root,{'CFrame','Position'})end
    return{Character=char and path(char),Health=human and human.Health,Position=root and vector(root.Position),FirstPosition=firstPosition,
        PlayerAttributes=attributes(player),CharacterAttributes=char and attributes(char),WorldAttributes=attributes(workspace),
        Streaming=props(workspace,{'StreamingEnabled','StreamingMinRadius','StreamingTargetRadius'}),
        BackpackCapacity='Unconfirmed: collection goal and bag capacity must be identified independently'}
end

cleanupObjects=function()for object in pairs(objectConnections)do untrack(object)end end
local capabilities={}
for _,name in ipairs({'hookmetamethod','getnamecallmethod','hookfunction','newcclosure','checkcaller','getcallingscript','setclipboard','fireproximityprompt','firesignal','firetouchinterest','getconnections'})do capabilities[name]=api(name)~=nil end
capabilities.APIAvailabilityNote='Names present only; input/interaction APIs are not invoked or proven operational by this diagnostic'
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
    gui=make('ScreenGui',{Name='HalloweenFarmDiagnosticGUI',ResetOnSpawn=false,DisplayOrder=1400,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg);handle.Gui=gui
    local safe=make('Frame',{Name='SafeArea',Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
    local window=make('Frame',{Name='Window',Size=UDim2.fromOffset(380,540),Position=UDim2.new(.5,-190,.5,-270),
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
    local title=label('Title','Halloween Farm Test 1.0.0',14,0,300,44,15,header);title.Font=Enum.Font.GothamBold
    local close=button('Close','×',340,8,28,28)
    label('Instructions','Открой дверь → accept candy → собери конфеты → скопируй отчёт.',15,47,350,34,12,window)
    local status=label('Status','Установка наблюдения…',15,82,350,34,11,window)
    local count=label('Count','Записей: 0',15,119,250,20,11,window)
    local prev=button('Previous','<',303,118,28,22);local nextButton=button('Next','>',340,118,28,22)
    local scroll=make('ScrollingFrame',{Name='ReportScroll',Position=UDim2.fromOffset(15,146),Size=UDim2.fromOffset(350,275),
        BackgroundColor3=Color3.fromRGB(92,42,139),BackgroundTransparency=.12,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,275)},window);round(scroll)
    local box=make('TextBox',{Name='Report',Text='',Position=UDim2.fromOffset(7,6),Size=UDim2.fromOffset(332,265),BackgroundTransparency=1,
        TextColor3=Color3.fromRGB(253,239,255),Font=Enum.Font.Code,TextSize=11,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,ClearTextOnFocus=false,MultiLine=true,TextEditable=true},scroll)
    local toggle=button('Record','RPC: ON',15,431,168,32);local copy=button('Copy','Копировать всё',197,431,168,32)
    local broad=button('Broad','Remote: запись на 30 секунд',15,472,168,30)
    local snap=button('Snapshot','Снимок / метка этапа',197,472,168,30)
    label('Credit','By: Probothotspot | Пассивная диагностика, без фарма',15,514,350,14,9,window)
    monitor=Monitor.new({Started=started,Roots=function()return{pg,player,workspace,game:GetService('ReplicatedStorage')}end,Skip=skip,Classify=classify,Read=readObject,ChangeKey=changeKey,
        Children=function(o)
            if o==player then local list={};for _,child in ipairs(o:GetChildren())do if child~=pg then list[#list+1]=child end end;return list end
            return o:GetChildren()
        end,Alive=function(o)return o.Parent~=nil and not ownUI(o)end,Track=track,Untrack=untrack,Context=context});handle.Monitor=monitor
    monitor:add(player);monitor:add(workspace);monitor:add(game:GetService('ReplicatedStorage'))
    context()
    engine=Diagnostic.new({Kind=typeof,Describe=describe,Value=value,Caller=caller,Capabilities=capabilities,Epoch=os.time,
        PlaceId=game.PlaceId,JobId=game.JobId,Context=function()
            local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
            local human=char and char:FindFirstChildOfClass('Humanoid');local tool=char and char:FindFirstChildOfClass('Tool')
            local stats=player:FindFirstChild('leaderstats');local glove=stats and stats:FindFirstChild('Glove')
            return{CharacterPath=char and path(char),Position=root and vector(root.Position),Health=human and human.Health,
                EquippedTool=tool and tool.Name,ToolPath=tool and path(tool),
                Glove=glove and glove:IsA('StringValue') and glove.Value or nil}
        end});handle.Engine=engine
    for _,key in ipairs({'ProbothotspotNPCGeneralHit','ProbothotspotLanternAutoHit'})do
        local auto=env[key]or _G[key]
        if type(auto)=='table'and auto.JobId==game.JobId and auto.Engine and auto.Engine.Enabled then
            auto.Engine:setEnabled(false);capabilities[key..'Paused']=true
        end
    end
    engine.BroadUntil=os.clock()+30
    local promptService=game:GetService('ProximityPromptService')
    connect(promptService.PromptShown,function(prompt,inputType)
        promptShown[prompt]=true;monitor:add(prompt);monitor:dirty(prompt)
        local d=readObject(prompt,'Prompt');d.InputType=tostring(inputType);monitor:event('Prompt shown',d)
    end)
    connect(promptService.PromptHidden,function(prompt)
        promptShown[prompt]=false;monitor:dirty(prompt);monitor:event('Prompt hidden',{FullPath=path(prompt)})
    end)
    connect(promptService.PromptTriggered,function(prompt,who)
        if who and who~=player then return end
        monitor:event('Manual prompt triggered',readObject(prompt,'Prompt'));monitor:request('After door prompt')
    end)
    for _,root in ipairs({workspace,game:GetService('ReplicatedStorage'),player})do
        connect(root.DescendantAdded,function(object)monitor:add(object)end)
        connect(root.DescendantRemoving,function(object)monitor:remove(object)end)
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
        if os.clock()<engine.BroadUntil then engine:capture(remote,method,args,origin)end
    end
    dispatcher.Listener=listener
    local http=game:GetService('HttpService');local selected
    local function current()
        for _,report in ipairs(engine.Reports)do if report.Id==selected then return report end end
        return engine.Reports[#engine.Reports]
    end
    local function render()
        local report=current();local b=monitor.Buckets
        local lines={'=== HALLOWEEN FARM: ИСТОЧНИКИ ДАННЫХ ===',
            'Индекс: '..(monitor.Ready and 'готов (видимые клиенту объекты)'or 'обход в фоне')..' | проверено: '..monitor.Scanned,
            'Дверей: '..#b.Door.Order..' | Prompt: '..#b.Prompt.Order..' | NPC: '..#b.NPC.Order,
            'UI: '..#b.UI.Order..' | Данные: '..#b.State.Order..' | Конфеты-кандидаты: '..#b.CandyHint.Order,
            'Снимков: '..#monitor.Snapshots..' | событий: '..monitor.EventCount,
            monitor.SnapshotInProgress and ('Снимок: '..monitor.SnapshotInProgress.State)or 'Снимок: нет незавершённого задания',
            '', 'Найденные подписи (это разные показатели):'}
        local candidates=0
        for _,object in ipairs(b.UI.Order)do
            local d=b.UI.Data[object];local parsed=d and d.Parsed
            if d and d.EffectiveVisible and parsed and (parsed.Round or parsed.CollectionGoal or parsed.Ratio or parsed.AcceptCandy)then
                lines[#lines+1]=tostring(d.Properties.Text)..' | '..d.FullPath;candidates=candidates+1
                if candidates>=10 then break end
            end
        end
        lines[#lines+1]='Вместимость рюкзака пока не установлена; цель раунда не считается вместимостью.'
        lines[#lines+1]='';lines[#lines+1]='Последние события:'
        for i=math.max(1,#monitor.Events-5),#monitor.Events do
            local e=monitor.Events[i];lines[#lines+1]=string.format('+%.1f с | %s',e.After,e.Kind)
        end
        if report then
            lines[#lines+1]='';lines[#lines+1]='Последний выбранный RPC: '..report.Remote.FullPath..':'..report.Method
            lines[#lines+1]=report.CallPreview
        end
        lines[#lines+1]='';lines[#lines+1]='Полные пути, свойства, изменения и RPC — «Копировать всё».'
        handle.ReportText=table.concat(lines,'\n');box.Text=handle.ReportText
        local h=0;for segment in (box.Text..'\n'):gmatch('(.-)\n')do h=h+math.max(1,math.ceil((utf8.len(segment)or #segment)/46))*14 end
        h=math.max(265,h);box.Size=UDim2.fromOffset(332,h);scroll.CanvasSize=UDim2.fromOffset(0,h+12)
        count.Text='RPC: '..#engine.Reports..' | выбрана: '..tostring(report and report.Id or '—')
        toggle.Text=engine.Recording and 'RPC: ON'or 'RPC: OFF'
        if monitor.LastError then status.Text='Ошибка снимка: '..monitor.LastError
        elseif not dispatcher.Ready then status.Text='UI/данные пишутся. Перехват RPC недоступен; возможности будут в отчёте.'
        else status.Text='Пассивная запись. Сделай действия вручную; перед копированием нажми «Снимок».'end
    end
    connect(toggle.Activated,function()engine.Recording=not engine.Recording;dispatcher.Listener=engine.Recording and listener or nil;if engine.Recording then engine.BroadUntil=os.clock()+30 end;render()end)
    connect(broad.Activated,function()engine.Recording=true;dispatcher.Listener=listener;engine.BroadUntil=os.clock()+30;render()end)
    connect(prev.Activated,function()
        local report=current();for i,item in ipairs(engine.Reports)do if report and item.Id==report.Id then selected=engine.Reports[math.max(1,i-1)].Id;break end end;render()
    end)
    connect(nextButton.Activated,function()
        local report=current();for i,item in ipairs(engine.Reports)do if report and item.Id==report.Id then selected=i<#engine.Reports and engine.Reports[i+1].Id or nil;break end end;render()
    end)
    connect(snap.Activated,function()monitor:event('User stage marker',{Context=context()});monitor:request('User stage marker');render()end)
    connect(copy.Activated,function()
        render()
        local report=current()
        local good,all=pcall(function()return http:JSONEncode({Schema=1,Version='1.0.0',Capabilities=capabilities,
            StateMonitor=monitor:export(),CurrentContext=context(),SelectedId=report and report.Id,Reports=engine.Reports,TotalObserved=engine.Sequence,Dropped=engine.Dropped,LastError=engine.LastError})end)
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
        scale.Scale=math.max(.1,math.min(1,(area.X-16)/380,(area.Y-16)/540))
        local x=window.Position.X.Scale*area.X+window.Position.X.Offset;local y=window.Position.Y.Scale*area.Y+window.Position.Y.Offset
        window.Position=UDim2.fromOffset(math.clamp(x,0,math.max(0,area.X-380*scale.Scale)),math.clamp(y,0,math.max(0,area.Y-540*scale.Scale)))
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
    local nextUI=0
    connect(game:GetService('RunService').Heartbeat,function()
        if env[KEY]~=handle or game.JobId~=handle.JobId or gui.Parent~=player:FindFirstChild('PlayerGui')then handle:Destroy();return end
        local good,problem=pcall(function()monitor:step()end)
        if not good then monitor.LastError=tostring(problem)end
        if os.clock()<nextUI then return end;nextUI=os.clock()+.5
        broad.Text=os.clock()<engine.BroadUntil and ('Remote: '..math.ceil(engine.BroadUntil-os.clock())..' с') or 'Remote: ещё 30 секунд'
        render()
    end)
    local tween=game:GetService('TweenService'):Create(gradient,TweenInfo.new(10,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,false),{Rotation=375})
    tweens[#tweens+1]=tween;tween:Play();render()
end)
if not ok then handle:Destroy();error('[Halloween Farm Diagnostic] '..tostring(why))end
return handle
