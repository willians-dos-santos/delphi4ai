unit Pollinations.Image.Provider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.NetEncoding,
  Image.Interfaces,
  LLM.Exceptions;

const
  POLLINATIONS_DEFAULT_URL = 'https://image.pollinations.ai/prompt';
  POLLINATIONS_DEFAULT_MODEL = 'flux';

  POLLINATIONS_MODEL_FLUX = 'flux';
  POLLINATIONS_MODEL_TURBO = 'turbo';
  POLLINATIONS_MODEL_REALISM = 'flux-realism';
  POLLINATIONS_MODEL_ANIME = 'flux-anime';
  POLLINATIONS_MODEL_3D = 'flux-3d';

type
  /// <summary>
  /// Provedor gratuito e publico para geracao de imagens via Pollinations.ai (FLUX.1 / Turbo)
  /// Nao exige cadastro nem chave de API.
  /// </summary>
  TPollinationsImageProvider = class(TInterfacedObject, ILLMImageProvider)
  private
    FApiKey: string;
    FBaseURL: string;
    FModel: string;
    FTimeout: Integer;
    FHttpClient: THTTPClient;

    function GetApiKey: string;
    procedure SetApiKey(const Value: string);
    function GetBaseURL: string;
    procedure SetBaseURL(const Value: string);
    function GetModel: string;
    procedure SetModel(const Value: string);
    function GetTimeout: Integer;
    procedure SetTimeout(const Value: Integer);

    procedure CalcularDimensoes(const AAspect: TLLMImageAspectRatio;
      const ASize: TLLMImageSize; out AWidth, AHeight: Integer);
  protected
    function BuildRequestURL(const ARequest: TLLMImageRequest): string; virtual;
    function ExecuteGet(const AURL: string; out ABytes: TBytes; out AMimeType: string): Integer; virtual;
  public
    constructor Create(const AModel: string = POLLINATIONS_DEFAULT_MODEL;
      const ABaseURL: string = POLLINATIONS_DEFAULT_URL;
      const AApiKey: string = '');
    destructor Destroy; override;

    function Generate(const APrompt: string): ILLMImageResponse; overload;
    function Generate(const ARequest: TLLMImageRequest): ILLMImageResponse; overload;

    property ApiKey: string read GetApiKey write SetApiKey;
    property BaseURL: string read GetBaseURL write SetBaseURL;
    property Model: string read GetModel write SetModel;
    property Timeout: Integer read GetTimeout write SetTimeout;
  end;

implementation

{ TPollinationsImageProvider }

constructor TPollinationsImageProvider.Create(const AModel, ABaseURL, AApiKey: string);
begin
  inherited Create;
  FApiKey := AApiKey.Trim;

  FModel := AModel.Trim;
  if FModel.IsEmpty then
    FModel := POLLINATIONS_DEFAULT_MODEL;

  FBaseURL := ABaseURL.Trim;
  if FBaseURL.IsEmpty then
    FBaseURL := POLLINATIONS_DEFAULT_URL;

  // Timeout padrao de 90 segundos
  FTimeout := 90000;
  FHttpClient := THTTPClient.Create;
end;

destructor TPollinationsImageProvider.Destroy;
begin
  FHttpClient.Free;
  inherited Destroy;
end;

function TPollinationsImageProvider.GetApiKey: string;
begin
  Result := FApiKey;
end;

procedure TPollinationsImageProvider.SetApiKey(const Value: string);
begin
  FApiKey := Value.Trim;
end;

function TPollinationsImageProvider.GetBaseURL: string;
begin
  Result := FBaseURL;
end;

procedure TPollinationsImageProvider.SetBaseURL(const Value: string);
begin
  FBaseURL := Value.Trim;
  if FBaseURL.IsEmpty then
    FBaseURL := POLLINATIONS_DEFAULT_URL;
end;

function TPollinationsImageProvider.GetModel: string;
begin
  Result := FModel;
end;

procedure TPollinationsImageProvider.SetModel(const Value: string);
begin
  FModel := Value.Trim;
  if FModel.IsEmpty then
    FModel := POLLINATIONS_DEFAULT_MODEL;
end;

function TPollinationsImageProvider.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TPollinationsImageProvider.SetTimeout(const Value: Integer);
begin
  FTimeout := Value;
end;

procedure TPollinationsImageProvider.CalcularDimensoes(const AAspect: TLLMImageAspectRatio;
  const ASize: TLLMImageSize; out AWidth, AHeight: Integer);
begin
  // Dimensoes base 1K (1024)
  case AAspect of
    ar16_9:
    begin
      AWidth := 1280;
      AHeight := 720;
    end;
    ar9_16:
    begin
      AWidth := 720;
      AHeight := 1280;
    end;
    ar3_2:
    begin
      AWidth := 1080;
      AHeight := 720;
    end;
    ar2_3:
    begin
      AWidth := 720;
      AHeight := 1080;
    end;
    ar4_3:
    begin
      AWidth := 1024;
      AHeight := 768;
    end;
    ar3_4:
    begin
      AWidth := 768;
      AHeight := 1024;
    end;
    ar4_5:
    begin
      AWidth := 816;
      AHeight := 1020;
    end;
    ar5_4:
    begin
      AWidth := 1020;
      AHeight := 816;
    end;
    ar21_9:
    begin
      AWidth := 1344;
      AHeight := 576;
    end;
  else
    // ar1_1 e arDefault
    AWidth := 1024;
    AHeight := 1024;
  end;

  // Ajusta proporcionalmente para 512px se requisitado
  if ASize = is512px then
  begin
    AWidth := AWidth div 2;
    AHeight := AHeight div 2;
  end;
end;

function TPollinationsImageProvider.BuildRequestURL(const ARequest: TLLMImageRequest): string;
var
  LBase, LPrompt, LModel: string;
  LWidth, LHeight: Integer;
begin
  LBase := FBaseURL.TrimRight(['/']);
  LModel := ARequest.Model.Trim;
  if LModel.IsEmpty then
    LModel := FModel;

  CalcularDimensoes(ARequest.AspectRatio, ARequest.ImageSize, LWidth, LHeight);

  LPrompt := TURI.URLEncode(ARequest.Prompt.Trim);

  Result := Format('%s/%s?width=%d&height=%d&model=%s&nologo=true', [
    LBase,
    LPrompt,
    LWidth,
    LHeight,
    LModel
  ]);
end;

function TPollinationsImageProvider.ExecuteGet(const AURL: string; out ABytes: TBytes;
  out AMimeType: string): Integer;
var
  LResp: IHTTPResponse;
  LStream: TMemoryStream;
begin
  SetLength(ABytes, 0);
  AMimeType := 'image/jpeg';

  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;

  if not FApiKey.IsEmpty then
    FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;

  LStream := TMemoryStream.Create;
  try
    LResp := FHttpClient.Get(AURL, LStream);
    Result := LResp.StatusCode;

    if Result = 402 then
      raise ELLMAPIError.Create(
        'O Pollinations.ai exige autenticação para prompts não cacheados (Erro 402: Payment Required).'#13#10#13#10 +
        'Como gerar imagens ilimitadas gratuitamente (sem cartão):'#13#10 +
        '1. Acesse https://enter.pollinations.ai'#13#10 +
        '2. Faça login com sua conta do GitHub para gerar uma API Key gratuita'#13#10 +
        '3. Cole a chave no campo "API Key" do aplicativo.');

    if (Result < 200) or (Result >= 300) then
      raise ELLMAPIError.CreateFmt('Erro ao gerar imagem no Pollinations.ai (%d): %s',
        [Result, LResp.StatusText]);

    AMimeType := LResp.HeaderValue['Content-Type'];
    if AMimeType.IsEmpty then
      AMimeType := 'image/jpeg';

    if AMimeType.Contains(';') then
      AMimeType := AMimeType.Substring(0, AMimeType.IndexOf(';')).Trim;

    SetLength(ABytes, LStream.Size);
    if LStream.Size > 0 then
    begin
      LStream.Position := 0;
      LStream.ReadBuffer(ABytes[0], LStream.Size);
    end;
  finally
    LStream.Free;
  end;
end;

function TPollinationsImageProvider.Generate(const APrompt: string): ILLMImageResponse;
begin
  Result := Generate(TLLMImageRequest.New(APrompt));
end;

function TPollinationsImageProvider.Generate(const ARequest: TLLMImageRequest): ILLMImageResponse;
var
  LURL, LMime, LBase64: string;
  LBytes: TBytes;
  LImages: TArray<ILLMImageItem>;
begin
  LURL := BuildRequestURL(ARequest);
  ExecuteGet(LURL, LBytes, LMime);

  LBase64 := TNetEncoding.Base64.EncodeBytesToString(LBytes);
  LBase64 := LBase64.Replace(#13, '').Replace(#10, '');

  SetLength(LImages, 1);
  LImages[0] := TLLMImageItem.Create(LBase64, LMime);

  Result := TLLMImageResponse.Create(Format('{"url":"%s"}', [LURL]), LImages, '', '');
end;

end.
