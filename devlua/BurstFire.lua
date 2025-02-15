--[[
	Checks the following values in the weapon tweak data entry for custom settings (treated as defaults, can be overriden with the menu if enabled)
	
	BURST_FIRE_FORCE_SUPPORT - (Experimental) Forces burst support in weapons that doesn't have single fire. May cause animation/sound glitches (default false)
	BURST_FIRE_ADAPTIVE - If explicitly set to false, disables the adaptive burst size and forces the weapon to fire the entire burst (defailt true)
	BURST_SIZE - Number of rounds fired per urst (max, may be lower if adaptive burst size is used) (default 3)
	BURST_FIRE_RATE_MUL - Fire rate multiplier when a weapon is fired in burst mode, (default 1, standard fire rate)
	BURST_FIRE_DELAY_RECOIL - Delays recoil until after the burst has ended. Recommended only for short, high rate burst weapons (default false)
]]

if not VHUDPlus:getSetting({"EQUIPMENT", "ENABLE_BURSTMODE"}, true) then
	return
end

if RequiredScript == "lib/units/weapons/newraycastweaponbase" then
	
	local _update_stats_values_original = NewRaycastWeaponBase._update_stats_values
	local fire_rate_multiplier_original = NewRaycastWeaponBase.fire_rate_multiplier
	local recoil_multiplier_original = NewRaycastWeaponBase.recoil_multiplier
	local on_enabled_original = NewRaycastWeaponBase.on_enabled
	local on_disabled_original = NewRaycastWeaponBase.on_disabled
	local start_reload_original = NewRaycastWeaponBase.start_reload
	local fire_original = NewRaycastWeaponBase.fire
	local toggle_firemode_original = NewRaycastWeaponBase.toggle_firemode
	
	local IDSTRING_SINGLE = Idstring("single")
	local IDSTRING_AUTO = Idstring("auto")
	local IDSTRING_BURST = Idstring("burst")
	local IDSTRING_VOLLEY = Idstring("volley")
	
	function NewRaycastWeaponBase:_update_stats_values(...)
		_update_stats_values_original(self, ...)
		
		if not self:is_npc() then
			self:_init_custom_firemodes()
		end
	end
	
	function NewRaycastWeaponBase:fire_rate_multiplier(...)
		local mult = self:in_burst_mode() and self._burst.fire_rate_multiplier or 1
		return fire_rate_multiplier_original(self, ...) * mult
	end
	
	function NewRaycastWeaponBase:recoil_multiplier(...)
		local mult = self:in_burst_mode() and self:burst_rounds_remaining() and self._burst.delayed_recoil and 0 or 1
		return recoil_multiplier_original(self, ...) * mult
	end
	
	function NewRaycastWeaponBase:on_enabled(...)
		self:cancel_burst(true)
		return on_enabled_original(self, ...)
	end
	
	function NewRaycastWeaponBase:on_disabled(...)
		self:cancel_burst(true)
		return on_disabled_original(self, ...)
	end
	
	function NewRaycastWeaponBase:start_reload(...)
		self:cancel_burst(true)
		return start_reload_original(self, ...)
	end
	
	function NewRaycastWeaponBase:fire(...)
		local result = fire_original(self, ...)
		
		if result and self:in_burst_mode() then
			self._burst.active = true
			self._burst.fired = self._burst.fired + 1
		
			if self:clip_empty() or not self:burst_rounds_remaining() then
				self:cancel_burst(true)
			end
		end
		
		return result
	end

	--Semi-override
	function NewRaycastWeaponBase:toggle_firemode(...)
		return self._burst and not self:gadget_overrides_weapon_functions() and self:_check_toggle_custom_mode() or toggle_firemode_original(self, ...)
	end
	
	
	function NewRaycastWeaponBase:in_burst_mode()
		return self._burst and self._available_modes[self._current_mode_index].burst or false
	end
	
	function NewRaycastWeaponBase:burst_rounds_remaining()
		local remaining = self._burst and self._burst.active and (self._burst.size - self._burst.fired) or 0
		return remaining > 0 and remaining or false
	end
	
	function NewRaycastWeaponBase:cancel_burst(force)
		if self._burst and (self._burst.adaptive or force) then
			if self._burst.delayed_recoil and self._burst.fired > 0 then
				self._setup.user_unit:movement():current_state():force_recoil_kick(self, self._burst.fired)
			end
			
			self._burst.fired = 0
			self._burst.active = false
		end
	end
	
	
	function NewRaycastWeaponBase:_init_custom_firemodes()
		local supports_single = self:weapon_tweak_data().FIRE_MODE == "single" or self:can_toggle_firemode()
		local supports_auto = self:weapon_tweak_data().FIRE_MODE == "auto" or self:can_toggle_firemode()
		local supports_volley = self:weapon_tweak_data().FIRE_MODE == "volley" or self:can_toggle_firemode()
		local supports_burst = self:weapon_tweak_data().FIRE_MODE == "burst" or self:can_toggle_firemode()
	
		local has_single = supports_single and (not self._locked_fire_mode or (self._locked_fire_mode == IDSTRING_SINGLE))
		local has_auto = supports_auto and (not self._locked_fire_mode or (self._locked_fire_mode == IDSTRING_AUTO))
		local has_burst = supports_single and (not self._locked_fire_mode or (self._locked_fire_mode == IDSTRING_BURST))
		local has_volley = supports_volley and (not self._locked_fire_mode or (self._locked_fire_mode == IDSTRING_VOLLEY))
		
		self:_setup_available_fire_modes(supports_single, has_single, supports_auto, has_auto, supports_burst, has_burst, supports_volley, has_volley)
	end
	
	function NewRaycastWeaponBase:_setup_available_fire_modes(supports_single, has_single, supports_auto, has_auto, supports_burst, has_burst, supports_volley, has_volley)
		local enabled = true
		
		self._burst = nil
		self._available_modes = nil
		
		if enabled and has_burst then
			local default_to_burst = false
			local adaptive_default = false
			
			self._burst = {
				active = false,
				fired = 0,
				size = math.round(3),
				adaptive = adaptive_default,
				fire_rate_multiplier = 1,
				delayed_recoil = false,
			}
			self._available_modes = {}
			
			if has_single then
				table.insert(self._available_modes, { id = "single", id_string = IDSTRING_SINGLE, burst = false })
			end

			if has_burst and (not has_volley) then
				table.insert(self._available_modes, { id = "burst", id_string = IDSTRING_BURST, burst = true })
			end
			
			if has_auto then
				table.insert(self._available_modes, { id = "auto", id_string = IDSTRING_AUTO, burst = false })
			end

			if has_volley then
				table.insert(self._available_modes, { id = "volley", id_string = IDSTRING_VOLLEY, burst = false })
			end
			
			for i, mode in ipairs(self._available_modes) do
				if default_to_burst then
					if mode.burst then
						self._fire_mode = mode.id_string
						self._current_mode_index = i
						break
					end
				else
					if self._fire_mode == mode.id_string and not mode.burst then
						self._current_mode_index = i
						break
					end
				end
			end
			if managers.hud then
				managers.hud:recreate_weapon_firemode(HUDManager.PLAYER_PANEL)
			end
		end
	end
	
	function NewRaycastWeaponBase:_check_toggle_custom_mode()
		local old_mode, current_mode = self:_next_mode()
		
		if old_mode.burst or current_mode.burst then
			self._fire_mode = current_mode.id_string
			self._sound_fire:post_event(current_mode.id == "single" and "wp_auto_switch_off" or "wp_auto_switch_on")
			self:cancel_burst(true)
			return true
		end
	end
	
	function NewRaycastWeaponBase:_next_mode()
		local current_index = self._current_mode_index
		local current_mode = self._available_modes[current_index]
		local next_index = (current_index % #self._available_modes) + 1
		local next_mode = self._available_modes[next_index]
		
		self._current_mode_index = next_index
		
		return current_mode, next_mode
	end
	
end

if RequiredScript == "lib/units/weapons/akimboweaponbase" then

	local fire_original = AkimboWeaponBase.fire
	local fire_rate_multiplier_original = AkimboWeaponBase.fire_rate_multiplier
	local toggle_firemode_original = AkimboWeaponBase.toggle_firemode

	local IDSTRING_SINGLE = Idstring("single")
	local IDSTRING_AUTO = Idstring("auto")
	local IDSTRING_BURST = Idstring("burst")
	local IDSTRING_VOLLEY = Idstring("volley")
	
	function AkimboWeaponBase:fire(...)
		local results = fire_original(self, ...)
		
		if self:in_single_mode() then
			self._fire_callbacks = {}
		end
		
		return results
	end
	
	function AkimboWeaponBase:fire_rate_multiplier(...)
		return fire_rate_multiplier_original(self, ...) * (self:in_single_mode() and 2 or 1)
	end
	
	--Smi-override
	function AkimboWeaponBase:toggle_firemode(...)
		return self._available_modes and not self:gadget_overrides_weapon_functions() and self:_check_toggle_custom_mode() or toggle_firemode_original(self, ...)
	end
	
	
	function AkimboWeaponBase:in_single_mode()
		return self._available_modes and self._available_modes[self._current_mode_index].single and true or false
	end
	
	function AkimboWeaponBase:_setup_available_fire_modes(supports_single, has_single, supports_auto, has_auto)
		local enabled = true

		-- self._available_modes = nil
	
		if enabled and has_single then
			self._manual_fire_second_gun = self._manual_fire_second_gun or false
			
			self._available_modes = {}
			
			table.insert(self._available_modes, { id = "double", id_string = IDSTRING_SINGLE, single = false })
			
			if has_auto then
				table.insert(self._available_modes, { id = "auto", id_string = IDSTRING_AUTO, single = false })
			end
			
			table.insert(self._available_modes, { id = "single", id_string = IDSTRING_SINGLE, single = true })
			
			for i, mode in ipairs(self._available_modes) do
				if self._fire_mode == mode.id_string and mode.single == self._manual_fire_second_gun then
					self._current_mode_index = i
					break
				end
			end
			if managers.hud then
				managers.hud:recreate_weapon_firemode(HUDManager.PLAYER_PANEL)
			end
		end
	end
	
	function AkimboWeaponBase:_check_toggle_custom_mode()
		local old_mode, current_mode = self:_next_mode()
		
		if old_mode.id_string == current_mode.id_string then
			if alive(self._second_gun) then
				self._second_gun:base():_check_toggle_custom_mode()
			end
			
			return true
		end
	end
	
end

if RequiredScript == "lib/units/beings/player/states/playerstandard" then

	local update_original = PlayerStandard.update
	local _check_action_primary_attack_original = PlayerStandard._check_action_primary_attack
	local _check_action_weapon_firemode_original = PlayerStandard._check_action_weapon_firemode

	function PlayerStandard:update(t, ...)
		update_original(self, t, ...)
		self:_update_burst_fire(t)
	end
	
	function PlayerStandard:_check_action_primary_attack(t, input, ...)
		if self._trigger_down and not input.btn_primary_attack_state then
			self._equipped_unit:base():cancel_burst(false)
		end
		self._trigger_down = input.btn_primary_attack_state
		
		return _check_action_primary_attack_original(self, t, input, ...)
	end
	
	function PlayerStandard:_check_action_weapon_firemode(...)
		local wbase = self._equipped_unit:base()
		local was_custom_mode = wbase.in_burst_mode and wbase:in_burst_mode() or wbase.in_single_mode and wbase:in_single_mode()
	
		_check_action_weapon_firemode_original(self, ...)
		
		local is_custom_mode = wbase.in_burst_mode and wbase:in_burst_mode() or wbase.in_single_mode and wbase:in_single_mode()
		if was_custom_mode ~= is_custom_mode then
			if is_custom_mode then
				managers.hud:set_teammate_weapon_firemode_burst(self._unit:inventory():equipped_selection())
			else
				managers.hud:set_teammate_weapon_firemode(HUDManager.PLAYER_PANEL, self._unit:inventory():equipped_selection(), wbase:fire_mode())
			end
		end
	end
	
	function PlayerStandard:_update_burst_fire(t)
		if alive(self._equipped_unit) and self._equipped_unit:base():burst_rounds_remaining() then
			self:_check_action_primary_attack(t, { btn_primary_attack_state = true, btn_primary_attack_press = true })
		end
	end
	
	function PlayerStandard:force_recoil_kick(weap_base, manual_multiplier)
		local recoil_multiplier = (weap_base:recoil() + weap_base:recoil_addend()) * weap_base:recoil_multiplier() * (manual_multiplier or 1)
		local up, down, left, right = unpack(weap_base:weapon_tweak_data().kick[self._state_data.in_steelsight and "steelsight" or self._state_data.ducking and "crouching" or "standing"])
		self._camera_unit:base():recoil_kick(up * recoil_multiplier, down * recoil_multiplier, left * recoil_multiplier, right * recoil_multiplier)
	end

end

if RequiredScript == "lib/managers/hudmanagerpd2" then

	HUDManager._USE_BURST_MODE = true
	
	HUDManager.set_teammate_weapon_firemode_burst = HUDManager.set_teammate_weapon_firemode_burst or function(self, id)
		self._teammate_panels[HUDManager.PLAYER_PANEL]:set_weapon_firemode_burst(id)
	end

end

if RequiredScript == "lib/managers/hud/hudteammate" then
	
	--Default function for vanilla HUD. If using a custom HUD that alters fire mode HUD components, make sure to implement this function in it
	HUDTeammate.set_weapon_firemode_burst = HUDTeammate.set_weapon_firemode_burst or function(self, id)
		local is_secondary = id == 1
		local secondary_weapon_panel = self._player_panel:child("weapons_panel"):child("secondary_weapon_panel")
		local primary_weapon_panel = self._player_panel:child("weapons_panel"):child("primary_weapon_panel")
		local weapon_selection = is_secondary and secondary_weapon_panel:child("weapon_selection") or primary_weapon_panel:child("weapon_selection")
		if alive(weapon_selection) then
			local firemode_single = weapon_selection:child("firemode_single")
			local firemode_auto = weapon_selection:child("firemode_auto")
			if alive(firemode_single) and alive(firemode_auto) then
				firemode_single:show()
				firemode_auto:show()
			end
		end
	end
	
end