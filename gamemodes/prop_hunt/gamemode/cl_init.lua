-- Include these
include("sh_init.lua")
include("sh_showwindowtaunt.lua")
include("cl_menu.lua")

-- Convars are bad at networking sometimes
CL_CAMERA_COLLISIONS = false

-- Glimpse of thirdperson (Timed)
CL_THIRDPERSON_TIMED = 0

-- Add some network stuff here (dirty code sry)
function PH_CameraCollisions(len)
	CL_CAMERA_COLLISIONS = net.ReadBool()
end
net.Receive("PH_CameraCollisions", PH_CameraCollisions)

function PH_CustomTauntEnabled(len)
	CUSTOM_TAUNT_ENABLED = net.ReadBool()
end
net.Receive("PH_CustomTauntEnabled", PH_CustomTauntEnabled)

function PH_CustomTauntDelay(len)
	CUSTOM_TAUNT_DELAY = net.ReadInt(8)
end
net.Receive("PH_CustomTauntDelay", PH_CustomTauntDelay)

-- Decides where  the player view should be (forces third person for props)
function GM:CalcView(pl, origin, angles, fov)
	local view = {} 
	
	if blind then
		view.origin = Vector(20000, 0, 0)
		view.angles = Angle(0, 0, 0)
		view.fov = fov
		
		return view
	end
	
 	view.origin = origin 
 	view.angles	= angles 
 	view.fov = fov 
 	
 	-- Give the active weapon a go at changing the viewmodel position 
	if pl:Team() == TEAM_PROPS && pl:Alive() then
		if CL_CAMERA_COLLISIONS then
			local trace = {}
			
			trace.start = origin + Vector(0, 0, hullz - 60)
			trace.endpos = origin + Vector(0, 0, hullz - 60) + (angles:Forward() * -80)
			trace.filter = client_prop_model && ents.FindByClass("ph_prop")
			local tr = util.TraceLine(trace)
			
			view.origin = tr.HitPos
		else
			view.origin = origin + Vector(0, 0, hullz - 60) + (angles:Forward() * -80)
		end
	elseif pl:Team() == TEAM_HUNTERS && pl:Alive() then
		-- hunter here
	 	local wep = pl:GetActiveWeapon() 
	 	if wep && wep != NULL then 
	 		local func = wep.GetViewModelPosition 
	 		if func then 
	 			view.vm_origin, view.vm_angles = func(wep, origin*1, angles*1) -- Note: *1 to copy the object so the child function can't edit it. 
	 		end
	 		 
	 		local func = wep.CalcView 
	 		if func then 
	 			view.origin, view.angles, view.fov = func(wep, pl, origin*1, angles*1, fov) -- Note: *1 to copy the object so the child function can't edit it. 
	 		end 
	 	end
		-- hunter glimpse of thirdperson
		if CL_THIRDPERSON_TIMED > CurTime() then
			local trace = {}
			
			trace.start = origin
			trace.endpos = origin + (angles:Forward() * -80)
			trace.filter = player.GetAll()
			trace.maxs = Vector(4, 4, 4)
			trace.mins = Vector(-4, -4, -4)
			local tr = util.TraceHull(trace)
			
			view.drawviewer = true
			view.origin = tr.HitPos
		end
	end
 	
 	return view 
end


-- Draw round timeleft and hunter release timeleft
function HUDPaint()
	if GetGlobalBool("InRound", false) then
		-- local blindlock_time_left = (HUNTER_BLINDLOCK_TIME - (CurTime() - GetGlobalFloat("RoundStartTime", 0))) + 1
		local blindlock_time_left = (GetConVarNumber("ph_hunter_blindlock_time") - (CurTime() - GetGlobalFloat("RoundStartTime", 0))) + 1
		
		if blindlock_time_left < 1 && blindlock_time_left > -6 then
			blindlock_time_left_msg = "Ready or not, here we come!"
		elseif blindlock_time_left > 0 then
			blindlock_time_left_msg = "Hunters will be unblinded and released in "..string.ToMinutesSeconds(blindlock_time_left)
		else
			blindlock_time_left_msg = nil
		end
		
		if blindlock_time_left_msg then
			surface.SetFont("MyFont")
			local tw, th = surface.GetTextSize(blindlock_time_left_msg)
			
			draw.RoundedBox(8, 20, 20, tw + 20, 26, Color(0, 0, 0, 75))
			draw.DrawText(blindlock_time_left_msg, "MyFont", 31, 26, Color(255, 255, 0, 255), TEXT_ALIGN_LEFT)
		end
	end
	
	-- Draw some nice text
	if LocalPlayer():GetNWBool("InFreezeCam", false) then
		local w1, h1 = surface.GetTextSize("You were killed by "..LocalPlayer():GetNWEntity("PlayerKilledByPlayerEntity", nil):Name() );
		local textx = ScrW()/2
		local steamx = (ScrW()/2) - 32
		draw.SimpleTextOutlined("You were killed by "..LocalPlayer():GetNWEntity("PlayerKilledByPlayerEntity", nil):Name(), "TrebuchetBig", textx, ScrH()*0.75, Color(255, 10, 10, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1.5, Color(0, 0, 0, 255))
	end
	
	-- Draw a crosshair so aiming is easier for props
	 if LocalPlayer() && LocalPlayer():IsValid() && LocalPlayer():Alive() && LocalPlayer():Team() == TEAM_PROPS then
		local trace = {}
			trace.start = LocalPlayer():EyePos() + Vector(0, 0, hullz - 60)
			trace.endpos = LocalPlayer():EyePos() + Vector(0, 0, hullz - 60) + LocalPlayer():EyeAngles():Forward() * 10000
			trace.filter = client_prop_model && ents.FindByClass("ph_prop")
		
		local trace2 = util.TraceLine(trace)
		
		local crosshair_pos = trace2.HitPos:ToScreen()
		
			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(crosshair_pos.x - 1, crosshair_pos.y - 1, 4, 4)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect(crosshair_pos.x, crosshair_pos.y, 2, 2)
	end
end
hook.Add("HUDPaint", "PH_HUDPaint", HUDPaint)


-- Called immediately after starting the gamemode 
function Initialize()
	hullz = 80
	client_prop_light = false
	
	CreateClientConVar("ph_cl_halos", "1", true, true, "Toggle Enable/Disable Halo effects when choosing a prop.")
	
	-- Just like the server constant
	USABLE_PROP_ENTITIES_CL = {
		"prop_physics",
		"prop_physics_multiplayer"
	}
	
	-- surface.CreateFont("Arial", 14, 1200, true, false, "ph_arial")
	surface.CreateFont( "MyFont",
	{
		font	= "Arial",
		size	= 14,
		weight	= 1200,
		antialias = true,
		underline = false
	})

	surface.CreateFont("TrebuchetBig", {
		font = "Impact",
		size = 40
	})
end
hook.Add("Initialize", "PH_Initialize", Initialize)


-- Resets the player hull
function ResetHull(um)
	if LocalPlayer() && LocalPlayer():IsValid() then
		LocalPlayer():ResetHull()
		hullz = 80
	end
end
usermessage.Hook("ResetHull", ResetHull)


-- Sets the local blind variable to be used in CalcView
function SetBlind(um)
	blind = um:ReadBool()
end
usermessage.Hook("SetBlind", SetBlind)

-- here you can add more than 2 additional freeze cam sounds. Every list ends with commas.
local rndfrz = {
	"misc/freeze_cam.wav",
	"misc/freeze_cam_sad1.wav"
}

-- Plays the Freeze Cam sound
function PlayFreezeCamSound(um)
	-- surface.PlaySound("misc/freeze_cam.wav") // if you want single Freeze Cam Sound instead 2, uncomment this, and comment below.
	surface.PlaySound(table.Random(rndfrz))
end
usermessage.Hook("PlayFreezeCamSound", PlayFreezeCamSound)


-- Sets the player hull
function SetHull(um)
	hullxy = um:ReadLong()
	hullz = um:ReadLong()
	new_health = um:ReadLong()
	
	LocalPlayer():SetHull(Vector(hullxy * -1, hullxy * -1, 0), Vector(hullxy, hullxy, hullz))
	LocalPlayer():SetHullDuck(Vector(hullxy * -1, hullxy * -1, 0), Vector(hullxy, hullxy, hullz))
	LocalPlayer():SetHealth(new_health)
end
usermessage.Hook("SetHull", SetHull)


-- Player has a client-side prop model
function ClientPropSpawn(um)
	client_prop_model = ents.CreateClientProp("models/player/kleiner.mdl")
end
usermessage.Hook("ClientPropSpawn", ClientPropSpawn)


-- Remove the client prop model
function RemoveClientPropUMSG(um)
	if client_prop_model && client_prop_model:IsValid() then
		client_prop_model:Remove()
		client_prop_model = nil
	end
end
usermessage.Hook("RemoveClientPropUMSG", RemoveClientPropUMSG)


-- Called every client frame.
function GM:Think()
	for _, pl in pairs(team.GetPlayers(TEAM_PROPS)) do
		if GetConVar("ph_better_prop_movement"):GetBool() then
			if LocalPlayer() && LocalPlayer():IsValid() && LocalPlayer():Alive() && LocalPlayer():GetPlayerPropEntity() && LocalPlayer():GetPlayerPropEntity():IsValid() && client_prop_model && client_prop_model:IsValid() then
				if client_prop_model:GetModel() == "models/player/kleiner.mdl" then
					client_prop_model:SetPos(LocalPlayer():GetPos())
				else
					client_prop_model:SetPos(LocalPlayer():GetPos() - Vector(0, 0, LocalPlayer():GetPlayerPropEntity():OBBMins().z))
				end
				client_prop_model:SetModel(LocalPlayer():GetPlayerPropEntity():GetModel())
				client_prop_model:SetAngles(LocalPlayer():GetPlayerPropEntity():GetAngles())
				client_prop_model:SetSkin(LocalPlayer():GetPlayerPropEntity():GetSkin())
			end
		end
	end
	
	if client_prop_light && LocalPlayer() && LocalPlayer():IsValid() && LocalPlayer():Alive() && LocalPlayer():Team() == TEAM_PROPS then
		local prop_light = DynamicLight(LocalPlayer():EntIndex())
		if prop_light then
			prop_light.pos = LocalPlayer():GetPos()
			prop_light.r = 255
			prop_light.g = 255
			prop_light.b = 255
			prop_light.brightness = 0.15
			prop_light.decay = 1
			prop_light.size = 128
			prop_light.dietime = CurTime() + 0.1
		end
	end
end

-- Draws halos on team members
function TeamDrawHalos()
	if GetConVar("ph_cl_halos"):GetBool() then
		--[[ Warning: Causes massive LAGs on Public/Crowd Server!!! 
		-- Enable this if you know what you are doing. Just play with halo.Add's Blur X/Y settings and it's passes.
		
		for _, pl in pairs(player.GetAll()) do
			if pl != LocalPlayer() && (pl && pl:IsValid() && pl:Alive() && pl:Team() == LocalPlayer():Team()) then
				local pl_table = {}
				if pl:GetPlayerPropEntity() && pl:GetPlayerPropEntity():IsValid() then
					table.insert(pl_table, pl:GetPlayerPropEntity())
				else
					table.insert(pl_table, pl)
				end
				halo.Add(pl_table, team.GetColor(pl:Team()), 2, 2, 1, true, true)
			end
		end
		]]--
		
		-- Something to tell if the prop is selectable
		if LocalPlayer():Team() == TEAM_PROPS && LocalPlayer():Alive() then
			local trace = {}
			-- fix for smaller prop size. They should stay horizontal rather than looking straight down.
			if hullz < 25 then
				trace.start = LocalPlayer():EyePos() + Vector(0, 0, hullz - 30)
				trace.endpos = LocalPlayer():EyePos() + Vector(0, 0, hullz - 30) + LocalPlayer():EyeAngles():Forward() * 100 -- 100 Hammer units.
			else
				trace.start = LocalPlayer():EyePos() + Vector(0, 0, hullz - 60)
				trace.endpos = LocalPlayer():EyePos() + Vector(0, 0, hullz - 60) + LocalPlayer():EyeAngles():Forward() * 100
			end
			trace.filter = client_prop_model && ents.FindByClass("ph_prop")
			
			local trace2 = util.TraceLine(trace) 
			if trace2.Entity && trace2.Entity:IsValid() && table.HasValue(USABLE_PROP_ENTITIES_CL, trace2.Entity:GetClass()) then
				local ent_table = {}
				table.insert(ent_table, trace2.Entity)
				halo.Add(ent_table, Color(20, 250, 0), 1.2, 1.2, 1, true, true)
			end
		end
		
	end
end
hook.Add("PreDrawHalos", "TeamDrawHalos", TeamDrawHalos)


-- Replaces the flashlight with a client-side dynamic light for props
function PlayerSwitchDynamicLight(um)
	if client_prop_light then
		client_prop_light = false
		if IsMounted("cstrike") then
			surface.PlaySound("items/nvg_off.wav")
		end
	else
		client_prop_light = true
		if IsMounted("cstrike") then
			surface.PlaySound("items/nvg_on.wav")
		end
	end
end
usermessage.Hook("PlayerSwitchDynamicLight", PlayerSwitchDynamicLight)


-- Receive a list of usable prop entities
function ServerUsablePropsToClient(len)
	USABLE_PROP_ENTITIES_CL = net.ReadTable()
end
net.Receive("ServerUsablePropsToClient", ServerUsablePropsToClient)


-- Turns the dynamic light OFF
function DisableDynamicLight(um)
	if client_prop_light then
		client_prop_light = false
	end
end
usermessage.Hook("DisableDynamicLight", DisableDynamicLight)
