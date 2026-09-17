unit Test.LLM.Tools;

interface

uses
  TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  LLM.Interfaces,
  LLM.Tools,
  LLM.Exceptions,
  LLM.MockProvider;

type
  TTestLLMTools = class(TTestCase)
  private
    FProvider: TMockLLMProvider;
    function GetMessageProperty(const AIndex: Integer; const AProperty: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRegisterTool_StringSchema;
    procedure TestRegisterTool_JSONObjectSchema;
    procedure TestRegisterTool_StringCallback;
    procedure TestRegisterTool_JSONCallback;
    procedure TestBuildBodyJSON_IncludesToolsArray;
    procedure TestExecuteRequest_ParsesToolCalls;
    procedure TestAutoExecuteTools_FullLoop;
    procedure TestManualExecuteTools_Flow;
    procedure TestToolException_CatchesAndSendsToModel;
    procedure TestToolException_PropagatesWhenConfigured;
    procedure TestMaxToolIterations_RaisesException;
    procedure TestSlidingWindow_PreservesToolBlockIntegrity;
  end;

implementation

uses
  LLM.HistoryStrategy;

{ TTestLLMTools }

procedure TTestLLMTools.SetUp;
begin
  inherited;
  FProvider := TMockLLMProvider.Create;
end;

procedure TTestLLMTools.TearDown;
begin
  FProvider.Free;
  inherited;
end;

function TTestLLMTools.GetMessageProperty(const AIndex: Integer;
  const AProperty: string): string;
var
  LObj: TJSONObject;
begin
  Result := EmptyStr;
  if (AIndex >= 0) and (AIndex < FProvider.Messages.Count) and
    (FProvider.Messages.Items[AIndex] is TJSONObject) then
  begin
    LObj := TJSONObject(FProvider.Messages.Items[AIndex]);
    Result := LObj.GetValue<string>(AProperty, EmptyStr);
  end;
end;

procedure TTestLLMTools.TestRegisterTool_StringSchema;
var
  LTool: ILLMTool;
begin
  FProvider.RegisterTool('obter_tempo', 'Consulta a previsao do tempo',
    '{"type":"object","properties":{"cidade":{"type":"string"}},"required":["cidade"]}',
    function(const AArgs: string): string
    begin
      Result := '{"temp":25}';
    end);

  CheckEquals(1, FProvider.Tools.Count, 'Deve registrar 1 ferramenta');
  CheckTrue(FProvider.Tools.Find('obter_tempo', LTool), 'Deve encontrar a ferramenta pelo nome');
  CheckEquals('obter_tempo', LTool.Name);
  CheckEquals('Consulta a previsao do tempo', LTool.Description);
  CheckNotNull(LTool.ParametersSchema);
end;

procedure TTestLLMTools.TestRegisterTool_JSONObjectSchema;
var
  LSchema: TJSONObject;
  LProps: TJSONObject;
  LTool: ILLMTool;
begin
  LSchema := TJSONObject.Create;
  try
    LSchema.AddPair('type', 'object');
    LProps := TJSONObject.Create;
    LProps.AddPair('moeda', TJSONObject.Create.AddPair('type', 'string'));
    LSchema.AddPair('properties', LProps);

    FProvider.RegisterTool('cotacao_moeda', 'Obtem cotacao de moeda', LSchema,
      function(const AArgs: string): string
      begin
        Result := '{"cotacao": 5.45}';
      end);
  finally
    LSchema.Free;
  end;

  CheckTrue(FProvider.Tools.Find('cotacao_moeda', LTool));
  CheckEquals('cotacao_moeda', LTool.Name);
  CheckNotNull(LTool.ParametersSchema);
  CheckEquals('object', LTool.ParametersSchema.GetValue<string>('type', ''));
end;

procedure TTestLLMTools.TestRegisterTool_StringCallback;
var
  LTool: ILLMTool;
  LResult: string;
begin
  FProvider.RegisterFunction('somar', 'Soma dois numeros',
    '{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}}}',
    function(const AArgs: string): string
    begin
      Result := '{"soma": 42}';
    end);

  CheckTrue(FProvider.Tools.Find('somar', LTool));
  LResult := LTool.Execute('{"a":20,"b":22}');
  CheckEquals('{"soma": 42}', LResult);
end;

procedure TTestLLMTools.TestRegisterTool_JSONCallback;
var
  LTool: ILLMTool;
  LResult: string;
begin
  FProvider.RegisterFunction('dobrar', 'Dobra um valor',
    '{"type":"object","properties":{"val":{"type":"integer"}}}',
    function(const AArgs: TJSONObject): string
    var
      V: Integer;
    begin
      V := AArgs.GetValue<Integer>('val', 0);
      Result := Format('{"dobro": %d}', [V * 2]);
    end);

  CheckTrue(FProvider.Tools.Find('dobrar', LTool));
  LResult := LTool.Execute('{"val": 25}');
  CheckEquals('{"dobro": 50}', LResult);
end;

procedure TTestLLMTools.TestBuildBodyJSON_IncludesToolsArray;
var
  LJSONStr: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
  LToolsArr: TJSONArray;
  LToolItem, LFuncObj: TJSONObject;
begin
  FProvider.RegisterTool('ping', 'Envia um ping', '{}',
    function(const AArgs: string): string
    begin
      Result := 'pong';
    end);

  LJSONStr := FProvider.TestBuildBodyJSON(FProvider.Model, FProvider.Temperature,
    FProvider.MaxTokens, FProvider.Messages);

  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal);
  try
    CheckTrue(LVal is TJSONObject);
    LObj := TJSONObject(LVal);

    CheckTrue(LObj.TryGetValue<TJSONArray>('tools', LToolsArr), 'Deve conter no tools');
    CheckEquals(1, LToolsArr.Count, 'Deve ter 1 tool');

    LToolItem := LToolsArr.Items[0] as TJSONObject;
    CheckEquals('function', LToolItem.GetValue<string>('type', ''));

    CheckTrue(LToolItem.TryGetValue<TJSONObject>('function', LFuncObj));
    CheckEquals('ping', LFuncObj.GetValue<string>('name', ''));
    CheckEquals('auto', LObj.GetValue<string>('tool_choice', ''));
  finally
    LVal.Free;
  end;
end;

procedure TTestLLMTools.TestExecuteRequest_ParsesToolCalls;
var LRaw:String;
begin


  FProvider.SetMockToolCall('call_001', 'buscar_cliente', '{"codigo":123}');
  FProvider.TestExecuteRequest('{}', LRaw);

  CheckTrue(FProvider.HasToolCalls, 'HasToolCalls deve ser True');
  CheckEquals(1, Length(FProvider.LastToolCalls), 'Deve haver 1 tool call retornado');
  CheckEquals('call_001', FProvider.LastToolCalls[0].Id);
  CheckEquals('buscar_cliente', FProvider.LastToolCalls[0].Name);
  CheckEquals('{"codigo":123}', FProvider.LastToolCalls[0].Arguments);
end;

procedure TTestLLMTools.TestAutoExecuteTools_FullLoop;
var
  LResponse1, LResponse2: string;
  LFinalResult: string;
  LToolCallsExecuted: Boolean;
begin
  LToolCallsExecuted := False;

  FProvider.RegisterTool('obter_saldo', 'Retorna saldo da conta',
    '{"type":"object","properties":{"conta":{"type":"string"}}}',
    function(const AArgs: string): string
    begin
      LToolCallsExecuted := True;
      Result := '{"saldo": 1250.50}';
    end);

  // Monta respostas simuladas da API:
  // Turno 1: LLM pede chamada de ferramenta
  LResponse1 :=
    '{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":null,' +
    '"tool_calls":[{"id":"call_saldo_99","type":"function","function":{"name":"obter_saldo","arguments":"{\"conta\":\"1234\"}"}}]}}]}';

  // Turno 2: LLM recebe o resultado da ferramenta e gera texto final
  LResponse2 :=
    '{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"Seu saldo atual e de R$ 1.250,50."}}]}';

  FProvider.SetMockResponsesQueue([LResponse1, LResponse2]);
  FProvider.AddUser('Qual e o meu saldo?');

  LFinalResult := FProvider.Send;

  CheckTrue(LToolCallsExecuted, 'A funcao Delphi deveria ter sido invocada automaticamente');
  CheckEquals('Seu saldo atual e de R$ 1.250,50.', LFinalResult);

  // O historico deve conter:
  // 0: user ('Qual e o meu saldo?')
  // 1: assistant (com tool_calls)
  // 2: tool (com tool_call_id: call_saldo_99 e resultado da funcao)
  // 3: assistant ('Seu saldo atual e de R$ 1.250,50.')
  CheckEquals(4, FProvider.Messages.Count, 'Historico deve conter as 4 mensagens do fluxo multi-turn');
  CheckEquals('user', GetMessageProperty(0, 'role'));
  CheckEquals('assistant', GetMessageProperty(1, 'role'));
  CheckEquals('tool', GetMessageProperty(2, 'role'));
  CheckEquals('call_saldo_99', GetMessageProperty(2, 'tool_call_id'));
  CheckEquals('{"saldo": 1250.50}', GetMessageProperty(2, 'content'));
  CheckEquals('assistant', GetMessageProperty(3, 'role'));
  CheckEquals('Seu saldo atual e de R$ 1.250,50.', GetMessageProperty(3, 'content'));
end;

procedure TTestLLMTools.TestManualExecuteTools_Flow;
var
  LResp: string;
begin
  FProvider.AutoExecuteTools := False;
  FProvider.SetMockToolCall('call_manual_1', 'calcular_desconto', '{"valor":100}');

  FProvider.AddUser('Calcule o desconto');
  LResp := FProvider.Send;

  CheckTrue(FProvider.HasToolCalls, 'Deve sinalizar que ha tool calls pendentes');
  CheckEquals(1, Length(FProvider.LastToolCalls));
  CheckEquals('call_manual_1', FProvider.LastToolCalls[0].Id);
  CheckEquals('calcular_desconto', FProvider.LastToolCalls[0].Name);

  // No modo manual, o assistente foi inserido com os tool_calls
  CheckEquals(2, FProvider.Messages.Count, 'User + Assistant(tool_calls)');

  // Usuario adiciona manualmente a resposta da tool
  FProvider.AddToolResult(FProvider.LastToolCalls[0].Id, '{"desconto": 10}');
  CheckEquals(3, FProvider.Messages.Count);
  CheckEquals('tool', GetMessageProperty(2, 'role'));
  CheckEquals('call_manual_1', GetMessageProperty(2, 'tool_call_id'));
end;

procedure TTestLLMTools.TestToolException_CatchesAndSendsToModel;
var
  LResp1, LResp2, LFinal: string;
begin
  FProvider.PropagateToolExceptions := False; // Padrao seguro

  FProvider.RegisterTool('consultar_cpf', 'Busca dados por CPF', '{}',
    function(const AArgs: string): string
    begin
      raise Exception.Create('CPF nao encontrado no banco');
    end);

  LResp1 :=
    '{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":null,' +
    '"tool_calls":[{"id":"call_cpf_1","type":"function","function":{"name":"consultar_cpf","arguments":"{}"}}]}}]}';
  LResp2 :=
    '{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"Nao foi possivel localizar o CPF informado."}}]}';

  FProvider.SetMockResponsesQueue([LResp1, LResp2]);
  FProvider.AddUser('Consulte meu CPF');

  LFinal := FProvider.Send;

  CheckEquals('Nao foi possivel localizar o CPF informado.', LFinal);
  // Mensagem da tool no historico deve conter o JSON de erro
  CheckEquals('tool', GetMessageProperty(2, 'role'));
  CheckTrue(Pos('CPF nao encontrado no banco', GetMessageProperty(2, 'content')) > 0,
    'Erro deve ser formatado no content da mensagem de tool');
end;

procedure TTestLLMTools.TestToolException_PropagatesWhenConfigured;
var
  LExRaised: Boolean;
begin
  FProvider.PropagateToolExceptions := True;

  FProvider.RegisterTool('falhar', 'Funcao que falha', '{}',
    function(const AArgs: string): string
    begin
      raise Exception.Create('Falha proposital');
    end);

  FProvider.SetMockToolCall('call_fail', 'falhar', '{}');
  FProvider.AddUser('Teste');

  LExRaised := False;
  try
    FProvider.Send;
  except
    on E: Exception do
    begin
      LExRaised := True;
      CheckEquals('Falha proposital', E.Message);
    end;
  end;

  CheckTrue(LExRaised, 'Deveria propagar a excecao quando PropagateToolExceptions = True');
end;

procedure TTestLLMTools.TestMaxToolIterations_RaisesException;
var
  LExRaised: Boolean;
  LInfiniteResp: string;
begin
  FProvider.MaxToolIterations := 2;

  FProvider.RegisterTool('loop_infinito', 'Loop', '{}',
    function(const AArgs: string): string
    begin
      Result := '{"next": true}';
    end);

  LInfiniteResp :=
    '{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":null,' +
    '"tool_calls":[{"id":"call_loop","type":"function","function":{"name":"loop_infinito","arguments":"{}"}}]}}]}';

  // Fila com mais respostas do que o limite permitido
  FProvider.SetMockResponsesQueue([LInfiniteResp, LInfiniteResp, LInfiniteResp, LInfiniteResp]);
  FProvider.AddUser('Inicie o loop');

  LExRaised := False;
  try
    FProvider.Send;
  except
    on E: ELLMMaxToolIterationsException do
      LExRaised := True;
  end;

  CheckTrue(LExRaised, 'Deveria lancar ELLMMaxToolIterationsException ao atingir o limite');
end;

procedure TTestLLMTools.TestSlidingWindow_PreservesToolBlockIntegrity;
var
  LAssistObj: TJSONObject;
  LToolCalls: TJSONArray;
  LCallObj: TJSONObject;
begin
  FProvider.HistoryStrategy := hsSlidingWindow;
  FProvider.MaxHistoryMessages := 3;

  // Monta manualmente mensagens antigas com tool
  FProvider.AddUser('Pergunta 1');

  // Assistant com tool call
  LAssistObj := TJSONObject.Create;
  LAssistObj.AddPair('role', 'assistant');
  LAssistObj.AddPair('content', TJSONNull.Create);
  LToolCalls := TJSONArray.Create;
  LCallObj := TJSONObject.Create;
  LCallObj.AddPair('id', 'call_antiga');
  LToolCalls.AddElement(LCallObj);
  LAssistObj.AddPair('tool_calls', LToolCalls);
  FProvider.Messages.AddElement(LAssistObj);

  // Resposta da tool
  FProvider.AddToolResult('call_antiga', '{"res": 1}');

  // Mensagens recentes
  FProvider.AddUser('Pergunta 2');
  FProvider.AddAssistant('Resposta 2');

  // Total antes da poda: 5 mensagens
  CheckEquals(5, FProvider.Messages.Count);

  FProvider.TestApplySlidingWindow;

  // A poda deve descartar o bloco completo da tool (assistant + tool)
  // Nenhuma mensagem 'tool' solta deve permanecer no inicio
  CheckTrue(FProvider.Messages.Count <= 3);
  CheckFalse(GetMessageProperty(0, 'role') = 'tool',
    'A primeira mensagem do historico apos poda nunca deve ser role tool orfa');
end;

initialization

RegisterTest(TTestLLMTools.Suite);

end.