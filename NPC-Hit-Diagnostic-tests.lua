-- Small deterministic engine fixture: not a replacement for live Roblox physics.
local count=0
local function eq(a,b) count=count+1;assert(a==b,'NPC Hit Diagnostic #'..count..': '..tostring(a)..' ~= '..tostring(b)..debug.traceback('',2))end
math.clamp=function(x,a,b)return math.max(a,math.min(b,x))end
local time=0;local realClock=os.clock;os.clock=function()return time end
local signals={}
local function signal()
 local s={listeners={}}
 function s:Connect(fn)
  local c={Connected=true,fn=fn};function c:Disconnect()self.Connected=false end
  self.listeners[#self.listeners+1]=c;return c
 end
 function s:Fire(...)
  local list={table.unpack(self.listeners)}
  for _,c in ipairs(list)do if c.Connected then c.fn(...)end end
 end
 signals[#signals+1]=s;return s
end
local vm={}
Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end}
vm.__index=function(v,k)
 if k=='Magnitude'then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end
 if k=='Unit'then return v*(1/v.Magnitude)end
 if k=='Dot'then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
vm.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__unm=function(a)return Vector3.new(-a.X,-a.Y,-a.Z)end
vm.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
Vector3.zero=Vector3.new(0,0,0)
Vector2={new=function(x,y)return{X=x,Y=y}end}
local cm={}
CFrame={new=function(x,y,z)
 local p=type(x)=='table'and x or Vector3.new(x or 0,y or 0,z or 0)
 return setmetatable({Position=p,RightVector=Vector3.new(1,0,0),UpVector=Vector3.new(0,1,0),LookVector=Vector3.new(0,0,-1)},cm)
end}
function CFrame.lookAt(p,target)
 local c=CFrame.new(p);c.LookVector=(target-p).Unit
 c.RightVector=Vector3.new(-c.LookVector.Z,0,c.LookVector.X).Unit;return c
end
cm.__index={ToObjectSpace=function(a,b)return CFrame.new(b.Position-a.Position)end}
cm.__mul=function(a,b)return CFrame.new(a.Position+a.RightVector*b.Position.X+a.UpVector*b.Position.Y-a.LookVector*b.Position.Z)end
UDim={new=function(s,o)return{Scale=s,Offset=o}end}
UDim2={new=function(xs,xo,ys,yo)return{X=UDim.new(xs,xo),Y=UDim.new(ys,yo)}end}
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
Color3={fromRGB=function(r,g,b)return{r,g,b}end}
ColorSequence={new=function(v)return v end};ColorSequenceKeypoint={new=function(t,v)return{t,v}end}
TweenInfo={new=function(...)return{...}end}
Enum=setmetatable({},{__index=function(t,k)local v=setmetatable({},{__index=function(_,n)return n end});rawset(t,k,v);return v end})
-- Real KeyCode enum items expose Name and can be enumerated for case-insensitive input.
local keyItems={}
for _,name in ipairs({'Unknown','T','F8','LeftShift','E','Space'})do
 local code={Name=name};Enum.KeyCode[name]=code;keyItems[#keyItems+1]=code
end
function Enum.KeyCode:GetEnumItems()return keyItems end
RaycastParams={new=function()return{}end};OverlapParams={new=function()return{}end}
local methods,mt={},{}
Instance={new=function(class)return setmetatable({class=class,p={Name=class,Enabled=true,Visible=true},children={},signals={}},mt)end}
mt.__index=function(o,k)
 if methods[k]then return methods[k]end
 if k=='GeneralHit' then
  local child=methods.FindFirstChild(o,k)
  if child then return child end
  error('GeneralHit is not a valid member of '..o.class)
 end
 if k=='ClassName'then return o.class end
 if k=='AbsoluteSize'then return{X=1000,Y=800}end
 if k=='Activated'or k=='InputBegan'or k=='InputChanged'or k=='InputEnded'or k=='WindowFocusReleased'or k=='Destroying'
 or k=='DescendantAdded'or k=='DescendantRemoving'or k=='MouseEnter'or k=='MouseLeave'or k=='Played'or k=='FocusLost'then
  o.signals[k]=o.signals[k]or signal();return o.signals[k]
 end
 return o.p[k]
end
mt.__newindex=function(o,k,v)
 if k=='Parent'then
  local old=o.p.Parent
  if old then for i,c in ipairs(old.children)do if c==o then table.remove(old.children,i);break end end end
  if v then v.children[#v.children+1]=o end
 end
 o.p[k]=v
 if k=='CFrame'then o.p.Position=v.Position end
end
function methods:IsA(c)return self.class==c or c=='BasePart'and(self.class=='Part'or self.class=='WedgePart')end
function methods:GetChildren()return{table.unpack(self.children)}end
function methods:GetDescendants()
 local all={};local function walk(p)for _,c in ipairs(p.children)do all[#all+1]=c;walk(c)end end;walk(self);return all
end
function methods:IsDescendantOf(p)local a=self.Parent;while a do if a==p then return true end;a=a.Parent end;return false end
function methods:FindFirstChild(n,recursive)
 for _,c in ipairs(self.children)do if c.Name==n then return c end;if recursive then local f=c:FindFirstChild(n,true);if f then return f end end end
end
function methods:FindFirstChildOfClass(c)for _,o in ipairs(self.children)do if o:IsA(c)then return o end end end
function methods:WaitForChild(n)return assert(self:FindFirstChild(n),n)end
function methods:GetPropertyChangedSignal(n)self.signals[n]=self.signals[n]or signal();return self.signals[n]end
function methods:Destroy()
 if self.p.Destroyed then return end;self.p.Destroyed=true;self.Destroying:Fire()
 for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil
end
function methods:GetPivot()return self:FindFirstChild('HumanoidRootPart').CFrame end
function methods:PivotTo(cf)self:FindFirstChild('HumanoidRootPart').CFrame=cf end
workspace=Instance.new('Workspace')
local player=Instance.new('Player');local pg=Instance.new('PlayerGui');pg.Parent=player
local char=Instance.new('Model');player.Character=char;char.Parent=workspace
local root=Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=CFrame.new(20,3,20);root.Size=Vector3.new(2,2,1);root.Parent=char
local h=Instance.new('Humanoid');h.Health=100;h.HipHeight=2;h.Parent=char
local doorContainer=Instance.new('Model');doorContainer.Name='Door';doorContainer.Parent=workspace
local door=Instance.new('Part');door.Name='DoorInnerTouch';door.Size=Vector3.new(5,10,.2);door.CFrame=CFrame.new(0,5,0);door.Parent=doorContainer
local knock=Instance.new('Sound');knock.Name='DoorKnock';knock.SoundId='rbxassetid://fixture';knock.Volume=1;knock.Parent=door
local camera={CFrame=CFrame.new(20,10,30),Focus=CFrame.new(),CameraType='Custom',CameraSubject=h}
function camera:WorldToViewportPoint()return{X=500,Y=400,Z=5},true end
function camera:WorldToScreenPoint()return{X=500,Y=436,Z=5},true end
workspace.CurrentCamera=camera
function workspace:Raycast(p)return{Position=Vector3.new(p.X,0,p.Z),Normal=Vector3.new(0,1,0)}end
function workspace:GetPartBoundsInBox()return{}end
local hb=signal();local input=Instance.new('UserInputService');local clicks={}
local services={Players={LocalPlayer=player},UserInputService=input,RunService={Heartbeat=hb},TweenService={},VirtualInputManager={},HttpService={},TeleportService={TeleportInitFailed=signal()}}
local tweens={}
function services.TweenService:Create(o,info,props)
 local t={Object=o,Props=props,Duration=info[1]}
 function t:Play()self.Played=true;if info[4]~=-1 then for k,v in pairs(props)do o[k]=v end end end
 function t:Cancel()self.Cancelled=true end
 tweens[#tweens+1]=t;return t
end
input.MouseBehavior='LockCenter'
function input:GetFocusedTextBox()return self.FocusedBox end
function input:GetMouseLocation()return Vector2.new(40,50)end
function input:CreateVirtualInput()return self.Virtual end
local moves={}
function services.VirtualInputManager:SendMouseMoveEvent(x,y)moves[#moves+1]={X=x,Y=y}end
function services.VirtualInputManager:SendMouseButtonEvent(x,y,_,down)
 clicks[#clicks+1]=down;self.LastY=y
 if self.Fail and down then error('fixture: mouse denied')end
 if down and y==(self.ViewportOnly and 400 or 436) and not self.Silent then knock.Played:Fire() end
end
player.UserId=123
game={PlaceId=100,JobId='current-test-job',GetService=function(_,n)return assert(services[n],n)end}
task={spawn=function(fn)fn()end,wait=function()end}


function methods:GetFullName()
 local names={};local p=self
 while p and p~=game do table.insert(names,1,p.Name);p=p.Parent end
 return table.concat(names,'.')
end
function methods:CaptureFocus()self.Focused=true end
local f=assert(io.open('NPC-Hit-Diagnostic.lua','rb'));local source=f:read('*a');f:close()
local prefix=assert(source:match('^(.-)%-%- BEGIN ROBLOX CLIENT'))
local Diagnostic=assert(load(prefix..'\nreturn Diagnostic','@NPCHitDiagnostic/Core'))()
local remote={Kind='Instance',Name='GeneralHit'}
local part={Kind='Instance',Name='Right Arm'}
local opaque={Kind='Instance',Name='Opaque123'}
local function kind(v)if type(v)=='table'and v.Kind then return v.Kind end;return type(v)end
local config={Kind=kind,Clock=function()return time end,Epoch=function()return 123456 end,PlaceId=100,JobId='fixture',Capabilities={fixture=true},
 Describe=function(v)return{Name=v.Name,ClassName='RemoteEvent',FullPath='Workspace.'..v.Name,Expression='game['..string.format('%q',v.Name)..']',Target=v==part and {Kind='NPC',Name='Skeleton'}or nil}end,
 Caller=function()return{Available=false},{Available=false}end,Value=function()return nil end}
local core=Diagnostic.new(config)
core:capture(remote,'FireServer',table.pack(part,nil,7),'game')
eq(#core.Reports,1);local report=core.Reports[1]
eq(report.Method,'FireServer');eq(report.ArgumentCount,3);eq(report.Arguments[2].Type,'nil');eq(#report.Targets,1)
eq(report.CallPreview,'game["GeneralHit"]:FireServer(game["Right Arm"], nil, 7)')
eq(report.Observation:find('damage not observed',1,true)~=nil,true)
time=time+.1;core:capture(remote,'FireServer',table.pack(part),'executor');eq(#core.Reports,1)
core:capture(remote,'Destroy',table.pack(part),'game');eq(#core.Reports,1)
core:capture(opaque,'FireServer',table.pack('no NPC'),'game');eq(#core.Reports,1)
core:capture(opaque,'FireServer',table.pack({target=part}),'game');eq(#core.Reports,2)
time=time+.1;core.Recording=false;core:capture(remote,'FireServer',table.pack(part),'game');eq(#core.Reports,2)
core.Recording=true;core.BroadUntil=time+10
core:capture(opaque,'InvokeServer',table.pack('opaque target'),'unknown');eq(#core.Reports,3);eq(core.Reports[3].Method,'InvokeServer')
eq(core.Reports[3].Match,'10-second broad capture')
time=time+11;core:capture(opaque,'InvokeServer',table.pack('opaque target'),'game');eq(#core.Reports,3)
local cycle={};cycle.self=cycle
core:capture(remote,'FireServer',table.pack(cycle),'game');report=core.Reports[#core.Reports]
eq(report.Arguments[1].Entries[1].Value.Type,'reference');eq(report.CallPreview:find('Unavailable',1,true)~=nil,true)
time=time+.1;core:capture(remote,'FireServer',table.pack(string.rep('я',2000)),'game');report=core.Reports[#core.Reports]
eq(report.Truncated,true);eq(report.Arguments[1].OriginalBytes,4000);eq(utf8.len(report.Arguments[1].Value)~=nil,true)
time=time+.1;core:capture(remote,'FireServer',table.pack('\255\254'),'game');report=core.Reports[#core.Reports]
-- Use genuinely invalid UTF-8 bytes as well as literal escapes.
time=time+.1;core:capture(remote,'FireServer',table.pack(string.char(255,254)),'game');report=core.Reports[#core.Reports]
eq(report.Arguments[1].Encoding,'hex');eq(report.Arguments[1].Value,'fffe')
local many={n=20};for i=1,20 do many[i]=i end
time=time+.1;core:capture(remote,'FireServer',many,'game');report=core.Reports[#core.Reports]
eq(report.ArgumentCount,20);eq(#report.Arguments,16);eq(report.Truncated,true)
local bounded=Diagnostic.new(config)
for i=1,100 do time=time+.01;bounded:capture(remote,'FireServer',table.pack(part),'game')end
eq(#bounded.Reports,12);eq(bounded.Sequence<=28,true);eq(bounded.Dropped>0,true)
-- Several packets from one manual hit can occur in the same frame.
local burst=Diagnostic.new(config)
for i=1,10 do burst:capture(remote,'FireServer',table.pack(part,i),'game')end
eq(#burst.Reports,8);eq(burst.Dropped,2)
for i,entry in ipairs(burst.Reports)do eq(entry.Arguments[2].Value,i)end
burst:Destroy()
local prior=bounded.Sequence;bounded:Destroy();time=time+.1;bounded:capture(remote,'FireServer',table.pack(part),'game');eq(bounded.Sequence,prior)
-- Hook adapter forwards exactly once, preserving nils, all results, errors and yields.
local installed,wrapped=0,nil;local forwarded=0;local method='FireServer';local behavior='normal';local notices=0
local runtime={}
local adapter={Game=runtime,GetNamecallMethod=function()return method end,NewCClosure=function(fn)return fn end,
 HookMetamethod=function(_,name,fn)
  eq(name,'__namecall');installed=installed+1;wrapped=fn
  return function(receiver,...)
   forwarded=forwarded+1
   if behavior=='error'then error('original RPC error')end
   if behavior=='yield'then coroutine.yield('waiting')end
   return receiver,nil,select('#',...)
  end
 end}
local hook=Diagnostic.install(adapter);eq(hook.Ready,true);eq(installed,1)
hook.Listener=function(_,observed,args)notices=notices+1;eq(observed,'FireServer');eq(args.n,3);error('observer failed')end
local result=table.pack(wrapped(remote,part,nil,4));eq(result.n,3);eq(result[1],remote);eq(result[2],nil);eq(result[3],3)
eq(forwarded,1);eq(notices,1)
hook.Listener=nil;behavior='error';local good,why=pcall(wrapped,remote,part);eq(good,false);eq(why:find('original RPC error',1,true)~=nil,true)
behavior='yield';local co=coroutine.create(function()return wrapped(remote,part)end)
local good,value=coroutine.resume(co);eq(good,true);eq(value,'waiting')
local resumed=table.pack(coroutine.resume(co));eq(resumed[1],true);eq(resumed[2],remote);eq(resumed[4],1)
adapter.Existing=hook;eq(Diagnostic.install(adapter),hook);eq(installed,1)
local missing=Diagnostic.install({Game={}});eq(missing.Ready,false);eq(#missing.Errors>0,true)
-- Function-hook fallback records FireServer/InvokeServer and preserves their return values.
local wrappers={};local functions={FireServer=function()return 'fire' end,InvokeServer=function()return 'invoke',nil,9 end}
local fallback=Diagnostic.install({Game={},MethodFunction=function(name)return functions[name]end,
 HookFunction=function(fn,wrapper)for name,f in pairs(functions)do if fn==f then wrappers[name]=wrapper end end;return fn end})
eq(fallback.Ready,true);eq(#fallback.Modes,2)
local fallbackCalls=0;fallback.Listener=function(_,m)fallbackCalls=fallbackCalls+1;eq(m,'InvokeServer')end
result=table.pack(wrappers.InvokeServer(remote,part));eq(result.n,3);eq(result[1],'invoke');eq(result[3],9);eq(fallbackCalls,1)
-- Real client script + GUI + hook bridge with actual remote and NPC path snapshots.
local objects={};local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
function services.HttpService:JSONEncode(v)objects[#objects+1]=copy(v);return 'json:'..#objects end
function services.HttpService:JSONDecode(s)local i=tonumber(s:match('^json:(%d+)$'));return copy(assert(objects[i],'invalid JSON'))end
function services.Players:GetPlayers()return{player}end
function services.Players:GetPlayerFromCharacter(c)if c==player.Character then return player end end
function typeof(v)
 if type(v)=='table'and rawget(v,'class')then return'Instance'end
 if getmetatable(v)==vm then return'Vector3'end
 if getmetatable(v)==cm then return'CFrame'end
 return type(v)
end
game.children={};workspace.Parent=game
local storage=Instance.new('ReplicatedStorage');storage.Parent=game
local event=Instance.new('RemoteEvent');event.Name='GeneralHit';event.Parent=storage
local enemies=Instance.new('Folder');enemies.Name='Enemies';enemies.Parent=workspace
local skeleton=Instance.new('Model');skeleton.Name='Skeleton';skeleton.Parent=enemies
local humanoid=Instance.new('Humanoid');humanoid.Health=80;humanoid.MaxHealth=100;humanoid.RigType='R6';humanoid.Parent=skeleton
local arm=Instance.new('Part');arm.Name='Right Arm';arm.Size=Vector3.new(1,2,1);arm.CFrame=CFrame.new(5,3,4);arm.CanTouch=true;arm.Parent=skeleton
local script=Instance.new('LocalScript');script.Name='GloveClient';script.Parent=char
local hudWrapped;local hookInstalls=0;local passThrough=0;local fromExecutor=false;method='FireServer'
hookmetamethod=function(_,_,fn)hookInstalls=hookInstalls+1;hudWrapped=fn;return function()passThrough=passThrough+1;return'transmitted'end end
getnamecallmethod=function()return method end
newcclosure=function(fn)return fn end
checkcaller=function()return fromExecutor end
getcallingscript=function()return script end
identifyexecutor=function()return'Fixture','1'end
local clipboard
setclipboard=function(text)clipboard=text end
local autoEnabled=true
_G.ProbothotspotNPCGeneralHit={JobId=game.JobId,Engine={Enabled=true,setEnabled=function(self,value)autoEnabled=value;self.Enabled=value end}}
local app=dofile('NPC-Hit-Diagnostic.lua')
local function find(name)return assert(app.Gui:FindFirstChild(name,true),name)end
local function tick()time=time+.1;hb:Fire(.1)end
eq(app.Gui.Parent,pg);eq(find('Title').Text,'NPC Hit Diagnostic 1.0.0');eq(autoEnabled,false);eq(passThrough,0);eq(hookInstalls,1)
local packet={n=3,arm,nil,7};hudWrapped(event,table.unpack(packet,1,packet.n));eq(passThrough,1);tick()
report=app.Engine.Reports[1];eq(report.Remote.FullPath,'ReplicatedStorage.GeneralHit');eq(report.Remote.ClassName,'RemoteEvent')
eq(report.Remote.Expression,'game:GetService("ReplicatedStorage")["GeneralHit"]')
eq(report.Arguments[1].FullPath,'Workspace.Enemies.Skeleton.Right Arm');eq(report.Arguments[2].Type,'nil')
eq(report.Targets[1].FullPath,'Workspace.Enemies.Skeleton');eq(report.Targets[1].Health,80)
eq(report.LocalCharacter.Health,100);eq(report.Initiator.Available,true);eq(report.Initiator.FullPath,'Workspace.Model.GloveClient')
eq(report.CallPreview:find('["Right Arm"]',1,true)~=nil,true)
eq(find('Report').Text:find('Workspace.Enemies.Skeleton.Right Arm',1,true)~=nil,true)
find('Copy').Activated:Fire();eq(type(clipboard),'string');eq(clipboard,app.CopyText)
local token=assert(clipboard:match('JSON ALL:\n(json:%d+)'));local all=services.HttpService:JSONDecode(token)
eq(#all.Reports,1);eq(all.Capabilities.Installed,true);eq(all.Capabilities.Executor,'Fixture')
-- No injected-script noise, stopping/starting, bounded history navigation and broad capture.
fromExecutor=true;time=time+.1;hudWrapped(event,arm);eq(#app.Engine.Reports,1);fromExecutor=false
find('Record').Activated:Fire();time=time+.1;hudWrapped(event,arm);eq(#app.Engine.Reports,1)
find('Record').Activated:Fire();time=time+.1;hudWrapped(event,arm);tick();eq(#app.Engine.Reports,2)
find('Previous').Activated:Fire();eq(find('Count').Text:find('1',1,true)~=nil,true);find('Next').Activated:Fire()
local other=Instance.new('RemoteEvent');other.Name='Opaque';other.Parent=storage
find('Broad').Activated:Fire();time=time+.1;hudWrapped(other,'target123');tick();eq(#app.Engine.Reports,3)
eq(app.Engine.Reports[3].Match,'10-second broad capture')
-- A second load reuses a dispatcher instead of stacking another hook.
local previous=app;app=dofile('NPC-Hit-Diagnostic.lua');eq(previous.Destroyed,true);eq(previous.Gui.Parent,nil);eq(hookInstalls,1)
time=time+.1;hudWrapped(event,arm);tick();eq(#app.Engine.Reports,1)
find('Close').Activated:Fire();eq(app.Destroyed,true);local observed=app.Engine.Sequence
hudWrapped(event,arm);eq(app.Engine.Sequence,observed);eq(_G.ProbothotspotNPCHitHook.Listener,nil)
-- Missing APIs produce a visible, copyable capability report, not fake captures.
_G.ProbothotspotNPCHitHook=nil;hookmetamethod=nil;getnamecallmethod=nil;newcclosure=nil
app=dofile('NPC-Hit-Diagnostic.lua');eq(find('Status').Text:find('недоступен',1,true)~=nil,true)
find('Copy').Activated:Fire();token=assert(clipboard:match('JSON ALL:\n(json:%d+)'));all=services.HttpService:JSONDecode(token)
eq(all.Capabilities.Installed,false);eq(#all.Reports,0)
setclipboard=nil;find('Copy').Activated:Fire();eq(find('Report').Focused,true);eq(find('Report').SelectionStart,#find('Report').Text+1)
app:Destroy()
local active=0;for _,sig in ipairs(signals)do for _,conn in ipairs(sig.listeners)do if conn.Connected then active=active+1 end end end
eq(active,0);eq(_G.ProbothotspotNPCHitDiagnostic,nil)
os.clock=realClock
print('PASS: '..count..' bounded packet snapshots, paths, filtering, forwarding, nils, errors, yields, hook reuse/fallback, actual GUI, clipboard and cleanup assertions')
