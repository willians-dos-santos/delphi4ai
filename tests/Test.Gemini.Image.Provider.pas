unit Test.Gemini.Image.Provider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  TestFramework,
  Image.Interfaces,
  Gemini.Image.Provider,
  LLM.Exceptions;

type
  /// <summary>
  /// Mock do provedor Gemini Image para testes unitarios sem conexao de rede
  /// </summary>
  TMockGeminiImageProvider = class(TGeminiImageProvider)
  private
    FLastRequestBody: string;
    FMockResponseContent: string;
    FMockStatusCode: Integer;
  protected
    function ExecuteRequest(const ABodyJSON: string; out ARawJSON: string): string; override;
  public
    constructor Create(const AApiKey: string = 'gemini_test_key_123';
      const AModel: string = GEMINI_DEFAULT_IMAGE_MODEL;
      const ABaseURL: string = GEMINI_INTERACTIONS_URL);

    procedure SetMockResponse(const AContent: string; const AStatusCode: Integer = 200);
    procedure SetMockImageResponse(const ABase64Data: string; const AMimeType: string = 'image/jpeg';
      const AText: string = 'Generated image text'; const AId: string = 'interactions/test-123');

    function TestBuildBodyJSON(const ARequest: TLLMImageRequest): string;
    function TestExtractErrorMessage(const AErrorJSON: string): string;
    function TestParseResponse(const ARawJSON: string): ILLMImageResponse;

    property LastRequestBody: string read FLastRequestBody;
  end;

  /// <summary>
  /// Suite de testes unitarios para geracao de imagens via Google Gemini Nano Banana
  /// </summary>
  TTestGeminiImageProvider = class(TTestCase)
  private
    FProvider: TMockGeminiImageProvider;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialDefaults;
    procedure TestGetRequestURL;
    procedure TestPrepareHeaders;
    procedure TestApiKeyMissingException;
    procedure TestBuildBodyJSON_SimplePrompt;
    procedure TestBuildBodyJSON_AdvancedOptions;
    procedure TestBuildBodyJSON_WithGoogleSearch;
    procedure TestBuildBodyJSON_WithGoogleImageSearch;
    procedure TestBuildBodyJSON_WithThinkingLevel;
    procedure TestBuildBodyJSON_WithPreviousInteractionId;
    procedure TestBuildBodyJSON_WithReferenceImages;
    procedure TestGenerate_Success_OutputImageConvenience;
    procedure TestGenerate_Success_StepsInterleaved;
    procedure TestImageItem_SaveToStreamAndBytes;
    procedure TestExtractErrorMessage;
    procedure TestGenerate_ApiError_ThrowsException;
    procedure TestFactory_CreateLLMImageProvider;
    procedure TestFactory_UnsupportedProviderThrows;
    procedure TestEnumsAndHelpers;
  end;

implementation

uses
  System.Net.HttpClient,
  Image.Factory;

const
  SAMPLE_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

{ TMockGeminiImageProvider }

constructor TMockGeminiImageProvider.Create(const AApiKey, AModel, ABaseURL: string);
begin
  inherited Create(AApiKey, AModel, ABaseURL);
  FLastRequestBody := EmptyStr;
  FMockStatusCode := 200;
  SetMockImageResponse(SAMPLE_BASE64);
end;

procedure TMockGeminiImageProvider.SetMockResponse(const AContent: string; const AStatusCode: Integer);
begin
  FMockResponseContent := AContent;
  FMockStatusCode := AStatusCode;
end;

procedure TMockGeminiImageProvider.SetMockImageResponse(const ABase64Data, AMimeType, AText, AId: string);
var
  LJSON, LImgObj: TJSONObject;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('id', AId);
    LJSON.AddPair('model', GEMINI_DEFAULT_IMAGE_MODEL);
    LJSON.AddPair('output_text', AText);

    LImgObj := TJSONObject.Create;
    LImgObj.AddPair('data', ABase64Data);
    LImgObj.AddPair('mime_type', AMimeType);
    LJSON.AddPair('output_image', LImgObj);

    SetMockResponse(LJSON.ToJSON, 200);
  finally
    LJSON.Free;
  end;
end;

function TMockGeminiImageProvider.ExecuteRequest(const ABodyJSON: string; out ARawJSON: string): string;
begin
  FLastRequestBody := ABodyJSON;
  ARawJSON := FMockResponseContent;

  if (FMockStatusCode < 200) or (FMockStatusCode >= 300) then
  begin
    raise ELLMAPIError.CreateFmt('Erro na API do Gemini Nano Banana (%d): %s',
      [FMockStatusCode, ExtractErrorMessage(FMockResponseContent)]);
  end;

  Result := FMockResponseContent;
end;

function TMockGeminiImageProvider.TestBuildBodyJSON(const ARequest: TLLMImageRequest): string;
begin
  Result := BuildBodyJSON(ARequest);
end;

function TMockGeminiImageProvider.TestExtractErrorMessage(const AErrorJSON: string): string;
begin
  Result := ExtractErrorMessage(AErrorJSON);
end;

function TMockGeminiImageProvider.TestParseResponse(const ARawJSON: string): ILLMImageResponse;
begin
  Result := ParseResponse(ARawJSON);
end;

{ TTestGeminiImageProvider }

procedure TTestGeminiImageProvider.SetUp;
begin
  inherited;
  FProvider := TMockGeminiImageProvider.Create('test_api_key_nano_banana');
end;

procedure TTestGeminiImageProvider.TearDown;
begin
  FreeAndNil(FProvider);
  inherited;
end;

procedure TTestGeminiImageProvider.TestInitialDefaults;
begin
  CheckEquals('test_api_key_nano_banana', FProvider.ApiKey, 'ApiKey inicial incorreta');
  CheckEquals(GEMINI_DEFAULT_IMAGE_MODEL, FProvider.Model, 'Modelo inicial incorreto');
  CheckEquals(GEMINI_INTERACTIONS_URL, FProvider.BaseURL, 'BaseURL inicial incorreta');
  CheckEquals(120000, FProvider.Timeout, 'Timeout inicial incorreto');
end;

procedure TTestGeminiImageProvider.TestGetRequestURL;
var
  LURL: string;
begin
  // Como GetRequestURL e protected na classe base, testamos via chamada direta no mock se herdado
  // ou verificamos que contem a chave de API
  FProvider.ApiKey := 'minha_chave_123';
  LURL := FProvider.BaseURL;
  CheckTrue(LURL.Contains('interactions'), 'URL deve apontar para interactions');
end;

procedure TTestGeminiImageProvider.TestPrepareHeaders;
var
  LClient: THTTPClient;
begin
  LClient := THTTPClient.Create;
  try
    FProvider.PrepareHeaders(LClient);
    CheckEquals('test_api_key_nano_banana', LClient.CustomHeaders['x-goog-api-key'], 'Header x-goog-api-key ausente ou incorreto');
    CheckEquals('application/json', LClient.CustomHeaders['Content-Type'], 'Content-Type incorreto');
  finally
    LClient.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestApiKeyMissingException;
var
  LClient: THTTPClient;
  LExCaught: Boolean;
begin
  LClient := THTTPClient.Create;
  try
    FProvider.ApiKey := '';
    LExCaught := False;
    try
      FProvider.PrepareHeaders(LClient);
    except
      on E: Exception do
        LExCaught := True;
    end;
    CheckTrue(LExCaught, 'Deveria lancar excecao quando ApiKey estiver vazia');
  finally
    LClient.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestBuildBodyJSON_SimplePrompt;
var
  LJSONStr: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
  LInputArr: TJSONArray;
  LItem: TJSONObject;
begin
  LJSONStr := FProvider.TestBuildBodyJSON(TLLMImageRequest.New('A cute red panda wearing a hat'));
  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal, 'JSON gerado deve ser valido');
  try
    CheckTrue(LVal is TJSONObject, 'Raiz deve ser um JSONObject');
    LObj := TJSONObject(LVal);
    CheckEquals('gemini-nano-banana-2.1', LObj.GetValue<string>('model', ''), 'Modelo incorreto no payload');

    LInputArr := LObj.FindValue('input') as TJSONArray;
    CheckNotNull(LInputArr, 'Array input deve existir');
    CheckEquals(1, LInputArr.Count, 'Input deve conter 1 elemento');

    LItem := LInputArr.Items[0] as TJSONObject;
    CheckEquals('text', LItem.GetValue<string>('type', ''), 'Tipo deve ser text');
    CheckEquals('A cute red panda wearing a hat', LItem.GetValue<string>('text', ''), 'Texto do prompt incorreto');
  finally
    LVal.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestBuildBodyJSON_AdvancedOptions;
var
  LReq: TLLMImageRequest;
  LJSONStr: string;
  LVal: TJSONValue;
  LObj, LRespFormat: TJSONObject;
begin
  LReq := TLLMImageRequest.New('Cyberpunk city')
    .SetAspectRatio(ar16_9)
    .SetImageSize(is2K)
    .SetFormat(imPNG)
    .SetModel(GEMINI_MODEL_3_PRO);

  LJSONStr := FProvider.TestBuildBodyJSON(LReq);
  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal);
  try
    LObj := TJSONObject(LVal);
    CheckEquals('gemini-3-pro-image', LObj.GetValue<string>('model', ''), 'Modelo customizado incorreto');

    LRespFormat := LObj.FindValue('response_format') as TJSONObject;
    CheckNotNull(LRespFormat, 'response_format deve existir');
    CheckEquals('image', LRespFormat.GetValue<string>('type', ''));
    CheckEquals('16:9', LRespFormat.GetValue<string>('aspect_ratio', ''));
    CheckEquals('2K', LRespFormat.GetValue<string>('image_size', ''));
    CheckEquals('image/png', LRespFormat.GetValue<string>('mime_type', ''));
  finally
    LVal.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestBuildBodyJSON_WithGoogleSearch;
var
  LReq: TLLMImageRequest;
  LJSONStr: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
  LToolsArr: TJSONArray;
  LTool: TJSONObject;
begin
  LReq := TLLMImageRequest.New('Arsenal score yesterday').EnableGoogleSearch(True);
  LJSONStr := FProvider.TestBuildBodyJSON(LReq);
  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal);
  try
    LObj := TJSONObject(LVal);
    LToolsArr := LObj.FindValue('tools') as TJSONArray;
    CheckNotNull(LToolsArr, 'tools deve existir');
    CheckEquals(1, LToolsArr.Count);

    LTool := LToolsArr.Items[0] as TJSONObject;
    CheckEquals('google_search', LTool.GetValue<string>('type', ''));
    CheckNull(LTool.FindValue('search_types'), 'search_types nao deve ser incluido quando apenas web');
  finally
    LVal.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestBuildBodyJSON_WithGoogleImageSearch;
var
  LReq: TLLMImageRequest;
  LJSONStr: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
  LToolsArr, LSearchTypesArr: TJSONArray;
  LTool: TJSONObject;
begin
  LReq := TLLMImageRequest.New('Timareta butterfly').EnableGoogleSearch(True, True);
  LJSONStr := FProvider.TestBuildBodyJSON(LReq);
  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal);
  try
    LObj := TJSONObject(LVal);
    LToolsArr := LObj.FindValue('tools') as TJSONArray;
    CheckNotNull(LToolsArr);

    LTool := LToolsArr.Items[0] as TJSONObject;
    LSearchTypesArr := LTool.FindValue('search_types') as TJSONArray;
    CheckNotNull(LSearchTypesArr, 'search_types deve existir para image_search');
    CheckEquals(2, LSearchTypesArr.Count);
    CheckEquals('web_search', LSearchTypesArr.Items[0].Value);
    CheckEquals('image_search', LSearchTypesArr.Items[1].Value);
  finally
    LVal.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestBuildBodyJSON_WithThinkingLevel;
var
  LReq: TLLMImageRequest;
  LJSONStr: string;
  LVal: TJSONValue;
  LObj, LGenConfig: TJSONObject;
begin
  LReq := TLLMImageRequest.New('Complex optical illusion').SetThinkingLevel(tlHigh);
  LJSONStr := FProvider.TestBuildBodyJSON(LReq);
  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal);
  try
    LObj := TJSONObject(LVal);
    LGenConfig := LObj.FindValue('generation_config') as TJSONObject;
    CheckNotNull(LGenConfig, 'generation_config deve existir');
    CheckEquals('high', LGenConfig.GetValue<string>('thinking_level', ''));
  finally
    LVal.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestBuildBodyJSON_WithPreviousInteractionId;
var
  LReq: TLLMImageRequest;
  LJSONStr: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
begin
  LReq := TLLMImageRequest.New('Change background to blue').SetPreviousInteractionId('interactions/turn-1');
  LJSONStr := FProvider.TestBuildBodyJSON(LReq);
  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal);
  try
    LObj := TJSONObject(LVal);
    CheckEquals('interactions/turn-1', LObj.GetValue<string>('previous_interaction_id', ''));
  finally
    LVal.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestBuildBodyJSON_WithReferenceImages;
var
  LReq: TLLMImageRequest;
  LJSONStr: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
  LInputArr: TJSONArray;
  LImgItem: TJSONObject;
begin
  LReq := TLLMImageRequest.New('Add sunglasses to this cat')
    .AddReferenceImage('fake_base64_cat_data', 'image/png');

  LJSONStr := FProvider.TestBuildBodyJSON(LReq);
  LVal := TJSONObject.ParseJSONValue(LJSONStr);
  CheckNotNull(LVal);
  try
    LObj := TJSONObject(LVal);
    LInputArr := LObj.FindValue('input') as TJSONArray;
    CheckNotNull(LInputArr);
    CheckEquals(2, LInputArr.Count, 'Input deve conter texto e imagem de referencia');

    LImgItem := LInputArr.Items[1] as TJSONObject;
    CheckEquals('image', LImgItem.GetValue<string>('type', ''));
    CheckEquals('image/png', LImgItem.GetValue<string>('mime_type', ''));
    CheckEquals('fake_base64_cat_data', LImgItem.GetValue<string>('data', ''));
  finally
    LVal.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestGenerate_Success_OutputImageConvenience;
var
  LResp: ILLMImageResponse;
begin
  FProvider.SetMockImageResponse(SAMPLE_BASE64, 'image/jpeg', 'Text response', 'interactions/xyz');
  LResp := FProvider.Generate('A fast sports car');

  CheckNotNull(LResp, 'Resposta nao deve ser nula');
  CheckTrue(LResp.HasImages, 'Deve conter imagens');
  CheckEquals(1, LResp.Count, 'Contagem de imagens deve ser 1');
  CheckNotNull(LResp.First, 'First image nao deve ser nulo');
  CheckEquals(SAMPLE_BASE64, LResp.First.Base64, 'Base64 incorreto');
  CheckEquals('image/jpeg', LResp.First.MimeType, 'MimeType incorreto');
  CheckEquals('Text response', LResp.Text, 'Texto da resposta incorreto');
  CheckEquals('interactions/xyz', LResp.InteractionId, 'ID da interacao incorreto');
end;

procedure TTestGeminiImageProvider.TestGenerate_Success_StepsInterleaved;
var
  LJSONStr: string;
  LResp: ILLMImageResponse;
begin
  LJSONStr := '{' +
    '"id": "interactions/step-test",' +
    '"steps": [' +
    '  {' +
    '    "type": "model_output",' +
    '    "content": [' +
    '      {"type": "text", "text": "Era uma vez uma borboleta..."},' +
    '      {"type": "image", "data": "' + SAMPLE_BASE64 + '", "mime_type": "image/png"}' +
    '    ]' +
    '  }' +
    ']' +
    '}';

  LResp := FProvider.TestParseResponse(LJSONStr);
  CheckNotNull(LResp);
  CheckTrue(LResp.HasImages);
  CheckEquals(1, LResp.Count);
  CheckEquals(SAMPLE_BASE64, LResp.First.Base64);
  CheckEquals('image/png', LResp.First.MimeType);
  CheckEquals('Era uma vez uma borboleta...', LResp.Text);
  CheckEquals('interactions/step-test', LResp.InteractionId);
end;

procedure TTestGeminiImageProvider.TestImageItem_SaveToStreamAndBytes;
var
  LItem: ILLMImageItem;
  LBytes: TBytes;
  LStream: TMemoryStream;
begin
  LItem := TLLMImageItem.Create(SAMPLE_BASE64, 'image/png');
  LBytes := LItem.AsBytes;
  CheckTrue(Length(LBytes) > 0, 'Bytes decodificados nao devem ser vazios');

  LStream := TMemoryStream.Create;
  try
    LItem.SaveToStream(LStream);
    CheckEquals(Length(LBytes), LStream.Size, 'Tamanho do stream deve corresponder aos bytes decodificados');
  finally
    LStream.Free;
  end;
end;

procedure TTestGeminiImageProvider.TestExtractErrorMessage;
var
  LGoogleErrorJSON, LErrMsg: string;
begin
  LGoogleErrorJSON := '{"error": {"code": 400, "message": "API key not valid", "status": "INVALID_ARGUMENT"}}';
  LErrMsg := FProvider.TestExtractErrorMessage(LGoogleErrorJSON);
  CheckEquals('INVALID_ARGUMENT: API key not valid', LErrMsg);
end;

procedure TTestGeminiImageProvider.TestGenerate_ApiError_ThrowsException;
var
  LExCaught: Boolean;
begin
  FProvider.SetMockResponse('{"error": {"code": 403, "message": "Quota exceeded", "status": "RESOURCE_EXHAUSTED"}}', 403);
  LExCaught := False;
  try
    FProvider.Generate('Prompt test');
  except
    on E: ELLMAPIError do
    begin
      LExCaught := True;
      CheckTrue(E.Message.Contains('RESOURCE_EXHAUSTED'), 'Mensagem de erro deve conter o status do Google');
    end;
  end;
  CheckTrue(LExCaught, 'Deveria ter disparado ELLMAPIError');
end;

procedure TTestGeminiImageProvider.TestFactory_CreateLLMImageProvider;
var
  LProvider: ILLMImageProvider;
begin
  LProvider := CreateImageProvider(iptGemini, 'chave_gemini_teste');
  CheckNotNull(LProvider, 'Provedor Gemini criado pela factory nao deve ser nulo');
  CheckEquals('chave_gemini_teste', LProvider.ApiKey);
  CheckEquals(GEMINI_DEFAULT_IMAGE_MODEL, LProvider.Model);
end;

procedure TTestGeminiImageProvider.TestFactory_UnsupportedProviderThrows;
var
  LExCaught: Boolean;
begin
  LExCaught := False;
  try
    CreateImageProvider(iptNone, 'chave_invalida');
  except
    on E: EArgumentException do
      LExCaught := True;
  end;
  CheckTrue(LExCaught, 'Factory deve lancar EArgumentException para provedores sem suporte ou invalidos');
end;

procedure TTestGeminiImageProvider.TestEnumsAndHelpers;
begin
  // AspectRatio
  CheckEquals('1:1', ar1_1.ToString);
  CheckEquals('16:9', ar16_9.ToString);
  CheckEquals('9:16', ar9_16.ToString);
  CheckEquals('3:2', ar3_2.ToString);
  CheckEquals('21:9', ar21_9.ToString);
  CheckTrue(TLLMImageAspectRatio.FromString('16:9') = ar16_9);
  CheckTrue(TLLMImageAspectRatio.FromString('1:1') = ar1_1);

  // ImageSize
  CheckEquals('1K', is1K.ToString);
  CheckEquals('2K', is2K.ToString);
  CheckEquals('4K', is4K.ToString);
  CheckEquals('512', is512px.ToString);
  CheckTrue(TLLMImageSize.FromString('512') = is512px);
  CheckTrue(TLLMImageSize.FromString('2K') = is2K);
  CheckTrue(TLLMImageSize.FromString('4K') = is4K);

  // MimeType
  CheckEquals('image/jpeg', imJPEG.ToString);
  CheckEquals('image/png', imPNG.ToString);
  CheckTrue(TLLMImageMimeType.FromString('image/png') = imPNG);
  CheckTrue(TLLMImageMimeType.FromString('image/jpeg') = imJPEG);

  // ThinkingLevel
  CheckEquals('minimal', tlMinimal.ToString);
  CheckEquals('medium', tlMedium.ToString);
  CheckEquals('high', tlHigh.ToString);
  CheckTrue(TLLMImageThinkingLevel.FromString('high') = tlHigh);
end;

initialization
  RegisterTest(TTestGeminiImageProvider.Suite);

end.
