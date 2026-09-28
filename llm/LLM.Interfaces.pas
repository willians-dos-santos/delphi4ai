unit LLM.Interfaces;

interface
uses
  System.JSON,
  LLM.HistoryStrategy,
  LLM.Tools;

type

  ILLMResponseFormat = interface;

  /// <summary>
  /// Interface especializada para envio fluente e retorno tipado estruturado (Record ou Class)
  /// </summary>
  ILLMSender<T> = interface
    function AddUser(const AContent: string): ILLMSender<T>;
    function AddSystem(const AContent: string): ILLMSender<T>;
    function Send: T; overload;
    function Send(const APrompt: string): T; overload;
    function Send(const APrompt: string; out RawJSON: string): T; overload;
  end;

  ILLMProvider = interface
    ['{E4627A59-5B8F-4D2A-94B6-1E27B13C4509}']
    // Getters e Setters das propriedades basicas
    function GetApiKey: string;
    procedure SetApiKey(const Value: string);
    function GetBaseURL: string;
    procedure SetBaseURL(const Value: string);
    function GetModel: string;
    procedure SetModel(const Value: string);
    function GetTemperature: Double;
    procedure SetTemperature(const Value: Double);
    function GetMaxTokens: Integer;
    procedure SetMaxTokens(const Value: Integer);
    function GetTimeout: Integer;
    procedure SetTimeout(const Value: Integer);
    function GetAutoAddAssistantResponse: Boolean;
    procedure SetAutoAddAssistantResponse(const Value: Boolean);

    // Getters e Setters de Historico
    function GetHistoryStrategy: THistoryStrategy;
    procedure SetHistoryStrategy(const Value: THistoryStrategy);
    function GetMaxHistoryMessages: Integer;
    procedure SetMaxHistoryMessages(const Value: Integer);
    function GetKeepRecentMessages: Integer;
    procedure SetKeepRecentMessages(const Value: Integer);
    function GetSummaryModel: string;
    procedure SetSummaryModel(const Value: string);
    function GetSummaryPrompt: string;
    procedure SetSummaryPrompt(const Value: string);

    function GetMessages: TJSONArray;

    // Getters e Setters de Tools / Function Calling
    function GetAutoExecuteTools: Boolean;
    procedure SetAutoExecuteTools(const Value: Boolean);
    function GetMaxToolIterations: Integer;
    procedure SetMaxToolIterations(const Value: Integer);
    function GetPropagateToolExceptions: Boolean;
    procedure SetPropagateToolExceptions(const Value: Boolean);
    function GetHasToolCalls: Boolean;
    function GetLastToolCalls: TLLMToolCallList;
    function GetTools: ILLMToolRegistry;
    function GetOnBeforeExecuteTool: TOnBeforeExecuteToolEvent;
    procedure SetOnBeforeExecuteTool(const Value: TOnBeforeExecuteToolEvent);
    function GetOnAfterExecuteTool: TOnAfterExecuteToolEvent;
    procedure SetOnAfterExecuteTool(const Value: TOnAfterExecuteToolEvent);

    // Metodos do provedor
    procedure ClearHistory;
    procedure AddMessage(const ARole, AContent: string);
    procedure AddSystem(const AContent: string);
    procedure AddUser(const AContent: string);
    procedure AddAssistant(const AContent: string);

    // Registro de Ferramentas / Functions
    procedure RegisterTool(const ATool: ILLMTool); overload;
    procedure RegisterTool(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback); overload;
    procedure RegisterTool(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback); overload;
    procedure RegisterTool(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback); overload;
    procedure RegisterTool(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback); overload;

    procedure RegisterFunction(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback); overload;
    procedure RegisterFunction(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback); overload;
    procedure RegisterFunction(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback); overload;
    procedure RegisterFunction(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback); overload;
    procedure RegisterTool(const AClass: TClass); overload;
    procedure RegisterTool(const AInstance: TObject); overload;
    procedure UnregisterTool(const AName: string);
    procedure ClearTools;

    // Metodo para resposta manual de Tool
    procedure AddToolResult(const AToolCallId, AContent: string);

    // Dispara manualmente o resumo do historico atual (util sob demanda)
    procedure SummarizeHistory;

    function Send(out RawJSON: string): string; overload;
    function Send: string; overload;

    // Propriedades basicas
    property ApiKey: string read GetApiKey write SetApiKey;
    property BaseURL: string read GetBaseURL write SetBaseURL;
    property Model: string read GetModel write SetModel;
    property Temperature: Double read GetTemperature write SetTemperature;
    property MaxTokens: Integer read GetMaxTokens write SetMaxTokens;
    property Timeout: Integer read GetTimeout write SetTimeout;
    property AutoAddAssistantResponse: Boolean read GetAutoAddAssistantResponse write SetAutoAddAssistantResponse;

    // Propriedades de controle de memoria/historico
    property HistoryStrategy: THistoryStrategy read GetHistoryStrategy write SetHistoryStrategy;
    property MaxHistoryMessages: Integer read GetMaxHistoryMessages write SetMaxHistoryMessages;
    property Messages: TJSONArray read GetMessages;
    property KeepRecentMessages: Integer read GetKeepRecentMessages write SetKeepRecentMessages;
    property SummaryModel: string read GetSummaryModel write SetSummaryModel;
    property SummaryPrompt: string read GetSummaryPrompt write SetSummaryPrompt;

    // Propriedades de Tools / Function Calling
    property AutoExecuteTools: Boolean read GetAutoExecuteTools write SetAutoExecuteTools;
    property MaxToolIterations: Integer read GetMaxToolIterations write SetMaxToolIterations;
    property PropagateToolExceptions: Boolean read GetPropagateToolExceptions write SetPropagateToolExceptions;
    property LastToolCalls: TLLMToolCallList read GetLastToolCalls;
    property HasToolCalls: Boolean read GetHasToolCalls;
    property Tools: ILLMToolRegistry read GetTools;

    // Eventos de execucao de Tools
    property OnBeforeExecuteTool: TOnBeforeExecuteToolEvent read GetOnBeforeExecuteTool write SetOnBeforeExecuteTool;
    property OnAfterExecuteTool: TOnAfterExecuteToolEvent read GetOnAfterExecuteTool write SetOnAfterExecuteTool;

    // Suporte a Saidas Estruturadas (Structured Outputs)
    function GetResponseFormat: ILLMResponseFormat;
    function SendAsJSON: TJSONObject;
    function SendAs(AClass: TClass): TObject; overload;
    procedure SendAs(ATypeInfo: Pointer; out Buffer); overload;



    property ResponseFormat: ILLMResponseFormat read GetResponseFormat;
  end;

  /// <summary>
  /// Tipo de formato de resposta para saídas estruturadas
  /// </summary>
  TResponseFormatType = (rfText, rfJSONObject, rfJSONSchema);

  /// <summary>
  /// Interface para configuracao do formato de resposta estruturada
  /// </summary>
  ILLMResponseFormat = interface
    ['{B4A3D1E2-F5C6-47A8-9B0C-1D2E3F4A5B6C}']
    function GetFormatType: TResponseFormatType;
    function GetSchemaName: string;
    function GetSchema: TJSONObject;
    function GetStrict: Boolean;

    procedure SetText;
    procedure SetJSONObject;
    procedure SetSchema(const AName, ASchemaJSON: string; AStrict: Boolean = True); overload;
    procedure SetSchema(const AName: string; const ASchema: TJSONObject; AStrict: Boolean = True); overload;
    procedure SetSchema(AClass: TClass; AStrict: Boolean = True); overload;
    procedure SetSchema(ATypeInfo: Pointer; AStrict: Boolean = True); overload;
    procedure Clear;

    property FormatType: TResponseFormatType read GetFormatType;
    property SchemaName: string read GetSchemaName;
    property Schema: TJSONObject read GetSchema;
    property Strict: Boolean read GetStrict;
  end;

  /// <summary>
  /// Interface especializada para o provedor Ollama
  /// </summary>
  IOllamaProvider = interface(ILLMProvider)
    ['{D1A7E9C4-61B8-4FE2-8924-11D5A720E71A}']
    /// <summary>
    /// Consulta o endpoint /api/tags e retorna a lista de nomes dos modelos locais instalados
    /// </summary>
    function ListModels: TArray<string>;

    /// <summary>
    /// Verifica se a instancia local do Ollama esta em execucao e respondendo
    /// </summary>
    function IsServerRunning: Boolean;
  end;

  /// <summary>
  /// Interface especializada para o provedor Groq
  /// </summary>
  IGroqProvider = interface(ILLMProvider)
    ['{85F84431-4CED-40D7-97D0-309705700CB9}']
    /// <summary>
    /// Consulta o endpoint /openai/v1/models e retorna a lista com os IDs dos modelos disponiveis no Groq
    /// </summary>
    function ListModels: TArray<string>;

    /// <summary>
    /// Metodos de leitura dos cabecalhos de Rate Limits retornados pelo Groq
    /// </summary>
    function GetRateLimitLimitRequests: Integer;
    function GetRateLimitRemainingRequests: Integer;
    function GetRateLimitResetRequests: string;
    function GetRateLimitLimitTokens: Integer;
    function GetRateLimitRemainingTokens: Integer;
    function GetRateLimitResetTokens: string;

    property RateLimitLimitRequests: Integer read GetRateLimitLimitRequests;
    property RateLimitRemainingRequests: Integer read GetRateLimitRemainingRequests;
    property RateLimitResetRequests: string read GetRateLimitResetRequests;
    property RateLimitLimitTokens: Integer read GetRateLimitLimitTokens;
    property RateLimitRemainingTokens: Integer read GetRateLimitRemainingTokens;
    property RateLimitResetTokens: string read GetRateLimitResetTokens;
  end;

implementation

end.