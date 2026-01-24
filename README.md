> ⚠️ **WARNING:** This library is in early development and it is not intended to be used for large productions.

# Kernel

This Kernel is a set of utility systems and controllers designed to centralize the common logic of a project. It focuses on three main pillars: decoupling, memory management and performance.

---

> 📝 **NOTE:** NEVER require files inside the Services or Controllers folders directly in your game logic.

The only permitted way to access a system is by asking the Kernel Core.

```lua
local Kernel = require(game.ReplicatedStorage.Shared.Kernel.Core)
local Data = Kernel.get("DataSystem")

Instead of requiring the DataSystem directly, you ask the Kernel to deliver the system.

## Getting Started