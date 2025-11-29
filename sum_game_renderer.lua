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

function SumPuzzleRenderer:paintCell(bb, x, y, size, row, col)
    local state = self.game:getCellState(row, col)
    local number = self.game:getCellNumber(row, col)

    local cx = x + self.cell_size/2
    local cy = y + self.cell_size/2

    local selection_size = self.cell_size/2.5
    
    local bg_color = Blitbuffer.COLOR_WHITE
    
    bb:paintRect(x + 2, y + 2, size - 4, size - 4, bg_color)
    
    if state == 1 then
        bb:paintBorder(cx - selection_size, cy - selection_size, selection_size * 2, selection_size * 2, 2, Blitbuffer.COLOR_GRAY_7, 15, 1)
    end

    local text_color = Blitbuffer.COLOR_BLACK
    if state == 2 then 
        text_color = Blitbuffer.COLOR_GRAY_D
    end
    self:drawCenteredText(bb, x, y, size, size, self.number_face, 
                         tostring(number), text_color)
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

return SumPuzzleRenderer