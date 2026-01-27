> [!WARNING]
> This library is in early development and it is not intended to be used for large productions.

# Kernel

The Kernel is a set of utility systems and controllers designed to centralize the common logic of a project. It focuses on three main pillars: **decoupling, memory management, and performance**.

---

> [!NOTE]
> NEVER require files inside the `Services` or `Controllers` folders directly in your game logic.

The only permitted way to access a system is via the Kernel Core:

```lua
local Kernel = require(game.ReplicatedStorage.Shared.Kernel.Core)
local Data = Kernel.get("DataSystem")
````

Instead of requiring the `DataSystem` directly, you ask the Kernel to deliver the system.

---

## Getting Started

### Network Service

The Network Service is a high-performance **Gateway-based** communication layer. It uses **Packet Batching** and **Buffer Compression** to minimize bandwidth and overhead. Instead of creating multiple RemoteEvents, all communication is routed through a single Gateway and organized by **Channels**.

#### 1. Accessing the Service

Never require the Network module directly. Always access it via the Kernel Core:

```lua
local Kernel = require(game.ReplicatedStorage.Shared.Kernel.Core)
local Network = Kernel.get("Network")
```

```lua
local NetworkContracts = require(ReplicatedStorage.Shared.Kernel.Network.NetworkContracts)
local Guard = require(ReplicatedStorage.Shared.Kernel.Security.Guard)

NetworkContracts.Add("RequestPurchase", {
    [1] = Guard.String, 
    [2] = Guard.Number  
})
```

#### 2. Client-to-Server (Send)

Use `Send` to transmit data to the server. The Kernel buffers these requests and sends them in a batch during the next `Heartbeat`.

**Client:**

```lua
Network.Send("RequestPurchase", "IronSword", 1)
```

**Server:**

```lua
Network.RegisterChannel("RequestPurchase", function(player, itemName, amount)
    print(player.Name .. " wants to buy " .. amount .. " " .. itemName)
end)
```

#### 3. Server-to-Client (Fire)

**Server:**

```lua
-- To a specific player
Network.FireClient(player, "Notify", "Purchase Successful!")

-- To all players
Network.FireAll("GlobalAnnouncement", "Server restarting in 5 minutes.")
```

**Client:**

```lua
Network.RegisterChannel("Notify", function(message)
    print("Notification received: " .. message)
end)
```

#### 4. Remote Invocation (Invoke / Async)

The Network Service implements an **Asynchronous Ping-Pong** mechanism. It avoids using RemoteFunctions directly, preventing server thread hangs.

**Server (Return Values):**

```lua
Network.RegisterChannel("GetBalance", function(player, accountType)
    local balance = 500
    return balance, "USD"
end)
```

**Client (Invoke):**

```lua
local balance, currency = Network.Invoke("GetBalance", "Savings")
if balance then
    print("Balance: " .. balance .. " " .. currency)
end
```

**Client (Async):**

```lua
Network.Async("GetBalance", "Savings"):andThen(function(balance)
    print("Received balance: " .. balance)
end):catch(function(err)
    warn("Request failed: " .. err)
end)
```

---

### Data System

The Data System manages **player profiles**, persistent storage, and real-time state synchronization. It uses a **Profile-based architecture** to ensure data integrity and provides a **path-based API** for nested data manipulation.

> [!IMPORTANT]
> The `TEMPLATE` table defines the default state for new players.

#### 1. Accessing the System

Always access the Data System through the Kernel Core:

```lua
local Kernel = require(game.ReplicatedStorage.Shared.Kernel.Core)
local DataSystem = Kernel.get("DataSystem")
```

#### 2. Basic Data Manipulation (Get, Set, Increment/Decrement)

```lua
-- Get: Retrieve data
local money = DataSystem:Get(player, "Stats.Money")

-- Set: Update data and sync to client
DataSystem:Set(player, "Stats.Level", 10)

-- Increment / Decrement numeric paths
DataSystem:Increment(player, "Stats.Money", 500)
DataSystem:Decrement(player, "Stats.Experience", 100)
```

#### 3. List Management (Arrays / Inventory)

```lua
-- Add item
DataSystem:ListAdd(player, "Inventory.Items", "IronSword")

-- Check item
local hasItem = DataSystem:ListHas(player, "Inventory.Items", nil, "IronSword")

-- Remove item
DataSystem:ListRemove(player, "Inventory.Items", nil, "IronSword")

-- Move item between categories
DataSystem:ListMove(player, "Inventory.Items", "Equipment.Active", "ID", "Slot1")
```

---

### State Controller (Client-side)

The **StateController** is a **client-side mirror** of your DataSystem. It automatically syncs with the server, providing **instant read access** without network lag.

#### Basic Usage

```lua
local StateController = Kernel.get("StateController")

-- Get data instantly
local gold = StateController.Get("Stats.Gold")

-- React to changes (e.g., update UI)
StateController.Changed:Connect(function(category, newValue)
    if category == "Stats.Gold" then
        print("New gold balance: " .. newValue)
    end
end)
```

---

> **Tips**

* Always access systems via `Kernel.get("SystemName")`
* Never require files inside `Services` or `Controllers` directly
* Read the documentation for each system to explore all available methods
