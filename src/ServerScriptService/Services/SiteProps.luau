--[[
    Kenney props (CC0) for the launch site, cloned from ServerScriptService.SiteModels
    (built by tools/map; see its README). Every model there is anchored decor with its
    pivot at the middle of its base, stored at 10 studs per kit metre, and takes its
    colours from its kit's palette image (Palettes; tools/map/prepare.luau sets them).

    SiteProps.place(parent, name, cframe, scale, solid) stands a copy on `cframe` at
    `scale` studs per kit metre and returns it, or nil if the model isn't there (so the
    site still builds without the props file).
]]
local SiteProps = {}

SiteProps.Stored = 10
SiteProps.Palettes = table.freeze({
    Factory = "rbxassetid://96315897677106",
    Station = "rbxassetid://109349449591065",
    -- Baked from every colour in the kit by tools/map/bake_spaceport.py; uploaded by
    -- Studio's importer.
    Space = "rbxassetid://71738999329000",
    -- Kenney Modular Space Kit's colormap, embedded by bake_spaceport.py.
    Modular = "rbxassetid://126762679417470",
})

local function models()
    return script.Parent.Parent:FindFirstChild("SiteModels")
end

function SiteProps.has(name)
    local folder = models()
    return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

function SiteProps.place(parent, name, cframe, scale, solid)
    local folder = models()
    local source = folder and folder:FindFirstChild(name)
    if not source then return nil end
    local model = source:Clone()
    model:ScaleTo(model:GetScale() * scale / SiteProps.Stored)
    model:PivotTo(cframe)
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide, part.CanQuery, part.CanTouch = solid == true, solid == true, false
        end
    end
    model.Parent = parent
    return model
end

return SiteProps
