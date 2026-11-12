# Entregas Widget

App iOS com widget que mostra entregas de hoje e amanhã a partir de um feed de calendário (.ics).

## Como usar

### 1. Abrir no Xcode
1. Abra `EntregasWidget.xcodeproj` no Xcode 15+
2. Selecione seu Team em **Signing & Capabilities** para ambos os targets:
   - `Entregas` (app principal)
   - `EntregasWidgetExtension` (widget)
3. Configure o App Group `group.com.entregas.widget` em ambos os targets

### 2. Configurar App Group no Xcode
Para que o app e o widget compartilhem dados:
1. Selecione o target **Entregas** > Signing & Capabilities > + Capability > App Groups
2. Adicione `group.com.entregas.widget`
3. Repita para o target **EntregasWidgetExtension**

### 3. Rodar no iPhone
1. Conecte seu iPhone ou selecione um simulador
2. Build e Run (⌘R)
3. No app, cole o link .ics da sua agenda
4. Toque "Salvar e Sincronizar"

### 4. Adicionar Widget
1. Na tela inicial, toque e segure
2. Toque o botão "+" no canto superior
3. Procure "Entregas"
4. Selecione o tamanho médio (horizontal)
5. Toque "Adicionar Widget"

## Funcionalidades

- **Widget horizontal**: Hoje à esquerda | Amanhã à direita
- **Atualização automática**: A cada 10 minutos busca novos eventos
- **Marcar como feito**: Toque no círculo para completar uma tarefa
- **Visual dark**: Fundo escuro, checkmarks azuis, texto riscado ao completar
- **Parser ICS**: Compatível com feeds do Blackboard, Google Calendar, etc.

## Estrutura

```
EntregasWidget/
├── EntregasApp/          # App principal
│   ├── EntregasApp.swift # Tela para colar link .ics
│   ├── EntregasApp.entitlements
│   └── Info.plist
├── Shared/               # Código compartilhado
│   ├── ICSParser.swift   # Parser de arquivos .ics
│   └── DataStore.swift   # Armazenamento via App Group
├── Widget/               # Widget Extension
│   ├── EntregasWidget.swift
│   └── EntregasWidget.entitlements
└── EntregasWidget.xcodeproj/
```

## Requisitos

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
