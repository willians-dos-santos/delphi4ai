unit LLM.Tools.Attributes;

interface

type
  TLLMToolAttribute = class(TCustomAttribute)
  private
    FName: string;
    FDescription: string;
  public
    constructor Create(const AName, ADescription: string);
    property Name: string read FName;
    property Description: string read FDescription;
  end;

  TLLMParamAttribute = class(TCustomAttribute)
  private
    FDescription: string;
    FRequired: Boolean;
  public
    constructor Create(const ADescription: string; ARequired: Boolean = True);
    property Description: string read FDescription;
    property Required: Boolean read FRequired;
  end;

implementation

{ TLLMToolAttribute }

constructor TLLMToolAttribute.Create(const AName, ADescription: string);
begin
  FName := AName;
  FDescription := ADescription;
end;

{ TLLMParamAttribute }

constructor TLLMParamAttribute.Create(const ADescription: string; ARequired: Boolean = True);
begin
  FDescription := ADescription;
  FRequired := ARequired;
end;

end.
