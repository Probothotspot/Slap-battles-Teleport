-- Small deterministic engine fixture: not a replacement for live Roblox physics.
local count=0
local function eq(a,b) count=count+1;assert(a==b,'Lantern AutoHit #'..count..': '..tostring(a)..' ~= '..tostring(b)..debug.traceback('',2))end
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


function cm.__index:PointToObjectSpace(p)
 local d=p-self.Position
 return Vector3.new(d:Dot(self.RightVector),d:Dot(self.UpVector),-d:Dot(self.LookVector))
end
function methods:GetAttribute(name)return(self.p.Attributes or {})[name]end
function methods:SetAttribute(name,value)self.p.Attributes=self.p.Attributes or {};self.p.Attributes[name]=value end
function methods:GetFullName()
 local names={};local p=self
 while p and p~=game do table.insert(names,1,p.Name);p=p.Parent end
 return table.concat(names,'.')
end
function methods:CaptureFocus()self.Focused=true end
local f=assert(io.open('Lantern-AutoHit.lua','rb'));local source=f:read('*a');f:close()
local prefix=assert(source:match('^(.-)%-%- BEGIN ROBLOX CLIENT'))
local Core=assert(load(prefix..'\nreturn Core','@LanternAutoHit/Core'))()
local function npc(world,name,size,pos,partName)
 local model=Instance.new('Model');model.Name=name;model.Parent=world
 local human=Instance.new('Humanoid');human.Health=100;human.Parent=model
 local part=Instance.new('Part');part.Name=partName or 'CandyCorn';part.Size=size or Vector3.new(2,2,2);part.CFrame=CFrame.new(pos or Vector3.new(3,0,0));part.Parent=model
 part.CanQuery=false;part.CanTouch=true;part:SetAttribute('slappable',true)
 return model,human,part
end
local function lantern(character,fn)
 local tool=Instance.new('Tool');tool.Name='Lantern';tool.Enabled=true;tool:SetAttribute('AttackActive',true);tool.Parent=character
 local handle=Instance.new('Part');handle.Name='Handle';handle.CFrame=CFrame.new(0,0,0);handle.Size=Vector3.new(1,1,1);handle.Parent=tool
 local remote=Instance.new('RemoteEvent');remote.Name='Network';remote.Parent=tool
 function remote:FireServer(...)return fn(self,...)end
 function tool:Activate()self.Activations=(self.Activations or 0)+1;if self.ActivationError then error('activation failed')end;if not self.NoAttribute then self:SetAttribute('AttackActive',true)end end
 function tool:Deactivate()self.Deactivations=(self.Deactivations or 0)+1;self:SetAttribute('AttackActive',false)end
 return tool,remote
end
local world=Instance.new('Workspace')
local character,ch,cpart=npc(world,'Local')
local players={list={{Character=character}}}
function players:GetPlayers()return self.list end
function players:GetPlayerFromCharacter(model)for _,p in ipairs(self.list)do if p.Character==model then return p end end end
local calls={}
local function record(remote,...)calls[#calls+1]={Receiver=remote,Args=table.pack(...),At=time}end
local tool,network=lantern(character,record)
local a,ah,ap=npc(world,'Small',Vector3.new(1,1,1),Vector3.new(3,0,0))
local b,bh,bp=npc(world,'Large',Vector3.new(10,10,10),Vector3.new(6,0,0))
local nested,nh,np=npc(character,'NestedPlayerRig')
local pose=Instance.new('Pose');pose.Name='CandyCorn';pose.Parent=a
local other,oh,op=npc(world,'AnotherPlayer');players.list[2]={Character=other}
local unrelated=Instance.new('Part');unrelated.Name='CandyCorn';unrelated.Parent=world
local config={World=world,Players=players,Character=function()return character end}
local core=Core.new(config);core:step()
eq(core.Ready,true);eq(#core.List,2);eq(#calls,0);eq(core.Rate,4);eq(core.Range,8);eq(core.Swing,true)
core:setSwing(false);core:setEnabled(true);core:step()
eq(#calls,1);eq(calls[1].Receiver,network);eq(calls[1].Args.n,2);eq(calls[1].Args[1],'Hit');eq(calls[1].Args[2],bp)
eq(core.LastDistance,1);eq(core.LastSize.X,10)
time=time+.26;core:step();eq(calls[2].Args[2],ap)
-- Poses, player rigs, standalone pickups and CanQuery=false never confuse physical NPC selection.
eq(core.Index[pose],nil);eq(core.Index[np],nil);eq(core.Index[op],nil);eq(core.Index[unrelated],nil)
eq(core.Index[bp]~=nil,true)
core:setEnabled(false);local before=#calls;time=time+1;core:step();eq(#calls,before)
for _,bad in ipairs({0,-1,21,1.5,0/0,math.huge,'5'})do eq(core:setRate(bad),false)end
for _,bad in ipairs({0,-1,31,0/0,math.huge,'8'})do eq(core:setRange(bad),false)end
eq(core:setRate(20),true);eq(core:setRange(2.5),true)
-- Oriented box distance handles rotations, varying sizes and positions inside the body.
local block=Instance.new('Part');block.Size=Vector3.new(2,4,8);block.CFrame=CFrame.new(10,0,0)
eq(Core.boxDistance(block,Vector3.new(10,0,0)),0);eq(Core.boxDistance(block,Vector3.new(0,0,0)),9)
block.CFrame=CFrame.lookAt(Vector3.new(10,0,0),Vector3.new(11,0,0))
eq(Core.boxDistance(block,Vector3.new(0,0,0)),6)
block.Size=Vector3.new(2,4,20);eq(Core.boxDistance(block,Vector3.new(0,0,0)),0)
-- Network is resolved from the current local Lantern, including replacement of the remote/tool/character.
core:setRange(8);network.Parent=nil;core:setEnabled(true);time=time+.3;before=#calls;core:step()
eq(#calls,before);eq(core.StatusCode,'waiting_tool');eq(core.Enabled,true)
network=Instance.new('RemoteEvent');network.Name='Network';network.Parent=tool;network.FireServer=record
time=time+.3;core:step();eq(calls[#calls].Receiver,network)
local old=tool;old.Parent=nil;tool,network=lantern(character,record)
time=time+.3;core:step();eq(calls[#calls].Receiver,network)
local previousChar=character;character,ch,cpart=npc(world,'Respawned');players.list[1].Character=character;previousChar.Parent=nil
ch.Health=0;time=time+.3;before=#calls;core:step();eq(#calls,before);eq(core.StatusCode,'waiting_tool')
ch.Health=100;tool,network=lantern(character,record);time=time+.3;core:step();eq(calls[#calls].Receiver,network)
-- A resized existing NPC is reconsidered using current Size, never a fixed center-distance assumption.
ah.Health=0;bp.CFrame=CFrame.new(20,0,0);bp.Size=Vector3.new(1,1,1);time=time+.3;before=#calls;core:step();eq(#calls,before)
bp.Size=Vector3.new(40,40,40);time=time+.1;core:step();eq(#calls,before+1);eq(core.LastDistance,0)
-- No health loss is invented when all packets are ignored.
local lossBefore=core.ObservedHPLoss
time=time+.05;core:step();eq(core.ObservedHPLoss,lossBefore)
bh.Health=90;time=time+.05;core:step();eq(core.ObservedHPLoss,lossBefore+10)
time=time+.05;core:step();eq(core.ObservedHPLoss,lossBefore+10)
bh.Health=100;time=time+.05;core:step();eq(core.ObservedHPLoss,lossBefore+10)
-- Window-gated swings run Tool:Activate; no AttackActive attribute is forged.
core:setEnabled(false);tool:SetAttribute('AttackActive',false);core:setSwing(true);core:setEnabled(true)
time=time+.3;before=#calls;core:step();eq(tool.Activations,1);eq(core.Swings,1);eq(#calls,before+1)
time=time+.07;core:step();eq(tool.Deactivations,1)
core:setEnabled(false);tool:SetAttribute('AttackActive',false)
local oldActivate=tool.Activate;tool.Activate=function(self)self.Activations=self.Activations+1 end
core:setEnabled(true);time=time+.3;before=#calls;core:step();eq(#calls,before);eq(core.StatusCode,'waiting_swing')
time=time+.1;core:step();eq(#calls,before)
core:setEnabled(false);tool.Activate=oldActivate
-- Absent AttackActive uses an explicit timed attempt, never labels the attribute as true.
tool.NoAttribute=true;tool:SetAttribute('AttackActive',nil);tool.Deactivate=function(self)self.Deactivations=(self.Deactivations or 0)+1 end
core:setEnabled(true);time=time+.3;before=#calls;core:step();eq(#calls,before)
time=time+.08;core:step();eq(#calls,before+1);eq(core.AttackActive,nil)
core:setEnabled(false);tool.NoAttribute=false
-- Failed FireServer backs off; a resumed/dropped frame does not cause a catch-up burst.
core:setSwing(false);core:setEnabled(true);network.FireServer=function()error('fixture server request failure')end
time=time+.3;core:step();eq(core.StatusCode,'fire_error');local failures=core.Failures
time=time+.1;core:step();eq(core.Failures,failures)
network.FireServer=record;time=time+30;before=#calls;core:step();eq(#calls-before,1)
-- Reentrant Heartbeat and OFF/Destroy during dispatch cannot send another request.
network.FireServer=function(r,...)core:step();return record(r,...)end
time=time+.3;before=#calls;core:step();eq(#calls-before,1);eq(core.Busy,false)
network.FireServer=function(r,...)core:setEnabled(false);return record(r,...)end
time=time+.3;core:step();eq(core.Enabled,false);eq(core.Message,'OFF — остановлено')
-- New NPC with an arbitrary part name is eligible only via slappable=true and Humanoid.
local fresh,fh,fp=npc(world,'Fresh',nil,nil,'DifferentHitbox');core:added(fp);core:step();eq(core.Index[fp]~=nil,true)
core:remove(fp);fp.Parent=nil;eq(core.Index[fp],nil)
local late=Instance.new('Model');late.Parent=world;local latePart=Instance.new('Part');latePart.Name='CandyCorn';latePart.Parent=late
core:added(latePart);core:step();eq(core.Index[latePart],nil)
local lateHuman=Instance.new('Humanoid');lateHuman.Health=100;lateHuman.Parent=late;core:added(lateHuman);core:step();eq(core.Index[latePart]~=nil,true)
-- Large animation dumps are skipped, and indexing is bounded before the initial scan completes.
local bigWorld=Instance.new('Workspace');local animation=Instance.new('KeyframeSequence');animation.Parent=bigWorld
for i=1,2000 do local o=Instance.new('Pose');o.Name='CandyCorn';o.Parent=animation end
for i=1,2000 do local o=Instance.new('Folder');o.Parent=bigWorld end
local scan=Core.new({World=bigWorld,Players=players,Character=function()return character end})
scan:step();eq(scan.Ready,false);eq(scan.Scanned<=512,true)
for i=1,30 do scan:step()end
eq(scan.Ready,true);eq(scan.Scanned,2001)
scan:Destroy();core:Destroy();eq(core.Destroyed,true);eq(#core.List,0)
-- Full production GUI with actual controls, animated states, clipboard and cleanup.
function services.Players:GetPlayers()return{player}end
function services.Players:GetPlayerFromCharacter(model)if model==player.Character then return player end end
local actualCalls={};local realTool,realNetwork=lantern(player.Character,function(r,...)actualCalls[#actualCalls+1]={Receiver=r,Args=table.pack(...)}end)
local target,th,tpart=npc(workspace,'Target',Vector3.new(2,2,2),Vector3.new(4,0,0))
local encoded={}
function services.HttpService:JSONEncode(value)encoded[#encoded+1]=value;return 'json:'..#encoded end
local clipboard
setclipboard=function(text)clipboard=text end
local app=dofile('Lantern-AutoHit.lua')
local function find(name)return assert(app.Gui:FindFirstChild(name,true),name)end
local function tick(dt)time=time+dt;hb:Fire(dt)end
eq(app.Gui.Parent,pg);eq(find('Title').Text,'Lantern AutoHit 1.0.0');eq(find('Window').GroupTransparency,0)
eq(find('Window'):FindFirstChildOfClass('UIGradient')~=nil,true);eq(app.Engine.Enabled,false)
tick(.1);eq(#actualCalls,0)
find('Swing').Activated:Fire();eq(app.Engine.Swing,false)
find('Rate').Text='3';find('Rate').FocusLost:Fire(true);eq(app.Engine.Rate,3)
find('Plus').Activated:Fire();eq(app.Engine.Rate,4);find('Minus').Activated:Fire();eq(app.Engine.Rate,3)
find('Range').Text='2';find('Range').FocusLost:Fire(true);eq(app.Engine.Range,2)
find('Toggle').Activated:Fire();tick(.3);eq(#actualCalls,0)
find('Range').Text='6';find('Range').FocusLost:Fire(true)
for i=1,20 do tick(.1)end
eq(#actualCalls>=4 and #actualCalls<=6,true)
for _,call in ipairs(actualCalls)do eq(call.Receiver,realNetwork);eq(call.Args.n,2);eq(call.Args[1],'Hit');eq(call.Args[2],tpart)end
find('Rate').Text='-5';find('Rate').FocusLost:Fire(true);eq(app.Engine.Rate,3)
find('Range').Text='100';find('Range').FocusLost:Fire(true);eq(app.Engine.Range,6)
find('Copy').Activated:Fire();eq(clipboard,app.CopyText);eq(encoded[#encoded].SentRequests,#actualCalls);eq(encoded[#encoded].ObservedHPLoss,0)
setclipboard=nil;find('Copy').Activated:Fire();eq(find('Export').Focused,true)
find('Collapse').Activated:Fire();eq(find('Body').Visible,false);eq(find('Window').Size.Y.Offset,44)
find('Collapse').Activated:Fire();eq(find('Body').Visible,true);eq(find('Window').Size.Y.Offset,460)
local window=find('Window');local x=window.Position.X.Offset
local pointer={UserInputType='MouseButton1',Position=Vector3.new(10,10,0)}
find('Header').InputBegan:Fire(pointer);input.InputChanged:Fire({UserInputType='MouseMovement',Position=Vector3.new(50,20,0)})
input.InputEnded:Fire(pointer);eq(window.Position.X.Offset,x+40)
local previous=app;app=dofile('Lantern-AutoHit.lua');eq(previous.Destroyed,true);eq(previous.Gui.Parent,nil)
find('Toggle').Activated:Fire();tick(.1);find('Close').Activated:Fire();local beforeClose=#actualCalls
tick(1);eq(#actualCalls,beforeClose);eq(app.Destroyed,true)
app=dofile('Lantern-AutoHit.lua');game.JobId='changed-job';tick(.1);eq(app.Destroyed,true)
local active=0;for _,sig in ipairs(signals)do for _,conn in ipairs(sig.listeners)do if conn.Connected then active=active+1 end end end
eq(active,0);eq(_G.ProbothotspotLanternAutoHit,nil)
os.clock=realClock
print('PASS: '..count..' Lantern packet, oriented size-aware distance, player/pose exclusion, swing gating, health observation, replacement, frame limits, GUI and clipboard assertions')
