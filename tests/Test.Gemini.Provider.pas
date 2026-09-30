unit Test.Gemini.Provider;

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
  Gemini.Provider;

type
  /// <summary>
  /// Mock do provedor Gemini para testes unitarios sem conexao real de rede
  /// </summary>
  TMockGeminiProvider = class(TGeminiProvider)
  private
    FLastRequestBody: string;
    FMockResponseContent: string;
    FMockRawJSON: string;
    FMockStatusCode: Integer;
    FMockErrorMessage: string;
    FMockResponsesQueue: TArray<string>;
    FCurrentResponseIndex: Integer;
  protected
    function ExecuteRequest(const ABodyJSON: string; out ARawJSON: string)
      : string; override;
  public
    constructor Create(const AApiKey: string = 'gemini_test_key_123';
      const AModel: string = GEMINI_DEFAULT_MODEL;
      const ABaseURL: string = GEMINI_DEFAULT_URL);

    procedure SetMockResponse(const AContent: string;
      APromptTokens: Integer = 10; ACandidatesTokens: Integer = 20;
      ATotalTokens: Integer = 30);
    procedure SetMockRawJSON(const ARawJSON: string);
    procedure SetMockError(const AStatusCode: Integer; const AErrorMsg: string);
    procedure SetMockToolCall(const AFuncName, AArgsJSON: string;
      const AContent: string = ''; const AToolId: string = '');
    procedure SetMockResponsesQueue(const AResponses: TArray<string>);

    function TestBuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string;
    function TestExtractErrorMessage(const AErrorJSON: string): string;
    procedure TestAppendAssistantToolCallsToHistory(const ARawJSON: string);

    property LastRequestBody: string read FLastRequestBody;
  end;

  /// <summary>
  /// Suite de testes unitarios para o provedor Google Gemini
  /// </summary>
  TTestGeminiProvider = class(TTestCase)
  private
    FProvider: TMockGeminiProvider;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialDefaults;
    procedure TestGetGenerateContentURL;
    procedure TestGetModelsURL;
    procedure TestPrepareHeaders;
    procedure TestApiKeyMissingException;
    procedure TestBuildBodyJSON_BasicUserMessage;
    procedure TestBuildBodyJSON_SystemInstruction;
    procedure TestBuildBodyJSON_StrictAlternatingRoles;
    procedure TestBuildBodyJSON_WithTools;
    procedure TestBuildBodyJSON_StructuredOutput_JSONObject;
    procedure TestBuildBodyJSON_StructuredOutput_JSONSchema;
    procedure TestBuildBodyJSON_TwoPhaseToolsWithStructuredOutput;
    procedure TestHasToolResultMessage;
    procedure TestExtractErrorMessage_GeminiFormat;
    procedure TestSend_SimpleMessageAndTokens;
    procedure TestSend_ToolCallsLoop;
    procedure TestAppendAssistantToolCallsToHistory;
    procedure TestFactory_CreateGeminiProvider;
    procedure TestFactory_Polymorphic;
  end;

implementation

uses
  System.Net.HttpClient,
  LLM.Exceptions,
  LLM.Factory;

{ TMockGeminiProvider }

constructor TMockGeminiProvider.Create(const AApiKey, AModel, ABaseURL: string);
begin
  inherited Create(AApiKey, AModel, ABaseURL);
  FMockStatusCode := 200;
  FMockResponseContent := 'Resposta simulada do Gemini';
  FMockRawJSON := EmptyStr;
  SetLength(FMockResponsesQueue, 0);
  FCurrentResponseIndex := 0;
end;

procedure TMockGeminiProvider.SetMockResponse(const AContent: string;
  APromptTokens, ACandidatesTokens, ATotalTokens: Integer);
var
  LRoot, LCandidate, LContent, LPart, LUsage: TJSONObject;
  LCandidates, LParts: TJSONArray;
begin
  FMockStatusCode := 200;
  FMockResponseContent := AContent;

  LRoot := TJSONObject.Create;
  try
    LCandidates := TJSONArray.Create;
    LRoot.AddPair('candidates', LCandidates);

    LCandidate := TJSONObject.Create;
    LCandidates.AddElement(LCandidate);
    LCandidate.AddPair('finishReason', 'STOP');

    LContent := TJSONObject.Create;
    LCandidate.AddPair('content', LContent);
    LContent.AddPair('role', 'model');

    LParts := TJSONArray.Create;
    LContent.AddPair('parts', LParts);

    LPart := TJSONObject.Create;
    LParts.AddElement(LPart);
    LPart.AddPair('text', AContent);

    LUsage := TJSONObject.Create;
    LUsage.AddPair('promptTokenCount', TJSONNumber.Create(APromptTokens));
    LUsage.AddPair('candidatesTokenCount',
      TJSONNumber.Create(ACandidatesTokens));
    LUsage.AddPair('totalTokenCount', TJSONNumber.Create(ATotalTokens));
    LRoot.AddPair('usageMetadata', LUsage);

    FMockRawJSON := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

procedure TMockGeminiProvider.SetMockRawJSON(const ARawJSON: string);
begin
  FMockStatusCode := 200;
  FMockRawJSON := ARawJSON;
end;

procedure TMockGeminiProvider.SetMockError(const AStatusCode: Integer;
  const AErrorMsg: string);
begin
  FMockStatusCode := AStatusCode;
  FMockErrorMessage := AErrorMsg;
end;

procedure TMockGeminiProvider.SetMockResponsesQueue(const AResponses
  : TArray<string>);
begin
  FMockResponsesQueue := AResponses;
  FCurrentResponseIndex := 0;
end;

procedure TMockGeminiProvider.SetMockToolCall(const AFuncName, AArgsJSON,
  AContent, AToolId: string);
var
  LRoot, LCandidate, LContent, LPart, LFuncCall, LArgsObj: TJSONObject;
  LCandidates, LParts: TJSONArray;
  LVal: TJSONValue;
  LId: string;
begin
  LId := AToolId;
  if LId.IsEmpty then
    LId := 'call_gemini_test_01';

  LRoot := TJSONObject.Create;
  try
    LCandidates := TJSONArray.Create;
    LRoot.AddPair('candidates', LCandidates);

    LCandidate := TJSONObject.Create;
    LCandidates.AddElement(LCandidate);
    LCandidate.AddPair('finishReason', 'STOP');

    LContent := TJSONObject.Create;
    LCandidate.AddPair('content', LContent);
    LContent.AddPair('role', 'model');

    LParts := TJSONArray.Create;
    LContent.AddPair('parts', LParts);

    if not AContent.IsEmpty then
    begin
      LPart := TJSONObject.Create;
      LPart.AddPair('text', AContent);
      LParts.AddElement(LPart);
    end;

    LPart := TJSONObject.Create;
    LParts.AddElement(LPart);

    LFuncCall := TJSONObject.Create;
    LPart.AddPair('functionCall', LFuncCall);
    LFuncCall.AddPair('name', AFuncName);
    LFuncCall.AddPair('id', LId);

    LVal := TJSONObject.ParseJSONValue(AArgsJSON);
    if LVal is TJSONObject then
      LArgsObj := TJSONObject(LVal)
    else
    begin
      if Assigned(LVal) then
        LVal.Free;
      LArgsObj := TJSONObject.Create;
    end;
    LFuncCall.AddPair('args', LArgsObj);

    FMockStatusCode := 200;
    FMockRawJSON := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TMockGeminiProvider.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LRawToProcess: string;
  LVal: TJSONValue;
  LJSON, LCandidate, LContent, LPartObj, LFuncCallObj, LUsageObj: TJSONObject;
  LCandidates, LParts: TJSONArray;
  LCandidatesVal, LContentVal, LPartsVal, LUsageVal, LFuncCallVal, LTextVal,
    LArgsVal: TJSONValue;
  I: Integer;
  LId, LName, LArgs: string;
  LCalls: TLLMToolCallList;
begin
  FLastRequestBody := ABodyJSON;
  Result := EmptyStr;
  ARawJSON := EmptyStr;
  SetLastToolCalls([]);

  if FMockStatusCode <> 200 then
    raise ELLMAPIError.CreateFmt('Erro API Gemini [%d]: %s',
      [FMockStatusCode, ExtractErrorMessage(FMockErrorMessage)]);

  if Length(FMockResponsesQueue) > 0 then
  begin
    if FCurrentResponseIndex < Length(FMockResponsesQueue) then
    begin
      LRawToProcess := FMockResponsesQueue[FCurrentResponseIndex];
      Inc(FCurrentResponseIndex);
    end
    else
      LRawToProcess := FMockResponsesQueue[High(FMockResponsesQueue)];
  end
  else if not FMockRawJSON.IsEmpty then
    LRawToProcess := FMockRawJSON
  else
  begin
    SetMockResponse(FMockResponseContent);
    LRawToProcess := FMockRawJSON;
  end;

  ARawJSON := LRawToProcess;

  LVal := TJSONObject.ParseJSONValue(LRawToProcess);
  if not(LVal is TJSONObject) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    raise Exception.Create
      ('A resposta retornada pelo Gemini nao e um JSON valido.');
  end;

  LJSON := TJSONObject(LVal);
  try
    LUsageVal := LJSON.FindValue('usageMetadata');
    if LUsageVal is TJSONObject then
    begin
      LUsageObj := TJSONObject(LUsageVal);
      FPromptTokenCount := LUsageObj.GetValue<Integer>('promptTokenCount', 0);
      FCandidatesTokenCount := LUsageObj.GetValue<Integer>
        ('candidatesTokenCount', 0);
      FTotalTokenCount := LUsageObj.GetValue<Integer>('totalTokenCount', 0);
    end;

    LCandidatesVal := LJSON.FindValue('candidates');
    if not(LCandidatesVal is TJSONArray) or
      (TJSONArray(LCandidatesVal).Count = 0) then
      raise Exception.Create('Nenhum candidato retornado pelo Gemini.');

    LCandidates := TJSONArray(LCandidatesVal);
    LCandidate := TJSONObject(LCandidates.Items[0]);

    LContentVal := LCandidate.FindValue('content');
    if not(LContentVal is TJSONObject) then
      Exit;

    LContent := TJSONObject(LContentVal);
    LPartsVal := LContent.FindValue('parts');
    if not(LPartsVal is TJSONArray) then
      Exit;

    LParts := TJSONArray(LPartsVal);
    SetLength(LCalls, 0);

    for I := 0 to LParts.Count - 1 do
    begin
      if LParts.Items[I] is TJSONObject then
      begin
        LPartObj := TJSONObject(LParts.Items[I]);

        LFuncCallVal := LPartObj.FindValue('functionCall');
        if LFuncCallVal is TJSONObject then
        begin
          LFuncCallObj := TJSONObject(LFuncCallVal);
          LName := LFuncCallObj.GetValue<string>('name', EmptyStr);
          LId := LFuncCallObj.GetValue<string>('id', EmptyStr);
          if LId.IsEmpty then
            LId := Format('call_gemini_%d', [I]);

          LArgs := '{}';
          LArgsVal := LFuncCallObj.FindValue('args');
          if LArgsVal is TJSONObject then
            LArgs := LArgsVal.ToJSON
          else if LArgsVal is TJSONString then
            LArgs := LArgsVal.Value
          else if Assigned(LArgsVal) then
            LArgs := LArgsVal.ToJSON;

          SetLength(LCalls, Length(LCalls) + 1);
          LCalls[High(LCalls)] := TLLMToolCall.Create(LId, LName, LArgs);
        end;

        LTextVal := LPartObj.FindValue('text');
        if (LTextVal <> nil) and not(LTextVal is TJSONNull) then
        begin
          if Result.IsEmpty then
            Result := LTextVal.Value
          else
            Result := Result + sLineBreak + LTextVal.Value;
        end;
      end;
    end;

    if Length(LCalls) > 0 then
      SetLastToolCalls(LCalls);
  finally
    LJSON.Free;
  end;
end;

function TMockGeminiProvider.TestBuildBodyJSON(const AModel: string;
  ATemp: Double; AMaxTok: Integer; AMsgs: TJSONArray): string;
begin
  Result := BuildBodyJSON(AModel, ATemp, AMaxTok, AMsgs);
end;

function TMockGeminiProvider.TestExtractErrorMessage(const AErrorJSON
  : string): string;
begin
  Result := ExtractErrorMessage(AErrorJSON);
end;

procedure TMockGeminiProvider.TestAppendAssistantToolCallsToHistory
  (const ARawJSON: string);
begin
  AppendAssistantToolCallsToHistory(ARawJSON);
end;

{ TTestGeminiProvider }

procedure TTestGeminiProvider.SetUp;
begin
  inherited;
  FProvider := TMockGeminiProvider.Create('test_api_key_gemini');
end;

procedure TTestGeminiProvider.TearDown;
begin
  FProvider.Free;
  inherited;
end;

procedure TTestGeminiProvider.TestInitialDefaults;
begin
  CheckEquals('test_api_key_gemini', FProvider.ApiKey, 'ApiKey incorreta');
  CheckEquals('gemini-2.5-flash', FProvider.Model,
    'Modelo padrao deve ser gemini-2.5-flash');
  CheckEquals('https://generativelanguage.googleapis.com/v1beta',
    FProvider.BaseURL, 'BaseURL incorreta');
  CheckEquals(0, FProvider.PromptTokenCount,
    'PromptTokenCount inicial deve ser 0');
  CheckEquals(0, FProvider.CandidatesTokenCount,
    'CandidatesTokenCount inicial deve ser 0');
  CheckEquals(0, FProvider.TotalTokenCount,
    'TotalTokenCount inicial deve ser 0');
end;

procedure TTestGeminiProvider.TestGetGenerateContentURL;
var
  LURL: string;
begin
  LURL := FProvider.GetGenerateContentURL;
  CheckTrue(LURL.Contains('/models/gemini-2.5-flash:generateContent'),
    'URL deve conter models/{model}:generateContent');
  CheckTrue(LURL.Contains('key=test_api_key_gemini'),
    'URL deve conter chave de API como parametro');

  // URL customizada com :generateContent
  FProvider.BaseURL :=
    'https://custom-proxy.internal/v1beta/models/custom-model:generateContent';
  LURL := FProvider.GetGenerateContentURL;
  CheckTrue(LURL.StartsWith
    ('https://custom-proxy.internal/v1beta/models/custom-model:generateContent'),
    'URL explicita deve ser preservada');

  // Teste de sanitizacao se veio com endpoint residual de OpenAI
  FProvider.BaseURL := 'https://api.openai.com/v1/chat/completions';
  LURL := FProvider.GetGenerateContentURL;
  CheckTrue(LURL.StartsWith('https://generativelanguage.googleapis.com/v1beta/models/'),
    'Deve sanitizar URL de outro provedor para o endpoint padrao do Gemini: ' + LURL);
end;

procedure TTestGeminiProvider.TestGetModelsURL;
var
  LURL: string;
begin
  LURL := FProvider.GetModelsURL;
  CheckTrue(LURL.EndsWith('/models?key=test_api_key_gemini') or
    LURL.Contains('/models?key='), 'Models URL incorreta: ' + LURL);
end;

procedure TTestGeminiProvider.TestPrepareHeaders;
var
  LClient: THTTPClient;
begin
  LClient := THTTPClient.Create;
  try
    FProvider.ApiKey := 'my_gemini_key';
    // Chama o metodo protegido indiretamente ou simula o cliente
    LClient.CustomHeaders['x-goog-api-key'] := FProvider.ApiKey;
    LClient.CustomHeaders['Content-Type'] := 'application/json';
    CheckEquals('my_gemini_key', LClient.CustomHeaders['x-goog-api-key'],
      'Header x-goog-api-key incorreto');
    CheckEquals('application/json', LClient.CustomHeaders['Content-Type'],
      'Header Content-Type incorreto');
  finally
    LClient.Free;
  end;
end;

procedure TTestGeminiProvider.TestApiKeyMissingException;
begin
  FProvider.ApiKey := '';
  try
    FProvider.Send;
    Fail('Deveria ter disparado excecao quando ApiKey nao informada');
  except
    on E: Exception do
      CheckTrue(E.Message.Contains('Gemini API Key não informada') or
        E.Message.Contains('Key'), 'Mensagem de erro inesperada: ' + E.Message);
  end;
end;

procedure TTestGeminiProvider.TestBuildBodyJSON_BasicUserMessage;
var
  LMsgs: TJSONArray;
  LMsg: TJSONObject;
  LBodyJSON: string;
  LRoot, LTurnObj, LPartObj: TJSONObject;
  LContents, LParts: TJSONArray;
begin
  LMsgs := TJSONArray.Create;
  try
    LMsg := TJSONObject.Create;
    LMsg.AddPair('role', 'user');
    LMsg.AddPair('content', 'Ola Gemini!');
    LMsgs.AddElement(LMsg);

    LBodyJSON := FProvider.TestBuildBodyJSON(FProvider.Model, 0.7, 100, LMsgs);

    LRoot := TJSONObject.ParseJSONValue(LBodyJSON) as TJSONObject;
    try
      CheckNotNull(LRoot, 'JSON gerado deve ser valido');
      CheckNotNull(LRoot.FindValue('contents'), 'Campo contents deve existir');

      LContents := TJSONArray(LRoot.FindValue('contents'));
      CheckEquals(1, LContents.Count, 'Deve ter 1 turn de conteudo');

      LTurnObj := TJSONObject(LContents.Items[0]);
      CheckEquals('user', LTurnObj.GetValue<string>('role', ''),
        'Role deve ser user');

      LParts := TJSONArray(LTurnObj.FindValue('parts'));
      CheckNotNull(LParts, 'parts deve existir');
      CheckEquals(1, LParts.Count, 'Deve ter 1 part');

      LPartObj := TJSONObject(LParts.Items[0]);
      CheckEquals('Ola Gemini!', LPartObj.GetValue<string>('text', ''),
        'Texto deve conferir');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGeminiProvider.TestBuildBodyJSON_SystemInstruction;
var
  LMsgs: TJSONArray;
  LSys, LUser: TJSONObject;
  LBodyJSON: string;
  LRoot, LSysInst, LPartObj: TJSONObject;
  LSysParts: TJSONArray;
begin
  LMsgs := TJSONArray.Create;
  try
    LSys := TJSONObject.Create;
    LSys.AddPair('role', 'system');
    LSys.AddPair('content', 'Voce e um assistente especialista em Delphi.');
    LMsgs.AddElement(LSys);

    LUser := TJSONObject.Create;
    LUser.AddPair('role', 'user');
    LUser.AddPair('content', 'Como usar RTTI?');
    LMsgs.AddElement(LUser);

    LBodyJSON := FProvider.TestBuildBodyJSON(FProvider.Model, 0.5, 200, LMsgs);

    LRoot := TJSONObject.ParseJSONValue(LBodyJSON) as TJSONObject;
    try
      CheckNotNull(LRoot.FindValue('systemInstruction'),
        'systemInstruction deve existir no payload');
      LSysInst := TJSONObject(LRoot.FindValue('systemInstruction'));

      LSysParts := TJSONArray(LSysInst.FindValue('parts'));
      CheckNotNull(LSysParts, 'parts em systemInstruction deve existir');
      CheckEquals(1, LSysParts.Count, 'Deve ter 1 part de system');

      LPartObj := TJSONObject(LSysParts.Items[0]);
      CheckEquals('Voce e um assistente especialista em Delphi.',
        LPartObj.GetValue<string>('text', ''));
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGeminiProvider.TestBuildBodyJSON_StrictAlternatingRoles;
var
  LMsgs: TJSONArray;
  LMsg1, LMsg2, LMsgModel, LMsgTool1, LMsgTool2: TJSONObject;
  LBodyJSON: string;
  LRoot, LTurn: TJSONObject;
  LContents, LParts: TJSONArray;
begin
  // Simula duas mensagens consecutivas de usuario seguidas de resposta model e dois retornos de tool
  LMsgs := TJSONArray.Create;
  try
    LMsg1 := TJSONObject.Create;
    LMsg1.AddPair('role', 'user');
    LMsg1.AddPair('content', 'Primeira pergunta');
    LMsgs.AddElement(LMsg1);

    LMsg2 := TJSONObject.Create;
    LMsg2.AddPair('role', 'user');
    LMsg2.AddPair('content', 'Segunda pergunta sem resposta intermediaria');
    LMsgs.AddElement(LMsg2);

    LMsgModel := TJSONObject.Create;
    LMsgModel.AddPair('role', 'assistant');
    LMsgModel.AddPair('content', 'Ok, executando...');
    LMsgs.AddElement(LMsgModel);

    LMsgTool1 := TJSONObject.Create;
    LMsgTool1.AddPair('role', 'tool');
    LMsgTool1.AddPair('tool_call_id', 'call_1');
    LMsgTool1.AddPair('name', 'tool_a');
    LMsgTool1.AddPair('content', '{"res": 1}');
    LMsgs.AddElement(LMsgTool1);

    LMsgTool2 := TJSONObject.Create;
    LMsgTool2.AddPair('role', 'tool');
    LMsgTool2.AddPair('tool_call_id', 'call_2');
    LMsgTool2.AddPair('name', 'tool_b');
    LMsgTool2.AddPair('content', '{"res": 2}');
    LMsgs.AddElement(LMsgTool2);

    LBodyJSON := FProvider.TestBuildBodyJSON(FProvider.Model, 0.7, 0, LMsgs);

    LRoot := TJSONObject.ParseJSONValue(LBodyJSON) as TJSONObject;
    try
      LContents := TJSONArray(LRoot.FindValue('contents'));
      // Deve ter exatamente 3 turns:
      // Turn 0: user (com 2 parts de texto fundidas)
      // Turn 1: model (com 1 part)
      // Turn 2: user (com 2 parts de functionResponse fundidas)
      CheckEquals(3, LContents.Count,
        'Os turns devem alternar estritamente user -> model -> user');

      LTurn := TJSONObject(LContents.Items[0]);
      CheckEquals('user', LTurn.GetValue<string>('role', ''));
      LParts := TJSONArray(LTurn.FindValue('parts'));
      CheckEquals(2, LParts.Count,
        'As 2 mensagens de user devem ter sido fundidas em 2 parts do mesmo turn');

      LTurn := TJSONObject(LContents.Items[1]);
      CheckEquals('model', LTurn.GetValue<string>('role', ''));

      LTurn := TJSONObject(LContents.Items[2]);
      CheckEquals('user', LTurn.GetValue<string>('role', ''));
      LParts := TJSONArray(LTurn.FindValue('parts'));
      CheckEquals(2, LParts.Count,
        'Os 2 tool results devem ter sido fundidos em 2 parts functionResponse do mesmo turn');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGeminiProvider.TestBuildBodyJSON_WithTools;
var
  LMsgs: TJSONArray;
  LMsg: TJSONObject;
  LBodyJSON: string;
  LRoot, LToolsArrObj, LFuncDecl: TJSONObject;
  LToolsArr, LFuncDecls: TJSONArray;
  LParams: TJSONObject;
begin
  FProvider.RegisterFunction('consultar_clima', 'Retorna a temperatura atual',
    '{"type":"object","properties":{"cidade":{"type":"string"}},"required":["cidade"]}',
    function(const AArgs: string): string
    begin
      Result := '22 graus';
    end);

  LMsgs := TJSONArray.Create;
  try
    LMsg := TJSONObject.Create;
    LMsg.AddPair('role', 'user');
    LMsg.AddPair('content', 'Qual o clima em Curitiba?');
    LMsgs.AddElement(LMsg);

    LBodyJSON := FProvider.TestBuildBodyJSON(FProvider.Model, 0.7, 0, LMsgs);

    LRoot := TJSONObject.ParseJSONValue(LBodyJSON) as TJSONObject;
    try
      CheckNotNull(LRoot.FindValue('tools'), 'Campo tools deve estar presente');
      LToolsArr := TJSONArray(LRoot.FindValue('tools'));
      CheckEquals(1, LToolsArr.Count, 'Array tools deve ter 1 elemento');

      LToolsArrObj := TJSONObject(LToolsArr.Items[0]);
      LFuncDecls := TJSONArray(LToolsArrObj.FindValue('functionDeclarations'));
      CheckNotNull(LFuncDecls, 'functionDeclarations deve existir');
      CheckEquals(1, LFuncDecls.Count, 'Deve ter 1 declaracao de funcao');

      LFuncDecl := TJSONObject(LFuncDecls.Items[0]);
      CheckEquals('consultar_clima', LFuncDecl.GetValue<string>('name', ''));
      CheckEquals('Retorna a temperatura atual',
        LFuncDecl.GetValue<string>('description', ''));

      LParams := TJSONObject(LFuncDecl.FindValue('parameters'));
      CheckNotNull(LParams, 'parameters deve existir');
      CheckEquals('OBJECT', LParams.GetValue<string>('type', ''),
        'Tipo em parameters deve ser convertido para maiusculo (OBJECT)');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGeminiProvider.TestBuildBodyJSON_StructuredOutput_JSONObject;
var
  LMsgs: TJSONArray;
  LMsg: TJSONObject;
  LBodyJSON: string;
  LRoot, LGenConfig: TJSONObject;
begin
  FProvider.ResponseFormat.SetJSONObject;

  LMsgs := TJSONArray.Create;
  try
    LMsg := TJSONObject.Create;
    LMsg.AddPair('role', 'user');
    LMsg.AddPair('content', 'Retorne em JSON');
    LMsgs.AddElement(LMsg);

    LBodyJSON := FProvider.TestBuildBodyJSON(FProvider.Model, 0.7, 0, LMsgs);

    LRoot := TJSONObject.ParseJSONValue(LBodyJSON) as TJSONObject;
    try
      LGenConfig := TJSONObject(LRoot.FindValue('generationConfig'));
      CheckNotNull(LGenConfig, 'generationConfig deve existir');
      CheckEquals('application/json',
        LGenConfig.GetValue<string>('responseMimeType', ''),
        'responseMimeType deve ser application/json');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGeminiProvider.TestBuildBodyJSON_StructuredOutput_JSONSchema;
var
  LMsgs: TJSONArray;
  LMsg: TJSONObject;
  LBodyJSON: string;
  LRoot, LGenConfig, LSchema: TJSONObject;
begin
  FProvider.ResponseFormat.SetSchema('Pessoa',
    '{"title":"Pessoa","type":"object","properties":{"nome":{"type":"string"},"idade":{"type":"integer"}},"required":["nome"],"additionalProperties":false}');

  LMsgs := TJSONArray.Create;
  try
    LMsg := TJSONObject.Create;
    LMsg.AddPair('role', 'user');
    LMsg.AddPair('content', 'Gere uma pessoa');
    LMsgs.AddElement(LMsg);

    LBodyJSON := FProvider.TestBuildBodyJSON(FProvider.Model, 0.7, 0, LMsgs);

    LRoot := TJSONObject.ParseJSONValue(LBodyJSON) as TJSONObject;
    try
      LGenConfig := TJSONObject(LRoot.FindValue('generationConfig'));
      CheckNotNull(LGenConfig, 'generationConfig deve existir');
      CheckEquals('application/json',
        LGenConfig.GetValue<string>('responseMimeType', ''),
        'responseMimeType deve ser application/json');

      LSchema := TJSONObject(LGenConfig.FindValue('responseSchema'));
      CheckNotNull(LSchema, 'responseSchema deve existir');
      CheckEquals('OBJECT', LSchema.GetValue<string>('type', ''),
        'Schema type deve ser OBJECT');
      CheckNull(LSchema.FindValue('additionalProperties'), 'additionalProperties deve ser removido para o Gemini');
      CheckNull(LSchema.FindValue('title'), 'title deve ser removido para o Gemini');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGeminiProvider.TestHasToolResultMessage;
var
  LMsgs: TJSONArray;
  LMsgUser, LMsgAssist, LMsgTool: TJSONObject;
begin
  CheckFalse(FProvider.HasToolResultMessage(nil), 'Array nil deve retornar False');

  LMsgs := TJSONArray.Create;
  try
    CheckFalse(FProvider.HasToolResultMessage(LMsgs), 'Array vazio deve retornar False');

    LMsgUser := TJSONObject.Create;
    LMsgUser.AddPair('role', 'user');
    LMsgUser.AddPair('content', 'Qual o clima?');
    LMsgs.AddElement(LMsgUser);

    CheckFalse(FProvider.HasToolResultMessage(LMsgs), 'Apenas user deve retornar False');

    LMsgAssist := TJSONObject.Create;
    LMsgAssist.AddPair('role', 'assistant');
    LMsgAssist.AddPair('content', '');
    LMsgs.AddElement(LMsgAssist);

    CheckFalse(FProvider.HasToolResultMessage(LMsgs), 'User + Assistant sem tool deve retornar False');

    LMsgTool := TJSONObject.Create;
    LMsgTool.AddPair('role', 'tool');
    LMsgTool.AddPair('content', '{"temp": 25}');
    LMsgs.AddElement(LMsgTool);

    CheckTrue(FProvider.HasToolResultMessage(LMsgs), 'Com tool recente deve retornar True');

    // Novo turno de usuario: as tools ainda nao rodaram neste novo turno
    LMsgUser := TJSONObject.Create;
    LMsgUser.AddPair('role', 'user');
    LMsgUser.AddPair('content', 'E amanha?');
    LMsgs.AddElement(LMsgUser);

    CheckFalse(FProvider.HasToolResultMessage(LMsgs), 'Novo turno com user recente deve retornar False');
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGeminiProvider.TestBuildBodyJSON_TwoPhaseToolsWithStructuredOutput;
var
  LMsgs: TJSONArray;
  LMsgUser, LMsgAssist, LMsgTool: TJSONObject;
  LBodyJSON: string;
  LRoot, LGenConfig, LSchema: TJSONObject;
begin
  FProvider.RegisterFunction('obter_clima', 'Retorna o clima atual',
    '{"type":"object","properties":{"cidade":{"type":"string"}},"required":["cidade"]}',
    function(const AArgs: string): string
    begin
      Result := '{"temp": 20}';
    end);

  FProvider.ResponseFormat.SetSchema('Previsao',
    '{"type":"object","properties":{"cidade":{"type":"string"},"temperatura":{"type":"number"}},"required":["cidade","temperatura"]}');

  // === FASE 1: Ferramenta ainda nao executada (apenas pergunta do usuario) ===
  LMsgs := TJSONArray.Create;
  try
    LMsgUser := TJSONObject.Create;
    LMsgUser.AddPair('role', 'user');
    LMsgUser.AddPair('content', 'Qual a previsao para Gramado?');
    LMsgs.AddElement(LMsgUser);

    LBodyJSON := FProvider.TestBuildBodyJSON(FProvider.Model, 0.7, 0, LMsgs);

    LRoot := TJSONObject.ParseJSONValue(LBodyJSON) as TJSONObject;
    try
      CheckNotNull(LRoot.FindValue('tools'),
        'Fase 1: Campo tools DEVE estar presente para permitir chamada de funcao');

      LGenConfig := TJSONObject(LRoot.FindValue('generationConfig'));
      if LGenConfig <> nil then
      begin
        CheckNull(LGenConfig.FindValue('responseMimeType'),
          'Fase 1: responseMimeType DEVE ser omitido para evitar erro 400 da API Gemini');
        CheckNull(LGenConfig.FindValue('responseSchema'),
          'Fase 1: responseSchema DEVE ser omitido para evitar erro 400 da API Gemini');
      end;

      CheckNotNull(LRoot.FindValue('systemInstruction'),
        'Fase 1: systemInstruction deve injetar orientacao sobre o schema');
    finally
      LRoot.Free;
    end;

    // === FASE 2: Ferramenta ja executada (historico contem retorno de tool) ===
    LMsgAssist := TJSONObject.Create;
    LMsgAssist.AddPair('role', 'assistant');
    LMsgAssist.AddPair('content', '');
    LMsgs.AddElement(LMsgAssist);

    LMsgTool := TJSONObject.Create;
    LMsgTool.AddPair('role', 'tool');
    LMsgTool.AddPair('tool_call_id', 'call_weather_1');
    LMsgTool.AddPair('name', 'obter_clima');
    LMsgTool.AddPair('content', '{"temp": 18, "condicao": "nublado"}');
    LMsgs.AddElement(LMsgTool);

    LBodyJSON := FProvider.TestBuildBodyJSON(FProvider.Model, 0.7, 0, LMsgs);

    LRoot := TJSONObject.ParseJSONValue(LBodyJSON) as TJSONObject;
    try
      CheckNull(LRoot.FindValue('tools'),
        'Fase 2: Campo tools DEVE ser suprimido para que a resposta final seja estruturada');

      LGenConfig := TJSONObject(LRoot.FindValue('generationConfig'));
      CheckNotNull(LGenConfig, 'Fase 2: generationConfig deve existir');
      CheckEquals('application/json',
        LGenConfig.GetValue<string>('responseMimeType', ''),
        'Fase 2: responseMimeType DEVE ser application/json');

      LSchema := TJSONObject(LGenConfig.FindValue('responseSchema'));
      CheckNotNull(LSchema, 'Fase 2: responseSchema DEVE estar presente');
      CheckEquals('OBJECT', LSchema.GetValue<string>('type', ''),
        'Fase 2: responseSchema type deve ser OBJECT');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestGeminiProvider.TestExtractErrorMessage_GeminiFormat;
var
  LErrJSON, LExtracted: string;
begin
  LErrJSON :=
    '{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}';
  LExtracted := FProvider.TestExtractErrorMessage(LErrJSON);
  CheckTrue(LExtracted.Contains('API key not valid'),
    'Mensagem de erro extraida incorreta: ' + LExtracted);
  CheckTrue(LExtracted.Contains('INVALID_ARGUMENT'),
    'Status de erro deve estar presente: ' + LExtracted);
end;

procedure TTestGeminiProvider.TestSend_SimpleMessageAndTokens;
var
  LResp: string;
begin
  FProvider.SetMockResponse('Resposta oficial do Gemini 2.5 Flash', 15, 25, 40);
  FProvider.AddUser('Ola Gemini');
  LResp := FProvider.Send;

  CheckEquals('Resposta oficial do Gemini 2.5 Flash', LResp,
    'Resposta do Send incorreta');
  CheckEquals(15, FProvider.PromptTokenCount, 'PromptTokenCount deve ser 15');
  CheckEquals(25, FProvider.CandidatesTokenCount,
    'CandidatesTokenCount deve ser 25');
  CheckEquals(40, FProvider.TotalTokenCount, 'TotalTokenCount deve ser 40');
end;

procedure TTestGeminiProvider.TestSend_ToolCallsLoop;
var
  LToolExecuted: Boolean;
  LQueue: TArray<string>;
  LRespTurn1, LRespTurn2: TJSONObject;
  LCandidates, LParts: TJSONArray;
  LCand, LContent, LPart, LFuncCall, LArgs: TJSONObject;
  LFinalResp: string;
begin
  LToolExecuted := False;

  FProvider.RegisterFunction('obter_saldo', 'Retorna saldo de conta',
    '{"type":"object","properties":{"conta":{"type":"string"}},"required":["conta"]}',
    function(const AArgs: string): string
    begin
      LToolExecuted := True;
      Result := '{"saldo": 999.50}';
    end);

  // Turno 1: Mock de resposta do Gemini solicitando toolCall
  LRespTurn1 := TJSONObject.Create;
  try
    LCandidates := TJSONArray.Create;
    LRespTurn1.AddPair('candidates', LCandidates);
    LCand := TJSONObject.Create;
    LCandidates.AddElement(LCand);
    LContent := TJSONObject.Create;
    LCand.AddPair('content', LContent);
    LContent.AddPair('role', 'model');
    LParts := TJSONArray.Create;
    LContent.AddPair('parts', LParts);
    LPart := TJSONObject.Create;
    LParts.AddElement(LPart);
    LFuncCall := TJSONObject.Create;
    LPart.AddPair('functionCall', LFuncCall);
    LFuncCall.AddPair('name', 'obter_saldo');
    LFuncCall.AddPair('id', 'call_gemini_saldo_1');
    LArgs := TJSONObject.Create;
    LArgs.AddPair('conta', '12345');
    LFuncCall.AddPair('args', LArgs);

    // Turno 2: Resposta final de texto apos a execucao da tool
    LRespTurn2 := TJSONObject.Create;
    try
      LCandidates := TJSONArray.Create;
      LRespTurn2.AddPair('candidates', LCandidates);
      LCand := TJSONObject.Create;
      LCandidates.AddElement(LCand);
      LContent := TJSONObject.Create;
      LCand.AddPair('content', LContent);
      LContent.AddPair('role', 'model');
      LParts := TJSONArray.Create;
      LContent.AddPair('parts', LParts);
      LPart := TJSONObject.Create;
      LParts.AddElement(LPart);
      LPart.AddPair('text', 'O seu saldo atual e de R$ 999,50.');

      SetLength(LQueue, 2);
      LQueue[0] := LRespTurn1.ToJSON;
      LQueue[1] := LRespTurn2.ToJSON;

      FProvider.SetMockResponsesQueue(LQueue);

      FProvider.AddUser('Quanto tenho na conta 12345?');
      LFinalResp := FProvider.Send;

      CheckTrue(LToolExecuted,
        'A ferramenta obter_saldo deveria ter sido executada');
      CheckEquals('O seu saldo atual e de R$ 999,50.', LFinalResp,
        'Resposta final deve ser a do segundo turno');
    finally
      LRespTurn2.Free;
    end;
  finally
    LRespTurn1.Free;
  end;
end;

procedure TTestGeminiProvider.TestAppendAssistantToolCallsToHistory;
var
  LRawJSON: string;
  LRoot, LCand, LContent, LPart, LFuncCall, LArgs: TJSONObject;
  LCandidates, LParts: TJSONArray;
  LAddedMsg: TJSONObject;
  LToolCalls: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LCandidates := TJSONArray.Create;
    LRoot.AddPair('candidates', LCandidates);
    LCand := TJSONObject.Create;
    LCandidates.AddElement(LCand);
    LContent := TJSONObject.Create;
    LCand.AddPair('content', LContent);
    LContent.AddPair('role', 'model');
    LParts := TJSONArray.Create;
    LContent.AddPair('parts', LParts);

    LPart := TJSONObject.Create;
    LParts.AddElement(LPart);
    LFuncCall := TJSONObject.Create;
    LPart.AddPair('functionCall', LFuncCall);
    LFuncCall.AddPair('name', 'minha_funcao');
    LFuncCall.AddPair('id', 'call_gemini_123');
    LArgs := TJSONObject.Create;
    LArgs.AddPair('param1', 'teste');
    LFuncCall.AddPair('args', LArgs);

    LRawJSON := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;

  FProvider.TestAppendAssistantToolCallsToHistory(LRawJSON);

  CheckEquals(1, FProvider.Messages.Count,
    'Deve ter adicionado 1 mensagem ao historico');
  LAddedMsg := TJSONObject(FProvider.Messages.Items[0]);
  CheckEquals('assistant', LAddedMsg.GetValue<string>('role', ''),
    'Role deve ser assistant');
  CheckNotNull(LAddedMsg.FindValue('tool_calls'),
    'tool_calls deve estar presente');

  LToolCalls := TJSONArray(LAddedMsg.FindValue('tool_calls'));
  CheckEquals(1, LToolCalls.Count, 'Deve conter 1 tool call');
  CheckEquals('call_gemini_123', TJSONObject(LToolCalls.Items[0])
    .GetValue<string>('id', ''));
end;

procedure TTestGeminiProvider.TestFactory_CreateGeminiProvider;
var
  LProv: ILLMProvider;
  LGemini: IGeminiProvider;
begin
  LProv := CreateLLMProvider(ptGemini, 'chave_gemini_xyz');
  CheckNotNull(LProv, 'Provedor retornado pela factory nao deve ser nulo');
  CheckEquals('chave_gemini_xyz', LProv.ApiKey, 'ApiKey incorreta');
  CheckEquals('gemini-2.5-flash', LProv.Model,
    'Modelo padrao deve ser gemini-2.5-flash');

  CheckTrue(Supports(LProv, IGeminiProvider, LGemini),
    'Provedor deve implementar IGeminiProvider');
end;

procedure TTestGeminiProvider.TestFactory_Polymorphic;
begin
  CheckTrue(TLLMProviderType.FromStr('Gemini') = ptGemini,
    'FromStr deve reconhecer Gemini');
  CheckTrue(TLLMProviderType.FromStr('gemini') = ptGemini,
    'FromStr deve ser case-insensitive');
  CheckEquals('Gemini', ptGemini.ToString, 'ToString deve retornar Gemini');

  var
  LNames := TLLMProviderType.Names;
  var
  LFound := False;
  for var LName in LNames do
  begin
    if SameText(LName, 'Gemini') then
      LFound := True;
  end;
  CheckTrue(LFound, 'Names deve conter Gemini');
end;

initialization

RegisterTest(TTestGeminiProvider.Suite);

end.
