--[[
    World signs in one style, the gym signs' (WorldSignController draws them per player):
    a dark rounded panel with a thick accent border, an optional round badge with an icon
    that gently pulses, a big outlined title and a subtitle in the accent colour.

    Signs.decorate(part, face, props) turns an existing part's face into one.
    Signs.board(parent, name, cframe, size, props) stands a new one: a dark backing slab
    with the panel on its front (cframe's look direction) and, given props.ground (a y),
    two steel posts down to it on concrete footings, a brace behind, and a lamp bar along
    the top shining down on the panel; props.back (more props) puts a second panel on the
    back (and then no brace).
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
                block(model, "SignFooting", Vector3.new(1.8, 1, 1.6),
                    CFrame.new(foot.Position.X, props.ground + 0.4, foot.Position.Z) * cframe.Rotation, Color3.fromRGB(160, 158, 152), Enum.Material.Concrete)
                if not props.back then
                    -- A diagonal brace from high on the post down to the ground behind it.
                    local top = Vector3.new(foot.Position.X, props.ground + height * 0.8, foot.Position.Z)
                    local base = top + cframe.LookVector * -height * 0.6 - Vector3.new(0, height * 0.8, 0)
                    block(model, "SignBrace", Vector3.new(0.3, 0.3, (top - base).Magnitude), CFrame.lookAt((top + base) / 2, top), STEEL, Enum.Material.Metal)
                end
            end
        end
        -- The lamp bar: a dark housing along the top edge, three lamps on short arms
        -- leaning out over the panel, and their light.
        local lampColor = Color3.fromRGB(255, 226, 170)
        block(model, "LampBar", Vector3.new(size.X * 0.8, 0.35, 0.6), cframe * CFrame.new(0, size.Y / 2 + 0.75, 0), Color3.fromRGB(40, 42, 50), Enum.Material.Metal)
        for _, x in { -size.X * 0.3, 0, size.X * 0.3 } do
            block(model, "LampArm", Vector3.new(0.2, 0.2, 1.4), cframe * CFrame.new(x, size.Y / 2 + 0.75, -0.9), Color3.fromRGB(40, 42, 50), Enum.Material.Metal)
            local lamp = block(model, "SignLamp", Vector3.new(0.9, 0.3, 0.6), cframe * CFrame.new(x, size.Y / 2 + 0.6, -1.6) * CFrame.Angles(math.rad(30), 0, 0), lampColor, Enum.Material.Neon)
            local light = Instance.new("SpotLight")
            light.Face, light.Angle, light.Range, light.Brightness, light.Color = Enum.NormalId.Bottom, 70, 10, 1.5, lampColor
            light.Parent = lamp
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
