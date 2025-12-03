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
                callback = function() 
                    self:onShowDifficultyDialog()
                    end,
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

function SumPuzzleScreen:onShowDifficultyDialog()
    local UIManager = require("ui/uimanager")
    local ButtonDialog = require("ui/widget/buttondialog")
    
    local buttons = {
        {
            {
                text = _("Classic (5×5)"),
                callback = function()
                    self:changeDifficulty({size = 5, density = math.random(10, 15), cages = nil})
                    UIManager:close(self.difficulty_dialog)
                end,
            },
        },
        {
            {
                text = _("Cages (8×8) Easy"),
                callback = function()
                    self:changeDifficulty({size = 8, density = math.random(28, 38), cages = 18})
                    UIManager:close(self.difficulty_dialog)
                end,
            },
        },
        {
            {
                text = _("Cages (8×8) Hard"),
                callback = function()
                    self:changeDifficulty({size = 8, density = math.random(28, 38), cages = 10})
                    UIManager:close(self.difficulty_dialog)
                end,
            },
        }
    }
    
    self.difficulty_dialog = ButtonDialog:new{
        title = _("Select Difficulty"),
        buttons = buttons,
    }
    
    UIManager:show(self.difficulty_dialog)
end

function SumPuzzleScreen:changeDifficulty(params)
    params = params or {}
    params.size = params.size or 5
    params.density = params.density or 10
    params.cages = params.cages or nil

    self.game:initialize({rows = params.size, cols = params.size, cages = params.cages})
    self.game:generatePuzzle({cages = params.cages, density = params.density})
    self.renderer:updateMetrics()
    self.game:resetState()
    self.renderer:refresh()
    self.plugin:saveState()
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
            timeout = 3,
        })
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
        if self.game:consumeHint() == false then
            self:updateStatus(_("No hints remaining!"))
            return
        end

        local random_index = math.random(1, #available_hints)
        local hint = available_hints[random_index]
        
        local ok, err = self.game:applyMove({
            action = "toggle",
            row = hint.row,
            col = hint.col,
            cellState = 1,
        })
    
        if not ok then
            self:updateStatus(err)
            return
        end

        self.renderer:refresh()
        self.plugin:saveState()
        
        self:updateStatus(T(_("%1 Hints remaining"), self.game.hints))
    else
        self:updateStatus(_("No hints available. All solution cells are selected!"))
    end
end

function SumPuzzleScreen:onRestart()
    self.game:resetState()
    self.renderer:refresh()
    self.plugin:saveState()
    self:updateStatus(_("Puzzle restarted!"))
end

return SumPuzzleScreen