--BDYJTB 🥀
local Projection = {}
Projection.__index = Projection

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local clock = os.clock
local floor = math.floor
local max = math.max
local min = math.min
local random = math.random
local sin = math.sin
local cos = math.cos
local pi = math.pi
local pi2 = pi * 2
local create = table.create
local insert = table.insert
local sort = table.sort
local unpack = unpack

local animCache = setmetatable({}, {__mode = "v"})
local animLengthCache = {}
local shardCache = {}
local shardPool = {}
local activeShards = {}
local folder, heartbeatConn

local shardTemplate = Instance.new("Part")
shardTemplate.Material = Enum.Material.Neon
shardTemplate.CanCollide = false
shardTemplate.CanQuery = false
shardTemplate.CanTouch = false
shardTemplate.Anchored = true
shardTemplate.TopSurface = Enum.SurfaceType.Smooth
shardTemplate.BottomSurface = Enum.SurfaceType.Smooth

local destroyClasses = {
    Decal = true, Texture = true, SurfaceAppearance = true, Accessory = true, Hat = true,
    Shirt = true, Pants = true, ShirtGraphic = true, BodyColors = true, Sound = true,
    ParticleEmitter = true, Fire = true, Smoke = true, Sparkles = true, Trail = true,
    Beam = true, PointLight = true, SpotLight = true, SurfaceLight = true, BillboardGui = true,
    SurfaceGui = true, Highlight = true, WrapTarget = true, WrapLayer = true, FaceControls = true
}

local viewportDestroyClasses = {
    ParticleEmitter = true, Fire = true, Smoke = true, Sparkles = true,
    Trail = true, Beam = true, Sound = true, BillboardGui = true, SurfaceGui = true
}

local function destroyTrack(track)
    if not track then return end
    pcall(track.Stop, track)
    pcall(track.Destroy, track)
end

local function stopTrack(track)
    if not track then return end
    pcall(track.Stop, track)
end

local backC1, backC3 = 1.70158, 2.70158
local elasticC = pi2 / 3

Projection.Path = {
    Linear = function(t, p0, p1) return p0:Lerp(p1, t) end,
    EaseIn = function(t, p0, p1) return p0:Lerp(p1, t * t) end,
    EaseOut = function(t, p0, p1) return p0:Lerp(p1, 1 - (1 - t) ^ 2) end,
    EaseInOut = function(t, p0, p1) return p0:Lerp(p1, t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 * 0.5) end,
    EaseInCubic = function(t, p0, p1) return p0:Lerp(p1, t ^ 3) end,
    EaseOutCubic = function(t, p0, p1) return p0:Lerp(p1, 1 - (1 - t) ^ 3) end,
    EaseInOutCubic = function(t, p0, p1) return p0:Lerp(p1, t < 0.5 and 4 * t ^ 3 or 1 - (-2 * t + 2) ^ 3 * 0.5) end,
    EaseInElastic = function(t, p0, p1)
        return (t == 0 or t == 1) and p0:Lerp(p1, t) or p0:Lerp(p1, -(2 ^ (10 * t - 10)) * sin((t * 10 - 10.75) * elasticC))
    end,
    EaseOutElastic = function(t, p0, p1)
        return (t == 0 or t == 1) and p0:Lerp(p1, t) or p0:Lerp(p1, 2 ^ (-10 * t) * sin((t * 10 - 0.75) * elasticC) + 1)
    end,
    EaseOutBack = function(t, p0, p1) return p0:Lerp(p1, 1 + backC3 * (t - 1) ^ 3 + backC1 * (t - 1) ^ 2) end,
    EaseInBack = function(t, p0, p1) return p0:Lerp(p1, backC3 * t ^ 3 - backC1 * t * t) end,
    QuadBezier = function(t, p0, p1, p2)
        local u = 1 - t
        return CFrame.new(p0.Position * u * u + p1.Position * 2 * u * t + p2.Position * t * t) * p0:Lerp(p2, t).Rotation
    end,
    CubicBezier = function(t, p0, p1, p2, p3)
        local u, tt = 1 - t, t * t
        return CFrame.new(p0.Position * u ^ 3 + p1.Position * 3 * u * u * t + p2.Position * 3 * u * tt + p3.Position * tt * t) * p0:Lerp(p3, t).Rotation
    end,
    CatmullRom = function(t, p0, p1, p2, p3, tension)
        tension = tension or 0.5
        local t2, t3 = t * t, t ^ 3
        local v0, v1, v2, v3 = p0.Position, p1.Position, p2.Position, p3.Position
        return CFrame.new(v1 + (v2 - v0) * tension * t + (2 * v0 - 5 * v1 + 4 * v2 - v3) * tension * t2 + (3 * v1 - 3 * v2 + v3 - v0) * tension * t3) * p1:Lerp(p2, t).Rotation
    end,
    Sine = function(t, p0, p1, amp, freq)
        local base = p0:Lerp(p1, t)
        return base + base.RightVector * sin(t * (freq or 2) * pi2) * (amp or 5)
    end,
    Spiral = function(t, p0, p1, radius, rotations)
        local angle, r = t * (rotations or 2) * pi2, radius or 3
        return p0:Lerp(p1, t) * CFrame.new(cos(angle) * r, sin(angle) * r, 0)
    end,
    SpiralIn = function(t, p0, p1, radius, rotations)
        local angle, r = t * (rotations or 3) * pi2, (radius or 5) * (1 - t)
        return p0:Lerp(p1, t) * CFrame.new(cos(angle) * r, sin(angle) * r, 0)
    end,
    SpiralOut = function(t, p0, p1, radius, rotations)
        local angle, r = t * (rotations or 3) * pi2, (radius or 5) * t
        return p0:Lerp(p1, t) * CFrame.new(cos(angle) * r, sin(angle) * r, 0)
    end,
    Bounce = function(t, p0, p1, height) return p0:Lerp(p1, t) + Vector3.new(0, sin(t * pi) * (height or 5) * (1 - t), 0) end,
    Arc = function(t, p0, p1, height) return p0:Lerp(p1, t) + Vector3.new(0, sin(t * pi) * (height or 10), 0) end,
    ZigZag = function(t, p0, p1, amp, segments)
        amp = amp or 3
        local base, phase = p0:Lerp(p1, t), (t * (segments or 4)) % 2
        return base + base.RightVector * ((phase < 1 and phase or 2 - phase) * amp - amp * 0.5)
    end,
    Wave = function(t, p0, p1, ampX, ampY, freqX, freqY)
        local base = p0:Lerp(p1, t)
        return base + base.RightVector * sin(t * (freqX or 2) * pi2) * (ampX or 3) + base.UpVector * sin(t * (freqY or 3) * pi2) * (ampY or 2)
    end,
    Figure8 = function(t, p0, p1, scaleX, scaleY)
        local base, angle = p0:Lerp(p1, t), t * pi2
        return base + base.RightVector * sin(angle) * (scaleX or 4) + base.UpVector * sin(angle * 2) * (scaleY or 2)
    end,
    Heart = function(t, p0, p1, scale)
        scale = (scale or 3) * 0.1
        local angle, sinA = t * pi2, sin(t * pi2)
        local x, y = 16 * sinA ^ 3, 13 * cos(angle) - 5 * cos(2 * angle) - 2 * cos(3 * angle) - cos(4 * angle)
        local base = p0:Lerp(p1, t)
        return base + base.RightVector * x * scale + base.UpVector * y * scale
    end,
    Helix = function(t, p0, p1, radius, rotations, verticalAmp)
        radius = radius or 3
        local angle, base = t * (rotations or 2) * pi2, p0:Lerp(p1, t)
        return base + base.RightVector * cos(angle) * radius + base.UpVector * (sin(angle) * radius + sin(t * pi) * (verticalAmp or 0))
    end
}

local EasingFunctions = {
    [Enum.EasingStyle.Linear] = function(t) return t end,
    [Enum.EasingStyle.Quad] = function(t) return t * t end,
    [Enum.EasingStyle.Cubic] = function(t) return t ^ 3 end,
    [Enum.EasingStyle.Quart] = function(t) return t ^ 4 end,
    [Enum.EasingStyle.Quint] = function(t) return t ^ 5 end,
    [Enum.EasingStyle.Sine] = function(t) return 1 - cos(t * pi * 0.5) end,
    [Enum.EasingStyle.Exponential] = function(t) return t == 0 and 0 or 2 ^ (10 * (t - 1)) end,
    [Enum.EasingStyle.Circular] = function(t) return 1 - (1 - t * t) ^ 0.5 end,
    [Enum.EasingStyle.Back] = function(t) return backC3 * t ^ 3 - backC1 * t * t end,
    [Enum.EasingStyle.Elastic] = function(t)
        return (t == 0 or t == 1) and t or -(2 ^ (10 * t - 10)) * sin((t * 10 - 10.75) * elasticC)
    end,
    [Enum.EasingStyle.Bounce] = function(t)
        t = 1 - t
        if t < 1 / 2.75 then return 1 - 7.5625 * t * t end
        if t < 2 / 2.75 then t -= 1.5 / 2.75 return 1 - (7.5625 * t * t + 0.75) end
        if t < 2.5 / 2.75 then t -= 2.25 / 2.75 return 1 - (7.5625 * t * t + 0.9375) end
        t -= 2.625 / 2.75 return 1 - (7.5625 * t * t + 0.984375)
    end
}

local defaultEasing = EasingFunctions[Enum.EasingStyle.Quad]

local function applyEasing(t, style, direction)
    local easeIn = EasingFunctions[style] or defaultEasing
    if direction == Enum.EasingDirection.In then return easeIn(t) end
    if direction == Enum.EasingDirection.Out then return 1 - easeIn(1 - t) end
    return t < 0.5 and easeIn(t * 2) * 0.5 or 1 - easeIn((1 - t) * 2) * 0.5
end

local function ensureFolder()
    if not folder or not folder.Parent then
        folder = Instance.new("Folder")
        folder.Name = "ProjectionFX"
        folder.Parent = workspace.Terrain
    end
    return folder
end

local function ensureHeartbeat()
    if heartbeatConn then return end
    heartbeatConn = RunService.Heartbeat:Connect(function()
        local now, n, i = clock(), #activeShards, 1
        while i <= n do
            local d = activeShards[i]
            local alpha = (now - d[2]) / d[7]
            if alpha >= 1 then
                d[1].Parent = nil
                shardPool[#shardPool + 1] = d[1]
                activeShards[i], activeShards[n], n = activeShards[n], nil, n - 1
            else
                local e = alpha * alpha
                d[1].Transparency = d[3] + (1 - d[3]) * e
                d[1].CFrame = d[4]:Lerp(d[5], e)
                d[1].Size = d[6] * (1 - e * 0.99)
                i += 1
            end
        end
    end)
end

local function getShard()
    local n = #shardPool
    if n > 0 then
        local s = shardPool[n]
        shardPool[n] = nil
        return s
    end
    return shardTemplate:Clone()
end

local function getShardLayout(sx, sy, sz, count)
    local k = floor(sx * 10) * 1000000 + floor(sy * 10) * 1000 + floor(sz * 10) + count * 0.001
    if shardCache[k] then return shardCache[k] end
    local l = create(count)
    for i = 1, count do
        l[i] = {
            Vector3.new((random() - 0.5) * sx, (random() - 0.5) * sy, (random() - 0.5) * sz),
            Vector3.new(max(sx * random(15, 40) * 0.01, 0.05), max(sy * random(15, 40) * 0.01, 0.05), max(sz * random(5, 20) * 0.01, 0.02)),
            CFrame.new((random() - 0.5) * 12, random(-3, 8), (random() - 0.5) * 12) * CFrame.Angles(random() * 6.2832, random() * 6.2832, random() * 6.2832)
        }
    end
    shardCache[k] = l
    return l
end

local function getAnim(id)
    local raw = tostring(id):match("%d+")
    if animCache[raw] then return animCache[raw] end
    local a = Instance.new("Animation")
    a.AnimationId = "rbxassetid://" .. raw
    animCache[raw] = a
    return a
end

local function getAnimLength(char, id)
    local raw = tostring(id):match("%d+")
    if animLengthCache[raw] then return animLengthCache[raw] end
    local h = char:FindFirstChildWhichIsA("Humanoid")
    if not h then return 1 end
    local anim = getAnim(id)
    local track = h:LoadAnimation(anim)
    local timeout = clock() + 5
    while track.Length == 0 and clock() < timeout do
        task.wait()
    end
    local length = track.Length
    if length == 0 then length = 1 end
    track:Stop()
    track:Destroy()
    animLengthCache[raw] = length
    return length
end

local function safeCloneCharacter(char)
    if not char then return nil end
    local wasArchivable = char.Archivable
    char.Archivable = true
    local clone = char:Clone()
    char.Archivable = wasArchivable
    return clone
end

local function collectParts(model)
    local parts, origTrans, pn = {}, {}, 0
    for _, v in model:GetDescendants() do
        if v:IsA("BasePart") then
            pn += 1
            parts[pn] = v
            origTrans[pn] = v.Transparency
        end
    end
    return parts, origTrans, pn
end

function Projection.new(cfg)
    cfg = cfg or {}
    local self = setmetatable({
        Player = cfg.Player or Players.LocalPlayer,
        StartPosition = cfg.StartPosition,
        EndPosition = cfg.EndPosition,
        Frames = cfg.Frames or 60,
        Duration = cfg.Duration or 2,
        ShardCount = cfg.ShardCount or 5,
        ShardLife = cfg.ShardLife or 0.8,
        VisibleWindow = cfg.VisibleWindow or 0,
        Color = cfg.Color or Color3.fromRGB(144, 213, 255),
        Transparency = cfg.Transparency or 0.75,
        PathFunc = cfg.PathFunc or Projection.Path.Linear,
        PathArgs = cfg.PathArgs or {},
        MovePlayer = cfg.MovePlayer ~= false,
        PlayAnimation = cfg.PlayAnimation ~= false,
        AnchorPlayer = cfg.AnchorPlayer ~= false,
        Interpolate = cfg.Interpolate ~= false,
        SettleTime = cfg.SettleTime or 0.1,
        UseViewport = cfg.UseViewport or false,
        TrailMode = cfg.TrailMode or false,
        FadeTime = cfg.FadeTime or 0.5,
        FadeStyle = cfg.FadeStyle or Enum.EasingStyle.Quad,
        FadeDirection = cfg.FadeDirection or Enum.EasingDirection.Out,
        AnimationId = cfg.AnimationId,
        AnimationTimeStart = cfg.AnimationTimeStart or 0,
        AnimationTimeEnd = cfg.AnimationTimeEnd,
        AnimationReverse = cfg.AnimationReverse or false,
        AnimationSpeed = cfg.AnimationSpeed or 1,
        AnimationFunc = cfg.AnimationFunc,
        _segments = {},
        _active = false,
        _projections = {},
        _pivots = {},
        _animData = {},
        _template = nil,
        _conn = nil,
        _playerTracks = {},
        _screenGui = nil,
        _viewport = nil,
        _worldModel = nil,
        _fadingModels = {},
        _fadeConn = nil,
        _fadingCount = 0,
        _projectionComplete = false,
        _modelPool = {},
        _maxPoolSize = 0
    }, Projection)

    if cfg.Segments then
        for _, seg in ipairs(cfg.Segments) do self:AddSegment(seg) end
    end

    ensureFolder()
    ensureHeartbeat()
    return self
end

function Projection:_isAlive(c)
    local h = c and c:FindFirstChildWhichIsA("Humanoid")
    return h and h.Health > 0
end

function Projection:_getTrack(char, id)
    local h = char:FindFirstChildWhichIsA("Humanoid")
    return h and h:LoadAnimation(getAnim(id))
end

function Projection:_getAnimator(model)
    local h = model:FindFirstChildWhichIsA("Humanoid")
    if not h then
        h = Instance.new("Humanoid")
        h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        h.Parent = model
    end
    local animator = h:FindFirstChildWhichIsA("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = h
    end
    return animator
end

function Projection:_setupViewportAnimation(model, animId, timePos, existingTrack, existingAnimId)
    if existingTrack and existingAnimId == animId then
        pcall(function()
            if not existingTrack.IsPlaying then
                existingTrack:Play(0, 1, 0)
            end
            existingTrack.TimePosition = timePos
        end)
        return existingTrack
    end

    destroyTrack(existingTrack)

    local animator = self:_getAnimator(model)
    if not animator then return nil end
    local track = animator:LoadAnimation(getAnim(animId))
    track:Play(0, 1, 0)
    task.defer(function()
        if track and track.IsPlaying then track.TimePosition = timePos end
    end)
    return track
end

function Projection:_buildTemplate()
    local char = self.Player.Character
    if not char then return nil end
    local t = safeCloneCharacter(char)
    if not t then return nil end

    local col, tr = self.Color, self.Transparency
    local toDestroy, parts, toDestroyN, partsN = {}, {}, 0, 0

    for _, v in t:GetDescendants() do
        local cn = v.ClassName
        if v:IsA("BasePart") then
            partsN += 1
            parts[partsN] = v
        elseif destroyClasses[cn] or v:IsA("BaseScript") then
            toDestroyN += 1
            toDestroy[toDestroyN] = v
        elseif v:IsA("SpecialMesh") or v:IsA("FileMesh") then
            v.TextureId = ""
        end
    end

    for i = toDestroyN, 1, -1 do toDestroy[i]:Destroy() end

    for i = 1, partsN do
        local v = parts[i]
        v.CanCollide, v.CanQuery, v.CanTouch, v.CastShadow = false, false, false, false
        v.Color, v.Material, v.Reflectance = col, Enum.Material.Neon, 0
        if v:IsA("MeshPart") then v.TextureID = "" end
        local isHRP = v.Name == "HumanoidRootPart"
        if isHRP then
            v.Transparency = 1
            v.Anchored = true
        elseif v.Transparency >= 1 then
            v.Transparency = 1
        else
            v.Transparency = tr
        end
    end

    local h = t:FindFirstChildWhichIsA("Humanoid")
    if not h then h = Instance.new("Humanoid") h.Parent = t end
    h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    h.BreakJointsOnDeath = false

    local animator = h:FindFirstChildWhichIsA("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = h
    end

    return t
end

function Projection:_buildViewportTemplate()
    local char = self.Player.Character
    if not char then return nil end
    local t = safeCloneCharacter(char)
    if not t then return nil end

    local toDestroy = {}
    for _, v in t:GetDescendants() do
        if v:IsA("BaseScript") or viewportDestroyClasses[v.ClassName] then insert(toDestroy, v) end
    end
    for _, v in toDestroy do v:Destroy() end

    for _, v in t:GetDescendants() do
        if v:IsA("BasePart") then
            v.CanCollide, v.CanQuery, v.CanTouch = false, false, false
            local isHRP = v.Name == "HumanoidRootPart"
            v.Transparency = isHRP and 1 or v.Transparency
            v.Anchored = isHRP
        end
    end

    local h = t:FindFirstChildWhichIsA("Humanoid")
    if not h then h = Instance.new("Humanoid") h.Parent = t end
    h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    h.BreakJointsOnDeath = false
    h.Health = h.MaxHealth
    h.PlatformStand = false
    if not h:FindFirstChildWhichIsA("Animator") then Instance.new("Animator").Parent = h end
    return t
end

function Projection:_createViewport()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ProjectionViewport"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 10

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.new(1, 0, 1, 0)
    viewport.BackgroundTransparency = 1
    viewport.ImageTransparency = 0.25
    viewport.Ambient = Color3.new(2, 2, 2)
    viewport.LightColor = Color3.new(2, 2, 2)
    viewport.LightDirection = Vector3.new(-1, -1, -1)
    viewport.CurrentCamera = workspace.CurrentCamera
    viewport.ImageColor3 = self.Color
    viewport.Parent = screenGui

    local worldModel = Instance.new("WorldModel")
    worldModel.Name = "WorldModel"
    worldModel.Parent = viewport

    screenGui.Parent = self.Player.PlayerGui
    self._screenGui, self._viewport, self._worldModel = screenGui, viewport, worldModel
    return screenGui, viewport, worldModel
end

function Projection:_poolModel(model, track, animId, parts, origTrans)
    local pool = self._modelPool
    if #pool >= self._maxPoolSize then
        destroyTrack(track)
        if model and model.Parent then model:Destroy() end
        return
    end
    model.Parent = nil
    stopTrack(track)
    pool[#pool + 1] = {
        model = model,
        track = track,
        animId = animId,
        parts = parts,
        origTrans = origTrans
    }
end

function Projection:_takeFromPool()
    local pool = self._modelPool
    local n = #pool
    if n == 0 then return nil end
    local entry = pool[n]
    pool[n] = nil
    return entry
end

function Projection:_drainPool()
    for _, pe in self._modelPool do
        destroyTrack(pe.track)
        if pe.model and pe.model.Parent then pe.model:Destroy() end
    end
    self._modelPool = {}
end

function Projection:_startFadeProcessor()
    if self._fadeConn then return end
    local useViewport = self.UseViewport
    self._fadeConn = RunService.Heartbeat:Connect(function()
        local now, fadingModels, n, i = clock(), self._fadingModels, #self._fadingModels, 1
        while i <= n do
            local fd = fadingModels[i]
            local alpha = (now - fd.startTime) / fd.fadeTime
            if alpha >= 1 then
                if useViewport and fd.parts then
                    self:_poolModel(fd.model, fd.track, fd.animId, fd.parts, fd.origTrans)
                else
                    destroyTrack(fd.track)
                    if fd.model and fd.model.Parent then fd.model:Destroy() end
                end
                fadingModels[i], fadingModels[n], n = fadingModels[n], nil, n - 1
                self._fadingCount -= 1
                if self._fadingCount <= 0 and self._projectionComplete then self:_cleanupViewport() end
            else
                local eased = applyEasing(alpha, fd.style, fd.direction)
                local fdParts, fdOrig = fd.parts, fd.origTrans
                for pi = 1, fd.partCount do
                    local orig = fdOrig[pi]
                    if orig < 1 then fdParts[pi].Transparency = orig + (1 - orig) * eased end
                end
                i += 1
            end
        end
    end)
end

function Projection:_fadeModel(model, track, animId, cachedParts, cachedOrigTrans, cachedPartCount)
    if not model or not model.Parent then
        destroyTrack(track)
        return
    end

    if self.FadeTime <= 0 then
        if self.UseViewport and cachedParts then
            self:_poolModel(model, track, animId, cachedParts, cachedOrigTrans)
        else
            destroyTrack(track)
            model:Destroy()
        end
        return
    end

    local parts, origTrans, pn
    if cachedParts then
        parts, pn = cachedParts, cachedPartCount or #cachedParts
        origTrans = {}
        for pi = 1, pn do
            origTrans[pi] = parts[pi].Transparency
        end
    else
        parts, origTrans, pn = collectParts(model)
    end

    if pn == 0 then
        destroyTrack(track)
        model:Destroy()
        return
    end

    self._fadingCount += 1
    self._fadingModels[#self._fadingModels + 1] = {
        model = model, track = track, animId = animId,
        startTime = clock(), fadeTime = self.FadeTime,
        parts = parts, origTrans = cachedOrigTrans or origTrans, partCount = pn,
        style = self.FadeStyle, direction = self.FadeDirection
    }
    self:_startFadeProcessor()
end

function Projection:_cleanupViewport()
    if self._fadeConn then self._fadeConn:Disconnect() self._fadeConn = nil end
    for _, fd in self._fadingModels do
        destroyTrack(fd.track)
        if fd.model and fd.model.Parent then fd.model:Destroy() end
    end
    self:_drainPool()
    if self._screenGui and self._screenGui.Parent then self._screenGui:Destroy() end
    self._screenGui, self._viewport, self._worldModel, self._fadingModels, self._fadingCount = nil, nil, nil, {}, 0
end

function Projection:_shatter(proj, cachedParts)
    if not proj or not proj.Parent then return end
    local now, sc, sl, col, f = clock(), self.ShardCount, self.ShardLife, self.Color, ensureFolder()
    local partsList = cachedParts
    if not partsList then
        partsList = {}
        local pn = 0
        for _, v in proj:GetDescendants() do
            if v:IsA("BasePart") then pn += 1 partsList[pn] = v end
        end
    end
    for _, v in partsList do
        if v.Transparency >= 1 then continue end
        local cf, sz = v.CFrame, v.Size
        for _, d in getShardLayout(sz.X, sz.Y, sz.Z, sc) do
            local s = getShard()
            s.Size, s.Color, s.Transparency = d[2], col, 0.75
            s.CFrame = cf * CFrame.new(d[1]) * CFrame.new(random(-1, 1), random(-1, 1), random(-1, 1))
            s.Parent = f
            activeShards[#activeShards + 1] = {s, now, 0.75, s.CFrame, s.CFrame * d[3], d[2], sl}
        end
    end
    proj:Destroy()
end

function Projection:_applyPoseAndLock(model, track)
    if track then
        for _, motor in model:GetDescendants() do
            if motor:IsA("Motor6D") then
                local p0, p1 = motor.Part0, motor.Part1
                if p0 and p1 then
                    p1.CFrame = p0.CFrame * motor.C0 * motor.Transform * motor.C1:Inverse()
                end
            end
        end
        destroyTrack(track)
    end

    for _, v in model:GetDescendants() do
        if v:IsA("BasePart") then
            v.Anchored = true
            v.CanCollide = false
            v.CanQuery = false
            v.CanTouch = false
        end
    end

    local h = model:FindFirstChildWhichIsA("Humanoid")
    if h then h:Destroy() end
end

function Projection:_hideParts(parts, partCount)
    for i = 1, partCount do parts[i].Transparency = 1 end
end

function Projection:_showParts(parts, partCount, origTrans)
    if origTrans then
        for i = 1, partCount do parts[i].Transparency = origTrans[i] end
    else
        local tr = self.Transparency
        for i = 1, partCount do
            if parts[i].Name ~= "HumanoidRootPart" then parts[i].Transparency = tr end
        end
    end
end

function Projection:_hide(p)
    for _, v in p:GetDescendants() do if v:IsA("BasePart") then v.Transparency = 1 end end
end

function Projection:_show(p)
    local tr = self.Transparency
    for _, v in p:GetDescendants() do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.Transparency = tr end
    end
end

function Projection:_computePivots()
    local sp, ep, n, pf, pa = self.StartPosition, self.EndPosition, self.Frames, self.PathFunc, self.PathArgs
    local char = self.Player.Character
    sp = sp or (char and char:GetPivot() or CFrame.identity)
    ep = ep or sp * CFrame.new(0, 0, -8 * n * 0.1)
    local pivots, div, hasArgs = create(n), n > 1 and 1 / (n - 1) or 0, #pa > 0
    for i = 1, n do
        local t = (i - 1) * div
        pivots[i] = hasArgs and pf(t, sp, ep, unpack(pa)) or pf(t, sp, ep)
    end
    return pivots
end

function Projection:_computeAnimData(char)
    local n, data = self.Frames, create(self.Frames)

    if self.AnimationFunc then
        local maxN = max(1, n - 1)
        for i = 1, n do
            local animId, timePos = self.AnimationFunc(i, n, (i - 1) / maxN)
            data[i] = {animId, timePos}
        end
        return data
    end

    if #self._segments > 0 then
        sort(self._segments, function(a, b) return a.StartFrame < b.StartFrame end)
        for i = 1, n do
            local seg
            for _, s in ipairs(self._segments) do
                if i >= s.StartFrame and i <= s.EndFrame then seg = s break end
            end
            if seg then
                local segProgress = (i - seg.StartFrame) / max(1, seg.EndFrame - seg.StartFrame)
                if seg.Easing then segProgress = seg.Easing(segProgress) end
                local animLength = getAnimLength(char, seg.AnimationId)
                local timeStart, timeEnd = seg.TimeStart or 0, seg.TimeEnd or animLength
                local duration = (timeEnd - timeStart) * (seg.Speed or 1)
                local timePos = seg.Reverse and timeEnd - segProgress * duration or timeStart + segProgress * duration
                data[i] = {seg.AnimationId, max(0, min(timePos, animLength))}
            elseif i > 1 and data[i-1] then
                data[i] = {data[i-1][1], data[i-1][2]}
            else
                data[i] = {self.AnimationId or 0, 0}
            end
        end
        return data
    end

    if not self.AnimationId then
        for i = 1, n do data[i] = {0, 0} end
        return data
    end

    local animLength = getAnimLength(char, self.AnimationId)
    local timeStart, timeEnd = self.AnimationTimeStart or 0, self.AnimationTimeEnd or animLength
    local duration, reverse, maxN = (timeEnd - timeStart) * (self.AnimationSpeed or 1), self.AnimationReverse, max(1, n - 1)
    for i = 1, n do
        local progress = (i - 1) / maxN
        local timePos = reverse and timeEnd - progress * duration or timeStart + progress * duration
        data[i] = {self.AnimationId, max(0, min(timePos, animLength))}
    end
    return data
end

function Projection:AddSegment(seg)
    insert(self._segments, {
        AnimationId = seg.AnimationId or seg[1], StartFrame = seg.StartFrame or seg[2] or 1,
        EndFrame = seg.EndFrame or seg[3] or self.Frames, TimeStart = seg.TimeStart or seg[4] or 0,
        TimeEnd = seg.TimeEnd or seg[5], Reverse = seg.Reverse or seg[6] or false,
        Speed = seg.Speed or seg[7] or 1, Easing = seg.Easing or seg[8]
    })
    return self
end

function Projection:ClearSegments() self._segments = {} return self end
function Projection:SetAnimationFunc(func) self.AnimationFunc = func return self end

function Projection:SetAnimation(animId, timeStart, timeEnd, reverse, speed)
    self.AnimationId, self.AnimationTimeStart, self.AnimationTimeEnd = animId, timeStart or 0, timeEnd
    self.AnimationReverse, self.AnimationSpeed = reverse or false, speed or 1
    return self
end

Projection.TimeEasing = {
    Linear = function(t) return t end,
    EaseIn = function(t) return t * t end,
    EaseOut = function(t) return 1 - (1 - t) ^ 2 end,
    EaseInOut = function(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 * 0.5 end,
    Hold = function() return 0 end,
    HoldEnd = function() return 1 end,
    Step = function(steps) return function(t) return floor(t * steps) / steps end end,
    Ping = function(t) return t < 0.5 and t * 2 or 2 - t * 2 end,
    PingPong = function(cycles)
        cycles = cycles or 1
        return function(t) local phase = (t * cycles * 2) % 2 return phase < 1 and phase or 2 - phase end
    end
}

function Projection:GetPivots() return self._pivots end
function Projection:GetProjections() return self._projections end
function Projection:GetAnimData() return self._animData end
function Projection:SetPath(func, ...) self.PathFunc, self.PathArgs = func, {...} return self end
function Projection:SetStart(cf) self.StartPosition = cf return self end
function Projection:SetEnd(cf) self.EndPosition = cf return self end
function Projection:SetDuration(d) self.Duration = d return self end
function Projection:SetFrames(count) self.Frames = count return self end
function Projection:SetViewportMode(enabled) self.UseViewport = enabled return self end
function Projection:SetTrailMode(enabled) self.TrailMode = enabled return self end
function Projection:SetFade(time, style, direction)
    self.FadeTime, self.FadeStyle, self.FadeDirection = time or self.FadeTime, style or self.FadeStyle, direction or self.FadeDirection
    return self
end
function Projection:SetColor(color)
    self.Color = color
    if self.UseViewport then
        if self._viewport then self._viewport.ImageColor3 = color end
    else
        if self._template and self._template.Parent then
            for _, v in self._template:GetDescendants() do
                if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.Color = color end
            end
        end
        for _, entry in self._projections do
            if entry and entry.parts then
                for i = 1, entry.partCount do
                    local p = entry.parts[i]
                    if p.Name ~= "HumanoidRootPart" then p.Color = color end
                end
            end
        end
    end
    return self
end
function Projection:IsActive() return self._active end

function Projection:Play(callback)
    if self._active then return nil end
    local char = self.Player.Character
    if not char or not self:_isAlive(char) then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    self._active, self._projectionComplete = true, false
    local useViewport = self.UseViewport
    local trailMode = self.TrailMode

    if useViewport then self:_createViewport() end
    local template = useViewport and self:_buildViewportTemplate() or self:_buildTemplate()

    if not template then
        self._active = false
        if useViewport then self:_cleanupViewport() end
        return nil
    end
    self._template = template

    local animData = self:_computeAnimData(char)
    self._animData = animData

    local hasAnim = false
    for i = 1, #animData do
        if animData[i][1] and animData[i][1] ~= 0 then hasAnim = true break end
    end

    if not hasAnim then
        template:Destroy()
        if useViewport then self:_cleanupViewport() end
        self._active = false
        return nil
    end

    local n, pivots = self.Frames, self:_computePivots()
    self._pivots = pivots

    local vw = self.VisibleWindow
    local streaming = vw > 0 and n > vw * 2
    local bufferSize = streaming and min(vw + 12, n) or n
    local lookAhead = streaming and min(8, floor(vw * 0.5)) or 0
    local settleTime = self.SettleTime
    local instantSettle = settleTime <= 0
    local parentFolder = useViewport and self._worldModel or ensureFolder()

    self._maxPoolSize = useViewport and min(bufferSize + 10, 60) or 0

    local pool, frameToSlot, pendingSetup = create(bufferSize), {}, {}
    local currentTrailFloor = 0

    local function recycleSlot(slot)
        local entry = pool[slot]
        if not entry then return end
        if entry.model and entry.model.Parent then
            if useViewport then
                self:_fadeModel(entry.model, entry.track, entry.animId, entry.parts, entry.origTrans, entry.partCount)
                entry.track = nil
            else
                self:_shatter(entry.model, entry.parts)
                destroyTrack(entry.track)
            end
        else destroyTrack(entry.track) end
        if entry.frameIdx and entry.frameIdx > 0 then frameToSlot[entry.frameIdx] = nil end
        pendingSetup[slot], pool[slot] = nil, nil
    end

    local function getAvailableSlot(frameIdx)
        for i = 1, bufferSize do if not pool[i] then return i end end
        local evictBelow = trailMode and currentTrailFloor or frameIdx
        local best, bestSlot = math.huge, nil
        for i = 1, bufferSize do
            local entry = pool[i]
            if entry and entry.frameIdx < evictBelow and entry.frameIdx < best then best, bestSlot = entry.frameIdx, i end
        end
        if not bestSlot then return nil end
        recycleSlot(bestSlot)
        return bestSlot
    end

    local function createProjection(frameIdx)
        if frameIdx < 1 or frameIdx > n or frameToSlot[frameIdx] then return end
        local slot = getAvailableSlot(frameIdx)
        if not slot then return end

        local frameAnimData = animData[frameIdx]
        local animId, timePos = frameAnimData[1], frameAnimData[2]

        local p, tr, parts, origTrans, partCount
        local pooled = useViewport and self:_takeFromPool() or nil

        if pooled then
            p = pooled.model
            parts = pooled.parts
            origTrans = pooled.origTrans
            partCount = #parts
            p.Parent = parentFolder
            p:PivotTo(pivots[frameIdx])

            if animId and animId ~= 0 then
                tr = self:_setupViewportAnimation(p, animId, timePos, pooled.track, pooled.animId)
            else
                destroyTrack(pooled.track)
            end
        else
            p = template:Clone()
            if not p then return end
            p.Parent = parentFolder
            p:PivotTo(pivots[frameIdx])

            if animId and animId ~= 0 then
                if useViewport then
                    tr = self:_setupViewportAnimation(p, animId, timePos)
                else
                    tr = self:_getTrack(p, animId)
                    if tr then
                        tr:Play(0, 1, 0)
                        tr.TimePosition = timePos
                    end
                end
            end

            parts, origTrans, partCount = collectParts(p)
        end

        local ready = instantSettle
        local entry = {
            model = p, track = tr, frameIdx = frameIdx,
            animId = animId, timePos = timePos,
            ready = ready, visible = false, setupTime = clock(),
            parts = parts, origTrans = origTrans, partCount = partCount
        }

        pool[slot], frameToSlot[frameIdx] = entry, slot

        if not ready then
            pendingSetup[slot] = true
        end

        self:_hideParts(parts, partCount)
    end

    local function processSettled()
        if instantSettle then return end
        local now = clock()
        for slot in pairs(pendingSetup) do
            local entry = pool[slot]
            if entry and not entry.ready and (now - entry.setupTime) >= settleTime then
                if useViewport then
                    if entry.track then pcall(entry.track.AdjustSpeed, entry.track, 0) end
                else
                    self:_applyPoseAndLock(entry.model, entry.track)
                    entry.track = nil
                end
                entry.ready, pendingSetup[slot] = true, nil
            end
        end
    end

    local function showProjection(frameIdx)
        local slot = frameToSlot[frameIdx]
        if not slot then return end
        local entry = pool[slot]
        if entry and entry.ready and entry.model and not entry.visible then
            self:_showParts(entry.parts, entry.partCount, entry.origTrans)
            entry.visible = true
        end
    end

    local function shatterProjection(frameIdx)
        local slot = frameToSlot[frameIdx]
        if slot then recycleSlot(slot) end
    end

    local uniqueAnims = {}
    for i = 1, n do local aid = animData[i][1] if aid and aid ~= 0 then uniqueAnims[aid] = true end end
    if self.PlayAnimation then
        for aid in pairs(uniqueAnims) do
            local track = self:_getTrack(char, aid)
            if track then self._playerTracks[aid] = track end
        end
    end

    if self.AnchorPlayer then hrp.Anchored = true end

    local batchSize, createLimit = streaming and min(20, bufferSize) or 30, streaming and min(bufferSize, n) or n
    for i = 1, createLimit, batchSize do
        for j = i, min(i + batchSize - 1, createLimit) do createProjection(j) end
        if i + batchSize <= createLimit then RunService.Heartbeat:Wait() end
    end

    if not instantSettle then
        for _ = 1, max(6, floor(settleTime / 0.016) + 3) do RunService.Heartbeat:Wait() processSettled() end
    end

    if not trailMode then
        local initialVisible = streaming and min(vw, n) or n
        for i = 1, initialVisible do if vw <= 0 or i <= vw then showProjection(i) end end
    end

    self._projections = pool

    local duration, lastIdx, startTime = self.Duration, 0, clock()
    local interpolate = self.Interpolate
    local currentPlayerAnimId, currentPlayerTrack
    local draining = false
    local drainIdx, drainStart, drainStartTime, drainRate = 0, 0, 0, 0

    local function cleanup()
        for i = 1, bufferSize do
            local entry = pool[i]
            if entry then
                if entry.model and entry.model.Parent then
                    if useViewport then
                        self:_fadeModel(entry.model, entry.track, entry.animId, entry.parts, entry.origTrans, entry.partCount)
                        entry.track = nil
                    else entry.model:Destroy() destroyTrack(entry.track) end
                else destroyTrack(entry.track) end
                pool[i] = nil
            end
        end
        hrp.Anchored = false
        for _, track in pairs(self._playerTracks) do pcall(track.Stop, track) end
        self._playerTracks, self._active = {}, false
        if template and template.Parent then template:Destroy() end
        self._projectionComplete = true
        if useViewport and self._fadingCount <= 0 then self:_cleanupViewport() end
    end

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not self._active or not char.Parent or not self:_isAlive(char) then
            conn:Disconnect()
            self._conn = nil
            cleanup()
            return
        end

        if draining then
            local elapsed = clock() - drainStartTime
            local targetIdx = drainStart + floor(elapsed * drainRate)
            while drainIdx <= min(targetIdx, n) do
                shatterProjection(drainIdx)
                drainIdx += 1
            end
            if drainIdx > n then
                conn:Disconnect()
                self._conn = nil
                cleanup()
            end
            return
        end

        processSettled()
        local progress = (clock() - startTime) / duration

        if progress >= 1 then
            if self.MovePlayer then hrp.CFrame = pivots[n] end
            local finalAnimData = animData[n]
            if self.PlayAnimation and finalAnimData[1] and self._playerTracks[finalAnimData[1]] then
                local track = self._playerTracks[finalAnimData[1]]
                if not track.IsPlaying then
                    for aid, t in pairs(self._playerTracks) do if aid ~= finalAnimData[1] then pcall(t.Stop, t) end end
                    track:Play()
                    track:AdjustSpeed(0)
                end
                track.TimePosition = finalAnimData[2]
            end

            if trailMode and vw > 0 then
                for fIdx = max(1, lastIdx + 1), n do showProjection(fIdx) end
                if callback then callback(n, pool, pivots, animData) end
                draining = true
                drainStart = max(1, n - vw + 1)
                drainIdx = drainStart
                drainStartTime = clock()
                drainRate = max(1, n / duration)
                return
            end

            conn:Disconnect()
            self._conn = nil
            if trailMode then
                for fIdx = max(1, lastIdx + 1), n do showProjection(fIdx) end
            end
            if callback then callback(n, pool, pivots, animData) end
            task.defer(function() for i = 1, n do shatterProjection(i) end cleanup() end)
            return
        end

        local exactFrame = progress * (n - 1) + 1
        local currentIdx, fracPart = max(1, min(floor(exactFrame), n)), exactFrame - floor(exactFrame)

        if self.MovePlayer then
            hrp.CFrame = interpolate and currentIdx < n and pivots[currentIdx]:Lerp(pivots[currentIdx + 1], fracPart) or pivots[currentIdx]
        end

        if self.PlayAnimation then
            local currentAnimData, targetAnimId = animData[currentIdx], animData[currentIdx][1]
            if targetAnimId and targetAnimId ~= 0 then
                local track = self._playerTracks[targetAnimId]
                if targetAnimId ~= currentPlayerAnimId then
                    if currentPlayerTrack then pcall(currentPlayerTrack.Stop, currentPlayerTrack, 0.1) end
                    if track then track:Play(0.1) track:AdjustSpeed(0) currentPlayerTrack, currentPlayerAnimId = track, targetAnimId end
                end
                if track then
                    if not track.IsPlaying then track:Play(0, 1, 0) end
                    track:AdjustSpeed(0)
                    if interpolate then
                        local nextAnimData = currentIdx < n and animData[currentIdx + 1] or currentAnimData
                        track.TimePosition = currentAnimData[1] == nextAnimData[1] and currentAnimData[2] + (nextAnimData[2] - currentAnimData[2]) * fracPart or currentAnimData[2]
                    else track.TimePosition = currentAnimData[2] end
                end
            end
        end

        if currentIdx ~= lastIdx then
            if trailMode then
                currentTrailFloor = max(1, currentIdx - vw + 1)

                for fIdx = max(1, lastIdx + 1), currentIdx do
                    showProjection(fIdx)
                end

                if vw > 0 then
                    local expireBelow = currentIdx - vw
                    if expireBelow >= 1 then
                        local startExpire = lastIdx > 0 and max(1, lastIdx - vw + 1) or 1
                        for fIdx = startExpire, expireBelow do
                            shatterProjection(fIdx)
                        end
                    end
                end

                if streaming then
                    local createEnd = min(currentIdx + lookAhead, n)
                    for fIdx = currentIdx + 1, createEnd do
                        if not frameToSlot[fIdx] then createProjection(fIdx) end
                    end
                end
            else
                local shatterEnd = currentIdx - 1
                local showStart = currentIdx

                if interpolate and fracPart > 0.01 then
                    shatterEnd = currentIdx
                    showStart = currentIdx + 1
                end

                for fIdx = max(1, lastIdx), shatterEnd do shatterProjection(fIdx) end

                if streaming then
                    for fIdx = currentIdx, min(currentIdx + lookAhead + vw, n) do
                        if not frameToSlot[fIdx] then createProjection(fIdx) end
                    end
                    for fIdx = showStart, min(showStart + vw - 1, n) do showProjection(fIdx) end
                elseif vw > 0 then
                    local ri = currentIdx + vw - 1
                    if ri > vw and ri <= n then showProjection(ri) end
                end
            end

            if callback then callback(currentIdx, pool, pivots, animData) end
            lastIdx = currentIdx
        end

        if not trailMode and interpolate and fracPart > 0.01 then
            shatterProjection(currentIdx)
        end
    end)

    self._conn = conn
    return self
end

function Projection:Stop()
    self._active = false
    if self._conn then self._conn:Disconnect() self._conn = nil end
    local useViewport = self.UseViewport
    for _, entry in self._projections do
        if entry then
            if entry.model and entry.model.Parent then
                if useViewport then
                    self:_fadeModel(entry.model, entry.track, entry.animId, entry.parts, entry.origTrans, entry.partCount)
                    entry.track = nil
                else self:_shatter(entry.model, entry.parts) destroyTrack(entry.track) end
            else destroyTrack(entry.track) end
        end
    end
    self._projections = {}
    for _, track in pairs(self._playerTracks) do pcall(track.Stop, track) end
    self._playerTracks = {}
    local char = self.Player.Character
    if char then local hrp = char:FindFirstChild("HumanoidRootPart") if hrp then hrp.Anchored = false end end
    self._projectionComplete = true
    if useViewport and self._fadingCount <= 0 then self:_cleanupViewport() end
    return self
end

function Projection:Destroy()
    self:Stop()
    if self._template and self._template.Parent then self._template:Destroy() end
    self:_drainPool()
    self:_cleanupViewport()
    setmetatable(self, nil)
end

return Projection
