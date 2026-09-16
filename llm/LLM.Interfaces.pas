unit LLM.Interfaces;

interface
uses
  System.JSON,
  LLM.HistoryStrategy;

type
  

  ILLMProvider = interface
    ['{E4627A59-5B8F-4D2A-94B6-1E27B13C4509}']
    // Getters e Setters das propriedades
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

    // Métodos do provedor
    procedure ClearHistory;
    procedure AddMessage(const ARole, AContent: string);
    procedure AddSystem(const AContent: string);
    procedure AddUser(const AContent: string);
    procedure AddAssistant(const AContent: string);

    // Dispara manualmente o resumo do histórico atual (útil sob demanda)
    procedure SummarizeHistory;

    function Send(out RawJSON: string): string; overload;
    function Send: string; overload;

    // Métodos privados da classe original (detalhes de implementação).
    // Caso queira torná-los parte do contrato da interface, basta descomentar:
    // function BuildBodyJSON(const AModel: string; ATemp: Double; AMaxTok: Integer; AMsgs: TJSONArray): string;
    // function ExtractErrorMessage(const AErrorJSON: string): string;
    // function ExecuteRequest(const ABodyJSON: string; out ARawJSON: string): string;
    // procedure ApplySlidingWindow;
    // procedure ProcessHistory;

    // Propriedades
    property ApiKey: string read GetApiKey write SetApiKey;
    property BaseURL: string read GetBaseURL write SetBaseURL;
    property Model: string read GetModel write SetModel;
    property Temperature: Double read GetTemperature write SetTemperature;
    property MaxTokens: Integer read GetMaxTokens write SetMaxTokens;
    property Timeout: Integer read GetTimeout write SetTimeout;
    property AutoAddAssistantResponse: Boolean read GetAutoAddAssistantResponse write SetAutoAddAssistantResponse;

    // Propriedades de controle de memória/histórico
    property HistoryStrategy: THistoryStrategy read GetHistoryStrategy write SetHistoryStrategy;
    property MaxHistoryMessages: Integer read GetMaxHistoryMessages write SetMaxHistoryMessages;
    property Messages: TJSONArray read GetMessages;
    property KeepRecentMessages: Integer read GetKeepRecentMessages write SetKeepRecentMessages;
    property SummaryModel: string read GetSummaryModel write SetSummaryModel;
    property SummaryPrompt: string read GetSummaryPrompt write SetSummaryPrompt;
  end;


implementation

end.
