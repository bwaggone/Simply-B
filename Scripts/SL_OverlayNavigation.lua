---------------------------------------------------------------------------
-- SL_OverlayNavigation.lua
-- Hybrid navigation controllers for Simply Love overlays.
--
-- Provides standard cursor movement, input handling, and sound effects for:
--  - "simple_confirm": Yes / No or multi-button binary choices
--  - "list": Vertical list navigation with cursor tracking & scrolling
--  - "paged": Horizontal tab / pane switching (single or dual player)
---------------------------------------------------------------------------

SL = SL or {}
SL.Overlay = SL.Overlay or {}

local Navigation = {}

---------------------------------------------------------------------------
-- Controller: simple_confirm
---------------------------------------------------------------------------
Navigation["simple_confirm"] = {
	Init = function(instance, nav_def)
		instance._nav_state = {
			index = nav_def.default_choice or 1,
			choices = nav_def.choices or { "Yes", "No" },
		}
	end,

	HandleInput = function(instance, nav_def, event)
		if event.type ~= "InputEventType_FirstPress" then return false end

		local state = instance._nav_state
		if not state then return false end

		if event.GameButton == "MenuLeft" or event.GameButton == "MenuRight" then
			local delta = (event.GameButton == "MenuRight") and 1 or -1
			local count = #state.choices
			state.index = ((state.index - 1 + delta) % count) + 1

			instance:PlaySound("change")

			if nav_def.on_cursor_change then
				nav_def.on_cursor_change(instance, state.index, state.choices[state.index])
			end

			-- Update button actors if default buttons are in use
			local container = instance:GetActor()
			if container then
				local modal = container:GetChild("ModalContainer")
				if modal then
					modal:playcommand("ChoiceChanged", { index = state.index })
				end
			end
			return true

		elseif event.GameButton == "Start" then
			instance:PlaySound("start")
			local is_accepted = (state.index == 1)
			if nav_def.on_confirm then
				nav_def.on_confirm(instance, is_accepted, event.PlayerNumber)
			else
				instance:Close(is_accepted and "confirm" or "cancel")
			end
			return true

		elseif event.GameButton == "Back" then
			instance:PlaySound("cancel")
			if nav_def.on_confirm then
				nav_def.on_confirm(instance, false, event.PlayerNumber)
			else
				instance:Close("cancel")
			end
			return true
		end

		return false
	end
}

---------------------------------------------------------------------------
-- Controller: list
---------------------------------------------------------------------------
Navigation["list"] = {
	Init = function(instance, nav_def)
		local items = nav_def.items or {}
		if type(items) == "function" then
			items = items(instance)
		end

		instance._nav_state = {
			items = items,
			index = nav_def.default_index or 1,
			visible_rows = nav_def.visible_rows or 7,
			wrap = (nav_def.wrap ~= false),
		}
	end,

	HandleInput = function(instance, nav_def, event)
		if event.type ~= "InputEventType_FirstPress" then return false end

		local state = instance._nav_state
		if not state or #state.items == 0 then return false end

		local count = #state.items

		if event.GameButton == "MenuUp" or event.GameButton == "MenuDown" then
			local delta = (event.GameButton == "MenuDown") and 1 or -1
			local new_index = state.index + delta

			if state.wrap then
				new_index = ((new_index - 1) % count) + 1
			else
				if new_index < 1 or new_index > count then
					instance:PlaySound("invalid")
					return true
				end
			end

			state.index = new_index
			instance:PlaySound("change")

			if nav_def.on_cursor_change then
				nav_def.on_cursor_change(instance, state.index, state.items[state.index])
			end

			local container = instance:GetActor()
			if container then
				container:playcommand("ListIndexChanged", { index = state.index, item = state.items[state.index] })
			end
			return true

		elseif event.GameButton == "Start" then
			instance:PlaySound("start")
			if nav_def.on_select then
				nav_def.on_select(instance, state.index, state.items[state.index], event.PlayerNumber)
			end
			return true

		elseif event.GameButton == "Back" then
			instance:PlaySound("cancel")
			if nav_def.on_cancel then
				nav_def.on_cancel(instance, event.PlayerNumber)
			else
				instance:Close("cancel")
			end
			return true
		end

		return false
	end
}

---------------------------------------------------------------------------
-- Controller: paged (tabs / eval panes)
---------------------------------------------------------------------------
Navigation["paged"] = {
	Init = function(instance, nav_def)
		local pages = nav_def.pages or nav_def.tabs or {}
		instance._nav_state = {
			pages = pages,
			player_pages = {
				[PLAYER_1] = (type(pages) == "table" and pages[PLAYER_1]) or pages,
				[PLAYER_2] = (type(pages) == "table" and pages[PLAYER_2]) or pages,
			},
			player_indices = {
				[PLAYER_1] = nav_def.default_page or 1,
				[PLAYER_2] = nav_def.default_page or 1,
			},
			shared_index = nav_def.default_page or 1,
			wrap = (nav_def.wrap ~= false),
		}

		-- Dynamic page setters/getters (for async/server-driven overlays)
		function instance:SetPages(player_or_pages, maybe_pages)
			local state = self._nav_state
			if not state then return end

			if maybe_pages ~= nil then
				local player = player_or_pages
				local new_pages = maybe_pages or {}
				state.player_pages[player] = new_pages
				state.player_indices[player] = 1
				if nav_def.on_page_change and #new_pages > 0 then
					nav_def.on_page_change(self, 1, new_pages[1], player)
				end
			else
				local new_pages = player_or_pages or {}
				state.pages = new_pages
				state.shared_index = 1
				if nav_def.on_page_change and #new_pages > 0 then
					nav_def.on_page_change(self, 1, new_pages[1], nil)
				end
			end
		end

		function instance:GetPages(player)
			local state = self._nav_state
			if not state then return {} end
			if player and state.player_pages and state.player_pages[player] then
				return state.player_pages[player]
			end
			return state.pages or {}
		end
	end,

	HandleInput = function(instance, nav_def, event)
		if event.type ~= "InputEventType_FirstPress" then return false end

		local state = instance._nav_state
		if not state then return false end

		local pn = event.PlayerNumber or PLAYER_1
		local is_dual = (instance.Layout == "DualPane" and event.PlayerNumber ~= nil)
		local pages = is_dual and (state.player_pages[pn] or {}) or (state.pages or {})
		local count = #pages

		if event.GameButton == "MenuLeft" or event.GameButton == "MenuRight" then
			if count <= 1 then return true end

			local delta = (event.GameButton == "MenuRight") and 1 or -1

			if is_dual then
				local current = state.player_indices[pn] or 1
				local new_page = current + delta
				if state.wrap then
					new_page = ((new_page - 1) % count) + 1
				else
					if new_page < 1 or new_page > count then
						instance:PlaySound("invalid")
						return true
					end
				end
				state.player_indices[pn] = new_page
				instance:PlaySound("change")

				if nav_def.on_page_change then
					nav_def.on_page_change(instance, new_page, pages[new_page], pn)
				end

				local pane = instance.GetPane and instance:GetPane(pn)
				if pane then
					pane:playcommand("PageChanged", { page = new_page, player = pn })
				end
			else
				local current = state.shared_index
				local new_page = current + delta
				if state.wrap then
					new_page = ((new_page - 1) % count) + 1
				else
					if new_page < 1 or new_page > count then
						instance:PlaySound("invalid")
						return true
					end
				end
				state.shared_index = new_page
				instance:PlaySound("change")

				if nav_def.on_page_change then
					nav_def.on_page_change(instance, new_page, pages[new_page], pn)
				end

				local actor = instance:GetActor()
				if actor then
					actor:playcommand("PageChanged", { page = new_page })
				end
			end
			return true

		elseif event.GameButton == "Start" or event.GameButton == "Back" then
			if is_dual then
				instance:PlaySound(event.GameButton == "Start" and "start" or "cancel")
				instance:SetPlayerReady(pn, true)
			else
				instance:PlaySound(event.GameButton == "Start" and "start" or "cancel")
				instance:Close(event.GameButton == "Start" and "confirm" or "cancel")
			end
			return true
		end

		return false
	end
}

---------------------------------------------------------------------------
-- Hook Navigation Into SL.Overlay Instance
---------------------------------------------------------------------------
function SL.Overlay.AttachNavigation(instance, nav_def)
	if not (nav_def and nav_def.type) then return end

	local controller = Navigation[nav_def.type]
	if not controller then return end

	controller.Init(instance, nav_def)

	instance._HandleNavigationInput = function(self, event)
		return controller.HandleInput(self, nav_def, event)
	end
end

return Navigation
