local player_x = 400
local player_y = 400
local player_scale = 0.25
local player_width = Engine.get_texture_width("test.png", player_scale)
local player_height = Engine.get_texture_height("test.png", player_scale)
print(player_height)
local player_speed = 20
local game_tick = 0

-- The _init function is called once when the game starts
function _init()
    print("Lua: _init() called. Game is starting up!")
end

-- The _update function is called every frame for game logic
function _update()
    game_tick = game_tick + 1

    if Engine.is_key_pressed("left_shift") then
        player_speed = math.min(player_speed + 1, 500)
        Engine.log("Speed increased to: " .. player_speed)
    end

    if Engine.is_key_pressed("left_control") then
        player_speed = math.max(player_speed - 1, 0)
        Engine.log("Speed decreased to: " .. player_speed)
    end

    if Engine.is_key_down("s") then
        player_y = math.min(player_y + player_speed, 800 - (player_height / 2))
    end

    if Engine.is_key_down("w") then
        player_y = math.max(player_y - player_speed, player_height / 2)
    end

    if Engine.is_key_down("d") then
        player_x = math.min(player_x + player_speed, 800 - (player_width / 2))
    end

    if Engine.is_key_down("a") then
        player_x = math.max(player_x - player_speed, player_width / 2)
    end
end

-- The _draw function is called every frame for rendering
function _draw()
    Engine.draw_texture("test.png", player_x, player_y, 0.0, player_scale, 255, 255, 255, 255)
    -- Engine.draw_circle(player_x, player_y, 30.0, 255, 0, 0, heightRed circle

end
