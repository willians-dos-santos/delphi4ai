unit Test.Ollama.Provider;

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
  Ollama.Provider;

type
  /// <summary>
  /// Mock do provedor Ollama para testes unitarios sem conexao real de rede
  /// </summary>
  TMockOllamaProvider = class(TOllamaProvider)
  private
    FLastRequestBody: string;
    FMockResponseContent: string;
    FMockRawJSON: string;
    FMockStatusCode: Integer;
    FMockErrorMessage: string;
  protected
    function ExecuteRequest(const ABodyJSON: string; out ARawJSON: string): string; override;
  public
    constructor Create(const AModel: string = 'llama3.2';
      const ABaseURL: string = 'http://localhost:11434/api/chat';
      const AApiKey: string = '');

    procedure SetMockResponse(const AContent: string);
    procedure SetMockRawJSON(const ARawJSON: string);
    procedure SetMockError(const AStatusCode: Integer; const AErrorMsg: string);
    procedure SetMockToolCall(const AFuncName, AArgsJSON: string; const AContent: string = ''; const AToolId: string = '');

    function TestBuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string;
    function TestExtractErrorMessage(const AErrorJSON: string): string;
    procedure TestAppendAssistantToolCallsToHistory(const ARawJSON: string);

    property LastRequestBody: string read FLastRequestBody;
  end;

  /// <summary>
  /// Suite de testes unitarios para o provedor Ollama
  /// </summary>
  TTestOllamaProvider = class(TTestCase)
  private
    FProvider: TMockOllamaProvider;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialDefaults;
    procedure TestBuildBodyJSON_Options;
    procedure TestBuildBodyJSON_WithTools;
    procedure TestExtractErrorMessage_OllamaFormat;
    procedure TestSend_SimpleMessage;
    procedure TestSend_ToolCallsWithJsonObjectArgs;
    procedure TestSend_ToolCallsWithJsonStringArgs;
    procedure TestAppendAssistantToolCallsToHistory;
    procedure TestFactory_CreateOllamaProvider;
    procedure TestFactory_Polymorphic;
  end;

implementation

uses
  LLM.Exceptions,
  LLM.Factory;

{ TMockOllamaProvider }

constructor TMockOllamaProvider.Create(const AModel, ABaseURL, AApiKey: string);
begin
  inherited Create(AModel, ABaseURL, AApiKey);
  FMockStatusCode := 200;
  FMockResponseContent := 'Resposta simulada do Ollama';
  FMockRawJSON := EmptyStr;
end;

procedure TMockOllamaProvider.SetMockResponse(const AContent: string);
begin
  FMockStatusCode := 200;
  FMockResponseContent := AContent;
  FMockRawJSON := EmptyStr;
end;

procedure TMockOllamaProvider.SetMockRawJSON(const ARawJSON: string);
begin
  FMockStatusCode := 200;
  FMockRawJSON := ARawJSON;
end;

procedure TMockOllamaProvider.SetMockError(const AStatusCode: Integer;
  const AErrorMsg: string);
begin
  FMockStatusCode := AStatusCode;
  FMockErrorMessage := AErrorMsg;
end;

procedure TMockOllamaProvider.SetMockToolCall(const AFuncName, AArgsJSON,
  AContent, AToolId: string);
var
  LRoot, LMsg, LToolCall, LFunc, LArgsObj: TJSONObject;
  LToolCalls: TJSONArray;
  LVal: TJSONValue;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('model', FModel);
    LRoot.AddPair('done', True);

    LMsg := TJSONObject.Create;
    LRoot.AddPair('message', LMsg);
    LMsg.AddPair('role', 'assistant');

    if AContent.IsEmpty then
      LMsg.AddPair('content', TJSONNull.Create)
    else
      LMsg.AddPair('content', AContent);

    LToolCalls := TJSONArray.Create;
    LMsg.AddPair('tool_calls', LToolCalls);

    LToolCall := TJSONObject.Create;
    LToolCalls.AddElement(LToolCall);

    if not AToolId.IsEmpty then
      LToolCall.AddPair('id', AToolId);

    LFunc := TJSONObject.Create;
    LToolCall.AddPair('function', LFunc);
    LFunc.AddPair('name', AFuncName);

    LVal := TJSONObject.ParseJSONValue(AArgsJSON);
    if LVal is TJSONObject then
      LFunc.AddPair('arguments', TJSONObject(LVal))
    else
    begin
      if Assigned(LVal) then
        LVal.Free;
      LFunc.AddPair('arguments', AArgsJSON);
    end;

    FMockStatusCode := 200;
    FMockRawJSON := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TMockOllamaProvider.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LVal, LMsgVal, LToolsVal, LFuncVal, LContentVal, LArgsVal: TJSONValue;
  LRoot, LMsg, LCallObj, LFuncObj: TJSONObject;
  LToolCallsArr: TJSONArray;
  LCalls: TLLMToolCallList;
  I: Integer;
  LId, LName, LArgs: string;
begin
  FLastRequestBody := ABodyJSON;
  Result := EmptyStr;
  ARawJSON := EmptyStr;
  SetLastToolCalls([]);

  if FMockStatusCode <> 200 then
  begin
    ARawJSON := Format('{"error":"%s"}', [FMockErrorMessage]);
    raise ELLMAPIError.CreateFmt('Erro API Ollama [%d]: %s',
      [FMockStatusCode, ExtractErrorMessage(ARawJSON)]);
  end;

  if not FMockRawJSON.IsEmpty then
    ARawJSON := FMockRawJSON
  else
  begin
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('model', FModel);
      LMsg := TJSONObject.Create;
      LMsg.AddPair('role', 'assistant');
      LMsg.AddPair('content', FMockResponseContent);
      LRoot.AddPair('message', LMsg);
      LRoot.AddPair('done', True);
      ARawJSON := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
  end;

  LVal := TJSONObject.ParseJSONValue(ARawJSON);
  if LVal is TJSONObject then
  begin
    LRoot := TJSONObject(LVal);
    try
      LMsgVal := LRoot.FindValue('message');
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
              if LId.IsEmpty then
                LId := Format('call_ollama_%d', [I]);

              LName := EmptyStr;
              LArgs := EmptyStr;

              LFuncVal := LCallObj.FindValue('function');
              if LFuncVal is TJSONObject then
              begin
                LFuncObj := TJSONObject(LFuncVal);
                LName := LFuncObj.GetValue<string>('name', EmptyStr);

                LArgsVal := LFuncObj.FindValue('arguments');
                if LArgsVal is TJSONObject then
                  LArgs := LArgsVal.ToJSON
                else if LArgsVal is TJSONString then
                  LArgs := LArgsVal.Value
                else if Assigned(LArgsVal) then
                  LArgs := LArgsVal.ToJSON;
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
    finally
      LRoot.Free;
    end;
  end;
end;

function TMockOllamaProvider.TestBuildBodyJSON(const AModel: string;
  ATemp: Double; AMaxTok: Integer; AMsgs: TJSONArray): string;
begin
  Result := BuildBodyJSON(AModel, ATemp, AMaxTok, AMsgs);
end;

function TMockOllamaProvider.TestExtractErrorMessage(
  const AErrorJSON: string): string;
begin
  Result := ExtractErrorMessage(AErrorJSON);
end;

procedure TMockOllamaProvider.TestAppendAssistantToolCallsToHistory(
  const ARawJSON: string);
begin
  AppendAssistantToolCallsToHistory(ARawJSON);
end;

{ TTestOllamaProvider }

procedure TTestOllamaProvider.SetUp;
begin
  inherited;
  FProvider := TMockOllamaProvider.Create('llama3.2',
    'http://localhost:11434/api/chat', '');
end;

procedure TTestOllamaProvider.TearDown;
begin
  FProvider.Free;
  inherited;
end;

procedure TTestOllamaProvider.TestInitialDefaults;
begin
  CheckEquals('llama3.2', FProvider.Model, 'Modelo padrao deve ser llama3.2');
  CheckEquals('http://localhost:11434/api/chat', FProvider.BaseURL,
    'BaseURL padrao deve ser http://localhost:11434/api/chat');
  CheckEquals('', FProvider.ApiKey, 'ApiKey padrao deve ser vazia no Ollama');
  CheckTrue(FProvider.HistoryStrategy = hsSlidingWindow,
    'HistoryStrategy padrao deve ser hsSlidingWindow');
  CheckTrue(FProvider.AutoAddAssistantResponse,
    'AutoAddAssistantResponse deve ser True por padrao');
  CheckEquals(0, FProvider.Messages.Count, 'Historico inicial deve estar vazio');
end;

procedure TTestOllamaProvider.TestBuildBodyJSON_Options;
var
  LMsgs: TJSONArray;
  LMsg: TJSONObject;
  LBodyStr: string;
  LVal, LOptionsVal: TJSONValue;
  LRoot, LOptions: TJSONObject;
begin
  LMsgs := TJSONArray.Create;
  try
    LMsg := TJSONObject.Create;
    LMsg.AddPair('role', 'user');
    LMsg.AddPair('content', 'Ola Ollama');
    LMsgs.AddElement(LMsg);

    LBodyStr := FProvider.TestBuildBodyJSON('llama3.2', 0.5, 512, LMsgs);

    LVal := TJSONObject.ParseJSONValue(LBodyStr);
    CheckTrue(LVal is TJSONObject, 'Body gerado deve ser um JSON valido');
    LRoot := TJSONObject(LVal);
    try
      CheckEquals('llama3.2', LRoot.GetValue<string>('model', ''), 'Campo model incorreto');
      CheckFalse(LRoot.GetValue<Boolean>('stream', True), 'Stream deve ser False');

      // No Ollama, temperature e num_predict devem estar dentro de options
      LOptionsVal := LRoot.FindValue('options');
      CheckTrue(LOptionsVal is TJSONObject, 'Objeto options deve estar presente');
      LOptions := TJSONObject(LOptionsVal);
      CheckEquals(0.5, LOptions.GetValue<Double>('temperature', 0.0), 0.01,
        'Temperature deve estar em options');
      CheckEquals(512, LOptions.GetValue<Integer>('num_predict', 0),
        'num_predict deve estar em options');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestOllamaProvider.TestBuildBodyJSON_WithTools;
var
  LMsgs: TJSONArray;
  LBodyStr: string;
  LVal, LToolsVal: TJSONValue;
  LRoot: TJSONObject;
begin
  FProvider.RegisterFunction('obter_cotacao', 'Obtem a cotacao de uma moeda',
    '{"type":"object","properties":{"moeda":{"type":"string"}}}',
    function(const AArgs: string): string
    begin
      Result := '5.50';
    end);

  LMsgs := TJSONArray.Create;
  try
    LBodyStr := FProvider.TestBuildBodyJSON('llama3.2', 0.7, 0, LMsgs);

    LVal := TJSONObject.ParseJSONValue(LBodyStr);
    CheckTrue(LVal is TJSONObject, 'Body gerado deve ser JSON');
    LRoot := TJSONObject(LVal);
    try
      LToolsVal := LRoot.FindValue('tools');
      CheckTrue(LToolsVal is TJSONArray, 'Campo tools deve existir no body');
      CheckEquals(1, TJSONArray(LToolsVal).Count, 'Deve ter 1 tool registrada');
    finally
      LRoot.Free;
    end;
  finally
    LMsgs.Free;
  end;
end;

procedure TTestOllamaProvider.TestExtractErrorMessage_OllamaFormat;
var
  LErrJSON, LMsg: string;
begin
  // Formato padrao de erro do Ollama: {"error": "model 'mistral' not found"}
  LErrJSON := '{"error":"model ''mistral'' not found"}';
  LMsg := FProvider.TestExtractErrorMessage(LErrJSON);
  CheckEquals('model ''mistral'' not found', LMsg,
    'Deve extrair erro string retornado pelo Ollama');
end;

procedure TTestOllamaProvider.TestSend_SimpleMessage;
var
  LResp: string;
begin
  FProvider.SetMockResponse('Ollama respondeu com sucesso!');
  FProvider.AddUser('Teste de mensagem');
  LResp := FProvider.Send;

  CheckEquals('Ollama respondeu com sucesso!', LResp, 'Resposta incorreta');
  CheckEquals(2, FProvider.Messages.Count,
    'Historico deve conter pergunta do usuario e resposta do assistente');
  CheckEquals('assistant',
    TJSONObject(FProvider.Messages.Items[1]).GetValue<string>('role', ''),
    'Role da resposta deve ser assistant');
end;

procedure TTestOllamaProvider.TestSend_ToolCallsWithJsonObjectArgs;
var
  LToolInvoked: Boolean;
  LParamRecebido: string;
begin
  LToolInvoked := False;
  LParamRecebido := EmptyStr;

  FProvider.RegisterFunction('consultar_saldo', 'Consulta o saldo de uma conta',
    '{"type":"object","properties":{"conta":{"type":"string"}}}',
    function(const AArgs: string): string
    var
      LArgsObj: TJSONObject;
    begin
      LToolInvoked := True;
      LArgsObj := TJSONObject.ParseJSONValue(AArgs) as TJSONObject;
      if Assigned(LArgsObj) then
      begin
        try
          LParamRecebido := LArgsObj.GetValue<string>('conta', '');
        finally
          LArgsObj.Free;
        end;
      end;
      Result := '{"saldo": 1500.00}';
    end);

  // Simula tool call retornado pelo Ollama com arguments como objeto JSON
  FProvider.SetMockToolCall('consultar_saldo', '{"conta":"12345"}', '', 'call_1');
  FProvider.AutoExecuteTools := False; // Para verificar estado retornado
  FProvider.Send;

  CheckTrue(FProvider.HasToolCalls, 'Deve identificar que o Ollama requisitou tool call');
  CheckEquals(1, Length(FProvider.LastToolCalls), 'Deve haver 1 tool call');
  CheckEquals('consultar_saldo', FProvider.LastToolCalls[0].Name, 'Nome da funcao incorreto');
  CheckTrue(FProvider.LastToolCalls[0].Arguments.Contains('12345'), 'Argumentos devem conter a conta');
end;

procedure TTestOllamaProvider.TestSend_ToolCallsWithJsonStringArgs;
begin
  // Simula tool call retornado pelo Ollama com arguments como string JSON escapada
  FProvider.SetMockRawJSON(
    '{"model":"llama3.2","message":{"role":"assistant","content":null,' +
    '"tool_calls":[{"function":{"name":"calcular","arguments":"{\"expressao\":\"2+2\"}"}}]},' +
    '"done":true}');
  FProvider.AutoExecuteTools := False;
  FProvider.Send;

  CheckTrue(FProvider.HasToolCalls, 'Deve detectar tool call com arguments string');
  CheckEquals('calcular', FProvider.LastToolCalls[0].Name, 'Nome da funcao incorreto');
  CheckTrue(FProvider.LastToolCalls[0].Arguments.Contains('2+2'), 'Argumento expressao incorreto');
  // Se nao veio id na resposta, deve ter gerado synthetic id
  CheckFalse(FProvider.LastToolCalls[0].Id.IsEmpty, 'Id sintetico deve ser gerado');
end;

procedure TTestOllamaProvider.TestAppendAssistantToolCallsToHistory;
var
  LRawJSON: string;
  LLastMsg: TJSONObject;
begin
  LRawJSON := '{"model":"llama3.2","message":{"role":"assistant","content":"","tool_calls":[{"function":{"name":"ping","arguments":{}}}]},"done":true}';
  FProvider.TestAppendAssistantToolCallsToHistory(LRawJSON);

  CheckEquals(1, FProvider.Messages.Count, 'Mensagem deve ter sido anexada');
  LLastMsg := TJSONObject(FProvider.Messages.Items[0]);
  CheckEquals('assistant', LLastMsg.GetValue<string>('role', ''), 'Role incorreto');
  CheckTrue(LLastMsg.FindValue('tool_calls') is TJSONArray, 'tool_calls deve estar no historico');
end;

procedure TTestOllamaProvider.TestFactory_CreateOllamaProvider;
var
  LProvider: IOllamaProvider;
begin
  LProvider := CreateOllamaProvider('qwen2.5', 'http://127.0.0.1:11434/api/chat');
  CheckNotNull(LProvider, 'Provedor Ollama nao pode ser nulo');
  CheckEquals('qwen2.5', LProvider.Model, 'Modelo deve ser qwen2.5');
  CheckEquals('http://127.0.0.1:11434/api/chat', LProvider.BaseURL, 'BaseURL incorreta');
end;

procedure TTestOllamaProvider.TestFactory_Polymorphic;
var
  LProvider: ILLMProvider;
begin
  LProvider := CreateLLMProvider(ptOllama, 'llama3.2');
  CheckNotNull(LProvider, 'Provedor polimorfico ptOllama nao pode ser nulo');
  CheckTrue(Supports(LProvider, IOllamaProvider), 'Instancia deve implementar IOllamaProvider');
  CheckEquals('llama3.2', LProvider.Model, 'Modelo deve ser llama3.2');
end;

initialization
  RegisterTest(TTestOllamaProvider.Suite);

end.
