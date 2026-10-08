unit Test.Pollinations.Image.Provider;

interface

uses
  System.SysUtils,
  System.Classes,
  TestFramework,
  LLM.Image.Interfaces,
  Pollinations.Image.Provider,
  LLM.Exceptions;

type
  /// <summary>
  /// Mock do provedor Pollinations para testes sem conexao real
  /// </summary>
  TMockPollinationsImageProvider = class(TPollinationsImageProvider)
  private
    FLastRequestURL: string;
    FMockStatusCode: Integer;
    FMockBytes: TBytes;
  protected
    function ExecuteGet(const AURL: string; out ABytes: TBytes; out AMimeType: string): Integer; override;
  public
    constructor Create(const AModel: string = POLLINATIONS_DEFAULT_MODEL;
      const ABaseURL: string = POLLINATIONS_DEFAULT_URL;
      const AApiKey: string = '');

    function TestBuildRequestURL(const ARequest: TLLMImageRequest): string;

    property LastRequestURL: string read FLastRequestURL;
  end;

  /// <summary>
  /// Suite de testes unitarios para o provedor Pollinations.ai
  /// </summary>
  TTestPollinationsImageProvider = class(TTestCase)
  private
    FProvider: TMockPollinationsImageProvider;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialDefaults;
    procedure TestBuildRequestURL_Default;
    procedure TestBuildRequestURL_AspectRatios;
    procedure TestBuildRequestURL_512pxSize;
    procedure TestGenerate_Success;
    procedure TestFactory_CreateLLMImageProvider;
  end;

implementation

uses
  LLM.Factory;

{ TMockPollinationsImageProvider }

constructor TMockPollinationsImageProvider.Create(const AModel, ABaseURL, AApiKey: string);
begin
  inherited Create(AModel, ABaseURL, AApiKey);
  FLastRequestURL := EmptyStr;
  FMockStatusCode := 200;
  SetLength(FMockBytes, 16);
  FillChar(FMockBytes[0], 16, 65); // 'A'
end;

function TMockPollinationsImageProvider.ExecuteGet(const AURL: string; out ABytes: TBytes;
  out AMimeType: string): Integer;
begin
  FLastRequestURL := AURL;
  ABytes := Copy(FMockBytes);
  AMimeType := 'image/jpeg';
  Result := FMockStatusCode;

  if (Result < 200) or (Result >= 300) then
    raise ELLMAPIError.CreateFmt('Erro ao gerar imagem no Pollinations.ai (%d): Erro simulado', [Result]);
end;

function TMockPollinationsImageProvider.TestBuildRequestURL(const ARequest: TLLMImageRequest): string;
begin
  Result := BuildRequestURL(ARequest);
end;

{ TTestPollinationsImageProvider }

procedure TTestPollinationsImageProvider.SetUp;
begin
  inherited;
  FProvider := TMockPollinationsImageProvider.Create;
end;

procedure TTestPollinationsImageProvider.TearDown;
begin
  FreeAndNil(FProvider);
  inherited;
end;

procedure TTestPollinationsImageProvider.TestInitialDefaults;
begin
  CheckEquals('flux', FProvider.Model, 'Modelo padrao deve ser flux');
  CheckEquals(POLLINATIONS_DEFAULT_URL, FProvider.BaseURL);
  CheckEquals(90000, FProvider.Timeout);
end;

procedure TTestPollinationsImageProvider.TestBuildRequestURL_Default;
var
  LURL: string;
begin
  LURL := FProvider.TestBuildRequestURL(TLLMImageRequest.New('Cute cat in space'));
  CheckTrue(LURL.Contains('image.pollinations.ai/prompt/Cute%20cat%20in%20space'), 'Prompt deve ser codificado na URL');
  CheckTrue(LURL.Contains('width=1024&height=1024'), 'Dimensoes padrao devem ser 1024x1024');
  CheckTrue(LURL.Contains('model=flux'), 'Modelo deve ser flux');
  CheckTrue(LURL.Contains('nologo=true'), 'Deve conter nologo=true');
end;

procedure TTestPollinationsImageProvider.TestBuildRequestURL_AspectRatios;
var
  LURL: string;
begin
  // 16:9
  LURL := FProvider.TestBuildRequestURL(TLLMImageRequest.New('Landscape').SetAspectRatio(ar16_9));
  CheckTrue(LURL.Contains('width=1280&height=720'), 'Dimensoes para 16:9 devem ser 1280x720');

  // 9:16
  LURL := FProvider.TestBuildRequestURL(TLLMImageRequest.New('Portrait').SetAspectRatio(ar9_16));
  CheckTrue(LURL.Contains('width=720&height=1280'), 'Dimensoes para 9:16 devem ser 720x1280');

  // 4:3
  LURL := FProvider.TestBuildRequestURL(TLLMImageRequest.New('Photo').SetAspectRatio(ar4_3));
  CheckTrue(LURL.Contains('width=1024&height=768'), 'Dimensoes para 4:3 devem ser 1024x768');
end;

procedure TTestPollinationsImageProvider.TestBuildRequestURL_512pxSize;
var
  LURL: string;
begin
  LURL := FProvider.TestBuildRequestURL(TLLMImageRequest.New('Fast cat')
    .SetAspectRatio(ar1_1)
    .SetImageSize(is512px));
  CheckTrue(LURL.Contains('width=512&height=512'), 'Dimensoes para 512px devem ser 512x512');
end;

procedure TTestPollinationsImageProvider.TestGenerate_Success;
var
  LResp: ILLMImageResponse;
begin
  LResp := FProvider.Generate('Cute puppy');
  CheckNotNull(LResp);
  CheckTrue(LResp.HasImages);
  CheckEquals(1, LResp.Count);
  CheckNotNull(LResp.First);
  CheckEquals('image/jpeg', LResp.First.MimeType);
  CheckTrue(Length(LResp.First.AsBytes) > 0);
  CheckFalse(LResp.First.Base64.IsEmpty);
end;

procedure TTestPollinationsImageProvider.TestFactory_CreateLLMImageProvider;
var
  LProv: ILLMImageProvider;
begin
  LProv := CreateLLMImageProvider(ptPollinations, '', 'turbo');
  CheckNotNull(LProv);
  CheckEquals('turbo', LProv.Model);
end;

initialization
  RegisterTest(TTestPollinationsImageProvider.Suite);

end.
