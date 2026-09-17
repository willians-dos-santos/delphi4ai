unit LLM.MockProvider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  LLM.Interfaces,
  LLM.Tools,
  LLM.Base;

type
  /// <summary>
  /// Provedor Mock para testes unitarios, evitando requisicoes HTTP reais
  /// </summary>
  TMockLLMProvider = class(TLLMProviderBase)
  private
    FLastRequestBody: string;
    FMockResponseContent: string;
    FMockRawJSON: string;
    FMockStatusCode: Integer;
    FMockErrorMessage: string;
    FExecuteCount: Integer;
    FMockResponsesQueue: TArray<string>;
    FCurrentResponseIndex: Integer;
  protected
    function ExecuteRequest(const ABodyJSON: string; out ARawJSON: string)
      : string; override;
  public
    constructor Create(const AApiKey: string = 'test-api-key';
      const ABaseURL: string = 'https://api.mock.test/v1/chat/completions';
      const AModel: string = 'gpt-4o-mini');

    procedure SetMockResponse(const AAssistantContent: string);
    procedure SetMockRawJSON(const ARawJSON: string);
    procedure SetMockError(const AStatusCode: Integer; const AErrorMsg: string);
    procedure SetMockToolCall(const AToolId, AFuncName, AArgsJSON: string; const AContent: string = '');
    procedure SetMockResponsesQueue(const AResponses: TArray<string>);

    // Metodos utilitarios para expor metodos protegidos aos testes
    function TestBuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string;
    function TestExtractErrorMessage(const AErrorJSON: string): string;
    procedure TestApplySlidingWindow;
    procedure TestProcessHistory;
    function TestExecuteRequest(const ABodyJSON: string; out ARawJSON: string)
      : string;

    property LastRequestBody: string read FLastRequestBody;
    property MockResponseContent: string read FMockResponseContent
      write FMockResponseContent;
    property MockRawJSON: string read FMockRawJSON write FMockRawJSON;
    property MockStatusCode: Integer read FMockStatusCode write FMockStatusCode;
    property MockErrorMessage: string read FMockErrorMessage
      write FMockErrorMessage;
    property ExecuteCount: Integer read FExecuteCount;
  end;

implementation

uses
  LLM.Exceptions;

{ TMockLLMProvider }

constructor TMockLLMProvider.Create(const AApiKey, ABaseURL, AModel: string);
begin
  inherited Create(AApiKey, ABaseURL, AModel);
  FMockStatusCode := 200;
  FMockResponseContent := 'Resposta simulada do assistente';
  FMockRawJSON := EmptyStr;
  FExecuteCount := 0;
  SetLength(FMockResponsesQueue, 0);
  FCurrentResponseIndex := 0;
end;

function TMockLLMProvider.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LRoot, LChoice, LMsg: TJSONObject;
  LChoices, LToolCallsArr: TJSONArray;
  LChoicesVal, LMsgVal, LToolsVal, LFuncVal, LContentVal: TJSONValue;
  LVal: TJSONValue;
  LCallObj, LFuncObj: TJSONObject;
  LCalls: TLLMToolCallList;
  I: Integer;
  LId, LName, LArgs: string;
begin
  Inc(FExecuteCount);
  FLastRequestBody := ABodyJSON;
  Result := EmptyStr;
  ARawJSON := EmptyStr;
  SetLastToolCalls([]);

  // Se configurado para simular erro HTTP
  if FMockStatusCode <> 200 then
  begin
    ARawJSON := Format('{"error":{"message":"%s"}}', [FMockErrorMessage]);
    raise ELLMAPIError.CreateFmt('Erro API [%d]: %s',
      [FMockStatusCode, ExtractErrorMessage(ARawJSON)]);
  end;

  // Se houver uma fila de respostas mockadas para multi-turn
  if (Length(FMockResponsesQueue) > 0) and (FCurrentResponseIndex < Length(FMockResponsesQueue)) then
  begin
    ARawJSON := FMockResponsesQueue[FCurrentResponseIndex];
    Inc(FCurrentResponseIndex);
  end
  // Senao, se foi fornecido um JSON bruto especifico para o mock
  else if not FMockRawJSON.IsEmpty then
    ARawJSON := FMockRawJSON
  else
  begin
    // Gera o JSON simulado de resposta no formato padrao OpenAI
    LRoot := TJSONObject.Create;
    try
      LChoices := TJSONArray.Create;
      LRoot.AddPair('choices', LChoices);

      LChoice := TJSONObject.Create;
      LChoices.AddElement(LChoice);

      LMsg := TJSONObject.Create;
      LMsg.AddPair('role', 'assistant');
      LMsg.AddPair('content', FMockResponseContent);
      LChoice.AddPair('message', LMsg);

      ARawJSON := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
  end;

  // Realiza o mesmo parsing de TLLMProviderBase para popular FLastToolCalls e Result
  LVal := TJSONObject.ParseJSONValue(ARawJSON);
  if LVal is TJSONObject then
  begin
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
            if (LContentVal <> nil) and not(LContentVal is TJSONNull) then
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
end;

procedure TMockLLMProvider.SetMockResponse(const AAssistantContent: string);
begin
  FMockStatusCode := 200;
  FMockResponseContent := AAssistantContent;
  FMockRawJSON := EmptyStr;
  SetLength(FMockResponsesQueue, 0);
  FCurrentResponseIndex := 0;
end;

procedure TMockLLMProvider.SetMockRawJSON(const ARawJSON: string);
begin
  FMockStatusCode := 200;
  FMockRawJSON := ARawJSON;
  SetLength(FMockResponsesQueue, 0);
  FCurrentResponseIndex := 0;
end;

procedure TMockLLMProvider.SetMockError(const AStatusCode: Integer;
  const AErrorMsg: string);
begin
  FMockStatusCode := AStatusCode;
  FMockErrorMessage := AErrorMsg;
end;

procedure TMockLLMProvider.SetMockToolCall(const AToolId, AFuncName,
  AArgsJSON: string; const AContent: string);
var
  LRoot, LChoice, LMsg, LToolCall, LFunc: TJSONObject;
  LChoices, LToolCalls: TJSONArray;

begin

  LRoot := TJSONObject.Create;
  try
    LChoices := TJSONArray.Create;
    LRoot.AddPair('choices', LChoices);

    LChoice := TJSONObject.Create;
    LChoices.AddElement(LChoice);
    LChoice.AddPair('finish_reason', 'tool_calls');

    LMsg := TJSONObject.Create;
    LChoice.AddPair('message', LMsg);
    LMsg.AddPair('role', 'assistant');
    if AContent.IsEmpty then
      LMsg.AddPair('content', TJSONNull.Create)
    else
      LMsg.AddPair('content', AContent);

    LToolCalls := TJSONArray.Create;
    LMsg.AddPair('tool_calls', LToolCalls);

    LToolCall := TJSONObject.Create;
    LToolCalls.AddElement(LToolCall);
    LToolCall.AddPair('id', AToolId);
    LToolCall.AddPair('type', 'function');

    LFunc := TJSONObject.Create;
    LToolCall.AddPair('function', LFunc);
    LFunc.AddPair('name', AFuncName);
    LFunc.AddPair('arguments', AArgsJSON);

    FMockStatusCode := 200;
    FMockRawJSON := LRoot.ToJSON;
    SetLength(FMockResponsesQueue, 0);
    FCurrentResponseIndex := 0;
  finally
    LRoot.Free;
  end;
end;

procedure TMockLLMProvider.SetMockResponsesQueue(
  const AResponses: TArray<string>);
begin
  FMockStatusCode := 200;
  FMockResponsesQueue := AResponses;
  FCurrentResponseIndex := 0;
  FMockRawJSON := EmptyStr;
end;

function TMockLLMProvider.TestBuildBodyJSON(const AModel: string; ATemp: Double;
  AMaxTok: Integer; AMsgs: TJSONArray): string;
begin
  Result := BuildBodyJSON(AModel, ATemp, AMaxTok, AMsgs);
end;

function TMockLLMProvider.TestExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
begin
  Result := ExecuteRequest(ABodyJSON, ARawJSON);
end;

function TMockLLMProvider.TestExtractErrorMessage(const AErrorJSON
  : string): string;
begin
  Result := ExtractErrorMessage(AErrorJSON);
end;

procedure TMockLLMProvider.TestApplySlidingWindow;
begin
  ApplySlidingWindow;
end;

procedure TMockLLMProvider.TestProcessHistory;
begin
  ProcessHistory;
end;

end.