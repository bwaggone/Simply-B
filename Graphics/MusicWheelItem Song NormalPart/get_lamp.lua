local args = {...}
local pn = args[1]

local IsUltraWide = (GetScreenAspectRatio() > 21/9)

local function GetLamp(song)
    local best_lamp = 6

    if song then
        local profile = PROFILEMAN:GetProfile(pn)
        local diff = GAMESTATE:GetCurrentSteps(pn):GetDifficulty()
        local st = GAMESTATE:GetCurrentStyle():GetStepsType()
        local steps = song:GetOneSteps(st, diff)
        if steps then
            high_score_list = profile:GetHighScoreListIfExists(song, steps)
            
            -- Unplayed song (or played, but quit out)
            if high_score_list == nil then
                return 6
            end
            
            for score in ivalues(high_score_list:GetHighScores()) do
                if score then

                    -- Misses are slightly more complicated to check
                    local misses = score:GetTapNoteScore("TapNoteScore_Miss") +
                                   score:GetTapNoteScore("TapNoteScore_CheckpointMiss") +
                                   score:GetTapNoteScore("TapNoteScore_HitMine") +
                                   score:GetHoldNoteScore("HoldNoteScore_LetGo")

                    local note_counts = {
                        misses,
                        score:GetTapNoteScore("TapNoteScore_W5"),
                        score:GetTapNoteScore("TapNoteScore_W4"),
                        score:GetTapNoteScore("TapNoteScore_W3"),
                        score:GetTapNoteScore("TapNoteScore_W2"),
                        score:GetTapNoteScore("TapNoteScore_W1")
                    }
                

                    current_lamp = 6
                    -- 6 is not an fc, 5 is no misses, 4 is a good fc, 3 great fc, 2 pfc, 1 mfc

                    for i, v in ipairs(note_counts) do
                        if v == 0 then
                            current_lamp = current_lamp - 1
                        else
                            break
                        end
                    end
                    if current_lamp < best_lamp then
                        best_lamp = current_lamp
                    end
                end
            end
        end
    end
    return best_lamp
end


return Def.ActorFrame{
	Def.Quad{
		SetCommand=function(self, param)
			self:scaletoclipped(SL_WideScale(5, 6), 31)
			
			local fc_lamp = GetLamp(param.Song)
			
			-- If unplayed or no FC, then no lamp
			if fc_lamp > 4 then
				self:visible(false)
			else
				self:visible(true)
				self:diffuseshift():effectperiod(0.8)
				self:effectcolor1(SL.JudgmentColors[SL.Global.GameMode][fc_lamp])
				self:effectcolor2(lerp_color(0.70, color("#ffffff"),
					SL.JudgmentColors[SL.Global.GameMode][fc_lamp]))
			end
			self:horizalign(right)
			
			-- Align P2's lamps to the right of the grade.
			if pn == PLAYER_2 then
				-- Ultrawide is quite hard to align, manually scale for it.
				if IsUltraWide then
					self:x(SL_WideScale(18, 30) * 2 + SL_WideScale(5, 8) + 40)
				else
					self:x(SL_WideScale(18, 30) * 2 + SL_WideScale(5, 8))
				end
			end
		end
	}
}