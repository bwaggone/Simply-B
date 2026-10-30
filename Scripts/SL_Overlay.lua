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

	-- Simple Confirm Navigation Buttons
	local use_default_buttons = def.Navigation
		and def.Navigation.type == "simple_confirm"
		and (def.Navigation.default_buttons == true or (def.Navigation.default_buttons ~= false and not def.Navigation.on_cursor_change and not def.Navigation.custom_buttons))

	if use_default_buttons then
		-- Default Yes / No button actors
		local choices = def.Navigation.choices or { "Yes", "No" }
		local choices_af = Def.ActorFrame{
			Name = "ChoicesAF",
			InitCommand = function(self) self:y(def.ChoicesY or 30) end,
		}

		local choice_spacing = math.min(150, (width - 40) / #choices)
		local choice_w = choice_spacing - 12
		local start_x = -(#choices - 1) * choice_spacing / 2

		for i, label in ipairs(choices) do
			local x_pos = start_x + (i - 1) * choice_spacing
			choices_af[#choices_af+1] = Def.ActorFrame{
				Name = "Choice_" .. i,
				InitCommand = function(self) self:x(x_pos) end,

				Def.Quad{
					Name = "Bg",
					InitCommand = function(self)
						local focus_color = def.FocusColor or GetCurrentColor()
						self:zoomto(choice_w, 34)
							:diffuse(i == 1 and focus_color or color("0,0,0,0.5"))
							:diffusealpha(i == 1 and 0.85 or 0.35)
					end,
					ChoiceChangedCommand = function(self, params)
						local is_selected = (params.index == i)
						local focus_color = def.FocusColor or GetCurrentColor()
						self:stoptweening():linear(0.1)
							:diffuse(is_selected and focus_color or color("0,0,0,0.5"))
							:diffusealpha(is_selected and 0.85 or 0.35)
					end
				},

				LoadFont("Common Bold")..{
					Name = "Label",
					Text = label,
					InitCommand = function(self)
						self:zoom(i == 1 and 0.82 or 0.72)
							:diffuse(i == 1 and Color.Black or Color.White)
							:diffusealpha(i == 1 and 1 or 0.6)
							:maxwidth(choice_w - 8)
					end,
					ChoiceChangedCommand = function(self, params)
						local is_selected = (params.index == i)
						self:stoptweening():linear(0.1)
							:zoom(is_selected and 0.82 or 0.72)
							:diffuse(is_selected and Color.Black or Color.White)
							:diffusealpha(is_selected and 1 or 0.6)
					end
				}
			}
		end
		container[#container+1] = choices_af
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
				self:xy(_screen.cx, def.TitleY or 90):zoom(def.TitleZoom or 0.9):maxwidth(_screen.w * 0.85):diffusealpha(1)
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

	-- Simple Confirm Navigation Buttons
	local use_default_buttons = def.Navigation
		and def.Navigation.type == "simple_confirm"
		and (def.Navigation.default_buttons == true or (def.Navigation.default_buttons ~= false and not def.Navigation.on_cursor_change and not def.Navigation.custom_buttons))

	if use_default_buttons then
		local choices = def.Navigation.choices or { "Yes", "No" }
		local choices_af = Def.ActorFrame{
			Name = "ChoicesAF",
			InitCommand = function(self) self:xy(_screen.cx, def.ChoicesY or (_screen.cy + 120)) end,
		}

		local choice_spacing = math.min(220, (_screen.w * 0.8) / #choices)
		local choice_w = choice_spacing - 16
		local start_x = -(#choices - 1) * choice_spacing / 2

		for i, label in ipairs(choices) do
			local x_pos = start_x + (i - 1) * choice_spacing
			choices_af[#choices_af+1] = Def.ActorFrame{
				Name = "Choice_" .. i,
				InitCommand = function(self) self:x(x_pos) end,

				Def.Quad{
					Name = "Bg",
					InitCommand = function(self)
						local focus_color = def.FocusColor or GetCurrentColor()
						self:zoomto(choice_w, 36)
							:diffuse(i == 1 and focus_color or color("0,0,0,0.5"))
							:diffusealpha(i == 1 and 0.85 or 0.35)
					end,
					ChoiceChangedCommand = function(self, params)
						local is_selected = (params.index == i)
						local focus_color = def.FocusColor or GetCurrentColor()
						self:stoptweening():linear(0.1)
							:diffuse(is_selected and focus_color or color("0,0,0,0.5"))
							:diffusealpha(is_selected and 0.85 or 0.35)
					end
				},

				LoadFont("Common Bold")..{
					Name = "Label",
					Text = label,
					InitCommand = function(self)
						self:zoom(i == 1 and 0.85 or 0.72)
							:diffuse(i == 1 and Color.Black or Color.White)
							:diffusealpha(i == 1 and 1 or 0.6)
							:maxwidth(choice_w - 12)
					end,
					ChoiceChangedCommand = function(self, params)
						local is_selected = (params.index == i)
						self:stoptweening():linear(0.1)
							:zoom(is_selected and 0.85 or 0.72)
							:diffuse(is_selected and Color.Black or Color.White)
							:diffusealpha(is_selected and 1 or 0.6)
					end
				}
			}
		end
		container[#container+1] = choices_af
	end

	-- Optional Footer text
	if def.FooterText then
		container[#container+1] = LoadFont("Common Normal")..{
			Name = "FooterText",
			Text = def.FooterText,
			InitCommand = function(self)
				self:xy(_screen.cx, _screen.h - 40):zoom(def.FooterZoom or 0.7):maxwidth(_screen.w * 0.9):diffusealpha(1)
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

		-- Ready Dialogue / Overlay (shown when player is waiting for other player to confirm exit)
		local other_pn = (player == PLAYER_1) and "P2" or "P1"
		local footer_h = (def.HasFooter ~= false and def.Footer ~= false) and (def.FooterHeight or 36) or 0
		local ready_box_w = math.min(260, pane_width - 24)
		local ready_y = (header_height - footer_h) / 2

		pane_af[#pane_af+1] = Def.ActorFrame{
			Name = "ReadyOverlay",
			InitCommand = function(self)
				self:visible(false)
			end,

			Def.Quad{
				Name = "ReadyBg",
				InitCommand = function(self)
					self:zoomto(pane_width - 4, pane_height - header_height - footer_h - 4)
						:y(ready_y)
						:diffuse(color("0,0,0,0.85"))
				end
			},

			Def.Quad{
				Name = "ReadyBoxBorder",
				InitCommand = function(self)
					self:zoomto(ready_box_w, 94):y(ready_y):diffuse(PlayerColor(player))
				end
			},

			Def.Quad{
				Name = "ReadyBoxBg",
				InitCommand = function(self)
					self:zoomto(ready_box_w - 4, 90):y(ready_y):diffuse(color("0.08,0.08,0.1,0.95"))
				end
			},

			LoadFont("Common Bold")..{
				Name = "ReadyText",
				Text = "READY!",
				InitCommand = function(self)
					self:y(ready_y - 18):zoom(0.95):diffuse(PlayerColor(player))
				end
			},

			LoadFont("Common Normal")..{
				Name = "WaitingText",
				Text = "Waiting for " .. other_pn .. " to confirm...",
				InitCommand = function(self)
					self:y(ready_y + 10):zoom(0.65):diffuse(Color.White):diffusealpha(0.85)
						:maxwidth(ready_box_w - 20)
				end
			},

			LoadFont("Common Normal")..{
				Name = "CancelPrompt",
				Text = "Press &BACK; to cancel",
				InitCommand = function(self)
					self:y(ready_y + 28):zoom(0.5):diffuse(Color.White):diffusealpha(0.6)
				end
			}
		}

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
		Navigation = def.Navigation,
	}

	if def.Navigation and SL.Overlay.AttachNavigation then
		SL.Overlay.AttachNavigation(instance, def.Navigation)
	end

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

		-- Update visual ready badge in footer and ready dialogue overlay
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

				local ready_overlay = pane:GetChild("ReadyOverlay")
				if ready_overlay then
					ready_overlay:visible(self._player_ready[player])
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

			if layout == "DualPane" then
				local sides = GAMESTATE:GetNumSidesJoined()
				local is_single = (sides == 1)
				local cur_pane_width = is_single and (def.Width1Player or def.Width or SL_WideScale(360, 420))
				                                  or (def.Width2Player or def.Width or SL_WideScale(290, 340))
				local pane_height = def.Height or 380
				local header_height = def.HeaderHeight or 36
				local footer_height = (def.HasFooter ~= false and def.Footer ~= false) and (def.FooterHeight or 36) or 0
				local offset = def.PaneOffset or ((cur_pane_width / 2) + 12)
				local py = def.Y or (_screen.cy + (def.OffsetY or 0))

				for player in ivalues(PlayerNumber) do
					local pane = self:GetPane(player)
					if pane then
						local is_joined = GAMESTATE:IsSideJoined(player)
						pane:visible(is_joined)

						if is_joined then
							local px = is_single and _screen.cx or ((player == PLAYER_1) and (_screen.cx - offset) or (_screen.cx + offset))
							pane:xy(px, py)

							local border = pane:GetChild("Border")
							if border then border:zoomto(cur_pane_width + (def.BorderWidth or 4), pane_height + (def.BorderWidth or 4)) end
							local bg = pane:GetChild("Background")
							if bg then bg:zoomto(cur_pane_width, pane_height) end
							local header_bar = pane:GetChild("HeaderBar")
							if header_bar then header_bar:zoomto(cur_pane_width, header_height) end
							local title = pane:GetChild("Title")
							if title then title:maxwidth(cur_pane_width - 24) end

							local footer = pane:GetChild("Footer")
							if footer then
								local footer_bar = footer:GetChild("FooterBar")
								if footer_bar then footer_bar:zoomto(cur_pane_width, footer_height) end
								local prompt = footer:GetChild("PromptText")
								if prompt then prompt:visible(true):maxwidth(cur_pane_width - 20) end
								local badge = footer:GetChild("ReadyBadge")
								if badge then badge:visible(false) end
							end

							local ready_overlay = pane:GetChild("ReadyOverlay")
							if ready_overlay then
								ready_overlay:visible(false)
								local r_box_w = math.min(260, cur_pane_width - 24)
								local r_y = (header_height - footer_height) / 2
								local r_bg = ready_overlay:GetChild("ReadyBg")
								if r_bg then
									r_bg:zoomto(cur_pane_width - 4, pane_height - header_height - footer_height - 4):y(r_y)
								end
								local r_border = ready_overlay:GetChild("ReadyBoxBorder")
								if r_border then
									r_border:zoomto(r_box_w, 94):y(r_y)
								end
								local r_box_bg = ready_overlay:GetChild("ReadyBoxBg")
								if r_box_bg then
									r_box_bg:zoomto(r_box_w - 4, 90):y(r_y)
								end
								local r_text = ready_overlay:GetChild("ReadyText")
								if r_text then r_text:y(r_y - 18) end
								local w_text = ready_overlay:GetChild("WaitingText")
								if w_text then w_text:y(r_y + 10):maxwidth(r_box_w - 20) end
								local c_prompt = ready_overlay:GetChild("CancelPrompt")
								if c_prompt then c_prompt:y(r_y + 28) end
							end

							pane:playcommand("Show", params)
							pane:stoptweening():decelerate(0.18):zoom(1):diffusealpha(1)
						end
					end
				end
			end

			-- If simple_confirm navigation is present, refresh initial choice state
			local parent = self._actor_ref:GetChild("ModalContainer") or self._actor_ref:GetChild("FullScreenContainer") or self._actor_ref
			local choices_af = parent and parent:GetChild("ChoicesAF")
			if choices_af and self._nav_state and self._nav_state.choices then
				for i = 1, #self._nav_state.choices do
					local choice = choices_af:GetChild("Choice_" .. i)
					if choice then
						choice:playcommand("ChoiceChanged", { index = self._nav_state.index or 1 })
					end
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
			pcall(function() def.OnClose(self, reason) end)
		end

		-- If screen is exiting, actors may already be destroyed or transitioning
		if reason == "screen_exit" then
			return
		end

		if def.AnimateOut then
			pcall(function() def.AnimateOut(self) end)
		elseif self._actor_ref then
			pcall(function()
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
			end)
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
