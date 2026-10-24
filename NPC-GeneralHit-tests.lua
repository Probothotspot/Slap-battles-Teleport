-- Small deterministic engine fixture: not a replacement for live Roblox physics.
local count=0
local function eq(a,b) count=count+1;assert(a==b,'NPC GeneralHit #'..count..': '..tostring(a)..' ~= '..tostring(b))end
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
 if k=='GeneralHit' or k=='Remotes' then
  local child=methods.FindFirstChild(o,k)
  if child then return child end
  error(k..' is not a valid member of '..o.class)
 end
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

local f=assert(io.open('NPC-GeneralHit.lua','rb'));local source=f:read('*a');f:close()
local prefix=assert(source:match('^(.-)%-%- BEGIN ROBLOX CLIENT'))
local Core=assert(load(prefix..'\nreturn Core','@NPCGeneralHit/Core'))()
local function npc(world,name,partName)
 local model=Instance.new('Model');model.Name=name;model.Parent=world
 local human=Instance.new('Humanoid');human.Health=100;human.Parent=model
 local arm=Instance.new('Part');arm.Name=partName or 'Right Arm';arm.Parent=model
 return model,human,arm
end
local function remote(storage,fn)
 local event=Instance.new('RemoteEvent');event.Name='GeneralHit';event.Parent=storage
 function event:FireServer(part)return fn(self,part)end
 return event
end
local world=Instance.new('Workspace');local storage=Instance.new('ReplicatedStorage')
local remotes=Instance.new('Folder');remotes.Name='Remotes';remotes.Parent=storage
local a,ah,armA=npc(world,'A');local b,bh,armB=npc(world,'B','RightHand')
local character,ch=npc(world,'PlayerCharacter');local nested,nh=npc(character,'NestedPlayerRig')
local players={list={{Character=character}}}
function players:GetPlayers()return self.list end
function players:GetPlayerFromCharacter(model)for _,p in ipairs(self.list)do if p.Character==model then return p end end end
local rootCalls=0;local trap=remote(storage,function()rootCalls=rootCalls+1;error('wrong root-level GeneralHit')end)
local calls={};local event=remote(remotes,function(r,part)calls[#calls+1]={Remote=r,Part=part,At=time}end)
local core=Core.new({World=world,Players=players,Storage=storage})
eq(core.Enabled,false);core:step();eq(#core.List,2);eq(core.Ready,true);eq(#calls,0)
core:setEnabled(true)
for i=0,199 do time=i/100;core:step()end
eq(#calls>=19 and #calls<=21,true)
for i,call in ipairs(calls)do eq(call.Part==armA or call.Part==armB,true);if i>1 then eq(call.Part~=calls[i-1].Part,true)end end
core:setEnabled(false);local before=#calls;time=time+1;core:step();eq(#calls,before)
for _,bad in ipairs({0,-1,101,1.5,0/0,math.huge,'20'})do eq(core:setRate(bad),false)end
eq(core.Rate,10);eq(core:setRate(100),true)
-- Dead NPCs are skipped; target limbs are looked up again, never held across respawns.
bh.Health=0;armA.Parent=nil
local replacement=Instance.new('Part');replacement.Name='Right Arm';replacement.Parent=a
core:setEnabled(true);time=time+.1;before=#calls;core:step();eq(#calls>before,true)
for i=before+1,#calls do eq(calls[i].Part,replacement)end
-- Removal/replacement of the remote is re-resolved instead of terminating the script.
event.Parent=nil;before=#calls;time=time+.1;core:step();eq(#calls,before);eq(core.Enabled,true)
eq(core.StatusCode,'remote_missing');eq(core.LastError:find('GeneralHit is not a valid member',1,true)~=nil,true)
eq(core.Message:find('ReplicatedStorage.Remotes.GeneralHit:',1,true)~=nil,true)
local replacementRemote=remote(remotes,function(r,part)calls[#calls+1]={Remote=r,Part=part,At=time}end)
time=time+.3;core:step();eq(calls[#calls].Remote,replacementRemote)
eq(core.StatusCode,'sent');eq(core.LastError,nil);eq(rootCalls,0);eq(core.RemotePath,'ReplicatedStorage.Remotes.GeneralHit')
-- A callable FireServer is used directly, without rejecting a different event class.
replacementRemote.class='UnreliableRemoteEvent';before=#calls;time=time+.1;core:step();eq(#calls>before,true)
replacementRemote.class='RemoteEvent'
-- A newly replicated NPC enters the queue without a whole-world refresh.
local fresh,fh,fpart=npc(world,'Fresh','HumanoidRootPart');core:added(fh)
time=time+.1;core:step();eq(core.Index[fh]~=nil,true)
fh.Parent=nil;core:remove(fh);eq(core.Index[fh],nil);eq(#core.List,2)
-- A newly assigned player character is excluded even if it was indexed as an NPC earlier.
players.list[2]={Character=a};time=time+.2;before=#calls;core:step();eq(#calls,before)
players.list[2]=nil
-- A long dropped frame cannot replay hundreds of overdue calls.
bh.Health=100;core:setEnabled(true);time=time+30;before=#calls;core:step();eq(#calls-before<=2,true)
-- Reentrant Heartbeat during executor IO cannot create a second concurrent dispatch.
local reentered=0
local racing=Core.new({World=world,Players=players,Storage=storage})
local oldFire=replacementRemote.FireServer
replacementRemote.FireServer=function(self,part)reentered=reentered+1;racing:step();return oldFire(self,part)end
racing:setEnabled(true);racing:step();eq(reentered,1);eq(racing.Sent,1)
replacementRemote.FireServer=function()racing:setEnabled(false)end
time=time+.2;racing:step();eq(racing.Enabled,false);eq(racing.Message,'OFF — остановлено')
replacementRemote.FireServer=function()error('fixture refusal')end
local failing=Core.new({World=world,Players=players,Storage=storage});failing:setEnabled(true);failing:step()
eq(failing.Failures,1);time=time+.1;failing:step();eq(failing.Failures,1);eq(failing.Sending,false)
eq(failing.StatusCode,'invoke_error');eq(failing.Message:find('GeneralHit:FireServer:',1,true)~=nil,true)
eq(failing.LastError:find('fixture refusal',1,true)~=nil,true)
-- Exact receiver, exactly one BasePart argument and no successful-damage claim.
local argumentCount,received,receiver
replacementRemote.FireServer=function(self,...)receiver=self;argumentCount=select('#',...);received=(...)end
local direct=Core.new({World=world,Players=players,Storage=storage});direct:setEnabled(true);direct:step()
eq(argumentCount,1);eq(receiver,replacementRemote);eq(received==armB or received==replacement,true)
direct:Destroy()
-- Missing NPCs are reported separately from a failed or absent remote.
local empty=Core.new({World=Instance.new('Workspace'),Players=players,Storage=Instance.new('ReplicatedStorage')})
empty:setEnabled(true);empty:step();eq(empty.StatusCode,'no_npc');eq(empty.Failures,0);eq(empty.Sent,0);empty:Destroy()
-- Scanning remains incremental and periodic rescans really happen while idle.
local large=Instance.new('Workspace')
for i=1,3000 do local junk=Instance.new('Folder');junk.Parent=large end
local indexing=Core.new({World=large,Players=players,Storage=storage})
indexing:step();eq(indexing.Ready,false);eq(indexing.Scanned<=512,true)
for i=1,60 do indexing:step()end
eq(indexing.Ready,true);local scanned=indexing.Scanned;local due=indexing.NextSweep
time=due-.1;indexing:step();eq(indexing.NextSweep,due)
time=due+.1;indexing:step();eq(indexing.Scanned>scanned,true)
-- The entire Remotes folder can be replaced; the current path must be used again.
remotes.Parent=nil;before=#calls;time=time+.6;core:step();eq(#calls,before);eq(core.StatusCode,'remote_missing');eq(rootCalls,0)
remotes=Instance.new('Folder');remotes.Name='Remotes';remotes.Parent=storage
local folderReplacement=remote(remotes,function(r,part)calls[#calls+1]={Remote=r,Part=part,At=time}end)
time=time+.3;core:step();eq(calls[#calls].Remote,folderReplacement);eq(core.StatusCode,'sent');eq(rootCalls,0)
core:Destroy();racing:Destroy();failing:Destroy();indexing:Destroy()
-- Full production file: actual GUI, controls, events, repeated run and complete cleanup.
services.ReplicatedStorage=Instance.new('ReplicatedStorage')
local fullRemotes=Instance.new('Folder');fullRemotes.Name='Remotes';fullRemotes.Parent=services.ReplicatedStorage
function services.Players:GetPlayers()return {player}end
function services.Players:GetPlayerFromCharacter(model)if model==player.Character then return player end end
local skeleton,sh,sarm=npc(workspace,'Skeleton')
local fullCalls={}
local fullRemote=remote(fullRemotes,function(_,part)fullCalls[#fullCalls+1]=part end)
local app=dofile('NPC-GeneralHit.lua')
local function find(name)return assert(app.Gui:FindFirstChild(name,true),name)end
local function tick(dt)time=time+dt;hb:Fire(dt)end
eq(app.Gui.Parent,pg);eq(find('Title').Text,'NPC GeneralHit 1.0.2');eq(find('Window').GroupTransparency,0)
eq(find('Window'):FindFirstChildOfClass('UIGradient')~=nil,true);eq(find('Toggle').Text,'OFF')
tick(.1);eq(#fullCalls,0)
find('Rate').Text='4';find('Rate').FocusLost:Fire(true);eq(app.Engine.Rate,4)
find('Rate').Text='-5';find('Rate').FocusLost:Fire(true);eq(app.Engine.Rate,4);eq(find('Rate').Text,'4')
find('Plus').Activated:Fire();eq(app.Engine.Rate,5);find('Minus').Activated:Fire();eq(app.Engine.Rate,4)
find('Toggle').Activated:Fire();eq(app.Engine.Enabled,true)
for i=1,20 do tick(.1)end
eq(#fullCalls>=7 and #fullCalls<=9,true)
for _,part in ipairs(fullCalls)do eq(part,sarm)end
local normalFullFire=fullRemote.FireServer
fullRemote.FireServer=function()error(string.rep('ошибка ',40))end
tick(.3);eq(app.Engine.StatusCode,'invoke_error')
eq(find('LogText').Text:find('GeneralHit:FireServer:',1,true)~=nil,true)
eq(find('LogText').Size.Y.Offset>100,true)
fullRemote.FireServer=normalFullFire
find('Toggle').Activated:Fire();before=#fullCalls;tick(1);eq(#fullCalls,before)
find('Collapse').Activated:Fire();eq(find('Body').Visible,false);eq(find('Window').Size.Y.Offset,44)
find('Collapse').Activated:Fire();eq(find('Body').Visible,true);eq(find('Window').Size.Y.Offset,366)
local window=find('Window');local originalX=window.Position.X.Offset
local pointer={UserInputType='MouseButton1',Position=Vector3.new(10,10,0)}
find('Header').InputBegan:Fire(pointer);input.InputChanged:Fire({UserInputType='MouseMovement',Position=Vector3.new(50,20,0)})
input.InputEnded:Fire(pointer);eq(window.Position.X.Offset,originalX+40)
local prior=app;find('Toggle').Activated:Fire();app=dofile('NPC-GeneralHit.lua')
eq(prior.Destroyed,true);eq(prior.Gui.Parent,nil);eq(app.Engine.Enabled,false)
local later,lh,lpart=npc(workspace,'NewSkeleton','Head');workspace.DescendantAdded:Fire(lh);tick(.1)
eq(app.Engine.Index[lh]~=nil,true)
workspace.DescendantRemoving:Fire(lh);lh.Parent=nil;eq(app.Engine.Index[lh],nil)
find('Toggle').Activated:Fire();tick(.1);find('Close').Activated:Fire()
eq(app.Destroyed,true);eq(app.Engine.Enabled,false);before=#fullCalls;tick(1);eq(#fullCalls,before)
app=dofile('NPC-GeneralHit.lua');game.JobId='other-job';tick(.1);eq(app.Destroyed,true)
local active=0;for _,sig in ipairs(signals)do for _,conn in ipairs(sig.listeners)do if conn.Connected then active=active+1 end end end
eq(active,0);eq(_G.ProbothotspotNPCGeneralHit,nil)
os.clock=realClock
print('PASS: '..count..' NPC GeneralHit target, rate, respawn, remote replacement, frame budget, actual GUI and cleanup assertions')
