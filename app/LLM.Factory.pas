unit LLM.Factory;

interface

uses
  LLM.Interfaces;

type
  /// <summary>
  /// Tipos de provedores suportados pelo Delphi4AI
  /// </summary>
  TLLMProviderType = (ptOpenAI, ptOllama, ptGroq, ptNone);

  TLLMProviderTypeHelper = record helper for TLLMProviderType
  public
    class function FromStr(const Value: string): TLLMProviderType; static;
    class function Names: TArray<string>; static;
    function ToString: string;
    function Index: Integer;
  end;

/// <summary>
/// Factory polimorfica para criacao de provedores com base no tipo
/// </summary>
function CreateLLMProvider(AProviderType: TLLMProviderType;
  const AApiKey: string = ''; const AModel: string = '';
  const ABaseURL: string = ''): ILLMProvider; overload;

/// <summary>
/// Sobrecarga para retrocompatibilidade direta com OpenAI
/// </summary>
function CreateLLMProvider(const AApiKey: string;
  const ABaseURL: string = ''; const AModel: string = ''): ILLMProvider; overload;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  LLM.Base,
  Ollama.Provider,
  Groq.Provider;

type
  TCreatorLLMProvider = function(const AApiKey, AModel, ABaseURL: string): ILLMProvider;

const
  PROVIDERS_NAMES: array [TLLMProviderType] of string = (
    'OpenAI',
    'Ollama',
    'Groq',
    ''
  );

function CreateNoneProvider(const AApiKey, AModel, ABaseURL: string): ILLMProvider;
begin
  raise EArgumentException.Create('Provedor de LLM desconhecido ou não configurado!');
end;

function CreateOpenAIProvider(const AApiKey, AModel, ABaseURL: string): ILLMProvider;
var
  LBaseURL, LModel: string;
begin
  LBaseURL := ABaseURL;
  if LBaseURL.Trim.IsEmpty then
    LBaseURL := 'https://api.openai.com/v1/chat/completions';

  LModel := AModel;
  if LModel.Trim.IsEmpty then
    LModel := 'gpt-4o-mini';

  Result := TLLMProviderBase.Create(AApiKey, LBaseURL, LModel);
end;

function CreateOllamaProvider(const AApiKey, AModel, ABaseURL: string): ILLMProvider;
var
  LModel, LKey, LBaseURL: string;
begin
  LModel := AModel;
  LKey := AApiKey;
  LBaseURL := ABaseURL;

  // Conveniencia: se passou apenas 1 parametro para Ollama (ex: CreateLLMProvider(ptOllama, 'llama3.2')),
  // interpreta como sendo o modelo desejado em vez de ApiKey.
  if LModel.Trim.IsEmpty and not LKey.Trim.IsEmpty then
  begin
    LModel := LKey;
    LKey := EmptyStr;
  end;

  if LBaseURL.Trim.IsEmpty then
    LBaseURL := 'http://localhost:11434/api/chat';

  if LModel.Trim.IsEmpty then
    LModel := 'llama3.2';

  Result := TOllamaProvider.Create(LModel, LBaseURL, LKey);
end;

function CreateGroqProvider(const AApiKey, AModel, ABaseURL: string): ILLMProvider;
var
  LBaseURL, LModel: string;
begin
  LBaseURL := ABaseURL;
  if LBaseURL.Trim.IsEmpty then
    LBaseURL := GROQ_DEFAULT_URL;

  LModel := AModel;
  if LModel.Trim.IsEmpty then
    LModel := GROQ_DEFAULT_MODEL;

  Result := TGroqProvider.Create(AApiKey, LModel, LBaseURL);
end;

const
  CREATORS: array [TLLMProviderType] of TCreatorLLMProvider = (
    CreateOpenAIProvider,
    CreateOllamaProvider,
    CreateGroqProvider,
    CreateNoneProvider
  );

function CreateLLMProvider(AProviderType: TLLMProviderType;
  const AApiKey: string; const AModel: string; const ABaseURL: string): ILLMProvider;
begin
  if (AProviderType = ptNone) or (Ord(AProviderType) > Ord(High(TLLMProviderType))) then
    raise EArgumentException.Create('Provedor de LLM não suportado ou inválido!');

  Result := CREATORS[AProviderType](AApiKey, AModel, ABaseURL);
end;

function CreateLLMProvider(const AApiKey: string;
  const ABaseURL: string; const AModel: string): ILLMProvider;
begin
  Result := CreateLLMProvider(ptOpenAI, AApiKey, AModel, ABaseURL);
end;

{ TLLMProviderTypeHelper }

class function TLLMProviderTypeHelper.FromStr(const Value: string): TLLMProviderType;
begin
  for var I := Low(PROVIDERS_NAMES) to High(PROVIDERS_NAMES) do
  begin
    if (I <> ptNone) and SameText(PROVIDERS_NAMES[I], Value.Trim) then
      Exit(I);
  end;
  Result := ptNone;
end;

function TLLMProviderTypeHelper.Index: Integer;
begin
  Result := Ord(Self);
end;

class function TLLMProviderTypeHelper.Names: TArray<string>;
var
  LCount: Integer;
begin
  LCount := 0;
  for var LType := Low(TLLMProviderType) to High(TLLMProviderType) do
  begin
    if (LType <> ptNone) and not PROVIDERS_NAMES[LType].Trim.IsEmpty then
      Inc(LCount);
  end;

  SetLength(Result, LCount);
  var LIndex := 0;
  for var LType := Low(TLLMProviderType) to High(TLLMProviderType) do
  begin
    if (LType <> ptNone) and not PROVIDERS_NAMES[LType].Trim.IsEmpty then
    begin
      Result[LIndex] := PROVIDERS_NAMES[LType];
      Inc(LIndex);
    end;
  end;
end;

function TLLMProviderTypeHelper.ToString: string;
begin
  Result := PROVIDERS_NAMES[Self];
end;

end.
