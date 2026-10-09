unit Image.Factory;

interface

uses
  Image.Interfaces;

type
  /// <summary>
  /// Provedores de geracao de imagem suportados pelo Delphi4AI
  /// </summary>
  TImageProviderType = (iptGemini, iptPollinations, iptNone);

  TImageProviderTypeHelper = record helper for TImageProviderType
  public
    class function FromStr(const Value: string): TImageProviderType; static;
    class function Names: TArray<string>; static;
    function ToString: string;
    function Index: Integer;
  end;

/// <summary>
/// Factory polimorfica para criacao de provedores de geracao de imagem
/// </summary>
function CreateImageProvider(AProviderType: TImageProviderType;
  const AApiKey: string = ''; const AModel: string = '';
  const ABaseURL: string = ''): ILLMImageProvider; overload;

/// <summary>
/// Sobrecarga/alias para compatibilidade de nomenclatura
/// </summary>
function CreateLLMImageProvider(AProviderType: TImageProviderType;
  const AApiKey: string = ''; const AModel: string = '';
  const ABaseURL: string = ''): ILLMImageProvider; overload;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Gemini.Image.Provider,
  Pollinations.Image.Provider;

const
  IMAGE_PROVIDERS_NAMES: array [TImageProviderType] of string = (
    'Gemini',
    'Pollinations',
    ''
  );

function CreateImageProvider(AProviderType: TImageProviderType;
  const AApiKey: string; const AModel: string; const ABaseURL: string): ILLMImageProvider;
begin
  case AProviderType of
    iptGemini:
      Result := TGeminiImageProvider.Create(AApiKey, AModel, ABaseURL);
    iptPollinations:
      Result := TPollinationsImageProvider.Create(AModel, ABaseURL, AApiKey);
  else
    raise EArgumentException.Create('Provedor de imagem desconhecido ou não configurado!');
  end;
end;

function CreateLLMImageProvider(AProviderType: TImageProviderType;
  const AApiKey: string; const AModel: string; const ABaseURL: string): ILLMImageProvider;
begin
  Result := CreateImageProvider(AProviderType, AApiKey, AModel, ABaseURL);
end;

{ TImageProviderTypeHelper }

class function TImageProviderTypeHelper.FromStr(const Value: string): TImageProviderType;
begin
  for var I := Low(IMAGE_PROVIDERS_NAMES) to High(IMAGE_PROVIDERS_NAMES) do
  begin
    if (I <> iptNone) and SameText(IMAGE_PROVIDERS_NAMES[I], Value.Trim) then
      Exit(I);
  end;
  Result := iptNone;
end;

function TImageProviderTypeHelper.Index: Integer;
begin
  Result := Ord(Self);
end;

class function TImageProviderTypeHelper.Names: TArray<string>;
var
  LCount: Integer;
begin
  LCount := 0;
  for var LType := Low(TImageProviderType) to High(TImageProviderType) do
  begin
    if (LType <> iptNone) and not IMAGE_PROVIDERS_NAMES[LType].Trim.IsEmpty then
      Inc(LCount);
  end;

  SetLength(Result, LCount);
  var LIndex := 0;
  for var LType := Low(TImageProviderType) to High(TImageProviderType) do
  begin
    if (LType <> iptNone) and not IMAGE_PROVIDERS_NAMES[LType].Trim.IsEmpty then
    begin
      Result[LIndex] := IMAGE_PROVIDERS_NAMES[LType];
      Inc(LIndex);
    end;
  end;
  TArray.Sort<string>(Result);
end;

function TImageProviderTypeHelper.ToString: string;
begin
  Result := IMAGE_PROVIDERS_NAMES[Self];
end;

end.
