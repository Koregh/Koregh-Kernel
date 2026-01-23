--!strict

export type StoreState = { [string]: any }

export type IStore = {
    Name: string,
    
    Get: (self: any, player: Player, key: string?) -> any,
    Set: (self: any, player: Player, key: string, value: any) -> boolean,
    Update: (self: any, player: Player, key: string, callback: (oldValue: any) -> any) -> boolean,
    
    OnUpdate: (self: any, player: Player, callback: (newState: StoreState) -> ()) -> any, 
    
    Load: (self: any, player: Player) -> boolean,
    Wipe: (self: any, player: Player) -> (),
}

return {}