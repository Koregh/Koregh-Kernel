--!strict
export type INetwork = {
    Events: { [string]: RemoteEvent },
    Functions: { [string]: RemoteFunction },
    
    FireClient: (self: any, player: Player, name: string, ...any) -> (),
    FireAllClients: (self: any, name: string, ...any) -> (),
    OnServerEvent: (self: any, name: string, callback: (...any) -> ()) -> (),
}

return {}