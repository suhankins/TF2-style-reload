--Initialializing autoreload delay
Hooks:PostHook(PlayerStandard, "init", "tf2_style_reload_init", function(self, unit)
	self.autoreload_delay = 0
	self.RELOAD_INTERVAL = 0.4
end)

--Making shooting cancel reloading
Hooks:PostHook(PlayerStandard, "_update_foley", "tf2_style_reload_update_foley", function(self, t, input)
	local weap_base = self._equipped_unit:base()

	--Aiming down sights always cancels reload
	local steelsight_wanted = input.btn_steelsight_state
	if self:_is_reloading() and steelsight_wanted then
		self:_interupt_action_reload(t)
		self._ext_camera:play_redirect(self:get_animation("idle")) -- otherwise it will play the reload animation
		self:_start_action_steelsight(t)
	end

	--Atack only cancels reload if there are any bullets to shoot
	local attack_wanted = input.btn_primary_attack_state or input.btn_primary_attack_release
	if attack_wanted
	and (not weap_base:clip_empty() -- we can't fire if there's ammo to be loaded
	or weap_base:out_of_ammo()) then -- but can dry fire if there's no ammo at all
		self.autoreload_delay = t + self.RELOAD_INTERVAL

		self:_interupt_action_reload(t)
		self:_check_action_primary_attack(t, input)
	end
end)

--Making gun reload whenever it can
local original_check_action_reload = PlayerStandard._check_action_reload
function PlayerStandard:_check_action_reload(t, input)
	if not tf2_style_reload.Options:GetValue("tf2_style_reload_autoreload") then
		return original_check_action_reload(self, t, input)
	end
	local new_action = nil
	local weap_base = self._equipped_unit:base()
	local ammo_base = weap_base:ammo_base()

	local action_forbidden = self:_is_reloading() or self:_changing_weapon() or self:_is_meleeing()                  -- Default
	or self._use_item_expire_t or self:_interacting() or self:_is_throwing_projectile() or self:is_shooting_count()  -- stuff
	or self._state_data.in_steelsight or self._steelsight_wanted -- Reloading doesn't cancel aiming downsights
	or (not self.RUN_AND_RELOAD and self._running) -- Reloading doesn't interrupt running
	or self:_is_charging_weapon() -- Reloading doesn't interrupt charging weapons (like hailstorm)
	or (ammo_base:get_ammo_total() - ammo_base:get_ammo_remaining_in_clip()) == 0 -- checks if there's reserve ammo to be loaded
	or self._equipped_unit:base():clip_full() -- no point in reloading if clip is full
	or self.autoreload_delay == 0
	or t < self.autoreload_delay

	if not action_forbidden and self._equipped_unit then
		self:_start_action_reload_enter(t)

		new_action = true
	end

	return new_action
end