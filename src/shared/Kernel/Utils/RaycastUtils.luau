--!strict
local Workspace = game:GetService("Workspace")

type CollisionFilter = {Instance}
type RaycastResult = RaycastResult?

local RaycastUtils = {}

local sharedParams = RaycastParams.new()
sharedParams.FilterType = Enum.RaycastFilterType.Exclude
sharedParams.RespectCanCollide = true


function RaycastUtils.Fire(origin: Vector3, direction: Vector3, filter: CollisionFilter?, janitor: any?): RaycastResult
    sharedParams.FilterDescendantsInstances = filter or {}
    
    local result = Workspace:Raycast(origin, direction, sharedParams)
    
    if result and janitor then
        janitor:Add(function()
        end, "CleanupRay")
    end
    
    return result
end


function RaycastUtils.ActiveCast(origin: Vector3, direction: Vector3, filter: CollisionFilter, janitor: any, callback: (RaycastResult) -> ())
    local currentPos = origin
    local step = direction.Unit * 2
    
    local connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        local result = RaycastUtils.Fire(currentPos, step, filter)
        
        if result then
            janitor:Remove("RayTask") 
            callback(result)
        else
            currentPos = currentPos + step
        end
        
        if (currentPos - origin).Magnitude > 500 then
            janitor:Remove("RayTask")
        end
    end)
    
    janitor:Add(connection, "Disconnect", "RayTask")
end

return RaycastUtils