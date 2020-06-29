-- Default values for the patter matches.
local BID_STARTED_REGEXP = ">>>.* Enter your bid for (.+)%. Minimum BID is.*"
local BID_ENDED_NOBID_REGEXP = "Bidding for.*finished.*"
local BID_ENDED_WON_REGEXP = "[^%s]+ won .* with %d+ DKP.*"
local BID_ACCEPTED_REGEXP = "([^%s]+) %- Current bid: (%d+)%. OK!.*"
local OFFICER_NOTE_DKP_REGEXP = "Net:%s*(%d+)"
local BID_MESSAGE = "+"

local DKPBidView = LibStub("AceAddon-3.0"):NewAddon("DKPBidView", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")

local DKPWin = {
	width = 180,
	height = 200,

	position = {
		point = "RIGHT",
		xOfs = -50,
		yOfs = 0,
	},

	["Show"] = function(self, item)
		if self.frame ~= nil then
			self:Hide()
		end

		local frame = AceGUI:Create("DKPFrame")
		frame:SetWidth(self.width)
		frame:SetHeight(self.height)

		frame:ClearAllPoints()
		frame:SetPoint(self.position.point,
			self.position.xOfs, self.position.yOfs)

		if item == nil then
			item = "Unknown Item"
		end
		frame:SetTitle(item)
		frame:SetStatusText("Your DKP: " .. DKPBidView:GetPlayerDKP())

		local noBidsLabel = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		noBidsLabel:SetPoint("TOPLEFT", 0, 20)
		noBidsLabel:SetPoint("BOTTOMRIGHT", 0, 0)
		noBidsLabel:SetHeight(20)
		noBidsLabel:SetJustifyH("CENTER")
		noBidsLabel:SetJustifyV("CENTER")
		noBidsLabel:SetText("No Bids")

		self.noBidsLabel = noBidsLabel
		self.frame = frame
	end,

	["Hide"] = function(self)
		if self.frame == nil then
			return
		end

		self.width = self.frame.frame.width
		self.height = self.frame.frame.height

		point, relativeTo, relativePoint, xOfs, yOfs = self.frame:GetPoint()
		self.position = {
			point = point,
			xOfs = xOfs,
			yOfs = yOfs,
		}

		self:RemoveNoBidders()

		self.frame:Release()
		self.frame = nil
	end,

	["RemoveNoBidders"] = function(self)
		if self.noBidsLabel == nil then
			return
		end

		self.noBidsLabel:Hide()
	end,

	["RefreshBidders"] = function(self, currentBidders)
		if self.frame == nil then
			return
		end

		self.frame:ReleaseChildren()
		self.frame:SetLayout("List")
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

		self:RemoveNoBidders()

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
				get = function(info) return self.db.char.enabled end
			},
			bidding = {
				name = "Bid Button",
				desc = "Controls the behaviour of the Bid button.",
				type = "group",
				order = 3,
				args = {
					explanation = {
						type = "description",
						order = 0,
						name = "When bidding is open one can use the Bid button to bid " ..
						"for the current item. It sends a chat message to /raid, " ..
						"/party or /say, depending whether the player is in raid, " ..
						"party or alone. This section controls the behaviour of the " ..
						"Bid button.",
					},
					bidMessage = {
						name = "Bid Message",
						type = "input",
						desc = "Change the text that will be sent once the Bid button has been pressed.",
						set = function(info, val) self.db.profile.bidding.bidMessage = val end,
						get = function(info) return self.db.profile.bidding.bidMessage end,
					},
				},
			},
			patterns={
				name = "Patterns",
				desc = "Patterns for matching bidding messages.",
				type = "group",
				order = 1,
				args={
					explanation = {
						type = "description",
						order = 0,
						name = "This section controls the different patters this " ..
							"addon will listen to in raid. Every pattern matches " ..
							"a particular event. They are all Lua regular expressions. " ..
							"Some of them are searching for particular thing in the " ..
							"message. Such things must be matched by regular expression " ..
							"groups.",
					},
					bidStarted = {
						name = "Bid Started",
						type = "input",
						desc = "Pattern for matching bidding started chat messages. If " ..
							"the pattern includes one group it will be shown as the item " ..
							"currently under bid.",
						set = function(info, val) self.db.profile.patterns.bidStartedRExp = val end,
						get = function(info) return self.db.profile.patterns.bidStartedRExp end,
						multiline = 2,
					},
					bidEndedNoBid = {
						name = "Bid Ended (no bids)",
						type = "input",
						desc = "Pattern for the chat message when bidding ended without any bids.",
						set = function(info, val) self.db.profile.patterns.bidEndedNoBidRExp = val end,
						get = function(info) return self.db.profile.patterns.bidEndedNoBidRExp end,
						multiline = 2,
					},
					bidEndedWon = {
						name = "Bid Won",
						type = "input",
						desc = "Pattern for the chat message when someone won an item after bidding.",
						set = function(info, val) self.db.profile.patterns.bidEndedWonRExp = val end,
						get = function(info) return self.db.profile.patterns.bidEndedWonRExp end,
						multiline = 2,
					},
					bidAccepted = {
						name = "Bid Accepted",
						type = "input",
						desc = "Pattern for the chat message when someone's bid has been accepted. " ..
							"This pattern must have two groups. The first one must match the player " ..
							"and the second one the DKP value.",
						set = function(info, val) self.db.profile.patterns.bidAcceptedRExp = val end,
						get = function(info) return self.db.profile.patterns.bidAcceptedRExp end,
						multiline = 2,
					},
				}
			},
			dkpExtract = {
				name = "My DKP",
				desc = "Configuration for obtaining player's DKP.",
				type = "group",
				order = 2,
				args = {
					explanation = {
						type = "description",
						order = 0,
						name = "This section controls how your DKP is shown on the " ..
							"bidding window status bar. Currently the only supported " ..
							"way of acquiring the DKP is from the your guild's " ..
							"officer note.",
					},
					dkpOfficerNote = {
						name = "DKP From Officer Note",
						type = "input",
						desc = "This pattern should match one number. It is used " ..
							"against the player's officer note in their guild. " ..
							"The pattern is Lua regular expression. It must have " ..
							"one group. The matched group will be the player's DKP.",
						set = function(info, val) self.db.profile.dkpExtract.officerNoteRExp = val end,
						get = function(info) return self.db.profile.dkpExtract.officerNoteRExp end,
						multiline = 2,
					}
				},
			},
			chats = {
				name = "Chats",
				desc = "Configure which chats this addon will read.",
				type = "group",
				order = 0,
				args = {
					explanation = {
						type = "description",
						order = 0,
						name = "This addon listens to chat messages for bidding events. " ..
							"Here you can control which channels this addon will listen to.",
					},
					raid = {
						name = "Raid Chat",
						type = "toggle",
						desc = "Listen for bidding messages in the RAID chat (/raid).",
						set = function(info, val)
							self.db.profile.chats.listenRaid = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.db.profile.chats.listenRaid end,
					},
					raidLeader = {
						name = "Raid Leader",
						type = "toggle",
						desc = "Listen for bidding messages from the raid leader.",
						set = function(info, val)
							self.db.profile.chats.listenRaidLeader = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.db.profile.chats.listenRaidLeader end,
					},
					raidWarning = {
						name = "Raid Warnings",
						type = "toggle",
						desc = "Listen for bidding messages in the RAID WARNING chat (/rw).",
						set = function(info, val)
							self.db.profile.chats.listenRaidWarning = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.db.profile.chats.listenRaidWarning end,
					},
					party = {
						name = "Party",
						type = "toggle",
						desc = "Listen for bidding messages in the party chat (/party).",
						set = function(info, val)
							self.db.profile.chats.listenParty = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.db.profile.chats.listenParty end,
					},
					partyLeader = {
						name = "Party Leader",
						type = "toggle",
						desc = "Listen for bidding messages from the party leader.",
						set = function(info, val)
							self.db.profile.chats.listenPartyLeader = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.db.profile.chats.listenPartyLeader end,
					},
					say = {
						name = "Say",
						type = "toggle",
						desc = "Listen for bidding in the say chat (/say).",
						set = function(info, val)
							self.db.profile.chats.listenSay = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.db.profile.chats.listenSay end,
					},
					yell = {
						name = "YELL",
						type = "toggle",
						desc = "Listen for people yelling bidding messages (/yell).",
						set = function(info, val)
							self.db.profile.chats.listenYell = val
							self:ResetChatListeners()
						end,
						get = function(info) return self.db.profile.chats.listenYell end,
					},
				},
			},
		},
	}

	opts.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	return opts
end

function DKPBidView:OnInitialize()
	self.playerRealm = GetRealmName()
	self.bidInProgress = false
	self.currentBidders = {}
	self.configAppName = "DKP Bid View"

	self.db = LibStub("AceDB-3.0"):New("DKPBidView", self:GetDBDefaults(), true)
	self.opts = self:GetOptions()

	AceConfig:RegisterOptionsTable(self.configAppName, self.opts)
	self.configDialog = AceConfigDialog:AddToBlizOptions(self.configAppName)

	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	self:ResetChatListeners()
end

function DKPBidView:RefreshConfig()
	self:ResetChatListeners()
end

function DKPBidView:GetDBDefaults()
	return {
		char = {
			enabled = true,
		},
		profile = {
			chats = {
				listenRaid = true,
				listenRaidLeader = true,
				listenRaidWarning = true,
				listenRaidParty = false,
				listenRaidPartyLeader = false,
				listenRaidSay = false,
				listenRaidYell = false,
			},
			dkpExtract = {
				officerNoteRExp = OFFICER_NOTE_DKP_REGEXP,
			},
			patterns = {
				bidStartedRExp = BID_STARTED_REGEXP,
				bidEndedNoBidRExp = BID_ENDED_NOBID_REGEXP,
				bidEndedWonRExp = BID_ENDED_WON_REGEXP,
				bidAcceptedRExp = BID_ACCEPTED_REGEXP,
			},
			bidding = {
				bidMessage = BID_MESSAGE,
			},
			window = {
				size = {
					width = 180,
					height = 200,
				},
				position = {
					point = "RIGHT",
					xOfs = -50,
					yOfs = 0,
				},
			},
		},
	}
end

function DKPBidView:OnEnable()
	DKPWin.width = self.db.profile.window.size.width
	DKPWin.height = self.db.profile.window.size.height
	DKPWin.position = self.db.profile.window.position
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

	if self.db.profile.chats.listenRaid then
		listeningChats[#listeningChats+1] = "CHAT_MSG_RAID"
	end

	if self.db.profile.chats.listenRaidLeader then
		listeningChats[#listeningChats+1] = "CHAT_MSG_RAID_LEADER"
	end

	if self.db.profile.chats.listenRaidWarning then
		listeningChats[#listeningChats+1] = "CHAT_MSG_RAID_WARNING"
	end

	if self.db.profile.chats.listenParty then
		listeningChats[#listeningChats+1] = "CHAT_MSG_PARTY"
	end

	if self.db.profile.chats.listenPartyLeader then
		listeningChats[#listeningChats+1] = "CHAT_MSG_PARTY_LEADER"
	end

	if self.db.profile.chats.listenSay then
		listeningChats[#listeningChats+1] = "CHAT_MSG_SAY"
	end

	if self.db.profile.chats.listenYell then
		listeningChats[#listeningChats+1] = "CHAT_MSG_YELL"
	end

	for _, eventID in ipairs(listeningChats) do
		self:RegisterEvent(eventID, self.HandleChatEvent, self)
	end
end

function DKPBidView:HandleChatEvent(author, msg)
	if not self.db.char.enabled then
		return
	end

	local _, _, itemLink = string.find(msg, self.db.profile.patterns.bidStartedRExp)
	if not (itemLink == nil) then
		self:StartBidding(itemLink)
		return
	end

	-- Bidding is not started yet. So there is no point trying to match
	-- any of the rest of the events.
	if not self.bidInProgress then
		return
	end

	if string.match(msg, self.db.profile.patterns.bidEndedNoBidRExp) or
			string.match(msg, self.db.profile.patterns.bidEndedWonRExp) then
		self:EndBidding()
	end

	for player, bid in msg:gmatch(self.db.profile.patterns.bidAcceptedRExp) do
		self:AcceptBid(player, bid)
	end
end

function DKPBidView:StartBidding(item)
	self:ResetState()
	self.bidInProgress = true
	DKPWin:Show(item)
	-- Fired when the player has pressed the "Bid" button on
	-- the DKP window.
	DKPWin.frame:SetCallback("OnBid", function(widget)
		self:PlaceBid()
	end)
end

function DKPBidView:EndBidding()
	self:ResetState()

	self.db.profile.window.size.width = DKPWin.width
	self.db.profile.window.size.height = DKPWin.height
	self.db.profile.window.position = DKPWin.position

	DKPWin:Hide()
end

function DKPBidView:AcceptBid(player, bid)
	if tonumber(bid) == nil then
		DKPBidView:Print("Bid [" .. bid .. "] from " .. player .. " is not a number. Ignoring it.")
		return
	end

	if player == nil then
		DKPBidView:Print("Bid for nil player reached acceptBid. Aborting.")
		return
	end

	-- Remove the realm if present in the player name.
	player = string.gsub(player, "-" .. self.playerRealm, "")

	self.currentBidders[player] = bid
	DKPWin:RefreshBidders(self.currentBidders)
end

function DKPBidView:PlaceBid()
	local channel = "SAY"

	if UnitInParty("player") then
		channel = "PARTY"
	end

	if UnitInRaid("player") then
		channel = "RAID"
	end

	SendChatMessage(self.db.profile.bidding.bidMessage, channel)
end

-- ResetState returns the state of the addon to the initial position. That
-- is, there are no bids in progress and no current bidders.
function DKPBidView:ResetState()
	self.bidInProgress = false
	self.currentBidders = {}
end

function DKPBidView:Enable()
	if self.db.char.enabled then
		return
	end

	self:ResetState();
	self.db.char.enabled = true
	DKPBidView:Print("DKP Bid View enabled")
end

function DKPBidView:Disable()
	if not self.db.char.enabled then
		return
	end

	DKPWin:Hide();
	self:ResetState();
	self.db.char.enabled = false
	DKPBidView:Print("DKP Bid View disabled. To enable it again write /dkpbv enable")
end

function DKPBidView:ShowStatus()
	if self.db.char.enabled then
		DKPBidView:Print("enabled")
	else
		DKPBidView:Print("disabled")
	end

	if self.bidInProgress then
		DKPBidView:Print("currently bidding is in progress")
	end
end

function DKPBidView:ShowHelp()
	print("Welcome to the DKP Bid View command line interface!")
	print("Possible sub-commands: status, cancel, hide, show, enable, disable, config")
	print("You can execute them by typing /dkpbv sub-command")
end

function DKPBidView:Print(msg)
	print("dkpbv: " .. msg)
end

-- GetPlayerDKP finds the current player's DKP from the guild's officer note.
function DKPBidView:GetPlayerDKP()
	guid = UnitGUID("player")
	if guid == nil then
		return "not in guild"
	end

	total, online, mobile = GetNumGuildMembers()
	local notRegExp = self.db.profile.dkpExtract.officerNoteRExp

	for i=1,total do
		local _, _, _, _, _, _, _, officerNote, _, _, _, _, _, _, _,
			_, memberGUID = GetGuildRosterInfo(i)
		if memberGUID == guid then
			local dkp = "unknown"
			for net, total in officerNote:gmatch(notRegExp) do
				dkp = net
			end
			return dkp
		end
	end

	return "unknown"
end

-- ShowConfig opens the addon configuration window.
function DKPBidView:ShowConfig()
	AceConfigDialog:Open(self.configAppName)
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
		DKPBidView:StartBidding(nil)
		return
	end

	if arg == "config" then
		DKPBidView:ShowConfig()
		return
	end

	if arg == "test" then
		-- local item = Item:CreateFromItemID(23288) -- long name
		local item = Item:CreateFromItemID(19360) -- short name
		item:ContinueOnItemLoad(function()
			local itemLink = item:GetItemLink()
			-- local printable = gsub(itemLink, "\124", "\124\124");

			SendChatMessage(">>> Please no raid spam. Enter your bid for " .. itemLink .. ". Minimum BID is 40!", "SAY")
			SendChatMessage("Ðezo-Ashbringer - Current bid: 80. OK!", "SAY")
			SendChatMessage("Nightruner - Current bid: 120. OK!", "SAY")
			SendChatMessage("Arcticus - NOT OK! You need at least 20 DKP to place a bid. You have 5.", "SAY")
		end)
		return
	end

	DKPBidView:Print("unknown command '" .. arg .. "'")
	DKPBidView:ShowHelp()
end

SlashCmdList["DKPBIDVIEW"] = dkpbvCli
