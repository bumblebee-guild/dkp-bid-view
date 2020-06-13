-- Default values for the patter matches.
local BID_STARTED_REGEXP = ">>>.* Enter your bid for.*Minimum BID is.*"
local BID_ENDED_NOBID_REGEXP = "Bidding for.*finished.*"
local BID_ENDED_WON_REGEXP = "[%w-]+ won .* with %d+ DKP.*"
local BID_ACCEPTED_REGEXP = "([%w-]+) %- Current bid: (%d+)%. OK!.*"
local OFFICER_NOTE_DKP_REGEXP = "Net:%s*(%d+)"

local DKPBidView = LibStub("AceAddon-3.0"):NewAddon("DKPBidView", "AceEvent-3.0")
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
		frame:SetStatusText("Your DKP: " .. DKPBidView:GetPlayerDKP())
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

function DKPBidView:GetOptions()
	local opts = {
		type = "group",
		args = {
			enable = {
				name = "Enable",
				desc = "Enables / disables the addon",
				type = "toggle",
				set = function(info,val)
					if val then
						self:Enable()
					else
						self:Disable()
					end
				end,
				get = function(info) return self.enabled end
			},
			patterns={
				name = "Patterns",
				desc = "Patterns for matching bidding messages.",
				type = "group",
				args={
					bidStarted = {
						name = "Bid Started",
						type = "input",
						desc = "Pattern for matching bidding started chat messages.",
						set = function(info, val) self.bidStartedRExp = val end,
						get = function(info) return self.bidStartedRExp end,
						multiline = 2,
					},
					bidEndedNoBid = {
						name = "Bid Ended (no bids)",
						type = "input",
						desc = "Pattern for the chat message when bidding ended without any bids.",
						set = function(info, val) self.bidEndedNoBidRExp = val end,
						get = function(info) return self.bidEndedNoBidRExp end,
						multiline = 2,
					},
					bidEndedWon = {
						name = "Bid Won",
						type = "input",
						desc = "Pattern for the chat message when someone won an item after bidding.",
						set = function(info, val) self.bidEndedWonRExp = val end,
						get = function(info) return self.bidEndedWonRExp end,
						multiline = 2,
					},
					bidAccepted = {
						name = "Bid Accepted",
						type = "input",
						desc = "Pattern for the chat message when someone's bid has been accepted.",
						set = function(info, val) self.bidAcceptedRExp = val end,
						get = function(info) return self.bidAcceptedRExp end,
						multiline = 2,
					},
				}
			},
			dkpExtract = {
				name = "My DKP",
				desc = "Configuration for obtaining player's DKP.",
				type = "group",
				args = {
					dkpOfficerNote = {
						name = "DKP From Officer Note",
						type = "input",
						desc = "This pattern should match one number. It is used against the player's officer note in their guild.",
						set = function(info, val) self.officerNoteRExp = val end,
						get = function(info) return self.officerNoteRExp end,
						multiline = 2,
					}
				},
			},
			chats = {
				name = "Chats",
				desc = "Configure which chats this addon will read.",
				type = "group",
				args = {
					raid = {
						name = "Raid Chat",
						type = "toggle",
						desc = "Listen for bidding messages in the RAID chat (/raid).",
						set = function(info, val)
							self.listenRaid = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.listenRaid end,
					},
					raidLeader = {
						name = "Raid Leader",
						type = "toggle",
						desc = "Listen for bidding messages from the raid leader.",
						set = function(info, val)
							self.listenRaidLeader = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.listenRaidLeader end,
					},
					raidWarning = {
						name = "Raid Warnings",
						type = "toggle",
						desc = "Listen for bidding messages in the RAID WARNING chat (/rw).",
						set = function(info, val)
							self.listenRaidWarning = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.listenRaidWarning end,
					},
					party = {
						name = "Party",
						type = "toggle",
						desc = "Listen for bidding messages in the party chat (/party).",
						set = function(info, val)
							self.listenParty = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.listenParty end,
					},
					partyLeader = {
						name = "Party Leader",
						type = "toggle",
						desc = "Listen for bidding messages from the party leader.",
						set = function(info, val)
							self.listenPartyLeader = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.listenPartyLeader end,
					},
					say = {
						name = "Say",
						type = "toggle",
						desc = "Listen for bidding in the say chat (/say).",
						set = function(info, val)
							self.listenSay = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.listenSay end,
					},
					yell = {
						name = "YELL",
						type = "toggle",
						desc = "Listen for people yelling bidding messages (/yell).",
						set = function(info, val)
							self.listenYell = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.listenYell end,
					},
				},
			},
		},
	}

	opts.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	return opts
end

function DKPBidView:OnInitialize()
	self.bidStartedRExp = BID_STARTED_REGEXP
	self.bidEndedNoBidRExp = BID_ENDED_NOBID_REGEXP
	self.bidEndedWonRExp = BID_ENDED_WON_REGEXP
	self.bidAcceptedRExp = BID_ACCEPTED_REGEXP
	self.officerNoteRExp = OFFICER_NOTE_DKP_REGEXP

	self.listenRaid = true
	self.listenRaidLeader = true
	self.listenRaidWarning = true
	self.listenParty = false
	self.listenPartyLeader = false
	self.listenSay = true
	self.listenYell = false

	self.enabled = true
	self.playerRealm = GetRealmName()
	self.bidInProgress = false
	self.currentBidders = {}
	self.configAppName = "DKP Bid View"

	self.db = LibStub("AceDB-3.0"):New("DKPBidView")
	self.opts = self:GetOptions()

	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable(self.configAppName, self.opts)

	local AceConfigDialog = LibStub("AceConfigDialog-3.0")
	AceConfigDialog:AddToBlizOptions(self.configAppName)

	self:ResetChatListeners()
end

function DKPBidView:ResetChatListeners()
	local unregisterEvents = {
		"CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER",
		"CHAT_MSG_RAID_WARNING",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_SAY",
		"CHAT_MSG_YELL",
	}

	for _, eventID in ipairs(unregisterEvents) do
		self:UnregisterEvent(eventID)
	end

	local listeningChats = {}

	if self.listenRaid then
		listeningChats[#listeningChats+1] = "CHAT_MSG_RAID"
	end

	if self.listenRaidLeader then
		listeningChats[#listeningChats+1] = "CHAT_MSG_RAID_LEADER"
	end

	if self.listenRaidWarning then
		listeningChats[#listeningChats+1] = "CHAT_MSG_RAID_WARNING"
	end

	if self.listenParty then
		listeningChats[#listeningChats+1] = "CHAT_MSG_PARTY"
	end

	if self.listenPartyLeader then
		listeningChats[#listeningChats+1] = "CHAT_MSG_PARTY_LEADER"
	end

	if self.listenSay then
		listeningChats[#listeningChats+1] = "CHAT_MSG_SAY"
	end

	if self.listenYell then
		listeningChats[#listeningChats+1] = "CHAT_MSG_YELL"
	end

	for _, eventID in ipairs(listeningChats) do
		self:RegisterEvent(eventID, self.HandleChatEvent, self)
	end
end

function DKPBidView:HandleChatEvent(author, msg)
	if not self.enabled then
		return
	end

	if string.match(msg, self.bidStartedRExp) then
		self:StartBidding()
		return
	end

	-- Bidding is not started yet. So there is no point trying to match
	-- any of the rest of the events.
	if not self.bidInProgress then
		return
	end

	if string.match(msg, self.bidEndedNoBidRExp) or
			string.match(msg, self.bidEndedWonRExp) then
		self:EndBidding()
	end

	for player, bid in msg:gmatch(self.bidAcceptedRExp) do
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

-- GetPlayerDKP finds the current player's DKP from the guild's officer note.
function DKPBidView:GetPlayerDKP()
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
			for net, total in officerNote:gmatch(self.officerNoteRExp) do
				dkp = net
			end
			return dkp
		end
	end

	return "unknown"
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
