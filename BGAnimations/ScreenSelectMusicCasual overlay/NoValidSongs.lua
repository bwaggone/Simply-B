local noSongsModal = SL.Overlay.Create({
	Name = "NoValidSongsModal",
	Layout = "FullScreen",
	Backdrop = { color = Color.Black, alpha = 0.6 },

	OnInput = function(self, event)
		if event.type == "InputEventType_FirstPress" and event.GameButton == "Start" then
			self:Close("confirm")
			local topscreen = SCREENMAN:GetTopScreen()
			if topscreen then
				topscreen:SetNextScreenName("ScreenGameOver"):StartTransitioningScreen("SM_GoToNextScreen")
			end
		end
	end,

	Content = function(self)
		return Def.ActorFrame{
			LoadActor(THEME:GetPathB("ScreenSelectMusicCasual", "overlay/Header.lua"), { h = 60 }),

			Def.BitmapText{
				Font = "Common Normal",
				Text = ScreenString("NoValidSongs"),
				InitCommand = function(self)
					self:Center():zoom(1.1):_wrapwidthpixels(320)
				end
			}
		}
	end
})

local af = Def.ActorFrame{
	OnCommand = function(self)
		noSongsModal:Open()
	end,
	noSongsModal
}

return af
