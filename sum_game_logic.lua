-- sumpuzzle.koplugin/game_logic.lua
-- Sum Puzzle game logic - select numbers that sum to target
local logger = require("logger")
local GridGame = require("kopuzzle/components/grid/grid_game")
local CageGenerator = require("cages_generator")
local _ = require("gettext")

local defaultGridSize = 5
local defaultDensity = 10
local defaultCages = 5

local SumPuzzle = GridGame:extend()

function SumPuzzle:new()
    local game = GridGame.new(self)
    game.state = true
    game.title = _("Sum Puzzle")
    
    --GRIDS
    game.state_grid = {}
    game.number_grid = {}
    game.cage_grid = {}
    game.cage_label_grid = {}
    game.hint_grid = {}

    --TARGETS
    game.cage_targets = {}
    game.row_targets = {}
    game.col_targets = {}

    game.hints = 3
    return game
end

function SumPuzzle:initialize(config)
    config = config or {}

    self.rows = config.rows or defaultGridSize
    self.cols = config.cols or defaultGridSize

    self.cage_grid = {}
    self.cage_targets  = {}

    self.number_grid    = self:createEmptyGrid(self.rows, self.cols, 0)
    self.hint_grid      = self:createEmptyGrid(self.rows, self.cols, 0)
    self.selection_grid     = self:createEmptyGrid(self.rows, self.cols, 0)
    self.cage_label_grid = self:createEmptyGrid(self.rows, self.cols, -1)
    
    if config.cages then
        self.cage_grid = self:createEmptyGrid(self.rows, self.cols, 0)
        for i = 1, config.cages or defaultCages do
            self.cage_targets[i] = 0
        end
    end
    
    for i = 1, self.cols do 
        self.row_targets[i] = 0
        self.col_targets[i] = 0
    end

    self.hints = 3
end

function SumPuzzle:resetState()
    self.state = true
    self.hints = 3
    for r = 1, self.rows do
        for c = 1, self.cols do
            self.selection_grid[r][c] = 0
        end
    end
end

function SumPuzzle:toggleCell(row, col, cellState)
    cellState = cellState or nil

    if row < 1 or row > self.rows or col < 1 or col > self.cols then
        return false
    end

    -- SET CELL SELECTION STATE
    if cellState then
        self.selection_grid[row][col] = cellState
        return true
    end

    -- CYCLE CELL SELECTION STATE
    if self.selection_grid[row][col] == 0 then 
        self.selection_grid[row][col] = 1
    elseif self.selection_grid[row][col] == 1 then
        self.selection_grid[row][col] = 2
    elseif self.selection_grid[row][col] == 2 then
        self.selection_grid[row][col] = 0 
    end

    return true
end

function SumPuzzle:getCageNumber(row, col)
    if self.cage_grid[row] == nil then
        return 0
    end
    
    return self.cage_grid[row][col]
end

function SumPuzzle:getCellState(row, col)
    if self.selection_grid[row][col] then 
        return self.selection_grid[row][col]
    end
    return false
end

function SumPuzzle:getCellNumber(row, col)
    return self.number_grid[row][col]
end

function SumPuzzle:consumeHint()
    if self.hints > 0 then
        self.hints = self.hints - 1
        return true
    end
    return false
end


function SumPuzzle:getHintNumber(row, col)
    return self.hint_grid[row][col]
end


function SumPuzzle:getRowSum(row, selectedOnly)
    if selectedOnly == nil then selectedOnly = true end
    local sum = 0
    for col = 1, self.cols do
        if not selectedOnly or self.selection_grid[row][col] == 1 then
            sum = sum + self.number_grid[row][col]
        end
    end
    return sum
end

function SumPuzzle:getColSum(col, selectedOnly)
    if selectedOnly == nil then selectedOnly = true end
    local sum = 0
    for row = 1, self.rows do
        if not selectedOnly or self.selection_grid[row][col] == 1 then
            sum = sum + self.number_grid[row][col]
        end
    end
    return sum
end

function SumPuzzle:checkRow(row)
    local sum = self:getRowSum(row)
    local target = self.row_targets[row]
    
    if sum == target then
        return true, "Correct"
    elseif sum > target then
        return false, "Too High"
    else
        return false, "Too Low"
    end
end

function SumPuzzle:checkCol(col)
    local sum = self:getColSum(col)
    local target = self.col_targets[col]
    
    if sum == target then
        return true, "Correct"
    elseif sum > target then
        return false, "Too High"
    else
        return false, "Too Low"
    end
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
        self:toggleCell(move.row, move.col, move.cellState)
        return true
    elseif move.action == "submit" then
        local ok, status = self:checkWinCondition()
        return ok, status
    end
    
    return false, _("Unknown action")
end

function SumPuzzle:checkWinCondition()
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

    self.state = false 
    return true, _("Puzzle complete! All sums match!")
end

function SumPuzzle:lowRandom(min, max, samples)
    min = min or 1
    max = max or 9
    samples = samples or 3

    local smallest = max -- Initialize with the highest possible value

    for i = 1, samples do
        local rand_num = math.random(min, max)
        if rand_num < smallest then
            smallest = rand_num
        end
    end

    return smallest
end

function SumPuzzle:generatePuzzle(params)
    params = params or {}

    if params.density == nil then
        params.density = defaultDensity
    end

    --ALL GRIDS RESET
    if params.cages then
        self.cage_grid = CageGenerator:generateCages(self.rows, self.cols, params.cages)
        for i = 1, params.cages or defaultCages do
            self.cage_targets[i] = 0
        end
    else
        self.cage_grid = {}
        self.cage_targets  = {}
    end

    for c = 1, self.cols do 
        for r = 1, self.rows do 
            self.selection_grid[r][c] = 0
            self.number_grid[r][c] = 0
            self.hint_grid[r][c] = 0
        end
    end

    -- ENSURE VALID DENSITY
    if params.density < self.rows then
        params.density = self.rows
    end

    local max_cells = self.rows * self.cols
    local num_to_populate = math.min(params.density, max_cells)

    local all_coords = {}
    for r = 1, self.rows do
        for c = 1, self.cols do
            table.insert(all_coords, {r, c})
        end
    end

    -- SELECTED COORDINATES TO POPULATE
    local selected_coords = {}

    -- ENSURE AT LEAST ONE SELECTION PER ROW
    for i = 1, self.rows do
        local rand_index = math.random(1, self.cols)
        table.insert(selected_coords, {i, rand_index})
    end

    local remaining_cells = num_to_populate - self.rows

    -- POPULATE REMAINING CELLS RANDOMLY
    if remaining_cells > 0 then
        -- Create list of all coordinates not yet selected
        local available_coords = {}
        for r = 1, self.rows do
            for c = 1, self.cols do
                local already_selected = false
                for _, coord in ipairs(selected_coords) do
                    if coord[1] == r and coord[2] == c then
                        already_selected = true
                        break
                    end
                end
                if not already_selected then
                    table.insert(available_coords, {r, c})
                end
            end
        end
        
        -- Randomly select from remaining cells using Fisher-Yates shuffle
        for i = 1, math.min(remaining_cells, #available_coords) do
            local rand_index = math.random(i, #available_coords)
            available_coords[i], available_coords[rand_index] = 
                available_coords[rand_index], available_coords[i]
            table.insert(selected_coords, available_coords[i])
        end
    end

    -- ASSIGN NUMBERS TO SELECTED COORDINATES AT LOW RANDOM
    for _, coord in ipairs(selected_coords) do
        local r = coord[1]
        local c = coord[2]

        self.number_grid[r][c] = self:lowRandom(1, 9, 3)
    end

    -- GET TARGETS
    for r = 1, self.rows do
        self.row_targets[r] = self:getRowSum(r, false)
    end

    for c = 1, self.cols do
        self.col_targets[c] = self:getColSum(c, false)
    end

    for r = 1, self.rows do
        for c = 1, self.cols do
            self.hint_grid[r][c] = self.number_grid[r][c]

            if params.cages then
                self.cage_targets[self.cage_grid[r][c]] = 
                (self.cage_targets[self.cage_grid[r][c]] or 0) + self.number_grid[r][c]
            end
        end
    end

    -- LABEL
    if params.cages then
        local visited = {}
        for i = 1, params.cages do
            visited[i] = false
        end

        for r = 1, self.rows do
            for c = 1, self.cols do
                if not visited[self.cage_grid[r][c]] then
                    self.cage_label_grid[r][c] = self.cage_targets[self.cage_grid[r][c]]
                    visited[self.cage_grid[r][c]] = true
                end
            end
        end
    end

    -- POPULATE THE REST OF THE GRID WITH RANDOM NUMBERS
    for r = 1, self.rows do
        for c = 1, self.cols do
            if self.number_grid[r][c] == 0 then
                self.number_grid[r][c] = math.random(1, 9)
            end
        end
    end

    self:resetState()
end

function SumPuzzle:serialize()
    return {
        rows = self.rows,
        cols = self.cols,
        hints = self.hints,
        number_grid = self:copyGrid(self.number_grid),
        state_grid = self:copyGrid(self.selection_grid),
        row_targets = self:copyList(self.row_targets),
        hint_grid = self:copyGrid(self.hint_grid),
        col_targets = self:copyList(self.col_targets),
        title = self.title,
        cage_grid = self:copyGrid(self.cage_grid),
        cage_targets = self:copyList(self.cage_targets),
        cage_label_grid = self:copyGrid(self.cage_label_grid),
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
    
    self.rows = data.rows
    self.cols = data.cols
    self.hints = data.hints or 3
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
        self.selection_grid = state_grid
    else
        self.selection_grid = self:createEmptyGrid(self.rows, self.cols, 0)
    end

    local hint_grid = self:validateGrid(data.hint_grid, self.rows, self.cols)
    if hint_grid then
        self.hint_grid = hint_grid
    else
        self.hint_grid = self:createEmptyGrid(self.rows, self.cols, 0)
    end

    local cage_grid = self:validateGrid(data.cage_grid, self.rows, self.cols)
    if cage_grid then
        self.cage_grid = cage_grid
    else
        self.cage_grid = self:createEmptyGrid(self.rows, self.cols, 0)
    end

    local cage_label_grid = self:validateGrid(data.cage_label_grid, self.rows, self.cols)
    if cage_grid then
        self.cage_label_grid = cage_label_grid
    else
        self.cage_label_grid = self:createEmptyGrid(self.rows, self.cols, -1)
    end
    
    self.row_targets = data.row_targets or {}
    self.col_targets = data.col_targets or {}
    self.cage_targets = data.cage_targets or {}
    
    return true
end

return SumPuzzle