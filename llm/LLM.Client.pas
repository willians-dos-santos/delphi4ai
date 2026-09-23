unit LLM.Client;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.TypInfo,
  LLM.Interfaces,
  LLM.HistoryStrategy,
  LLM.Tools,
  LLM.Schema;

type
  /// <summary>
  /// Implementacao padrao da interface ILLMSender<T>
  /// </summary>
  TLLMSender<T> = class(TInterfacedObject, ILLMSender<T>)
  private
    FProvider: ILLMProvider;
  public
    constructor Create(const AProvider: ILLMProvider);
    class function New(const AProvider: ILLMProvider): ILLMSender<T>;

    function AddUser(const AContent: string): ILLMSender<T>;
    function AddSystem(const AContent: string): ILLMSender<T>;
    function Send: T; overload;
    function Send(const APrompt: string): T; overload;
    function Send(const APrompt: string; out RawJSON: string): T; overload;
  end;

  /// <summary>
  /// Smart Record que envolve ILLMProvider, permitindo chamadas genericas diretas (ex: LLM.SendAs<T>)
  /// com zero gerenciamento manual de memoria e conversao transparente de/para ILLMProvider.
  /// </summary>
  TLLMClient = record
  private
    FProvider: ILLMProvider;

    procedure CheckAssigned;

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
    function GetResponseFormat: ILLMResponseFormat;
  public
    constructor Create(const AProvider: ILLMProvider);

    // Operadores de conversao implicita / explicita
    class operator Implicit(const AProvider: ILLMProvider): TLLMClient;
    class operator Implicit(const AClient: TLLMClient): ILLMProvider;
    class operator Explicit(const AProvider: ILLMProvider): TLLMClient;
    class operator Equal(const ALeft, ARight: TLLMClient): Boolean;
    class operator NotEqual(const ALeft, ARight: TLLMClient): Boolean;

    function IsAssigned: Boolean;

    // Metodos do provedor delegados
    procedure ClearHistory;
    procedure AddMessage(const ARole, AContent: string);
    procedure AddSystem(const AContent: string);
    procedure AddUser(const AContent: string);
    procedure AddAssistant(const AContent: string);

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

    procedure AddToolResult(const AToolCallId, AContent: string);
    procedure SummarizeHistory;

    function Send(out RawJSON: string): string; overload;
    function Send: string; overload;
    function SendPrompt(const APrompt: string): string; overload;
    function SendPrompt(const APrompt: string; out RawJSON: string): string; overload;

    function SendAsJSON: TJSONObject; overload;
    function SendAsJSON(const APrompt: string): TJSONObject; overload;
    function SendAs(AClass: TClass): TObject; overload;
    procedure SendAs(ATypeInfo: Pointer; out Buffer); overload;

    // Metodos genericos diretos na instancia
    function SendAs<T>: T; overload;
    function SendAs<T>(const APrompt: string): T; overload;
    procedure SetResponseSchema<T>(AStrict: Boolean = True);

    // Fabrica para obter o Typed Sender fluente
    function Sender<T>: ILLMSender<T>;

    // Metodos estaticos utilitarios
    class function SendAs<T>(const AProvider: ILLMProvider): T; overload; static;
    class function SendAs<T>(const AProvider: ILLMProvider; const APrompt: string): T; overload; static;

    // Propriedades delegadas
    property Provider: ILLMProvider read FProvider;
    property ApiKey: string read GetApiKey write SetApiKey;
    property BaseURL: string read GetBaseURL write SetBaseURL;
    property Model: string read GetModel write SetModel;
    property Temperature: Double read GetTemperature write SetTemperature;
    property MaxTokens: Integer read GetMaxTokens write SetMaxTokens;
    property Timeout: Integer read GetTimeout write SetTimeout;
    property AutoAddAssistantResponse: Boolean read GetAutoAddAssistantResponse write SetAutoAddAssistantResponse;

    property HistoryStrategy: THistoryStrategy read GetHistoryStrategy write SetHistoryStrategy;
    property MaxHistoryMessages: Integer read GetMaxHistoryMessages write SetMaxHistoryMessages;
    property KeepRecentMessages: Integer read GetKeepRecentMessages write SetKeepRecentMessages;
    property SummaryModel: string read GetSummaryModel write SetSummaryModel;
    property SummaryPrompt: string read GetSummaryPrompt write SetSummaryPrompt;

    property Messages: TJSONArray read GetMessages;

    property AutoExecuteTools: Boolean read GetAutoExecuteTools write SetAutoExecuteTools;
    property MaxToolIterations: Integer read GetMaxToolIterations write SetMaxToolIterations;
    property PropagateToolExceptions: Boolean read GetPropagateToolExceptions write SetPropagateToolExceptions;
    property LastToolCalls: TLLMToolCallList read GetLastToolCalls;
    property HasToolCalls: Boolean read GetHasToolCalls;
    property Tools: ILLMToolRegistry read GetTools;

    property OnBeforeExecuteTool: TOnBeforeExecuteToolEvent read GetOnBeforeExecuteTool write SetOnBeforeExecuteTool;
    property OnAfterExecuteTool: TOnAfterExecuteToolEvent read GetOnAfterExecuteTool write SetOnAfterExecuteTool;
    property ResponseFormat: ILLMResponseFormat read GetResponseFormat;
  end;

  /// <summary>
  /// Alias conciso para TLLMClient
  /// </summary>
  TLLM = TLLMClient;

/// <summary>
/// Funcao helper global para envolver uma instancia ILLMProvider em um TLLMClient (Smart Record)
/// </summary>
function LLM(const AProvider: ILLMProvider): TLLMClient; inline;

implementation

function LLM(const AProvider: ILLMProvider): TLLMClient;
begin
  Result := TLLMClient.Create(AProvider);
end;

{ TLLMSender<T> }

constructor TLLMSender<T>.Create(const AProvider: ILLMProvider);
begin
  inherited Create;
  if AProvider = nil then
    raise Exception.Create('AProvider nao pode ser nil para TLLMSender<T>.');
  FProvider := AProvider;
end;

class function TLLMSender<T>.New(const AProvider: ILLMProvider): ILLMSender<T>;
begin
  Result := TLLMSender<T>.Create(AProvider);
end;

function TLLMSender<T>.AddUser(const AContent: string): ILLMSender<T>;
begin
  FProvider.AddUser(AContent);
  Result := Self;
end;

function TLLMSender<T>.AddSystem(const AContent: string): ILLMSender<T>;
begin
  FProvider.AddSystem(AContent);
  Result := Self;
end;

function TLLMSender<T>.Send: T;
var
  LRawJSON: string;
begin
  Result := Send('', LRawJSON);
end;

function TLLMSender<T>.Send(const APrompt: string): T;
var
  LRawJSON: string;
begin
  Result := Send(APrompt, LRawJSON);
end;

function TLLMSender<T>.Send(const APrompt: string; out RawJSON: string): T;
var
  LJSON: TJSONObject;
  LWasConfigured: Boolean;
  LTypeInfo: PTypeInfo;
  LObj: TObject;
begin
  if not APrompt.IsEmpty then
    FProvider.AddUser(APrompt);

  LTypeInfo := TypeInfo(T);
  if LTypeInfo = nil then
    raise Exception.Create('Tipo invalido para Send<T>.');

  Result := Default(T);

  LWasConfigured := (FProvider.ResponseFormat.FormatType <> rfText);
  if not LWasConfigured then
    FProvider.ResponseFormat.SetSchema(LTypeInfo);

  try
    LJSON := FProvider.SendAsJSON;
    try
      RawJSON := LJSON.ToJSON;
      if LTypeInfo.Kind = tkClass then
      begin
        LObj := TLLMJSONDeserializer.DeserializeClass(LJSON, GetTypeData(LTypeInfo).ClassType);
        PPointer(@Result)^ := Pointer(LObj);
      end
      else if LTypeInfo.Kind = tkRecord then
      begin
        TLLMJSONDeserializer.DeserializeRecord(LJSON, LTypeInfo, Result);
      end
      else
        raise Exception.CreateFmt('Send<T> suporta apenas classes ou records (tipo: %s).', [LTypeInfo.Name]);
    finally
      LJSON.Free;
    end;
  finally
    if not LWasConfigured then
      FProvider.ResponseFormat.Clear;
  end;
end;

{ TLLMClient }

constructor TLLMClient.Create(const AProvider: ILLMProvider);
begin
  FProvider := AProvider;
end;

class operator TLLMClient.Implicit(const AProvider: ILLMProvider): TLLMClient;
begin
  Result.FProvider := AProvider;
end;

class operator TLLMClient.Implicit(const AClient: TLLMClient): ILLMProvider;
begin
  Result := AClient.FProvider;
end;

class operator TLLMClient.Explicit(const AProvider: ILLMProvider): TLLMClient;
begin
  Result.FProvider := AProvider;
end;

class operator TLLMClient.Equal(const ALeft, ARight: TLLMClient): Boolean;
begin
  Result := (ALeft.FProvider = ARight.FProvider);
end;

class operator TLLMClient.NotEqual(const ALeft, ARight: TLLMClient): Boolean;
begin
  Result := (ALeft.FProvider <> ARight.FProvider);
end;

function TLLMClient.IsAssigned: Boolean;
begin
  Result := Assigned(FProvider);
end;

procedure TLLMClient.CheckAssigned;
begin
  if not Assigned(FProvider) then
    raise Exception.Create('TLLMClient: O provedor LLM nao foi atribuido ou inicializado.');
end;

function TLLMClient.GetApiKey: string;
begin
  CheckAssigned;
  Result := FProvider.ApiKey;
end;

procedure TLLMClient.SetApiKey(const Value: string);
begin
  CheckAssigned;
  FProvider.ApiKey := Value;
end;

function TLLMClient.GetBaseURL: string;
begin
  CheckAssigned;
  Result := FProvider.BaseURL;
end;

procedure TLLMClient.SetBaseURL(const Value: string);
begin
  CheckAssigned;
  FProvider.BaseURL := Value;
end;

function TLLMClient.GetModel: string;
begin
  CheckAssigned;
  Result := FProvider.Model;
end;

procedure TLLMClient.SetModel(const Value: string);
begin
  CheckAssigned;
  FProvider.Model := Value;
end;

function TLLMClient.GetTemperature: Double;
begin
  CheckAssigned;
  Result := FProvider.Temperature;
end;

procedure TLLMClient.SetTemperature(const Value: Double);
begin
  CheckAssigned;
  FProvider.Temperature := Value;
end;

function TLLMClient.GetMaxTokens: Integer;
begin
  CheckAssigned;
  Result := FProvider.MaxTokens;
end;

procedure TLLMClient.SetMaxTokens(const Value: Integer);
begin
  CheckAssigned;
  FProvider.MaxTokens := Value;
end;

function TLLMClient.GetTimeout: Integer;
begin
  CheckAssigned;
  Result := FProvider.Timeout;
end;

procedure TLLMClient.SetTimeout(const Value: Integer);
begin
  CheckAssigned;
  FProvider.Timeout := Value;
end;

function TLLMClient.GetAutoAddAssistantResponse: Boolean;
begin
  CheckAssigned;
  Result := FProvider.AutoAddAssistantResponse;
end;

procedure TLLMClient.SetAutoAddAssistantResponse(const Value: Boolean);
begin
  CheckAssigned;
  FProvider.AutoAddAssistantResponse := Value;
end;

function TLLMClient.GetHistoryStrategy: THistoryStrategy;
begin
  CheckAssigned;
  Result := FProvider.HistoryStrategy;
end;

procedure TLLMClient.SetHistoryStrategy(const Value: THistoryStrategy);
begin
  CheckAssigned;
  FProvider.HistoryStrategy := Value;
end;

function TLLMClient.GetMaxHistoryMessages: Integer;
begin
  CheckAssigned;
  Result := FProvider.MaxHistoryMessages;
end;

procedure TLLMClient.SetMaxHistoryMessages(const Value: Integer);
begin
  CheckAssigned;
  FProvider.MaxHistoryMessages := Value;
end;

function TLLMClient.GetKeepRecentMessages: Integer;
begin
  CheckAssigned;
  Result := FProvider.KeepRecentMessages;
end;

procedure TLLMClient.SetKeepRecentMessages(const Value: Integer);
begin
  CheckAssigned;
  FProvider.KeepRecentMessages := Value;
end;

function TLLMClient.GetSummaryModel: string;
begin
  CheckAssigned;
  Result := FProvider.SummaryModel;
end;

procedure TLLMClient.SetSummaryModel(const Value: string);
begin
  CheckAssigned;
  FProvider.SummaryModel := Value;
end;

function TLLMClient.GetSummaryPrompt: string;
begin
  CheckAssigned;
  Result := FProvider.SummaryPrompt;
end;

procedure TLLMClient.SetSummaryPrompt(const Value: string);
begin
  CheckAssigned;
  FProvider.SummaryPrompt := Value;
end;

function TLLMClient.GetMessages: TJSONArray;
begin
  CheckAssigned;
  Result := FProvider.Messages;
end;

function TLLMClient.GetAutoExecuteTools: Boolean;
begin
  CheckAssigned;
  Result := FProvider.AutoExecuteTools;
end;

procedure TLLMClient.SetAutoExecuteTools(const Value: Boolean);
begin
  CheckAssigned;
  FProvider.AutoExecuteTools := Value;
end;

function TLLMClient.GetMaxToolIterations: Integer;
begin
  CheckAssigned;
  Result := FProvider.MaxToolIterations;
end;

procedure TLLMClient.SetMaxToolIterations(const Value: Integer);
begin
  CheckAssigned;
  FProvider.MaxToolIterations := Value;
end;

function TLLMClient.GetPropagateToolExceptions: Boolean;
begin
  CheckAssigned;
  Result := FProvider.PropagateToolExceptions;
end;

procedure TLLMClient.SetPropagateToolExceptions(const Value: Boolean);
begin
  CheckAssigned;
  FProvider.PropagateToolExceptions := Value;
end;

function TLLMClient.GetHasToolCalls: Boolean;
begin
  CheckAssigned;
  Result := FProvider.HasToolCalls;
end;

function TLLMClient.GetLastToolCalls: TLLMToolCallList;
begin
  CheckAssigned;
  Result := FProvider.LastToolCalls;
end;

function TLLMClient.GetTools: ILLMToolRegistry;
begin
  CheckAssigned;
  Result := FProvider.Tools;
end;

function TLLMClient.GetOnBeforeExecuteTool: TOnBeforeExecuteToolEvent;
begin
  CheckAssigned;
  Result := FProvider.OnBeforeExecuteTool;
end;

procedure TLLMClient.SetOnBeforeExecuteTool(const Value: TOnBeforeExecuteToolEvent);
begin
  CheckAssigned;
  FProvider.OnBeforeExecuteTool := Value;
end;

function TLLMClient.GetOnAfterExecuteTool: TOnAfterExecuteToolEvent;
begin
  CheckAssigned;
  Result := FProvider.OnAfterExecuteTool;
end;

procedure TLLMClient.SetOnAfterExecuteTool(const Value: TOnAfterExecuteToolEvent);
begin
  CheckAssigned;
  FProvider.OnAfterExecuteTool := Value;
end;

function TLLMClient.GetResponseFormat: ILLMResponseFormat;
begin
  CheckAssigned;
  Result := FProvider.ResponseFormat;
end;

procedure TLLMClient.ClearHistory;
begin
  CheckAssigned;
  FProvider.ClearHistory;
end;

procedure TLLMClient.AddMessage(const ARole, AContent: string);
begin
  CheckAssigned;
  FProvider.AddMessage(ARole, AContent);
end;

procedure TLLMClient.AddSystem(const AContent: string);
begin
  CheckAssigned;
  FProvider.AddSystem(AContent);
end;

procedure TLLMClient.AddUser(const AContent: string);
begin
  CheckAssigned;
  FProvider.AddUser(AContent);
end;

procedure TLLMClient.AddAssistant(const AContent: string);
begin
  CheckAssigned;
  FProvider.AddAssistant(AContent);
end;

procedure TLLMClient.RegisterTool(const ATool: ILLMTool);
begin
  CheckAssigned;
  FProvider.RegisterTool(ATool);
end;

procedure TLLMClient.RegisterTool(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback);
begin
  CheckAssigned;
  FProvider.RegisterTool(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMClient.RegisterTool(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback);
begin
  CheckAssigned;
  FProvider.RegisterTool(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMClient.RegisterTool(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback);
begin
  CheckAssigned;
  FProvider.RegisterTool(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMClient.RegisterTool(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback);
begin
  CheckAssigned;
  FProvider.RegisterTool(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMClient.RegisterFunction(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolCallback);
begin
  CheckAssigned;
  FProvider.RegisterFunction(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMClient.RegisterFunction(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolCallback);
begin
  CheckAssigned;
  FProvider.RegisterFunction(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMClient.RegisterFunction(const AName, ADescription, AParametersSchemaJSON: string; const AHandler: TToolJSONCallback);
begin
  CheckAssigned;
  FProvider.RegisterFunction(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMClient.RegisterFunction(const AName, ADescription: string; const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback);
begin
  CheckAssigned;
  FProvider.RegisterFunction(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMClient.RegisterTool(const AClass: TClass);
begin
  CheckAssigned;
  FProvider.RegisterTool(AClass);
end;

procedure TLLMClient.RegisterTool(const AInstance: TObject);
begin
  CheckAssigned;
  FProvider.RegisterTool(AInstance);
end;

procedure TLLMClient.UnregisterTool(const AName: string);
begin
  CheckAssigned;
  FProvider.UnregisterTool(AName);
end;

procedure TLLMClient.ClearTools;
begin
  CheckAssigned;
  FProvider.ClearTools;
end;

procedure TLLMClient.AddToolResult(const AToolCallId, AContent: string);
begin
  CheckAssigned;
  FProvider.AddToolResult(AToolCallId, AContent);
end;

procedure TLLMClient.SummarizeHistory;
begin
  CheckAssigned;
  FProvider.SummarizeHistory;
end;

function TLLMClient.Send(out RawJSON: string): string;
begin
  CheckAssigned;
  Result := FProvider.Send(RawJSON);
end;

function TLLMClient.Send: string;
begin
  CheckAssigned;
  Result := FProvider.Send;
end;

function TLLMClient.SendPrompt(const APrompt: string): string;
begin
  CheckAssigned;
  FProvider.AddUser(APrompt);
  Result := FProvider.Send;
end;

function TLLMClient.SendPrompt(const APrompt: string; out RawJSON: string): string;
begin
  CheckAssigned;
  FProvider.AddUser(APrompt);
  Result := FProvider.Send(RawJSON);
end;

function TLLMClient.SendAsJSON: TJSONObject;
begin
  CheckAssigned;
  Result := FProvider.SendAsJSON;
end;

function TLLMClient.SendAsJSON(const APrompt: string): TJSONObject;
begin
  CheckAssigned;
  FProvider.AddUser(APrompt);
  Result := FProvider.SendAsJSON;
end;

function TLLMClient.SendAs(AClass: TClass): TObject;
begin
  CheckAssigned;
  Result := FProvider.SendAs(AClass);
end;

procedure TLLMClient.SendAs(ATypeInfo: Pointer; out Buffer);
begin
  CheckAssigned;
  FProvider.SendAs(ATypeInfo, Buffer);
end;

function TLLMClient.SendAs<T>: T;
begin
  CheckAssigned;
  Result := TLLM<T>.SendAs(FProvider);
end;

function TLLMClient.SendAs<T>(const APrompt: string): T;
begin
  CheckAssigned;
  FProvider.AddUser(APrompt);
  Result := TLLM<T>.SendAs(FProvider);
end;

procedure TLLMClient.SetResponseSchema<T>(AStrict: Boolean);
begin
  CheckAssigned;
  TLLM<T>.SetResponseSchema(FProvider, AStrict);
end;

function TLLMClient.Sender<T>: ILLMSender<T>;
begin
  CheckAssigned;
  Result := TLLMSender<T>.Create(FProvider);
end;

class function TLLMClient.SendAs<T>(const AProvider: ILLMProvider): T;
begin
  Result := TLLM<T>.SendAs(AProvider);
end;

class function TLLMClient.SendAs<T>(const AProvider: ILLMProvider; const APrompt: string): T;
begin
  if AProvider = nil then
    raise Exception.Create('Provedor LLM nao pode ser nulo.');
  AProvider.AddUser(APrompt);
  Result := TLLM<T>.SendAs(AProvider);
end;

end.
