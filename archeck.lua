local ARcheck_Tooltip = CreateFrame("GameTooltip", "ARcheckTooltip", nil, "GameTooltipTemplate")
local ARcheck_Prefix = "ARcheckTooltip"
ARcheck_Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local gfind = string.gmatch or string.gfind

do
	SLASH_ARCHECK1 = "/archeck"
	SlashCmdList["ARCHECK"] = function(message)
		local commandlist = { }
		local command

		for command in gfind(message, "[^ ]+") do
			table.insert(commandlist, string.lower(command))
		end

		if type(tonumber(commandlist[1])) == "number" then
			local arValue = tonumber(commandlist[1])
			local belowThresholdList = { }
			local tooFarList = { }
			-- DEFAULT_CHAT_FRAME:AddMessage("Checking for players below |cff33ffcc" .. arValue .. " AR")

			for i=1,40 do
				local unit = "raid"..i
				local name = UnitName(unit)
				local isTooFar = true
				local totalAR = 0
				if UnitExists(unit) then
					for slot=1, 19 do
						if ARcheck_Tooltip:SetInventoryItem(unit, slot) then
							isTooFar = false
							local _, _, eqItemLink = strfind(GetInventoryItemLink(unit, slot), "(item:%d+:%d+:%d+:%d+)")
							if eqItemLink then ARcheck_Tooltip:ClearLines() ARcheck_Tooltip:SetHyperlink(eqItemLink) end
							for line=1, ARcheck_Tooltip:NumLines() do
								local left = getglobal(ARcheck_Prefix .. "TextLeft" .. line)
								if left:GetText() then
									local _,_, value = strfind(left:GetText(), "([%d.]+) Arcane Resistance")
									if value then
										totalAR = totalAR + tonumber(value)
									end
									_,_, value = strfind(left:GetText(), "([%d.]+) All Resistances")
									if value then
										totalAR = totalAR + tonumber(value)
									end
								end
							end
						end
					end

					if isTooFar == true then
						table.insert(tooFarList, {name})
						-- print("Raider "..name.." is too far")
						-- SendChatMessage("Raider "..name.." is too far", "RAID")
					elseif totalAR < arValue then
						table.insert(belowThresholdList, {name, totalAR})
						-- print("Raider "..name.." has "..totalAR.." AR")
						-- SendChatMessage("Raider "..name.." has "..totalAR.." AR", "RAID")
					end
				end
			end

			local belowThresholdMsg = "Raiders below |cff33ffcc"..arValue.." AR |rfrom gear:\n"
			local belowThresholdMsgAdd = ""
			local tooFarMsg = "Raiders too far to inspect:\n"
			local tooFarMsgAdd = ""

			for k, v in pairs(belowThresholdList) do
				if k > 1 then
					belowThresholdMsgAdd = belowThresholdMsgAdd .. ", "
				end
				belowThresholdMsgAdd = belowThresholdMsgAdd .. v[1] .. " (" .. v[2] .. " AR)"
			end

			for k, v in pairs(tooFarList) do
				if k > 1 then
					tooFarMsgAdd = tooFarMsgAdd .. ", "
				end
				tooFarMsgAdd = tooFarMsgAdd .. v[1]
			end

			if commandlist[2] == "announce" then
				SendChatMessage(belowThresholdMsg, "RAID")
				if next(belowThresholdList) == nil and next(tooFarList) == nil then
					local successMsg = "|cff33ffccNone! Time to kill Anomalus|r"
					SendChatMessage(successMsg, "RAID")
				end
				if next(belowThresholdList) ~= nil then
					SendChatMessage(belowThresholdMsgAdd, "RAID")
				end
				if next(tooFarList) ~= nil then
					SendChatMessage(tooFarMsg, "RAID")
					SendChatMessage(tooFarMsgAdd, "RAID")
				end
			else
				if next(belowThresholdList) == nil and next(tooFarList) == nil then
					belowThresholdMsg = belowThresholdMsg .. "|cff33ffccNone! Time to kill Anomalus|r"
				end
				DEFAULT_CHAT_FRAME:AddMessage(belowThresholdMsg .. belowThresholdMsgAdd)
				if next(tooFarList) ~= nil then
					DEFAULT_CHAT_FRAME:AddMessage(tooFarMsg .. tooFarMsgAdd)
				end
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("AR Checker Usage:")
			DEFAULT_CHAT_FRAME:AddMessage("|cffaaffdd/archeck 230 |cffaaaaaa - |rLists all players in your raid who have less than 230 AR from gear")
			DEFAULT_CHAT_FRAME:AddMessage("|cffaaffdd/archeck 230 announce|cffaaaaaa - |rAnnounces in raid chat all players in your raid who less than 230 AR from gear")
		end
	end
end

local function StartInspecting(unitID)
	local name = UnitName(unitID);

	if (name ~= inspectedPlayerName) then -- changed target, clear currently inspected player
		ClearInspectPlayer();
		inspectedPlayerName = nil;
	end
	if (name == nil
		or name == inspectedPlayerName
		or not UnitIsPlayer(unitID)
		--or not UnitIsFriend("player", unitID)  -- all grouped players are Alliance on turtle so this will record enemy players data
		or eFaction[UnitRace(unitID)] -- check if players race is of other faciton
		or not CheckInteractDistance(unitID, 1)
		or not CanInspect(unitID)) then
		return
	end
	
	local player = HonorSpy.db.realm.hs.currentStandings[name] or inspectedPlayers[name]; --need to check for faction
	if (player == nil) then
		inspectedPlayers[name] = {last_checked = 0};
		player = inspectedPlayers[name];
	end
	if (time() - player.last_checked < 30) then -- 30 seconds until new inspection request
		return
	end
	-- we gonna inspect new player, clear old one
	ClearInspectPlayer();
	inspectedPlayerName = name;
	player.unitID = unitID;
	NotifyInspect(unitID);
	RequestInspectHonorData();
	_, player.rank = GetPVPRankInfo(UnitPVPRank(player.unitID)); -- rank must be get asap while mouse is still over a unit
	_, player.class = UnitClass(player.unitID); -- same
	_, player.race = UnitRace(player.unitID); -- same
end