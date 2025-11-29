-- sumpuzzle.koplugin/game_screen.lua
-- Sum Puzzle screen controller

local PuzzleScreen = require("kopuzzle/core/puzzle_screen")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local T = require("ffi/util").template
local _ = require("gettext")

local SumPuzzleScreen = PuzzleScreen:extend{}

function SumPuzzleScreen:init()
    -- Setup renderer callbacks
    self.renderer.onCellActivated = function(row, col)
        self:onCellTapped(row, col)
    end
    
    self.renderer.onSelectionChanged = function(row, col)
        self:updateStatus()
    end
    
    -- Call parent init
    PuzzleScreen.init(self)
end

function SumPuzzleScreen:getInitialStatus()
    return _("Tap Submit when ready!")
end

function SumPuzzleScreen:getTopButtons()
    return {
        {
            {
                text = _("New game"),
                callback = function() self:onNewGame() end,
            },
            {
                text = _("Clear"),
                callback = function() self:onRestart() end,
            },
            {
                text = _("Close"),
                callback = function()
                    self:onClose()
                    UIManager:close(self)
                    UIManager:setDirty(nil, "full")
                end,
            },
        },
    }
end

function SumPuzzleScreen:getActionButtons()
    return {
        {
            {
                text = _("Submit"),
                callback = function()
                    self:onSubmit()
                end,
            },
            {
                text = _("Hint"),
                callback = function()
                    self:onHint()
                end,
            },
        },
    }
end

function SumPuzzleScreen:updateStatus(message)
    if message then
        PuzzleScreen.updateStatus(self, message)
        return
    end
    
    -- Show current sums
    local row, col = self.game:getSelection()
    local row_sum = self.game:getRowSum(row)
    local row_target = self.game.row_targets[row]
    local col_sum = self.game:getColSum(col)
    local col_target = self.game.col_targets[col]
    
    local status = T(_("\nRow %1, Col %2"), 
                        row, col)
    
    if self.game:checkWinCondition() then
        status = "\n" .. _("Puzzle complete! All sums match!")
    end
    
    PuzzleScreen.updateStatus(self, status)
end

function SumPuzzleScreen:onCellTapped(row, col)
    if not self.game.state then
        self:updateStatus(_("Puzzle Solved, start new game"))
        return
    end
    
    local ok, err = self.game:applyMove({
        action = "toggle",
        row = row,
        col = col
    })
    
    if not ok then
        self:updateStatus(err)
        return
    end
    
    self.renderer:refresh()
    self.plugin:saveState()
    self:updateStatus()
end

function SumPuzzleScreen:onSubmit()
    if not self.game.state then
        self:updateStatus(_("Can't submit because the Puzzle is Solved"))
        return
    end
    
    local ok, msg = self.game:applyMove({action = "submit"})
    
    self.renderer:refresh()
    self.plugin:saveState()
    
    if ok then
        UIManager:show(InfoMessage:new{
            text = msg,
            timeout = 2,
        })
        
        if not self.game.state then
            UIManager:show(InfoMessage:new{
                text = _("Congratulations! Puzzle solved!"),
                timeout = 3,
            })
        end
    else
        UIManager:show(InfoMessage:new{
            text = T(_("Puzzle not Solved: sum %1"), msg),
            timeout = 3,
        })
    end
    
    self:updateStatus()
end

function SumPuzzleScreen:onHint()
    -- Find all cells that are part of the solution but not yet selected
    local available_hints = {}
    
    for row = 1, self.game.rows do
        for col = 1, self.game.cols do
            if self.game:getHintNumber(row, col) ~= 0 and self.game:getCellState(row, col) ~= 1 then
                table.insert(available_hints, {row = row, col = col})
            end
        end
    end
    
    -- If we found available hints, pick one randomly
    if #available_hints > 0 then
        local random_index = math.random(1, #available_hints)
        local hint = available_hints[random_index]
        
        self.game.state_grid[hint.row][hint.col] = 1
        self.renderer:refresh()
        self.plugin:saveState()
        
        local temp = T(_("Hint: Selected cell at %1,%2"), hint.row, hint.col)
        self:updateStatus(temp)
    else
        self:updateStatus(_("No hints available. All solution cells are selected!"))
    end
end

function SumPuzzleScreen:onNewGame()
    self.game:resetState()
    self.game:generatePuzzle()
    self.renderer:updateMetrics()
    self.renderer:refresh()
    self.plugin:saveState()
    self:updateStatus(_("New puzzle generated!"))
end

function SumPuzzleScreen:onRestart()
    self.game:resetState()
    self.renderer:refresh()
    self.plugin:saveState()
    self:updateStatus(_("Puzzle restarted!"))
end

return SumPuzzleScreen