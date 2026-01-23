--!strict
local RateLimiter = {}

local DEFAULT_RPS = 5
local _storage = {} 
local FrameworkLogger: any = nil

function RateLimiter._setLogger(logger: any)
	FrameworkLogger = logger
end

function RateLimiter.Cleanup(player: Player)
	_storage[player.UserId] = nil
end

function RateLimiter.IsAllowed(player: Player, action: string, rps: number?): boolean
	local userId = player.UserId
	local now = os.clock()
	local limit = rps or DEFAULT_RPS
	
	if not _storage[userId] then _storage[userId] = {} end
	
	local lastCall = _storage[userId][action] or 0
	local timePassed = now - lastCall
	local cooldown = 1 / limit

	if timePassed < cooldown then
		if timePassed < (cooldown / 2) and FrameworkLogger then
			FrameworkLogger.warn("Security", string.format(
				"Rate Limit Abuso: %s em '%s' (Esperado: %.2fs, Recebido: %.2fs)",
				player.Name, action, cooldown, timePassed
			))
		end
		return false
	end

	_storage[userId][action] = now
	return true
end

return table.freeze(RateLimiter)