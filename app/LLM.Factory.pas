unit LLM.Factory;

interface

uses
  LLM.Interfaces;

  function CreateLLMProvider(const AApiKey, ABaseURL, AModel: string):ILLMProvider;

implementation

uses
  LLM.Base;

function CreateLLMProvider(const AApiKey, ABaseURL, AModel: string):ILLMProvider;
begin
  Result := TLLMProviderBase.Create(AApiKey, ABaseURL, AModel)
end;

end.
