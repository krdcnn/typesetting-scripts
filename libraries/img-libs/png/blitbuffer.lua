local ffi = require("ffi")
local bit = require("bit")

-- we will use this extensively
local floor = math.floor
local rshift, lshift = bit.rshift, bit.lshift
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local intt, uint8pt = ffi.typeof("int"), ffi.typeof("uint8_t*")

-- the following definitions are redundant.
-- they need to be since only this way we can set
-- different metatables for them.
ffi.cdef [[
    typedef struct Color8 {
        uint8_t a;
    } Color8;
    typedef struct Color8A {
        uint8_t a;
        uint8_t alpha;
    } Color8A;
    typedef struct ColorRGB16 {
        uint16_t v;
    } ColorRGB16;
    typedef struct ColorRGB24 {
        uint8_t r;
        uint8_t g;
        uint8_t b;
    } ColorRGB24;
    typedef struct ColorRGB32 {
        uint8_t r;
        uint8_t g;
        uint8_t b;
        uint8_t alpha;
    } ColorRGB32;
    typedef struct BlitBuffer {
        int w;
        int h;
        int pitch;
        uint8_t *data;
        uint8_t config;
    } BlitBuffer;
    typedef struct BlitBuffer8 {
        int w;
        int h;
        int pitch;
        Color8 *data;
        uint8_t config;
    } BlitBuffer8;
    typedef struct BlitBuffer8A {
        int w;
        int h;
        int pitch;
        Color8A *data;
        uint8_t config;
    } BlitBuffer8A;
    typedef struct BlitBufferRGB16 {
        int w;
        int h;
        int pitch;
        ColorRGB16 *data;
        uint8_t config;
    } BlitBufferRGB16;
    typedef struct BlitBufferRGB24 {
        int w;
        int h;
        int pitch;
        ColorRGB24 *data;
        uint8_t config;
    } BlitBufferRGB24;
    typedef struct BlitBufferRGB32 {
        int w;
        int h;
        int pitch;
        ColorRGB32 *data;
        uint8_t config;
    } BlitBufferRGB32;
    void *malloc(int size);
    void free(void *ptr);
]]

-- color value types
local Color8 = ffi.typeof("Color8")
local Color8A = ffi.typeof("Color8A")
local ColorRGB16 = ffi.typeof("ColorRGB16")
local ColorRGB24 = ffi.typeof("ColorRGB24")
local ColorRGB32 = ffi.typeof("ColorRGB32")

-- metatables for color types:
local Color8_mt = {__index = {}}
local Color8A_mt = {__index = {}}
local ColorRGB16_mt = {__index = {}}
local ColorRGB24_mt = {__index = {}}
local ColorRGB32_mt = {__index = {}}

-- color setting
function Color8_mt.__index:set(color)
    self.a = color:getColor8().a
end

function Color8A_mt.__index:set(color)
    local c = color:getColor8A()
    self.a = c.a
    self.alpha = c.alpha
end

function ColorRGB16_mt.__index:set(color)
    self.v = color:getColorRGB16().v
end

function ColorRGB24_mt.__index:set(color)
    local c = color:getColorRGB24()
    self.r = c.r
    self.g = c.g
    self.b = c.b
end

function ColorRGB32_mt.__index:set(color)
    local c = color:getColorRGB32()
    self.r = c.r
    self.g = c.g
    self.b = c.b
    self.alpha = c.alpha
end

-- alpha blending (8bit alpha value):
local function div255(value)
    return rshift(value + intt(1) + rshift(value, 8), 8)
end

local function div4080(value)
    return rshift(value + intt(1) + rshift(value, 8), 12)
end

function Color8_mt.__index:blend(color)
    local alpha = color:getAlpha()
    -- simplified: we expect a 8bit grayscale "color" as parameter
    local value = div255(self.a * (intt(0xFF) - alpha) + color:getR() * alpha)
    self:set(Color8(value))
end

function Color8A_mt.__index:blend(color)
    local alpha = color:getAlpha()
    -- simplified: we expect a 8bit grayscale "color" as parameter
    local value = div255(self.a * (intt(0xFF) - alpha) + color:getR() * alpha)
    self:set(Color8A(value, self:getAlpha()))
end

function ColorRGB16_mt.__index:blend(color)
    local alpha = color:getAlpha()
    local ainv = intt(0xFF) - alpha
    local r = div255(self:getR() * ainv + color:getR() * alpha)
    local g = div255(self:getG() * ainv + color:getG() * alpha)
    local b = div255(self:getB() * ainv + color:getB() * alpha)
    self:set(ColorRGB24(r, g, b))
end

ColorRGB24_mt.__index.blend = ColorRGB16_mt.__index.blend
function ColorRGB32_mt.__index:blend(color)
    local alpha = color:getAlpha()
    local ainv = intt(0xFF) - alpha
    local r = div255(self:getR() * ainv + color:getR() * alpha)
    local g = div255(self:getG() * ainv + color:getG() * alpha)
    local b = div255(self:getB() * ainv + color:getB() * alpha)
    self:set(ColorRGB32(r, g, b, self:getAlpha()))
end

-- color conversions:
--[[
Uses luminance match for approximating the human perception of colour, as per
http://en.wikipedia.org/wiki/Grayscale#Converting_color_to_grayscale

L = 0.299*Red + 0.587*Green + 0.114*Blue
--]]
-- to Color8:

function Color8_mt.__index:getColor8()
    return self
end

function Color8A_mt.__index:getColor8()
    return Color8(self.a)
end

function ColorRGB16_mt.__index:getColor8()
    local r = rshift(self.v, 11)
    local g = band(rshift(self.v, 5), 0x3F)
    local b = band(self.v, 0x001F)
    return Color8(rshift(39190 * r + 38469 * g + 14942 * b, 14))
end

function ColorRGB24_mt.__index:getColor8()
    return Color8(rshift(4897 * self:getR() + 9617 * self:getG() + 1868 * self:getB(), 14))
end
ColorRGB32_mt.__index.getColor8 = ColorRGB24_mt.__index.getColor8

-- to Color8A:
function Color8_mt.__index:getColor8A()
    return Color8A(self.a, 0)
end

function Color8A_mt.__index:getColor8A()
    return self
end

function ColorRGB16_mt.__index:getColor8A()
    local r = rshift(self.v, 11)
    local g = band(rshift(self.v, 5), 0x3F)
    local b = band(self.v, 0x001F)
    return Color8A(rshift(39190 * r + 38469 * g + 14942 * b, 14), 0)
end

function ColorRGB24_mt.__index:getColor8A()
    return Color8A(rshift(4897 * self:getR() + 9617 * self:getG() + 1868 * self:getB(), 14), 0)
end

function ColorRGB32_mt.__index:getColor8A()
    return Color8A(rshift(4897 * self:getR() + 9617 * self:getG() + 1868 * self:getB(), 14), self:getAlpha())
end

-- to ColorRGB16:
function Color8_mt.__index:getColorRGB16()
    local v = self:getColor8().a
    local v5bit = rshift(v, 3)
    return ColorRGB16(lshift(v5bit, 11) + lshift(band(v, 0xFC), 3) + v5bit)
end

Color8A_mt.__index.getColorRGB16 = Color8_mt.__index.getColorRGB16
function ColorRGB16_mt.__index:getColorRGB16()
    return self
end

function ColorRGB24_mt.__index:getColorRGB16()
    return ColorRGB16(lshift(band(self.r, 0xF8), 8) + lshift(band(self.g, 0xFC), 3) + rshift(self.b, 3))
end
ColorRGB32_mt.__index.getColorRGB16 = ColorRGB24_mt.__index.getColorRGB16

-- to ColorRGB24:
function Color8_mt.__index:getColorRGB24()
    local v = self:getColor8()
    return ColorRGB24(v.a, v.a, v.a)
end
Color8A_mt.__index.getColorRGB24 = Color8_mt.__index.getColorRGB24

function ColorRGB16_mt.__index:getColorRGB24()
    local r = rshift(self.v, 11)
    local g = band(rshift(self.v, 5), 0x3F)
    local b = band(self.v, 0x001F)
    return ColorRGB24(lshift(r, 3) + rshift(r, 2), lshift(g, 2) + rshift(g, 4), lshift(b, 3) + rshift(b, 2))
end

function ColorRGB24_mt.__index:getColorRGB24()
    return self
end

function ColorRGB32_mt.__index:getColorRGB24()
    return ColorRGB24(self.r, self.g, self.b)
end

-- to ColorRGB32:
function Color8_mt.__index:getColorRGB32()
    return ColorRGB32(self.a, self.a, self.a, 0xFF)
end

function Color8A_mt.__index:getColorRGB32()
    return ColorRGB32(self.a, self.a, self.a, self.alpha)
end

function ColorRGB16_mt.__index:getColorRGB32()
    local r = rshift(self.v, 11)
    local g = band(rshift(self.v, 5), 0x3F)
    local b = band(self.v, 0x001F)
    return ColorRGB32(lshift(r, 3) + rshift(r, 2), lshift(g, 2) + rshift(g, 4), lshift(b, 3) + rshift(b, 2), 0xFF)
end

function ColorRGB24_mt.__index:getColorRGB32()
    return ColorRGB32(self.r, self.g, self.b, 0xFF)
end

function ColorRGB32_mt.__index:getColorRGB32()
    return self
end

-- RGB getters (special case for 4bpp mode)
function Color8_mt.__index:getR()
    return self:getColor8().a
end

Color8_mt.__index.getG = Color8_mt.__index.getR
Color8_mt.__index.getB = Color8_mt.__index.getR

function Color8_mt.__index:getAlpha()
    return intt(0xFF)
end

Color8A_mt.__index.getR = Color8_mt.__index.getR
Color8A_mt.__index.getG = Color8_mt.__index.getR
Color8A_mt.__index.getB = Color8_mt.__index.getR

function Color8A_mt.__index:getAlpha()
    return self.alpha
end

function ColorRGB16_mt.__index:getR()
    local r = rshift(self.v, 11)
    return lshift(r, 3) + rshift(r, 2)
end

function ColorRGB16_mt.__index:getG()
    local g = band(rshift(self.v, 5), 0x3F)
    return lshift(g, 2) + rshift(g, 4)
end

function ColorRGB16_mt.__index:getB()
    local b = band(self.v, 0x001F)
    return lshift(b, 3) + rshift(b, 2)
end
ColorRGB16_mt.__index.getAlpha = Color8_mt.__index.getAlpha

function ColorRGB24_mt.__index:getR()
    return self.r
end

function ColorRGB24_mt.__index:getG()
    return self.g
end

function ColorRGB24_mt.__index:getB()
    return self.b
end

ColorRGB24_mt.__index.getAlpha = Color8_mt.__index.getAlpha
ColorRGB32_mt.__index.getR = ColorRGB24_mt.__index.getR
ColorRGB32_mt.__index.getG = ColorRGB24_mt.__index.getG
ColorRGB32_mt.__index.getB = ColorRGB24_mt.__index.getB

function ColorRGB32_mt.__index:getAlpha()
    return self.alpha
end

-- modifications:
-- inversion:
function Color8_mt.__index:invert()
    return Color8(bxor(self.a, 0xFF))
end

function Color8A_mt.__index:invert()
    return Color8A(bxor(self.a, 0xFF), self.alpha)
end

function ColorRGB16_mt.__index:invert()
    return ColorRGB16(bxor(self.v, 0xFFFF))
end

function ColorRGB24_mt.__index:invert()
    return ColorRGB24(bxor(self.r, 0xFF), bxor(self.g, 0xFF), bxor(self.b, 0xFF))
end

function ColorRGB32_mt.__index:invert()
    return ColorRGB32(bxor(self.r, 0xFF), bxor(self.g, 0xFF), bxor(self.b, 0xFF), self.alpha)
end

-- comparison:
function ColorRGB32_mt:__eq(c)
    c = c:getColorRGB32()
    return (self:getR() == c:getR()) and (self:getG() == c:getG()) and (self:getB() == c:getB()) and
               (self:getAlpha() == c:getAlpha())
end
Color8_mt.__eq = ColorRGB32_mt.__eq
Color8A_mt.__eq = ColorRGB32_mt.__eq
ColorRGB16_mt.__eq = ColorRGB32_mt.__eq
ColorRGB24_mt.__eq = ColorRGB32_mt.__eq

-- pretty printing
function Color8_mt:__tostring()
    return "Color8(" .. self.a .. ")"
end

function Color8A_mt:__tostring()
    return "Color8A(" .. self.a .. ", " .. self.alpha .. ")"
end

function ColorRGB16_mt:__tostring()
    return "ColorRGB16(" .. self:getR() .. ", " .. self:getG() .. ", " .. self:getB() .. ")"
end

function ColorRGB24_mt:__tostring()
    return "ColorRGB24(" .. self:getR() .. ", " .. self:getG() .. ", " .. self:getB() .. ")"
end

function ColorRGB32_mt:__tostring()
    return "ColorRGB32(" .. self:getR() .. ", " .. self:getG() .. ", " .. self:getB() .. ", " .. self:getAlpha() .. ")"
end

local MASK_ALLOCATED = 0x01
local SHIFT_ALLOCATED = 0
local MASK_INVERSE = 0x02
local SHIFT_INVERSE = 1
local MASK_ROTATED = 0x0C
local SHIFT_ROTATED = 2
local MASK_TYPE = 0xF0
local SHIFT_TYPE = 4

local TYPE_BB8 = 1
local TYPE_BB8A = 2
local TYPE_BBRGB16 = 3
local TYPE_BBRGB24 = 4
local TYPE_BBRGB32 = 5

local BB = {}

-- metatables for BlitBuffer objects:
local BB8_mt = {__index = {}}
local BB8A_mt = {__index = {}}
local BBRGB16_mt = {__index = {}}
local BBRGB24_mt = {__index = {}}
local BBRGB32_mt = {__index = {}}

-- this is like a metatable for the others,
-- but we don't make it a metatable because LuaJIT
-- doesn't cope well with ctype metatables with
-- metatables on them
-- we just replicate what's in the following table
-- when we set the other metatables for their types
local BB_mt = {__index = {}}

function BB_mt.__index:getRotation()
    return rshift(band(MASK_ROTATED, self.config), SHIFT_ROTATED)
end

function BB_mt.__index:setRotation(rotation_mode)
    self.config = bor(band(self.config, bxor(MASK_ROTATED, 0xFF)), lshift(rotation_mode, SHIFT_ROTATED))
end

function BB_mt.__index:rotateAbsolute(degree)
    local mode = (degree % 360) / 90
    self:setRotation(mode)
    return self
end

function BB_mt.__index:rotate(degree)
    degree = degree + self:getRotation() * 90
    return self:rotateAbsolute(degree)
end

function BB_mt.__index:getInverse()
    return rshift(band(MASK_INVERSE, self.config), SHIFT_INVERSE)
end

function BB_mt.__index:setInverse(inverse)
    self.config = bor(band(self.config, bxor(MASK_INVERSE, 0xFF)), lshift(inverse, SHIFT_INVERSE))
end

function BB_mt.__index:invert()
    self:setInverse((self:getInverse() + 1) % 2)
    return self
end

function BB_mt.__index:getAllocated()
    return rshift(band(MASK_ALLOCATED, self.config), SHIFT_ALLOCATED)
end

function BB_mt.__index:setAllocated(allocated)
    self.config = bor(band(self.config, bxor(MASK_ALLOCATED, 0xFF)), lshift(allocated, SHIFT_ALLOCATED))
end

function BB_mt.__index:getType()
    return rshift(band(MASK_TYPE, self.config), SHIFT_TYPE)
end

function BB8_mt.__index:getBpp()
    return 8
end

function BB8A_mt.__index:getBpp()
    return 8
end

function BBRGB16_mt.__index:getBpp()
    return 16
end

function BBRGB24_mt.__index:getBpp()
    return 24
end

function BBRGB32_mt.__index:getBpp()
    return 32
end

function BB_mt.__index:isRGB()
    local bb_type = self:getType()
    if bb_type == TYPE_BBRGB16 or bb_type == TYPE_BBRGB24 or bb_type == TYPE_BBRGB32 then
        return true
    end
    return false
end

function BB_mt.__index:setType(type_id)
    self.config = bor(band(self.config, bxor(MASK_TYPE, 0xFF)), lshift(type_id, SHIFT_TYPE))
end

function BB_mt.__index:getPhysicalCoordinates(x, y)
    local rotation = self:getRotation()
    if rotation == 0 then
        return x, y
    elseif rotation == 1 then
        return self.w - y - 1, x
    elseif rotation == 2 then
        return self.w - x - 1, self.h - y - 1
    elseif rotation == 3 then
        return y, self.h - x - 1
    end
end

function BB_mt.__index:getPhysicalRect(x, y, w, h)
    local px1, py1 = self:getPhysicalCoordinates(x, y)
    local px2, py2 = self:getPhysicalCoordinates(x + w - 1, y + h - 1)
    if self:getRotation() % 2 == 1 then
        w, h = h, w
    end
    return math.min(px1, px2), math.min(py1, py2), w, h
end

-- physical coordinate checking
function BB_mt.__index:checkCoordinates(x, y)
    assert(x >= 0, "x coordinate >= 0")
    assert(y >= 0, "y coordinate >= 0")
    assert(x < self:getWidth(), "x coordinate < width")
    assert(y < self:getHeight(), "y coordinate < height")
end

-- getPixelP (pointer) routines, working on physical coordinates
function BB_mt.__index:getPixelP(x, y)
    -- self:checkCoordinates(x, y)
    return ffi.cast(self.data, ffi.cast(uint8pt, self.data) + self.pitch * y) + x
end

function BB_mt.__index:getPixel(x, y)
    local px, py = self:getPhysicalCoordinates(x, y)
    local color = self:getPixelP(px, py)[0]
    if self:getInverse() == 1 then
        color = color:invert()
    end
    return color
end

-- blitbuffer specific color conversions
function BB8_mt.__index.getMyColor(color)
    return color:getColor8()
end

function BB8A_mt.__index.getMyColor(color)
    return color:getColor8A()
end

function BBRGB16_mt.__index.getMyColor(color)
    return color:getColorRGB16()
end

function BBRGB24_mt.__index.getMyColor(color)
    return color:getColorRGB24()
end

function BBRGB32_mt.__index.getMyColor(color)
    return color:getColorRGB32()
end

-- set pixel values
function BB_mt.__index:setPixel(x, y, color)
    local px, py = self:getPhysicalCoordinates(x, y)
    if not use_cblitbuffer and self:getInverse() == 1 then
        color = color:invert()
    end
    self:getPixelP(px, py)[0]:set(color)
end

function BB_mt.__index:setPixelAdd(x, y, color, alpha)
    -- fast path:
    if alpha == 0 then
        return
    elseif alpha == 0xFF then
        return self:setPixel(x, y, color)
    end
    -- this method works with a grayscale value
    local px, py = self:getPhysicalCoordinates(x, y)
    color = color:getColor8A()
    if self:getInverse() == 1 then
        color = color:invert()
    end
    color.alpha = alpha
    self:getPixelP(px, py)[0]:blend(color)
end

function BBRGB16_mt.__index:setPixelAdd(x, y, color, alpha)
    -- fast path:
    if alpha == 0 then
        return
    elseif alpha == 0xFF then
        return self:setPixel(x, y, color)
    end
    -- this method uses a RGB color value
    local px, py = self:getPhysicalCoordinates(x, y)
    if self:getInverse() == 1 then
        color = color:invert()
    end
    color = color:getColorRGB32()
    color.alpha = alpha
    self:getPixelP(px, py)[0]:blend(color)
end

BBRGB24_mt.__index.setPixelAdd = BBRGB16_mt.__index.setPixelAdd
BBRGB32_mt.__index.setPixelAdd = BBRGB16_mt.__index.setPixelAdd
function BB_mt.__index:setPixelBlend(x, y, color)
    local px, py = self:getPhysicalCoordinates(x, y)
    if self:getInverse() == 1 then
        color = color:invert()
    end
    self:getPixelP(px, py)[0]:blend(color)
end

function BB_mt.__index:setPixelColorize(x, y, mask, color)
    -- use 8bit grayscale pixel value as alpha for blitting
    local alpha = mask:getColor8().a
    -- fast path:
    if alpha == 0 then
        return
    end
    local px, py = self:getPhysicalCoordinates(x, y)
    if alpha == 0xFF then
        self:getPixelP(px, py)[0]:set(color)
    else
        color.alpha = alpha
        self:getPixelP(px, py)[0]:blend(color)
    end
end

function BB_mt.__index:setPixelInverted(x, y, color)
    self:setPixel(x, y, color:invert())
end

-- checked Pixel setting:
function BB_mt.__index:setPixelClamped(x, y, color)
    if x >= 0 and x < self:getWidth() and y >= 0 and y < self:getHeight() then
        self:setPixel(x, y, color)
    end
end

-- functions for accessing dimensions
function BB_mt.__index:getWidth()
    if 0 == bit.band(1, self:getRotation()) then
        return self.w
    else
        return self.h
    end
end

function BB_mt.__index:getHeight()
    if 0 == bit.band(1, self:getRotation()) then
        return self.h
    else
        return self.w
    end
end

-- names of optimized blitting routines
BB_mt.__index.blitfunc = "blitDefault" -- not optimized
BB8_mt.__index.blitfunc = "blitTo8"
BB8A_mt.__index.blitfunc = "blitTo8A"
BBRGB16_mt.__index.blitfunc = "blitToRGB16"
BBRGB24_mt.__index.blitfunc = "blitToRGB24"
BBRGB32_mt.__index.blitfunc = "blitToRGB32"

--[[
    generic boundary check for copy operations

    @param length length of copy operation
    @param target_offset where to place part into target
    @param source_offset where to take part from in source
    @param target_size length of target buffer
    @param source_size length of source buffer

    @return adapted length that actually fits
    @return adapted target offset, guaranteed within range 0..(target_size-1)
    @return adapted source offset, guaranteed within range 0..(source_size-1)
--]]

function BB.checkBounds(length, target_offset, source_offset, target_size, source_size)
    -- deal with negative offsets
    if target_offset < 0 then
        length = length + target_offset
        source_offset = source_offset - target_offset
        target_offset = 0
    end
    if source_offset < 0 then
        length = length + source_offset
        target_offset = target_offset - source_offset
        source_offset = 0
    end
    -- calculate maximum lengths (size left starting at offset)
    local target_left = target_size - target_offset
    local source_left = source_size - source_offset
    -- return corresponding values
    if target_left <= 0 or source_left <= 0 then
        return 0, 0, 0
    elseif length <= target_left and length <= source_left then
        -- length is the smallest value
        return floor(length), floor(target_offset), floor(source_offset)
    elseif target_left < length and target_left < source_left then
        -- target_left is the smalles value
        return floor(target_left), floor(target_offset), floor(source_offset)
    else
        -- source_left must be the smallest value
        return floor(source_left), floor(target_offset), floor(source_offset)
    end
end

function BB_mt.__index:blitDefault(dest, dest_x, dest_y, offs_x, offs_y, width, height, setter, set_param)
    -- slow default variant:
    local o_y = offs_y
    for y = dest_y, dest_y + height - 1 do
        local o_x = offs_x
        for x = dest_x, dest_x + width - 1 do
            setter(dest, x, y, self:getPixel(o_x, o_y), set_param)
            o_x = o_x + 1
        end
        o_y = o_y + 1
    end
end

-- no optimized blitting by default:
BB_mt.__index.blitTo4 = BB_mt.__index.blitDefault
BB_mt.__index.blitTo8 = BB_mt.__index.blitDefault
BB_mt.__index.blitTo8A = BB_mt.__index.blitDefault
BB_mt.__index.blitToRGB16 = BB_mt.__index.blitDefault
BB_mt.__index.blitToRGB24 = BB_mt.__index.blitDefault
BB_mt.__index.blitToRGB32 = BB_mt.__index.blitDefault

function BB_mt.__index:blitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height, setter, set_param)
    width, height = width or source:getWidth(), height or source:getHeight()
    width, dest_x, offs_x = BB.checkBounds(width, dest_x or 0, offs_x or 0, self:getWidth(), source:getWidth())
    height, dest_y, offs_y = BB.checkBounds(height, dest_y or 0, offs_y or 0, self:getHeight(), source:getHeight())
    if width <= 0 or height <= 0 then
        return
    end
    if not setter then
        setter = self.setPixel
    end
    source[self.blitfunc](source, self, dest_x, dest_y, offs_x, offs_y, width, height, setter, set_param)
end
BB_mt.__index.blitFullFrom = BB_mt.__index.blitFrom

-- blitting with a per-blit alpha value
function BB_mt.__index:addblitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height, intensity)
    width, height = width or source:getWidth(), height or source:getHeight()
    width, dest_x, offs_x = BB.checkBounds(width, dest_x or 0, offs_x or 0, self:getWidth(), source:getWidth())
    height, dest_y, offs_y = BB.checkBounds(height, dest_y or 0, offs_y or 0, self:getHeight(), source:getHeight())
    if width <= 0 or height <= 0 then
        return
    end
    self:blitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height, self.setPixelAdd, intt(intensity * 0xFF))
end

-- alpha-pane aware blitting
function BB_mt.__index:alphablitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height)
    width, height = width or source:getWidth(), height or source:getHeight()
    width, dest_x, offs_x = BB.checkBounds(width, dest_x or 0, offs_x or 0, self:getWidth(), source:getWidth())
    height, dest_y, offs_y = BB.checkBounds(height, dest_y or 0, offs_y or 0, self:getHeight(), source:getHeight())
    if width <= 0 or height <= 0 then
        return
    end
    self:blitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height, self.setPixelBlend)
end

-- invert blitting
function BB_mt.__index:invertblitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height)
    width, height = width or source:getWidth(), height or source:getHeight()
    width, dest_x, offs_x = BB.checkBounds(width, dest_x or 0, offs_x or 0, self:getWidth(), source:getWidth())
    height, dest_y, offs_y = BB.checkBounds(height, dest_y or 0, offs_y or 0, self:getHeight(), source:getHeight())
    if width <= 0 or height <= 0 then
        return
    end
    self:blitFrom(self, dest_x, dest_y, offs_x, offs_y, width, height, self.setPixelInverted)
end

-- colorize area using source blitbuffer as a alpha-map
function BB_mt.__index:colorblitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height, color)
    -- we need color with alpha later:
    color = color:getColorRGB32()
    if self:getInverse() == 1 then
        color = color:invert()
    end
    self:blitFrom(source, dest_x, dest_y, offs_x, offs_y, width, height, self.setPixelColorize, color)
end

local function sinc(x)
    if x == 0 then
        return 1
    else
        return math.sin(x * math.pi) / (math.pi * x)
    end
end

local function lanczos(x, a)
    if x > -a and x < a then
        return sinc(x) * sinc(x / a)
    else
        return 0
    end
end

local function filter2d(kernel, A)
    return function(src, x, y)
        local r, g, b, a = 0, 0, 0, 0
        for i = math.floor(x) - A + 1, math.floor(x) + A do
            if i >= 0 and i < src:getWidth() then
                for j = math.floor(y) - A + 1, math.floor(y) + A do
                    if j >= 0 and j < src:getHeight() then
                        local v = src:getPixel(i, j):getColorRGB32()
                        local k = kernel(math.sqrt((x - i) ^ 2 + (y - j) ^ 2), A)
                        r = r + v.r * k
                        g = g + v.g * k
                        b = b + v.b * k
                        a = a + v.alpha * k
                    end
                end
            end
        end
        if r < 0 then
            r = 0
        end
        if g < 0 then
            g = 0
        end
        if b < 0 then
            b = 0
        end
        if a < 0 then
            a = 0
        end
        if r > 0xFF then
            r = 0xFF
        end
        if g > 0xFF then
            g = 0xFF
        end
        if b > 0xFF then
            b = 0xFF
        end
        if a > 0xFF then
            a = 0xFF
        end
        return ColorRGB32(r, g, b, a)
    end
end
BB.lanczos2 = filter2d(lanczos, 2)
BB.lanczos3 = filter2d(lanczos, 3)
local transparentblack = ColorRGB32(0, 0, 0, 0)
function BB.bilinear(src, x, y)
    local x_low, x_high = math.floor(x), math.floor(x) + 1
    local y_low, y_high = math.floor(y), math.floor(y) + 1
    local top_l, top_r, bottom_l, bottom_r = transparentblack, transparentblack, transparentblack, transparentblack
    if x_low >= 0 and x_low < src:getWidth() then
        if y_low >= 0 and y_low < src:getHeight() then
            top_l = src:getPixel(x_low, y_low):getColorRGB32()
        end
        if y_high >= 0 and y_high < src:getHeight() then
            bottom_l = src:getPixel(x_low, y_high):getColorRGB32()
        end
    end
    if x_high >= 0 and x_high < src:getWidth() then
        if y_low >= 0 and y_low < src:getHeight() then
            top_r = src:getPixel(x_high, y_low):getColorRGB32()
        end
        if y_high >= 0 and y_high < src:getHeight() then
            bottom_r = src:getPixel(x_high, y_high):getColorRGB32()
        end
    end
    local f_x = x - x_low
    local f_y = y - y_low
    local Rtop = top_l:getR() * (1 - f_x) + top_r:getR() * f_x
    local Rbottom = bottom_l:getR() * (1 - f_x) + bottom_r:getR() * f_x
    local Gtop = top_l:getG() * (1 - f_x) + top_r:getG() * f_x
    local Gbottom = bottom_l:getG() * (1 - f_x) + bottom_r:getG() * f_x
    local Btop = top_l:getB() * (1 - f_x) + top_r:getB() * f_x
    local Bbottom = bottom_l:getB() * (1 - f_x) + bottom_r:getB() * f_x
    local Alphatop = top_l:getAlpha() * (1 - f_x) + top_r:getAlpha() * f_x
    local Alphabottom = bottom_l:getAlpha() * (1 - f_x) + bottom_r:getAlpha() * f_x
    return ColorRGB32(Rtop * (1 - f_y) + Rbottom * f_y, Gtop * (1 - f_y) + Gbottom * f_y, Btop * (1 - f_y) + Bbottom * f_y, Alphatop * (1 - f_y) + Alphabottom * f_y)
end

function BB.by_matrix(matrix)
    local invm = -matrix
    return function(x, y)
        return invm:apply(x, y)
    end
end

function BB_mt.__index:blitFromTransformed(source, transformation, filter, dest_x, dest_y, width, height, setter,
    set_param)
    width, height = width or self:getWidth(), height or self:getHeight()
    dest_x, dest_y = dest_x or 0, dest_y or 0
    if not setter then
        setter = self.setPixel
    end
    for y = dest_y, dest_y + height - 1 do
        for x = dest_x, dest_x + width - 1 do
            local src_x, src_y = transformation(x, y)
            setter(self, x, y, filter(source, src_x, src_y), set_param)
        end
    end
end

-- scale method does not modify the original blitbuffer, instead, it allocates
-- and returns a new scaled blitbuffer.
function BB_mt.__index:scale(new_width, new_height)
    local self_w, self_h = self:getWidth(), self:getHeight()
    local scaled_bb = BB.new(new_width, new_height, self:getType())
    -- uses very simple nearest neighbour scaling
    for y = 0, new_height - 1 do
        for x = 0, new_width - 1 do
            scaled_bb:setPixel(x, y, self:getPixel(floor(x * self_w / new_width), floor(y * self_h / new_height)))
        end
    end
    return scaled_bb
end

-- rotatedCopy method, unlike rotate method, does not modify the original
-- blitbuffer, instead, it allocates and returns a new rotated blitbuffer.
function BB_mt.__index:rotatedCopy(degree)
    self:rotate(degree) -- rotate in-place
    local rot_w, rot_h = self:getWidth(), self:getHeight()
    local rot_bb = BB.new(rot_w, rot_h, self:getType())
    rot_bb:blitFrom(self, 0, 0, 0, 0, rot_w, rot_h)
    self:rotate(-degree) -- revert in-place rotation
    return rot_bb
end

--[[
    explicit unset

    will free resources immediately
    this is also called upon garbage collection
--]]

function BB_mt.__index:free()
    if band(lshift(1, SHIFT_ALLOCATED), self.config) ~= 0 then
        self.config = band(self.config, bxor(0xFF, lshift(1, SHIFT_ALLOCATED)))
        ffi.C.free(self.data)
    end
end

--[[
    memory management
--]]

BB_mt.__gc = BB_mt.__index.free

--[[
    PAINTING
--]]

--[[
    fill the whole blitbuffer with a given color value
--]]

function BB_mt.__index:fill(value)
    local w = self:getWidth()
    local h = self:getHeight()
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            self:setPixel(x, y, value)
        end
    end
end

function BB8_mt.__index:fill(value)
    ffi.fill(self.data, self.pitch * self.h, value:getColor8().a)
end

--[[
    invert a rectangle within the buffer

    @param x X coordinate
    @param y Y coordinate
    @param w width
    @param h height
--]]

function BB_mt.__index:invertRect(x, y, w, h)
    self:invertblitFrom(self, x, y, x, y, w, h)
end

--[[
    paint a rectangle onto this buffer

    @param x X coordinate
    @param y Y coordinate
    @param w width
    @param h height
    @param value color value
    @param setter function used to set pixels (defaults to normal setPixel)
--]]

function BB_mt.__index:paintRect(x, y, w, h, value, setter)
    if w <= 0 or h <= 0 then
        return
    end
    setter = setter or self.setPixel
    value = value or Color8(0)
    w, x = BB.checkBounds(w, x, 0, self:getWidth(), 0xFFFF)
    h, y = BB.checkBounds(h, y, 0, self:getHeight(), 0xFFFF)
    for tmp_y = y, y + h - 1 do
        for tmp_x = x, x + w - 1 do
            setter(self, tmp_x, tmp_y, value)
        end
    end
end

--[[
    paint a circle onto this buffer

    @param x1 X coordinate of the circle's center
    @param y1 Y coordinate of the circle's center
    @param r radius
    @param c color value (defaults to black)
    @param w width of line (defaults to radius)
--]]

function BB_mt.__index:paintCircle(center_x, center_y, r, c, w)
    c = c or Color8(0)
    if r == 0 then
        return
    end
    if w == nil then
        w = r
    end
    if w > r then
        w = r
    end
    -- for outer circle
    local x = 0
    local y = r
    local delta = 5 / 4 - r
    -- for inner circle
    local r2 = r - w
    local x2 = 0
    local y2 = r2
    local delta2 = 5 / 4 - r
    -- draw two axles
    for tmp_y = r, r2 + 1, -1 do
        self:setPixelClamped(center_x + 0, center_y + tmp_y, c)
        self:setPixelClamped(center_x - 0, center_y - tmp_y, c)
        self:setPixelClamped(center_x + tmp_y, center_y + 0, c)
        self:setPixelClamped(center_x - tmp_y, center_y - 0, c)
    end
    while x < y do
        -- decrease y if we are out of circle
        x = x + 1;
        if delta > 0 then
            y = y - 1
            delta = delta + 2 * x - 2 * y + 2
        else
            delta = delta + 2 * x + 1
        end
        -- inner circle finished drawing, increase y linearly for filling
        if x2 > y2 then
            y2 = y2 + 1
            x2 = x2 + 1
        else
            x2 = x2 + 1
            if delta2 > 0 then
                y2 = y2 - 1
                delta2 = delta2 + 2 * x2 - 2 * y2 + 2
            else
                delta2 = delta2 + 2 * x2 + 1
            end
        end
        for tmp_y = y, y2 + 1, -1 do
            self:setPixelClamped(center_x + x, center_y + tmp_y, c)
            self:setPixelClamped(center_x + tmp_y, center_y + x, c)
            self:setPixelClamped(center_x + tmp_y, center_y - x, c)
            self:setPixelClamped(center_x + x, center_y - tmp_y, c)
            self:setPixelClamped(center_x - x, center_y - tmp_y, c)
            self:setPixelClamped(center_x - tmp_y, center_y - x, c)
            self:setPixelClamped(center_x - tmp_y, center_y + x, c)
            self:setPixelClamped(center_x - x, center_y + tmp_y, c)
        end
    end
    if r == w then
        self:setPixelClamped(center_x, center_y, c)
    end
end

function BB_mt.__index:paintRoundedCorner(off_x, off_y, w, h, bw, r, c)
    if 2 * r > h or 2 * r > w or r == 0 then
        -- no operation
        return
    end
    r = math.min(r, h, w)
    if bw > r then
        bw = r
    end
    -- for outer circle
    local x = 0
    local y = r
    local delta = 5 / 4 - r
    -- for inner circle
    local r2 = r - bw
    local x2 = 0
    local y2 = r2
    local delta2 = 5 / 4 - r
    while x < y do
        -- decrease y if we are out of circle
        x = x + 1
        if delta > 0 then
            y = y - 1
            delta = delta + 2 * x - 2 * y + 2
        else
            delta = delta + 2 * x + 1
        end
        -- inner circle finished drawing, increase y linearly for filling
        if x2 > y2 then
            y2 = y2 + 1
            x2 = x2 + 1
        else
            x2 = x2 + 1
            if delta2 > 0 then
                y2 = y2 - 1
                delta2 = delta2 + 2 * x2 - 2 * y2 + 2
            else
                delta2 = delta2 + 2 * x2 + 1
            end
        end
        for tmp_y = y, y2 + 1, -1 do
            self:setPixelClamped((w - r) + off_x + x - 1, (h - r) + off_y + tmp_y - 1, c)
            self:setPixelClamped((w - r) + off_x + tmp_y - 1, (h - r) + off_y + x - 1, c)
            self:setPixelClamped((w - r) + off_x + tmp_y - 1, (r) + off_y - x, c)
            self:setPixelClamped((w - r) + off_x + x - 1, (r) + off_y - tmp_y, c)
            self:setPixelClamped((r) + off_x - x, (r) + off_y - tmp_y, c)
            self:setPixelClamped((r) + off_x - tmp_y, (r) + off_y - x, c)
            self:setPixelClamped((r) + off_x - tmp_y, (h - r) + off_y + x - 1, c)
            self:setPixelClamped((r) + off_x - x, (h - r) + off_y + tmp_y - 1, c)
        end
    end
end

--[[
    Draw a border

    @x:  start position in x axis
    @y:  start position in y axis
    @w:  width of the border
    @h:  height of the border
    @bw: line width of the border
    @c:  color for loading bar
    @r:  radius of for border's corner (nil or 0 means right corner border)
--]]

function BB_mt.__index:paintBorder(x, y, w, h, bw, c, r)
    x, y = math.ceil(x), math.ceil(y)
    h, w = math.ceil(h), math.ceil(w)
    if not r or r == 0 then
        self:paintRect(x, y, w, bw, c)
        self:paintRect(x, y + h - bw, w, bw, c)
        self:paintRect(x, y + bw, bw, h - 2 * bw, c)
        self:paintRect(x + w - bw, y + bw, bw, h - 2 * bw, c)
    else
        if h < 2 * r then
            r = math.floor(h / 2)
        end
        if w < 2 * r then
            r = math.floor(w / 2)
        end
        self:paintRoundedCorner(x, y, w, h, bw, r, c)
        self:paintRect(r + x, y, w - 2 * r, bw, c)
        self:paintRect(r + x, y + h - bw, w - 2 * r, bw, c)
        self:paintRect(x, r + y, bw, h - 2 * r, c)
        self:paintRect(x + w - bw, r + y, bw, h - 2 * r, c)
    end
end

--[[
    Fill a rounded corner rectangular area

    @x:  start position in x axis
    @y:  start position in y axis
    @w:  width of the area
    @h:  height of the area
    @c:  color used to fill the area
    @r:  radius of for four corners
--]]

function BB_mt.__index:paintRoundedRect(x, y, w, h, c, r)
    x, y = math.ceil(x), math.ceil(y)
    h, w = math.ceil(h), math.ceil(w)
    if not r or r == 0 then
        self:paintRect(x, y, w, h, c)
    else
        if h < 2 * r then
            r = math.floor(h / 2)
        end
        if w < 2 * r then
            r = math.floor(w / 2)
        end
        self:paintBorder(x, y, w, h, r, c, r)
        self:paintRect(x + r, y + r, w - 2 * r, h - 2 * r, c)
    end
end

--[[
    Draw a progress bar according to following args:

    @x:  start position in x axis
    @y:  start position in y axis
    @w:  width for progress bar
    @h:  height for progress bar
    @load_m_w: width margin for loading bar
    @load_m_h: height margin for loading bar
    @load_percent: progress in percent
    @c:  color for loading bar
--]]

function BB_mt.__index:progressBar(x, y, w, h, load_m_w, load_m_h, load_percent, c)
    if load_m_h * 2 > h then
        load_m_h = h / 2
    end
    self:paintBorder(x, y, w, h, 2, 15)
    self:paintRect(x + load_m_w, y + load_m_h, (w - 2 * load_m_w) * load_percent, (h - 2 * load_m_h), c)
end

--[[
    dim color values in rectangular area

    @param x X coordinate
    @param y Y coordinate
    @param w width
    @param h height
    @param by dim by this factor (default: 0.5)
--]]

function BB_mt.__index:dimRect(x, y, w, h, by)
    local color = Color8A(255, 255 * (by or 0.5))
    self:paintRect(x, y, w, h, color, self.setPixelBlend)
end

--[[
    lighten color values in rectangular area

    @param x X coordinate
    @param y Y coordinate
    @param w width
    @param h height
    @param by lighten by this factor (default: 0.5)
--]]

function BB_mt.__index:lightenRect(x, y, w, h, by)
    local color = Color8A(0, 255 * (by or 0.5))
    self:paintRect(x, y, w, h, color, self.setPixelBlend)
end

--[[
    make a full copy of the current buffer, with its own memory
--]]

function BB_mt.__index:copy()
    local mytype = ffi.typeof(self)
    local buffer = ffi.C.malloc(self.pitch * self.h)
    assert(buffer, "cannot allocate buffer")
    ffi.copy(buffer, self.data, self.pitch * self.h)
    local copy = mytype(self.w, self.h, self.pitch, buffer, self.config)
    copy:setAllocated(1)
    return copy
end

--[[
    return a new Blitbuffer object that works on a rectangular
    subset of the current Blitbuffer

    Note that the caller has to make sure that the underlying memory
    (of the Blitbuffer this method is called on) stays in place. In other
    words, a viewport does not create a new buffer with memory.
--]]

function BB_mt.__index:viewport(x, y, w, h)
    x, y, w, h = self:getPhysicalRect(x, y, w, h)
    local viewport = BB.new(w, h, self:getType(), self:getPixelP(x, y), self.pitch)
    viewport:setRotation(self:getRotation())
    viewport:setInverse(self:getInverse())
    return viewport
end

--[[
    write blitbuffer contents to a PNG file

    @param filename the name of the file to be created
--]]

function BB_mt.__index:writePNG(png, filename)
    png = png or require("png.png")
    local w, h = self:getWidth(), self:getHeight()
    local cdata = ffi.C.malloc(w * h * 4)
    local mem = ffi.cast("char*", cdata)
    for y = 0, h - 1 do
        local offset = 4 * w * y
        for x = 0, w - 1 do
            local c = self:getPixel(x, y):getColorRGB32()
            mem[offset] = c.r
            mem[offset + 1] = c.g
            mem[offset + 2] = c.b
            mem[offset + 3] = 0xFF
            offset = offset + 4
        end
    end
    png.encode_to_file(filename, mem, w, h)
    ffi.C.free(cdata)
end

-- if no special case in BB???_mt exists, use function from BB_mt
-- (we do not use BB_mt as metatable for BB???_mt since this causes
--  a major slowdown and would not get properly JIT-compiled)
for name, func in pairs(BB_mt.__index) do
    if not BB8_mt.__index[name] then
        BB8_mt.__index[name] = func
    end
    if not BB8A_mt.__index[name] then
        BB8A_mt.__index[name] = func
    end
    if not BBRGB16_mt.__index[name] then
        BBRGB16_mt.__index[name] = func
    end
    if not BBRGB24_mt.__index[name] then
        BBRGB24_mt.__index[name] = func
    end
    if not BBRGB32_mt.__index[name] then
        BBRGB32_mt.__index[name] = func
    end
end

-- set metatables for the BlitBuffer types
local BlitBuffer8 = ffi.metatype("BlitBuffer8", BB8_mt)
local BlitBuffer8A = ffi.metatype("BlitBuffer8A", BB8A_mt)
local BlitBufferRGB16 = ffi.metatype("BlitBufferRGB16", BBRGB16_mt)
local BlitBufferRGB24 = ffi.metatype("BlitBufferRGB24", BBRGB24_mt)
local BlitBufferRGB32 = ffi.metatype("BlitBufferRGB32", BBRGB32_mt)

-- set metatables for the Color types
ffi.metatype("Color8", Color8_mt)
ffi.metatype("Color8A", Color8A_mt)
ffi.metatype("ColorRGB16", ColorRGB16_mt)
ffi.metatype("ColorRGB24", ColorRGB24_mt)
ffi.metatype("ColorRGB32", ColorRGB32_mt)

function BB.new(width, height, buffertype, dataptr, pitch)
    local bb = nil
    buffertype = buffertype or TYPE_BB8
    if pitch == nil then
        if buffertype == TYPE_BB8 then
            pitch = width
        elseif buffertype == TYPE_BB8A then
            pitch = lshift(width, 1)
        elseif buffertype == TYPE_BBRGB16 then
            pitch = lshift(width, 1)
        elseif buffertype == TYPE_BBRGB24 then
            pitch = width * 3
        elseif buffertype == TYPE_BBRGB32 then
            pitch = lshift(width, 2)
        end
    end
    if buffertype == TYPE_BB8 then
        bb = BlitBuffer8(width, height, pitch, nil, 0)
    elseif buffertype == TYPE_BB8A then
        bb = BlitBuffer8A(width, height, pitch, nil, 0)
    elseif buffertype == TYPE_BBRGB16 then
        bb = BlitBufferRGB16(width, height, pitch, nil, 0)
    elseif buffertype == TYPE_BBRGB24 then
        bb = BlitBufferRGB24(width, height, pitch, nil, 0)
    elseif buffertype == TYPE_BBRGB32 then
        bb = BlitBufferRGB32(width, height, pitch, nil, 0)
    else
        error("unknown blitbuffer type")
    end
    bb:setType(buffertype)
    if dataptr == nil then
        dataptr = ffi.C.malloc(pitch * height)
        assert(dataptr, "cannot allocate memory for blitbuffer")
        ffi.fill(dataptr, pitch * height)
        bb:setAllocated(1)
    end
    bb.data = ffi.cast(bb.data, dataptr)
    return bb
end

function BB.compat(oldbuffer)
    return ffi.cast("BlitBuffer4*", oldbuffer)[0]
end

function BB.fromstring(width, height, buffertype, str, pitch)
    local dataptr = ffi.C.malloc(#str)
    ffi.copy(dataptr, str, #str)
    local bb = BB.new(width, height, buffertype, dataptr, pitch)
    bb:setAllocated(1)
    return bb
end

function BB.fromMonoASCII(ascii)
    local width, height = 0, 0
    local p_set = Color8A(255, 255)
    local p_clr = Color8A(0, 0)
    for line in string.gmatch(ascii, "([.X]+)") do
        height = height + 1
        if #line > width then
            width = #line
        end
    end
    local bb = BB.new(width, height, TYPE_BB8A)
    local y = 0
    for line in string.gmatch(ascii, "([.X]+)") do
        local x = 0
        for c in string.gmatch(line, "[.X]") do
            if c == "." then
                bb:setPixel(x, y, p_clr)
            else
                bb:setPixel(x, y, p_set)
            end
            x = x + 1
        end
        y = y + 1
    end
    return bb
end

function BB.tostring(bb)
    return ffi.string(bb.data, bb.pitch * bb.h)
end

--[[
    return a Color value resembling a given level of blackness/gray

    0 is white, 1.0 is black
--]]

function BB.gray(level)
    return Color8(0xFF - floor(0xFF * level))
end

-- some generic color values:
BB.COLOR_BLACK = Color8(0)
BB.COLOR_WHITE = Color8(0xFF)
BB.COLOR_GREY = Color8(0x80)
BB.COLOR_LIGHT_GREY = Color8(0xD0)

-- accessors for color types:
BB.Color8 = Color8
BB.Color8A = Color8A
BB.ColorRGB16 = ColorRGB16
BB.ColorRGB24 = ColorRGB24
BB.ColorRGB32 = ColorRGB32

-- accessors for Blitbuffer types
BB.BlitBuffer4 = BlitBuffer4
BB.BlitBuffer8 = BlitBuffer8
BB.BlitBuffer8A = BlitBuffer8A
BB.BlitBufferRGB16 = BlitBufferRGB16
BB.BlitBufferRGB24 = BlitBufferRGB24
BB.BlitBufferRGB32 = BlitBufferRGB32
BB.TYPE_BB8 = TYPE_BB8
BB.TYPE_BB8A = TYPE_BB8A
BB.TYPE_BBRGB16 = TYPE_BBRGB16
BB.TYPE_BBRGB24 = TYPE_BBRGB24
BB.TYPE_BBRGB32 = TYPE_BBRGB32

return BB