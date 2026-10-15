-- Runs every Services/*Check module. From the Studio command bar or MCP:
-- print(require(game.ServerScriptService.RunChecks)())
return function()
    local results, failed = {}, 0
    for _, module in script.Parent.Services:GetChildren() do
        if module:IsA("ModuleScript") and module.Name:match("Check$") then
            local ok, err = pcall(function() require(module)() end)
            if not ok then failed += 1 end
            table.insert(results, module.Name .. ": " .. (ok and "PASS" or "FAIL " .. tostring(err)))
        end
    end
    table.sort(results)
    table.insert(results, failed == 0 and "ALL CHECKS PASS" or failed .. " CHECK(S) FAILED")
    return table.concat(results, "\n"), failed == 0
end
