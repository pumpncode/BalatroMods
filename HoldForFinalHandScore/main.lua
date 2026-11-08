-- Hold For Final Hand Score
-- Original mod by Wiwiweb. Updated for current Steamodded and Lovely.
--
-- Two pauses are added to the scoring animation:
--   1. After the final Chip X Mult is on screen (after any deck effect such as
--      Plasma Deck's balancing has been shown), before it turns into the hand score.
--   2. After the hand score is shown, before it is added to the round score.
--      This waits for the chip flames to die down, with a minimum and a maximum.
--
-- All times are affected by the Game Speed setting (1s at 2x speed lasts 0.5s).

local mod = SMODS.current_mod
local config = mod.config

-- Safe defaults in case an older config.lua is missing a key.
local defaults = {
  final_mult_enabled = true,
  final_mult_seconds = 1.5,
  hand_total_enabled = true,
  hand_total_min_seconds = 1.0,
  hand_total_max_seconds = 6.0,
}
for k, v in pairs(defaults) do
  if config[k] == nil then config[k] = v end
end

-- LuaJIT (Lua 5.1) has no table.pack, so keep every return value by hand.
local function pack(...)
  return { n = select('#', ...), ... }
end

local function flames_still_burning()
  local flames = G.ARGS and G.ARGS.chip_flames
  local intensity = flames and flames.real_intensity
  -- A missing or NaN intensity (for example from a naneinf score) must never block the queue.
  if type(intensity) ~= 'number' or intensity ~= intensity then return false end
  return intensity >= 0.5
end

-- Pause 1: final chips X mult.
-- Hooked on the deck's final_scoring_step so it is queued after the final joker effects
-- and after Plasma Deck's own events. The original deck result is passed through untouched.
local trigger_effect_ref = Back.trigger_effect
function Back:trigger_effect(args)
  local ret = pack(trigger_effect_ref(self, args))
  if config.final_mult_enabled and type(args) == 'table' and args.context == 'final_scoring_step' then
    G.E_MANAGER:add_event(Event({
      trigger = 'before',
      delay = config.final_mult_seconds,
      func = function()
        G.ACC = 0 -- Reset game speed acceleration
        return true
      end
    }))
  end
  return unpack(ret, 1, ret.n)
end

-- Pause 2: final hand score.
-- Queued right after the game queues the chip total display, before the round score is added.
local check_and_set_high_score_ref = check_and_set_high_score
function check_and_set_high_score(score, amt)
  if config.hand_total_enabled and score == 'hand' then
    local started
    G.E_MANAGER:add_event(Event({
      trigger = 'before',
      delay = config.hand_total_min_seconds, -- minimum hold
      func = function()
        G.ACC = 0
        started = started or G.TIMERS.REAL
        -- Never wait forever, whatever the flames are doing.
        if G.TIMERS.REAL - started >= config.hand_total_max_seconds then return true end
        return not flames_still_burning()
      end
    }))
  end
  return check_and_set_high_score_ref(score, amt)
end

-- Settings tab
mod.config_tab = function()
  local function slider(label, key, min, max)
    return create_slider({
      label = label,
      w = 4,
      h = 0.4,
      text_scale = 0.3,
      label_scale = 0.35,
      ref_table = config,
      ref_value = key,
      min = min,
      max = max,
      decimal_places = 1,
    })
  end
  return {
    n = G.UIT.ROOT,
    config = { align = 'cm', padding = 0.1, colour = G.C.CLEAR },
    nodes = {
      {
        n = G.UIT.C,
        config = { align = 'tm', padding = 0.1 },
        nodes = {
          create_toggle({ label = 'Pause on final Chips X Mult', ref_table = config, ref_value = 'final_mult_enabled' }),
          slider('Seconds', 'final_mult_seconds', 0, 4),
          create_toggle({ label = 'Pause on final hand score', ref_table = config, ref_value = 'hand_total_enabled' }),
          slider('Minimum seconds', 'hand_total_min_seconds', 0, 4),
          slider('Maximum seconds (flames wait)', 'hand_total_max_seconds', 1, 12),
        },
      },
    },
  }
end
