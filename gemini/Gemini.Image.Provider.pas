unit Gemini.Image.Provider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.URLClient,
  System.Net.HttpClient,
  LLM.Image.Interfaces,
  LLM.Exceptions;

const
  GEMINI_INTERACTIONS_URL = 'https://generativelanguage.googleapis.com/v1beta/interactions';
  GEMINI_DEFAULT_IMAGE_MODEL = 'gemini-nano-banana-2.1';

  // Constantes com os nomes oficiais dos modelos Nano Banana
  GEMINI_MODEL_NANO_BANANA_2_1 = 'gemini-nano-banana-2.1';
  GEMINI_MODEL_3_1_FLASH_LITE  = 'gemini-3.1-flash-lite-image';
  GEMINI_MODEL_3_1_FLASH       = 'gemini-3.1-flash-image';
  GEMINI_MODEL_3_PRO           = 'gemini-3-pro-image';
  GEMINI_MODEL_2_5_FLASH       = 'gemini-2.5-flash-image';

type
  /// <summary>
  /// Provedor nativo para geracao e edicao de imagens via Google Gemini Nano Banana (Interactions API)
  /// </summary>
  TGeminiImageProvider = class(TInterfacedObject, ILLMImageProvider)
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
  protected
    procedure PrepareHeaders(AClient: THTTPClient); virtual;
    function GetRequestURL: string; virtual;
    function BuildBodyJSON(const ARequest: TLLMImageRequest): string; virtual;
    function ExtractErrorMessage(const AErrorJSON: string): string; virtual;
    function ExecuteRequest(const ABodyJSON: string; out ARawJSON: string): string; virtual;
    function ParseResponse(const ARawJSON: string): ILLMImageResponse; virtual;
  public
    constructor Create(const AApiKey: string;
      const AModel: string = GEMINI_DEFAULT_IMAGE_MODEL;
      const ABaseURL: string = GEMINI_INTERACTIONS_URL);
    destructor Destroy; override;

    function Generate(const APrompt: string): ILLMImageResponse; overload;
    function Generate(const ARequest: TLLMImageRequest): ILLMImageResponse; overload;

    property ApiKey: string read GetApiKey write SetApiKey;
    property BaseURL: string read GetBaseURL write SetBaseURL;
    property Model: string read GetModel write SetModel;
    property Timeout: Integer read GetTimeout write SetTimeout;
  end;

implementation

{ TGeminiImageProvider }

constructor TGeminiImageProvider.Create(const AApiKey, AModel, ABaseURL: string);
begin
  inherited Create;
  FApiKey := AApiKey.Trim;

  FModel := AModel.Trim;
  if FModel.IsEmpty then
    FModel := GEMINI_DEFAULT_IMAGE_MODEL;

  FBaseURL := ABaseURL.Trim;
  if FBaseURL.IsEmpty then
    FBaseURL := GEMINI_INTERACTIONS_URL;

  // Timeout padrao de 120 segundos para geracao de imagens
  FTimeout := 120000;

  FHttpClient := THTTPClient.Create;
end;

destructor TGeminiImageProvider.Destroy;
begin
  FHttpClient.Free;
  inherited Destroy;
end;

function TGeminiImageProvider.GetApiKey: string;
begin
  Result := FApiKey;
end;

procedure TGeminiImageProvider.SetApiKey(const Value: string);
begin
  FApiKey := Value.Trim;
end;

function TGeminiImageProvider.GetBaseURL: string;
begin
  Result := FBaseURL;
end;

procedure TGeminiImageProvider.SetBaseURL(const Value: string);
begin
  FBaseURL := Value.Trim;
  if FBaseURL.IsEmpty then
    FBaseURL := GEMINI_INTERACTIONS_URL;
end;

function TGeminiImageProvider.GetModel: string;
begin
  Result := FModel;
end;

procedure TGeminiImageProvider.SetModel(const Value: string);
begin
  FModel := Value.Trim;
  if FModel.IsEmpty then
    FModel := GEMINI_DEFAULT_IMAGE_MODEL;
end;

function TGeminiImageProvider.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TGeminiImageProvider.SetTimeout(const Value: Integer);
begin
  FTimeout := Value;
end;

procedure TGeminiImageProvider.PrepareHeaders(AClient: THTTPClient);
begin
  if FApiKey.IsEmpty then
    raise Exception.Create('Gemini API Key não informada. Forneça uma chave de API válida.');

  AClient.CustomHeaders['x-goog-api-key'] := FApiKey;
  AClient.CustomHeaders['Content-Type'] := 'application/json';
end;

function TGeminiImageProvider.GetRequestURL: string;
var
  LURL: string;
begin
  LURL := FBaseURL;
  if not FApiKey.IsEmpty and not LURL.Contains('key=') then
  begin
    if LURL.Contains('?') then
      LURL := LURL + '&key=' + FApiKey
    else
      LURL := LURL + '?key=' + FApiKey;
  end;
  Result := LURL;
end;

function TGeminiImageProvider.BuildBodyJSON(const ARequest: TLLMImageRequest): string;
var
  LBody: TJSONObject;
  LInputArr: TJSONArray;
  LTextObj, LImgObj: TJSONObject;
  LRespFormat: TJSONObject;
  LToolsArr: TJSONArray;
  LSearchTool: TJSONObject;
  LSearchTypesArr: TJSONArray;
  LGenConfig: TJSONObject;
  LModelToUse: string;
  I: Integer;
begin
  LModelToUse := ARequest.Model.Trim;
  if LModelToUse.IsEmpty then
    LModelToUse := FModel;

  LBody := TJSONObject.Create;
  try
    LBody.AddPair('model', LModelToUse);

    // 1. Input (Array contendo prompt texto e imagens de referencia opcionais)
    LInputArr := TJSONArray.Create;

    if not ARequest.Prompt.Trim.IsEmpty then
    begin
      LTextObj := TJSONObject.Create;
      LTextObj.AddPair('type', 'text');
      LTextObj.AddPair('text', ARequest.Prompt);
      LInputArr.AddElement(LTextObj);
    end;

    for I := 0 to Length(ARequest.ReferenceImages) - 1 do
    begin
      if not ARequest.ReferenceImages[I].Data.IsEmpty then
      begin
        LImgObj := TJSONObject.Create;
        LImgObj.AddPair('type', 'image');
        LImgObj.AddPair('mime_type', ARequest.ReferenceImages[I].MimeType);
        LImgObj.AddPair('data', ARequest.ReferenceImages[I].Data);
        LInputArr.AddElement(LImgObj);
      end;
    end;

    LBody.AddPair('input', LInputArr);

    // 2. Previous Interaction ID (para conversas / edicao multi-turn sequencial)
    if not ARequest.PreviousInteractionId.Trim.IsEmpty then
      LBody.AddPair('previous_interaction_id', ARequest.PreviousInteractionId.Trim);

    // 3. Response Format (aspect_ratio, image_size, mime_type)
    if (ARequest.AspectRatio <> arDefault) or
       (ARequest.ImageSize <> isDefault) or
       (ARequest.Format <> imDefault) then
    begin
      LRespFormat := TJSONObject.Create;
      LRespFormat.AddPair('type', 'image');

      if ARequest.Format <> imDefault then
        LRespFormat.AddPair('mime_type', ARequest.Format.ToString);

      if ARequest.AspectRatio <> arDefault then
        LRespFormat.AddPair('aspect_ratio', ARequest.AspectRatio.ToString);

      if ARequest.ImageSize <> isDefault then
        LRespFormat.AddPair('image_size', ARequest.ImageSize.ToString);

      LBody.AddPair('response_format', LRespFormat);
    end;

    // 4. Tools (Grounding com Google Search / Image Search)
    if ARequest.UseGoogleSearch then
    begin
      LToolsArr := TJSONArray.Create;
      LSearchTool := TJSONObject.Create;
      LSearchTool.AddPair('type', 'google_search');

      if ARequest.UseImageSearch then
      begin
        LSearchTypesArr := TJSONArray.Create;
        LSearchTypesArr.Add('web_search');
        LSearchTypesArr.Add('image_search');
        LSearchTool.AddPair('search_types', LSearchTypesArr);
      end;

      LToolsArr.AddElement(LSearchTool);
      LBody.AddPair('tools', LToolsArr);
    end;

    // 5. Generation Config (Thinking level: minimal, medium, high)
    if ARequest.ThinkingLevel <> tlDefault then
    begin
      LGenConfig := TJSONObject.Create;
      LGenConfig.AddPair('thinking_level', ARequest.ThinkingLevel.ToString);
      LBody.AddPair('generation_config', LGenConfig);
    end;

    Result := LBody.ToJSON;
  finally
    LBody.Free;
  end;
end;

function TGeminiImageProvider.ExtractErrorMessage(const AErrorJSON: string): string;
var
  LVal, LErrVal, LMsgVal, LStatusVal: TJSONValue;
  LObj, LErr: TJSONObject;
  LMsg, LStatus: string;
begin
  Result := AErrorJSON;
  LVal := TJSONObject.ParseJSONValue(AErrorJSON);
  if LVal is TJSONObject then
  begin
    LObj := TJSONObject(LVal);
    try
      LErrVal := LObj.FindValue('error');
      if LErrVal is TJSONObject then
      begin
        LErr := TJSONObject(LErrVal);
        LMsgVal := LErr.FindValue('message');
        LStatusVal := LErr.FindValue('status');

        LMsg := EmptyStr;
        if LMsgVal is TJSONString then
          LMsg := LMsgVal.Value;

        LStatus := EmptyStr;
        if LStatusVal is TJSONString then
          LStatus := LStatusVal.Value;

        if not LStatus.IsEmpty and not LMsg.IsEmpty then
          Result := Format('%s: %s', [LStatus, LMsg])
        else if not LMsg.IsEmpty then
          Result := LMsg
        else
          Result := LErr.ToJSON;
      end
      else if LErrVal is TJSONString then
        Result := LErrVal.Value;
    finally
      LObj.Free;
    end;
  end
  else if Assigned(LVal) then
    LVal.Free;
end;

function TGeminiImageProvider.ExecuteRequest(const ABodyJSON: string;
  out ARawJSON: string): string;
var
  LResp: IHTTPResponse;
  LStream: TStringStream;
  LURL, LSResp: string;
begin
  Result := EmptyStr;
  ARawJSON := EmptyStr;

  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
  PrepareHeaders(FHttpClient);

  LURL := GetRequestURL;

  LStream := TStringStream.Create(ABodyJSON, TEncoding.UTF8);
  try
    LResp := FHttpClient.Post(LURL, LStream);
  finally
    LStream.Free;
  end;

  LSResp := LResp.ContentAsString(TEncoding.UTF8);
  ARawJSON := LSResp;

  if (LResp.StatusCode < 200) or (LResp.StatusCode >= 300) then
  begin
    raise ELLMAPIError.CreateFmt('Erro na API do Gemini Nano Banana (%d): %s',
      [LResp.StatusCode, ExtractErrorMessage(LSResp)]);
  end;

  Result := LSResp;
end;

function TGeminiImageProvider.ParseResponse(const ARawJSON: string): ILLMImageResponse;
var
  LVal, LImgVal, LDataVal, LMimeVal, LTextVal, LIdVal: TJSONValue;
  LStepsVal, LContentVal: TJSONValue;
  LRoot, LImgObj, LStepObj, LContentObj: TJSONObject;
  LStepsArr, LContentArr: TJSONArray;
  LImages: TArray<ILLMImageItem>;
  LText, LInteractionId, LMime, LData, LType: string;
  I, J: Integer;

  procedure AddImage(const ABase64, AMimeType: string);
  var
    LIdx: Integer;
  begin
    if ABase64.Trim.IsEmpty then
      Exit;
    LIdx := Length(LImages);
    SetLength(LImages, LIdx + 1);
    LImages[LIdx] := TLLMImageItem.Create(ABase64, AMimeType);
  end;

begin
  SetLength(LImages, 0);
  LText := EmptyStr;
  LInteractionId := EmptyStr;

  LVal := TJSONObject.ParseJSONValue(ARawJSON);
  if not (LVal is TJSONObject) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    raise ELLMAPIError.Create('Resposta inválida do Gemini Nano Banana: JSON esperado.');
  end;

  LRoot := TJSONObject(LVal);
  try
    // ID da interacao
    LIdVal := LRoot.FindValue('id');
    if LIdVal <> nil then
      LInteractionId := LIdVal.Value;

    // Texto de conveniencia no nivel raiz
    LTextVal := LRoot.FindValue('output_text');
    if LTextVal <> nil then
      LText := LTextVal.Value;

    // Imagem direta de conveniencia no nivel raiz (output_image)
    LImgVal := LRoot.FindValue('output_image');
    if LImgVal is TJSONObject then
    begin
      LImgObj := TJSONObject(LImgVal);
      LDataVal := LImgObj.FindValue('data');
      LMimeVal := LImgObj.FindValue('mime_type');

      LData := EmptyStr;
      if LDataVal <> nil then
        LData := LDataVal.Value;

      LMime := 'image/jpeg';
      if LMimeVal <> nil then
        LMime := LMimeVal.Value;

      AddImage(LData, LMime);
    end;

    // Se nao veio em output_image ou para capturar steps adicionais (ex: gemini-3-pro-image interleaved)
    LStepsVal := LRoot.FindValue('steps');
    if LStepsVal is TJSONArray then
    begin
      LStepsArr := TJSONArray(LStepsVal);
      for I := 0 to LStepsArr.Count - 1 do
      begin
        if LStepsArr.Items[I] is TJSONObject then
        begin
          LStepObj := TJSONObject(LStepsArr.Items[I]);
          LContentVal := LStepObj.FindValue('content');
          if LContentVal is TJSONArray then
          begin
            LContentArr := TJSONArray(LContentVal);
            for J := 0 to LContentArr.Count - 1 do
            begin
              if LContentArr.Items[J] is TJSONObject then
              begin
                LContentObj := TJSONObject(LContentArr.Items[J]);
                LType := LContentObj.GetValue<string>('type', EmptyStr);

                if SameText(LType, 'image') then
                begin
                  LData := LContentObj.GetValue<string>('data', EmptyStr);
                  LMime := LContentObj.GetValue<string>('mime_type', 'image/jpeg');

                  // Se ja adicionamos a mesma imagem via output_image, evitamos duplicata
                  if (Length(LImages) = 0) or (LImages[0].Base64 <> LData) then
                    AddImage(LData, LMime);
                end
                else if SameText(LType, 'text') and LText.IsEmpty then
                begin
                  LText := LContentObj.GetValue<string>('text', EmptyStr);
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    Result := TLLMImageResponse.Create(ARawJSON, LImages, LText, LInteractionId);
  finally
    LRoot.Free;
  end;
end;

function TGeminiImageProvider.Generate(const APrompt: string): ILLMImageResponse;
begin
  Result := Generate(TLLMImageRequest.New(APrompt));
end;

function TGeminiImageProvider.Generate(const ARequest: TLLMImageRequest): ILLMImageResponse;
var
  LBodyJSON, LRawJSON: string;
begin
  LBodyJSON := BuildBodyJSON(ARequest);
  ExecuteRequest(LBodyJSON, LRawJSON);
  Result := ParseResponse(LRawJSON);
end;

end.
