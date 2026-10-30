local text_width = 420

local _zoom = {
	active   = WideScale(1.15, 1.1),
	inactive = WideScale(0.55, 0.5)
}
local choice_actors = {}

local promptModal = SL.Overlay.Create({
	Name = "PromptToSetSrpgVisualStyle",
	Layout = "FullScreen",
	Backdrop = { color = Color.Black, alpha = 0.65 },

	Navigation = {
		type = "simple_confirm",
		choices = { "Yes", "No" },
		default_choice = 1,
		on_cursor_change = function(self, index)
			for i, actor in ipairs(choice_actors) do
				local is_active = (i == index)
				actor:diffuse(is_active and PlayerColor(PLAYER_2) or color("1,1,1,1"))
					:finishtweening():linear(0.1)
					:zoom(is_active and _zoom.active or _zoom.inactive)
			end
		end,
		on_confirm = function(self, accepted, player)
			if accepted then
				SL.SRPG10:ActivateVisualStyle()
			else
				ThemePrefs.Set("LastActiveEvent", "SRPG10")
			end
			local top_screen = SCREENMAN:GetTopScreen()
			top_screen:SetNextScreenName("ScreenTitleMenu"):StartTransitioningScreen("SM_GoToNextScreen")
		end
	},

	Content = function(self)
		local content_af = Def.ActorFrame{}

		content_af[#content_af+1] = LoadFont("Common Normal")..{
			Text = ScreenString("Paragraph1"),
			InitCommand = function(self)
				self:xy(_screen.cx, 90):_wrapwidthpixels(text_width):diffusealpha(0):zoom(WideScale(2.15, 2))
			end,
			OnCommand = function(self) self:linear(0.15):diffusealpha(1) end
		}

		content_af[#content_af+1] = LoadFont("Common Normal")..{
			Text = ScreenString("Paragraph2"),
			InitCommand = function(self)
				self:xy(_screen.cx, 350):_wrapwidthpixels(text_width):diffusealpha(0):zoom(WideScale(1.15, 1))
			end,
			OnCommand = function(self) self:linear(0.15):diffusealpha(1) end
		}

		local choices_af = Def.ActorFrame{
			InitCommand = function(self) self:diffusealpha(0):y(225) end,
			OnCommand = function(self) self:sleep(0.15):linear(0.15):diffusealpha(1) end,
		}

		choices_af[#choices_af+1] = Def.ActorFrame{
			InitCommand = function(self)
				self:x(_screen.cx - 80):diffuse(PlayerColor(PLAYER_2)):zoom(_zoom.active)
				choice_actors[1] = self
			end,
			LoadFont("Common Bold")..{
				Text = THEME:GetString("ScreenPromptToResetPreferencesToStock", "Yes"),
				InitCommand = function(self) self:zoom(1.1) end
			},
			LoadFont("Common Normal")..{
				Text = ScreenString("YesInfo"),
				InitCommand = function(self) self:y(32) end
			}
		}

		choices_af[#choices_af+1] = Def.ActorFrame{
			InitCommand = function(self)
				self:x(_screen.cx + 80):zoom(_zoom.inactive)
				choice_actors[2] = self
			end,
			LoadFont("Common Bold")..{
				Text = THEME:GetString("ScreenPromptToResetPreferencesToStock", "No"),
				InitCommand = function(self) self:zoom(1.1) end
			},
			LoadFont("Common Normal")..{
				Text = ScreenString("NoInfo"),
				InitCommand = function(self) self:y(32) end
			}
		}

		content_af[#content_af+1] = choices_af
		return content_af
	end
})

local t = Def.ActorFrame{
	OnCommand = function(self)
		promptModal:Open()
	end,
	promptModal
}

return t
