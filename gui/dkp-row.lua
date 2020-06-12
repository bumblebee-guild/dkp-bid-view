--[[-----------------------------------------------------------------------------
Displays a number and a player name.
-------------------------------------------------------------------------------]]
local Type, Version = "DKPRow", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local max, select, pairs = math.max, select, pairs

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GameFontHighlightSmall

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		-- set the flag to stop constant size updates
		self.resizing = true
		-- height is set dynamically by the text and image size
		self:SetWidth(200)
		self:SetText()
		self:SetNumber()
		self:SetColor()
		self:SetFontObject()

		self.label:SetJustifyH("LEFT")
		self.label:SetJustifyV("TOP")

		self.number:SetJustifyH("RIGHT")
		self.number:SetJustifyV("TOP")

		-- reset the flag
		self.resizing = nil
		-- run the update explicitly
	end,

	-- ["OnRelease"] = nil,

	["OnWidthSet"] = function(self, width)
		if self.resizing then return end

		self.label:ClearAllPoints()
		self.number:ClearAllPoints()

		self.number:SetPoint("TOPLEFT")
		self.label:SetPoint("TOPLEFT", self.number, "TOPRIGHT", 6, 0)

		local height = max(self.number:GetStringHeight(), self.label:GetStringHeight())
		local width = self.frame.width or self.frame:GetWidth() or 0
		self.number:SetWidth(35)
		self.label:SetWidth(width - 35)

		self.resizing = true
		self.frame:SetHeight(height)
		self.frame.height = height
		self.resizing = nil
	end,

	["SetText"] = function(self, text)
		self.label:SetText(text)
		self:OnWidthSet()
	end,

	["SetNumber"] = function(self, text)
		self.number:SetText(text)
		self:OnWidthSet()
	end,

	["SetColor"] = function(self, r, g, b)
		if not (r and g and b) then
			r, g, b = 1, 1, 1
		end
		self.label:SetVertexColor(r, g, b)
		self.number:SetVertexColor(r, g, b)
	end,

	["SetFont"] = function(self, font, height, flags)
		self.label:SetFont(font, height, flags)
		self.number:SetFont(font, height, flags)
	end,

	["SetFontObject"] = function(self, font)
		self:SetFont((font or GameFontHighlightSmall):GetFont())
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()

	local number = frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	local label = frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")

	-- create widget
	local widget = {
		number = number,
		label = label,
		frame = frame,
		type  = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
