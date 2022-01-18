# Prediction documentation

## Prediction Input

Determines the skillshot input needed for prediction process.  
The "[unit]" type stands for game_object or vec3 type.

* source - the unit that the skillshot will be launched from **[unit]**
* hitbox - indicates if the unit bounding radius should be included in calculations **[boolean]**
* speed - the skillshot speed in units per second **[number]**
* range - the skillshot range in units **[number]**
* delay - the skillshot initial delay in seconds **[number]**
* radius - the skillshot radius (for non-conic skillshots) **[number]**
* angle - the skillshot angle (for conic skillshots) **[number]**
* collision - determines the collision flags for the skillshot **[table]**:
  * {"minion", "ally_hero", "enemy_hero", "wind_wall", "terrain_wall"}
* type - the skillshot type: ("linear", "circular", "conic") **[string]**

## Prediction Output

Determines the final prediction output for given skillshot input and target.

* cast_pos - the skillshot cast position **[vec3]**
* pred_pos - the predicted unit position **[vec3]**
* hit_chance - the calculated skillshot hit chance **[number]**
* hit_count - the area of effect hit count **[number]**
* time_to_hit - the total skillshot arrival time **[number]**

## Hit Chance

* -2 - the unit is unpredictable or invulnerable
* -1 - the skillshot is colliding the units on path
* 0 - the predicted position is out of the skillshot range
* (0.01 - 0.99) - the solution has been found for given input
* 1 - the unit is immobile or skillshot will land for sure
* 2 - the unit is dashing or blinking

## Attack Data (Health Prediction)

* processed - indicates if sent attack has been completed **[boolean]**
* timer - the start time of launched attack **[number]**
* source - the source which has launched the attack **[game_object]**
* target - the target which is going to take a damage **[game_object]**
* windup_time - the source attack windup time **[number]**
* animation_time - the source attack animation time **[number]**
* speed - the projectile speed of sent attack **[number]**
* damage - the predicted attack damage to target **[number]**

## API

* **_calc_auto_attack_damage(game_object source, game_object unit)_ [number]**  
  Calculates the auto-attack damage to unit target and returns it (no passives included).

* **_get_aoe_prediction(prediction_input input, game_object unit)_ [prediction_output]**  
  Returns the area of effect prediction output for given input and unit.

* **_get_aoe_position(prediction_input input, table<unit> units, unit star = nil)_ [{position, hit_count}]**  
  Calculates the area of effect position for given input and table of targets.  
  You can optionally set the "star target" which is **always included** in output within skillshot range.

* **_get_collision(prediction_input input, vec3 end_pos, game_object exclude = nil)_ [table<unit>]**  
  Returns the list of the units that the skillshot will hit before reaching the set end position.

* **_get_fast_prediction(game_object/vec3 source, game_object unit, number speed, number delay)_ [vec3]**  
  Returns the predicted unit position for given projectile speed and delay.

* **_get_health_prediction(game_object unit, number delta, number delay = 0)_ [number]**  
  Returns the unit health after a set time. Health prediction only supports enemy wave minions.

* **_get_lane_clear_health_prediction(game_object unit, number delta)_ [number]**  
  Returns the unit health after a set time assuming that the past auto-attacks are periodic.

* **_get_position_after(game_object unit, number delta, boolean skip_latency = false)_ [vec3]**  
  Returns the position where the unit will be after a set time. When the **skip_latency**  
  parameter is not used, it will increase the set time due to the latency and server tick.

* **_get_prediction(prediction_input input, game_object unit)_ [prediction_output]**  
  Returns the general prediction output for given input and unit.

* **_get_hero_aggro(game_object unit)_ [table<active_data>]**  
  Returns the table including data of active attacks launched by ally champions on given unit.

* **_get_immobile_duration(game_object unit)_ [number]**  
  Returns the duration of the unit's immobilility.

* **_get_invisible_duration(game_object unit)_ [number]**  
  Returns the duration of the unit's invisibility or fog of war state.

* **_get_invulnerable_duration(game_object unit)_ [number]**  
  Returns the duration of the unit's invulnerability (supports champions only)

* **_get_minion_aggro(game_object unit)_ [table<active_data>]**  
  Returns the table including data of active attacks launched by ally minions on given unit.

* **_get_movement_speed(game_object unit)_ [number]**  
  Returns the unit's movement speed (also supports dashing speed).

* **_get_turret_aggro(game_object unit)_ [table<active_data>]**  
  Returns the table including data of active attacks launched by ally turrets on given unit.

* **_get_waypoints(game_object unit)_ [table<vec3>]**  
  Returns the current moving path of the unit (also works in fog of war state).

* **_is_loaded()_**  
  Indicates if prediction library has been loaded successfully.

* **_set_collision_buffer(number buffer)_**  
  Sets the additional collision buffer for **get_collision** calculations.

* **_set_internal_delay(number delay)_**  
  Sets the internal delay for prediction calculations.

## Example (Ezreal Q)

```lua
local myHero = game.local_player
local pred = _G.Prediction

local input = {
    source = myHero,
    speed = 2000, range = 1150,
    delay = 0.25, radius = 60,
    collision = {"minion", "wind_wall"},
    type = "linear", hitbox = true
}

local function on_tick()
    if not spellbook:can_cast(SLOT_Q) or
        not pred:is_loaded() then return end
    for _, unit in ipairs(game.players) do
        if unit.is_valid and unit.is_enemy then
            local output = pred:get_prediction(input, unit)
            local inv = pred:get_invisible_duration(unit)
            if output.hit_chance > 0.5 and inv < 0.125 then
                local p = output.cast_pos
                spellbook:cast_spell(SLOT_Q, 0.25, p.x, p.y, p.z)
            end
        end
    end
end

client:set_event_callback("on_tick", on_tick)
```
