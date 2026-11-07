-- Made by Bones hub Sol rng best script
local env=getgenv()
env.__BONES_BOSS_CANCELLED=false
local runtime=[========[if setthreadidentity then setthreadidentity(8) end
local env = getgenv()
env.__BONES_BOSS_CANCELLED=false
if env.__BONES_BOSS_PILOT then pcall(env.__BONES_BOSS_PILOT.Stop) end
local players, rs, run = game:GetService("Players"), game:GetService("ReplicatedStorage"), game:GetService("RunService")
while not players.LocalPlayer do task.wait() end
local player, core, http = players.LocalPlayer, game:GetService("CoreGui"), game:GetService("HttpService")
local old = core:FindFirstChild("BonesHubBossProbe") if old then old:Destroy() end
local bridge = Instance.new("Folder") bridge.Name = "BonesHubBossProbe" bridge.Parent = core
local live, cons, hazards, parts, history = true, {}, {}, {}, {}
local clock = os.clock
local nextDash, nextDecision, nextLog, nextWrite = 0, 0, 0, 0
local escapeStarted,escapeSent=nil,false
local lastHP, damage, commands, dashes = nil, 0, 0, 0
local desired = Vector3.zero
local escapeRoute,escapeIndex,routeBusy,routeRequest = {},1,false,0
local shelterPosition,shelterUntil,moonUntil=nil,0,0
local routeMode=""
local decisions,injuries={},{}
local lastDecision,castSeen={},0
local ledger=env.__BONES_BOSS_LEDGER
if not ledger or ledger.Job~=game.JobId then
 ledger={Job=game.JobId,Version="stability-v6",Started=workspace:GetServerTimeNow(),Deaths={0,0,0},Damage={0,0,0},Casts={},PhaseReached=0}
 env.__BONES_BOSS_LEDGER=ledger
end
local previousCharacter,deathMarked,castStart,previousUsing=nil,false,nil,false
local stuckSince,jumpAfter,blockedDirection,blockedUntil=nil,0,Vector3.zero,0
bridge:SetAttribute("Version",ledger.Version)
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function log(kind,data)
 history[#history+1]={Time=workspace:GetServerTimeNow(),Kind=kind,Data=data}
 if #history>400 then table.remove(history,1) end
 if kind=="Damage" or kind=="Dash" or kind=="Result" then
  if type(appendfile)=="function" then pcall(appendfile,"BonesHubBossRaid_Events.jsonl",http:JSONEncode({Time=workspace:GetServerTimeNow(),Kind=kind,Data=data}).."\n") end
 end
end
local function serial(v,depth)
 local t=typeof(v)
 if t=="Vector3" then return {X=v.X,Y=v.Y,Z=v.Z} end
 if t=="CFrame" then return {Position=serial(v.Position),Look=serial(v.LookVector)} end
 if t=="Instance" then return v:GetFullName() end
 if t=="table" then local o={} if (depth or 0)>1 then return "table" end for k,x in pairs(v) do o[tostring(k)]=serial(x,(depth or 0)+1) end return o end
 if t=="number" or t=="boolean" or t=="string" then return v end
 return tostring(v)
end
local function connect(signal,callback) local c=signal:Connect(callback) cons[#cons+1]=c return c end
local controls
local attackStop
local function stop()
 live=false
 for _,c in ipairs(cons) do c:Disconnect() end
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid") if h then h:Move(Vector3.zero,false) end
 if controls then pcall(function() controls:Enable() end) end
 run:UnbindFromRenderStep("BonesBossMovement")
 local runner=env.run_on_actor or run_on_actor
 if type(runner)=="function" then pcall(runner,game.ReplicatedFirst.ClientHandlers,[[if getgenv().__BONES_BOSS_ATTACK then getgenv().__BONES_BOSS_ATTACK.Stop() end]]) end
 bridge:SetAttribute("Active",false)
 bridge:SetAttribute("Status","Stopped")
end
env.__BONES_BOSS_PILOT={Stop=stop}
bridge:SetAttribute("Active",true)
run:BindToRenderStep("BonesBossMovement",Enum.RenderPriority.Last.Value,function()
 if not live then return end
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if h and h.Health>0 then h:Move(desired,false) end
end)
local events=rs:WaitForChild("Events",30)
if not events then bridge:SetAttribute("Error","Raid events unavailable") stop() return end
local function shape(kind,cf,a,b,delay,duration)
 if typeof(cf)~="CFrame" then return end
 hazards[#hazards+1]={Kind=kind,CF=cf,A=a,B=b,Start=clock()+math.max(0,delay or 0),End=clock()+math.max(0,delay or 0)+(duration or .7)}
end
local vfx=rs:FindFirstChild("VFX_Manager")
if vfx and vfx:FindFirstChild("VFX_Remote") then
 connect(vfx.VFX_Remote.OnClientEvent,function(group,name,...)
  local args={...}
  if name~="Shake_Camera" and name~="PlaySound" and name~="MagicWandVFX" then log("VFX",{Group=group,Name=name,Args=serial(args)}) end
  if group~="Cast_Effects" then return end
  if name=="StraightRangeVFX" then
   local warning=tonumber(args[4]) or 1
   shape("Box",args[1],tonumber(args[3]) or 10,tonumber(args[2]) or 30,warning,3.0)
   if typeof(args[1])=="CFrame" and math.abs((tonumber(args[3]) or 0)-27.648)<1 then
    local cf=args[1] local tip=cf.Position+cf.LookVector*(tonumber(args[2]) or 30)/2
    shape("Circle",CFrame.new(tip),58,0,warning+.7,3.0)
   end
  elseif (name=="WingScratch_dashVFX" or name=="WingScratch_slashVFX") and typeof(args[1])=="Instance" and args[1]:IsA("Model") and args[1].PrimaryPart then
   local part=args[1].PrimaryPart
   shape("Circle",part.CFrame,58,0,0,name=="WingScratch_dashVFX" and 3 or 1.8) hazards[#hazards].Follow=part
  elseif name=="CircularRangeVFX" then shape("Circle",args[1],(tonumber(args[2]) or 1)*.25,0,tonumber(args[3]) or 1,1.0)
  elseif name=="CircularRangeVFX(weld)" and typeof(args[1])=="Instance" and args[1]:IsA("BasePart") then
   shape("Circle",args[1].CFrame,(tonumber(args[2]) or 1)*.25,0,tonumber(args[3]) or 1,1.0) hazards[#hazards].Follow=args[1]
  elseif name=="SlashRangeVFX" then shape("Circle",args[1],(tonumber(args[2]) or 1)*18,0,tonumber(args[3]) or 1,.8)
  elseif name=="LaserVFX" and typeof(args[1])=="CFrame" and typeof(args[2])=="CFrame" then
   local p,q=args[1].Position,args[2].Position local center=(p+q)/2
   if flat(q-p).Magnitude>1 then shape("Box",CFrame.lookAt(center,center+flat(q-p)),10,(q-p).Magnitude,0,(tonumber(args[3]) or .2)+(tonumber(args[4]) or 1)) end
  elseif name=="Meteor" and typeof(args[1])=="Vector3" and typeof(args[2])=="Vector3" then
   shape("Projectile",CFrame.new(args[1]),16,0,tonumber(args[4]) or .75,(tonumber(args[5]) or 1)+.4)
   local h=hazards[#hazards] h.From=args[1]+Vector3.new(0,tonumber(args[3]) or 10,0) h.To=args[2] h.Travel=tonumber(args[5]) or 1
   shape("Circle",CFrame.new(args[2]),32,0,(tonumber(args[4]) or 1)+(tonumber(args[5]) or 3)-.2,1.0)
  elseif name=="SetMagicCircle" and typeof(args[1])=="CFrame" and (tonumber(args[2]) or 99)<=5 then
   shape("Circle",args[1],28,0,math.max(.1,(tonumber(args[2]) or 2)-.3),1.0)
  elseif name=="MoonDrop" and typeof(args[2])=="Vector3" then
   moonUntil=clock()+(tonumber(args[3]) or 0)+(tonumber(args[4]) or 0)+2
   -- Shelter position observed in this Easy arena; use the replicated shield as soon as it appears.
   shelterPosition=Vector3.new(-64,77.5,20) shelterUntil=moonUntil
   shape("Circle",CFrame.new(args[2]),112.5,0,(tonumber(args[3]) or 0)+(tonumber(args[4]) or 0),3)
  end
 end)
end
connect(workspace.DescendantAdded,function(p)
 if p.Name~="shield" and p.Name~="Stella" then return end
 task.defer(function()
  if not live or not p.Parent or not rs:FindFirstChild("PhaseValue") or rs.PhaseValue.Value<3 then return end
  local point
  if p:IsA("Model") then point=p:GetPivot().Position elseif p:IsA("BasePart") then point=p.Position end
  if point and point.Y<180 then
   shelterPosition=point shelterUntil=clock()+12
   bridge:SetAttribute("ShelterPosition",http:JSONEncode(serial(point)))
   log("Shelter",{Name=p:GetFullName(),Position=serial(point)})
  end
 end)
end)
for _,folderName in ipairs({"HitBox","BossHitBox"}) do
 local folder=workspace:FindFirstChild(folderName)
 if folder then
  local function add(p)
   if not p:IsA("BasePart") then return end
   log("Part",{Folder=folderName,Name=p.Name,Position=serial(p.Position),Size=serial(p.Size),Attributes=serial(p:GetAttributes()),Shape=p:IsA("Part") and p.Shape.Name})
   if folderName=="HitBox" then parts[p]={Born=clock(),Position=p.Position,Time=clock(),Velocity=Vector3.zero} end
  end
  for _,p in ipairs(folder:GetDescendants()) do add(p) end
  connect(folder.DescendantAdded,add)
 end
end
connect(events.Dash.OnClientEvent,function(cd) if type(cd)=="number" then nextDash=clock()+cd log("DashAck",cd) end end)
connect(events.RoundResult.OnClientEvent,function(result) ledger.Result=serial(result) log("Result",serial(result)) bridge:SetAttribute("Result",http:JSONEncode(serial(result))) end)
local runner=env.run_on_actor or run_on_actor
local actor=game:GetService("ReplicatedFirst"):WaitForChild("ClientHandlers",30)
if actor and type(runner)=="function" then
 runner(actor,[==[
  local core=game:GetService("CoreGui") local b=core:FindFirstChild("BonesHubBossProbe")
  local rs=game:GetService("ReplicatedStorage") local p=game.Players.LocalPlayer local ev=rs:WaitForChild("Events")
  local auraList=ev:WaitForChild("AuraList",30) local selectAura=ev:WaitForChild("SelectAura",30)
  if not auraList or not selectAura then return end
  local sent=false
  local c
  c=auraList.OnClientEvent:Connect(function(list)
   if sent then return end
   local names={} local found
   for _,v in pairs(list) do
    names[#names+1]=v.auraName
    if v.auraName=="Archangel" and (not found or found.isRentalAura) then found=v end
   end
   local identity=getthreadidentity and getthreadidentity()
   if setthreadidentity then setthreadidentity(8) end
   if b and b.Parent then b:SetAttribute("Auras",game:GetService("HttpService"):JSONEncode(names)) end
   if found then
    sent=true
    selectAura:FireServer({auraName=found.auraName,isRental=found.isRentalAura==true})
    if setthreadidentity then setthreadidentity(8) end
    if b and b.Parent then b:SetAttribute("SelectedSent",found.auraName) end
   end
   if identity and setthreadidentity then setthreadidentity(identity) end
  end)
  task.spawn(function()
   local deadline=os.clock()+35
   task.spawn(function()
    local ui=require(game.ReplicatedFirst.ClientHandlers.BossRaidClient.AuraSelectUI)
    repeat
     if sent then return end
     for _,row in ipairs(ui.itemList:GetChildren()) do
      for _,v in ipairs(row:GetDescendants()) do
       if v:IsA("TextLabel") and v.Name=="Archangel" then
        sent=true
        ui.selectedAura="Archangel" ui.isRentalAura=row:HasTag("RentalAura")
        selectAura:FireServer({auraName="Archangel",isRental=ui.isRentalAura})
        local id=getthreadidentity and getthreadidentity()
        if setthreadidentity then setthreadidentity(8) end
        if b and b.Parent then b:SetAttribute("SelectedSent","Archangel") end
        if id and setthreadidentity then setthreadidentity(id) end
        return
       end
      end
     end
     task.wait(.1)
    until os.clock()>deadline
   end)
   repeat
    if p:GetAttribute("AuraName")=="Archangel" then break end
    if rs:FindFirstChild("PhaseValue") and rs.PhaseValue.Value>0 then break end
    auraList:FireServer() task.wait(1)
   until sent or os.clock()>deadline
   task.wait(2)
   c:Disconnect()
  end)
 ]==])
end
local mapParams=RaycastParams.new() mapParams.FilterType=Enum.RaycastFilterType.Include
mapParams.FilterDescendantsInstances={workspace:WaitForChild("Map"),workspace:FindFirstChild("FolderForPhase3WallToExcludeFromRaycast")}
mapParams.RespectCanCollide=true
local function planEscape(root,hazard)
 if routeBusy or clock()<routeRequest then return end
 routeBusy=true routeRequest=clock()+2
 local origin=root.Position
 task.spawn(function()
  local points={}
  local radial=flat(origin-hazard.CF.Position)
  local start=math.atan2(radial.Z,radial.X)
  for _,offset in ipairs({0,.4,-.4,.8,-.8,1.2,-1.2,math.pi}) do
   local angle=start+offset
   local point=hazard.CF.Position+Vector3.new(math.cos(angle),0,math.sin(angle))*(hazard.A+14)
   local floor=workspace:Raycast(Vector3.new(point.X,origin.Y+6,point.Z),Vector3.new(0,-22,0),mapParams)
   if floor and point.X>=-120 and point.X<=80 and point.Z>=-85 and point.Z<=105 then points[#points+1]=floor.Position+Vector3.new(0,3,0) end
  end
  table.sort(points,function(a,b) return (a-origin).Magnitude<(b-origin).Magnitude end)
  for _,target in ipairs(points) do
   local path=game:GetService("PathfindingService"):CreatePath({AgentRadius=3,AgentHeight=5,AgentCanJump=true,WaypointSpacing=5})
   local ok=pcall(function() path:ComputeAsync(origin,target) end)
   if ok and path.Status==Enum.PathStatus.Success then
    if live then escapeRoute=path:GetWaypoints() escapeIndex=2 bridge:SetAttribute("Route","Moon escape: "..#escapeRoute) end
    break
   end
  end
  routeBusy=false
 end)
end
local function planTravel(root,target)
 if routeBusy or clock()<routeRequest then return end
 routeBusy=true routeRequest=clock()+2
 local origin=root.Position
 task.spawn(function()
  local floor=workspace:Raycast(target+Vector3.new(0,6,0),Vector3.new(0,-22,0),mapParams)
  if floor then
   local path=game:GetService("PathfindingService"):CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,WaypointSpacing=4})
   local ok=pcall(function() path:ComputeAsync(origin,floor.Position+Vector3.new(0,3,0)) end)
   if ok and path.Status==Enum.PathStatus.Success and live then
    escapeRoute=path:GetWaypoints() escapeIndex=2 bridge:SetAttribute("Route","Ground route: "..#escapeRoute)
   end
  end
  routeBusy=false
 end)
end
local function danger(position,when)
 local value=0
 for _,h in ipairs(hazards) do
  if when<=h.End then
   local cf=h.Follow and h.Follow.Parent and h.Follow.CFrame or h.CF
   if h.Kind=="Projectile" then cf=CFrame.new(h.From:Lerp(h.To,1-math.cos(math.clamp((when-h.Start)/math.max(.01,h.Travel),0,1)*math.pi/2))) end
   local p=cf:PointToObjectSpace(position)
   local margin
   if h.Kind=="Box" then margin=math.max(math.abs(p.X)-h.A/2,math.abs(p.Z)-h.B/2)
   else margin=flat(position-cf.Position).Magnitude-h.A end
   if h.Kind~="Projectile" or math.abs(position.Y-cf.Position.Y)<22 then
    value+=math.max(0,6-margin)*((when>=h.Start-.15) and 20 or (8/math.max(1,h.Start-when)))
   end
  end
 end
 for part,record in pairs(parts) do
  if not part.Parent then parts[part]=nil
  else
   local projected=part.Position+(record.Velocity or Vector3.zero)*math.clamp(when-clock(),0,1.2)
   if math.abs(projected.Y-position.Y)<part.Size.Y/2+6 then
   local p=(part.CFrame+(projected-part.Position)):PointToObjectSpace(position)
   local margin=math.max(math.abs(p.X)-part.Size.X/2,math.abs(p.Z)-part.Size.Z/2)
   value+=math.max(0,6-margin)*25
   end
  end
 end
 return value
end
connect(run.Heartbeat,function()
 if not live then return end
 if setthreadidentity then setthreadidentity(8) end
 local now=clock()
 if env.__BONES_BOSS_CANCELLED then stop() return end
 local char=player.Character local hum=char and char:FindFirstChildOfClass("Humanoid") local root=char and char:FindFirstChild("HumanoidRootPart")
 if now>=nextLog then
  nextLog=now+1
  local phase=rs:FindFirstChild("PhaseValue") and rs.PhaseValue.Value or 0
  ledger.PhaseReached=math.max(ledger.PhaseReached,phase)
  bridge:SetAttribute("Ledger",http:JSONEncode(ledger))
  local state={Time=workspace:GetServerTimeNow(),Aura=player:GetAttribute("AuraName"),Phase=rs:FindFirstChild("PhaseValue") and rs.PhaseValue.Value,HP=hum and hum.Health,BossHP=rs:FindFirstChild("BossHealthValue") and rs.BossHealthValue.Value,DamageTaken=damage,Commands=commands,Dashes=dashes,Stunned=hum and hum:GetAttribute("Stunned"),Ended=rs:GetAttribute("gameEnded"),Position=root and serial(root.Position),Hazards=#hazards,Direction=serial(desired),Revives=player:GetAttribute("reviveCount")}
  bridge:SetAttribute("State",http:JSONEncode(state))
  bridge:SetAttribute("History",http:JSONEncode(history))
  if now>=nextWrite and type(writefile)=="function" then nextWrite=now+5 pcall(writefile,"BonesHubBossRaid_Pilot.json",http:JSONEncode({State=state,History=history})) end
 end
 if char~=previousCharacter then previousCharacter=char deathMarked=false lastHP=nil end
 if hum then
  local ph=math.clamp(rs.PhaseValue.Value,1,3)
  if hum.Health<=0 and not deathMarked then deathMarked=true ledger.Deaths[ph]+=1 end
  local using=player:GetAttribute("UsingSkill")==true
  if using and not previousUsing and root then castStart={Time=workspace:GetServerTimeNow(),Position=serial(root.Position),HP=hum.Health,Phase=ph,Kind=bridge:GetAttribute("AttackState")} end
  if not using and previousUsing and castStart and root then
   castStart.End=workspace:GetServerTimeNow() castStart.EndPosition=serial(root.Position) castStart.EndHP=hum.Health
   ledger.Casts[#ledger.Casts+1]=castStart if #ledger.Casts>12 then table.remove(ledger.Casts,1) end castStart=nil
  end
  previousUsing=using
  if lastHP and hum.Health<lastHP then
   damage+=lastHP-hum.Health
   ledger.Damage[ph]+=lastHP-hum.Health
   local injury={Time=workspace:GetServerTimeNow(),Phase=rs.PhaseValue.Value,Amount=lastHP-hum.Health,Position=root and serial(root.Position),Speed=hum.WalkSpeed,UsingSkill=player:GetAttribute("UsingSkill"),Anchored=root and root.Anchored,Decision=lastDecision,Recent={}}
   for i=math.max(1,#history-200),#history do if type(history[i].Data)=="table" and history[i].Kind=="VFX" and workspace:GetServerTimeNow()-history[i].Time<7 and history[i].Data.Name~="ThornVFX" then injury.Recent[#injury.Recent+1]=history[i] end end
   injuries[#injuries+1]=injury if #injuries>12 then table.remove(injuries,1) end
   bridge:SetAttribute("Injuries",http:JSONEncode(injuries))
   log("Damage",{Amount=lastHP-hum.Health,Position=root and serial(root.Position)})
  end
  lastHP=hum.Health
 end
 if not hum or not root or hum.Health<=0 or rs:GetAttribute("gameEnded") or (rs:FindFirstChild("PlayingCutscene") and rs.PlayingCutscene.Value) then
  desired=Vector3.zero
  bridge:SetAttribute("Status",rs:GetAttribute("gameEnded") and "Raid ended" or ((not hum or hum.Health<=0) and "Respawning" or "Cutscene"))
  return
 end
 if player:GetAttribute("AuraName")~="Archangel" then desired=Vector3.zero bridge:SetAttribute("Status","Waiting for Archangel") return end
 bridge:SetAttribute("Status","Ground combat")
 local stunUI=player.PlayerGui:FindFirstChild("StunEscape")
 if stunUI and stunUI.Enabled and hum:GetAttribute("Stunned") then
  escapeStarted=escapeStarted or now
  if not escapeSent and now-escapeStarted>=1.3 then
   escapeSent=true events.RequestStunEscape:FireServer() log("StunEscape",{})
  end
 else escapeStarted=nil escapeSent=false end
 if hum:GetAttribute("Stunned") then desired=Vector3.zero return end
 if (desired.Magnitude>.5 or (lastDecision.Risk or 0)>30) and hum.WalkSpeed>=20 and not root.Anchored and flat(root.AssemblyLinearVelocity).Magnitude<3 then
  stuckSince=stuckSince or now
  if now-stuckSince>.4 and now>jumpAfter and hum.FloorMaterial~=Enum.Material.Air then
   hum.Jump=true jumpAfter=now+1.0 blockedDirection=desired blockedUntil=now+1.2
   log("StallRecovery",{Position=serial(root.Position),Direction=serial(desired)})
  end
 else stuckSince=nil end
 if now<nextDecision then return end nextDecision=now+.08
 for part,record in pairs(parts) do
  if part.Parent then
   local elapsed=now-record.Time
   if elapsed>.015 then
    local velocity=(part.Position-record.Position)/elapsed
    record.Velocity=velocity.Magnitude<600 and velocity or Vector3.zero
    record.Position=part.Position record.Time=now
   end
  end
 end
 for i=#hazards,1,-1 do if hazards[i].End<now then table.remove(hazards,i) end end
 local target=rs:FindFirstChild("CurrentBossModelValue") local boss=target and target.Value
 if not boss or not boss.PrimaryPart then return end
 local bp=boss.PrimaryPart.Position local radial=flat(root.Position-bp) local dist=radial.Magnitude
 if dist<.1 then radial=Vector3.xAxis dist=1 end
 local tangent=Vector3.new(-radial.Z,0,radial.X).Unit
 local center=Vector3.new(-10,root.Position.Y,15)
 local arenaRadial=flat(root.Position-center)
 if arenaRadial.Magnitude<1 then arenaRadial=Vector3.xAxis end
 local orbit=Vector3.new(-arenaRadial.Z,0,arenaRadial.X).Unit
 local prefer=(orbit+arenaRadial.Unit*math.clamp((78-arenaRadial.Magnitude)/20,-2,2)).Unit
 local shelter=shelterPosition and now<shelterUntil and now<moonUntil
 local phase3=rs.PhaseValue.Value>=3
 local kiteGoal
 if phase3 and not shelter then
  local center=Vector3.new(-75,root.Position.Y,20)
  local away=flat(root.Position-center) if away.Magnitude<1 then away=Vector3.xAxis end
  local around=Vector3.new(-away.Z,0,away.X).Unit
  local delta=around+away.Unit*math.clamp((42-away.Magnitude)/15,-1.5,1.5)
  if delta.Magnitude>.1 then prefer=delta.Unit end
  kiteGoal=center+(away.Unit+around*.6).Unit*42
 end
 local escape
 for _,h in ipairs(hazards) do
  if h.Kind=="Circle" and h.A>=45 and h.End>now and flat(root.Position-h.CF.Position).Magnitude<h.A+18 then escape=h break end
 end
 local nextMode=shelter and "shelter" or (escape and "escape" or (phase3 and "phase3" or "orbit"))
 if nextMode~=routeMode then routeMode=nextMode escapeRoute={} escapeIndex=1 routeRequest=0 end
 if shelter then
  planTravel(root,shelterPosition)
  while escapeRoute[escapeIndex] and flat(escapeRoute[escapeIndex].Position-root.Position).Magnitude<3 do escapeIndex+=1 end
  local waypoint=escapeRoute[escapeIndex]
  local delta=flat((waypoint and waypoint.Position or shelterPosition)-root.Position)
  if delta.Magnitude>2 then prefer=delta.Unit else desired=Vector3.zero hum:Move(desired,false) return end
  if waypoint and waypoint.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
 elseif escape then
  planEscape(root,escape)
  while escapeRoute[escapeIndex] and flat(escapeRoute[escapeIndex].Position-root.Position).Magnitude<5 do escapeIndex+=1 end
  local waypoint=escapeRoute[escapeIndex]
  local delta=waypoint and flat(waypoint.Position-root.Position) or flat(root.Position-escape.CF.Position)
  if delta.Magnitude>.1 then prefer=delta.Unit end
  if waypoint and waypoint.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
 elseif phase3 then
  planTravel(root,kiteGoal)
  while escapeRoute[escapeIndex] and flat(escapeRoute[escapeIndex].Position-root.Position).Magnitude<4 do escapeIndex+=1 end
  local waypoint=escapeRoute[escapeIndex]
  if waypoint then
   local delta=flat(waypoint.Position-root.Position)
   if delta.Magnitude>.1 then prefer=delta.Unit end
   if waypoint.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
  end
 else
  local orbitGoal=center+(arenaRadial.Unit+orbit*.7).Unit*78
  planTravel(root,orbitGoal)
  while escapeRoute[escapeIndex] and flat(escapeRoute[escapeIndex].Position-root.Position).Magnitude<4 do escapeIndex+=1 end
  local waypoint=escapeRoute[escapeIndex]
  if waypoint then
   local delta=flat(waypoint.Position-root.Position)
   if delta.Magnitude>.1 then prefer=delta.Unit end
   if waypoint.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
  end
 end
 local best,bestScore,bestRisk=Vector3.zero,math.huge,math.huge
 local rejected={Floor=0,Wall=0,Height=0,Boundary=0,Valid=0}
 local function outside(p) return math.max(0,-125-p.X,p.X-85,-90-p.Z,p.Z-110) end
 local speed=math.max(1,hum.WalkSpeed)
 local underfoot=workspace:Raycast(root.Position,Vector3.new(0,-22,0),mapParams)
 local feetY=underfoot and underfoot.Position.Y or (root.Position.Y-3)
 for i=0,16 do
  local dir=i==16 and Vector3.zero or Vector3.new(math.cos(i*math.pi/8),0,math.sin(i*math.pi/8))
  local step=rs.PhaseValue.Value>=3 and .16 or .4
  local endPos=root.Position+dir*speed*step
  local floor=workspace:Raycast(endPos+Vector3.new(0,5,0),Vector3.new(0,-45,0),mapParams)
  local wall=workspace:Raycast(root.Position,dir*(speed*step+1.5),mapParams)
  if not phase3 and outside(endPos)>math.max(0,outside(root.Position)-.1) then rejected.Boundary+=1 elseif not floor then rejected.Floor+=1 elseif (floor.Position.Y-feetY>5 or floor.Position.Y-feetY < -20) then rejected.Height+=1 elseif wall and wall.Normal.Y<=.65 then rejected.Wall+=1 else
   rejected.Valid+=1
   local risk=0
   for j=1,7 do local t=j*.16 risk+=danger(root.Position+dir*speed*t,now+t) end
   local front=flat(endPos-bp)
   local facing=flat(boss.PrimaryPart.CFrame.LookVector)
   local frontCost=front.Magnitude>1 and front.Magnitude<85 and facing.Magnitude>.1 and math.max(0,front.Unit:Dot(facing.Unit)) * 6 or 0
   local stallPenalty=now<blockedUntil and math.max(0,dir:Dot(blockedDirection)) * 80 or 0
   local separation=not phase3 and math.max(0,75-flat(root.Position+dir*speed*.8-bp).Magnitude)*4 or 0
   local idlePenalty=i==16 and 25 or 0
   local score=idlePenalty+stallPenalty+separation+(shelter and risk*.05 or risk)+(1-dir:Dot(prefer))*(shelter and 80 or (escape and 35 or (phase3 and 12 or 12)))+(1-dir:Dot(desired))*1+frontCost
   if score<bestScore then best,bestScore,bestRisk=dir,score,risk end
  end
 end
 desired=best hum:Move(best,false) commands+=1
 local currentRisk=danger(root.Position,now+.3)
 bridge:SetAttribute("Danger",currentRisk)
 lastDecision={Direction=serial(best),Risk=currentRisk,PathRisk=bestRisk,Score=bestScore,Rejected=rejected,Speed=hum.WalkSpeed,ActualSpeed=flat(root.AssemblyLinearVelocity).Magnitude,UsingSkill=player:GetAttribute("UsingSkill"),Anchored=root.Anchored,Stunned=hum:GetAttribute("Stunned"),FloorMaterial=hum.FloorMaterial.Name,FeetY=feetY,Hazards=#hazards,Distance=dist}
 bridge:SetAttribute("Decision",http:JSONEncode(lastDecision))
 local castRisk=0
 for j=0,12 do castRisk+=danger(root.Position,now+j*.1) end
 bridge:SetAttribute("AttackSafe",castRisk<1 and bestRisk<1 and hum.WalkSpeed>=20 and not shelter)
 bridge:SetAttribute("CastRisk",castRisk)
 local dashClear=phase3 or outside(root.Position+best*25)==0
 if best.Magnitude>.5 then
  for j=1,5 do
   local p=root.Position+best*(j*5)
   local f=workspace:Raycast(p+Vector3.new(0,5,0),Vector3.new(0,-45,0),mapParams)
   if not f or math.abs(f.Position.Y-feetY)>5 then dashClear=false break end
  end
  if workspace:Raycast(root.Position,best*27,mapParams) then dashClear=false end
 end
 if currentRisk>30 and bestRisk<currentRisk*5 and dashClear and now>=nextDash and best.Magnitude>.5 and not player:GetAttribute("UsingSkill") then
  nextDash=now+2 dashes+=1 events.Dash:FireServer() log("Dash",{Risk=currentRisk,Direction=serial(best),Position=serial(root.Position)})
  local origin=root.Position
  task.delay(.35,function() if live and root.Parent then log("DashTravel",{Distance=(root.Position-origin).Magnitude,Position=serial(root.Position)}) end end)
 end
end)

run_on_actor(game.ReplicatedFirst.ClientHandlers,[======[local env=getgenv()
if env.__BONES_BOSS_ATTACK then env.__BONES_BOSS_ATTACK.Stop() end
local rs=game:GetService("ReplicatedStorage")
local player=game.Players.LocalPlayer
local aura=require(rs.Packets.Aura)
local live,cons,nextTry,cooldown,shots=true,{},0,0,0
local function report(name,value)
 local id=getthreadidentity and getthreadidentity()
 if setthreadidentity then setthreadidentity(8) end
 local b=game:GetService("CoreGui"):FindFirstChild("BonesHubBossProbe")
 if b then b:SetAttribute(name,value) end
 if id and setthreadidentity then setthreadidentity(id) end
end
local remove
local function stop() live=false for _,c in ipairs(cons) do c:Disconnect() end if type(remove)=="function" then pcall(remove) end end
env.__BONES_BOSS_ATTACK={Stop=stop}
-- Native packet listeners return an unsubscribe function on this ByteNet build.
remove=aura.SetSkill.listen(function(data)
 if live and data.AuraName=="Archangel" and data.SkillName=="Holy Slash" then
  cooldown=tonumber(data.End) or 0
  report("SkillCooldown",cooldown)
 end
end)
cons[#cons+1]=game:GetService("RunService").Heartbeat:Connect(function()
 if not live then return end
 local now=workspace:GetServerTimeNow()
 if now<nextTry or now<cooldown then return end
 if player:GetAttribute("AuraName")~="Archangel" or player:GetAttribute("UsingSkill") then return end
 if rs:GetAttribute("gameEnded") or rs.PlayingCutscene.Value or rs.PhaseValue.Value<1 then return end
 if rs.BossCounterGimmic.Value then report("AttackState","Counter: hold fire") return end
 local c=player.Character local h=c and c:FindFirstChildOfClass("Humanoid") local root=c and c:FindFirstChild("HumanoidRootPart")
 local boss=rs.CurrentBossModelValue.Value local target=boss and boss.PrimaryPart
 if not h or h.Health<=0 or h:GetAttribute("Stunned") or not root or not target then return end
 local id=getthreadidentity and getthreadidentity()
 if setthreadidentity then setthreadidentity(8) end
 local bridge=game.CoreGui:FindFirstChild("BonesHubBossProbe")
 local safe=bridge and bridge:GetAttribute("AttackSafe")==true
 if id and setthreadidentity then setthreadidentity(id) end
 if not safe then report("AttackState","Dodge: hold fire") return end
 local delta=target.Position-root.Position
 if delta.Magnitude<1 then return end
 nextTry=now+1.0
 aura.UseSkill.send({SkillName="Holy Slash",LookVector=delta.Unit,MouseHit=CFrame.new(target.Position)})
 shots+=1 report("Shots",shots) report("AttackState","Holy Slash")
end)
print("BOSS_ARCHANGEL_ATTACK_READY")
]======])
local core=game:GetService("CoreGui")
local old=core:FindFirstChild("BonesHubBossRaid") if old then old:Destroy() end
local gui=Instance.new("ScreenGui") gui.Name="BonesHubBossRaid" gui.ResetOnSpawn=false gui.Parent=core
local frame=Instance.new("Frame") frame.Size=UDim2.fromOffset(285,112) frame.Position=UDim2.fromOffset(14,175) frame.BackgroundColor3=Color3.fromRGB(20,23,29) frame.BorderSizePixel=0 frame.Parent=gui
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,7) corner.Parent=frame
local label=Instance.new("TextLabel") label.BackgroundTransparency=1 label.Position=UDim2.fromOffset(12,8) label.Size=UDim2.new(1,-24,1,-39) label.Font=Enum.Font.Code label.TextSize=14 label.TextColor3=Color3.fromRGB(226,232,241) label.TextXAlignment=Enum.TextXAlignment.Left label.TextYAlignment=Enum.TextYAlignment.Top label.TextWrapped=true label.Parent=frame
local button=Instance.new("TextButton") button.Size=UDim2.fromOffset(74,24) button.Position=UDim2.new(1,-84,1,-29) button.Text="Stop" button.Font=Enum.Font.Code button.TextSize=14 button.TextColor3=Color3.new(1,1,1) button.BackgroundColor3=Color3.fromRGB(145,49,55) button.BorderSizePixel=0 button.Parent=frame
button.Activated:Connect(function()
 local e=getgenv() e.__BONES_BOSS_CANCELLED=true
 if e.__BONES_BOSS_PILOT then e.__BONES_BOSS_PILOT.Stop() end
 button.Text="Stopped"
end)
task.spawn(function()
 local http=game:GetService("HttpService")
 while gui.Parent do
  if setthreadidentity then setthreadidentity(8) end
  local b=core:FindFirstChild("BonesHubBossProbe")
  local ok,state=pcall(function() return http:JSONDecode(b and b:GetAttribute("State") or "{}") end)
  if ok then
   local status=b and b:GetAttribute("Active") and "Running" or "Stopped"
   label.Text=string.format("Bones Hub | Blood Moon Easy\n%s | %s | Phase %s\nHP %s | Boss %s | Revives %s\n%s",status,state.Aura or "Selecting Archangel",tostring(state.Phase or "-"),tostring(state.HP or "-"),tostring(state.BossHP or "-"),tostring(state.Revives or 0),tostring(b and (b:GetAttribute("Status") or b:GetAttribute("AttackState")) or "Waiting for raid"))
  end
  task.wait(.3)
 end
end)
]========]
local function start()
 local ok,err=xpcall(function() assert(loadstring(runtime))() end,debug.traceback)
 if not ok then warn("Bones Hub raid: "..tostring(err)) end
end
local queue=env.queue_on_teleport or queue_on_teleport or (syn and syn.queue_on_teleport)
local queued="repeat task.wait(.1) until game:IsLoaded() and game:GetService('Players').LocalPlayer\n".."local ok,err=xpcall(function() loadstring("..string.format("%q",runtime)..")() end,debug.traceback) if not ok then warn(err) end"
local function arm()
 assert(type(queue)=="function","Teleport queue unavailable: execute this script inside the raid")
 queue(queued)
end
local rs=game:GetService("ReplicatedStorage")
if game.PlaceId==15532962292 then
 arm()
 local raid=rs:WaitForChild("Remote",20):WaitForChild("BossRaid",20):WaitForChild("RemoteEvent",20)
 raid:FireServer("playSolo","The Amalgamation","Easy")
elseif rs:FindFirstChild("DifficultyMode") and rs:FindFirstChild("PhaseValue") then
 assert(rs.DifficultyMode.Value=="Easy","This script requires Easy difficulty")
 if rs:GetAttribute("gameEnded") then
  arm() rs.Events.RestartPacket.Restart:FireServer()
 else
  start()
 end
else
 error("Open Sol's RNG main world or The Amalgamation Easy raid")
end
