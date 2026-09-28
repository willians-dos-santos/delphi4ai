unit Test.Groq.Provider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  TestFramework,
  LLM.Interfaces,
  LLM.HistoryStrategy,
  LLM.Tools,
  LLM.Base,
  Groq.Provider;

type
  /// <summary>
  /// Mock do provedor Groq para testes unitarios sem conexao de rede
  /// </summary>
  TMockGroqProvider = class(TGroqProvider)
  private
    FLastRequestBody: string;
    FMockResponseContent: string;
    FMockRawJSON: string;
    FMockStatusCode: Integer;
    FMockErrorMessage: string;
    FMockHeaders: TStringList;
    FMockResponsesQueue: TArray<string>;
    FCurrentResponseIndex: Integer;
  protected
    function ExecuteRequest(const ABodyJSON: string; out ARawJSON: string): string; override;
  public
    constructor Create(const AApiKey: string = 'gsk_test_key_12345';
      const AModel: string = 'llama-3.3-70b-versatile';
      const ABaseURL: string = 'https://api.groq.com/openai/v1/chat/completions');
    destructor Destroy; override;

    procedure SetMockResponse(const AContent: string);
    procedure SetMockRawJSON(const ARawJSON: string);
    procedure SetMockError(const AStatusCode: Integer; const AErrorMsg: string);
    procedure SetMockToolCall(const AToolId, AFuncName, AArgsJSON: string; const AContent: string = '');
    procedure SetMockResponsesQueue(const AResponses: TArray<string>);
    procedure SetMockHeader(const AHeaderName, AHeaderValue: string);
    procedure ClearMockHeaders;

    function TestBuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string;
    function TestExtractErrorMessage(const AErrorJSON: string): string;

    property LastRequestBody: string read FLastRequestBody;
  end;

  /// <summary>
  /// Suite de testes unitarios para o provedor Groq
  /// </summary>
  TTestGroqProvider = class(TTestCase)
  private
    FProvider: TMockGroqProvider;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialDefaults;
    procedure TestUpdateRateLimit_IndividualHeaders;
    procedure TestUpdateRateLimit_CaseInsensitive;
    procedure TestUpdateRateLimit_InvalidNumber;
    procedure TestSend_CapturesRateLimitsViaHeaders;
    procedure TestBuildBodyJSON_Options;
    procedure TestBuildBodyJSON_WithTools;
    procedure TestBuildBodyJSON_StructuredOutputJSONObject;
    procedure TestBuildBodyJSON_StructuredOutputJSONSchema;
    procedure TestBuildBodyJSON_TwoPhaseToolsWithStructuredOutput;
    procedure TestExtractErrorMessage_GroqFormat;
    procedure TestSend_SimpleMessage;
    procedure TestSend_ToolCalls;
    procedure TestFactory_CreateGroqProvider;
    procedure TestFactory_Polymorphic;
    procedure TestApiKeyMissingException;
    procedure TestGetModelsURL;
  end;

implementation

uses
  System.Net.HttpClient,
  LLM.Exceptions,
  LLM.Factory;

{ TMockGroqProvider }

constructor TMockGroqProvider.Create(const AApiKey, AModel, ABaseURL: string);
begin
  inherited Create(AApiKey, AModel, ABaseURL);
  FMockStatusCode := 200;
  FMockResponseContent := 'Resposta simulada do Groq';
  FMockRawJSON := EmptyStr;
  FMockHeaders := TStringList.Create;
  SetLength(FMockResponsesQueue, 0);
  FCurrentResponseIndex := 0;
end;

destructor TMockGroqProvider.Destroy;
begin
  FMockHeaders.Free;
  inherited;
end;

procedure TMockGroqProvider.SetMockResponse(const AContent: string);
begin
  FMockStatusCode := 200;
  FMockResponseContent := AContent;
  FMockRawJSON := EmptyStr;
end;

procedure TMockGroqProvider.SetMockRawJSON(const ARawJSON: string);
begin
  FMockStatusCode := 200;
  FMockRawJSON := ARawJSON;
end;

procedure TMockGroqProvider.SetMockError(const AStatusCode: Integer;
  const AErrorMsg: string);
begin
  FMockStatusCode := AStatusCode;
  FMockErrorMessage := AErrorMsg;
end;

procedure TMockGroqProvider.SetMockResponsesQueue(const AResponses: TArray<string>);
begin
  FMockResponsesQueue := AResponses;
  FCurrentResponseIndex := 0;
end;

procedure TMockGroqProvider.SetMockHeader(const AHeaderName, AHeaderValue: string);
begin
  FMockHeaders.Values[AHeaderName] := AHeaderValue;
end;

procedure TMockGroqProvider.ClearMockHeaders;
begin
  FMockHeaders.Clear;
end;

procedure TMockGroqProvider.SetMockToolCall(const AToolId, AFuncName,
  AArgsJSON: string; const AContent: string);
var
  LRoot, LChoice, LMsg, LCall, LFunc: TJSONObject;
  LChoices, LToolCalls: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LChoices := TJSONArray.Create;
    LChoice := TJSONObject.Create;
    LMsg := TJSONObject.Create;

    LMsg.AddPair('role', 'assistant');
    if AContent.IsEmpty then
      LMsg.AddPair('content', TJSONNull.Create)
    else
      LMsg.AddPair('content', AContent);

    LToolCalls := TJSONArray.Create;
    LCall := TJSONObject.Create;
    LCall.AddPair('id', AToolId);
    LCall.AddPair('type', 'function');

    LFunc := TJSONObject.Create;
    LFunc.AddPair('name', AFuncName);
    LFunc.AddPair('arguments', AArgsJSON);

    LCall.AddPair('function', LFunc);
    LToolCalls.AddElement(LCall);
    LMsg.AddPair('tool_calls', LToolCalls);

    LChoice.AddPair('message', LMsg);
    LChoices.AddElement(LChoice);
    LRoot.AddPair('choices', LChoices);

    SetMockRawJSON(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TMockGroqProvider.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LRoot, LChoice, LMsg: TJSONObject;
  LChoices, LToolCallsArr: TJSONArray;
  LChoicesVal, LMsgVal, LToolsVal, LFuncVal, LContentVal, LVal: TJSONValue;
  I: Integer;
  LCallObj, LFuncObj: TJSONObject;
  LId, LName, LArgs: string;
  LCalls: TLLMToolCallList;
  LTempClient: THTTPClient;
begin
  // Executa a validacao oficial de headers do provedor (incluindo teste de ApiKey)
  LTempClient := THTTPClient.Create;
  try
    PrepareHeaders(LTempClient);
  finally
    LTempClient.Free;
  end;

  FLastRequestBody := ABodyJSON;
  Result := EmptyStr;
  ARawJSON := EmptyStr;
  SetLastToolCalls([]);

  // Aplica os cabecalhos mockados chamando o metodo real UpdateRateLimit do TGroqProvider
  for I := 0 to FMockHeaders.Count - 1 do
    UpdateRateLimit(FMockHeaders.Names[I], FMockHeaders.ValueFromIndex[I]);

  if FMockStatusCode <> 200 then
  begin
    ARawJSON := Format('{"error":{"message":"%s","type":"invalid_request_error"}}',
      [FMockErrorMessage]);
    raise ELLMAPIError.CreateFmt('Erro API Groq [%d]: %s',
      [FMockStatusCode, FMockErrorMessage]);
  end;

  // Se houver uma fila de respostas para multi-turn
  if (Length(FMockResponsesQueue) > 0) and (FCurrentResponseIndex < Length(FMockResponsesQueue)) then
  begin
    ARawJSON := FMockResponsesQueue[FCurrentResponseIndex];
    Inc(FCurrentResponseIndex);
  end
  // Senao, se houver um RawJSON mockado (ex: tool call), consome na iteracao
  else if not FMockRawJSON.Trim.IsEmpty then
  begin
    ARawJSON := FMockRawJSON;
    FMockRawJSON := EmptyStr; // Consome para a proxima chamada receber a resposta final
  end
  else
  begin
    LRoot := TJSONObject.Create;
    try
      LChoices := TJSONArray.Create;
      LChoice := TJSONObject.Create;
      LMsg := TJSONObject.Create;
      LMsg.AddPair('role', 'assistant');
      LMsg.AddPair('content', FMockResponseContent);
      LChoice.AddPair('message', LMsg);
      LChoices.AddElement(LChoice);
      LRoot.AddPair('choices', LChoices);
      ARawJSON := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
  end;

  LVal := TJSONObject.ParseJSONValue(ARawJSON);
  if not (LVal is TJSONObject) then
    raise Exception.Create('A resposta retornada pelo Groq nao e um JSON valido.');

  LRoot := TJSONObject(LVal);
  try
    LChoicesVal := LRoot.FindValue('choices');
    if (LChoicesVal is TJSONArray) and (TJSONArray(LChoicesVal).Count > 0) then
    begin
      LChoices := TJSONArray(LChoicesVal);
      if LChoices.Items[0] is TJSONObject then
      begin
        LChoice := TJSONObject(LChoices.Items[0]);
        LMsgVal := LChoice.FindValue('message');
        if LMsgVal is TJSONObject then
        begin
          LMsg := TJSONObject(LMsgVal);

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
          if (LContentVal <> nil) and not (LContentVal is TJSONNull) then
            Result := LContentVal.Value
          else
            Result := EmptyStr;
        end;
      end;
    end;
  finally
    LRoot.Free;
  end;
end;

function TMockGroqProvider.TestBuildBodyJSON(const AModel: string;
  ATemp: Double; AMaxTok: Integer; AMsgs: TJSONArray): string;
begin
  Result := BuildBodyJSON(AModel, ATemp, AMaxTok, AMsgs);
end;

function TMockGroqProvider.TestExtractErrorMessage(const AErrorJSON: string): string;
begin
  Result := ExtractErrorMessage(AErrorJSON);
end;

{ TTestGroqProvider }

procedure TTestGroqProvider.SetUp;
begin
  inherited;
  FProvider := TMockGroqProvider.Create('gsk_test_123', 'llama-3.3-70b-versatile');
end;

procedure TTestGroqProvider.TearDown;
begin
  FProvider.Free;
  inherited;
end;

procedure TTestGroqProvider.TestInitialDefaults;
begin
  CheckEquals('gsk_test_123', FProvider.ApiKey, 'ApiKey incorreta');
  CheckEquals('https://api.groq.com/openai/v1/chat/completions', FProvider.BaseURL, 'BaseURL incorreta');
  CheckEquals('llama-3.3-70b-versatile', FProvider.Model, 'Model incorreto');
  CheckEquals(0.7, FProvider.Temperature, 0.001, 'Temperature padrao deve ser 0.7');
  CheckEquals(0, FProvider.MaxTokens, 'MaxTokens padrao deve ser 0');
  CheckEquals(60000, FProvider.Timeout, 'Timeout padrao deve ser 60000 ms');
  CheckTrue(FProvider.AutoAddAssistantResponse, 'AutoAddAssistantResponse deve ser True');
  CheckTrue(FProvider.HistoryStrategy = hsSlidingWindow, 'HistoryStrategy padrao deve ser hsSlidingWindow');
  CheckEquals(0, FProvider.Messages.Count, 'Historico inicial deve estar vazio');
  CheckEquals(0, FProvider.RateLimitLimitRequests, 'RateLimitLimitRequests inicial deve ser 0');
  CheckEquals(0, FProvider.RateLimitRemainingTokens, 'RateLimitRemainingTokens inicial deve ser 0');
end;

procedure TTestGroqProvider.TestUpdateRateLimit_IndividualHeaders;
begin
  FProvider.UpdateRateLimit('x-ratelimit-limit-requests', '14400');
  CheckEquals(14400, FProvider.RateLimitLimitRequests, 'Falha ao atualizar limit-requests');

  FProvider.UpdateRateLimit('x-ratelimit-remaining-requests', '14390');
  CheckEquals(14390, FProvider.RateLimitRemainingRequests, 'Falha ao atualizar remaining-requests');

  FProvider.UpdateRateLimit('x-ratelimit-reset-requests', '2m15s');
  CheckEquals('2m15s', FProvider.RateLimitResetRequests, 'Falha ao atualizar reset-requests');

  FProvider.UpdateRateLimit('x-ratelimit-limit-tokens', '30000');
  CheckEquals(30000, FProvider.RateLimitLimitTokens, 'Falha ao atualizar limit-tokens');

  FProvider.UpdateRateLimit('x-ratelimit-remaining-tokens', '29850');
  CheckEquals(29850, FProvider.RateLimitRemainingTokens, 'Falha ao atualizar remaining-tokens');

  FProvider.UpdateRateLimit('x-ratelimit-reset-tokens', '450ms');
  CheckEquals('450ms', FProvider.RateLimitResetTokens, 'Falha ao atualizar reset-tokens');
end;

procedure TTestGroqProvider.TestUpdateRateLimit_CaseInsensitive;
begin
  // Testa headers com maiusculas e minusculas
  FProvider.UpdateRateLimit('X-RateLimit-Remaining-Tokens', '12345');
  CheckEquals(12345, FProvider.RateLimitRemainingTokens, 'UpdateRateLimit deve ser case-insensitive');

  FProvider.UpdateRateLimit('X-RATELIMIT-RESET-TOKENS', '80ms');
  CheckEquals('80ms', FProvider.RateLimitResetTokens, 'UpdateRateLimit deve ser case-insensitive para strings');
end;

procedure TTestGroqProvider.TestUpdateRateLimit_InvalidNumber;
begin
  FProvider.UpdateRateLimit('x-ratelimit-remaining-tokens', 'nao-numerico');
  CheckEquals(0, FProvider.RateLimitRemainingTokens, 'Valores nao-numericos devem resultar em 0 de forma segura');
end;

procedure TTestGroqProvider.TestSend_CapturesRateLimitsViaHeaders;
begin
  FProvider.SetMockHeader('x-ratelimit-limit-requests', '14400');
  FProvider.SetMockHeader('x-ratelimit-remaining-requests', '14350');
  FProvider.SetMockHeader('x-ratelimit-reset-requests', '12s');
  FProvider.SetMockHeader('x-ratelimit-limit-tokens', '40000');
  FProvider.SetMockHeader('x-ratelimit-remaining-tokens', '38500');
  FProvider.SetMockHeader('x-ratelimit-reset-tokens', '150ms');

  FProvider.SetMockResponse('OK');
  FProvider.AddUser('Teste rate limits');
  FProvider.Send;

  CheckEquals(14400, FProvider.RateLimitLimitRequests, 'LimitRequests incorreto apos Send');
  CheckEquals(14350, FProvider.RateLimitRemainingRequests, 'RemainingRequests incorreto apos Send');
  CheckEquals('12s', FProvider.RateLimitResetRequests, 'ResetRequests incorreto apos Send');
  CheckEquals(40000, FProvider.RateLimitLimitTokens, 'LimitTokens incorreto apos Send');
  CheckEquals(38500, FProvider.RateLimitRemainingTokens, 'RemainingTokens incorreto apos Send');
  CheckEquals('150ms', FProvider.RateLimitResetTokens, 'ResetTokens incorreto apos Send');
end;

procedure TTestGroqProvider.TestBuildBodyJSON_Options;
var
  LMsgs: TJSONArray;
  LMsg: TJSONObject;
  LJSONStr: string;
  LVal: TJSONValue;
  LRoot: TJSONObject;
begin
  LMsgs := TJSONArray.Create;
  try
    LMsg := TJSONObject.Create;
    LMsg.AddPair('role', 'user');
    LMsg.AddPair('content', 'Ola Groq!');
    LMsgs.AddElement(LMsg);

    LJSONStr := FProvider.TestBuildBodyJSON('llama-3.3-70b-versatile', 0.5, 1024, LMsgs);
    LVal := TJSONObject.ParseJSONValue(LJSONStr);
    CheckNotNull(LVal, 'JSON gerado deve ser valido');
    CheckTrue(LVal is TJSONObject, 'Raiz deve ser um JSONObject');

    LRoot := TJSONObject(LVal);
    try
      CheckEquals('llama-3.3-70b-versatile', LRoot.GetValue<string>('model'), 'Campo model incorreto');
      CheckEquals(0.5, LRoot.GetValue<Double>('temperature'), 0.001, 'Campo temperature incorreto');
      CheckEquals(1024, LRoot.GetValue<Integer>('max_tokens'), 'Campo max_tokens incorreto');
      CheckFalse(LRoot.GetValue<Boolean>('stream'), 'stream deve ser false');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGroqProvider.TestBuildBodyJSON_WithTools;
var
  LMsgs: TJSONArray;
  LJSONStr: string;
  LVal, LToolsVal: TJSONValue;
  LRoot: TJSONObject;
begin
  FProvider.RegisterFunction(
    'somar',
    'Soma dois numeros inteiros',
    '{"type":"object","properties":{"a":{"type":"integer"},"b":{"type":"integer"}},"required":["a","b"]}',
    function(const AArgs: string): string
    begin
      Result := '42';
    end
  );

  LMsgs := TJSONArray.Create;
  try
    LJSONStr := FProvider.TestBuildBodyJSON('llama-3.3-70b-versatile', -1, 0, LMsgs);
    LVal := TJSONObject.ParseJSONValue(LJSONStr);
    CheckNotNull(LVal);

    LRoot := TJSONObject(LVal);
    try
      LToolsVal := LRoot.FindValue('tools');
      CheckNotNull(LToolsVal, 'Campo tools deve estar presente no body do Groq');
      CheckTrue(LToolsVal is TJSONArray, 'Campo tools deve ser um array');
      CheckEquals(1, TJSONArray(LToolsVal).Count, 'Deve conter 1 ferramenta');
      CheckEquals('auto', LRoot.GetValue<string>('tool_choice'), 'tool_choice deve ser auto');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGroqProvider.TestBuildBodyJSON_StructuredOutputJSONObject;
var
  LMsgs: TJSONArray;
  LJSONStr: string;
  LVal, LFormatVal: TJSONValue;
  LRoot: TJSONObject;
begin
  FProvider.ResponseFormat.SetJSONObject;

  LMsgs := TJSONArray.Create;
  try
    LJSONStr := FProvider.TestBuildBodyJSON('llama-3.3-70b-versatile', -1, 0, LMsgs);
    LVal := TJSONObject.ParseJSONValue(LJSONStr);
    CheckNotNull(LVal);

    LRoot := TJSONObject(LVal);
    try
      LFormatVal := LRoot.FindValue('response_format');
      CheckNotNull(LFormatVal, 'Campo response_format deve existir');
      CheckTrue(LFormatVal is TJSONObject);
      CheckEquals('json_object', TJSONObject(LFormatVal).GetValue<string>('type'),
        'response_format.type deve ser json_object');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGroqProvider.TestBuildBodyJSON_StructuredOutputJSONSchema;
var
  LMsgs: TJSONArray;
  LJSONStr: string;
  LVal, LFormatVal, LSchemaVal: TJSONValue;
  LRoot, LFormatObj: TJSONObject;
begin
  FProvider.ResponseFormat.SetSchema('teste_schema', '{"type":"object","properties":{"nome":{"type":"string"}}}', True);

  LMsgs := TJSONArray.Create;
  try
    LJSONStr := FProvider.TestBuildBodyJSON('llama-3.3-70b-versatile', -1, 0, LMsgs);
    LVal := TJSONObject.ParseJSONValue(LJSONStr);
    CheckNotNull(LVal);

    LRoot := TJSONObject(LVal);
    try
      LFormatVal := LRoot.FindValue('response_format');
      CheckNotNull(LFormatVal, 'Campo response_format deve existir');
      LFormatObj := TJSONObject(LFormatVal);
      CheckEquals('json_schema', LFormatObj.GetValue<string>('type'),
        'response_format.type deve ser json_schema');

      LSchemaVal := LFormatObj.FindValue('json_schema');
      CheckNotNull(LSchemaVal, 'Objeto json_schema deve estar dentro de response_format');
      CheckEquals('teste_schema', TJSONObject(LSchemaVal).GetValue<string>('name'));
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGroqProvider.TestBuildBodyJSON_TwoPhaseToolsWithStructuredOutput;
var
  LMsgs: TJSONArray;
  LMsg, LToolMsg: TJSONObject;
  LJSONStr: string;
  LVal, LToolsVal, LFormatVal: TJSONValue;
  LRoot: TJSONObject;
begin
  // Registra ferramenta
  FProvider.RegisterFunction('get_current_weather', 'Retorna clima',
    '{"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}',
    function(const AArgs: string): string
    begin
      Result := '{"temperature": 22}';
    end
  );

  // Configura saida estruturada
  FProvider.ResponseFormat.SetSchema('WeatherDTO', '{"type":"object","properties":{"temp":{"type":"number"}}}', True);

  // FASE 1: Historico contem apenas a mensagem do usuario (sem mensagens de tool)
  LMsgs := TJSONArray.Create;
  try
    LMsg := TJSONObject.Create;
    LMsg.AddPair('role', 'user');
    LMsg.AddPair('content', 'Qual o clima atual?');
    LMsgs.AddElement(LMsg);

    LJSONStr := FProvider.TestBuildBodyJSON('llama-3.3-70b-versatile', -1, 0, LMsgs);
    LVal := TJSONObject.ParseJSONValue(LJSONStr);
    CheckNotNull(LVal, 'JSON da Fase 1 deve ser valido');
    LRoot := TJSONObject(LVal);
    try
      LToolsVal := LRoot.FindValue('tools');
      CheckNotNull(LToolsVal, 'Fase 1: Campo tools DEVE estar presente para invocar a ferramenta');
      LFormatVal := LRoot.FindValue('response_format');
      CheckNull(LFormatVal, 'Fase 1: response_format DEVE ser omitido para nao conflitar com tools (Groq 400)');
    finally
      LRoot.Free;
    end;

    // FASE 2: Historico agora contem o resultado da ferramenta (role = 'tool')
    LToolMsg := TJSONObject.Create;
    LToolMsg.AddPair('role', 'tool');
    LToolMsg.AddPair('tool_call_id', 'call_001');
    LToolMsg.AddPair('content', '{"temperature": 22}');
    LMsgs.AddElement(LToolMsg);

    LJSONStr := FProvider.TestBuildBodyJSON('llama-3.3-70b-versatile', -1, 0, LMsgs);
    LVal := TJSONObject.ParseJSONValue(LJSONStr);
    CheckNotNull(LVal, 'JSON da Fase 2 deve ser valido');
    LRoot := TJSONObject(LVal);
    try
      LToolsVal := LRoot.FindValue('tools');
      CheckNull(LToolsVal, 'Fase 2: Campo tools DEVE ser suprimido pois as ferramentas ja executaram');
      LFormatVal := LRoot.FindValue('response_format');
      CheckNotNull(LFormatVal, 'Fase 2: response_format DEVE estar presente para formatar a resposta final');
      CheckEquals('json_schema', TJSONObject(LFormatVal).GetValue<string>('type'));
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGroqProvider.TestExtractErrorMessage_GroqFormat;
var
  LErrJSON, LMsg: string;
begin
  LErrJSON := '{"error":{"message":"Invalid API Key provided","type":"invalid_request_error","code":"invalid_api_key"}}';
  LMsg := FProvider.TestExtractErrorMessage(LErrJSON);
  CheckEquals('Invalid API Key provided', LMsg, 'Deveria extrair a mensagem de erro do objeto "error"');
end;

procedure TTestGroqProvider.TestSend_SimpleMessage;
var
  LResp: string;
begin
  FProvider.SetMockResponse('Olá do Groq super rápido!');
  FProvider.AddUser('Olá');
  LResp := FProvider.Send;

  CheckEquals('Olá do Groq super rápido!', LResp, 'Resposta retornada incorreta');
  CheckEquals(2, FProvider.Messages.Count, 'Historico deve conter user e assistant');
  CheckEquals('assistant', TJSONObject(FProvider.Messages.Items[1]).GetValue<string>('role'));
  CheckEquals('Olá do Groq super rápido!', TJSONObject(FProvider.Messages.Items[1]).GetValue<string>('content'));
end;

procedure TTestGroqProvider.TestSend_ToolCalls;
var
  LToolExecutada: Boolean;
  LResp: string;
begin
  LToolExecutada := False;

  FProvider.RegisterFunction(
    'calcular_dobro',
    'Calcula o dobro de um numero',
    '{"type":"object","properties":{"n":{"type":"integer"}},"required":["n"]}',
    function(const AArgs: string): string
    begin
      LToolExecutada := True;
      Result := '{"resultado": 20}';
    end
  );

  // Define a resposta final para quando a ferramenta for concluida
  FProvider.SetMockResponse('O dobro de 10 e 20.');
  // Define o tool call inicial do modelo
  FProvider.SetMockToolCall('call_groq_001', 'calcular_dobro', '{"n": 10}');
  FProvider.AddUser('Quanto e o dobro de 10?');

  LResp := FProvider.Send;

  CheckTrue(LToolExecutada, 'A ferramenta registrada deveria ter sido invocada automaticamente');
  CheckEquals('O dobro de 10 e 20.', LResp, 'Resposta final deve ser a resposta do assistente apos a execucao da tool');
  CheckTrue(FProvider.Messages.Count >= 3, 'Historico deve conter user, assistant tool_call e tool result');
end;

procedure TTestGroqProvider.TestFactory_CreateGroqProvider;
var
  LProv: ILLMProvider;
  LGroq: IGroqProvider;
begin
  LProv := CreateLLMProvider(ptGroq, 'gsk_minha_chave', 'llama-3.1-8b-instant');
  CheckNotNull(LProv, 'Provedor nao deve ser nil');
  CheckEquals('gsk_minha_chave', LProv.ApiKey, 'ApiKey incorreta');
  CheckEquals('llama-3.1-8b-instant', LProv.Model, 'Model incorreto');
  CheckEquals('https://api.groq.com/openai/v1/chat/completions', LProv.BaseURL, 'BaseURL incorreta');
  CheckTrue(Supports(LProv, IGroqProvider, LGroq), 'Deve implementar IGroqProvider');
end;

procedure TTestGroqProvider.TestFactory_Polymorphic;
var
  LProv: ILLMProvider;
begin
  LProv := CreateLLMProvider(TLLMProviderType.FromStr('Groq'), 'gsk_polymorphic');
  CheckNotNull(LProv);
  CheckEquals('llama-3.3-70b-versatile', LProv.Model, 'Deve usar modelo padrao do Groq');
  CheckEquals('https://api.groq.com/openai/v1/chat/completions', LProv.BaseURL);
end;

procedure TTestGroqProvider.TestApiKeyMissingException;
var
  LEmptyKeyProvider: TMockGroqProvider;
  LDisparou: Boolean;
begin
  LEmptyKeyProvider := TMockGroqProvider.Create('');
  try
    LDisparou := False;
    try
      LEmptyKeyProvider.AddUser('Ola');
      LEmptyKeyProvider.Send;
    except
      on E: Exception do
      begin
        LDisparou := True;
        CheckTrue(E.Message.Contains('Groq API Key'), 'Mensagem de erro deve mencionar Groq API Key');
      end;
    end;
    CheckTrue(LDisparou, 'Deveria lancar excecao quando ApiKey nao informada');
  finally
    LEmptyKeyProvider.Free;
  end;
end;

procedure TTestGroqProvider.TestGetModelsURL;
begin
  CheckEquals('https://api.groq.com/openai/v1/models', FProvider.GetModelsURL,
    'GetModelsURL deve substituir /chat/completions por /models');
end;

initialization
  RegisterTest(TTestGroqProvider.Suite);

end.
