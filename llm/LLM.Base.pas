unit LLM.Base;

interface

uses
  LLM.Interfaces,
  LLM.HistoryStrategy,
  LLM.Tools,
  LLM.Tools.RTTI,
  LLM.Schema,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.URLClient,
  System.Net.HttpClient;

type
  /// <summary>
  /// Provedor base para integracao com APIs de LLM compativeis com OpenAI
  /// </summary>
  TLLMProviderBase = class(TInterfacedObject, ILLMProvider)
  private
    // Getters e Setters de Propriedades Basicas
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

    // Getters e Setters de Tools
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

  protected
    FApiKey: string;
    FBaseURL: string;
    FModel: string;
    FTemperature: Double;
    FMaxTokens: Integer;
    FTimeout: Integer;
    FAutoAddAssistantResponse: Boolean;
    FMessages: TJSONArray;
    FHttpClient: THTTPClient;

    // Configuracoes de Historico
    FHistoryStrategy: THistoryStrategy;
    FMaxHistoryMessages: Integer;
    FKeepRecentMessages: Integer;
    FSummaryModel: string;
    FSummaryPrompt: string;

    // Configuracoes e estado de Tools / Function Calling
    FTools: ILLMToolRegistry;
    FRTTIManager: TLLMRTTIManager;
    FAutoExecuteTools: Boolean;
    FMaxToolIterations: Integer;
    FPropagateToolExceptions: Boolean;
    FLastToolCalls: TLLMToolCallList;
    FHasToolCalls: Boolean;
    FOnBeforeExecuteTool: TOnBeforeExecuteToolEvent;
    FOnAfterExecuteTool: TOnAfterExecuteToolEvent;

    // Configuracoes de Saidas Estruturadas (Structured Output)
    FResponseFormat: ILLMResponseFormat;
    function GetResponseFormat: ILLMResponseFormat;

    procedure PrepareHeaders(AClient: THTTPClient); virtual;
    procedure AppendAssistantToolCallsToHistory(const ARawJSON: string); virtual;

    function BuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string; virtual;
    function ExtractErrorMessage(const AErrorJSON: string): string; virtual;
    function ExecuteRequest(const ABodyJSON: string;
      out ARawJSON: string): string; virtual;
    procedure DoAfterReceiveResponse(const AResponse: IHTTPResponse); virtual;

    procedure ApplySlidingWindow; virtual;
    procedure ProcessHistory; virtual;
    procedure SetLastToolCalls(const ACalls: TLLMToolCallList);
  public
    constructor Create(const AApiKey: string; const ABaseURL: string;
      const AModel: string);
    destructor Destroy; override;

    procedure ClearHistory;
    procedure AddMessage(const ARole, AContent: string);
    procedure AddSystem(const AContent: string); inline;
    procedure AddUser(const AContent: string); inline;
    procedure AddAssistant(const AContent: string); inline;

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
    procedure AddToolResult(const AToolCallId, AContent: string);

    procedure SummarizeHistory;

    function Send(out RawJSON: string): string; overload;
    function Send: string; overload;

    property Messages: TJSONArray read GetMessages;

    property ApiKey: string read GetApiKey write SetApiKey;
    property BaseURL: string read GetBaseURL write SetBaseURL;
    property Model: string read GetModel write SetModel;
    property Temperature: Double read GetTemperature write SetTemperature;
    property MaxTokens: Integer read GetMaxTokens write SetMaxTokens;
    property Timeout: Integer read GetTimeout write SetTimeout;
    property AutoAddAssistantResponse: Boolean read GetAutoAddAssistantResponse
      write SetAutoAddAssistantResponse;

    property HistoryStrategy: THistoryStrategy read GetHistoryStrategy
      write SetHistoryStrategy;
    property MaxHistoryMessages: Integer read GetMaxHistoryMessages
      write SetMaxHistoryMessages;
    property KeepRecentMessages: Integer read GetKeepRecentMessages
      write SetKeepRecentMessages;
    property SummaryModel: string read GetSummaryModel write SetSummaryModel;
    property SummaryPrompt: string read GetSummaryPrompt write SetSummaryPrompt;

    property AutoExecuteTools: Boolean read GetAutoExecuteTools write SetAutoExecuteTools;
    property MaxToolIterations: Integer read GetMaxToolIterations write SetMaxToolIterations;
    property PropagateToolExceptions: Boolean read GetPropagateToolExceptions write SetPropagateToolExceptions;
    property LastToolCalls: TLLMToolCallList read GetLastToolCalls;
    property HasToolCalls: Boolean read GetHasToolCalls;
    property Tools: ILLMToolRegistry read GetTools;

    property OnBeforeExecuteTool: TOnBeforeExecuteToolEvent read GetOnBeforeExecuteTool write SetOnBeforeExecuteTool;
    property OnAfterExecuteTool: TOnAfterExecuteToolEvent read GetOnAfterExecuteTool write SetOnAfterExecuteTool;

    // Metodos e propriedades de Saidas Estruturadas (Structured Output)
    function SendAsJSON: TJSONObject;
    function SendAs(AClass: TClass): TObject; overload;
    procedure SendAs(ATypeInfo: Pointer; out Buffer); overload;

    property ResponseFormat: ILLMResponseFormat read GetResponseFormat;

  end;

  /// <summary>
  /// Class helper para permitir chamada fluente de SendAs<T> diretamente na instancia da classe
  /// </summary>
  TLLMProviderBaseHelper = class helper for TLLMProviderBase
  public
    function SendAs<T>: T;
    procedure SetResponseSchema<T>(AStrict: Boolean = True);
  end;

implementation

uses
  LLM.Exceptions,
  Utils.JSONArray;

constructor TLLMProviderBase.Create(const AApiKey, ABaseURL, AModel: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel := AModel;
  FBaseURL := ABaseURL;
  FTemperature := 0.7;
  FMaxTokens := 0;
  FTimeout := 60000;
  FAutoAddAssistantResponse := True;

  // Configuracoes padrao de historico
  FHistoryStrategy := hsSlidingWindow;
  FMaxHistoryMessages := 10;
  FKeepRecentMessages := 4;
  FSummaryModel := EmptyStr;
  FSummaryPrompt :=
    'Sintetize os pontos principais, variaveis e decisoes desta conversa:';

  // Inicializacao de Tools / Function Calling
  FTools := TLLMToolRegistry.Create;
  FRTTIManager := TLLMRTTIManager.Create(FTools);
  FAutoExecuteTools := True;
  FMaxToolIterations := 10;
  FPropagateToolExceptions := False;
  FHasToolCalls := False;
  SetLength(FLastToolCalls, 0);
  FOnBeforeExecuteTool := nil;
  FOnAfterExecuteTool := nil;

  FMessages := TJSONArray.Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;

  FResponseFormat := TLLMResponseFormat.Create;
end;

destructor TLLMProviderBase.Destroy;
begin
  FRTTIManager.Free;
  FHttpClient.Free;
  FMessages.Free;
  inherited;
end;

procedure TLLMProviderBase.ClearHistory;
begin
  FMessages.Clear;
  FHasToolCalls := False;
  SetLength(FLastToolCalls, 0);
end;

procedure TLLMProviderBase.AddMessage(const ARole, AContent: string);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create;
  LMsg.AddPair('role', ARole);
  LMsg.AddPair('content', AContent);
  FMessages.AddElement(LMsg);
end;

procedure TLLMProviderBase.AddSystem(const AContent: string);
begin
  AddMessage('system', AContent);
end;

procedure TLLMProviderBase.AddUser(const AContent: string);
begin
  AddMessage('user', AContent);
end;

procedure TLLMProviderBase.AddAssistant(const AContent: string);
begin
  AddMessage('assistant', AContent);
end;

procedure TLLMProviderBase.AddToolResult(const AToolCallId, AContent: string);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create;
  LMsg.AddPair('role', 'tool');
  LMsg.AddPair('tool_call_id', AToolCallId);
  LMsg.AddPair('content', AContent);
  FMessages.AddElement(LMsg);
end;

procedure TLLMProviderBase.RegisterTool(const ATool: ILLMTool);
begin
  FTools.RegisterTool(ATool);
end;

procedure TLLMProviderBase.RegisterTool(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolCallback);
begin
  FTools.RegisterTool(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMProviderBase.RegisterTool(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolCallback);
begin
  FTools.RegisterTool(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMProviderBase.RegisterTool(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolJSONCallback);
begin
  FTools.RegisterTool(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMProviderBase.RegisterTool(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback);
begin
  FTools.RegisterTool(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMProviderBase.RegisterFunction(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolCallback);
begin
  FTools.RegisterFunction(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMProviderBase.RegisterFunction(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolCallback);
begin
  FTools.RegisterFunction(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMProviderBase.RegisterFunction(const AName, ADescription,
  AParametersSchemaJSON: string; const AHandler: TToolJSONCallback);
begin
  FTools.RegisterFunction(AName, ADescription, AParametersSchemaJSON, AHandler);
end;

procedure TLLMProviderBase.RegisterFunction(const AName, ADescription: string;
  const AParametersSchema: TJSONObject; const AHandler: TToolJSONCallback);
begin
  FTools.RegisterFunction(AName, ADescription, AParametersSchema, AHandler);
end;

procedure TLLMProviderBase.UnregisterTool(const AName: string);
begin
  FTools.Unregister(AName);
end;

procedure TLLMProviderBase.ClearTools;
begin
  FTools.Clear;
  FRTTIManager.ClearTools;
end;

function TLLMProviderBase.BuildBodyJSON(const AModel: string; ATemp: Double;
  AMaxTok: Integer; AMsgs: TJSONArray): string;
var
  LBody: TJSONObject;
  LOldOwned: Boolean;
  LToolsArray: TJSONArray;
  LRespFmt, LSchemaObj: TJSONObject;
  LMsgsToSend: TJSONArray;
  LSysInstruction: TJSONObject;
  LHasSchema: Boolean;
begin
  LBody := TJSONObject.Create;
  LOldOwned := AMsgs.Owned;
  try
    LBody.AddPair('model', AModel);

    LHasSchema := Assigned(FResponseFormat) and (FResponseFormat.FormatType = rfJSONSchema) and
      (FResponseFormat.Schema <> nil);

    if LHasSchema and (Pos('11434', FBaseURL) > 0) then
    begin
      LMsgsToSend := AMsgs.Clone as TJSONArray;
      LSysInstruction := TJSONObject.Create;
      LSysInstruction.AddPair('role', 'system');
      if Assigned(FTools) and (FTools.Count > 0) then
        LSysInstruction.AddPair('content',
          'IMPORTANTE: Voce pode utilizar as ferramentas disponiveis para obter informacoes se necessario. Ao gerar a resposta final (ou caso ferramentas nao sejam necessarias), responda ESTRITAMENTE em formato JSON valido em conformidade com este schema: ' +
          FResponseFormat.Schema.ToJSON)
      else
        LSysInstruction.AddPair('content',
          'IMPORTANTE: Responda ESTRITAMENTE em formato JSON valido em conformidade com este schema: ' +
          FResponseFormat.Schema.ToJSON);
      LMsgsToSend.AddElement(LSysInstruction);
      LBody.AddPair('messages', LMsgsToSend);
    end
    else
    begin
      // Impede que LBody.Free destrua o array AMsgs compartilhado
      AMsgs.Owned := False;
      LBody.AddPair('messages', AMsgs);
    end;

    if ATemp >= 0 then
      LBody.AddPair('temperature', TJSONNumber.Create(ATemp));

    if AMaxTok > 0 then
      LBody.AddPair('max_tokens', TJSONNumber.Create(AMaxTok));

    // Se houver tools registradas
    if Assigned(FTools) and (FTools.Count > 0) then
    begin
      LToolsArray := FTools.ToJSONArray;
      LBody.AddPair('tools', LToolsArray);
      LBody.AddPair('tool_choice', 'auto');
    end;

    // Se houver configuracao de Structured Output (response_format)
    if Assigned(FResponseFormat) then
    begin
      case FResponseFormat.FormatType of
        rfJSONObject:
        begin
          LRespFmt := TJSONObject.Create;
          LRespFmt.AddPair('type', 'json_object');
          LBody.AddPair('response_format', LRespFmt);
          if Pos('11434', FBaseURL) > 0 then
            LBody.AddPair('format', 'json');
        end;
        rfJSONSchema:
        begin
          if FResponseFormat.Schema <> nil then
          begin
            LRespFmt := TJSONObject.Create;
            LRespFmt.AddPair('type', 'json_schema');

            LSchemaObj := TJSONObject.Create;
            LSchemaObj.AddPair('name', FResponseFormat.SchemaName);
            LSchemaObj.AddPair('strict', FResponseFormat.Strict);
            LSchemaObj.AddPair('schema', FResponseFormat.Schema.Clone as TJSONObject);

            LRespFmt.AddPair('json_schema', LSchemaObj);
            LBody.AddPair('response_format', LRespFmt);

            if Pos('11434', FBaseURL) > 0 then
            begin
              if AModel.ToLower.Contains('cloud') then
                LBody.AddPair('format', 'json')
              else
                LBody.AddPair('format', FResponseFormat.Schema.Clone as TJSONObject);
            end;
          end;
        end;
      end;
    end;

    LBody.AddPair('stream', False);
    Result := LBody.ToJSON;
  finally
    LBody.Free;
    AMsgs.Owned := LOldOwned;
  end;
end;

function TLLMProviderBase.ExtractErrorMessage(const AErrorJSON: string): string;
var
  LVal, LErrVal: TJSONValue;
  LObj, LErr: TJSONObject;
begin
  Result := AErrorJSON;
  LVal := TJSONObject.ParseJSONValue(AErrorJSON);
  if LVal is TJSONObject then
  begin
    LObj := TJSONObject(LVal);
    try
      LErrVal := LObj.FindValue('error');
      if LErrVal is TJSONObject then
      begin
        LErr := TJSONObject(LErrVal);
        Result := LErr.GetValue<string>('message', AErrorJSON);
      end
      else if LErrVal is TJSONString then
        Result := LErrVal.Value;
    finally
      LObj.Free;
    end;
  end
  else if Assigned(LVal) then
    LVal.Free;
end;

procedure TLLMProviderBase.PrepareHeaders(AClient: THTTPClient);
begin
  if not FApiKey.Trim.IsEmpty then
    AClient.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
  AClient.CustomHeaders['Content-Type'] := 'application/json';
end;

procedure TLLMProviderBase.SetLastToolCalls(const ACalls: TLLMToolCallList);
begin
  FLastToolCalls := ACalls;
  FHasToolCalls := Length(FLastToolCalls) > 0;
end;

procedure TLLMProviderBase.DoAfterReceiveResponse(const AResponse: IHTTPResponse);
begin
  // Hook virtual para subclasses processarem headers e status da resposta HTTP
end;

function TLLMProviderBase.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LResp: IHTTPResponse;
  LSResp: string;
  LStream: TStringStream;
  LVal: TJSONValue;
  LJSON, LChoice, LMsg: TJSONObject;
  LChoices, LToolCallsArr: TJSONArray;
  LChoicesVal, LMsgVal, LToolsVal, LFuncVal, LContentVal: TJSONValue;
  I: Integer;
  LCallObj, LFuncObj: TJSONObject;
  LId, LName, LArgs: string;
  LCalls: TLLMToolCallList;
begin
  Result := EmptyStr;
  ARawJSON := EmptyStr;
  SetLastToolCalls([]);

  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
  PrepareHeaders(FHttpClient);

  LStream := TStringStream.Create(ABodyJSON, TEncoding.UTF8);
  try
    LResp := FHttpClient.Post(FBaseURL, LStream);
  finally
    LStream.Free;
  end;
 
  DoAfterReceiveResponse(LResp);

  LSResp := LResp.ContentAsString(TEncoding.UTF8);
  ARawJSON := LSResp;

  if LResp.StatusCode <> 200 then
    raise ELLMAPIError.CreateFmt('Erro API [%d]: %s',
      [LResp.StatusCode, ExtractErrorMessage(LSResp)]);

  LVal := TJSONObject.ParseJSONValue(LSResp);
  if not(LVal is TJSONObject) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    raise Exception.Create
      ('A resposta retornada pela API nao e um JSON valido.');
  end;

  LJSON := TJSONObject(LVal);
  try
    LChoicesVal := LJSON.FindValue('choices');
    if not (LChoicesVal is TJSONArray) or (TJSONArray(LChoicesVal).Count = 0) then
      raise Exception.Create('Nenhum no "choices" retornado pela API.');

    LChoices := TJSONArray(LChoicesVal);
    if not (LChoices.Items[0] is TJSONObject) then
      raise Exception.Create('Primeiro choice nao e um objeto JSON.');

    LChoice := TJSONObject(LChoices.Items[0]);
    LMsgVal := LChoice.FindValue('message');
    if not (LMsgVal is TJSONObject) then
      raise Exception.Create('Objeto "message" ausente no choice.');

    LMsg := TJSONObject(LMsgVal);

    // Verifica se ha solicitacao de tool_calls
    LToolsVal := LMsg.FindValue('tool_calls');
    if (LToolsVal is TJSONArray) and (TJSONArray(LToolsVal).Count > 0) then
    begin
      LToolCallsArr := TJSONArray(LToolsVal);
      SetLength(LCalls, LToolCallsArr.Count);
      for I := 0 to LToolCallsArr.Count - 1 do
      begin
        if LToolCallsArr.Items[I] is TJSONObject then
        begin
          LCallObj := TJSONObject(LToolCallsArr.Items[I]);
          LId := LCallObj.GetValue<string>('id', EmptyStr);
          LName := EmptyStr;
          LArgs := EmptyStr;
          LFuncVal := LCallObj.FindValue('function');
          if LFuncVal is TJSONObject then
          begin
            LFuncObj := TJSONObject(LFuncVal);
            LName := LFuncObj.GetValue<string>('name', EmptyStr);
            LArgs := LFuncObj.GetValue<string>('arguments', EmptyStr);
          end;
          LCalls[I] := TLLMToolCall.Create(LId, LName, LArgs);
        end;
      end;
      SetLastToolCalls(LCalls);
    end;

    LContentVal := LMsg.FindValue('content');
    if (LContentVal <> nil) and not(LContentVal is TJSONNull) then
      Result := LContentVal.Value
    else
      Result := EmptyStr;
  finally
    LJSON.Free;
  end;
end;

procedure TLLMProviderBase.ApplySlidingWindow;
var
  LSystemOffset: Integer;
  LVal: TJSONValue;
  LItemObj: TJSONObject;
begin
  if (FMaxHistoryMessages <= 0) or (FMessages.Count <= FMaxHistoryMessages) then
    Exit;

  LSystemOffset := 0;
  // Protege a instrucao de sistema no topo caso exista
  if (FMessages.Count > 0) and (FMessages.Items[0] is TJSONObject) then
  begin
    if TJSONObject(FMessages.Items[0]).GetValue<string>('role', EmptyStr) = 'system' then
      LSystemOffset := 1;
  end;

  while (FMessages.Count > FMaxHistoryMessages) and
    (FMessages.Count > LSystemOffset) do
  begin
    LItemObj := FMessages.Items[LSystemOffset] as TJSONObject;

    // Se estiver removendo um assistant que chamou ferramentas, remove tambem as respostas 'tool' correspondentes
    if (LItemObj.GetValue<string>('role', EmptyStr) = 'assistant') and
       (LItemObj.FindValue('tool_calls') <> nil) then
    begin
      LVal := FMessages.Remove(LSystemOffset);
      LVal.Free;

      // Remove todas as mensagens 'tool' que se seguiam a ele
      while (FMessages.Count > LSystemOffset) and (FMessages.Items[LSystemOffset] is TJSONObject) and
            (TJSONObject(FMessages.Items[LSystemOffset]).GetValue<string>('role', EmptyStr) = 'tool') do
      begin
        LVal := FMessages.Remove(LSystemOffset);
        LVal.Free;
      end;
    end
    else
    begin
      LVal := FMessages.Remove(LSystemOffset);
      LVal.Free;
    end;
  end;

  // Garante que nao sobrou mensagem 'tool' orfa sem o seu assistant chamador
  while (FMessages.Count > LSystemOffset) and (FMessages.Items[LSystemOffset] is TJSONObject) and
        (TJSONObject(FMessages.Items[LSystemOffset]).GetValue<string>('role', EmptyStr) = 'tool') do
  begin
    LVal := FMessages.Remove(LSystemOffset);
    LVal.Free;
  end;
end;

procedure TLLMProviderBase.SummarizeHistory;
var
  LHasSystem: Boolean;
  LStartIdx, LCountToSummarize, I: Integer;
  LTranscript, LSummaryText, LDummyRaw, LModelToUse: string;
  LItem, LSummarySys, LSummaryUser, LSummaryBlock: TJSONObject;
  LReqMsgs, LNewMessages: TJSONArray;
  LBodyJSON: string;
begin
  LHasSystem := (FMessages.Count > 0) and (FMessages.Items[0] is TJSONObject)
    and (TJSONObject(FMessages.Items[0]).GetValue<string>('role', EmptyStr)
    = 'system');

  LStartIdx := 0;
  if LHasSystem then
    LStartIdx := 1;

  LCountToSummarize := (FMessages.Count - LStartIdx) - FKeepRecentMessages;
  if LCountToSummarize <= 0 then
    Exit;

  // 1. Monta o historico a ser resumido
  LTranscript := EmptyStr;
  for I := LStartIdx to (LStartIdx + LCountToSummarize - 1) do
  begin
    if FMessages.Items[I] is TJSONObject then
    begin
      LItem := TJSONObject(FMessages.Items[I]);

      if LItem.FindValue('tool_calls') <> nil then
        LTranscript := LTranscript + Format('[assistant (chamada de ferramentas)]: %s' + sLineBreak,
          [LItem.FindValue('tool_calls').ToJSON])
      else if LItem.GetValue<string>('role', EmptyStr) = 'tool' then
        LTranscript := LTranscript + Format('[resultado da ferramenta id %s]: %s' + sLineBreak,
          [LItem.GetValue<string>('tool_call_id', EmptyStr),
           LItem.GetValue<string>('content', EmptyStr)])
      else
        LTranscript := LTranscript + Format('[%s]: %s' + sLineBreak,
          [LItem.GetValue<string>('role', EmptyStr),
          LItem.GetValue<string>('content', EmptyStr)]);
    end;
  end;

  // 2. Prepara e executa a chamada de resumo
  LModelToUse := FSummaryModel;
  if LModelToUse.Trim.IsEmpty then
    LModelToUse := FModel;

  LReqMsgs := TJSONArray.Create;
  try
    LSummarySys := TJSONObject.Create;
    LSummarySys.AddPair('role', 'system');
    LSummarySys.AddPair('content',
      'Voce e um assistente encarregado de compactar historicos de chat. ' +
      'Gere um resumo enxuto e objetivo dos topicos discutidos, decisoes tomadas e dados informados, '
      + 'para que o contexto nao se perca.');
    LReqMsgs.AddElement(LSummarySys);

    LSummaryUser := TJSONObject.Create;
    LSummaryUser.AddPair('role', 'user');
    LSummaryUser.AddPair('content', FSummaryPrompt + sLineBreak + sLineBreak +
      LTranscript);
    LReqMsgs.AddElement(LSummaryUser);

    LBodyJSON := BuildBodyJSON(LModelToUse, 0.3, 0, LReqMsgs);
    LSummaryText := ExecuteRequest(LBodyJSON, LDummyRaw);
  finally
    LReqMsgs.Free;
  end;

  if LSummaryText.Trim.IsEmpty then
    Exit;

  // 3. Reconstroi o FMessages
  LNewMessages := TJSONArray.Create;

  // Preserva o System Prompt original no topo
  if LHasSystem then
    LNewMessages.AddElement(FMessages.RemoveFirst);

  // Insere o resumo gerado
  LSummaryBlock := TJSONObject.Create;
  LSummaryBlock.AddPair('role', 'system');
  LSummaryBlock.AddPair('content', '[RESUMO DO HISTORICO ANTERIOR]:' +
    sLineBreak + LSummaryText);
  LNewMessages.AddElement(LSummaryBlock);

  // Libera da memoria as mensagens condensadas
  for I := 1 to LCountToSummarize do
    FMessages.RemoveFirstAndFree;

  // Transfere as mensagens recentes restantes
  while FMessages.Count > 0 do
    LNewMessages.AddElement(FMessages.RemoveFirst);

  FMessages.Free;
  FMessages := LNewMessages;
end;

procedure TLLMProviderBase.ProcessHistory;
begin
  case FHistoryStrategy of
    hsSlidingWindow:
      ApplySlidingWindow;
    hsSummarize:
      begin
        if (FMaxHistoryMessages > 0) and (FMessages.Count > FMaxHistoryMessages)
        then
          SummarizeHistory;
      end;
  end;
end;

procedure TLLMProviderBase.AppendAssistantToolCallsToHistory(const ARawJSON: string);
var
  LVal: TJSONValue;
  LJSON, LChoice: TJSONObject;
  LChoices: TJSONArray;
  LChoicesVal, LMsgVal: TJSONValue;
begin
  LVal := TJSONObject.ParseJSONValue(ARawJSON);
  if LVal is TJSONObject then
  begin
    LJSON := TJSONObject(LVal);
    try
      LChoicesVal := LJSON.FindValue('choices');
      if (LChoicesVal is TJSONArray) and (TJSONArray(LChoicesVal).Count > 0) then
      begin
        LChoices := TJSONArray(LChoicesVal);
        if LChoices.Items[0] is TJSONObject then
        begin
          LChoice := TJSONObject(LChoices.Items[0]);
          LMsgVal := LChoice.FindValue('message');
          if LMsgVal is TJSONObject then
            FMessages.AddElement(LMsgVal.Clone as TJSONObject);
        end;
      end;
    finally
      LJSON.Free;
    end;
  end;
end;

function TLLMProviderBase.Send(out RawJSON: string): string;
var
  LBodyStr: string;
  LIteration: Integer;
  LToolIndex: Integer;
  LToolCall: TLLMToolCall;
  LTool: ILLMTool;
  LToolResult: string;
  LSuccess: Boolean;
begin
  LIteration := 0;

  while True do
  begin
    ProcessHistory;

    LBodyStr := BuildBodyJSON(FModel, FTemperature, FMaxTokens, FMessages);
    Result := ExecuteRequest(LBodyStr, RawJSON);

    // Se nao foram solicitadas chamadas de ferramentas, obtivemos a resposta final
    if not FHasToolCalls then
    begin
      if FAutoAddAssistantResponse and (Result <> EmptyStr) then
        AddAssistant(Result);
      Break;
    end;

    // Se houve tool_calls, anexa a mensagem do assistente com os tool_calls ao historico
    AppendAssistantToolCallsToHistory(RawJSON);

    // Se a execucao automatica estiver desativada (Modo Manual), encerra aqui para o usuario responder
    if not FAutoExecuteTools then
      Break;

    // Modo Automatico: Verifica limite de iteracoes para evitar loops infinitos
    Inc(LIteration);
    if LIteration > FMaxToolIterations then
      raise ELLMMaxToolIterationsException.CreateFmt(
        'Limite maximo de iteracoes de ferramentas atingido (%d)', [FMaxToolIterations]);

    // Executa as ferramentas requisitadas pelo modelo
    for LToolIndex := 0 to Length(FLastToolCalls) - 1 do
    begin
      LToolCall := FLastToolCalls[LToolIndex];

      if Assigned(FOnBeforeExecuteTool) then
        FOnBeforeExecuteTool(LToolCall);

      LSuccess := True;
      LToolResult := EmptyStr;

      try
        if FTools.Find(LToolCall.Name, LTool) then
          LToolResult := LTool.Execute(LToolCall.Arguments)
        else
          raise ELLMToolNotFoundException.CreateFmt('Ferramenta "%s" nao encontrada.', [LToolCall.Name]);
      except
        on E: Exception do
        begin
          LSuccess := False;
          if FPropagateToolExceptions then
            raise
          else
            LToolResult := Format('{"error":"%s"}', [E.Message.Replace('"', '\"')]);
        end;
      end;

      if Assigned(FOnAfterExecuteTool) then
        FOnAfterExecuteTool(LToolCall, LToolResult, LSuccess);

      AddToolResult(LToolCall.Id, LToolResult);
    end;

    // O loop continua, enviando o historico com as respostas das ferramentas de volta ao modelo
  end;
end;

function TLLMProviderBase.Send: string;
var
  LDummy: string;
begin
  Result := Send(LDummy);
end;

function TLLMProviderBase.GetApiKey: string;
begin
  Result := FApiKey;
end;

function TLLMProviderBase.GetAutoAddAssistantResponse: Boolean;
begin
  Result := FAutoAddAssistantResponse;
end;

function TLLMProviderBase.GetAutoExecuteTools: Boolean;
begin
  Result := FAutoExecuteTools;
end;

function TLLMProviderBase.GetBaseURL: string;
begin
  Result := FBaseURL;
end;

function TLLMProviderBase.GetHasToolCalls: Boolean;
begin
  Result := FHasToolCalls;
end;

function TLLMProviderBase.GetHistoryStrategy: THistoryStrategy;
begin
  Result := FHistoryStrategy;
end;

function TLLMProviderBase.GetKeepRecentMessages: Integer;
begin
  Result := FKeepRecentMessages;
end;

function TLLMProviderBase.GetLastToolCalls: TLLMToolCallList;
begin
  Result := FLastToolCalls;
end;

function TLLMProviderBase.GetMaxHistoryMessages: Integer;
begin
  Result := FMaxHistoryMessages;
end;

function TLLMProviderBase.GetMaxTokens: Integer;
begin
  Result := FMaxTokens;
end;

function TLLMProviderBase.GetMaxToolIterations: Integer;
begin
  Result := FMaxToolIterations;
end;

function TLLMProviderBase.GetMessages: TJSONArray;
begin
  Result := FMessages;
end;

function TLLMProviderBase.GetModel: string;
begin
  Result := FModel;
end;

function TLLMProviderBase.GetOnAfterExecuteTool: TOnAfterExecuteToolEvent;
begin
  Result := FOnAfterExecuteTool;
end;

function TLLMProviderBase.GetOnBeforeExecuteTool: TOnBeforeExecuteToolEvent;
begin
  Result := FOnBeforeExecuteTool;
end;

function TLLMProviderBase.GetPropagateToolExceptions: Boolean;
begin
  Result := FPropagateToolExceptions;
end;

function TLLMProviderBase.GetSummaryModel: string;
begin
  Result := FSummaryModel;
end;

function TLLMProviderBase.GetSummaryPrompt: string;
begin
  Result := FSummaryPrompt;
end;

function TLLMProviderBase.GetTemperature: Double;
begin
  Result := FTemperature;
end;

function TLLMProviderBase.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

function TLLMProviderBase.GetTools: ILLMToolRegistry;
begin
  Result := FTools;
end;

procedure TLLMProviderBase.SetApiKey(const Value: string);
begin
  FApiKey := Value;
end;

procedure TLLMProviderBase.SetAutoAddAssistantResponse(const Value: Boolean);
begin
  FAutoAddAssistantResponse := Value;
end;

procedure TLLMProviderBase.SetAutoExecuteTools(const Value: Boolean);
begin
  FAutoExecuteTools := Value;
end;

procedure TLLMProviderBase.SetBaseURL(const Value: string);
begin
  FBaseURL := Value;
end;

procedure TLLMProviderBase.SetHistoryStrategy(const Value: THistoryStrategy);
begin
  FHistoryStrategy := Value;
end;

procedure TLLMProviderBase.SetKeepRecentMessages(const Value: Integer);
begin
  FKeepRecentMessages := Value;
end;

procedure TLLMProviderBase.SetMaxHistoryMessages(const Value: Integer);
begin
  FMaxHistoryMessages := Value;
end;

procedure TLLMProviderBase.SetMaxTokens(const Value: Integer);
begin
  FMaxTokens := Value;
end;

procedure TLLMProviderBase.SetMaxToolIterations(const Value: Integer);
begin
  FMaxToolIterations := Value;
end;

procedure TLLMProviderBase.SetModel(const Value: string);
begin
  FModel := Value;
end;

procedure TLLMProviderBase.SetOnAfterExecuteTool(
  const Value: TOnAfterExecuteToolEvent);
begin
  FOnAfterExecuteTool := Value;
end;

procedure TLLMProviderBase.SetOnBeforeExecuteTool(
  const Value: TOnBeforeExecuteToolEvent);
begin
  FOnBeforeExecuteTool := Value;
end;

procedure TLLMProviderBase.SetPropagateToolExceptions(const Value: Boolean);
begin
  FPropagateToolExceptions := Value;
end;

procedure TLLMProviderBase.SetSummaryModel(const Value: string);
begin
  FSummaryModel := Value;
end;

procedure TLLMProviderBase.SetSummaryPrompt(const Value: string);
begin
  FSummaryPrompt := Value;
end;

procedure TLLMProviderBase.SetTemperature(const Value: Double);
begin
  FTemperature := Value;
end;

procedure TLLMProviderBase.SetTimeout(const Value: Integer);
begin
  FTimeout := Value;
end;

procedure TLLMProviderBase.RegisterTool(const AClass: TClass);
begin
  FRTTIManager.RegisterTool(AClass);
end;

procedure TLLMProviderBase.RegisterTool(const AInstance: TObject);
begin
  FRTTIManager.RegisterTool(AInstance);
end;

function TLLMProviderBase.GetResponseFormat: ILLMResponseFormat;
begin
  Result := FResponseFormat;
end;

function TLLMProviderBase.SendAsJSON: TJSONObject;
var
  LRawResp, LCleanStr: string;
  LVal: TJSONValue;
  LWasText: Boolean;
  LStartIdx, LEndIdx, LFirstBrace, LLastBrace: Integer;
begin
  LWasText := (FResponseFormat.FormatType = rfText);
  if LWasText then
    FResponseFormat.SetJSONObject;

  try
    LRawResp := Send;
    LCleanStr := LRawResp.Trim;

    // 1. Tenta extrair bloco ```json ... ``` ou ``` ... ``` em qualquer ponto do texto
    LStartIdx := Pos('```json', LCleanStr);
    if LStartIdx > 0 then
    begin
      LCleanStr := Copy(LCleanStr, LStartIdx + 7, Length(LCleanStr));
      LEndIdx := Pos('```', LCleanStr);
      if LEndIdx > 0 then
        LCleanStr := Copy(LCleanStr, 1, LEndIdx - 1);
      LCleanStr := LCleanStr.Trim;
    end
    else
    begin
      LStartIdx := Pos('```', LCleanStr);
      if LStartIdx > 0 then
      begin
        LCleanStr := Copy(LCleanStr, LStartIdx + 3, Length(LCleanStr));
        LEndIdx := Pos('```', LCleanStr);
        if LEndIdx > 0 then
          LCleanStr := Copy(LCleanStr, 1, LEndIdx - 1);
        LCleanStr := LCleanStr.Trim;
      end;
    end;

    // 2. Se nao comecar com '{', tenta localizar o primeiro '{' e o ultimo '}'
    if not LCleanStr.StartsWith('{') then
    begin
      LFirstBrace := Pos('{', LCleanStr);
      LLastBrace := LastDelimiter('}', LCleanStr);
      if (LFirstBrace > 0) and (LLastBrace > LFirstBrace) then
        LCleanStr := Copy(LCleanStr, LFirstBrace, LLastBrace - LFirstBrace + 1).Trim;
    end;

    LVal := TJSONObject.ParseJSONValue(LCleanStr);
    if not (LVal is TJSONObject) then
    begin
      if Assigned(LVal) then
        LVal.Free;
      raise Exception.CreateFmt('A resposta da IA nao e um objeto JSON valido: %s', [LRawResp]);
    end;

    Result := TJSONObject(LVal);
  finally
    if LWasText then
      FResponseFormat.Clear;
  end;
end;

function TLLMProviderBase.SendAs(AClass: TClass): TObject;
var
  LJSON: TJSONObject;
  LWasConfigured: Boolean;
begin
  if AClass = nil then
    raise Exception.Create('AClass nao pode ser nil para SendAs.');

  LWasConfigured := (FResponseFormat.FormatType <> rfText);
  if not LWasConfigured then
    FResponseFormat.SetSchema(AClass);

  try
    LJSON := SendAsJSON;
    try
      Result := TLLMJSONDeserializer.DeserializeClass(LJSON, AClass);
    finally
      LJSON.Free;
    end;
  finally
    if not LWasConfigured then
      FResponseFormat.Clear;
  end;
end;

procedure TLLMProviderBase.SendAs(ATypeInfo: Pointer; out Buffer);
var
  LJSON: TJSONObject;
  LWasConfigured: Boolean;
begin
  if ATypeInfo = nil then
    raise Exception.Create('ATypeInfo nao pode ser nil para SendAs.');

  LWasConfigured := (FResponseFormat.FormatType <> rfText);
  if not LWasConfigured then
    FResponseFormat.SetSchema(ATypeInfo);

  try
    LJSON := SendAsJSON;
    try
      TLLMJSONDeserializer.DeserializeRecord(LJSON, ATypeInfo, Buffer);
    finally
      LJSON.Free;
    end;
  finally
    if not LWasConfigured then
      FResponseFormat.Clear;
  end;
end;

{ TLLMProviderBaseHelper }

function TLLMProviderBaseHelper.SendAs<T>: T;
begin
  Result := TLLM<T>.SendAs(Self);
end;

procedure TLLMProviderBaseHelper.SetResponseSchema<T>(AStrict: Boolean);
begin
  TLLM<T>.SetResponseSchema(Self, AStrict);
end;



end.