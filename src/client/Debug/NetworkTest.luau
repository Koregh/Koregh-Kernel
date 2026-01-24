local NetworkDebugger = {}

function NetworkDebugger.Start()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local NetworkKernel = require(ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)

    task.wait(3)
    print("[CLIENT] Iniciando Teste de Tipos AAA...")

    local stringTest = "DraxOutz_Dev"
    local numberTest = 150.5
    local boolTest = true
    local tableTest = {hp = 100, stamina = 50}

    print("Enviando Mix de Dados...")
    NetworkKernel.Send("Ping", stringTest, numberTest, boolTest, tableTest)

    task.spawn(function()
        print("Solicitando Dados Complexos via Invoke...")
        local status, data = NetworkKernel.Invoke("GetServerInfo")
        if status == "Success" then
            print(`[INVOKE] Servidor respondeu! Versão: {data.Version}, Players: {data.PlayerCount}`)
        end
    end)
end

return NetworkDebugger