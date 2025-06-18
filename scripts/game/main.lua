-- Game Configuration
local SCREEN_WIDTH = 800
local SCREEN_HEIGHT = 800
local GROUND_HEIGHT = 50 -- Height of the "ground" area at the bottom

-- Player Variables
local player_x = 100 -- Fixed X position for Flappy Bird
local player_y = SCREEN_HEIGHT / 2
local player_velocity_y = 0
local player_gravity = 800 -- Pixels per second squared
local player_flap_strength = -300 -- Instant upward velocity on flap
local player_scale = 0.125
local player_texture = "bird.png" -- Make sure you have this asset
local player_width = Engine.get_texture_width(player_texture, player_scale)
local player_height = Engine.get_texture_height(player_texture, player_scale)
local player_rect = Rect.new(player_x + (player_width * 0.25), player_y + (player_height * 0.25), player_width * 0.5, player_height * 0.5)

-- Game State Variables
local game_state = 1
local score = 0

-- Pipe Variables
local pipes = {}
local pipe_gap = 120 -- Vertical gap between top and bottom pipes
local pipe_width = 70
local pipe_speed = 150 -- Pixels per second
local pipe_spawn_interval = 2 -- Seconds between pipe spawns
local time_since_last_pipe = 0
local PIPE_MIN_HEIGHT = 50
local PIPE_MAX_HEIGHT = SCREEN_HEIGHT - GROUND_HEIGHT - pipe_gap - PIPE_MIN_HEIGHT

-- Collision visualization (optional)
local player_color_r = 255
local player_color_g = 255
local player_color_b = 255
local player_color_a = 255

-- Helper function to generate a random number within a range
local function math_random_range(min, max)
    return min + math.random() * (max - min)
end

-- Function to reset game state for a new round
local function reset_game()
    player_y = SCREEN_HEIGHT / 2
    player_velocity_y = 0
    score = 0
    pipes = {}
    time_since_last_pipe = 0
    game_state = 1
    player_color_r = 255
    player_color_g = 255
    player_color_b = 255
    player_color_a = 255
    Engine.log("Game Reset!")
end

-- Function to create a new pair of pipes
local function spawn_pipe()
    -- Calculate random height for the top pipe
    local top_pipe_height = math_random_range(PIPE_MIN_HEIGHT, PIPE_MAX_HEIGHT)
    local bottom_pipe_y = top_pipe_height + pipe_gap

    local pipe_x = SCREEN_WIDTH

    -- Top pipe
    table.insert(pipes, {
        rect = Rect.new(pipe_x, 0, pipe_width, top_pipe_height),
        passed = false -- Flag to check if player passed this pipe for scoring
    })
    -- Bottom pipe
    table.insert(pipes, {
        rect = Rect.new(pipe_x, bottom_pipe_y, pipe_width, SCREEN_HEIGHT - bottom_pipe_y - GROUND_HEIGHT),
        passed = false
    })
    Engine.log("Pipe spawned!")
end


-- The _init function is called once when the game starts
function _init()
    print("Lua: _init() called. Game is starting up!")
    -- Initial pipe spawn
    spawn_pipe()
end

-- The _update function is called every frame for game logic
function _update()
    local delta_time = Engine.get_frame_time()

    if game_state == 1 then
        print("playing")
        -- Apply gravity
        player_velocity_y = player_velocity_y + player_gravity * delta_time
        player_y = player_y + player_velocity_y * delta_time

        -- Input handling for flap
        if Input.is_key_pressed("space") then
            player_velocity_y = player_flap_strength
        end

        -- Update the player's collision rectangle position
        player_rect.x = player_x + (player_width * 0.25)
        player_rect.y = player_y + (player_height * 0.25)

        -- Keep player within vertical bounds (and handle game over if goes too low)
        if player_y < -player_height / 2 then -- Allow a little off-screen top
            player_y = -player_height / 2
            player_velocity_y = 0 -- Stop upward movement
        elseif player_y + player_height > SCREEN_HEIGHT - GROUND_HEIGHT then
            player_y = SCREEN_HEIGHT - GROUND_HEIGHT - player_height
            game_state = 0
            Engine.log("Game Over! Hit ground.")
        end

        -- Pipe generation
        time_since_last_pipe = time_since_last_pipe + delta_time
        if time_since_last_pipe >= pipe_spawn_interval then
            spawn_pipe()
            time_since_last_pipe = 0
        end

        -- Update and check pipes
        for i = #pipes, 1, -1 do -- Iterate backwards to safely remove pipes
            local pipe_pair = pipes[i]
            pipe_pair.rect.x = pipe_pair.rect.x - pipe_speed * delta_time

            -- Check collision with player
            if Rect.check_collision(player_rect, pipe_pair.rect) then
                game_state = 0
                Engine.log("Game Over! Collision with pipe.")
                player_color_r = 255
                player_color_g = 0
                player_color_b = 0
            end

            -- Check for scoring
            if not pipe_pair.passed and pipe_pair.rect.x + pipe_width < player_x then
                score = score + 0.5 -- Each pipe in a pair contributes 0.5 to score
                pipe_pair.passed = true
                Engine.log("Score: " .. math.floor(score)) -- Only log integer score
            end

            -- Remove pipes that are off-screen
            if pipe_pair.rect.x + pipe_width < 0 then
                table.remove(pipes, i)
            end
        end

    elseif game_state == 0 then
        -- Allow restart on space key
        if Input.is_key_pressed("space") then
            reset_game()
        end
    end
end

-- The _draw function is called every frame for rendering
function _draw()
    Engine.draw_texture(player_texture, player_x, player_y, 0.0, player_scale, player_color_r, player_color_g, player_color_b, player_color_a)

    -- Draw pipes
    for _, pipe_pair in ipairs(pipes) do
        Engine.draw_rect(pipe_pair.rect.x, pipe_pair.rect.y, pipe_pair.rect.width, pipe_pair.rect.height, 0, 150, 0, 255) -- Green pipes
    end

    Engine.draw_rect(0, SCREEN_HEIGHT - GROUND_HEIGHT, SCREEN_WIDTH, GROUND_HEIGHT, 100, 100, 100, 255)

    -- Display score and game over message
    Engine.draw_text("Score: " .. math.floor(score), 10, 10, 20, 255, 255, 255, 255)
    if game_state == 0 then
        Engine.draw_text("GAME OVER! Press SPACE to Restart", SCREEN_WIDTH / 2 - 200, SCREEN_HEIGHT / 2, 30, 255, 0, 0, 255)
    end
end
