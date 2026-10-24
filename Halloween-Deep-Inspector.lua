-- Halloween Deep Inspector v1.0.0 | Probothotspot
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

-- Ranked evidence, never an invented server capacity or RPC signature.
local Deep={}
local weights={capacity=12,maxcarry=12,carrylimit=12,baglimit=12,maxcandy=12,maxcandies=12,backpack=7,inventory=3,candy=4,corn=2,round=3,wave=2,limit=4,collect=2,accept=2,fireserver=3,invokeserver=3}
function Deep.score(text)
    text=tostring(text or ''):lower():gsub('[%s_%-]','');local n=0
    for word,value in pairs(weights)do if text:find(word,1,true)then n=n+value end end
    return n
end
function Deep.topic(text)
    text=tostring(text):lower():gsub('[%s_%-]','')
    if text:find('capacity',1,true)or text:find('maxcarry',1,true)or text:find('baglimit',1,true)or text:find('maxcand',1,true)then return'Bag/carry limit candidate'end
    if text:find('fireserver',1,true)or text:find('invokeserver',1,true)then return'Client RPC code candidate'end
    if text:find('round',1,true)or text:find('wave',1,true)then return'Round/goal candidate'end
    return'Game data candidate'
end
function Deep.new(c)
    local clock=c.Clock or os.clock
    local began=clock()
    local self={Destroyed=false,Ready=false,Scanned=0,Objects={},ObjectCount=0,ObjectOverflow=0,Scripts={},ScriptMap={},ScriptOverflow=0,
        Findings={},FindingCount=0,FindingOverflow=0,Seen={},Tasks={},Stack={},Revision=0,NextId=0,Ids=setmetatable({},{__mode='k'}),SourceReads=0,SourceErrors=0,Values={},Remotes={}}
    for i=#c.Roots,1,-1 do self.Stack[#self.Stack+1]={Node=c.Roots[i]}end
    function self:put(record)
        local key=record.Kind..'|'..record.Path..'|'..tostring(record.Line or record.Field or '')..'|'..tostring(record.Text or '')
        if self.Seen[key]then return end;self.Seen[key]=true;self.FindingCount=self.FindingCount+1
        record.CollectedAfter=clock()-began
        record.Score=record.Score or Deep.score((record.Field or '')..' '..(record.Text or '')..' '..record.Path)
        record.Topic=Deep.topic((record.Field or '')..' '..(record.Text or '')..' '..record.Path)
        record.Note=record.Note or 'Client evidence only; active server rules and exact RPC arguments are not established by static values.'
        if #self.Findings>=350 then
            local lowest=1;for i=2,#self.Findings do if self.Findings[i].Score<self.Findings[lowest].Score then lowest=i end end
            if record.Score>self.Findings[lowest].Score then self.Findings[lowest]=record end
            self.FindingOverflow=self.FindingOverflow+1
        else self.Findings[#self.Findings+1]=record end
        self.Revision=self.Revision+1
    end
    function self:discover(object,origin)
        if self.Destroyed or c.Skip(object)then return end
        if not self.Ids[object]then self.NextId=self.NextId+1;self.Ids[object]=self.NextId else return end
        local ok,data=pcall(c.Meta,object)
        if not ok then self.LastError=tostring(data);return end
        data.ObjectId=self.Ids[object];data.Discovery=origin or 'Hierarchy'
        self.ObjectCount=self.ObjectCount+1
        if #self.Objects<10000 then self.Objects[#self.Objects+1]=data else self.ObjectOverflow=self.ObjectOverflow+1 end
        if data.IsScript then
            if #self.Scripts<1200 then
                local item={Object=object,Path=data.FullPath,ClassName=data.ClassName,Priority=Deep.score(data.FullPath),Status='Pending',Discovery=data.Discovery,InGameRoots=data.InGameRoots}
                self.Scripts[#self.Scripts+1]=item;self.ScriptMap[object]=item
            else self.ScriptOverflow=self.ScriptOverflow+1 end
        end
        if data.Remote and #self.Remotes<600 then self.Remotes[#self.Remotes+1]=data end
        if data.IsValue then
            local ok,value=pcall(c.Value,object)
            if ok then
                if #self.Values<2000 then self.Values[#self.Values+1]={Path=data.FullPath,Value=value,ClassName=data.ClassName}end
                if Deep.score(data.FullPath..' '..tostring(value))>=4 then self:put({Kind='Replicated value',Path=data.FullPath,Field='Value',Value=value,Text=tostring(value)})end
            end
        end
        local good,attrs=pcall(c.Attributes,object)
        if good then
            local n=0;for key,value in next,attrs do
                n=n+1;if n>40 then break end
                if Deep.score(tostring(key)..' '..tostring(value))>=4 then
                    self:put({Kind='Replicated attribute',Path=data.FullPath,Field=tostring(key),Value=c.Plain(value),Text=tostring(key)..' = '..tostring(value)})
                end
            end
        end
    end
    function self:nextScript()
        local best
        for _,item in ipairs(self.Scripts)do if item.Status=='Pending'and(not best or item.Priority>best.Priority)then best=item end end
        if best then best.Status='Reading' end
        return best
    end
    function self:source(item,text,origin,reason)
        if self.Destroyed then return end
        if type(text)~='string'or #text==0 then
            item.Status='Unavailable';item.Error=clip(tostring(reason or 'No readable source'),300);self.SourceErrors=self.SourceErrors+1;self.Revision=self.Revision+1;return
        end
        self.SourceReads=self.SourceReads+1;item.Status='Searching';item.SourceOrigin=origin;item.SourceBytes=#text
        if #text>393216 then text=clip(text,393216);item.SourceTruncated=true end
        self.Tasks[#self.Tasks+1]=coroutine.create(function()
            local lines={};for line in (text..'\n'):gmatch('(.-)\n')do
                if #lines>=8000 then item.SourceTruncated=true;break end
                if #line>1600 then item.SourceTruncated=true end
                lines[#lines+1]=clip(line,1600);coroutine.yield()
            end
            local hits=0
            for i,line in ipairs(lines)do
                local score=Deep.score(line)
                if score>=4 or line:find('FireServer',1,true)or line:find('InvokeServer',1,true)then
                    local first,last=math.max(1,i-1),math.min(#lines,i+2);local context={}
                    for j=first,last do context[#context+1]=j..': '..lines[j]end
                    local snippet=clip(table.concat(context,'\n'),2600)
                    self:put({Kind='Client source',Path=item.Path,Line=i,Text=snippet,Score=Deep.score(snippet),SourceOrigin=origin,
                        Note='Read/decompiled client text; constants, comments and branches may be unused. This does not prove the active server capacity.'})
                    hits=hits+1;if hits>=30 then item.HitsTruncated=true;break end
                end
                coroutine.yield()
            end
            item.Status='Searched';item.Hits=hits;self.Revision=self.Revision+1
        end)
    end
    function self:tableEvidence(data,path,origin)
        if type(data)~='table'or self.Destroyed then return end
        self.Tasks[#self.Tasks+1]=coroutine.create(function()
            local seen={};local nodes=0
            local function walk(t,p,depth,inherited)
                if seen[t]or depth>3 or nodes>=180 then return end;seen[t]=true
                local n=0
                for key,value in next,t do
                    n=n+1;nodes=nodes+1;if n>40 or nodes>180 then break end
                    local kt=type(key)
                    if kt=='string'or kt=='number'then
                        local field=p..'['..tostring(key)..']';local score=Deep.score(field)
                        if type(value)=='table'then walk(value,field,depth+1,math.max(score,inherited))
                        elseif type(value)=='number'or type(value)=='string'or type(value)=='boolean'then
                            if math.max(score,inherited)>=4 then
                                self:put({Kind='Client runtime table',Path=path,Field=field,Text=clip(tostring(value),768),Value=c.Plain(value),Origin=origin,Score=math.max(score,inherited),
                                    Note='Client table/upvalue with this key. Numeric round keys are preserved; authoritative server limits remain unverified.'})
                            end
                        end
                    end
                    coroutine.yield()
                end
            end
            walk(data,'table',0,0)
        end)
    end
    function self:constants(data,path,origin)
        if type(data)~='table'or self.Destroyed then return end
        local rows={};local context={};local n=0
        for key,value in next,data do
            n=n+1;if n>96 then break end
            if type(value)=='number'or type(value)=='string'or type(value)=='boolean'then
                rows[#rows+1]={Index=tostring(key),Value=c.Plain(value)}
                if type(value)=='string'then context[#context+1]=clip(value,180)end
            end
        end
        local text=clip(table.concat(context,' | '),1600)
        if Deep.score(text)>=4 or text:find('FireServer',1,true)or text:find('InvokeServer',1,true)then self:put({Kind='Client function constants',Path=path,Field=origin,Text=text,Constants=rows,Origin=origin,
            Note='Constants in one client function; their order does not identify argument order, a round map or an active capacity.'})end
    end
    function self:step()
        if self.Destroyed then return end
        local started=clock();local n=0
        while #self.Stack>0 and n<256 and clock()-started<.0015 do
            n=n+1;local frame=self.Stack[#self.Stack]
            if not frame.Children then local ok,children=pcall(c.Children,frame.Node);frame.Children=ok and children or {};frame.Pos=1
            elseif frame.Pos>#frame.Children then table.remove(self.Stack)
            else
                local object=frame.Children[frame.Pos];frame.Pos=frame.Pos+1;self.Scanned=self.Scanned+1
                if c.Alive(object)and not c.Skip(object)then self:discover(object);self.Stack[#self.Stack+1]={Node=object}end
            end
        end
        if #self.Stack==0 then self.Ready=true end
        started=clock();n=0
        while #self.Tasks>0 and n<80 and clock()-started<.0015 do
            n=n+1;local work=table.remove(self.Tasks,1);local ok,why=coroutine.resume(work)
            if not ok then self.LastError=tostring(why)
            elseif coroutine.status(work)~='dead'then self.Tasks[#self.Tasks+1]=work end
        end
    end
    function self:rank(query)
        local words={};for word in tostring(query or ''):lower():gmatch('[^,%s]+')do words[#words+1]=word end
        local out={}
        for _,row in ipairs(self.Findings)do
            local hay=(row.Path..' '..(row.Field or '')..' '..(row.Text or '')):lower();local match=#words==0
            for _,word in ipairs(words)do if hay:find(word,1,true)then match=true;break end end
            if match then out[#out+1]=row end
        end
        table.sort(out,function(a,b)
            if a.Score~=b.Score then return a.Score>b.Score end
            if a.Path~=b.Path then return a.Path<b.Path end
            return (a.CollectedAfter or 0)>(b.CollectedAfter or 0)
        end)
        return out
    end
    function self:export(query)
        local scripts={};for _,s in ipairs(self.Scripts)do scripts[#scripts+1]={Path=s.Path,Status=s.Status,Discovery=s.Discovery,InGameRoots=s.InGameRoots,SourceOrigin=s.SourceOrigin,SourceBytes=s.SourceBytes,SourceTruncated=s.SourceTruncated,Hits=s.Hits,Error=s.Error,NativeTimeout=s.NativeTimeout,Introspection=s.Introspection}end
        return{Ready=self.Ready,Scanned=self.Scanned,ObjectsIndexed=#self.Objects,ObjectCount=self.ObjectCount,ObjectOverflow=self.ObjectOverflow,
            ScriptOverflow=self.ScriptOverflow,Scripts=scripts,SourceReads=self.SourceReads,SourceErrors=self.SourceErrors,
            Findings=self:rank(query),FindingCount=self.FindingCount,FindingOverflow=self.FindingOverflow,Values=self.Values,Remotes=self.Remotes,
            OutstandingTasks=#self.Tasks,LastError=self.LastError,
            Scope='Client hierarchy, readable/decompiled client code, constants and available client upvalues only. No modules are required or executed; no server files or authoritative capacity are claimed.'}
    end
    function self:Destroy()self.Destroyed=true;self.Stack={};self.Tasks={}end
    return self
end

-- BEGIN ROBLOX CLIENT
local Players=game:GetService('Players');local player=Players.LocalPlayer
assert(player,'Halloween Deep Inspector requires a client player')
local env=_G
if type(getgenv)=='function' then local ok,v=pcall(getgenv);if ok and type(v)=='table' then env=v end end
local KEY,HOOK='ProbothotspotHalloweenDeepInspector','ProbothotspotNPCHitHook'
local oldFarm=env.ProbothotspotHalloweenFarmDiagnostic
if type(oldFarm)=='table'and type(oldFarm.Destroy)=='function'then oldFarm:Destroy()end
local previousDiagnostic=env.ProbothotspotNPCHitDiagnostic
if type(previousDiagnostic)=='table'and type(previousDiagnostic.Destroy)=='function'then previousDiagnostic:Destroy()end
local previous=env[KEY];if type(previous)=='table' and type(previous.Destroy)=='function' then previous:Destroy() end
local pg=player:WaitForChild('PlayerGui',10);assert(pg,'PlayerGui unavailable')
local connections,tweens={},{};local cleanupObjects,deepCleanup;local gui,engine,dispatcher,listener,monitor
local handle={Version='1.0.0',JobId=game.JobId,Destroyed=false};env[KEY]=handle
local function connect(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
function handle:Destroy()
    if self.Destroyed then return end;self.Destroyed=true
    if engine then engine:Destroy() end
    if monitor then monitor:Destroy()end
    if cleanupObjects then cleanupObjects()end
    if deepCleanup then deepCleanup()end
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
        firesignal=firesignal,firetouchinterest=firetouchinterest,getconnections=getconnections,
        decompile=decompile,getloadedmodules=getloadedmodules,getscriptclosure=getscriptclosure,getscriptfunction=getscriptfunction,
        getgc=getgc,getfenv=getfenv,getconstants=getconstants,getupvalues=getupvalues}
    if type(direct[name])=='function' then return direct[name]end
    if type(env[name])=='function' then return env[name]end
    if type(_G[name])=='function' then return _G[name]end
    if (name=='getconstants'or name=='getupvalues')and type(debug)=='table'and type(debug[name])=='function'then return debug[name]end
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
for _,name in ipairs({'hookmetamethod','getnamecallmethod','hookfunction','newcclosure','checkcaller','getcallingscript','setclipboard','fireproximityprompt','firesignal','firetouchinterest','getconnections','decompile','getloadedmodules','getscriptclosure','getscriptfunction','getgc','getfenv','getconstants','getupvalues'})do capabilities[name]=api(name)~=nil end
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
local deep,sourceJob,sourceThread,memoryWork,memoryThread;local knownRoots={}
local sourceStarted=0;local sourceCount=0;local sourceBudget=256;local decompileCount=0;local decompileBudget=24;local decompileDisabled=false;local introspectionDisabled=false
local memoryStatus='Не запускалась';local memoryStarted=0;local memoryFunctions=0
local function roots()
    local out={pg,player,workspace,game:GetService('ReplicatedStorage')}
    for _,name in ipairs({'ReplicatedFirst','StarterPlayer','StarterGui'})do
        local ok,service=pcall(function()return game:GetService(name)end);if ok and service then out[#out+1]=service end
    end
    knownRoots=out;return out
end
local function inGameRoots(object)
    for _,root in ipairs(knownRoots)do if object==root or object:IsDescendantOf(root)then return true end end
    return false
end
local function meta(object)
    local data=common(object)
    data.InGameRoots=inGameRoots(object)
    data.IsScript=object:IsA('LocalScript')or object:IsA('ModuleScript')or object:IsA('Script')
    data.IsValue=object:IsA('ValueBase')
    data.Remote=object:IsA('RemoteEvent')or object:IsA('RemoteFunction')or object:IsA('UnreliableRemoteEvent')
    return data
end
local function introspect(fn,pathName,origin,errors)
    if type(fn)~='function'or not deep or deep.Destroyed then return end
    for _,entry in ipairs({{'getconstants','constants'},{'getupvalues','tableEvidence'}})do
        local getter=api(entry[1])
        if getter then
            local ok,values=pcall(getter,fn)
            if handle.Destroyed then return end
            if ok and type(values)=='table'then deep[entry[2]](deep,values,pathName,origin..' / '..entry[1])
            elseif errors then errors[#errors+1]=entry[1]..': '..clip(tostring(values),180)end
        end
    end
end
local function readScript(item)
    local job={Item=item};sourceJob=job;sourceStarted=os.clock();sourceCount=sourceCount+1
    sourceThread=task.spawn(function()
        local good,text=pcall(function()return item.Object.Source end);local reason
        local origin='Source property'
        if not good or type(text)~='string'or #text==0 then
            reason='Source property: '..clip(tostring(text),180);text=nil
            local decompiler=api('decompile')
            if decompiler and not decompileDisabled and decompileCount<decompileBudget then
                decompileCount=decompileCount+1;origin='Executor decompile output'
                local ok,result=pcall(decompiler,item.Object)
                if handle.Destroyed or sourceJob~=job then return end
                if ok and type(result)=='string'and #result>0 then text=result
                else reason=reason..'; decompile: '..clip(tostring(result),180)end
            else reason=reason..'; decompile '..(decompileDisabled and 'disabled after timeout'or not decompiler and 'unavailable'or 'call budget exhausted')end
        end
        if handle.Destroyed or sourceJob~=job then return end
        deep:source(item,text,origin,reason)
        item.Introspection={}
        local getclosure=api('getscriptclosure')or api('getscriptfunction')
        if getclosure and not introspectionDisabled then
            local ok,fn=pcall(getclosure,item.Object)
            if handle.Destroyed or sourceJob~=job then return end
            if ok and type(fn)=='function'then introspect(fn,item.Path,'Script closure',item.Introspection)
            else item.Introspection[#item.Introspection+1]='script closure: '..clip(tostring(fn),180)end
        else item.Introspection[#item.Introspection+1]='script closure unavailable or disabled after API timeout'end
        if sourceJob==job then sourceJob=nil end
    end)
end
local function seedModules()
    local getmodules=api('getloadedmodules')
    if not getmodules then capabilities.LoadedModules='API unavailable';return end
    capabilities.LoadedModules='API requested; result pending'
    task.spawn(function()
        local ok,modules=pcall(getmodules)
        if handle.Destroyed then return end
        if not ok or type(modules)~='table'then capabilities.LoadedModules=clip(tostring(modules),180);return end
        local n=0
        for _,object in next,modules do
            n=n+1;if n>2000 then capabilities.LoadedModulesTruncated=true;break end
            if typeof(object)=='Instance'and (not object.Parent or inGameRoots(object))then
                deep:discover(object,object.Parent and 'getloadedmodules (no require)'or 'Detached loaded module; origin unverified')
            end
            if n%32==0 then task.wait()end
            if handle.Destroyed then return end
        end
        capabilities.LoadedModules='Enumeration returned; module code was not executed'
    end)
end
local function startMemory()
    if memoryWork or memoryStatus=='Запрос getgc…'then return end
    local gc,environment=api('getgc'),api('getfenv')
    if not gc or not environment then memoryStatus='Нужны getgc и getfenv';return end
    memoryStatus='Запрос getgc…';memoryStarted=os.clock()
    memoryThread=task.spawn(function()
        local ok,entries=pcall(gc,true)
        if handle.Destroyed or memoryStatus~='Запрос getgc…'then return end
        if not ok or type(entries)~='table'then memoryStatus='getgc: '..clip(tostring(entries),160);return end
        memoryStatus='Поиск функций известных игровых скриптов'
        memoryWork=coroutine.create(function()
            local inspected=0
            for _,entry in next,entries do
                inspected=inspected+1
                if inspected>50000 or memoryFunctions>=200 then memoryStatus='Готово в пределах лимитов';return end
                if type(entry)=='function'then
                    local good,envTable=pcall(environment,entry)
                    local scriptObject=good and type(envTable)=='table'and rawget(envTable,'script')
                    local known=scriptObject and deep.ScriptMap[scriptObject]
                    if known and known.InGameRoots then memoryFunctions=memoryFunctions+1;introspect(entry,known.Path,'Live game function (getgc + env.script)')end
                end
                coroutine.yield()
            end
            memoryStatus='Готово'
        end)
    end)
end
local function deepStep()
    deep:step()
    if sourceJob and os.clock()-sourceStarted>12 then
        local item=sourceJob.Item;sourceJob=nil;decompileDisabled=true;introspectionDisabled=true
        item.NativeTimeout=true
        if item.SourceOrigin then
            item.Introspection=item.Introspection or {};item.Introspection[#item.Introspection+1]='12-second introspection timeout; native script APIs disabled'
        else deep:source(item,nil,nil,'12-second source/closure API timeout; subsequent native script APIs disabled')end
        if task.cancel and sourceThread then pcall(task.cancel,sourceThread)end
    end
    if deep.Ready and not sourceJob and sourceCount<sourceBudget then
        local item=deep:nextScript();if item then readScript(item)end
    end
    if memoryStatus=='Запрос getgc…'and os.clock()-memoryStarted>12 then
        memoryStatus='getgc timeout';if task.cancel and memoryThread then pcall(task.cancel,memoryThread)end
    end
    if memoryWork then
        local began=os.clock();local n=0
        while memoryWork and n<80 and os.clock()-began<.0015 do
            n=n+1;local ok,why=coroutine.resume(memoryWork)
            if not ok then memoryStatus='Ошибка памяти: '..clip(tostring(why),180);memoryWork=nil
            elseif coroutine.status(memoryWork)=='dead'then memoryWork=nil end
        end
    end
end
local function stopDeep()
    if deep then deep:Destroy()end
    sourceJob=nil;memoryWork=nil
    if task.cancel then
        if sourceThread then pcall(task.cancel,sourceThread)end
        if memoryThread then pcall(task.cancel,memoryThread)end
    end
end

deepCleanup=stopDeep
local function make(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function round(o)make('UICorner',{CornerRadius=UDim.new(0,10)},o)end
local ok,why=pcall(function()
    gui=make('ScreenGui',{Name='HalloweenDeepInspectorGUI',ResetOnSpawn=false,DisplayOrder=1400,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg);handle.Gui=gui
    local safe=make('Frame',{Name='SafeArea',Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
    local window=make('Frame',{Name='Window',Size=UDim2.fromOffset(400,670),Position=UDim2.new(.5,-200,.5,-335),
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
    local title=label('Title','Halloween Deep Inspector 1.0.0',14,0,300,44,15,header);title.Font=Enum.Font.GothamBold
    local close=button('Close','×',357,8,28,28)
    local queryBox=make('TextBox',{Name='Query',Text='candy,backpack,capacity,round',PlaceholderText='Поиск по коду, значениям и путям',Position=UDim2.fromOffset(15,50),Size=UDim2.fromOffset(370,30),
        ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(92,42,139),BorderSizePixel=0,TextColor3=Color3.fromRGB(255,243,255),Font=Enum.Font.Code,TextSize=12},window);round(queryBox)
    local treeButton=button('Tree','Дерево',15,155,88,28)
    local upButton=button('Up','↑',111,155,40,28)
    local moreCode=button('MoreCode','Ещё код: +256',15,551,176,30)
    local memoryButton=button('Memory','Память: искать',203,551,182,30)
    local compactCopy=button('CompactCopy','Копировать находки',203,511,182,32)
    local status=label('Status','Установка наблюдения…',15,86,370,42,11,window)
    local count=label('Count','Записей: 0',15,129,370,20,11,window)
    local prev=button('Previous','<',303,155,28,28);local nextButton=button('Next','>',350,155,28,28)
    local scroll=make('ScrollingFrame',{Name='ReportScroll',Position=UDim2.fromOffset(15,193),Size=UDim2.fromOffset(370,305),
        BackgroundColor3=Color3.fromRGB(92,42,139),BackgroundTransparency=.12,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,305)},window);round(scroll)
    local box=make('TextBox',{Name='Report',Text='',Position=UDim2.fromOffset(7,6),Size=UDim2.fromOffset(352,295),BackgroundTransparency=1,
        TextColor3=Color3.fromRGB(253,239,255),Font=Enum.Font.Code,TextSize=11,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,ClearTextOnFocus=false,MultiLine=true,TextEditable=true},scroll)
    local toggle=button('Record','RPC: ON',15,511,176,32);local copy=button('Copy','Полный отчёт',203,591,182,30)
    local broad=button('Broad','RPC: ещё 30 секунд',15,591,176,30)
    local snap=button('Snapshot','Снимок состояния',15,630,176,26)
    label('Credit','By: Probothotspot | Read-only',203,633,182,18,9,window)
    monitor=Monitor.new({Started=started,Roots=function()return{pg,player,workspace,game:GetService('ReplicatedStorage')}end,Skip=skip,Classify=classify,Read=readObject,ChangeKey=changeKey,
        Children=function(o)
            if o==player then local list={};for _,child in ipairs(o:GetChildren())do if child~=pg then list[#list+1]=child end end;return list end
            return o:GetChildren()
        end,Alive=function(o)return o.Parent~=nil and not ownUI(o)end,Track=track,Untrack=untrack,Context=context});handle.Monitor=monitor
    monitor:add(player);monitor:add(workspace);monitor:add(game:GetService('ReplicatedStorage'))
    context()
    deep=Deep.new({Roots=roots(),Children=function(o)
        if o==player then local out={};for _,child in ipairs(o:GetChildren())do if child~=pg then out[#out+1]=child end end;return out end
        return o:GetChildren()
    end,Skip=skip,
        Alive=function(o)return o.Parent~=nil end,Meta=meta,Attributes=attributes,
        Value=function(o)return packed(o.Value)end,Plain=packed});handle.Deep=deep
    seedModules()
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
        connect(root.DescendantAdded,function(object)monitor:add(object);deep:discover(object,'DescendantAdded')end)
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
    local exportPinned=false;local treeMode=false;local treeNode=workspace;local treePage=0;local treeChildren={};local treeRows={};local render
    local function clipboard(text)
        handle.CopyText=text;exportPinned=false
        local fn=api('setclipboard')or api('toclipboard')
        if fn then local ok,v=pcall(fn,text);if ok and v~=false then status.Text='Находки скопированы';return end end
        exportPinned=true
        for _,row in ipairs(treeRows)do row.Visible=false end
        box.Visible=true;box.Text=text;box:CaptureFocus();box.CursorPosition=1;box.SelectionStart=#text+1
        status.Text='Буфер недоступен: текст выделен'
    end
    local function chooseNode(node)
        exportPinned=false;treeNode=node;treePage=0;treeMode=true
        scroll.CanvasPosition=Vector2.new(0,0)
        if deep.ScriptMap[node]then
            local item=deep.ScriptMap[node]
            if item.Status=='Pending'or item.Status=='Unavailable'then
                item.Priority=9999;item.Status='Pending';sourceBudget=math.max(sourceBudget,sourceCount+1)
                decompileBudget=math.max(decompileBudget,decompileCount+1)
            end
        end
        render()
    end
    for n=1,24 do
        local row=make('TextButton',{Name='TreeRow'..n,Text='',Size=UDim2.fromOffset(345,28),Position=UDim2.fromOffset(7,180+(n-1)*31),
            Visible=false,BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(123,62,170),TextColor3=Color3.fromRGB(255,244,255),
            TextSize=11,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},scroll)
        treeRows[n]=row;connect(row.Activated,function()
            local node=treeChildren[treePage*24+n];if node then chooseNode(node)end
        end)
    end
    render=function()
        if exportPinned then return end
        local report=current();local ranked=deep:rank(queryBox.Text)
        count.Text='Объектов: '..deep.ObjectCount..' | Скриптов: '..#deep.Scripts..' | Находок: '..#ranked
        status.Text=(deep.Ready and 'Обход готов' or 'Обход в фоне')..' | код: '..sourceCount..'/'..#deep.Scripts..' | доступен: '..deep.SourceReads..' | закрыт: '..deep.SourceErrors
        toggle.Text=engine.Recording and os.clock()<engine.BroadUntil and 'RPC: ON'or 'RPC: OFF'
        treeButton.Text=treeMode and 'Сводка'or 'Дерево'
        if treeMode then
            local ok,children=pcall(function()return treeNode:GetChildren()end);treeChildren={}
            if ok then for i=1,math.min(#children,600)do if not ownUI(children[i])then treeChildren[#treeChildren+1]=children[i]end end end
            table.sort(treeChildren,function(a,b)return a.Name<b.Name end)
            treePage=math.clamp(treePage,0,math.max(0,math.ceil(#treeChildren/24)-1))
            local details={Object=common(treeNode),Attributes=attributes(treeNode),Properties=props(treeNode,{'Value','Text','Image','Size','Position','CanTouch','CanQuery','Enabled','ActionText','ObjectText'})}
            local item=deep.ScriptMap[treeNode];if item then details.Script={Status=item.Status,SourceOrigin=item.SourceOrigin,Hits=item.Hits,Error=item.Error,Introspection=item.Introspection}end
            local good,json=pcall(function()return http:JSONEncode(details)end)
            box.Text='[ДЕРЕВО — только чтение]\n'..path(treeNode)..'\nСтраница '..(treePage+1)..' / '..math.max(1,math.ceil(#treeChildren/24))..'\n'..clip(good and json or tostring(json),1900)
            box.Size=UDim2.fromOffset(352,170)
            for n,row in ipairs(treeRows)do
                local child=treeChildren[treePage*24+n];row.Visible=child~=nil
                if child then row.Text='  '..child.Name..' ['..child.ClassName..']'end
            end
            scroll.CanvasSize=UDim2.fromOffset(0,190+math.min(24,math.max(0,#treeChildren-treePage*24))*31)
            handle.ReportText=box.Text;return
        end
        for _,row in ipairs(treeRows)do row.Visible=false end
        local lines={'=== HALLOWEEN DEEP INSPECTOR ===',
            'Source: '..deep.SourceReads..' | недоступны: '..deep.SourceErrors..' | поиск фрагментов: '..#deep.Tasks,
            'Декомпиляция: '..decompileCount..'/'..decompileBudget..(decompileDisabled and ' | остановлена после таймаута'or ''),
            'Память: '..memoryStatus..' | игровых функций: '..memoryFunctions,
            'RPC: '..#engine.Reports..' | значения: '..#deep.Values..' | Remote: '..#deep.Remotes,
            'Числа ниже — свидетельства клиента, не подтверждённые серверные лимиты.', ''}
        if #ranked==0 then
            lines[#lines+1]='Совпадений по фильтру пока нет.'
            lines[#lines+1]='Если Source закрыт, смотри API/ошибки. «Память» проверяет доступные живые функции известных игровых скриптов.'
            lines[#lines+1]='«Дерево» открывает объекты и их атрибуты. Выбор скрипта повышает его приоритет.'
        end
        for i=1,math.min(#ranked,18)do
            local row=ranked[i];lines[#lines+1]='['..row.Score..'] '..row.Topic..' | '..row.Kind
            lines[#lines+1]=row.Path..(row.Line and ':'..row.Line or '')..(row.Field and ' | '..row.Field or '')
            lines[#lines+1]=clip(row.Text or tostring(row.Value),900);lines[#lines+1]=''
        end
        if report then lines[#lines+1]='Фактически наблюдавшийся вызов:\n'..report.CallPreview end
        handle.ReportText=table.concat(lines,'\n');box.Text=handle.ReportText
        local h=0;for segment in (box.Text..'\n'):gmatch('(.-)\n')do h=h+math.max(1,math.ceil((utf8.len(segment)or #segment)/48))*14 end
        h=math.max(295,h);box.Size=UDim2.fromOffset(352,h);scroll.CanvasSize=UDim2.fromOffset(0,h+12)
    end
    handle.Explore=chooseNode
    connect(queryBox.FocusLost,function()exportPinned=false;treeMode=false;scroll.CanvasPosition=Vector2.new(0,0);render()end)
    connect(treeButton.Activated,function()exportPinned=false;treeMode=not treeMode;scroll.CanvasPosition=Vector2.new(0,0);render()end)
    connect(upButton.Activated,function()if treeNode.Parent then chooseNode(treeNode.Parent)end end)
    connect(moreCode.Activated,function()sourceBudget=sourceBudget+256;decompileBudget=decompileBudget+24;render()end)
    connect(memoryButton.Activated,function()startMemory();render()end)
    connect(compactCopy.Activated,function()
        local ranked=deep:rank(queryBox.Text);local top={};for i=1,math.min(#ranked,100)do top[i]=ranked[i]end
        local closed={};for _,item in ipairs(deep.Scripts)do
            if item.Status=='Unavailable'and #closed<24 then closed[#closed+1]={Path=item.Path,Error=item.Error,Introspection=item.Introspection}end
        end
        local state={};for _,name in ipairs({'UI','State'})do
            local bucket=monitor.Buckets[name]
            for _,object in ipairs(bucket.Order)do
                local d=bucket.Data[object];local p=d and d.Properties or {};local parsed=d and d.Parsed
                if d and (Deep.score(d.FullPath)>=4 or parsed and(parsed.Round or parsed.CollectionGoal or parsed.Ratio or parsed.NumericLabel))and #state<160 then
                    state[#state+1]={Path=d.FullPath,Properties={Text=p.Text,Value=p.Value,Image=p.Image},Parsed=parsed,Attributes=d.Attributes,Visible=d.EffectiveVisible}
                end
            end
        end
        local data={Schema=1,Version=handle.Version,PlaceId=game.PlaceId,Capabilities=capabilities,IndexReady=deep.Ready,Objects=deep.ObjectCount,
            ScriptCount=#deep.Scripts,SourceAttempts=sourceCount,SourceReadable=deep.SourceReads,SourceUnavailable=deep.SourceErrors,OutstandingSearches=#deep.Tasks,
            DecompileCalls=decompileCount,DecompileDisabled=decompileDisabled,MemoryStatus=memoryStatus,MemoryFunctions=memoryFunctions,
            Findings=top,FindingsTotal=#ranked,UnavailableExamples=closed,StateCandidates=state,ObservedCalls=engine.Reports,
            SelectedObject=treeMode and {Object=common(treeNode),Attributes=attributes(treeNode),Properties=props(treeNode,{'Value','Text','Size','Position'})}or nil,
            Limits='Up to 100 ranked findings, 24 source-error examples, 160 state candidates and 32 observed RPCs. Full report has the wider manifest.',
            Meaning='No capacity is declared authoritative. Decompiled source/constants/tables are client evidence; only observed calls demonstrate actual sent arguments.'}
        local good,text=pcall(function()return http:JSONEncode(data)end)
        if good then clipboard('=== HALLOWEEN DEEP FINDINGS ===\n'..text)else status.Text='JSON: '..tostring(text)end
    end)
    connect(toggle.Activated,function()engine.Recording=not(engine.Recording and os.clock()<engine.BroadUntil);dispatcher.Listener=engine.Recording and listener or nil;if engine.Recording then engine.BroadUntil=os.clock()+30 end;render()end)
    connect(broad.Activated,function()engine.Recording=true;dispatcher.Listener=listener;engine.BroadUntil=os.clock()+30;render()end)
    connect(prev.Activated,function()
        if treeMode then treePage=math.max(0,treePage-1);render();return end
        local report=current();for i,item in ipairs(engine.Reports)do if report and item.Id==report.Id then selected=engine.Reports[math.max(1,i-1)].Id;break end end;render()
    end)
    connect(nextButton.Activated,function()
        if treeMode then treePage=treePage+1;render();return end
        local report=current();for i,item in ipairs(engine.Reports)do if report and item.Id==report.Id then selected=i<#engine.Reports and engine.Reports[i+1].Id or nil;break end end;render()
    end)
    connect(snap.Activated,function()exportPinned=false;monitor:event('User stage marker',{Context=context()});monitor:request('User stage marker');render()end)
    connect(copy.Activated,function()
        render()
        local report=current()
        local good,all=pcall(function()return http:JSONEncode({Schema=1,Version='1.0.0',Capabilities=capabilities,
            DeepInspector=deep:export(queryBox.Text),DeepAPIs={SourceJobs=sourceCount,SourceBudget=sourceBudget,DecompileCalls=decompileCount,DecompileDisabled=decompileDisabled,Memory=memoryStatus,MemoryFunctions=memoryFunctions},StateMonitor=monitor:export(),CurrentContext=context(),SelectedId=report and report.Id,Reports=engine.Reports,TotalObserved=engine.Sequence,Dropped=engine.Dropped,LastError=engine.LastError})end)
        local text=handle.ReportText..'\n\nJSON ALL:\n'..(good and all or tostring(all))
        handle.CopyText=text;exportPinned=false
        local fn=api('setclipboard') or api('toclipboard')
        if fn then local copied,result=pcall(fn,text);if copied and result~=false then status.Text='Все записи скопированы';return end end
        exportPinned=true;for _,row in ipairs(treeRows)do row.Visible=false end
        box.Text=text
        box:CaptureFocus();box.CursorPosition=1;box.SelectionStart=#box.Text+1
        status.Text='Буфер недоступен: текст выделен для ручного копирования'
    end)
    connect(close.Activated,function()handle:Destroy()end)
    connect(gui.Destroying,function()handle:Destroy()end)
    local dragging,start,origin
    local function fit()
        local area=safe.AbsoluteSize;if area.X<=0 or area.Y<=0 then return end
        scale.Scale=math.max(.1,math.min(1,(area.X-16)/400,(area.Y-16)/670))
        local x=window.Position.X.Scale*area.X+window.Position.X.Offset;local y=window.Position.Y.Scale*area.Y+window.Position.Y.Offset
        window.Position=UDim2.fromOffset(math.clamp(x,0,math.max(0,area.X-400*scale.Scale)),math.clamp(y,0,math.max(0,area.Y-670*scale.Scale)))
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
        local good,problem=pcall(function()monitor:step();deepStep()end)
        if not good then monitor.LastError=tostring(problem)end
        if os.clock()<nextUI then return end;nextUI=os.clock()+.5
        broad.Text=os.clock()<engine.BroadUntil and ('Remote: '..math.ceil(engine.BroadUntil-os.clock())..' с') or 'Remote: ещё 30 секунд'
        render()
    end)
    local tween=game:GetService('TweenService'):Create(gradient,TweenInfo.new(10,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,false),{Rotation=375})
    tweens[#tweens+1]=tween;tween:Play();render()
end)
if not ok then handle:Destroy();error('[Halloween Deep Inspector] '..tostring(why))end
return handle
