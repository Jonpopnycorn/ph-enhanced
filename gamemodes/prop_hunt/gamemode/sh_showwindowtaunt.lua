if SERVER then
	util.AddNetworkString("CL2SV_PlayThisTaunt")
	
	net.Receive("CL2SV_PlayThisTaunt", function(len, ply)
		local snd = net.ReadString()
		
		if IsValid(ply) then
			ply:EmitSound(snd, 100)
		end
	end)	
end

if CLIENT then
	local isplayed = false
	local isopened = false
	local isforcedclose = false
	
	net.Receive("PH_ForceCloseTauntWindow", function()
		isforcedclose = true
	end)
	
	net.Receive("PH_AllowTauntWindow", function()
		isforcedclose = false
	end)
	
	local function MainFrame()
		if !CUSTOM_TAUNT_ENABLED then
			chat.AddText(Color(220,0,0),"[PH: Enhanced - Taunt] Warning: This server has custom taunts disabled.")
			return
		end
		
		isopened = true
	
		local frame = vgui.Create("DFrame")
		frame:SetSize(400,600)
		frame:SetTitle("Prop Hunt | Taunt List")
		frame:Center()
		frame:MakePopup()
		
		frame.OnClose = function()
			isopened = false
		end
		
		local function frame_Think_Force()
			if isforcedclose == true && isopened == true then
				isopened = false
				frame:Close()
			end
		end
		hook.Add("Think", "CloseWindowFrame_Force", frame_Think_Force)
		
		local list = vgui.Create("DListView", frame)
		list:SetMultiSelect(false)
		list:AddColumn("Sound list")
		list:SetPos(10,52)
		list:SetSize(380,528)
		
		-- Determine if prop or hunter taunt list to be used
		local TEAM_TAUNTS = PROP_TAUNTS
		if (LocalPlayer():Team() == TEAM_HUNTERS) then
			TEAM_TAUNTS = HUNTER_TAUNTS
		end
		
		for _,snd in pairs(TEAM_TAUNTS) do
			list:AddLine(snd)
		end
		
		local comb = vgui.Create("DComboBox", frame)
		comb:SetPos(10,28)
		comb:SetSize(380, 20)
		comb:SetValue("Original Taunts")
		comb:AddChoice("Original Taunts")
		comb:AddChoice("Custom Taunts")
		
		comb.OnSelect = function(pnl, idx, val)
			if val == "Original Taunts" then
				list:Clear()
				if TEAM_TAUNTS then
					for k,v in pairs(TEAM_TAUNTS) do
						list:AddLine(v)
					end
				end
			elseif val == "Custom Taunts" then
				list:Clear()
				if LocalPlayer():Team() == TEAM_PROPS then
					if PH_TAUNT_CUSTOM.PROP then
						for k,v in pairs(PH_TAUNT_CUSTOM.PROP) do
							list:AddLine(v)
						end
					end
				else
					if PH_TAUNT_CUSTOM.HUNTER then
						for k,v in pairs(PH_TAUNT_CUSTOM.HUNTER) do
							list:AddLine(v)
						end
					end
				end
			end
		end
		
		list.OnRowRightClick = function(panel,line)
			local getline = list:GetLine(list:GetSelectedLine()):GetValue(1)
			
			local function SendToServer()
				if isplayed != true then
					net.Start("CL2SV_PlayThisTaunt"); net.WriteString(tostring(getline)); net.SendToServer();
					isplayed = true
					timer.Simple(CUSTOM_TAUNT_DELAY, function() isplayed = false; end)
				else
					chat.AddText(Color(220,40,0),"[PH: Enhanced - Taunt] Warning: ",Color(220,220,220),"You have to wait "..CUSTOM_TAUNT_DELAY.." seconds to play this taunt again!")
				end
			end
			
			local menu = DermaMenu()
			menu:AddOption("Play (Local)", function() surface.PlaySound(getline); print("Playing: "..getline); end):SetIcon("icon16/control_play.png")
			menu:AddOption("Play (Global)", function() SendToServer(); end):SetIcon("icon16/sound.png")
			menu:AddOption("Play and Close (Global)", function() SendToServer(); frame:Close(); end):SetIcon("icon16/sound_delete.png")
			menu:AddSpacer()
			menu:AddOption("Close", function() frame:Close(); end):SetIcon("icon16/delete.png")
			menu:Open()
		end
	end
	
	concommand.Add("ph_showtaunts", function()
	if LocalPlayer():Alive() && isforcedclose != true then
		if isopened != true then
			MainFrame()
		end	
	else
		chat.AddText(Color(220,40,0),"[PH: Enhanced - Taunt] Notice: ",Color(220,220,220),"You can only play custom taunts when you\'re alive!")
	end
	end, nil, "Show Prop Hunt taunt list, so you can select and play for self or play as a taunt.")
	
	local function BindPress(ply, bind, pressed)
		if string.find(bind, "+menu_context") and pressed then
			RunConsoleCommand("ph_showtaunts")
		end
	end
	hook.Add("PlayerBindPress", "PlayerBindPress_menuContext", BindPress)
	
end