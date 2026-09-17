unit LLM.Interfaces;

interface
uses
  System.JSON,
  LLM.HistoryStrategy,
  LLM.Tools;

type

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
  end;

implementation

end.