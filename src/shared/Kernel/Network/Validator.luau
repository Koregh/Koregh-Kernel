--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Shared.Kernel.Security.Guard)

type WriteFn = (b: buffer, c: number, v: any) -> number
type ReadFn = (b: buffer, c: number) -> (any, number)

export type TypeConfig = {
    Name: string,
    Guard: (v: any) -> boolean,
    Write: WriteFn?,
    Read: ReadFn?,
    IsComplex: boolean?,
}

local Validator = {}

local TYPE_DEFINITIONS: { [number]: TypeConfig } = {
    [1] = { 
        Name = "boolean", -- Letra minúscula para bater com typeof()
        Guard = Guard.Boolean, 
        Write = function(b, c, v) buffer.writeu8(b, c, v and 1 or 0) return 1 end,
        Read = function(b, c) return buffer.readu8(b, c) == 1, 1 end 
    },
    [2] = { 
        Name = "number", 
        Guard = Guard.Number, 
        Write = function(b, c, v) buffer.writef64(b, c, v) return 8 end,
        Read = function(b, c) return buffer.readf64(b, c), 8 end 
    },
    [3] = { 
        Name = "string", 
        Guard = Guard.String, 
        Write = function(b, c, v) 
            local len = #v
            buffer.writeu32(b, c, len)
            buffer.writestring(b, c + 4, v, len)
            return 4 + len
        end,
        Read = function(b, c) 
            local len = buffer.readu32(b, c)
            return buffer.readstring(b, c + 4, len), 4 + len
        end 
    },
    [4] = { 
        Name = "Vector3", 
        Guard = Guard.Vector3, 
        Write = function(b, c, v) 
            buffer.writef32(b, c, v.X)
            buffer.writef32(b, c + 4, v.Y)
            buffer.writef32(b, c + 8, v.Z)
            return 12 
        end,
        Read = function(b, c) 
            return Vector3.new(buffer.readf32(b, c), buffer.readf32(b, c + 4), buffer.readf32(b, c + 8)), 12
        end 
    },
    [5] = { 
        Name = "CFrame", 
        Guard = Guard.CFrame, 
        Write = function(b, c, v) 
            local x, y, z, r1, r2, r3, r4 = v:GetComponents()
            buffer.writef32(b, c, x) buffer.writef32(b, c + 4, y) buffer.writef32(b, c + 8, z)
            buffer.writef32(b, c + 12, r1) buffer.writef32(b, c + 16, r2) 
            buffer.writef32(b, c + 20, r3) buffer.writef32(b, c + 24, r4)
            return 28
        end,
        Read = function(b, c) 
            return CFrame.new(
                buffer.readf32(b, c), buffer.readf32(b, c + 4), buffer.readf32(b, c + 8),
                buffer.readf32(b, c + 12), buffer.readf32(b, c + 16), 
                buffer.readf32(b, c + 20), buffer.readf32(b, c + 24)
            ), 28
        end 
    },
    [6] = { Name = "table", Guard = Guard.Table, IsComplex = true },
    [7] = { Name = "Instance", Guard = Guard.Instance("Instance"), IsComplex = true }, -- Tratado como complexo pelo kernel por enquanto
    [8] = { 
        Name = "Color3", 
        Guard = Guard.Color3, 
        Write = function(b, c, v) 
            buffer.writeu8(b, c, v.R * 255)
            buffer.writeu8(b, c + 1, v.G * 255)
            buffer.writeu8(b, c + 2, v.B * 255)
            return 3
        end,
        Read = function(b, c) 
            return Color3.fromRGB(buffer.readu8(b, c), buffer.readu8(b, c + 1), buffer.readu8(b, c + 2)), 3
        end
    },
    [9] = { 
        Name = "Vector2", 
        Guard = Guard.Vector2, 
        Write = function(b, c, v) 
            buffer.writef32(b, c, v.X) buffer.writef32(b, c + 4, v.Y)
            return 8
        end,
        Read = function(b, c) return Vector2.new(buffer.readf32(b, c), buffer.readf32(b, c + 4)), 8 end
    },
    [10] = { 
        Name = "nil", 
        Guard = function(v) return v == nil end,
        Write = function(b, c, v) return 0 end,
        Read = function(b, c) return nil, 0 end
    }
}

Validator.TypeIds = TYPE_DEFINITIONS

Validator.NamesToIds = {}
for id, config in pairs(Validator.TypeIds) do
    Validator.NamesToIds[config.Name] = id
end

function Validator.new(schema: Guard.Schema)
    return {
        Schema = schema,
        Validate = function(...)
            return Guard.Check({...}, schema)
        end
    }
end

return table.freeze(Validator)