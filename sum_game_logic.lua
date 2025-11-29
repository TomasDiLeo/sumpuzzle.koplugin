-- sumpuzzle.koplugin/game_logic.lua
-- Sum Puzzle game logic - select numbers that sum to target

local logger = require("logger")
local GridGame = require("kopuzzle/components/grid/grid_game")
local _ = require("gettext")

local gridSize = 5

local SumPuzzle = GridGame:extend()

function SumPuzzle:new()
    local game = GridGame.new(self)
    game.state = true
    game.title = _("Sum Puzzle")
    
    game.state_grid = {}
    game.numer_grid = {}
    game.hint_grid = {}
    game.row_targets = {}
    game.col_targets = {}

    return game
end

function SumPuzzle:initialize(config)
    config = config or {}
    self.rows = gridSize
    self.cols = gridSize

    self.number_grid = self:createEmptyGrid(self.rows, self.cols, 0)
    self.hint_grid = self:createEmptyGrid(self.rows, self.cols, 0)
    self.state_grid = self:createEmptyGrid(self.rows, self.cols, 0)

    for i = 1, gridSize do 
        self.row_targets[i] = 0
        self.col_targets[i] = 0
    end
end

function SumPuzzle:resetState()
    self.state = true

    for r = 1, self.rows do
        for c = 1, self.cols do
            self.state_grid[r][c] = 0
        end
    end
end

function SumPuzzle:toggleCell(row, col, state)
    state = state or nil
    if row < 1 or row > self.rows or col < 1 or col > self.cols then
        return false
    end

    if state then
        self.state_grid[row][col] = state
        return true
    end

    if self.state_grid[row][col] == 0 then 
        self.state_grid[row][col] = 1
    elseif self.state_grid[row][col] == 1 then
        self.state_grid[row][col] = 2
    elseif self.state_grid[row][col] == 2 then
        self.state_grid[row][col] = 0 
    end

    return true
end

function SumPuzzle:getCellState(row, col)
    if self.state_grid[row][col] then 
        return self.state_grid[row][col]
    end

    return false
end

function SumPuzzle:getCellNumber(row, col)
    return self.number_grid[row][col]
end

function SumPuzzle:getHintNumber(row, col)
    return self.hint_grid[row][col]
end


function SumPuzzle:getRowSum(row)
    local sum = 0
    for col = 1, self.cols do
        if self.state_grid[row][col] == 1 then
            sum = sum + self.number_grid[row][col]
        end
    end
    return sum
end

function SumPuzzle:getColSum(col)
    local sum = 0
    for row = 1, self.rows do
        if self.state_grid[row][col] == 1 then
            sum = sum + self.number_grid[row][col]
        end
    end
    return sum
end

function SumPuzzle:checkRow(row)
    local sum = self:getRowSum(row)
    local target = self.row_targets[row]
    
    if sum == target then
        return true, "correct"
    elseif sum > target then
        return false, "too_high"
    else
        return false, "too_low"
    end
end

function SumPuzzle:checkCol(col)
    local sum = self:getColSum(col)
    local target = self.col_targets[col]
    
    if sum == target then
        return true, "correct"
    elseif sum > target then
        return false, "too_high"
    else
        return false, "too_low"
    end
end

function SumPuzzle:submitAnswer()

    for row = 1, self.rows do
        local ok, status = self:checkRow(row)
        if not ok then
            return false, status
        end
    end

    for col = 1, self.cols do
        local ok, status = self:checkCol(col)
        if not ok then
            return false, status
        end
    end
    
    return true, _("Correct!")
end

function SumPuzzle:validateMove(move)
    if not move then
        return false, _("Invalid move")
    end
    return true
end

function SumPuzzle:applyMove(move)
    local ok, err = self:validateMove(move)
    if not ok then
        return false, err
    end

    if move.action == "toggle" then
        self:toggleCell(move.row, move.col)
        return true
    elseif move.action == "submit" then
        local ok, status = self:checkWinCondition()
        return ok, status
    end
    
    return false, _("Unknown action")
end

function SumPuzzle:checkWinCondition()
    local ok, status = self:submitAnswer()
    if ok then self.state = false end
    return ok, status
end

function SumPuzzle:lowRandom()
    local min = 1
    local max = 9
    local num_samples = 3 -- Increase this number for a stronger bias

    local smallest = max -- Initialize with the highest possible value

    for i = 1, num_samples do
        local rand_num = math.random(min, max)
        if rand_num < smallest then
            smallest = rand_num
        end
    end

    return smallest
end

function SumPuzzle:generatePuzzle(params)
    params = {}

    self.state_grid = self:createEmptyGrid(self.rows, self.cols, 1)
    self.number_grid = self:createEmptyGrid(self.rows, self.cols, 0)

    local density = 15

    local max_cells = self.rows * self.cols
    local num_to_populate = math.min(density, max_cells)

    local all_coords = {}
    for r = 1, self.rows do
        for c = 1, self.cols do
            -- Store coordinates as a table {r, c}
            table.insert(all_coords, {r, c})
        end
    end

    local selected_coords = {}
    for i = 1, num_to_populate do
        local rand_index = math.random(i, max_cells)
        all_coords[i], all_coords[rand_index] = all_coords[rand_index], all_coords[i]
        table.insert(selected_coords, all_coords[i])
    end

    for _, coord in ipairs(selected_coords) do
        local r = coord[1]
        local c = coord[2]

        self.number_grid[r][c] = self.lowRandom(self)
    end

    for r = 1, self.rows do
        self.row_targets[r] = self:getRowSum(r)
    end

    for c = 1, self.cols do
        self.col_targets[c] = self:getColSum(c)
    end

    for r = 1, self.rows do
        for c = 1, self.cols do
            self.hint_grid[r][c] = self.number_grid[r][c]
        end
    end

    for r = 1, self.rows do
        for c = 1, self.cols do
            if self.number_grid[r][c] == 0 then
                self.number_grid[r][c] = self.lowRandom(self)
            end
        end
    end
    self:resetState()
end

function SumPuzzle:serialize()
    return {
        rows = self.rows,
        cols = self.cols,
        number_grid = self:copyGrid(self.number_grid),
        state_grid = self:copyGrid(self.state_grid),
        row_targets = self:copyList(self.row_targets),
        hint_grid = self:copyGrid(self.hint_grid),
        col_targets = self:copyList(self.col_targets),
        title = self.title
    }
end

function SumPuzzle:copyList(list)
    local copy = {}
    for i, v in ipairs(list) do
        copy[i] = v
    end
    return copy
end

function SumPuzzle:deserialize(data)
    if type(data) ~= "table" then
        return false
    end
    
    self.rows = data.rows or 5
    self.cols = data.cols or 5
    self.title = data.title or _("Sum Puzzle")
    
    local numbers = self:validateGrid(data.number_grid, self.rows, self.cols)
    if numbers then
        self.number_grid = numbers
    else
        self:generatePuzzle()
        return true
    end
    
    local state_grid = self:validateGrid(data.state_grid, self.rows, self.cols)
    if state_grid then
        self.state_grid = state_grid
    else
        self.state_grid = self:createEmptyGrid(self.rows, self.cols, 0)
    end

    local hint_grid = self:validateGrid(data.hint_grid, self.rows, self.cols)
    if hint_grid then
        self.hint_grid = hint_grid
    else
        self.hint_grid = self.createEmptyGrid(self.rows, self.cols, 0)
    end
    
    self.row_targets = data.row_targets or {}
    self.col_targets = data.col_targets or {}
    
    return true
end

return SumPuzzle