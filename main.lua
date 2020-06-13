local BID_STARTED_REGEXP = ">>>.* Enter your bid for.*Minimum BID is.*"
local BID_ENDED_NOBID_REGEXP = "Bidding for.*finished.*"
local BID_ENDED_WON_REGEXP = "[%w-]+ won .* with %d+ DKP.*"
local BID_ACCEPTED_REGEXP = "([%w-]+) %- Current bid: (%d+)%. OK!.*"
local OFFICER_NOTE_DKP_REGEXP = "Net:%s*(%d+)"

local listeningChats = {
	"CHAT_MSG_RAID", -- raid chat
	"CHAT_MSG_RAID_LEADER", -- raid leader chat
	"CHAT_MSG_RAID_WARNING", -- raid warning
	"CHAT_MSG_SAY", -- say (for testing)
}

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

local DKPBidView = LibStub("AceAddon-3.0"):NewAddon("DKPBidView", "AceEvent-3.0")

function DKPBidView:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("DKPBidView")

	self.enabled = true
	self.playerRealm = GetRealmName()
	self.bidInProgress = false
	self.currentBidders = {}

	for _, eventID in ipairs(listeningChats) do
		self:RegisterEvent(eventID, self.HandleChatEvent, self)
	end
end

function DKPBidView:HandleChatEvent(author, msg)
	if not self.enabled then
		return
	end

	if string.match(msg, BID_STARTED_REGEXP) then
		self:StartBidding()
		return
	end

	-- Bidding is not started yet. So there is no point trying to match
	-- any of the rest of the events.
	if not self.bidInProgress then
		return
	end

	if string.match(msg, BID_ENDED_NOBID_REGEXP) or
			string.match(msg, BID_ENDED_WON_REGEXP) then
		self:EndBidding()
	end

	for player, bid in msg:gmatch(BID_ACCEPTED_REGEXP) do
		self:AcceptBid(player, bid)
	end
end

function DKPBidView:StartBidding()
	self:ResetState();
	self.bidInProgress = true;
	DKPWin:Show();
end

function DKPBidView:EndBidding()
	self:ResetState();
	DKPWin:Hide();
end

function DKPBidView:AcceptBid(player, bid)
	if tonumber(bid) == nil then
		print("Bid [" .. bid .. "] from " .. player .. " is not a number. Ignoring it.")
		return
	end

	if player == nil then
		print("Bid for nil player reached acceptBid. Aborting.")
		return
	end

	-- Remove the realm if present in the player name.
	player = string.gsub(player, "-" .. self.playerRealm, "")

	self.currentBidders[player] = bid
	DKPWin:RefreshBidders(self.currentBidders)
end

-- ResetState returns the state of the addon to the initial position. That
-- is, there are no bids in progress and no current bidders.
function DKPBidView:ResetState()
	self.bidInProgress = false
	self.currentBidders = {}
end

function DKPBidView:Enable()
	if self.enabled then
		return
	end

	self:ResetState();
	self.enabled = true
	print("dkpbv enabled")
end

function DKPBidView:Disable()
	if not self.enabled then
		return
	end

	DKPWin:Hide();
	self:ResetState();
	self.enabled = false
	print("dkpbv disabled. To enable it again write /dkpbv enable")
end

function DKPBidView:ShowStatus()
	if self.enabled then
		print("dkpbv: enabled")
	else
		print("dkpbv: disabled")
	end

	if self.bidInProgress then
		print("dkpbv: currently bidding is in progress")
	end
end

function DKPBidView:ShowHelp()
	print("Possible commands: status, cancel, hide, show, enable, disable")
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
		DKPBidView:ShowHelp()
		return
	end

	if arg == "cancel" or arg == "hide" then
		DKPBidView:EndBidding()
		return
	end

	if arg == "disable" then
		DKPBidView:Disable()
		return
	end

	if arg == "enable" then
		DKPBidView:Enable()
		return
	end

	if arg == "status" then
		DKPBidView:ShowStatus()
		return
	end

	if arg == "show" then
		DKPBidView:StartBidding()
		return
	end

	print("dkpbv: unknown command '" .. arg .. "'")
	DKPBidView:ShowHelp()
end

SlashCmdList["DKPBIDVIEW"] = dkpbvCli
