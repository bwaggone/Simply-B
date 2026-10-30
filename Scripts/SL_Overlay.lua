---------------------------------------------------------------------------
-- SL_Overlay.lua
-- Standard overlay factory and layout archetypes for Simply Love. Creates an
-- ActorFrame with a standardized visual layout and a set of instance methods.
--
-- Layout Archetypes:
--  - "CenteredModal": Single centered dialog box with backdrop, header, content, footer.
--  - "DualPane": Independent per-player side-by-side panes with two-phase ready synchronization.
--  - "FullScreen": Fullscreen overlay with optional title, content, and footer.
---------------------------------------------------------------------------

SL = SL or {}
SL.Overlay = SL.Overlay or {}
SL.Overlay.Instances = SL.Overlay.Instances or {}

function SL.Overlay.Open(name, params)
	if SL.Overlay.Instances and SL.Overlay.Instances[name] then
		SL.Overlay.Instances[name]:Open(params)
	end
end

function SL.Overlay.Close(name, reason)
	if SL.Overlay.Instances and SL.Overlay.Instances[name] then
		SL.Overlay.Instances[name]:Close(reason)
	end
end

local function DefaultBorderColor(player)
	if player then
		return PlayerColor(player)
	end
	return GetCurrentColor()
end

local DefaultBgColor     = color("0.05,0.05,0.07,0.95")
local DefaultHeaderColor = color("0.12,0.12,0.15,1")

-- Standard audio cues
local Sounds = {
	change  = THEME:GetPathS("ScreenSelectMaster", "change"),
	start   = THEME:GetPathS("Common", "start"),
	cancel  = THEME:GetPathS("Common", "cancel"),
	invalid = THEME:GetPathS("ScreenSelectMaster", "invalid"),
}

local function PlayOverlaySound(name)
	if Sounds[name] then
		SOUND:PlayOnce(Sounds[name])
	end
end

---------------------------------------------------------------------------
-- CenteredModal Layout Builder
---------------------------------------------------------------------------
local function BuildCenteredModal(def, af, instance)
	local width  = def.Width  or SL_WideScale(440, 520)
	local height = def.Height or 300
	local title_text = def.Title or ""

	-- Root modal container centered on screen
	local container = Def.ActorFrame{
		Name = "ModalContainer",
		InitCommand = function(self)
			self:xy(_screen.cx, _screen.cy):zoom(0.95):diffusealpha(0)
		end,
		ShowCommand = function(self)
			self:stoptweening():decelerate(0.18):zoom(1):diffusealpha(1)
		end,
		HideCommand = function(self)
			self:stoptweening():accelerate(0.15):zoom(0.95):diffusealpha(0)
		end,

		-- Outer Border Quad
		Def.Quad{
			Name = "Border",
			InitCommand = function(self)
				self:zoomto(width + 4, height + 4):diffuse(def.BorderColor or DefaultBorderColor())
			end
		},

		-- Inner Body Background Quad
		Def.Quad{
			Name = "Background",
			InitCommand = function(self)
				self:zoomto(width, height):diffuse(def.BgColor or DefaultBgColor)
			end
		},

		-- Header Bar Background Quad
		Def.Quad{
			Name = "HeaderBar",
			InitCommand = function(self)
				self:zoomto(width, 36):y(-height/2 + 18):diffuse(def.HeaderColor or DefaultHeaderColor)
			end
		},

		-- Title BitmapText
		LoadFont("Common Bold")..{
			Name = "Title",
			Text = title_text,
			InitCommand = function(self)
				self:y(-height/2 + 18):zoom(0.85):maxwidth(width - 24)
			end
		},

		-- Footer / Prompt Bar
		Def.ActorFrame{
			Name = "Footer",
			InitCommand = function(self)
				self:y(height/2 - 16)
			end,

			Def.Quad{
				Name = "FooterBar",
				InitCommand = function(self)
					self:zoomto(width, 32):diffuse(0, 0, 0, 0.4)
				end
			},

			LoadFont("Common Normal")..{
				Name = "PromptText",
				Text = def.FooterText or THEME:GetString("Common", "PopupDismissText"),
				InitCommand = function(self)
					self:zoom(0.75):maxwidth(width - 20)
				end
			}
		}
	}

	-- User Content Slot
	if def.Content and type(def.Content) == "function" then
		local content_actor = def.Content(instance)
		if content_actor then
			content_actor.Name = content_actor.Name or "ContentSlot"
			container[#container+1] = content_actor
		end
	end

	af[#af+1] = container
end

---------------------------------------------------------------------------
-- FullScreen Layout Builder
---------------------------------------------------------------------------
local function BuildFullScreen(def, af, instance)
	local container = Def.ActorFrame{
		Name = "FullScreenContainer",
		InitCommand = function(self)
			self:diffusealpha(0)
		end,
		ShowCommand = function(self)
			self:stoptweening():linear(0.15):diffusealpha(1)
		end,
		HideCommand = function(self)
			self:stoptweening():linear(0.15):diffusealpha(0)
		end,
	}

	-- Optional Title text
	if def.Title then
		container[#container+1] = LoadFont(def.TitleFont or "Common Bold")..{
			Name = "Title",
			Text = def.Title,
			InitCommand = function(self)
				self:xy(_screen.cx, def.TitleY or 90):zoom(def.TitleZoom or 1.2):diffusealpha(1)
				self:diffuse(def.TitleColor or GetCurrentColor())
			end
		}
	end

	-- User Content Slot
	if def.Content and type(def.Content) == "function" then
		local content_actor = def.Content(instance)
		if content_actor then
			content_actor.Name = content_actor.Name or "ContentSlot"
			container[#container+1] = content_actor
		end
	end

	-- Optional Footer text
	if def.FooterText then
		container[#container+1] = LoadFont("Common Normal")..{
			Name = "FooterText",
			Text = def.FooterText,
			InitCommand = function(self)
				self:xy(_screen.cx, _screen.h - 40):zoom(def.FooterZoom or 0.85):diffusealpha(1)
			end
		}
	end

	af[#af+1] = container
end

---------------------------------------------------------------------------
-- DualPane Layout Builder
---------------------------------------------------------------------------
local function BuildDualPane(def, af, instance)
	local num_sides = GAMESTATE:GetNumSidesJoined()
	local single_player = (num_sides == 1)

	local pane_width = def.Width
	if not pane_width then
		pane_width = single_player and (def.Width1Player or SL_WideScale(360, 420)) or (def.Width2Player or SL_WideScale(290, 340))
	end
	local pane_height = def.Height or 380

	local human_players = GAMESTATE:GetHumanPlayers()

	for player in ivalues(PlayerNumber) do
		local pn = ToEnumShortString(player)
		local is_joined = GAMESTATE:IsSideJoined(player)

		local pane_x = _screen.cx
		if not single_player then
			local offset = def.PaneOffset or ((pane_width / 2) + 12)
			pane_x = (player == PLAYER_1) and (_screen.cx - offset) or (_screen.cx + offset)
		end
		local pane_y = def.Y or (_screen.cy + (def.OffsetY or 0))

		local pane_name = def.PaneName and def.PaneName(player) or ("Pane_" .. pn)
		local header_height = def.HeaderHeight or 36

		local pane_af = Def.ActorFrame{
			Name = pane_name,
			InitCommand = function(self)
				self.PaneFunctions = {}
				local sides = GAMESTATE:GetNumSidesJoined()
				local is_single = (sides == 1)
				local px = _screen.cx
				if not is_single then
					local offset = def.PaneOffset or ((pane_width / 2) + 12)
					px = (player == PLAYER_1) and (_screen.cx - offset) or (_screen.cx + offset)
				end
				local py = def.Y or (_screen.cy + (def.OffsetY or 0))
				self:xy(px, py):zoom(0.95):diffusealpha(0):visible(GAMESTATE:IsSideJoined(player))
			end,
			PlayerJoinedMessageCommand = function(self, params)
				if params.Player == player then
					self:visible(true)
				end
			end,
			ShowCommand = function(self, params)
				if def.OnPaneShow then
					def.OnPaneShow(instance, player, self, params)
				end
				if self:GetVisible() then
					self:stoptweening():decelerate(0.18):zoom(1):diffusealpha(1)
				end
			end,
			HideCommand = function(self)
				if self:GetVisible() then
					self:stoptweening():accelerate(0.15):zoom(0.95):diffusealpha(0)
				end
			end,

			-- Border Quad
			Def.Quad{
				Name = "Border",
				InitCommand = function(self)
					self:zoomto(pane_width + (def.BorderWidth or 4), pane_height + (def.BorderWidth or 4)):diffuse(def.BorderColor or DefaultBorderColor(player))
				end
			},

			-- Background Quad
			Def.Quad{
				Name = "Background",
				InitCommand = function(self)
					self:zoomto(pane_width, pane_height):diffuse(def.BgColor or DefaultBgColor)
				end
			},

			-- Header Bar
			Def.Quad{
				Name = "HeaderBar",
				InitCommand = function(self)
					self:zoomto(pane_width, header_height):y(-pane_height/2 + header_height/2):diffuse(def.HeaderColor or DefaultHeaderColor)
				end
			},

			-- Title / Header BitmapText
			LoadFont(def.TitleFont or "Common Bold")..{
				Name = "Title",
				Text = type(def.Title) == "function" and def.Title(player) or (def.Title or pn),
				InitCommand = function(self)
					self:y(-pane_height/2 + header_height/2):zoom(def.TitleZoom or 0.85):maxwidth(pane_width - 24)
				end
			},
		}

		-- User Player Content Slot
		if def.PlayerContent and type(def.PlayerContent) == "function" then
			local player_content = def.PlayerContent(instance, player)
			if player_content then
				if player_content.Class or player_content.Name then
					pane_af[#pane_af+1] = player_content
				elseif type(player_content) == "table" then
					for _, actor in ipairs(player_content) do
						pane_af[#pane_af+1] = actor
					end
				end
			end
		end

		-- Footer / Ready Indicator Bar (optional, enabled by default)
		if def.HasFooter ~= false and def.Footer ~= false then
			local footer_height = def.FooterHeight or 36
			pane_af[#pane_af+1] = Def.ActorFrame{
				Name = "Footer",
				InitCommand = function(self)
					self:y(pane_height/2 - footer_height/2)
				end,

				Def.Quad{
					Name = "FooterBar",
					InitCommand = function(self)
						self:zoomto(pane_width, footer_height):diffuse(0, 0, 0, 0.45)
					end
				},

				LoadFont("Common Normal")..{
					Name = "PromptText",
					Text = def.FooterText or THEME:GetString("Common", "PopupDismissText"),
					InitCommand = function(self)
						self:zoom(0.75):maxwidth(pane_width - 20)
					end
				},

				-- Ready Badge (hidden initially)
				LoadFont("Common Bold")..{
					Name = "ReadyBadge",
					Text = THEME:GetString("ScreenEvaluation", "Ready") or "READY!",
					InitCommand = function(self)
						self:zoom(0.9):diffuse(PlayerColor(player)):visible(false)
					end
				}
			}
		end

		af[#af+1] = pane_af
	end
end

---------------------------------------------------------------------------
-- SL.Overlay.Create Factory
---------------------------------------------------------------------------
function SL.Overlay.Create(def)
	def = def or {}
	local layout = def.Layout or "CenteredModal"

	-- Table holding overlay instance methods & state
	local instance = {
		Name = def.Name or "OverlayInstance",
		Layout = layout,
		PauseTimer = def.PauseTimer or false,
		_player_ready = {
			[PLAYER_1] = false,
			[PLAYER_2] = false,
		},
		_is_open = false,
		_actor_ref = nil,
	}

	-- Root ActorFrame definition
	local af = Def.ActorFrame{
		Name = instance.Name,
		InitCommand = function(self)
			instance._actor_ref = self
			self:visible(false)
			if def.OnInit then def.OnInit(instance) end
		end,
	}

	-- Fullscreen Scrim / Backdrop Quad
	local show_backdrop = (def.Backdrop ~= false)
	local target_alpha = 0.85
	if show_backdrop then
		local backdrop_color = (type(def.Backdrop) == "table" and def.Backdrop.color) or color("0,0,0,1")
		target_alpha = (type(def.Backdrop) == "table" and def.Backdrop.alpha) or 0.85

		af[#af+1] = Def.Quad{
			Name = "Backdrop",
			InitCommand = function(self)
				self:FullScreen():diffuse(backdrop_color):diffusealpha(0)
			end,
			ShowCommand = function(self)
				self:finishtweening():linear(0.18):diffusealpha(target_alpha)
			end,
			HideCommand = function(self)
				self:finishtweening():linear(0.15):diffusealpha(0)
			end
		}
	end

	-- Assemble visual layout archetype
	if layout == "DualPane" then
		BuildDualPane(def, af, instance)
	elseif layout == "CenteredModal" then
		BuildCenteredModal(def, af, instance)
	elseif layout == "FullScreen" then
		BuildFullScreen(def, af, instance)
	elseif layout == "Custom" and def.FooterText then
		af[#af+1] = LoadFont("Common Normal")..{
			Text = def.FooterText,
			InitCommand = function(self) self:xy(_screen.cx, _screen.h - 50):zoom(1.1) end
		}
	end

	-----------------------------------------------------------------------
	-- Instance Methods
	-----------------------------------------------------------------------
	function instance:Open(params)
		SL.OverlayManager:Push(self, params)
	end

	function instance:Close(reason)
		SL.OverlayManager:Pop(reason)
	end

	function instance:IsOpen()
		return self._is_open
	end

	function instance:GetActor()
		return self._actor_ref
	end

	function instance:PlaySound(name)
		PlayOverlaySound(name)
	end

	-- Two-Phase Ready State management (primarily for DualPane)
	function instance:GetPane(player)
		if not self._actor_ref or not player then return nil end
		local pn = ToEnumShortString(player)
		return (def.PaneName and self._actor_ref:GetChild(def.PaneName(player)))
			or self._actor_ref:GetChild("Pane_" .. pn)
			or self._actor_ref:GetChild(pn .. "EventAf")
	end

	function instance:SetPlayerReady(player, is_ready)
		if not player then return end
		self._player_ready[player] = (is_ready == true)

		-- Update visual ready badge in footer
		if self._actor_ref then
			local pane = self:GetPane(player)
			if pane then
				local footer = pane:GetChild("Footer")
				if footer then
					local prompt = footer:GetChild("PromptText")
					local badge  = footer:GetChild("ReadyBadge")
					if prompt and badge then
						prompt:visible(not self._player_ready[player])
						badge:visible(self._player_ready[player])
					end
				end
			end
		end

		if def.OnPlayerReady then
			def.OnPlayerReady(self, player, self._player_ready[player])
		end

		-- Check if all joined human players are ready
		if self:AreAllPlayersReady() then
			self:Close("ready")
		end
	end

	function instance:IsPlayerReady(player)
		return self._player_ready[player] == true
	end

	function instance:AreAllPlayersReady()
		local joined = GAMESTATE:GetHumanPlayers()
		if #joined == 0 then return true end

		for p in ivalues(joined) do
			if not self._player_ready[p] then
				return false
			end
		end
		return true
	end

	-- Internal lifecycle handlers invoked by SL.OverlayManager
	function instance:_InternalOpen(params)
		self._is_open = true
		self._player_ready[PLAYER_1] = false
		self._player_ready[PLAYER_2] = false

		if self._actor_ref then
			self._actor_ref:visible(true)

			local backdrop = self._actor_ref:GetChild("Backdrop")
			if backdrop then
				backdrop:finishtweening():linear(0.18):diffusealpha(target_alpha)
			end

			local modal = self._actor_ref:GetChild("ModalContainer")
			if modal then
				modal:finishtweening():decelerate(0.18):zoom(1):diffusealpha(1)
			end

			local fs = self._actor_ref:GetChild("FullScreenContainer")
			if fs then
				fs:finishtweening():linear(0.18):diffusealpha(1)
			end

			for player in ivalues(PlayerNumber) do
				local pane = self:GetPane(player)
				if pane and pane:GetVisible() then
					pane:stoptweening():decelerate(0.18):zoom(1):diffusealpha(1)
				end
			end
		end

		if def.AnimateIn then
			def.AnimateIn(self)
		end

		if def.OnOpen then
			def.OnOpen(self, params)
		end
	end

	function instance:_InternalClose(reason)
		self._is_open = false

		if def.OnClose then
			def.OnClose(self, reason)
		end

		if def.AnimateOut then
			def.AnimateOut(self)
		elseif self._actor_ref then
			local backdrop = self._actor_ref:GetChild("Backdrop")
			if backdrop then
				backdrop:finishtweening():linear(0.15):diffusealpha(0)
			end

			local modal = self._actor_ref:GetChild("ModalContainer")
			if modal then
				modal:finishtweening():accelerate(0.15):zoom(0.95):diffusealpha(0)
			end

			local fs = self._actor_ref:GetChild("FullScreenContainer")
			if fs then
				fs:finishtweening():linear(0.15):diffusealpha(0)
			end

			for player in ivalues(PlayerNumber) do
				local pane = self:GetPane(player)
				if pane and pane:GetVisible() then
					pane:stoptweening():accelerate(0.15):zoom(0.95):diffusealpha(0)
				end
			end

			-- Hide visibility after animation finishes
			self._actor_ref:sleep(0.18):queuecommand("FinishClose")
		end
	end

	-- FinishCloseCommand hides the actor tree once tweens conclude
	af.FinishCloseCommand = function(self)
		if not instance._is_open then
			self:visible(false)
		end
	end

	-- Commands callable via playcommand on C++ ActorFrame userdata
	af.OpenCommand = function(self, params)
		instance:Open(params)
	end
	af.CloseCommand = function(self, params)
		instance:Close(params and params.reason)
	end
	af.SetPlayerReadyCommand = function(self, params)
		if params and params.player then
			instance:SetPlayerReady(params.player, params.ready)
		end
	end

	-- Internal input router
	function instance:_HandleInput(event)
		if not (event and event.button) then return end

		-- If a navigation controller is present, process it
		if self.Navigation and self._HandleNavigationInput then
			local handled = self:_HandleNavigationInput(event)
			if handled then return end
		end

		-- Per-player routing if OnPlayerInput is provided
		if event.PlayerNumber and def.OnPlayerInput then
			def.OnPlayerInput(self, event.PlayerNumber, event)
			return
		end

		-- General input handler
		if def.OnInput then
			def.OnInput(self, event)
			return
		end

		-- Default fallback: Start or Back dismisses the overlay
		if event.type == "InputEventType_FirstPress" then
			if event.GameButton == "Start" or event.GameButton == "Back" then
				self:PlaySound("cancel")
				self:Close(event.GameButton == "Start" and "confirm" or "cancel")
			end
		end
	end

	-- Register instance globally by Name
	if def.Name then
		SL.Overlay.Instances[def.Name] = instance
	end

	-- Attach direct convenience methods onto the ActorFrame table
	af._OverlayInstance = instance
	function af:Open(params)
		instance:Open(params)
	end
	function af:Close(reason)
		instance:Close(reason)
	end
	function af:SetPlayerReady(player, ready)
		instance:SetPlayerReady(player, ready)
	end

	return af
end

return SL.Overlay
