unit LLM.Base;

interface

uses

  LLM.Interfaces,
  LLM.HistoryStrategy,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.URLClient,
  System.Net.HttpClient;

type
  // <summary>
  // Provedor base
  // </summary>
  TLLMProviderBase = class(TInterfacedObject, ILLMProvider)
  private
    FApiKey: string;
    FBaseURL: string;
    FModel: string;
    FTemperature: Double;
    FMaxTokens: Integer;
    FTimeout: Integer;
    FAutoAddAssistantResponse: Boolean;
    FMessages: TJSONArray;
    FHttpClient: THTTPClient;

    // Configurações de Histórico
    FHistoryStrategy: THistoryStrategy;
    FMaxHistoryMessages: Integer;
    FKeepRecentMessages: Integer;
    FSummaryModel: string;
    FSummaryPrompt: string;

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

    function BuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string;
    function ExtractErrorMessage(const AErrorJSON: string): string;
    function ExecuteRequest(const ABodyJSON: string;
      out ARawJSON: string): string;

    procedure ApplySlidingWindow;
    procedure ProcessHistory;
  public
    constructor Create(const AApiKey: string; const ABaseURL:String;
      const AModel: string);
    destructor Destroy; override;

    procedure ClearHistory;
    procedure AddMessage(const ARole, AContent: string);
    procedure AddSystem(const AContent: string); inline;
    procedure AddUser(const AContent: string); inline;
    procedure AddAssistant(const AContent: string); inline;

    procedure SummarizeHistory;

    function Send(out RawJSON: string): string; overload;
    function Send: string; overload;

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
  end;

implementation
uses
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

  // Configurações padrão de histórico
  FHistoryStrategy := hsSlidingWindow;
  FMaxHistoryMessages := 10;
  FKeepRecentMessages := 4;
  FSummaryModel := EmptyStr; // Se vazio, usa o mesmo FModel
  FSummaryPrompt :=
    'Sintetize os pontos principais, variáveis e decisões desta conversa:';

  FMessages := TJSONArray.Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
end;

destructor TLLMProviderBase.Destroy;
begin
  FHttpClient.Free;
  FMessages.Free;
  inherited;
end;

procedure TLLMProviderBase.ClearHistory;
begin
  FMessages.Clear;
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

function TLLMProviderBase.BuildBodyJSON(const AModel: string; ATemp: Double;
  AMaxTok: Integer; AMsgs: TJSONArray): string;
var
  LBody: TJSONObject;
begin
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('model', AModel);
    LBody.AddPair('messages', AMsgs);

    if ATemp >= 0 then
      LBody.AddPair('temperature', TJSONNumber.Create(ATemp));

    if AMaxTok > 0 then
      LBody.AddPair('max_tokens', TJSONNumber.Create(AMaxTok));

    Result := LBody.ToJSON;
  finally
    // Desvincula o array antes de dar Free no container para evitar AV/Double Free
    LBody.RemovePair('messages');
    LBody.Free;
  end;
end;

function TLLMProviderBase.ExtractErrorMessage(const AErrorJSON: string): string;
var
  LVal: TJSONValue;
  LObj, LErr: TJSONObject;
begin
  Result := AErrorJSON;
  LVal := TJSONObject.ParseJSONValue(AErrorJSON);
  if LVal is TJSONObject then
  begin
    LObj := TJSONObject(LVal);
    try
      if LObj.TryGetValue<TJSONObject>('error', LErr) then
        Result := LErr.GetValue<string>('message', AErrorJSON);
    finally
      LObj.Free;
    end;
  end
  else
    LVal.Free;
end;

function TLLMProviderBase.GetApiKey: string;
begin
  Result := FApiKey;
end;

function TLLMProviderBase.GetAutoAddAssistantResponse: Boolean;
begin
  Result := FAutoAddAssistantResponse;
end;

function TLLMProviderBase.GetBaseURL: string;
begin
  Result := FBaseURL;
end;

function TLLMProviderBase.GetHistoryStrategy: THistoryStrategy;
begin
  Result := FHistoryStrategy;
end;

function TLLMProviderBase.GetKeepRecentMessages: Integer;
begin
  Result := FKeepRecentMessages;
end;

function TLLMProviderBase.GetMaxHistoryMessages: Integer;
begin
  Result := FMaxHistoryMessages;
end;

function TLLMProviderBase.GetMaxTokens: Integer;
begin
  Result := FMaxTokens;
end;

function TLLMProviderBase.GetModel: string;
begin
  Result := FModel;
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

function TLLMProviderBase.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LResp: IHTTPResponse;
  LSResp: string;
  LStream: TStringStream;
  LVal: TJSONValue;
  LJSON, LChoice, LMsg: TJSONObject;
  LChoices: TJSONArray;
  LContentVal: TJSONValue;
begin
  Result := EmptyStr;
  ARawJSON := EmptyStr;

  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
  FHttpClient.CustomHeaders['Content-Type'] := 'application/json';

  LStream := TStringStream.Create(ABodyJSON, TEncoding.UTF8);
  try
    LResp := FHttpClient.Post(FBaseURL, LStream);
  finally
    LStream.Free;
  end;

  LSResp := LResp.ContentAsString(TEncoding.UTF8);
  ARawJSON := LSResp;

  if LResp.StatusCode <> 200 then
    raise Exception.CreateFmt('Erro API [%d]: %s',
      [LResp.StatusCode, ExtractErrorMessage(LSResp)]);

  LVal := TJSONObject.ParseJSONValue(LSResp);
  if not(LVal is TJSONObject) then
  begin
    LVal.Free;
    raise Exception.Create
      ('A resposta retornada pela API não é um JSON válido.');
  end;

  LJSON := TJSONObject(LVal);
  try
    if not LJSON.TryGetValue<TJSONArray>('choices', LChoices) or
      (LChoices.Count = 0) then
      raise Exception.Create('Nenhum nó "choices" retornado pela API.');

    LChoice := LChoices.Items[0] as TJSONObject;
    if not LChoice.TryGetValue<TJSONObject>('message', LMsg) then
      raise Exception.Create('Objeto "message" ausente no choice.');

    if LMsg.TryGetValue<TJSONValue>('content', LContentVal) and
      not(LContentVal is TJSONNull) then
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
begin
  if (FMaxHistoryMessages <= 0) or (FMessages.Count <= FMaxHistoryMessages) then
    Exit;

  LSystemOffset := 0;
  // Protege a instrução de sistema no topo caso exista
  if (FMessages.Count > 0) and (FMessages.Items[0] is TJSONObject) then
  begin
    if TJSONObject(FMessages.Items[0]).GetValue<string>('role', EmptyStr) = 'system'
    then
      LSystemOffset := 1;
  end;

  while (FMessages.Count > FMaxHistoryMessages) and
    (FMessages.Count > LSystemOffset) do
  begin
    LVal := FMessages.Remove(LSystemOffset);
    LVal.Free; // Libera o objeto removido para evitar memory leak
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
    Exit; // Sem mensagens suficientes para condensar

  // 1. Monta o histórico a ser resumido
  LTranscript := EmptyStr;
  for I := LStartIdx to (LStartIdx + LCountToSummarize - 1) do
  begin
    if FMessages.Items[I] is TJSONObject then
    begin
      LItem := TJSONObject(FMessages.Items[I]);
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
      'Você é um assistente encarregado de compactar históricos de chat. ' +
      'Gere um resumo enxuto e objetivo dos tópicos discutidos, decisões tomadas e dados informados, '
      + 'para que o contexto não se perca.');
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

  // 3. Reconstrói o FMessages de forma segura e sem vazamento de memória
  LNewMessages := TJSONArray.Create;

  // Preserva o System Prompt original no topo
  if LHasSystem then
    LNewMessages.AddElement(FMessages.RemoveFirst);

  // Insere o resumo gerado logo após as instruções de sistema
  LSummaryBlock := TJSONObject.Create;
  LSummaryBlock.AddPair('role', 'system');
  LSummaryBlock.AddPair('content', '[RESUMO DO HISTÓRICO ANTERIOR]:' +
    sLineBreak + LSummaryText);
  LNewMessages.AddElement(LSummaryBlock);

  // Libera da memória as mensagens que foram condensadas
  for I := 1 to LCountToSummarize do
    FMessages.RemoveFirstAndFree;

  // Transfere as mensagens recentes restantes
  while FMessages.Count > 0 do
    LNewMessages.AddElement(FMessages.RemoveFirst);

  // Substitui o array de mensagens
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
        // Se ultrapassou o limite, condensa as antigas
        if (FMaxHistoryMessages > 0) and (FMessages.Count > FMaxHistoryMessages)
        then
          SummarizeHistory;
      end;
  end;
end;

function TLLMProviderBase.Send(out RawJSON: string): string;
var
  LBodyStr: string;
begin
  // Executa a estratégia de redução de histórico antes do envio
  ProcessHistory;

  LBodyStr := BuildBodyJSON(FModel, FTemperature, FMaxTokens, FMessages);
  Result := ExecuteRequest(LBodyStr, RawJSON);

  if FAutoAddAssistantResponse and (Result <> EmptyStr) then
    AddAssistant(Result);
end;

function TLLMProviderBase.Send: string;
var
  LDummy: string;
begin
  Result := Send(LDummy);
end;

procedure TLLMProviderBase.SetApiKey(const Value: string);
begin
  FApiKey := Value;
end;

procedure TLLMProviderBase.SetAutoAddAssistantResponse(const Value: Boolean);
begin
  FAutoAddAssistantResponse := Value;
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

procedure TLLMProviderBase.SetModel(const Value: string);
begin
  FModel := Value;
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

end.
