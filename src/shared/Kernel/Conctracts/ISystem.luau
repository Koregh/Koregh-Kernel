--!strict
export type ISystem = {
    Name: string,
    Priority: number?, 
    
    OnInit: (self: any) -> (),
    OnStart: (self: any) -> (),
    OnUpdate: ((self: any, dt: number) -> ())?,
}

return {}