-- sumpuzzle.koplugin/main.lua
-- Sum Puzzle plugin entry point

local PuzzlePlugin = require("kopuzzle/core/puzzle_plugin")
local SumPuzzle = require("sum_game_logic")
local SumPuzzleRenderer = require("sum_game_renderer")
local SumPuzzleScreen = require("sum_game_screen")
local _ = require("gettext")

local SumPuzzlePlugin = PuzzlePlugin:extend{
    name = "sumpuzzle",
}

function SumPuzzlePlugin:getMenuText()
    return _("Sum Puzzle")
end

function SumPuzzlePlugin:createGame()
    local game = SumPuzzle:new()
    game:initialize({rows = 5, cols = 5, lives = 3})
    return game
end

function SumPuzzlePlugin:createScreen()
    local game = self:getGame()
    
    local renderer = SumPuzzleRenderer:new{
        game = game,
    }
    
    return SumPuzzleScreen:new{
        game = game,
        renderer = renderer,
        plugin = self,
    }
end

return SumPuzzlePlugin