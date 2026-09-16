unit Test.LLM.Base;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  TestFramework,
  LLM.Interfaces,
  LLM.HistoryStrategy,
  LLM.Base,
  LLM.MockProvider;

type
  TTestLLMBase = class(TTestCase)
  private
    FProvider: TMockLLMProvider;
    function GetMessageProperty(const AIndex: Integer;
      const AProperty: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialDefaults;
    procedure TestAddMessages;
    procedure TestClearHistory;
    procedure TestSlidingWindow_WithSystemPrompt;
    procedure TestSlidingWindow_WithoutSystemPrompt;
    procedure TestSlidingWindow_UnderLimitDoesNotDrop;
    procedure TestHistoryStrategy_None;
    procedure TestBuildBodyJSON;
    procedure TestExtractErrorMessage_StandardOpenAI;
    procedure TestExtractErrorMessage_PlainTextFallback;
    procedure TestSend_AutoAddAssistantResponse;
    procedure TestSend_WithoutAutoAddAssistantResponse;
    procedure TestSend_RaisesExceptionOnError;
    procedure TestSummarizeHistory;
  end;

implementation
uses
  LLM.Exceptions;

{ TTestLLMBase }

function TTestLLMBase.GetMessageProperty(const AIndex: Integer;
  const AProperty: string): string;
var
  LItem: TJSONObject;
begin
  Result := EmptyStr;
  if (AIndex >= 0) and (AIndex < FProvider.Messages.Count) and
    (FProvider.Messages.Items[AIndex] is TJSONObject) then
  begin
    LItem := TJSONObject(FProvider.Messages.Items[AIndex]);
    Result := LItem.GetValue<string>(AProperty, EmptyStr);
  end;
end;

procedure TTestLLMBase.SetUp;
begin
  inherited;
  FProvider := TMockLLMProvider.Create('test-api-key',
    'https://api.mock.test/v1/chat/completions', 'gpt-4o-mini');
end;

procedure TTestLLMBase.TearDown;
begin
  FProvider.Free;
  inherited;
end;

procedure TTestLLMBase.TestInitialDefaults;
begin
  CheckEquals('test-api-key', FProvider.ApiKey, 'ApiKey incorreta');
  CheckEquals('https://api.mock.test/v1/chat/completions', FProvider.BaseURL,
    'BaseURL incorreta');
  CheckEquals('gpt-4o-mini', FProvider.Model, 'Model incorreto');
  CheckEquals(0.7, FProvider.Temperature, 0.001,
    'Temperature padrão deve ser 0.7');
  CheckEquals(0, FProvider.MaxTokens, 'MaxTokens padrão deve ser 0');
  CheckEquals(60000, FProvider.Timeout, 'Timeout padrão deve ser 60000 ms');
  CheckTrue(FProvider.AutoAddAssistantResponse,
    'AutoAddAssistantResponse deve ser True por padrão');
  CheckTrue(FProvider.HistoryStrategy = hsSlidingWindow,
    'HistoryStrategy padrão deve ser hsSlidingWindow');
  CheckEquals(10, FProvider.MaxHistoryMessages,
    'MaxHistoryMessages padrão deve ser 10');
  CheckEquals(4, FProvider.KeepRecentMessages,
    'KeepRecentMessages padrão deve ser 4');
  CheckEquals(0, FProvider.Messages.Count,
    'Histórico inicial deve estar vazio');
end;

procedure TTestLLMBase.TestAddMessages;
begin
  FProvider.AddSystem('Instrução de sistema');
  FProvider.AddUser('Pergunta do usuário');
  FProvider.AddAssistant('Resposta do assistente');
  FProvider.AddMessage('custom_role', 'Conteúdo customizado');

  CheckEquals(4, FProvider.Messages.Count,
    'Devem existir 4 mensagens no histórico');

  CheckEquals('system', GetMessageProperty(0, 'role'));
  CheckEquals('Instrução de sistema', GetMessageProperty(0, 'content'));

  CheckEquals('user', GetMessageProperty(1, 'role'));
  CheckEquals('Pergunta do usuário', GetMessageProperty(1, 'content'));

  CheckEquals('assistant', GetMessageProperty(2, 'role'));
  CheckEquals('Resposta do assistente', GetMessageProperty(2, 'content'));

  CheckEquals('custom_role', GetMessageProperty(3, 'role'));
  CheckEquals('Conteúdo customizado', GetMessageProperty(3, 'content'));
end;

procedure TTestLLMBase.TestClearHistory;
begin
  FProvider.AddSystem('System');
  FProvider.AddUser('User');
  FProvider.AddAssistant('Assistant');
  CheckEquals(3, FProvider.Messages.Count);

  FProvider.ClearHistory;
  CheckEquals(0, FProvider.Messages.Count,
    'Após ClearHistory o histórico deve estar vazio');
end;

procedure TTestLLMBase.TestSlidingWindow_WithSystemPrompt;
begin
  FProvider.HistoryStrategy := hsSlidingWindow;
  FProvider.MaxHistoryMessages := 4; // Limite de 4 mensagens no total

  // 1 System + 5 mensagens = 6 mensagens
  FProvider.AddSystem('System Prompt Fixo');
  FProvider.AddUser('Msg 1');
  FProvider.AddAssistant('Resp 1');
  FProvider.AddUser('Msg 2');
  FProvider.AddAssistant('Resp 2');
  FProvider.AddUser('Msg 3');

  CheckEquals(6, FProvider.Messages.Count, 'Total antes da poda deve ser 6');

  FProvider.TestApplySlidingWindow;

  CheckEquals(4, FProvider.Messages.Count,
    'Total após poda deve respeitar MaxHistoryMessages = 4');

  // O System Prompt DEVE ser preservado intacto no índice 0
  CheckEquals('system', GetMessageProperty(0, 'role'));
  CheckEquals('System Prompt Fixo', GetMessageProperty(0, 'content'));

  // As mensagens mais antigas (Msg 1 e Resp 1) foram removidas.
  // As restantes devem ser: Resp 2, Msg 3 (e Msg 2)
  CheckEquals('Resp 2', GetMessageProperty(2, 'content'));
  CheckEquals('Msg 3', GetMessageProperty(3, 'content'));
end;

procedure TTestLLMBase.TestSlidingWindow_WithoutSystemPrompt;
begin
  FProvider.HistoryStrategy := hsSlidingWindow;
  FProvider.MaxHistoryMessages := 3;

  FProvider.AddUser('Msg 1');
  FProvider.AddAssistant('Resp 1');
  FProvider.AddUser('Msg 2');
  FProvider.AddAssistant('Resp 2');

  CheckEquals(4, FProvider.Messages.Count);

  FProvider.TestApplySlidingWindow;

  CheckEquals(3, FProvider.Messages.Count, 'Deve reduzir para 3 mensagens');
  // Sem system prompt, a mensagem 1 (no índice 0) é descartada diretamente
  CheckEquals('Resp 1', GetMessageProperty(0, 'content'));
  CheckEquals('Msg 2', GetMessageProperty(1, 'content'));
  CheckEquals('Resp 2', GetMessageProperty(2, 'content'));
end;

procedure TTestLLMBase.TestSlidingWindow_UnderLimitDoesNotDrop;
begin
  FProvider.HistoryStrategy := hsSlidingWindow;
  FProvider.MaxHistoryMessages := 5;

  FProvider.AddSystem('System');
  FProvider.AddUser('Msg 1');
  FProvider.AddAssistant('Resp 1');

  CheckEquals(3, FProvider.Messages.Count);
  FProvider.TestApplySlidingWindow;
  CheckEquals(3, FProvider.Messages.Count,
    'Nenhuma mensagem deve ser descartada quando abaixo do limite');
end;

procedure TTestLLMBase.TestHistoryStrategy_None;
begin
  FProvider.HistoryStrategy := hsNone;
  FProvider.MaxHistoryMessages := 2;

  FProvider.AddUser('1');
  FProvider.AddAssistant('2');
  FProvider.AddUser('3');
  FProvider.AddAssistant('4');

  FProvider.TestProcessHistory;

  CheckEquals(4, FProvider.Messages.Count,
    'hsNone não deve aplicar poda no histórico');
end;

procedure TTestLLMBase.TestBuildBodyJSON;
var
  LJSONStr: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
  LMsgs: TJSONArray;
begin
  FProvider.Model := 'gpt-4o';
  FProvider.Temperature := 0.5;
  FProvider.MaxTokens := 250;
  FProvider.AddSystem('Instrucao');
  FProvider.AddUser('Pergunta');

  LJSONStr := FProvider.TestBuildBodyJSON(FProvider.Model,
    FProvider.Temperature, FProvider.MaxTokens, FProvider.Messages);

  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal, 'JSON gerado deve ser válido');
  try
    CheckTrue(LVal is TJSONObject, 'JSON gerado deve ser um objeto');
    LObj := TJSONObject(LVal);

    CheckEquals('gpt-4o', LObj.GetValue<string>('model', ''));
    CheckEquals(0.5, LObj.GetValue<Double>('temperature', 0.0), 0.001);
    CheckEquals(250, LObj.GetValue<Integer>('max_tokens', 0));

    CheckTrue(LObj.TryGetValue<TJSONArray>('messages', LMsgs));
    CheckEquals(2, LMsgs.Count,
      'Array de mensagens no JSON deve conter 2 itens');
  finally
    LVal.Free;
  end;
end;

procedure TTestLLMBase.TestExtractErrorMessage_StandardOpenAI;
var
  LErrorJSON, LExtracted: string;
begin
  LErrorJSON :=
    '{"error": {"message": "Chave de API inválida", "type": "invalid_api_key"}}';
  LExtracted := FProvider.TestExtractErrorMessage(LErrorJSON);
  CheckEquals('Chave de API inválida', LExtracted,
    'Deve extrair corretamente error.message');
end;

procedure TTestLLMBase.TestExtractErrorMessage_PlainTextFallback;
var
  LPlainText, LExtracted: string;
begin
  LPlainText := '502 Bad Gateway - Servidor indisponível';
  LExtracted := FProvider.TestExtractErrorMessage(LPlainText);
  CheckEquals(LPlainText, LExtracted,
    'Deve retornar o texto puro se não for JSON');
end;

procedure TTestLLMBase.TestSend_AutoAddAssistantResponse;
var
  LResponse: string;
begin
  FProvider.AutoAddAssistantResponse := True;
  FProvider.AddUser('Qual é a capital do Brasil?');
  FProvider.SetMockResponse('A capital do Brasil é Brasília.');

  LResponse := FProvider.Send;

  CheckEquals('A capital do Brasil é Brasília.', LResponse,
    'Resposta retornada deve ser a do mock');
  CheckEquals(2, FProvider.Messages.Count,
    'Deve conter a pergunta do usuário e a resposta automática do assistente');
  CheckEquals('assistant', GetMessageProperty(1, 'role'));
  CheckEquals('A capital do Brasil é Brasília.',
    GetMessageProperty(1, 'content'));
end;

procedure TTestLLMBase.TestSend_WithoutAutoAddAssistantResponse;
var
  LResponse: string;
begin
  FProvider.AutoAddAssistantResponse := False;
  FProvider.AddUser('Olá');
  FProvider.SetMockResponse('Oi!');

  LResponse := FProvider.Send;

  CheckEquals('Oi!', LResponse);
  CheckEquals(1, FProvider.Messages.Count,
    'Com AutoAddAssistantResponse=False não deve anexar ao histórico');
  CheckEquals('user', GetMessageProperty(0, 'role'));
end;

procedure TTestLLMBase.TestSend_RaisesExceptionOnError;
var
  LExRaised: Boolean;
begin
  FProvider.SetMockError(401, 'Invalid API Key');
  LExRaised := False;
  try
    try
      FProvider.Send;
    except
      on E: ELLMAPIError do
      begin
        LExRaised := True;
        CheckTrue(Pos('401', E.Message) > 0,
          'Mensagem deve conter o status code 401');
        CheckTrue(Pos('Invalid API Key', E.Message) > 0,
          'Mensagem deve conter a mensagem de erro extraída');
      end;
    end;
    CheckTrue(LExRaised,
      'Deveria ter lançado ELLMAPIError ao simular erro HTTP 401');
  finally
    FProvider.MockStatusCode := 200;
    FProvider.MockErrorMessage := EmptyStr;
  end;
end;

procedure TTestLLMBase.TestSummarizeHistory;
begin
  FProvider.HistoryStrategy := hsSummarize;
  FProvider.KeepRecentMessages := 2;
  FProvider.SetMockResponse('Resumo das decisoes anteriores');

  FProvider.AddSystem('System Instruction');
  FProvider.AddUser('Msg 1');
  FProvider.AddAssistant('Resp 1');
  FProvider.AddUser('Msg 2');
  FProvider.AddAssistant('Resp 2');
  FProvider.AddUser('Msg Recente');
  FProvider.AddAssistant('Resp Recente');

  CheckEquals(7, FProvider.Messages.Count,
    'Antes do resumo deve conter 7 mensagens');

  FProvider.SummarizeHistory;

  // Esperado:
  // Índice 0: System original
  // Índice 1: [RESUMO DO HISTORICO ANTERIOR]: ...
  // Índice 2: Msg Recente
  // Índice 3: Resp Recente
  CheckEquals(4, FProvider.Messages.Count,
    'Após resumo deve condensar para 4 mensagens (System + Resumo + 2 Recentes)');

  CheckEquals('system', GetMessageProperty(0, 'role'));
  CheckEquals('System Instruction', GetMessageProperty(0, 'content'));

  CheckEquals('system', GetMessageProperty(1, 'role'));
  CheckTrue(Pos('RESUMO DO HISTORICO ANTERIOR', GetMessageProperty(1,
    'content')) > 0, 'Deve conter cabeçalho do resumo');
  CheckTrue(Pos('Resumo das decisoes anteriores', GetMessageProperty(1,
    'content')) > 0, 'Deve conter o texto gerado pelo mock');

  CheckEquals('Msg Recente', GetMessageProperty(2, 'content'));
  CheckEquals('Resp Recente', GetMessageProperty(3, 'content'));
end;

initialization

RegisterTest(TTestLLMBase.Suite);

end.
