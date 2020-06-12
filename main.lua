local BID_STARTED_REGEXP = ">>>.* Enter your bid for.*Minimum BID is.*"
local BID_ENDED_NOBID_REGEXP = "Bidding for.*finished.*"
local BID_ENDED_WON_REGEXP = "%w+ won .* with %d+ DKP.*"
local BID_ACCEPTED_REGEXP = "([%w-]+) %- Current bid: (%d+).*OK.*"
local OFFICER_NOTE_DKP_REGEXP = "Net:%s*(%d+)"

local listeningChats = {
	"CHAT_MSG_RAID", -- raid chat
	"CHAT_MSG_RAID_LEADER", -- raid leader chat
	"CHAT_MSG_RAID_WARNING", -- raid warning
	-- "CHAT_MSG_SAY", -- say (for testing)
}

-- Convert the chat names to a set which can be used for faster testing wheter
-- some channel belongs to the set or not.
local listeningChatsSet = {}
for _, eventID in ipairs(listeningChats) do
	listeningChatsSet[eventID] = true;
end

local enabled = true
local playerRealm = GetRealmName()
local bidInProgress = false
local currentBidders = {}

-- getPlayerDKP finds the current player's DKP from the guild's officer note.
local function getPlayerDKP()
	guid = UnitGUID("player")
	if guid == nil then
		return "not in guild"
	end

	total, online, mobile = GetNumGuildMembers()

	for i=1,total do
		name, rankName, rankIndex, level, classDisplayName, zone, publicNote,
		officerNote, isOnline, status, class, achievementPoints, achievementRank,
		isMobile, canSoR, repStanding, memberGUID = GetGuildRosterInfo(i)
		if memberGUID == guid then
			local dkp = "unknown"
			for net, total in officerNote:gmatch(OFFICER_NOTE_DKP_REGEXP) do
				dkp = net
			end
			return dkp
		end
	end

	return "unknown"
end

local AceGUI = LibStub("AceGUI-3.0")

-- resetState returns the state of the addon to the initial position. That
-- is, there are no bids in progress and no current bidders.
local function resetState()
	bidInProgress = false
	currentBidders = {}
end

-- isChatEvent returns true if the event is part of the chat events we're listening
-- on for updates.
local function isChatEvent(event)
	return listeningChatsSet[event] == true;
end

local DKPWin = {
	["Show"] = function(self)
		if self.frame ~= nil then
			self:Hide()
		end

		frame = AceGUI:Create("DKPFrame")
		frame:SetWidth(180)
		frame:SetHeight(200)

		frame:SetPoint("RIGHT", -50, 0)

		frame:SetTitle("DKP Bid View")
		frame:SetStatusText("Your DKP: " .. getPlayerDKP())
		frame:SetLayout("List")

		self.frame = frame
	end,

	["Hide"] = function(self)
		if self.frame == nil then
			return
		end
		self.frame:Release()
		self.frame = nil
	end,

	["RefreshBidders"] = function(self, currentBidders)
		if self.frame == nil then
			return
		end

		self.frame:ReleaseChildren()
		local dkpToBidder = {}
		local order = {}

		for player, bid in pairs(currentBidders) do
			local ibid = tonumber(bid)
			if ibid ~= nil then
				if dkpToBidder[ibid] == nil then
					dkpToBidder[ibid] = {}
					order[#order+1] = ibid
				end
				dkpToBidder[ibid][player] = true
			end
		end

		table.sort(order)
		for i=#order,1,-1 do
			local bid = order[i]
			for player, t in pairs(dkpToBidder[bid]) do
				local l = AceGUI:Create("DKPRow")
				l:SetText(player)
				l:SetNumber(string.format("%s", bid))
				self.frame:AddChild(l)
			end
		end
	end
}

local function startBidding()
	resetState();
	bidInProgress = true;
	DKPWin:Show();
end

local function endBidding()
	resetState();
	DKPWin:Hide();
end

local function acceptBid(player, bid)
	if tonumber(bid) == nil then
		print("Bid [" .. bid .. "] from " .. player .. " is not a number. Ignoring it.")
		return
	end

	if player == nil then
		print("Bid for nil player reached acceptBid. Aborting.")
		return
	end

	-- Remove the realm if present in the player name.
	player = string.gsub(player, "-" .. playerRealm, "")

	currentBidders[player] = bid
	DKPWin:RefreshBidders(currentBidders)
end

local function handleChatEvent(author, msg)
	if string.match(msg, BID_STARTED_REGEXP) then
		startBidding()
		return
	end

	-- Bidding is not started yet. So there is no point trying to match
	-- any of the rest of the events.
	if not bidInProgress then
		return
	end

	if string.match(msg, BID_ENDED_NOBID_REGEXP) or
			string.match(msg, BID_ENDED_WON_REGEXP) then
		endBidding()
	end

	for player, bid in msg:gmatch(BID_ACCEPTED_REGEXP) do
		acceptBid(player, bid)
	end
end

local function eventDispatcher(self, event, arg1, arg2)
	if not enabled then
		return
	end

	-- Filter only chat events in the global event handlers. This leaves the door
	-- open for registering other type of events in the future.
	if isChatEvent(event) then
		-- For all the chat events arg2 is the author and arg1 is the
		-- acctual message.
		handleChatEvent(arg2, arg1)
	end
end

local function enable()
	if enabled then
		return
	end

	resetState();
	enabled = true
	print("dkpbv enabled")
end

local function disable()
	if not enabled then
		return
	end

	DKPWin:Hide();
	resetState();
	enabled = false
	print("dkpbv disabled. To enable it again write /dkpbv enable")
end

local function showStatus()
	if enabled then
		print("dkpbv: enabled")
	else
		print("dkpbv: enabled")
	end

	if bidInProgress then
		print("dkpbv: currently bidding is in progress")
	end
end

local function showHelp()
	print("Possible commands: status, cancel, hide, enable, disable")
	print("Current matchers:")
	print(" * bid started: " .. BID_STARTED_REGEXP)
	print(" * bid accepted: " .. BID_ACCEPTED_REGEXP)
	print(" * bid ended no bids: " .. BID_ENDED_NOBID_REGEXP)
	print(" * bid ended with win: " .. BID_ENDED_WON_REGEXP)
end

SLASH_DKPBIDVIEW1 = "/dkpbv"

-- dkpbvCli will include the "command line" interface
-- of the addon. Things such as start listening, stop listening
-- and stuff.
local function dkpbvCli(arg)
	if arg == "" or arg == "-h" then
		showHelp()
		return
	end

	if arg == "cancel" or arg == "hide" then
		endBidding()
		return
	end

	if arg == "disable" then
		disable()
		return
	end

	if arg == "enable" then
		enable()
		return
	end

	if arg == "status" then
		showStatus()
		return
	end

	print("dkpbv: unknown command '" .. arg .. "'")
	showHelp()
end

SlashCmdList["DKPBIDVIEW"] = dkpbvCli

DKPBidView = LibStub("AceAddon-3.0"):NewAddon("DKPBidView")

function DKPBidView:OnInitialize()
	resetState();
	local listenFrame = CreateFrame("FRAME", "DKPBidViewListeningFrame");
	for _, eventID in ipairs(listeningChats) do
		listenFrame:RegisterEvent(eventID);
	end
	listenFrame:SetScript("OnEvent", eventDispatcher);
end
