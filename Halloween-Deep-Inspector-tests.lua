-- Small deterministic engine fixture: not a replacement for live Roblox physics.
local count=0
local function eq(a,b) count=count+1;assert(a==b,'Halloween Deep Inspector #'..count..': '..tostring(a)..' ~= '..tostring(b)..debug.traceback('',2))end
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
 or k=='AttributeChanged'or k=='DescendantAdded'or k=='DescendantRemoving'or k=='MouseEnter'or k=='MouseLeave'or k=='Played'or k=='FocusLost'then
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
function methods:IsA(c)
 if self.class==c then return true end
 if c=='BasePart'then return self.class=='Part'or self.class=='WedgePart'or self.class=='MeshPart'end
 if c=='GuiButton'then return self.class=='TextButton'or self.class=='ImageButton'end
 if c=='GuiObject'then return self.class=='TextLabel'or self.class=='TextBox'or self.class=='TextButton'or self.class=='ImageLabel'or self.class=='ImageButton'or self.class=='Frame'or self.class=='CanvasGroup'or self.class=='ScrollingFrame'end
 if c=='ValueBase'then return self.class=='IntValue'or self.class=='NumberValue'or self.class=='BoolValue'or self.class=='StringValue'or self.class=='ObjectValue'end
 return false
end
function methods:GetAttributes()return self.p.Attributes or {}end
function methods:GetAttribute(k)return(self.p.Attributes or {})[k]end
function methods:SetAttribute(k,v)self.p.Attributes=self.p.Attributes or {};self.p.Attributes[k]=v;self.AttributeChanged:Fire(k)end
function methods:GetTags()return self.p.Tags or {}end
function cm.__index:GetComponents()return self.Position.X,self.Position.Y,self.Position.Z,1,0,0,0,1,0,0,0,1 end

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

function typeof(v)
 if type(v)=='table'and rawget(v,'class')then return'Instance'end
 if getmetatable(v)==vm then return'Vector3'end
 if getmetatable(v)==cm then return'CFrame'end
 return type(v)
end
local f=assert(io.open('Halloween-Deep-Inspector.lua','rb'));local source=f:read('*a');f:close()
local prefix=assert(source:match('^(.-)%-%- BEGIN ROBLOX CLIENT'))
local Diagnostic,Monitor,Deep=assert(load(prefix..'\nreturn Diagnostic,Monitor,Deep','@HalloweenFarm/Core'))()
-- Parse explicit source text without interpreting a round goal or ratio as bag capacity.
eq(Monitor.parse('Round 2').Round,2)
eq(Monitor.parse('<b>Collect 3,000 Candy Corns</b>').CollectionGoal,3000)
eq(Monitor.parse('0 / 3000').Ratio.Goal,3000)
eq(Monitor.parse('2000').NumericLabel,2000)
eq(Monitor.parse('* accept candy *').AcceptCandy,true)
eq(Monitor.parse('IV').Round,nil)
eq(Monitor.parse('Round 2').Capacity,nil)
eq(Monitor.parse('0/3000').Capacity,nil)
-- Pure monitor: incremental scans, semantic changes, snapshots, history and explicit caps.
local mclock=0;local changes=0
local mroot={Children={}}
for i=1,3000 do mroot.Children[i]={Name='Node'..i,Children={},Value=i,Alive=true}end
local function config(root)
 return {Clock=function()return mclock end,Started=0,Roots=function()return{root}end,Children=function(o)return o.Children end,
  Skip=function(o)return o.Skip==true end,Alive=function(o)return o.Alive~=false end,
  Classify=function(o)return{'State'}end,
  Read=function(o)return{FullPath=o.Name,Properties={Value=o.Value}}end,
  ChangeKey=function(_,d)return d.Properties end,Context=function()return{Capacity='Unconfirmed'}end}
end
local mon=Monitor.new(config(mroot));mon:step();eq(mon.Ready,false);eq(mon.Scanned<=384,true)
for i=1,100 do mclock=mclock+.01;mon:step()end
eq(mon.Ready,true);eq(#mon.Buckets.State.Order,350);eq(mon.Buckets.State.Overflow>0,true)
eq(#mon.Snapshots,1);eq(mon.Snapshots[1].State,'Complete')
local selected=mroot.Children[1];selected.Value=999;mon:dirty(selected);mon:step()
local found=false
for _,event in ipairs(mon.Events)do if event.Kind=='Changed State'and event.Data.After.Properties.Value==999 then found=true end end
eq(found,true)
mon:request('Before');mon:request('After');eq(mon.PendingSnapshot,'After')
for i=1,100 do mclock=mclock+.01;mon:step()end
eq(#mon.Snapshots,3);eq(mon.Snapshots[3].Reason,'After')
for i=1,7 do mon:request('marker '..i);for j=1,20 do mclock=mclock+.01;mon:step()end end
eq(#mon.Snapshots,6);eq(mon.Snapshots[1].Reason,'Initial indexed state')
for i=1,220 do mon:event('marker',{N=i})end
eq(#mon.Events,180);eq(mon.EventDropped>0,true)
selected.Alive=false;mon:remove(selected);eq(mon.Buckets.State.Index[selected],nil)
eq(mon:export().Interpretation:find('capacity',1,true)~=nil,true)
mon:Destroy();eq(mon.Destroyed,true);eq(mon.SnapshotTask,nil)
-- Evidence engine: capacity keys, round maps, constants and inaccessible code are distinct.
local root={Children={},Alive=true}
local sourceObject={Name='Rules',Alive=true,Children={}}
root.Children[1]=sourceObject
local dc={Roots={root},Children=function(o)return o.Children end,Alive=function(o)return o.Alive end,Skip=function()return false end,
 Meta=function(o)return{FullPath='ReplicatedStorage.'..o.Name,ClassName='ModuleScript',IsScript=true}end,
 Attributes=function()return{}end,Value=function(o)return o.Value end,Plain=function(v)return v end,Clock=function()return 0 end}
local d=Deep.new(dc);d:step();eq(d.Ready,true);eq(#d.Scripts,1)
local item=d:nextScript();eq(item.Status,'Reading')
d:source(item,'local CandyRoundGoals = {2000,3000}\nlocal BagCapacity = { [1]=2000, [2]=3000 }\nnetwork:FireServer("Accept", choice)','Source property')
local nested={Limits={BagCapacity={[1]=2000,[2]=3000}}};nested.Cycle=nested
d:tableEvidence(nested,item.Path,'fixture live upvalues')
d:constants({'FireServer','Accept',3000},item.Path,'fixture constants')
for i=1,20 do d:step()end
eq(item.Status,'Searched');eq(item.Hits,3)
local bagKey=false;local rpcLine=false;local const=false
for _,row in ipairs(d.Findings)do
 if row.Kind=='Client runtime table'and row.Field:find('[BagCapacity][2]',1,true)and row.Value==3000 then bagKey=true end
 if row.Kind=='Client source'and row.Line==3 then rpcLine=true end
 if row.Kind=='Client function constants'then const=true end
end
eq(bagKey,true);eq(rpcLine,true);eq(const,true)
eq(Deep.topic('RoundGoal'),'Round/goal candidate');eq(Deep.topic('BagCapacity'),'Bag/carry limit candidate')
eq(d:export('').Capacity,nil);eq(#d:rank('bagcapacity')>0,true);eq(#d:rank('unmatchedfilter'),0)
local unreadable={Path='ReplicatedStorage.Closed',Status='Reading'};d:source(unreadable,nil,nil,'source permission denied')
eq(unreadable.Status,'Unavailable');eq(d.SourceErrors,1)
for i=1,400 do d:put({Kind='Fixture',Path='p'..i,Field='Capacity',Text='capacity '..i,Score=i})end
eq(#d.Findings,350);eq(d.FindingOverflow>0,true)
d:Destroy();eq(d.Destroyed,true);eq(#d.Tasks,0)

-- Real client adapter and GUI: no server requests, teleport or simulated input.
function services.Players:GetPlayers()return{player}end
function services.Players:GetPlayerFromCharacter(c)if c==player.Character then return player end end
game.children={};workspace.Parent=game;player.Parent=game
local storage=Instance.new('ReplicatedStorage');storage.Parent=game;services.ReplicatedStorage=storage
local promptService={PromptShown=signal(),PromptHidden=signal(),PromptTriggered=signal()};services.ProximityPromptService=promptService
local function object(class,name,parent)local o=Instance.new(class);o.Name=name;o.Parent=parent;return o end
local hud=object('ScreenGui','HalloweenHUD',pg)
local round=object('TextLabel','RoundLabel',hud);round.Text='Round 2'
local goal=object('TextLabel','CollectionTarget',hud);goal.Text='Collect 3000 Candy Corns'
local ratio=object('TextLabel','TeamCandy',hud);ratio.Text='0/3000'
local bag=object('TextLabel','Amount',object('Frame','BagDisplay',hud));bag.Text='0'
local icon=object('ImageLabel','BagIcon',bag.Parent);icon.Image='rbxassetid://bag-fixture'
local capacity=object('IntValue','Capacity',object('Folder','CandyInventory',player));capacity.Value=2000
local map=object('Folder','HalloweenMap',workspace)
local houses=object('Folder','Houses',map);local house=object('Model','HouseA',houses);local door=object('Model','Door',house)
local collision=object('Part','CollisionBox',door);collision.CFrame=CFrame.new(200,10,-500);collision.Size=Vector3.new(.78,9.1,6.63)
local prompt=object('ProximityPrompt','Interaction',door);prompt.ActionText='Trick or Treat!';prompt.ObjectText='Door';prompt.Enabled=true;prompt.MaxActivationDistance=12
local dialog=object('Frame','Dialogue',hud);dialog.Visible=false
local accept=object('TextButton','Choice1',dialog);accept.Text='* accept candy *'
local resident=object('TextLabel','ResidentText',dialog);resident.Text='Here kid, have some candy!'
local rig=object('Model','UnfixedNPCName',workspace);rig:SetAttribute('WindupEndsAt',42)
local enemyHuman=object('Humanoid','Humanoid',rig);enemyHuman.Health=100;enemyHuman.MaxHealth=100
local corn=object('Part','CandyCorn',rig);corn.CFrame=CFrame.new(5,4,6);corn.Size=Vector3.new(4.5,5.07,3);corn:SetAttribute('slappable',true)
local loose=object('Part','CandyCorn',map);loose.CFrame=CFrame.new(40,3,10);loose.Size=Vector3.new(1,1,1)
local animation=object('KeyframeSequence','AnimSaves',rig);object('Pose','CandyCorn',animation)
local wrapped;local forwarded=0
hookmetamethod=function(_,_,fn)wrapped=fn;return function()forwarded=forwarded+1;return'transmitted'end end
getnamecallmethod=function()return'FireServer'end
newcclosure=function(fn)return fn end
checkcaller=function()return false end
identifyexecutor=function()return'Fixture','1.0'end
local clipboard;local encodes={}
setclipboard=function(text)clipboard=text end
function services.HttpService:JSONEncode(data)encodes[#encodes+1]=data;return'json:'..#encodes end
local enabled=true
_G.ProbothotspotLanternAutoHit={JobId=game.JobId,Engine={Enabled=true,setEnabled=function(self,value)self.Enabled=value;enabled=value end}}
-- Fake introspection APIs return evidence without invoking the game's functions or require.
local configModule=object('ModuleScript','CandyRules',storage)
configModule.Source='local BagCapacity = { [1]=2000, [2]=3000 }\nlocal CandyRoundGoal = 3000\nnetwork:FireServer("Accept", part)'
local closedModule=object('ModuleScript','ClosedCandyRules',storage)
local detached=object('ModuleScript','DetachedCandyConfig',nil);detached.Source='return {MaxCandy=2000}'
local forbiddenExecutions=0
local gameFunction=function()forbiddenExecutions=forbiddenExecutions+1;error('game code must never execute')end
local foreignFunction=function()end
getloadedmodules=function()return{configModule,closedModule,detached}end
getscriptclosure=function()return gameFunction end
getconstants=function()return{'FireServer','Hit','CandyCorn',2000}end
getupvalues=function()return{{BagCapacity={[1]=2000,[2]=3000}}}end
decompile=function(script)if script==closedModule then error('fixture decompile unavailable')end;return nil end
getgc=function()return{gameFunction,foreignFunction,{Capacity=999999}}end
getfenv=function(fn)return fn==gameFunction and {script=configModule}or {}end

local app=dofile('Halloween-Deep-Inspector.lua')
local function find(name)return assert(app.Gui:FindFirstChild(name,true),name)end
local function tick(dt)time=time+(dt or .1);hb:Fire(dt or .1)end
for i=1,70 do tick()end
eq(app.Gui.Parent,pg);eq(find('Title').Text,'Halloween Deep Inspector 1.0.0');eq(enabled,false);eq(forwarded,0)
eq(app.Monitor.Ready,true);eq(#app.Monitor.Buckets.Door.Order,2) -- the earlier fixture DoorInnerTouch is also a physical door
local db=app.Monitor.Buckets.Door.Data[collision]
eq(db.FullPath,'Workspace.HalloweenMap.Houses.HouseA.Door.CollisionBox');eq(db.ThinAxis,'X')
eq(#app.Monitor.Buckets.NPC.Order,1);eq(#app.Monitor.Buckets.CandyHint.Order,1)
eq(app.Monitor.Buckets.UI.Data[round].Parsed.Round,2)
eq(app.Monitor.Buckets.UI.Data[goal].Parsed.CollectionGoal,3000)
eq(app.Monitor.Buckets.UI.Data[bag].Parsed.NumericLabel,0)
eq(app.Monitor.Buckets.State.Data[capacity].Properties.Value,2000)
local ownCount=0;for _,o in ipairs(app.Monitor.Buckets.UI.Order)do if o:IsDescendantOf(app.Gui)then ownCount=ownCount+1 end end
eq(ownCount,0)
promptService.PromptShown:Fire(prompt,'Touch');promptService.PromptTriggered:Fire(prompt,player)
dialog.Visible=true;dialog:GetPropertyChangedSignal('Visible'):Fire()
accept.Activated:Fire();bag.Text='20';bag:GetPropertyChangedSignal('Text'):Fire()
for i=1,70 do tick()end
eq(app.Monitor.Buckets.UI.Data[bag].Parsed.NumericLabel,20)
local activated=false;local changedBag=false
for _,event in ipairs(app.Monitor.Events)do
 if event.Kind=='Manual GUI activation'and event.Data.Properties.Text=='* accept candy *'then activated=true end
 if event.Kind=='Changed UI'and event.Data.After.FullPath==app.Monitor.Buckets.UI.Data[bag].FullPath and event.Data.After.Properties.Text=='20'then changedBag=true end
end
eq(activated,true);eq(changedBag,true)
local network=object('RemoteEvent','HalloweenNetwork',storage)
wrapped(network,'Accept',nil);eq(forwarded,1);eq(app.Engine.Reports[1].ArgumentCount,2)
eq(app.Engine.Reports[1].Arguments[2].Type,'nil');eq(app.Engine.Reports[1].Remote.FullPath,'ReplicatedStorage.HalloweenNetwork')
find('Snapshot').Activated:Fire();for i=1,70 do tick()end
find('Copy').Activated:Fire();eq(clipboard,app.CopyText)
local exported=encodes[#encodes]
eq(exported.StateMonitor.IndexReady,true);eq(exported.DeepInspector.Ready,true);eq(#exported.StateMonitor.Latest.Door.Items,2)
eq(exported.CurrentContext.BackpackCapacity:find('Unconfirmed',1,true)~=nil,true)
eq(#exported.StateMonitor.Snapshots>=2,true)
-- Source text and runtime maps are searchable; the compact export does not invent capacity.
for i=1,100 do tick()end
eq(app.Deep.Ready,true);eq(app.Deep.SourceReads>=2,true);eq(app.Deep.ScriptMap[detached]~=nil,true)
eq(app.Deep.ScriptMap[closedModule].Status,'Unavailable');eq(forbiddenExecutions,0)
local matched=app.Deep:rank('BagCapacity');eq(#matched>0,true)
find('Memory').Activated:Fire();for i=1,100 do tick()end
find('CompactCopy').Activated:Fire();local concise=encodes[#encodes]
eq(concise.MemoryFunctions,1);eq(#concise.Findings>0,true);eq(concise.Capacity,nil);eq(forbiddenExecutions,0)
find('Query').Text='nomatchesplease';find('Query').FocusLost:Fire()
eq(find('Report').Text:find('Совпадений',1,true)~=nil,true)
find('Query').Text='capacity';find('Query').FocusLost:Fire()
app.Explore(configModule);eq(find('TreeRow1').Visible,false)
eq(find('Report').Text:find('CandyRules',1,true)~=nil,true)
find('Up').Activated:Fire();eq(find('TreeRow1').Visible,true)
find('Tree').Activated:Fire();eq(find('TreeRow1').Visible,false)
find('MoreCode').Activated:Fire()

-- RPC window expires while UI/state monitoring keeps working; renewal restarts it.
local oldCount=#app.Engine.Reports;time=time+31;wrapped(network,'Later');eq(#app.Engine.Reports,oldCount)
find('Broad').Activated:Fire();wrapped(network,'Again');eq(#app.Engine.Reports,oldCount+1)
find('Record').Activated:Fire();wrapped(network,'Stopped');eq(#app.Engine.Reports,oldCount+1)
bag.Text='40';bag:GetPropertyChangedSignal('Text'):Fire();tick();eq(app.Monitor.Buckets.UI.Data[bag].Parsed.NumericLabel,40)
-- Fallback export, repeated run and missing hooks preserve a useful state-only diagnostic.
setclipboard=nil;find('Copy').Activated:Fire();eq(find('Report').Focused,true)
local pinned=find('Report').Text;tick(1);eq(find('Report').Text,pinned)
local prior=app;app=dofile('Halloween-Deep-Inspector.lua');eq(prior.Destroyed,true);eq(prior.Gui.Parent,nil)
find('Close').Activated:Fire();eq(app.Destroyed,true);eq(app.Monitor.Destroyed,true);eq(_G.ProbothotspotNPCHitHook.Listener,nil)
_G.ProbothotspotNPCHitHook=nil;hookmetamethod=nil;getnamecallmethod=nil;newcclosure=nil
app=dofile('Halloween-Deep-Inspector.lua');for i=1,50 do tick()end
eq(app.Engine.Sequence,0);eq(app.Monitor.Ready,true);eq(app.Engine.Sequence,0)
app:Destroy()
local active=0;for _,sig in ipairs(signals)do for _,conn in ipairs(sig.listeners)do if conn.Connected then active=active+1 end end end
eq(active,0);eq(_G.ProbothotspotHalloweenDeepInspector,nil)
os.clock=realClock
print('PASS: '..count..' deep source/table/constant evidence, no module execution, live-function attribution, ranked search, tree explorer, state/RPC export and cleanup assertions')
