# Delphi4AI 🤖⚡

Biblioteca nativa em **Delphi** para integração moderna, rápida e desacoplada com Modelos de Linguagem Grande (**LLMs**) compatíveis com a API da OpenAI (OpenAI, OpenRouter, Groq, DeepSeek, Ollama, LM Studio, vLLM e outros) e provedores nativos dedicados para **Google Gemini** e **Ollama**.

Projetada com foco em **baixo acoplamento**, **zero dependências externas** (utiliza apenas a RTL padrão do Delphi) e suporte de primeira classe a **Function Calling / Tool Calling (incluindo RTTI declarativa)** e **gerenciamento inteligente de histórico**.

---

## 🚀 Destaques

- **Zero Dependências Externas**: Utiliza apenas `System.Net.HttpClient`, `System.JSON` e `System.Rtti` nativos do Delphi.
- **Ampla Compatibilidade**: Funciona com qualquer endpoint compatível com a API Chat Completions da OpenAI (`https://api.openai.com/v1`, Ollama local `http://localhost:11434/v1`, OpenRouter, Groq, etc.) e suporte nativo ao **Google Gemini** (`generateContent`).
- **Tools & Function Calling Avançado**:
  - **RTTI Declarativa**: Transforme métodos de qualquer classe em ferramentas para a IA decorando com `[TLLMTool]` e `[TLLMParam]`.
  - **Funções Anônimas**: Registre ferramentas dinamicamente com closures Pascal (`TToolCallback` ou `TToolJSONCallback`).
  - **Loop Multi-Turn Automático**: A biblioteca detecta chamadas de ferramentas, executa o método correspondente no Delphi e devolve o resultado para a IA em um loop contínuo até a resposta final.
- **Gerenciamento de Histórico de Conversa**:
  - **Sliding Window (`hsSlidingWindow`)**: Janela deslizante com proteção atômica de blocos de tools (nunca deixa chamadas de ferramentas ou resultados órfãos).
  - **Summarization (`hsSummarize`)**: Compactação e resumo automático do histórico antigo usando a própria IA.
- **Design Baseado em Interfaces**: Totalmente testável e desacoplado através de `ILLMProvider` e `ILLMToolRegistry`.
- **Suíte de Testes com DUnit**: Testes automatizados cobrindo requisições, parsing de chamadas de ferramentas, poda de histórico e RTTI.

---

## 📦 Requisitos

- **Embarcadero Delphi 10.3 Rio** ou superior (testado e otimizado no **Delphi 12 Athens**).
- Plataformas: **Win32** e **Win64** (com suporte arquitetural para multiplataforma via RTL).

---

## ⚡ Início Rápido

### 1. Inicializando o Provedor

Adicione as units ao seu `uses`:

```delphi
uses
  LLM.Interfaces,
  LLM.Factory;

var
  LLM: ILLMProvider;
  Resposta: string;
begin
  // Provedor Google Gemini (padrao gemini-2.5-flash via API REST nativa)
  LLM := CreateLLMProvider(ptGemini, 'sua-gemini-api-key');

  // Ou Groq (ultra-rapido via LPU, padrao llama-3.3-70b-versatile)
  // LLM := CreateLLMProvider(ptGroq, 'sua-groq-api-key');

  // Ou OpenAI padrao
  // LLM := CreateLLMProvider(ptOpenAI, 'sua-openai-api-key', 'gpt-4o-mini');

  // Ou Ollama local (localhost:11434)
  // LLM := CreateLLMProvider(ptOllama, 'llama3.2');

  // Envia mensagem do usuario
  LLM.AddUser('Explique o que e RTTI no Delphi em poucas palavras.');
  Resposta := LLM.Send;

  ShowMessage(Resposta);
end;
```

---

## 🛠️ Function Calling / Tools

O Delphi4AI oferece duas formas elegantes de expor ferramentas para os modelos de IA.

### Método 1: Registro Declarativo via RTTI (Recomendado)

Crie uma classe comum e decore seus métodos com os atributos `[TLLMTool]` e `[TLLMParam]`:

```delphi
uses
  LLM.Tools.Attributes;

type
  TMinhasFerramentas = class
  public
    [TLLMTool('consultar_saldo', 'Retorna o saldo bancario de uma conta')]
    function ConsultarSaldo(
      [TLLMParam('Numero da conta')] Conta: Integer;
      [TLLMParam('Codigo da agencia', True)] Agencia: string
    ): string;

    [TLLMTool('converter_moeda', 'Converte valor de BRL para moeda estrangeira')]
    function ConverterMoeda(
      [TLLMParam('Valor em reais')] Valor: Double;
      [TLLMParam('Moeda destino (USD, EUR)')] Moeda: string
    ): string;
  end;
```

No seu provedor, registre a classe (a biblioteca cuida da instanciação e ciclo de vida) ou uma instância pré-existente:

```delphi
// Registra por classe:
LLM.RegisterTool(TMinhasFerramentas);

// Ou registra por instancia existente:
// LLM.RegisterTool(FMinhasFerramentasInstancia);
```

#### Vantagens do RTTI no Delphi4AI:
- **Zero JSON Schema manual**: O JSON Schema (propriedades, tipos e array `required`) é gerado automaticamente por reflexão.
- **Conversão de tipos segura**: Converte automaticamente `Integer`, `Int64`, `Double`, `Boolean` e `string`, com tolerância a formatos numéricos e busca *case-insensitive* de parâmetros.
- **Valores padrão**: Se o modelo omitir um parâmetro opcional, o RTTI atribui valores padrão seguros evitando falhas de execução.

---

### Método 2: Funções Anônimas / Callbacks Tradicionais

Você também pode registrar ferramentas dinamicamente em tempo de execução com closures Pascal:

```delphi
// Com schema em JSON bruto:
LLM.RegisterFunction(
  'obter_hora_atual',
  'Retorna a data e hora atual do sistema local',
  '{"type":"object","properties":{}}',
  function(const AArgs: string): string
  begin
    Result := Format('{"data_hora": "%s"}', [DateTimeToStr(Now)]);
  end
);

// Com parametros estruturados:
LLM.RegisterFunction(
  'consultar_cep',
  'Busca informacoes de endereco a partir do CEP',
  '{"type":"object","properties":{"cep":{"type":"string","description":"CEP com 8 digitos"}},"required":["cep"]}',
  function(const AArgs: string): string
  var
    LArgs: TJSONObject;
    LCEP: string;
  begin
    LArgs := TJSONObject.ParseJSONValue(AArgs) as TJSONObject;
    try
      LCEP := LArgs.GetValue<string>('cep', '');
      Result := Format('{"endereco": "Av. Paulista, 1000", "cidade": "Sao Paulo", "cep": "%s"}', [LCEP]);
    finally
      LArgs.Free;
    end;
  end
);
```

---

### Obter Ferramentas Registradas

Para listar em logs ou interfaces as ferramentas ativas no momento:

```delphi
// Retorna um TArray<string> com o nome de todas as tools
var LTools: TArray<string> := LLM.Tools.GetNames;

// Ou usando a propriedade:
ShowMessage('Tools ativas: ' + string.Join(', ', LLM.Tools.Names));
```

---

### Notificações de Execução (Eventos)

Você pode acompanhar visualmente cada chamada feita pelo modelo:

```delphi
LLM.OnBeforeExecuteTool := procedure(const ACall: TLLMToolCall)
begin
  Writeln(Format('[Chamando Tool] %s com argumentos: %s', [ACall.Name, ACall.Arguments]));
end;

LLM.OnAfterExecuteTool := procedure(const ACall: TLLMToolCall; const AResult: string; const ASuccess: Boolean)
begin
  Writeln(Format('[Retorno Tool] %s -> %s (Sucesso: %s)', [ACall.Name, AResult, BoolToStr(ASuccess, True)]));
end;
```

---

## 🧠 Gerenciamento de Histórico

Modelos de linguagem possuem limite de tokens de contexto. O Delphi4AI gerencia o histórico de mensagens automaticamente:

```delphi
// Estrategia por Janela Deslizante (padrao)
LLM.HistoryStrategy := hsSlidingWindow;
LLM.MaxHistoryMessages := 10; // Mantem no maximo 10 mensagens
```

### Estratégias disponíveis:

| Estratégia | Descrição |
|---|---|
| `hsSlidingWindow` | Descarta as mensagens mais antigas mantendo a instrução de sistema (`system`) no topo e preservando a integridade atômica dos blocos de ferramentas (evita deixar mensagens `tool` sem seu `assistant` chamador). |
| `hsSummarize` | Ao atingir o limite, aciona uma chamada interna para que o modelo sintetize a conversa antiga em um resumo compacto, preservando o contexto essencial sem estourar o limite de tokens. |
| `hsNone` | Mantém todo o histórico cumulativamente sem descarte. |

---

## 🖥️ Exemplo Prático (VCL)

Na pasta [`exemplos/simples/`](file:///g:/Meu%20Drive/workspace/delphi/Delphi4AI/exemplos/simples/) você encontra uma aplicação VCL pronta para teste:

- Chat visual completo.
- Configuração dinâmica de URL, Modelo, API Key e Estratégia de Histórico.
- Demonstração de Tool Calling tradicional (`obter_hora_atual`, `consultar_cotacao_moeda`).
- Demonstração de Tool Calling via RTTI com a classe `TWeatherAPI` (`uWeatherTool.pas`), consultando a API real do OpenWeatherMap.

> **Dica**: Para testar a ferramenta de clima no exemplo, copie `exemplos/simples/weather_tool/env-sample.ini` para `env.ini` e preencha sua chave do OpenWeatherMap.

---

## 🧪 Testes Automatizados

O projeto inclui uma suíte completa de testes com o framework **DUnit**:

- Projeto: `tests/Delphi4AI.Tests.dpr`
- Cobre:
  - Registro de ferramentas via string, JSON e RTTI.
  - Parsing de respostas com tool calls.
  - Execução de ciclo de ferramentas multi-turn.
  - Poda e proteção de integridade no Sliding Window.
  - Resumo de mensagens.
  - Propagação e tratamento de exceções em ferramentas.

---

## 📂 Estrutura do Repositório

```text
Delphi4AI/
├── app/
│   └── LLM.Factory.pas            # Factory para criacao de provedores
├── llm/
│   ├── LLM.Base.pas               # Implementacao base do provedor OpenAI
│   ├── LLM.Interfaces.pas         # Interfaces fundamentais (ILLMProvider, ILLMTool, ILLMSender, etc.)
│   ├── LLM.Client.pas             # Smart Record (TLLMClient) e executor tipado ILLMSender<T>
│   ├── LLM.Schema.pas             # Atributos, gerador de schema e desserializador tipado
│   ├── LLM.HistoryStrategy.pas    # Enums e definicoes de estrategia de contexto
│   ├── LLM.Exceptions.pas         # Hierarquia de excecoes customizadas
│   ├── LLM.Tools.pas              # Registro e despacho de tools manuais
│   ├── LLM.Tools.Attributes.pas   # Atributos [TLLMTool] e [TLLMParam]
│   └── LLM.Tools.RTTI.pas         # Mecanismo de reflexao e execucao via RTTI
├── utils/
│   └── Utils.JSONArray.pas        # Utilitarios e helpers para manipulação de arrays JSON
├── ollama/
│   └── Ollama.Provider.pas        # Provedor nativo para Ollama local (/api/chat)
├── groq/
│   └── Groq.Provider.pas          # Provedor nativo para Groq LPU (API ultra-rapida)
├── gemini/
│   └── Gemini.Provider.pas        # Provedor nativo para Google Gemini (generateContent)
├── exemplos/
│   └── simples/                   # Aplicacao demonstrativa VCL completa
├── tests/                         # Suite de testes unitarios com DUnit
└── Delphi4AI.dpk                  # Pacote de instalacao Delphi
```

---

## 📄 Licença

Distribuído sob a licença MIT. Veja o arquivo de licença para mais detalhes.
