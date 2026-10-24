-- NPC Hit Inspector v1.0.0 | Probothotspot
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
            data.Type=kind;ctx.Instances[v]=data;ctx.References[#ctx.References+1]=v
            if data.Target and data.Target.Kind=='NPC' and #ctx.Targets<8 and not ctx.TargetSeen[data.Target.FullPath or data.Target.Name] then
                ctx.TargetSeen[data.Target.FullPath or data.Target.Name]=true;ctx.Targets[#ctx.Targets+1]=data.Target
            end
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
            local ctx={Nodes=0,Started=now,Truncated=false,Seen={},Instances={},References={},Targets={},TargetSeen={},TableId=0}
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
            local report={Schema=2,Version='1.0.0',Id=self.Sequence,Time=c.Epoch(),LocalClock=now,PlaceId=c.PlaceId,JobId=c.JobId,
                Method=method,Origin=origin or 'unknown',Remote=remoteInfo,ArgumentCount=n,Arguments=values,Targets=ctx.Targets,
                Match=broad and '10-second broad capture' or #ctx.Targets>0 and 'NPC instance argument' or 'hit-like remote name; NPC not proven',
                Initiator=initiator,Stack=stack,LocalCharacter=context,Truncated=ctx.Truncated,Dropped=self.Dropped,Capabilities=c.Capabilities,
                Observation='Outgoing client request only; server response/damage not observed at capture. Later health samples are observations, not causal proof',
                Availability={ServerSource=false,ServerValidationRules=false,RawNetworkBytes=false,ExactContactPoint=false,Note='Instance arguments do not identify an exact contact pixel or the server hit test'}}
            local parts={};local reproducible=not ctx.Truncated and remoteInfo.Expression~=nil
            for _,value in ipairs(values)do local part=code(value);if not part then reproducible=false;break end;parts[#parts+1]=part end
            if reproducible then report.CallPreview=remoteInfo.Expression..':'..method..'('..table.concat(parts,', ')..')'
            else report.CallPreview='Unavailable: arguments/path truncated or unsupported; do not treat this as a complete replay' end
            self.Reports[#self.Reports+1]=report
            if #self.Reports>12 then table.remove(self.Reports,1) end
            self.CaptureCredit=self.CaptureCredit-1;self.Revision=self.Revision+1
            if c.AfterCapture then
                local good,why=pcall(c.AfterCapture,report,ctx.References,remote)
                if not good then report.ObjectSurvey={State='Error',Reason=tostring(why)}end
            end
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
-- Bounded deferred survey. No tree walk or wait is performed inside the RPC hook.
local Survey={}
function Survey.new(c)
    local clock=c.Clock or os.clock
    local self={Jobs={},Watches={},Destroyed=false}
    local function changed()if c.Changed then c.Changed()end end
    local function finish(job,state,reason)
        job.Data.State=state;job.Data.Reason=reason;job.Data.FinishedAfter=clock()-job.At
        job.Refs=nil;changed()
    end
    function self:enqueue(report,refs)
        if self.Destroyed then return end
        if #self.Jobs>=8 then
            report.ObjectSurvey={State='Skipped',Reason='Detail queue is full (8); pause automatic attackers and hit manually'}
            report.HealthObservation={State='Skipped',Reason='Detail queue is full'};changed();return
        end
        local data={State='Queued',Nodes={},Roots={},Truncated=false,Limits={Nodes=256,Depth=12,Roots=4},
            Note='Client-visible properties sampled AFTER the outgoing call; not a server snapshot, screenshot or server script source'}
        report.ObjectSurvey=data
        report.HealthObservation={State='Watching',WindowSeconds=2,Targets={},
            Attribution='Health changes are local observations; concurrent attacks, healing, lag and server rejection cannot be separated'}
        local job={Report=report,Data=data,Refs=refs,At=clock()};local roots,seen,humans={},{},{}
        for _,ref in ipairs(refs)do
            local good,root,human=pcall(c.Root,ref)
            if good and root and not seen[root]then
                seen[root]=true
                if #roots<4 then roots[#roots+1]=root else data.Truncated=true end
            end
            if good and human and not humans[human] and #report.HealthObservation.Targets<4 and #self.Watches<32 then
                humans[human]=true
                local ok,health=pcall(c.Health,human)
                if ok and type(health)=='number' and finite(health)then
                    local target={FullPath=c.Path(human),Before=health,Samples={},OverlappingCalls=false}
                    for _,watch in ipairs(self.Watches)do
                        if watch.Human==human then watch.Target.OverlappingCalls=true;target.OverlappingCalls=true end
                    end
                    report.HealthObservation.Targets[#report.HealthObservation.Targets+1]=target
                    self.Watches[#self.Watches+1]={Human=human,Target=target,Report=report,At=clock(),Next=1}
                end
            end
        end
        if #report.HealthObservation.Targets==0 then report.HealthObservation.State='Unavailable';report.HealthObservation.Reason='No readable Humanoid reference, or 32 active watches limit reached' end
        job.Work=coroutine.create(function()
            data.State='Inspecting'
            local stack={}
            for i=#roots,1,-1 do stack[#stack+1]={Object=roots[i],Depth=0,Root=i}end
            local seenNodes={}
            while #stack>0 and #data.Nodes<256 do
                local entry=table.remove(stack);local object=entry.Object
                if not seenNodes[object]then
                    seenNodes[object]=true
                    local ok,node=pcall(c.Node,object)
                    if not ok then node={FullPath=c.Path(object),ReadError=clip(tostring(node),512)};data.Truncated=true end
                    node.Depth=entry.Depth;node.ParentIndex=entry.Parent;node.RootIndex=entry.Root
                    node.SampledAfter=clock()-job.At
                    data.Nodes[#data.Nodes+1]=node;local index=#data.Nodes
                    if entry.Depth==0 then data.Roots[#data.Roots+1]={FullPath=node.FullPath,Index=index}end
                    local good,children=pcall(c.Children,object)
                    if not good then node.ChildrenReadError=clip(tostring(children),256);data.Truncated=true
                    else
                        node.ChildCount=#children
                        if entry.Depth>=12 then if #children>0 then node.DepthLimit=true;data.Truncated=true end
                        else
                            -- Cap the stack too: an object with thousands of children cannot grow it without bound.
                            local capacity=math.max(0,256-#data.Nodes-#stack)
                            local take=math.min(#children,capacity)
                            if take<#children then node.ChildrenTruncated=true;data.Truncated=true end
                            for i=take,1,-1 do stack[#stack+1]={Object=children[i],Depth=entry.Depth+1,Parent=index,Root=entry.Root}end
                        end
                    end
                    coroutine.yield()
                end
            end
            if #stack>0 then data.Truncated=true end
            finish(job,'Complete')
        end)
        self.Jobs[#self.Jobs+1]=job;changed()
    end
    function self:step()
        if self.Destroyed then return end
        -- At most one sample per watch per frame; actual elapsed time is retained after a slow frame.
        local sampleTimes={.2,.5,1,2}
        for i=#self.Watches,1,-1 do
            local watch=self.Watches[i];local elapsed=clock()-watch.At
            if elapsed>=sampleTimes[watch.Next]then
                local ok,health=pcall(c.Health,watch.Human)
                local sample={After=elapsed,Available=ok and type(health)=='number' and finite(health)}
                if sample.Available then sample.Health=health;sample.Delta=health-watch.Target.Before
                else sample.Reason='Humanoid removed or unreadable; disappearance is not proof of death' end
                watch.Target.Samples[#watch.Target.Samples+1]=sample
                while watch.Next<=4 and elapsed>=sampleTimes[watch.Next]do watch.Next=watch.Next+1 end
                if watch.Next>4 then
                    watch.Target.Finished=true;table.remove(self.Watches,i)
                    local done=true;for _,target in ipairs(watch.Report.HealthObservation.Targets)do if not target.Finished then done=false end end
                    if done then watch.Report.HealthObservation.State='Complete' end
                end
                changed()
            end
        end
        local started=clock();local steps=0
        while #self.Jobs>0 and steps<16 and clock()-started<.0015 do
            local job=table.remove(self.Jobs,1)
            if clock()-job.At>8 then job.Data.Truncated=true;finish(job,'Partial','8 second survey deadline')
            else
                local good,why=coroutine.resume(job.Work);steps=steps+1
                if not good then job.Data.Truncated=true;finish(job,'Partial',clip(tostring(why),512))
                elseif coroutine.status(job.Work)~='dead' then self.Jobs[#self.Jobs+1]=job end
            end
        end
    end
    function self:Destroy()
        self.Destroyed=true
        for _,job in ipairs(self.Jobs)do finish(job,'Cancelled','Inspector closed or restarted')end
        for _,watch in ipairs(self.Watches)do watch.Report.HealthObservation.State='Cancelled' end
        self.Jobs={};self.Watches={}
    end
    return self
end

-- BEGIN ROBLOX CLIENT
local Players=game:GetService('Players');local player=Players.LocalPlayer
assert(player,'NPC Hit Inspector requires a client player')
local env=_G
if type(getgenv)=='function' then local ok,v=pcall(getgenv);if ok and type(v)=='table' then env=v end end
local KEY,HOOK='ProbothotspotNPCHitDiagnostic','ProbothotspotNPCHitHook'
local previous=env[KEY];if type(previous)=='table' and type(previous.Destroy)=='function' then previous:Destroy() end
local pg=player:WaitForChild('PlayerGui',10);assert(pg,'PlayerGui unavailable')
local connections,tweens={},{};local gui,engine,dispatcher,listener,survey
local handle={Version='1.0.0',JobId=game.JobId,Destroyed=false};env[KEY]=handle
local function connect(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
function handle:Destroy()
    if self.Destroyed then return end;self.Destroyed=true
    if engine then engine:Destroy() end
    if survey then survey:Destroy()end
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
-- Explicit readable property groups. No decompilation, remote replay or whole-map scan.
local propertyGroups={
    {'BasePart',{'Position','Size','CFrame','Orientation','Color','BrickColor','Material','MaterialVariant','Transparency','LocalTransparencyModifier','Reflectance','CastShadow','Anchored','CanCollide','CanTouch','CanQuery','CollisionGroup','Massless','RootPriority','AssemblyMass','AssemblyLinearVelocity','AssemblyAngularVelocity','AssemblyRootPart','CustomPhysicalProperties','Locked'}},
    {'Part',{'Shape','TopSurface','BottomSurface'}},
    {'MeshPart',{'MeshId','TextureID','DoubleSided','RenderFidelity','CollisionFidelity'}},
    {'UnionOperation',{'UsePartColor','RenderFidelity','CollisionFidelity'}},
    {'SpecialMesh',{'MeshId','TextureId','MeshType','Scale','Offset','VertexColor'}},
    {'Decal',{'Texture','Color3','Transparency','Face','ZIndex'}},
    {'Texture',{'StudsPerTileU','StudsPerTileV','OffsetStudsU','OffsetStudsV'}},
    {'SurfaceAppearance',{'ColorMap','MetalnessMap','NormalMap','RoughnessMap','AlphaMode','Color'}},
    {'Model',{'PrimaryPart','ModelStreamingMode','WorldPivot'}},
    {'Humanoid',{'Health','MaxHealth','RigType','WalkSpeed','JumpPower','JumpHeight','UseJumpPower','HipHeight','AutoRotate','PlatformStand','Sit','MoveDirection','FloorMaterial','RootPart','DisplayName','BreakJointsOnDeath','RequiresNeck'}},
    {'JointInstance',{'Part0','Part1','C0','C1','Enabled','Active'}},
    {'Motor6D',{'Transform'}},
    {'WeldConstraint',{'Part0','Part1','Enabled','Active'}},
    {'Attachment',{'Position','CFrame','WorldCFrame','Axis','SecondaryAxis','Visible'}},
    {'Constraint',{'Attachment0','Attachment1','Enabled','Active','Visible'}},
    {'Accessory',{'AccessoryType','AttachmentPoint'}},
    {'Shirt',{'ShirtTemplate','Color3'}}, {'Pants',{'PantsTemplate','Color3'}},
    {'ShirtGraphic',{'Graphic','Color3'}},
    {'BodyColors',{'HeadColor3','TorsoColor3','LeftArmColor3','RightArmColor3','LeftLegColor3','RightLegColor3'}},
    {'Tool',{'Enabled','RequiresHandle','CanBeDropped','Grip','TextureId','ToolTip'}},
    {'ProximityPrompt',{'Enabled','ActionText','ObjectText','KeyboardKeyCode','GamepadKeyCode','HoldDuration','MaxActivationDistance','RequiresLineOfSight'}},
    {'ClickDetector',{'MaxActivationDistance','CursorIcon'}},
    {'Sound',{'SoundId','Volume','PlaybackSpeed','Playing','TimePosition','TimeLength','Looped','RollOffMaxDistance'}},
    {'Animation',{'AnimationId'}},
    {'ParticleEmitter',{'Enabled','Texture','Rate','Color','Size','Lifetime','Speed','Transparency','LightEmission'}},
    {'Beam',{'Enabled','Texture','Color','Transparency','Attachment0','Attachment1','Width0','Width1'}},
    {'Trail',{'Enabled','Texture','Color','Transparency','Attachment0','Attachment1','Lifetime'}},
    {'Light',{'Enabled','Color','Brightness','Shadows'}},
    {'Highlight',{'Enabled','Adornee','FillColor','OutlineColor','FillTransparency','OutlineTransparency','DepthMode'}},
    {'ValueBase',{'Value'}}, {'BaseScript',{'Enabled','RunContext'}},
}
local function packedValue(v)
    local kind=typeof(v)
    if kind=='nil' then return nil end
    if kind=='boolean' then return v end
    if kind=='number' then return finite(v) and v or tostring(v)end
    if kind=='string' then
        if utf8 and not utf8.len(v)then return{Encoding='hex',Value=(v:sub(1,256):gsub('.',function(ch)return string.format('%02x',string.byte(ch))end)),Truncated=true}end
        if #v>1024 then return{Value=clip(v,1024),OriginalBytes=#v,Truncated=true}end;return v
    end
    if kind=='Instance' then return{FullPath=path(v),ClassName=v.ClassName}end
    if kind=='Vector3' then return vector(v)end
    if kind=='Vector2' then return{X=v.X,Y=v.Y}end
    if kind=='Color3' then return{R=v.R,G=v.G,B=v.B,RGB={math.floor(v.R*255+.5),math.floor(v.G*255+.5),math.floor(v.B*255+.5)}}end
    if kind=='CFrame' then return{Components={v:GetComponents()}}end
    if kind=='BrickColor' then return{Name=v.Name,Number=v.Number}end
    if kind=='NumberRange' then return{Min=v.Min,Max=v.Max}end
    if kind=='PhysicalProperties' then return{Density=v.Density,Friction=v.Friction,Elasticity=v.Elasticity,FrictionWeight=v.FrictionWeight,ElasticityWeight=v.ElasticityWeight}end
    if kind=='NumberSequence' or kind=='ColorSequence' then
        local keys={};for i,key in ipairs(v.Keypoints)do
            if i>32 then break end
            keys[i]={Time=key.Time,Value=packedValue(key.Value)}
            if kind=='NumberSequence' then keys[i].Envelope=key.Envelope end
        end
        return{Keypoints=keys,Truncated=#v.Keypoints>32}
    end
    return tostring(v)
end
local function inspectNode(object)
    local out={Name=object.Name,ClassName=object.ClassName,FullPath=path(object),Properties={},UnavailableProperties={}}
    local function read(name)
        local ok,v=pcall(function()return packedValue(object[name])end)
        if ok then out.Properties[name]=v
        elseif #out.UnavailableProperties<24 then out.UnavailableProperties[#out.UnavailableProperties+1]={Name=name,Reason=clip(tostring(v),180)}end
    end
    read('Archivable')
    for _,group in ipairs(propertyGroups)do if object:IsA(group[1])then for _,name in ipairs(group[2])do read(name)end end end
    local good,attrs=pcall(function()return object:GetAttributes()end)
    if good then
        out.Attributes={};local n=0
        for name,v in pairs(attrs)do n=n+1;if n>32 then out.AttributesTruncated=true;break end
            local ok,data=pcall(packedValue,v);out.Attributes[name]=ok and data or {ReadError=clip(tostring(data),180)}
        end
    else out.AttributesError=clip(tostring(attrs),180)end
    local ok,tags=pcall(function()return object:GetTags()end)
    if ok then out.Tags={};for i=1,math.min(#tags,32)do out.Tags[i]=tags[i]end;out.TagsTruncated=#tags>32
    else out.TagsError=clip(tostring(tags),180)end
    if object:IsA('Model')then
        local ok,cf,size=pcall(function()return object:GetBoundingBox()end)
        if ok then out.Bounds={CFrame=packedValue(cf),Size=packedValue(size)}end
    end
    if object:IsA('Humanoid')then
        local ok,state=pcall(function()return object:GetState()end);if ok then out.HumanoidState=tostring(state)end
        local animator=object:FindFirstChildOfClass('Animator')
        if animator then
            local ok,tracks=pcall(function()return animator:GetPlayingAnimationTracks()end)
            if ok then out.PlayingAnimations={}
                for i=1,math.min(#tracks,12)do
                    local good,track=pcall(function()local t=tracks[i];return{Name=t.Name,AnimationId=t.Animation and t.Animation.AnimationId,Speed=t.Speed,TimePosition=t.TimePosition,WeightCurrent=t.WeightCurrent}end)
                    if good then out.PlayingAnimations[#out.PlayingAnimations+1]=track end
                end
            end
        end
    end
    return out
end
local function surveyRoot(object)
    -- Keep a remote/script as itself. Workspace arguments expand to their closest rig/model.
    if object:IsA('Tool') or object:IsA('LuaSourceContainer')then return object end
    if not object:IsDescendantOf(workspace)then return object end
    local p=object;local nearest;local depth=0
    while p and p~=workspace and depth<64 do
        if p:IsA('Model')then
            nearest=nearest or p;local human=p:FindFirstChildOfClass('Humanoid')
            if human then return p,human end
        end
        p=p.Parent;depth=depth+1
    end
    return nearest or object
end
local function detailSummary(report)
    local lines={'=== ПОДРОБНОСТИ ===','Точный вызов выше — пример в тексте, автоматически не повторяется.'}
    local health=report.HealthObservation
    if health then
        lines[#lines+1]='Наблюдение HP: '..health.State
        for _,target in ipairs(health.Targets or {})do
            lines[#lines+1]=target.FullPath..' | до: '..tostring(target.Before)..(target.OverlappingCalls and ' | пересекающиеся вызовы' or '')
            for _,sample in ipairs(target.Samples)do
                lines[#lines+1]=string.format('  +%.2f с: %s',sample.After,sample.Available and ('HP '..sample.Health..' | Δ '..sample.Delta)or 'объект недоступен')
            end
        end
        lines[#lines+1]='Изменение HP само по себе не доказывает причину урона.'
    end
    local survey=report.ObjectSurvey
    if survey then
        lines[#lines+1]='Структура: '..survey.State..' | узлов: '..#(survey.Nodes or {})..(survey.Truncated and ' | частично' or '')
        if survey.Reason then lines[#lines+1]=survey.Reason end
        for i,node in ipairs(survey.Nodes or {})do
            if i>90 then lines[#lines+1]='Остальные узлы включены в копируемый JSON.';break end
            local p=node.Properties or {};local info={}
            if p.Material then info[#info+1]=tostring(p.Material)end
            if p.Size and type(p.Size)=='table' then info[#info+1]=string.format('размер %.2f×%.2f×%.2f',p.Size.X,p.Size.Y,p.Size.Z)end
            if p.Color and p.Color.RGB then info[#info+1]='RGB '..table.concat(p.Color.RGB,',')end
            for _,key in ipairs({'MeshId','TextureID','TextureId','Texture','ShirtTemplate','PantsTemplate','AnimationId','SoundId'})do
                if type(p[key])=='string' and p[key]~='' then info[#info+1]=key..'='..p[key]end
            end
            lines[#lines+1]=string.rep(' ',math.min(node.Depth or 0,12)*2)..tostring(node.Name)..' ['..tostring(node.ClassName)..'] '..table.concat(info,' | ')
        end
    end
    lines[#lines+1]='Полные свойства, атрибуты, теги, связи и JSON всех записей: кнопка «Копировать всё».'
    lines[#lines+1]='Серверный код, проверка попадания и точка контакта недоступны по одному исходящему вызову.'
    return table.concat(lines,'\n')
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
    gui=make('ScreenGui',{Name='NPCHitInspectorGUI',ResetOnSpawn=false,DisplayOrder=1400,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg);handle.Gui=gui
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
    local title=label('Title','NPC Hit Inspector 1.0.0',14,0,290,44,15,header);title.Font=Enum.Font.GothamBold
    local close=button('Close','×',316,8,28,28)
    label('Instructions','Ударь NPC вручную → подожди 2–3 с → Копировать всё.',15,47,330,34,12,window)
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
    label('Credit','By: Probothotspot | Пассивный подробный отчёт',15,460,330,14,9,window)
    survey=Survey.new({Path=path,Root=surveyRoot,Children=function(o)
        if o==workspace or o.Parent==game then return{}end;return o:GetChildren()
    end,Node=inspectNode,Health=function(h)
        if not h.Parent or not h:IsDescendantOf(workspace)then error('Humanoid no longer visible in Workspace')end
        return h.Health
    end,Changed=function()if engine then engine.Revision=engine.Revision+1 end end});handle.Survey=survey
    engine=Diagnostic.new({AfterCapture=function(report,refs,remote)
        local list={};for i=1,math.min(#refs,16)do list[#list+1]=refs[i]end;list[#list+1]=remote
        local char=player.Character;local tool=char and char:FindFirstChildOfClass('Tool')
        if tool then list[#list+1]=tool end
        survey:enqueue(report,list)
        if #refs>16 then report.ObjectSurvey.Truncated=true;report.ObjectSurvey.ReferenceLimit=true end
    end,Kind=typeof,Describe=describe,Value=value,Caller=caller,Capabilities=capabilities,Epoch=os.time,
        PlaceId=game.PlaceId,JobId=game.JobId,Context=function()
            local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
            local human=char and char:FindFirstChildOfClass('Humanoid');local tool=char and char:FindFirstChildOfClass('Tool')
            local stats=player:FindFirstChild('leaderstats');local glove=stats and stats:FindFirstChild('Glove')
            local cam=workspace.CurrentCamera
            return{CharacterPath=char and path(char),Position=root and vector(root.Position),Health=human and human.Health,
                Facing=root and root.CFrame and vector(root.CFrame.LookVector),
                Velocity=root and root.AssemblyLinearVelocity and vector(root.AssemblyLinearVelocity),
                CameraPosition=cam and cam.CFrame and vector(cam.CFrame.Position),
                CameraFacing=cam and cam.CFrame and vector(cam.CFrame.LookVector),
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
        local good,json=true,''
        if not report then good,json=pcall(function()return http:JSONEncode(data)end)end
        local text
        if report then
            local paths={}
            for i,arg in ipairs(report.Arguments)do
                if arg.Type=='Instance' then paths[#paths+1]='arg['..i..']: '..tostring(arg.FullPath)..' ('..tostring(arg.ClassName)..')'end
            end
            for _,target in ipairs(report.Targets)do paths[#paths+1]='NPC: '..tostring(target.FullPath)..' | Health: '..tostring(target.Health)end
            text='=== OBSERVED NPC HIT / CLIENT CALL ===\nRemote: '..tostring(report.Remote.FullPath)..'\nClass: '..tostring(report.Remote.ClassName)..
                '\nMethod: '..report.Method..'\nArgs: '..report.ArgumentCount..'\nMatch: '..report.Match..'\n'..table.concat(paths,'\n')..'\n\n'..report.CallPreview..'\n\n'..detailSummary(report)
        else text=good and json or tostring(json) end
        handle.ReportText=text;box.Text=text
        local lines=0;for segment in (text..'\n'):gmatch('(.-)\n')do lines=lines+math.max(1,math.ceil((utf8.len(segment) or #segment)/44))end
        local h=math.max(215,lines*14);box.Size=UDim2.fromOffset(312,h);scroll.CanvasSize=UDim2.fromOffset(0,h+12)
        count.Text='Записей: '..#engine.Reports..' | Выбрана: '..tostring(report and report.Id or '—')
        toggle.Text=engine.Recording and 'Запись: ON' or 'Запись: OFF'
        if not dispatcher.Ready then status.Text='Перехват недоступен. Скопируй отчёт возможностей.'
        elseif engine.LastError then status.Text='Ошибка записи: '..engine.LastError
        elseif report then status.Text=report.Method..': '..report.Remote.Name..' | Структура: '..tostring(report.ObjectSurvey and report.ObjectSurvey.State or '—')..' | HP: '..tostring(report.HealthObservation and report.HealthObservation.State or '—')
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
        local good,all=pcall(function()return http:JSONEncode({Schema=2,Version='1.0.0',Capabilities=capabilities,
            SelectedId=report and report.Id,Reports=engine.Reports,TotalObserved=engine.Sequence,Dropped=engine.Dropped,LastError=engine.LastError})end)
        local text=handle.ReportText..'\n\nJSON ALL:\n'..(good and all or tostring(all))
        handle.CopyText=text
        local fn=api('setclipboard') or api('toclipboard')
        if fn then local copied,result=pcall(fn,text);if copied and result~=false then status.Text='Все записи скопированы (включая текущий прогресс)';return end end
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
        survey:step()
        if os.clock()<nextUI then return end;nextUI=os.clock()+.25
        broad.Text=os.clock()<engine.BroadUntil and ('Все Remote: '..math.ceil(engine.BroadUntil-os.clock())..' с') or 'Поймать все Remote на 10 секунд'
        if revision~=engine.Revision then revision=engine.Revision;render()end
    end)
    local tween=game:GetService('TweenService'):Create(gradient,TweenInfo.new(10,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,false),{Rotation=375})
    tweens[#tweens+1]=tween;tween:Play();render()
end)
if not ok then handle:Destroy();error('[NPC Hit Inspector] '..tostring(why))end
return handle
