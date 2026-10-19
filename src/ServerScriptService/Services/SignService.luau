--[[
    World signs in one style, the gym signs' (WorldSignController draws them per player):
    a dark rounded panel with a thick accent border, an optional round badge with an icon
    that gently pulses, a big outlined title and a subtitle in the accent colour.

    Signs.decorate(part, face, props) turns an existing part's face into one.
    Signs.board(parent, name, cframe, size, props) stands a new one: a dark backing slab
    with the panel on its front (cframe's look direction) and, given props.ground (a y),
    two steel posts down to it; props.back (more props) puts a second panel on the back.
    props: { title, subtitle?, icon?, accent? (Color3), ground?, back? }.
]]
local CollectionService = game:GetService("CollectionService")
local Signs = {}

Signs.Tag = "WorldSign"
Signs.Backing = Color3.fromRGB(34, 26, 52)
local STEEL = Color3.fromRGB(150, 156, 166)

function Signs.decorate(part, face, props)
    part:SetAttribute("Title", props.title)
    part:SetAttribute("Subtitle", props.subtitle)
    part:SetAttribute("Icon", props.icon)
    part:SetAttribute("Accent", props.accent or Color3.fromRGB(255, 204, 40))
    part:SetAttribute("Face", (face or Enum.NormalId.Front).Name)
    CollectionService:AddTag(part, Signs.Tag)
    return part
end

local function block(parent, name, size, cframe, color, material)
    local part = Instance.new("Part")
    part.Name, part.Size, part.CFrame, part.Color = name, size, cframe, color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
    part.Parent = parent
    return part
end

function Signs.board(parent, name, cframe, size, props)
    local model = Instance.new("Model")
    model.Name = name
    model.Parent = parent
    local backing = block(model, "SignBacking", Vector3.new(size.X + 0.8, size.Y + 0.8, 0.8), cframe, Signs.Backing, Enum.Material.Metal)
    -- A thin accent rim round the backing (centred in it, so no faces meet).
    block(model, "SignTrim", Vector3.new(size.X + 1.2, size.Y + 1.2, 0.4), cframe, props.accent or Color3.fromRGB(255, 204, 40), Enum.Material.Neon)
    if props.ground then
        local bottom = cframe.Position.Y - size.Y / 2 - 0.6
        local height = bottom - props.ground
        if height > 0.5 then
            for _, x in { -size.X * 0.32, size.X * 0.32 } do
                -- Thinner than the backing and centred in it, so they meet neither face.
                local foot = cframe * CFrame.new(x, 0, 0)
                block(model, "SignPost", Vector3.new(0.8, height + size.Y * 0.5, 0.6),
                    CFrame.new(foot.Position.X, props.ground + (height + size.Y * 0.5) / 2, foot.Position.Z) * cframe.Rotation, STEEL, Enum.Material.Metal).CanCollide = true
            end
        end
    end
    -- The panel's surface: a face just in front of the backing, so nothing z-fights it.
    local face = block(model, "SignFace", Vector3.new(size.X, size.Y, 0.05), cframe * CFrame.new(0, 0, -0.43), Signs.Backing)
    face.Transparency = 1
    Signs.decorate(face, Enum.NormalId.Front, props)
    if props.back then
        local back = block(model, "SignFace", Vector3.new(size.X, size.Y, 0.05), cframe * CFrame.new(0, 0, 0.43) * CFrame.Angles(0, math.pi, 0), Signs.Backing)
        back.Transparency = 1
        Signs.decorate(back, Enum.NormalId.Front, props.back)
    end
    backing.CanCollide = true
    return model, face
end

return Signs
