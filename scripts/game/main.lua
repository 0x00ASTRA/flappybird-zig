local player_x = 400
local player_y = 400
local player_scale = 0.125
local player_width = Engine.get_texture_width("test.png", player_scale)
local player_height = Engine.get_texture_height("test.png", player_scale)

-- Create the player's rectangle
local player_rect = Rect.new(player_x, player_y, player_width, player_height)

print(player_height) -- Keep this for debugging if needed
local player_speed = 20
local game_tick = 0

-- Define a static obstacle rectangle
local obstacle_x = 200
local obstacle_y = 200
local obstacle_width = 100
local obstacle_height = 150
local obstacle_rect = Rect.new(obstacle_x, obstacle_y, obstacle_width, obstacle_height)

-- Variables for collision visualization
local player_color_r = 255
local player_color_g = 255
local player_color_b = 255
local player_color_a = 255

-- The _init function is called once when the game starts
function _init()
    print("Lua: _init() called. Game is starting up!")
end

-- The _update function is called every frame for game logic
function _update()
    game_tick = game_tick + 1

    -- Reset player color to white at the start of each frame
    player_color_r = 255
    player_color_g = 255
    player_color_b = 255
    player_color_a = 255

    -- Input handling for player movement
    if Input.is_key_pressed("left_shift") then
        player_speed = math.min(player_speed + 1, 500)
        Engine.log("Speed increased to: " .. player_speed)
    end

    if Input.is_key_pressed("left_control") then
        player_speed = math.max(player_speed - 1, 0)
        Engine.log("Speed decreased to: " .. player_speed)
    end

    if Input.is_key_down("s") then
        player_y = player_y + player_speed
    end

    if Input.is_key_down("w") then
        player_y = player_y - player_speed
    end

    if Input.is_key_down("d") then
        player_x = player_x + player_speed
    end

    if Input.is_key_down("a") then
        player_x = player_x - player_speed
    end

    -- Update the player_rect's position
    player_rect.x = player_x
    player_rect.y = player_y

    -- Check for collision between player and obstacle
    if Rect.check_collision(player_rect, obstacle_rect) then
        Engine.log("Collision detected!")
        -- Change player color to red on collision
        player_color_r = 255
        player_color_g = 0
        player_color_b = 0
    end
end

-- The _draw function is called every frame for rendering
function _draw()
    -- Draw the player texture, with color changing on collision
    Engine.draw_texture("test.png", player_x, player_y, 0.0, player_scale, player_color_r, player_color_g, player_color_b, player_color_a)

    Engine.draw_rect(obstacle_x, obstacle_y, obstacle_width, obstacle_height, 0, 0, 255, 150)
end
