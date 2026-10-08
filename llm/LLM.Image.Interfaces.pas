unit LLM.Image.Interfaces;

interface

uses
  System.SysUtils,
  System.Classes,
  System.NetEncoding,
  System.IOUtils;

type
  /// <summary>
  /// Proporcao de aspecto para geracao de imagens
  /// </summary>
  TLLMImageAspectRatio = (
    arDefault,
    ar1_1,
    ar3_2,
    ar2_3,
    ar3_4,
    ar4_3,
    ar4_5,
    ar5_4,
    ar9_16,
    ar16_9,
    ar21_9
  );

  TLLMImageAspectRatioHelper = record helper for TLLMImageAspectRatio
  public
    function ToString: string;
    class function FromString(const Value: string): TLLMImageAspectRatio; static;
  end;

  /// <summary>
  /// Resolucao/tamanho da imagem gerada (512px, 1K, 2K, 4K)
  /// </summary>
  TLLMImageSize = (
    isDefault,
    is512px,
    is1K,
    is2K,
    is4K
  );

  TLLMImageSizeHelper = record helper for TLLMImageSize
  public
    function ToString: string;
    class function FromString(const Value: string): TLLMImageSize; static;
  end;

  /// <summary>
  /// Formato MIME da imagem de saida
  /// </summary>
  TLLMImageMimeType = (
    imDefault,
    imJPEG,
    imPNG,
    imWebP
  );

  TLLMImageMimeTypeHelper = record helper for TLLMImageMimeType
  public
    function ToString: string;
    class function FromString(const Value: string): TLLMImageMimeType; static;
  end;

  /// <summary>
  /// Nivel de raciocinio (Thinking) para modelos visuais reflexivos
  /// </summary>
  TLLMImageThinkingLevel = (
    tlDefault,
    tlMinimal,
    tlMedium,
    tlHigh
  );

  TLLMImageThinkingLevelHelper = record helper for TLLMImageThinkingLevel
  public
    function ToString: string;
    class function FromString(const Value: string): TLLMImageThinkingLevel; static;
  end;

  /// <summary>
  /// Referencia de imagem de entrada para edicao, inpainting ou composicao multimodal
  /// </summary>
  TLLMImageReference = record
  private
    FData: string; // Base64
    FMimeType: string;
  public
    class function Create(const ABase64Data: string; const AMimeType: string = 'image/png'): TLLMImageReference; static;
    class function FromFile(const AFilePath: string; const AMimeType: string = ''): TLLMImageReference; static;
    class function FromStream(AStream: TStream; const AMimeType: string = 'image/png'): TLLMImageReference; static;
    class function FromBytes(const ABytes: TBytes; const AMimeType: string = 'image/png'): TLLMImageReference; static;

    property Data: string read FData;
    property MimeType: string read FMimeType;
  end;

  /// <summary>
  /// Parametros e opcoes para solicitacao de geracao de imagem
  /// </summary>
  TLLMImageRequest = record
  private
    FPrompt: string;
    FModel: string;
    FAspectRatio: TLLMImageAspectRatio;
    FImageSize: TLLMImageSize;
    FFormat: TLLMImageMimeType;
    FThinkingLevel: TLLMImageThinkingLevel;
    FUseGoogleSearch: Boolean;
    FUseImageSearch: Boolean;
    FPreviousInteractionId: string;
    FReferenceImages: TArray<TLLMImageReference>;
  public
    class function New(const APrompt: string = ''): TLLMImageRequest; static;

    function SetPrompt(const Value: string): TLLMImageRequest;
    function SetModel(const Value: string): TLLMImageRequest;
    function SetAspectRatio(const Value: TLLMImageAspectRatio): TLLMImageRequest;
    function SetImageSize(const Value: TLLMImageSize): TLLMImageRequest;
    function SetFormat(const Value: TLLMImageMimeType): TLLMImageRequest;
    function SetThinkingLevel(const Value: TLLMImageThinkingLevel): TLLMImageRequest;
    function EnableGoogleSearch(const Value: Boolean = True; const AIncludeImageSearch: Boolean = False): TLLMImageRequest;
    function SetPreviousInteractionId(const Value: string): TLLMImageRequest;
    function AddReferenceImage(const ARef: TLLMImageReference): TLLMImageRequest; overload;
    function AddReferenceImage(const ABase64Data: string; const AMimeType: string = 'image/png'): TLLMImageRequest; overload;
    function AddReferenceFile(const AFilePath: string; const AMimeType: string = ''): TLLMImageRequest;

    property Prompt: string read FPrompt write FPrompt;
    property Model: string read FModel write FModel;
    property AspectRatio: TLLMImageAspectRatio read FAspectRatio write FAspectRatio;
    property ImageSize: TLLMImageSize read FImageSize write FImageSize;
    property Format: TLLMImageMimeType read FFormat write FFormat;
    property ThinkingLevel: TLLMImageThinkingLevel read FThinkingLevel write FThinkingLevel;
    property UseGoogleSearch: Boolean read FUseGoogleSearch write FUseGoogleSearch;
    property UseImageSearch: Boolean read FUseImageSearch write FUseImageSearch;
    property PreviousInteractionId: string read FPreviousInteractionId write FPreviousInteractionId;
    property ReferenceImages: TArray<TLLMImageReference> read FReferenceImages write FReferenceImages;
  end;

  /// <summary>
  /// Representa uma imagem gerada retornada pela API
  /// </summary>
  ILLMImageItem = interface
    ['{A194E38F-E9F3-43DE-9963-8CF7D07EB62A}']
    function GetBase64: string;
    function GetMimeType: string;
    function AsBytes: TBytes;
    procedure SaveToFile(const AFileName: string);
    procedure SaveToStream(AStream: TStream);

    property Base64: string read GetBase64;
    property MimeType: string read GetMimeType;
  end;

  /// <summary>
  /// Resposta completa da requisicao de geracao de imagem
  /// </summary>
  ILLMImageResponse = interface
    ['{E8721319-DC53-4856-B10E-6F3993D64B79}']
    function GetRawJSON: string;
    function GetImages: TArray<ILLMImageItem>;
    function GetFirstImage: ILLMImageItem;
    function GetText: string;
    function GetInteractionId: string;
    function HasImages: Boolean;
    function Count: Integer;

    property RawJSON: string read GetRawJSON;
    property Images: TArray<ILLMImageItem> read GetImages;
    property First: ILLMImageItem read GetFirstImage;
    property Text: string read GetText;
    property InteractionId: string read GetInteractionId;
  end;

  /// <summary>
  /// Provedor para geracao de imagens
  /// </summary>
  ILLMImageProvider = interface
    ['{FA593F36-4197-400A-AE20-E415494C69F2}']
    function GetApiKey: string;
    procedure SetApiKey(const Value: string);
    function GetBaseURL: string;
    procedure SetBaseURL(const Value: string);
    function GetModel: string;
    procedure SetModel(const Value: string);
    function GetTimeout: Integer;
    procedure SetTimeout(const Value: Integer);

    function Generate(const APrompt: string): ILLMImageResponse; overload;
    function Generate(const ARequest: TLLMImageRequest): ILLMImageResponse; overload;

    property ApiKey: string read GetApiKey write SetApiKey;
    property BaseURL: string read GetBaseURL write SetBaseURL;
    property Model: string read GetModel write SetModel;
    property Timeout: Integer read GetTimeout write SetTimeout;
  end;

  /// <summary>
  /// Implementacao padrao da imagem retornada (ILLMImageItem)
  /// </summary>
  TLLMImageItem = class(TInterfacedObject, ILLMImageItem)
  private
    FBase64: string;
    FMimeType: string;
    function GetBase64: string;
    function GetMimeType: string;
  public
    constructor Create(const ABase64: string; const AMimeType: string = 'image/jpeg');
    function AsBytes: TBytes;
    procedure SaveToFile(const AFileName: string);
    procedure SaveToStream(AStream: TStream);

    property Base64: string read GetBase64;
    property MimeType: string read GetMimeType;
  end;

  /// <summary>
  /// Implementacao padrao da resposta de geracao de imagem (ILLMImageResponse)
  /// </summary>
  TLLMImageResponse = class(TInterfacedObject, ILLMImageResponse)
  private
    FRawJSON: string;
    FImages: TArray<ILLMImageItem>;
    FText: string;
    FInteractionId: string;
    function GetRawJSON: string;
    function GetImages: TArray<ILLMImageItem>;
    function GetFirstImage: ILLMImageItem;
    function GetText: string;
    function GetInteractionId: string;
    function HasImages: Boolean;
    function Count: Integer;
  public
    constructor Create(const ARawJSON: string; const AImages: TArray<ILLMImageItem>;
      const AText: string = ''; const AInteractionId: string = '');

    property RawJSON: string read GetRawJSON;
    property Images: TArray<ILLMImageItem> read GetImages;
    property First: ILLMImageItem read GetFirstImage;
    property Text: string read GetText;
    property InteractionId: string read GetInteractionId;
  end;

implementation

{ TLLMImageAspectRatioHelper }

function TLLMImageAspectRatioHelper.ToString: string;
begin
  case Self of
    ar1_1:   Result := '1:1';
    ar3_2:   Result := '3:2';
    ar2_3:   Result := '2:3';
    ar3_4:   Result := '3:4';
    ar4_3:   Result := '4:3';
    ar4_5:   Result := '4:5';
    ar5_4:   Result := '5:4';
    ar9_16:  Result := '9:16';
    ar16_9:  Result := '16:9';
    ar21_9:  Result := '21:9';
  else
    Result := EmptyStr;
  end;
end;

class function TLLMImageAspectRatioHelper.FromString(const Value: string): TLLMImageAspectRatio;
var
  LVal: string;
begin
  LVal := Value.Trim.ToLower;
  if LVal = '1:1' then Result := ar1_1
  else if LVal = '3:2' then Result := ar3_2
  else if LVal = '2:3' then Result := ar2_3
  else if LVal = '3:4' then Result := ar3_4
  else if LVal = '4:3' then Result := ar4_3
  else if LVal = '4:5' then Result := ar4_5
  else if LVal = '5:4' then Result := ar5_4
  else if LVal = '9:16' then Result := ar9_16
  else if LVal = '16:9' then Result := ar16_9
  else if LVal = '21:9' then Result := ar21_9
  else Result := arDefault;
end;

{ TLLMImageSizeHelper }

function TLLMImageSizeHelper.ToString: string;
begin
  case Self of
    is512px: Result := '512px';
    is1K:    Result := '1K';
    is2K:    Result := '2K';
    is4K:    Result := '4K';
  else
    Result := EmptyStr;
  end;
end;

class function TLLMImageSizeHelper.FromString(const Value: string): TLLMImageSize;
var
  LVal: string;
begin
  LVal := Value.Trim.ToUpper;
  if (LVal = '512PX') or (LVal = '0.5K') or (LVal = '512') then Result := is512px
  else if LVal = '1K' then Result := is1K
  else if LVal = '2K' then Result := is2K
  else if LVal = '4K' then Result := is4K
  else Result := isDefault;
end;

{ TLLMImageMimeTypeHelper }

function TLLMImageMimeTypeHelper.ToString: string;
begin
  case Self of
    imJPEG: Result := 'image/jpeg';
    imPNG:  Result := 'image/png';
    imWebP: Result := 'image/webp';
  else
    Result := EmptyStr;
  end;
end;

class function TLLMImageMimeTypeHelper.FromString(const Value: string): TLLMImageMimeType;
var
  LVal: string;
begin
  LVal := Value.Trim.ToLower;
  if (LVal = 'image/jpeg') or (LVal = 'image/jpg') or (LVal = 'jpeg') or (LVal = 'jpg') then
    Result := imJPEG
  else if (LVal = 'image/png') or (LVal = 'png') then
    Result := imPNG
  else if (LVal = 'image/webp') or (LVal = 'webp') then
    Result := imWebP
  else
    Result := imDefault;
end;

{ TLLMImageThinkingLevelHelper }

function TLLMImageThinkingLevelHelper.ToString: string;
begin
  case Self of
    tlMinimal: Result := 'minimal';
    tlMedium:  Result := 'medium';
    tlHigh:    Result := 'high';
  else
    Result := EmptyStr;
  end;
end;

class function TLLMImageThinkingLevelHelper.FromString(const Value: string): TLLMImageThinkingLevel;
var
  LVal: string;
begin
  LVal := Value.Trim.ToLower;
  if LVal = 'minimal' then Result := tlMinimal
  else if LVal = 'medium' then Result := tlMedium
  else if LVal = 'high' then Result := tlHigh
  else Result := tlDefault;
end;

{ TLLMImageReference }

class function TLLMImageReference.Create(const ABase64Data, AMimeType: string): TLLMImageReference;
begin
  Result.FData := ABase64Data.Trim;
  Result.FMimeType := AMimeType.Trim;
  if Result.FMimeType.IsEmpty then
    Result.FMimeType := 'image/png';
end;

class function TLLMImageReference.FromFile(const AFilePath, AMimeType: string): TLLMImageReference;
var
  LBytes: TBytes;
  LMime: string;
  LExt: string;
begin
  if not TFile.Exists(AFilePath) then
    raise EFileNotFoundException.CreateFmt('Arquivo de imagem de referência não encontrado: %s', [AFilePath]);

  LBytes := TFile.ReadAllBytes(AFilePath);
  LMime := AMimeType.Trim;
  if LMime.IsEmpty then
  begin
    LExt := TPath.GetExtension(AFilePath).ToLower;
    if (LExt = '.jpg') or (LExt = '.jpeg') then
      LMime := 'image/jpeg'
    else if LExt = '.png' then
      LMime := 'image/png'
    else if LExt = '.webp' then
      LMime := 'image/webp'
    else
      LMime := 'image/png';
  end;

  Result := FromBytes(LBytes, LMime);
end;

class function TLLMImageReference.FromStream(AStream: TStream; const AMimeType: string): TLLMImageReference;
var
  LBytes: TBytes;
  LPos: Int64;
begin
  if AStream = nil then
    raise EArgumentNilException.Create('Stream não pode ser nulo');

  LPos := AStream.Position;
  SetLength(LBytes, AStream.Size - LPos);
  if Length(LBytes) > 0 then
    AStream.ReadBuffer(LBytes[0], Length(LBytes));

  Result := FromBytes(LBytes, AMimeType);
end;

class function TLLMImageReference.FromBytes(const ABytes: TBytes; const AMimeType: string): TLLMImageReference;
begin
  Result.FData := TNetEncoding.Base64.EncodeBytesToString(ABytes);
  // Remove quebras de linha que alguns encoders possam emitir
  Result.FData := Result.FData.Replace(#13, '').Replace(#10, '');
  Result.FMimeType := AMimeType;
  if Result.FMimeType.IsEmpty then
    Result.FMimeType := 'image/png';
end;

{ TLLMImageRequest }

class function TLLMImageRequest.New(const APrompt: string): TLLMImageRequest;
begin
  Result.FPrompt := APrompt;
  Result.FModel := EmptyStr;
  Result.FAspectRatio := arDefault;
  Result.FImageSize := isDefault;
  Result.FFormat := imDefault;
  Result.FThinkingLevel := tlDefault;
  Result.FUseGoogleSearch := False;
  Result.FUseImageSearch := False;
  Result.FPreviousInteractionId := EmptyStr;
  SetLength(Result.FReferenceImages, 0);
end;

function TLLMImageRequest.SetPrompt(const Value: string): TLLMImageRequest;
begin
  FPrompt := Value;
  Result := Self;
end;

function TLLMImageRequest.SetModel(const Value: string): TLLMImageRequest;
begin
  FModel := Value;
  Result := Self;
end;

function TLLMImageRequest.SetAspectRatio(const Value: TLLMImageAspectRatio): TLLMImageRequest;
begin
  FAspectRatio := Value;
  Result := Self;
end;

function TLLMImageRequest.SetImageSize(const Value: TLLMImageSize): TLLMImageRequest;
begin
  FImageSize := Value;
  Result := Self;
end;

function TLLMImageRequest.SetFormat(const Value: TLLMImageMimeType): TLLMImageRequest;
begin
  FFormat := Value;
  Result := Self;
end;

function TLLMImageRequest.SetThinkingLevel(const Value: TLLMImageThinkingLevel): TLLMImageRequest;
begin
  FThinkingLevel := Value;
  Result := Self;
end;

function TLLMImageRequest.EnableGoogleSearch(const Value: Boolean; const AIncludeImageSearch: Boolean): TLLMImageRequest;
begin
  FUseGoogleSearch := Value;
  FUseImageSearch := Value and AIncludeImageSearch;
  Result := Self;
end;

function TLLMImageRequest.SetPreviousInteractionId(const Value: string): TLLMImageRequest;
begin
  FPreviousInteractionId := Value;
  Result := Self;
end;

function TLLMImageRequest.AddReferenceImage(const ARef: TLLMImageReference): TLLMImageRequest;
var
  LIndex: Integer;
begin
  LIndex := Length(FReferenceImages);
  SetLength(FReferenceImages, LIndex + 1);
  FReferenceImages[LIndex] := ARef;
  Result := Self;
end;

function TLLMImageRequest.AddReferenceImage(const ABase64Data, AMimeType: string): TLLMImageRequest;
begin
  Result := AddReferenceImage(TLLMImageReference.Create(ABase64Data, AMimeType));
end;

function TLLMImageRequest.AddReferenceFile(const AFilePath, AMimeType: string): TLLMImageRequest;
begin
  Result := AddReferenceImage(TLLMImageReference.FromFile(AFilePath, AMimeType));
end;

{ TLLMImageItem }

constructor TLLMImageItem.Create(const ABase64, AMimeType: string);
begin
  inherited Create;
  FBase64 := ABase64.Trim.Replace(#13, '').Replace(#10, '');
  FMimeType := AMimeType.Trim;
  if FMimeType.IsEmpty then
    FMimeType := 'image/jpeg';
end;

function TLLMImageItem.GetBase64: string;
begin
  Result := FBase64;
end;

function TLLMImageItem.GetMimeType: string;
begin
  Result := FMimeType;
end;

function TLLMImageItem.AsBytes: TBytes;
begin
  if FBase64.IsEmpty then
    SetLength(Result, 0)
  else
    Result := TNetEncoding.Base64.DecodeStringToBytes(FBase64);
end;

procedure TLLMImageItem.SaveToStream(AStream: TStream);
var
  LBytes: TBytes;
begin
  if AStream = nil then
    raise EArgumentNilException.Create('Stream não pode ser nulo');

  LBytes := AsBytes;
  if Length(LBytes) > 0 then
    AStream.WriteBuffer(LBytes[0], Length(LBytes));
end;

procedure TLLMImageItem.SaveToFile(const AFileName: string);
var
  LFileStream: TFileStream;
begin
  LFileStream := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(LFileStream);
  finally
    LFileStream.Free;
  end;
end;

{ TLLMImageResponse }

constructor TLLMImageResponse.Create(const ARawJSON: string;
  const AImages: TArray<ILLMImageItem>; const AText, AInteractionId: string);
begin
  inherited Create;
  FRawJSON := ARawJSON;
  FImages := AImages;
  FText := AText;
  FInteractionId := AInteractionId;
end;

function TLLMImageResponse.GetRawJSON: string;
begin
  Result := FRawJSON;
end;

function TLLMImageResponse.GetImages: TArray<ILLMImageItem>;
begin
  Result := FImages;
end;

function TLLMImageResponse.GetFirstImage: ILLMImageItem;
begin
  if Length(FImages) > 0 then
    Result := FImages[0]
  else
    Result := nil;
end;

function TLLMImageResponse.GetText: string;
begin
  Result := FText;
end;

function TLLMImageResponse.GetInteractionId: string;
begin
  Result := FInteractionId;
end;

function TLLMImageResponse.HasImages: Boolean;
begin
  Result := Length(FImages) > 0;
end;

function TLLMImageResponse.Count: Integer;
begin
  Result := Length(FImages);
end;

end.
