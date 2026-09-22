unit LLM.Factory;

interface

uses
  LLM.Interfaces;

type
  /// <summary>
  /// Tipos de provedores suportados pelo Delphi4AI
  /// </summary>
  TLLMProviderType = (
    ptOpenAI,
    ptOllama
  );

  /// <summary>
  /// Factory retrocompativel para criacao de provedores padrao (OpenAI e compativeis)
  /// </summary>
  function CreateLLMProvider(const AApiKey, ABaseURL, AModel: string): ILLMProvider; overload;

  /// <summary>
  /// Factory polimorfica para criacao de provedores com base no tipo
  /// </summary>
  function CreateLLMProvider(AProviderType: TLLMProviderType;
    const AApiKey: string = ''; const AModel: string = '';
    const ABaseURL: string = ''): ILLMProvider; overload;

  /// <summary>
  /// Factory especializada para o provedor nativo Ollama
  /// </summary>
  function CreateOllamaProvider(const AModel: string = 'llama3.2';
    const ABaseURL: string = 'http://localhost:11434/api/chat';
    const AApiKey: string = ''): IOllamaProvider;

implementation

uses
  System.SysUtils,
  LLM.Base,
  Ollama.provider;

function CreateLLMProvider(const AApiKey, ABaseURL, AModel: string): ILLMProvider;
begin
  Result := TLLMProviderBase.Create(AApiKey, ABaseURL, AModel);
end;

function CreateLLMProvider(AProviderType: TLLMProviderType;
  const AApiKey: string; const AModel: string;
  const ABaseURL: string): ILLMProvider;
var
  LModel: string;
  LKey: string;
begin
  case AProviderType of
    ptOpenAI:
      Result := TLLMProviderBase.Create(AApiKey, ABaseURL, AModel);
    ptOllama:
    begin
      LModel := AModel;
      LKey := AApiKey;
      // Conveniencia: se passou apenas 1 parametro para Ollama (ex: CreateLLMProvider(ptOllama, 'llama3.2')),
      // interpreta como sendo o modelo desejado em vez de ApiKey.
      if LModel.Trim.IsEmpty and not LKey.Trim.IsEmpty and not LKey.StartsWith('sk-', True) then
      begin
        LModel := LKey;
        LKey := EmptyStr;
      end;
      Result := TOllamaProvider.Create(LModel, ABaseURL, LKey);
    end;
  else
    Result := TLLMProviderBase.Create(AApiKey, ABaseURL, AModel);
  end;
end;

function CreateOllamaProvider(const AModel: string;
  const ABaseURL: string; const AApiKey: string): IOllamaProvider;
var
  LModel, LKey: string;
begin
  LModel := AModel;
  LKey := AApiKey;
  // Compatibilidade caso chamado na ordem (ApiKey, BaseURL, Model):
  if LModel.Trim.IsEmpty and not LKey.Trim.IsEmpty then
  begin
    LModel := LKey;
    LKey := EmptyStr;
  end;
  Result := TOllamaProvider.Create(LModel, ABaseURL, LKey);
end;

end.
