unit LLM.MockProvider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  LLM.Interfaces,
  LLM.Base;

type
  /// <summary>
  /// Provedor Mock para testes unitários, evitando requisições HTTP reais
  /// </summary>
  TMockLLMProvider = class(TLLMProviderBase)
  private
    FLastRequestBody: string;
    FMockResponseContent: string;
    FMockRawJSON: string;
    FMockStatusCode: Integer;
    FMockErrorMessage: string;
    FExecuteCount: Integer;
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

    // Métodos utilitários para expor métodos protegidos aos testes
    function TestBuildBodyJSON(const AModel: string; ATemp: Double;
      AMaxTok: Integer; AMsgs: TJSONArray): string;
    function TestExtractErrorMessage(const AErrorJSON: string): string;
    procedure TestApplySlidingWindow;
    procedure TestProcessHistory;

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
end;

function TMockLLMProvider.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LRoot, LChoice, LMsg: TJSONObject;
  LChoices: TJSONArray;
begin
  Inc(FExecuteCount);
  FLastRequestBody := ABodyJSON;

  // Se configurado para simular erro HTTP
  if FMockStatusCode <> 200 then
  begin
    ARawJSON := Format('{"error":{"message":"%s"}}', [FMockErrorMessage]);
    raise ELLMAPIError.CreateFmt('Erro API [%d]: %s',
      [FMockStatusCode, ExtractErrorMessage(ARawJSON)]);
  end;

  // Se foi fornecido um JSON bruto específico para o mock
  if not FMockRawJSON.IsEmpty then
  begin
    ARawJSON := FMockRawJSON;
    Result := FMockResponseContent;
    Exit;
  end;

  // Gera o JSON simulado de resposta no formato padrão OpenAI
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
    Result := FMockResponseContent;
  finally
    LRoot.Free;
  end;
end;

procedure TMockLLMProvider.SetMockResponse(const AAssistantContent: string);
begin
  FMockStatusCode := 200;
  FMockResponseContent := AAssistantContent;
  FMockRawJSON := EmptyStr;
end;

procedure TMockLLMProvider.SetMockRawJSON(const ARawJSON: string);
begin
  FMockStatusCode := 200;
  FMockRawJSON := ARawJSON;
end;

procedure TMockLLMProvider.SetMockError(const AStatusCode: Integer;
  const AErrorMsg: string);
begin
  FMockStatusCode := AStatusCode;
  FMockErrorMessage := AErrorMsg;
end;

function TMockLLMProvider.TestBuildBodyJSON(const AModel: string; ATemp: Double;
  AMaxTok: Integer; AMsgs: TJSONArray): string;
begin
  Result := BuildBodyJSON(AModel, ATemp, AMaxTok, AMsgs);
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
