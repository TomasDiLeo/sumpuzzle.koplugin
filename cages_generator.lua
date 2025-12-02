-- Generate exactly numberOfCages irregular cages using a controlled growth algorithm
-- Each cage will be an irregular, contiguous region of cells
local CageGenerator = {}
CageGenerator.__index = CageGenerator

-- Get valid neighbors (up, down, left, right)
function CageGenerator:getNeighbors(row, col, rows, cols)
    local neighbors = {}
    local directions = {{-1,0}, {1,0}, {0,-1}, {0,1}}
    
    for _, dir in ipairs(directions) do
        local newRow = row + dir[1]
        local newCol = col + dir[2]
        if newRow >= 1 and newRow <= rows and newCol >= 1 and newCol <= cols then
            table.insert(neighbors, {newRow, newCol})
        end
    end
    
    return neighbors
end

function CageGenerator:generateCages(rows, cols, numberOfCages)
    -- Validate input
    if numberOfCages < 1 then
        numberOfCages = 1
    end
    
    local totalCells = rows * cols
    if numberOfCages > totalCells then
        numberOfCages = totalCells
    end
    
    -- Initialize grid with all cells unassigned (0)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            grid[r][c] = 0
        end
    end
    
    -- Calculate target size for each cage (with some variance allowed)
    local baseCageSize = math.floor(totalCells / numberOfCages)
    local remainder = totalCells % numberOfCages
    
    -- Create a list to track how many cells each cage should have
    local cageSizes = {}
    for i = 1, numberOfCages do
        -- Distribute remainder cells among first cages
        local targetSize = baseCageSize
        if i <= remainder then
            targetSize = targetSize + 1
        end
        cageSizes[i] = targetSize
    end
    
    -- Randomly select starting positions for each cage
    -- Ensure they don't overlap initially
    local startPositions = {}
    local usedPositions = {}
    
    for cageId = 1, numberOfCages do
        local startRow, startCol
        local attempts = 0
        local maxAttempts = 1000
        
        repeat
            startRow = math.random(1, rows)
            startCol = math.random(1, cols)
            local key = startRow .. "," .. startCol
            attempts = attempts + 1
            
            if attempts > maxAttempts then
                -- Fallback: find first available cell
                local found = false
                for r = 1, rows do
                    for c = 1, cols do
                        local k = r .. "," .. c
                        if not usedPositions[k] then
                            startRow = r
                            startCol = c
                            found = true
                            break
                        end
                    end
                    if found then break end
                end
                break
            end
        until not usedPositions[key]
        
        local key = startRow .. "," .. startCol
        usedPositions[key] = true
        startPositions[cageId] = {startRow, startCol}
        
        -- Assign starting cell to this cage
        grid[startRow][startCol] = cageId
    end
    
    -- Grow each cage to its target size using frontier-based growth
    -- Use round-robin approach to grow all cages fairly
    local cageGrowthComplete = {}
    local cageFrontiers = {}
    
    -- Initialize frontiers for each cage
    for cageId = 1, numberOfCages do
        cageFrontiers[cageId] = {}
        local pos = startPositions[cageId]
        local neighbors = self:getNeighbors(pos[1], pos[2], rows, cols)
        
        for _, neighbor in ipairs(neighbors) do
            local nr, nc = neighbor[1], neighbor[2]
            if grid[nr][nc] == 0 then
                table.insert(cageFrontiers[cageId], neighbor)
            end
        end
        
        cageGrowthComplete[cageId] = false
    end
    
    -- Track current size of each cage
    local currentCageSizes = {}
    for i = 1, numberOfCages do
        currentCageSizes[i] = 1  -- Each cage starts with 1 cell
    end
    
    -- Grow cages in round-robin fashion until all reach target size
    local allComplete = false
    local maxIterations = totalCells * 10  -- Safety limit
    local iterations = 0
    
    while not allComplete and iterations < maxIterations do
        iterations = iterations + 1
        allComplete = true
        
        for cageId = 1, numberOfCages do
            -- Skip if this cage is already complete
            if cageGrowthComplete[cageId] then
                goto continue
            end
            
            allComplete = false
            
            -- Check if cage has reached target size
            if currentCageSizes[cageId] >= cageSizes[cageId] then
                cageGrowthComplete[cageId] = true
                goto continue
            end
            
            -- Get frontier for this cage
            local frontier = cageFrontiers[cageId]
            
            if #frontier == 0 then
                -- No more cells available for this cage
                cageGrowthComplete[cageId] = true
                goto continue
            end
            
            -- Remove duplicates and invalid cells from frontier
            local validFrontier = {}
            local frontierKeys = {}
            
            for _, cell in ipairs(frontier) do
                local r, c = cell[1], cell[2]
                local key = r .. "," .. c
                
                if grid[r][c] == 0 and not frontierKeys[key] then
                    table.insert(validFrontier, cell)
                    frontierKeys[key] = true
                end
            end
            
            if #validFrontier == 0 then
                cageGrowthComplete[cageId] = true
                goto continue
            end
            
            -- Select a random cell from valid frontier
            local selectedIndex = math.random(1, #validFrontier)
            local selectedCell = validFrontier[selectedIndex]
            local r, c = selectedCell[1], selectedCell[2]
            
            -- Assign this cell to the cage
            grid[r][c] = cageId
            currentCageSizes[cageId] = currentCageSizes[cageId] + 1
            
            -- Update frontier: remove assigned cell and add its unassigned neighbors
            local newFrontier = {}
            
            -- Add all previous frontier cells except the one we just assigned
            for _, cell in ipairs(validFrontier) do
                if cell ~= selectedCell then
                    table.insert(newFrontier, cell)
                end
            end
            
            -- Add new neighbors of the assigned cell
            local neighbors = self:getNeighbors(r, c, rows, cols)
            for _, neighbor in ipairs(neighbors) do
                local nr, nc = neighbor[1], neighbor[2]
                if grid[nr][nc] == 0 then
                    table.insert(newFrontier, neighbor)
                end
            end
            
            cageFrontiers[cageId] = newFrontier
            
            ::continue::
        end
    end
    
    -- Handle any remaining unassigned cells (edge case)
    -- Assign them to the nearest cage
    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] == 0 then
                -- Find nearest assigned cell and use its cage ID
                local nearestCage = 1
                local minDistance = math.huge
                
                for checkR = 1, rows do
                    for checkC = 1, cols do
                        if grid[checkR][checkC] ~= 0 then
                            local distance = math.abs(r - checkR) + math.abs(c - checkC)
                            if distance < minDistance then
                                minDistance = distance
                                nearestCage = grid[checkR][checkC]
                            end
                        end
                    end
                end
                
                grid[r][c] = nearestCage
            end
        end
    end
    
    return grid
end

return CageGenerator