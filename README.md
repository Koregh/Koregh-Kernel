# Kernel 

O **Kernel** é um framework modular focado em **comunicação binária**, **segurança de dados** e **gerenciamento de ciclo de vida**.  
Ele foi projetado para **reduzir overhead de rede**, **isolar falhas de sistema** e **proteger o servidor contra abusos comuns** em jogos multiplayer de média e larga escala.

> [!NOTE]
> Este projeto não substitui a engine do Roblox. Ele atua como uma **camada de infraestrutura** acima dos serviços nativos.

---

## 🎯 Objetivos do Projeto

- Reduzir tráfego de rede via serialização binária
- Garantir validação e sanitização de dados no servidor
- Evitar falhas em cascata causadas por erros de módulos
- Padronizar comunicação, input e ciclo de vida dos sistemas

> [!WARNING]
> O Kernel assume que **toda autoridade reside no servidor**.  
> Nenhuma lógica crítica deve ser executada no cliente.

---

## 🛠 Arquitetura Principal

O framework é dividido em **serviços core**, cada um com responsabilidade bem definida.

---

## 1️⃣ NetworkKernel (Camada de Rede)

O `NetworkKernel` substitui o uso direto de `RemoteEvent` e `RemoteFunction` por uma camada controlada e otimizada.

### Funcionalidades

- **Comunicação Binária**
  - Serialização em buffer de tipos nativos (`Vector3`, `CFrame`, `number`)
  - Redução significativa de payloads JSON/texto

- **Security Layer**
  - Rate limit por jogador
  - Sanitização automática de valores
  - Bloqueio de:
    - `NaN` e `inf`
    - Strings excessivamente longas
    - Tipos inesperados

- **Invoke & Async**
  - Chamadas assíncronas baseadas em Promises
  - Evita travamentos comuns de `RemoteFunction`

> [!TIP]
> Toda entrada recebida pelo servidor **passa obrigatoriamente** por validação antes de alcançar a lógica de jogo.

---

## 2️⃣ Lifecycle Management (Core)

O Kernel utiliza um **ciclo de vida previsível** para inicialização e execução dos sistemas.

### Etapas

- **OnInit**
  - Registro de canais
  - Configurações síncronas
  - Nenhuma lógica pesada

- **OnStart**
  - Execução da lógica principal
  - Inicialização em threads protegidas

- **ThreadManager**
  - Centraliza e monitora threads
  - Isola erros por módulo
  - Evita que uma falha derrube o servidor inteiro

> [!IMPORTANT]
> Um erro em um sistema **não interrompe** a execução global do Kernel.

---

## 3️⃣ Input System

O `InputController` abstrai teclas físicas para **ações semânticas**.

### Recursos

- **Priority Stack**
  - UI pode capturar input antes do gameplay
  - Elimina `if menuOpen then return end` espalhados

- **Input Buffering**
  - Detecção de janelas de tempo
  - Suporte a combos e ações rápidas

> [!NOTE]
> O sistema foi projetado para ser determinístico e previsível, não para macros ou automação complexa.
