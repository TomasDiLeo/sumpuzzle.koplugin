-- sumpuzzle.koplugin/game_renderer.lua
-- Sum Puzzle renderer

local GridRenderer = require("kopuzzle/components/grid/grid_renderer")
local Blitbuffer = require("ffi/blitbuffer")
local RenderText = require("ui/rendertext")
local Font = require("ui/font")
local Device = require("device")
local Screen = Device.screen

local SumPuzzleRenderer = GridRenderer:extend{}

function SumPuzzleRenderer:init()
    GridRenderer.init(self)
    self.number_face = Font:getFace("cfont", math.max(24, math.floor(Screen:getWidth() / 32)))
    self.clue_face = Font:getFace("smallinfofont", math.max(20, math.floor(Screen:getWidth() / 50)))
    self.cage_face = Font:getFace("smallinfofont", math.max(17, math.floor(Screen:getWidth() / 100)))
end

function SumPuzzleRenderer:paintGrid(bb, x, y)
    local cell = self.cell_size
    local rows = self.game.rows
    local cols = self.game.cols
    local sel_row, sel_col = self.game:getSelection()
    
    -- Draw cells
    for row = 1, rows do
        for col = 1, cols do
            local cell_x = x + (col - 1) * cell
            local cell_y = y + (row - 1) * cell
            
            -- Background
            local bg_color = Blitbuffer.COLOR_WHITE
            if row == sel_row and col == sel_col then
                bg_color = Blitbuffer.COLOR_GRAY
            end
            bb:paintRect(cell_x, cell_y, cell, cell, bg_color)
            
            -- Cell content (override this method to customize)
            self:paintCell(bb, cell_x, cell_y, cell, row, col)
        end
    end
    
    for i = 0, rows do
        local y0 = y + i * cell
        local thickness = Screen:scaleBySize(0.5)
        bb:paintRect(x, y0, cols * cell, thickness, Blitbuffer.COLOR_BLACK)
    end
    
    for i = 0, cols do
        local x0 = x + i * cell
        local thickness = Screen:scaleBySize(0.5)
        bb:paintRect(x0, y, thickness, rows * cell, Blitbuffer.COLOR_BLACK)
    end
end


function SumPuzzleRenderer:updateMetrics()
    if not self.game then
        return
    end
    
    local rows = self.game.rows or 0
    local cols = self.game.cols or 0
    
    -- Reserve space for clues on left and top
    local clue_width = 60
    local clue_height = 40
    
    local target_w = (self.max_width or math.floor(Screen:getWidth() * 0.9)) - clue_width
    local target_h = (self.max_height or math.floor(Screen:getHeight() * 0.9)) - clue_height
    
    local cell_size = math.floor(math.min(
        target_w / math.max(1, cols),
        target_h / math.max(1, rows)
    ))
    
    cell_size = math.max(30, cell_size)
    
    self.cell_size = cell_size
    self.clue_width = clue_width
    self.clue_height = clue_height
    self.total_width = cols * cell_size + clue_width
    self.total_height = rows * cell_size + clue_height
    self.grid_origin_x = self.paint_rect.x + clue_width
    self.grid_origin_y = self.paint_rect.y + clue_height
    self.dimen = require("ui/geometry"):new{w = self.total_width, h = self.total_height}
end

function SumPuzzleRenderer:drawCenteredText(bb, x, y, w, h, face, text, color)
    local metrics = RenderText:sizeUtf8Text(0, h, face, text, true, false)
    local text_x = x + math.floor((w - metrics.x) / 2)
    local baseline = y + math.floor((h + metrics.y_top - metrics.y_bottom) / 2)
    RenderText:renderUtf8Text(bb, text_x, baseline, face, text, true, false, color)
end

function SumPuzzleRenderer:drawCorneredText(bb, x, y, w, h, face, text, color)
    local metrics = RenderText:sizeUtf8Text(0, h, face, text, true, false)
    
    -- Position text in top-left corner with small padding
    local padding = 4
    local text_x = x + padding
    local baseline = y + (metrics.y_top - metrics.y_bottom) + padding

    bb:paintRoundedRect(text_x, y + padding, metrics.x + padding/2, metrics.y_top - metrics.y_bottom + padding, Blitbuffer.COLOR_WHITE, 3)

    RenderText:renderUtf8Text(bb, text_x, baseline, face, text, true, false, color)
end


function SumPuzzleRenderer:paintClues(bb, x, y)
    local cell = self.cell_size
    local grid_x = x + self.clue_width
    local grid_y = y + self.clue_height
    
    -- Draw row targets (left side)
    for row = 1, self.game.rows do
        local target = self.game.row_targets[row] or 0
        local cell_y = grid_y + (row - 1) * cell
        
        local bg_color = Blitbuffer.COLOR_GRAY_E
        
        bb:paintRect(x, cell_y, self.clue_width, cell, bg_color)
        self:drawCenteredText(bb, x, cell_y, self.clue_width, cell, 
                            self.clue_face, tostring(target), Blitbuffer.COLOR_BLACK)
    end
    
    -- Draw column targets (top side)
    for col = 1, self.game.cols do
        local target = self.game.col_targets[col] or 0
        local cell_x = grid_x + (col - 1) * cell
        
        local bg_color = Blitbuffer.COLOR_GRAY_E
        
        bb:paintRect(cell_x, y, cell, self.clue_height, bg_color)
        self:drawCenteredText(bb, cell_x, y, cell, self.clue_height,
                            self.clue_face, tostring(target), Blitbuffer.COLOR_BLACK)
    end
    
    -- Draw corner (empty or lives indicator)
    bb:paintRect(x, y, self.clue_width, self.clue_height, Blitbuffer.COLOR_GRAY_D)
end

function SumPuzzleRenderer:getCageBorders(row, col)
    -- Returns which sides of this cell need cage borders
    -- Returns: top, right, bottom, left (booleans)
    local current_cage = self.game:getCageNumber(row, col)
    
    if current_cage == 0 then
        return false, false, false, false
    end
    
    local top = false
    local right = false
    local bottom = false
    local left = false
    
    -- Check top neighbor
    if row == 1 then
        top = true
    else
        local neighbor_cage = self.game:getCageNumber(row - 1, col)
        if neighbor_cage ~= current_cage then
            top = true
        end
    end
    
    -- Check right neighbor
    if col == self.game.cols then
        right = true
    else
        local neighbor_cage = self.game:getCageNumber(row, col + 1)
        if neighbor_cage ~= current_cage then
            right = true
        end
    end
    
    -- Check bottom neighbor
    if row == self.game.rows then
        bottom = true
    else
        local neighbor_cage = self.game:getCageNumber(row + 1, col)
        if neighbor_cage ~= current_cage then
            bottom = true
        end
    end
    
    -- Check left neighbor
    if col == 1 then
        left = true
    else
        local neighbor_cage = self.game:getCageNumber(row, col - 1)
        if neighbor_cage ~= current_cage then
            left = true
        end
    end
    
    return top, right, bottom, left
end

function SumPuzzleRenderer:paintCell(bb, x, y, size, row, col)
    local state = self.game:getCellState(row, col)
    local number = self.game:getCellNumber(row, col)

    local cx = x + self.cell_size/2
    local cy = y + self.cell_size/2

    local selection_size = self.cell_size/2.5
    local bg_color = Blitbuffer.COLOR_WHITE

    if self.game:getCageNumber(row, col) ~= 0 then
        bg_color = self:cageColor(self.game.cage_grid[row][col])
    end
    
    bb:paintRect(x, y, size, size, bg_color)
    
    -- Draw cage borders (inset from cell edges)
    local border_width = 4
    local border_inset = 0
    local border_color = Blitbuffer.COLOR_BLACK
    local top, right, bottom, left = self:getCageBorders(row, col)
    
    if top then
        bb:paintRect(x + border_inset, y + border_inset, size - (border_inset * 2), border_width, border_color)
    end
    if right then
        bb:paintRect(x + size - border_inset - border_width, y + border_inset, border_width, size - (border_inset * 2), border_color)
    end
    if bottom then
        bb:paintRect(x + border_inset, y + size - border_inset - border_width, size - (border_inset * 2), border_width, border_color)
    end
    if left then
        bb:paintRect(x + border_inset, y + border_inset, border_width, size - (border_inset * 2), border_color)
    end
    
    if state == 1 then
        bb:paintBorder(cx - selection_size, cy - selection_size, selection_size * 2, selection_size * 2, 4, Blitbuffer.COLOR_BLACK, 15, 1)
    end

    local text_color = Blitbuffer.COLOR_BLACK
    if state == 2 then 
        text_color = bg_color
    end

    self:drawCenteredText(bb, x, y, size, size, self.number_face, 
                         tostring(number), text_color)
    
    -- Fix: Access cage_label_grid through self.game
    if self.game.cage_label_grid[row][col] ~= -1 then
        self:drawCorneredText(bb, x, y, size, size, self.cage_face, 
        tostring(self.game.cage_label_grid[row][col]), Blitbuffer.COLOR_BLACK)
    end
end

function SumPuzzleRenderer:paintTo(bb, x, y)
    self.paint_rect = require("ui/geometry"):new{
        x = x,
        y = y,
        w = self.total_width or 10,
        h = self.total_height or 10
    }
    self:updateMetrics()
    self.paint_rect.w = self.total_width
    self.paint_rect.h = self.total_height
    
    bb:paintRect(x, y, self.total_width, self.total_height, Blitbuffer.COLOR_WHITE)
    self:paintGrid(bb, self.grid_origin_x, self.grid_origin_y)
    self:paintClues(bb, x, y)
end

-- BB.COLOR_WHITE = Color8(0xFF)
--! BB.COLOR_GRAY_E = Color8(0xEE)
-- BB.COLOR_GRAY_D = Color8(0xDD)
--! BB.COLOR_LIGHT_GRAY = Color8(0xCC)
-- BB.COLOR_GRAY_B = Color8(0xBB)
--! BB.COLOR_GRAY = Color8(0xAA)
-- BB.COLOR_GRAY_9 = Color8(0x99) -- was COLOR_WEB_GRAY
--! BB.COLOR_DARK_GRAY = Color8(0x88)
-- BB.COLOR_GRAY_7 = Color8(0x77)
--! BB.COLOR_GRAY_6 = Color8(0x66)
-- BB.COLOR_GRAY_5 = Color8(0x55) -- was COLOR_DIM_GRAY
-- BB.COLOR_GRAY_4 = Color8(0x44)
-- BB.COLOR_GRAY_3 = Color8(0x33)
-- BB.COLOR_GRAY_2 = Color8(0x22)
-- BB.COLOR_GRAY_1 = Color8(0x11)
-- BB.COLOR_BLACK = Color8(0)

function SumPuzzleRenderer:cageColor(cage)
    local colors = {
        Blitbuffer.COLOR_GRAY_E,
        Blitbuffer.COLOR_LIGHT_GRAY,
        Blitbuffer.COLOR_GRAY_D,
        Blitbuffer.COLOR_GRAY_9,
        Blitbuffer.COLOR_GRAY,
        Blitbuffer.COLOR_GRAY_B,

    }
    return colors[cage % #colors + 1]
end

return SumPuzzleRenderer