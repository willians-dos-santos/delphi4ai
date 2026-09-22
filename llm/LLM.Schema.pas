unit LLM.Schema;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.RTTI,
  System.TypInfo,
  LLM.Interfaces;

type
  /// <summary>
  /// Atributo para definir o nome e descricao de um Schema (aplicavel em classes e records)
  /// </summary>
  TLLMSchemaAttribute = class(TCustomAttribute)
  private
    FName: string;
    FDescription: string;
  public
    constructor Create(const AName: string; const ADescription: string = '');
    property Name: string read FName;
    property Description: string read FDescription;
  end;

  /// <summary>
  /// Atributo para documentar e configurar propriedades ou campos no Schema
  /// </summary>
  TLLMPropertyAttribute = class(TCustomAttribute)
  private
    FDescription: string;
    FRequired: Boolean;
  public
    constructor Create(const ADescription: string; ARequired: Boolean = True); overload;
    constructor Create(ARequired: Boolean); overload;
    property Description: string read FDescription;
    property Required: Boolean read FRequired;
  end;

  /// <summary>
  /// Gerador de JSON Schema via RTTI para classes e records Delphi
  /// </summary>
  TLLMSchemaGenerator = class
  private
    class function MapTypeToJSONSchema(AType: TRttiType; out APropSchema: TJSONObject): Boolean;
    class function CleanTypeName(const AName: string): string;
  public
    class function GenerateSchema(AType: TRttiType; out ASchemaName: string): TJSONObject;
    class function GenerateSchemaFromClass(AClass: TClass; out ASchemaName: string): TJSONObject;
    class function GenerateSchemaFromTypeInfo(ATypeInfo: Pointer; out ASchemaName: string): TJSONObject;
  end;

  /// <summary>
  /// Desserializador de TJSONObject para instancias de classes ou buffers de records via RTTI
  /// </summary>
  TLLMJSONDeserializer = class
  private
    class function FindValueCaseInsensitive(const AJSON: TJSONObject; const AName: string): TJSONValue;
    class function ConvertJSONToValue(const AJSONVal: TJSONValue; ATargetType: TRttiType): TValue;
  public
    class function DeserializeClass(const AJSON: TJSONObject; AClass: TClass): TObject;
    class procedure DeserializeRecord(const AJSON: TJSONObject; ATypeInfo: Pointer; var ARecordBuffer);
  end;

  /// <summary>
  /// Implementacao de ILLMResponseFormat
  /// </summary>
  TLLMResponseFormat = class(TInterfacedObject, ILLMResponseFormat)
  private
    FFormatType: TResponseFormatType;
    FSchemaName: string;
    FSchema: TJSONObject;
    FStrict: Boolean;

    function GetFormatType: TResponseFormatType;
    function GetSchemaName: string;
    function GetSchema: TJSONObject;
    function GetStrict: Boolean;
    procedure SetSchemaInternal(const AName: string; ASchema: TJSONObject; AStrict: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetText;
    procedure SetJSONObject;
    procedure SetSchema(const AName, ASchemaJSON: string; AStrict: Boolean = True); overload;
    procedure SetSchema(const AName: string; const ASchema: TJSONObject; AStrict: Boolean = True); overload;
    procedure SetSchema(AClass: TClass; AStrict: Boolean = True); overload;
    procedure SetSchema(ATypeInfo: Pointer; AStrict: Boolean = True); overload;
    procedure Clear;

    property FormatType: TResponseFormatType read GetFormatType;
    property SchemaName: string read GetSchemaName;
    property Schema: TJSONObject read GetSchema;
    property Strict: Boolean read GetStrict;
  end;

  /// <summary>
  /// Utilitarios genericos para Saidas Estruturadas (Structured Outputs)
  /// </summary>
  TLLM<T> = record
    /// <summary>
    /// Envia a requisicao e desserializa o resultado diretamente no tipo T (suporta Class e Record)
    /// </summary>
    class function SendAs(const AProvider: ILLMProvider): T; static;

    /// <summary>
    /// Configura o schema de saida a partir de um tipo generico T (Class ou Record)
    /// </summary>
    class procedure SetResponseSchema(const AProvider: ILLMProvider; AStrict: Boolean = True); static;
  end;

implementation


{ TLLMSchemaAttribute }

constructor TLLMSchemaAttribute.Create(const AName, ADescription: string);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
end;

{ TLLMPropertyAttribute }

constructor TLLMPropertyAttribute.Create(const ADescription: string; ARequired: Boolean);
begin
  inherited Create;
  FDescription := ADescription;
  FRequired := ARequired;
end;

constructor TLLMPropertyAttribute.Create(ARequired: Boolean);
begin
  inherited Create;
  FDescription := EmptyStr;
  FRequired := ARequired;
end;

{ TLLMSchemaGenerator }

class function TLLMSchemaGenerator.CleanTypeName(const AName: string): string;
begin
  Result := AName;
  if Result.StartsWith('T', True) and (Result.Length > 1) and (Result.Chars[1] = UpperCase(Result.Chars[1])) then
    Result := Result.Substring(1);
end;

class function TLLMSchemaGenerator.MapTypeToJSONSchema(AType: TRttiType;
  out APropSchema: TJSONObject): Boolean;
var
  LEnumCount, I: Integer;
  LEnumArray: TJSONArray;
begin
  Result := True;
  APropSchema := TJSONObject.Create;

  if AType = nil then
  begin
    APropSchema.AddPair('type', 'string');
    Exit;
  end;

  case AType.TypeKind of
    tkInteger, tkInt64:
      APropSchema.AddPair('type', 'integer');

    tkFloat:
      APropSchema.AddPair('type', 'number');

    tkString, tkLString, tkWString, tkUString, tkChar, tkWChar:
      APropSchema.AddPair('type', 'string');

    tkEnumeration:
    begin
      if SameText(AType.Name, 'Boolean') then
        APropSchema.AddPair('type', 'boolean')
      else
      begin
        APropSchema.AddPair('type', 'string');
        // Adiciona array de enum com todos os valores validos
        LEnumArray := TJSONArray.Create;
        LEnumCount := GetTypeData(AType.Handle)^.MaxValue;
        for I := GetTypeData(AType.Handle)^.MinValue to LEnumCount do
          LEnumArray.Add(GetEnumName(AType.Handle, I));
        APropSchema.AddPair('enum', LEnumArray);
      end;
    end;

    tkClass, tkRecord:
    begin
      // Tipos aninhados simples
      APropSchema.AddPair('type', 'object');
    end;
  else
    APropSchema.AddPair('type', 'string');
  end;
end;

class function TLLMSchemaGenerator.GenerateSchema(AType: TRttiType;
  out ASchemaName: string): TJSONObject;
var
  LPropsObj, LItemDef: TJSONObject;
  LReqArr:TJSONArray;
  LAttr: TCustomAttribute;
  LPropAttr: TLLMPropertyAttribute;
  LProp: TRttiProperty;
  LField: TRttiField;
  LPropName, LDesc: string;
  LIsRequired: Boolean;
begin
  if AType = nil then
    raise Exception.Create('TRttiType nao pode ser nulo para gerar schema.');

  ASchemaName := CleanTypeName(AType.Name);
  Result := TJSONObject.Create;
  try
    Result.AddPair('type', 'object');

    // Extrai nome e descricao customizados via [TLLMSchema]
    for LAttr in AType.GetAttributes do
    begin
      if LAttr is TLLMSchemaAttribute then
      begin
        if not TLLMSchemaAttribute(LAttr).Name.IsEmpty then
          ASchemaName := TLLMSchemaAttribute(LAttr).Name;
        if not TLLMSchemaAttribute(LAttr).Description.IsEmpty then
          Result.AddPair('description', TLLMSchemaAttribute(LAttr).Description);
        Break;
      end;
    end;

    LPropsObj := TJSONObject.Create;
    LReqArr := TJSONArray.Create;

    // Processamento para Classes: inspeciona propriedades published/public
    if AType is TRttiInstanceType then
    begin
      for LProp in AType.GetProperties do
      begin
        if not (LProp.Visibility in [mvPublished, mvPublic]) then
          Continue;
        if not LProp.IsWritable then
          Continue;

        LPropName := LProp.Name.ToLower;
        MapTypeToJSONSchema(LProp.PropertyType, LItemDef);

        LIsRequired := True;
        LDesc := EmptyStr;

        for LAttr in LProp.GetAttributes do
        begin
          if LAttr is TLLMPropertyAttribute then
          begin
            LPropAttr := TLLMPropertyAttribute(LAttr);
            LDesc := LPropAttr.Description;
            LIsRequired := LPropAttr.Required;
            Break;
          end;
        end;

        if not LDesc.IsEmpty then
          LItemDef.AddPair('description', LDesc);

        LPropsObj.AddPair(LPropName, LItemDef);

        if LIsRequired then
          LReqArr.Add(LPropName);
      end;
    end
    // Processamento para Records: inspeciona campos
    else if AType is TRttiRecordType then
    begin
      for LField in TRttiRecordType(AType).GetFields do
      begin
        LPropName := LField.Name.ToLower;
        MapTypeToJSONSchema(LField.FieldType, LItemDef);

        LIsRequired := True;
        LDesc := EmptyStr;

        for LAttr in LField.GetAttributes do
        begin
          if LAttr is TLLMPropertyAttribute then
          begin
            LPropAttr := TLLMPropertyAttribute(LAttr);
            LDesc := LPropAttr.Description;
            LIsRequired := LPropAttr.Required;
            Break;
          end;
        end;

        if not LDesc.IsEmpty then
          LItemDef.AddPair('description', LDesc);

        LPropsObj.AddPair(LPropName, LItemDef);

        if LIsRequired then
          LReqArr.Add(LPropName);
      end;
    end;

    Result.AddPair('properties', LPropsObj);

    // No modo estrito (strict), required deve conter todas as propriedades obrigatorias
    Result.AddPair('required', LReqArr);

    // Obrigatorio para schemas estritos (OpenAI strict mode)
    Result.AddPair('additionalProperties', False);
  except
    Result.Free;
    raise;
  end;
end;

class function TLLMSchemaGenerator.GenerateSchemaFromClass(AClass: TClass;
  out ASchemaName: string): TJSONObject;
var
  LCtx: TRttiContext;
  LType: TRttiType;
begin
  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(AClass);
    Result := GenerateSchema(LType, ASchemaName);
  finally
    LCtx.Free;
  end;
end;

class function TLLMSchemaGenerator.GenerateSchemaFromTypeInfo(ATypeInfo: Pointer;
  out ASchemaName: string): TJSONObject;
var
  LCtx: TRttiContext;
  LType: TRttiType;
begin
  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(ATypeInfo);
    Result := GenerateSchema(LType, ASchemaName);
  finally
    LCtx.Free;
  end;
end;

{ TLLMJSONDeserializer }

class function TLLMJSONDeserializer.FindValueCaseInsensitive(
  const AJSON: TJSONObject; const AName: string): TJSONValue;
var
  Pair: TJSONPair;
begin
  Result := nil;
  if AJSON = nil then
    Exit;

  Result := AJSON.FindValue(AName);
  if Result <> nil then
    Exit;

  for Pair in AJSON do
  begin
    if SameText(Pair.JsonString.Value, AName) then
      Exit(Pair.JsonValue);
  end;
end;

class function TLLMJSONDeserializer.ConvertJSONToValue(
  const AJSONVal: TJSONValue; ATargetType: TRttiType): TValue;
var
  LInt64: Int64;
  LDouble: Double;
  LEnumVal: Integer;
begin
  Result := TValue.Empty;
  if (AJSONVal = nil) or (AJSONVal is TJSONNull) or (ATargetType = nil) then
    Exit;

  case ATargetType.TypeKind of
    tkString, tkLString, tkWString, tkUString, tkChar, tkWChar:
    begin
      if AJSONVal is TJSONString then
        Result := TJSONString(AJSONVal).Value
      else
        Result := AJSONVal.Value;
    end;

    tkInteger, tkInt64:
    begin
      if AJSONVal is TJSONNumber then
        LInt64 := TJSONNumber(AJSONVal).AsInt64
      else
        LInt64 := StrToInt64Def(AJSONVal.Value, 0);
      Result := TValue.From<Int64>(LInt64);
    end;

    tkFloat:
    begin
      if AJSONVal is TJSONNumber then
        LDouble := TJSONNumber(AJSONVal).AsDouble
      else
        LDouble := StrToFloatDef(AJSONVal.Value.Replace(',', '.'), 0.0);
      Result := TValue.From<Double>(LDouble);
    end;

    tkEnumeration:
    begin
      if SameText(ATargetType.Name, 'Boolean') then
      begin
        if AJSONVal is TJSONBool then
          Result := TJSONBool(AJSONVal).AsBoolean
        else if SameText(AJSONVal.Value, 'true') then
          Result := True
        else
          Result := False;
      end
      else
      begin
        LEnumVal := GetEnumValue(ATargetType.Handle, AJSONVal.Value);
        if LEnumVal <> -1 then
          TValue.Make(@LEnumVal, ATargetType.Handle, Result)
        else
        begin
          LEnumVal := 0;
          TValue.Make(@LEnumVal, ATargetType.Handle, Result);
        end;
      end;
    end;
  else
    Result := AJSONVal.Value;
  end;
end;

class function TLLMJSONDeserializer.DeserializeClass(const AJSON: TJSONObject;
  AClass: TClass): TObject;
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LVal: TJSONValue;
  LConverted: TValue;
  ConsMeth: TRttiMethod;
begin
  Result := nil;
  if (AJSON = nil) or (AClass = nil) then
    Exit;

  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(AClass);

    // Instanciacao via construtor padrao
    for ConsMeth in LType.GetMethods do
    begin
      if ConsMeth.IsConstructor and (Length(ConsMeth.GetParameters) = 0) then
      begin
        try
          Result := ConsMeth.Invoke(AClass, []).AsObject;
        except
          Result := nil;
        end;
        Break;
      end;
    end;

    if Result = nil then
      Result := AClass.Create;

    for LProp in LType.GetProperties do
    begin
      if not LProp.IsWritable then
        Continue;

      LVal := FindValueCaseInsensitive(AJSON, LProp.Name);
      if LVal <> nil then
      begin
        LConverted := ConvertJSONToValue(LVal, LProp.PropertyType);
        if not LConverted.IsEmpty then
          LProp.SetValue(Result, LConverted);
      end;
    end;
  finally
    LCtx.Free;
  end;
end;

class procedure TLLMJSONDeserializer.DeserializeRecord(const AJSON: TJSONObject;
  ATypeInfo: Pointer; var ARecordBuffer);
var
  LCtx: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
  LVal: TJSONValue;
  LConverted: TValue;
begin
  if (AJSON = nil) or (ATypeInfo = nil) then
    Exit;

  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(ATypeInfo);
    if not (LType is TRttiRecordType) then
      raise Exception.CreateFmt('Tipo "%s" nao e um record.', [LType.Name]);

    for LField in TRttiRecordType(LType).GetFields do
    begin
      LVal := FindValueCaseInsensitive(AJSON, LField.Name);
      if LVal <> nil then
      begin
        LConverted := ConvertJSONToValue(LVal, LField.FieldType);
        if not LConverted.IsEmpty then
          LField.SetValue(@ARecordBuffer, LConverted);
      end;
    end;
  finally
    LCtx.Free;
  end;
end;

{ TLLMResponseFormat }

constructor TLLMResponseFormat.Create;
begin
  inherited Create;
  FFormatType := rfText;
  FSchemaName := EmptyStr;
  FSchema := nil;
  FStrict := True;
end;

destructor TLLMResponseFormat.Destroy;
begin
  FSchema.Free;
  inherited;
end;

function TLLMResponseFormat.GetFormatType: TResponseFormatType;
begin
  Result := FFormatType;
end;

function TLLMResponseFormat.GetSchema: TJSONObject;
begin
  Result := FSchema;
end;

function TLLMResponseFormat.GetSchemaName: string;
begin
  Result := FSchemaName;
end;

function TLLMResponseFormat.GetStrict: Boolean;
begin
  Result := FStrict;
end;

procedure TLLMResponseFormat.Clear;
begin
  FreeAndNil(FSchema);
  FSchemaName := EmptyStr;
  FFormatType := rfText;
  FStrict := True;
end;

procedure TLLMResponseFormat.SetText;
begin
  Clear;
end;

procedure TLLMResponseFormat.SetJSONObject;
begin
  Clear;
  FFormatType := rfJSONObject;
end;

procedure TLLMResponseFormat.SetSchemaInternal(const AName: string;
  ASchema: TJSONObject; AStrict: Boolean);
begin
  FreeAndNil(FSchema);
  FSchemaName := AName;
  FSchema := ASchema;
  FStrict := AStrict;
  FFormatType := rfJSONSchema;
end;

procedure TLLMResponseFormat.SetSchema(const AName, ASchemaJSON: string;
  AStrict: Boolean);
var
  LVal: TJSONValue;
begin
  LVal := TJSONObject.ParseJSONValue(ASchemaJSON);
  if not (LVal is TJSONObject) then
  begin
    if Assigned(LVal) then
      LVal.Free;
    raise Exception.Create('Schema JSON informado nao e um objeto JSON valido.');
  end;
  SetSchemaInternal(AName, TJSONObject(LVal), AStrict);
end;

procedure TLLMResponseFormat.SetSchema(const AName: string;
  const ASchema: TJSONObject; AStrict: Boolean);
begin
  if ASchema = nil then
    raise Exception.Create('ASchema nao pode ser nulo.');
  SetSchemaInternal(AName, ASchema.Clone as TJSONObject, AStrict);
end;

procedure TLLMResponseFormat.SetSchema(AClass: TClass; AStrict: Boolean);
var
  LName: string;
  LSchemaObj: TJSONObject;
begin
  LSchemaObj := TLLMSchemaGenerator.GenerateSchemaFromClass(AClass, LName);
  SetSchemaInternal(LName, LSchemaObj, AStrict);
end;

procedure TLLMResponseFormat.SetSchema(ATypeInfo: Pointer; AStrict: Boolean);
var
  LName: string;
  LSchemaObj: TJSONObject;
begin
  LSchemaObj := TLLMSchemaGenerator.GenerateSchemaFromTypeInfo(ATypeInfo, LName);
  SetSchemaInternal(LName, LSchemaObj, AStrict);
end;

{ TLLM }

class function TLLM<T>.SendAs(const AProvider: ILLMProvider): T;
var
  LTypeInfo: PTypeInfo;
  LObj: TObject;
begin
  if AProvider = nil then
    raise Exception.Create('Provedor LLM nao pode ser nulo para SendAs.');

  LTypeInfo := TypeInfo(T);
  if LTypeInfo = nil then
    raise Exception.Create('Tipo fornecido para SendAs<T> invalido.');

  Result := Default(T);

  if LTypeInfo.Kind = tkClass then
  begin
    LObj := AProvider.SendAs(GetTypeData(LTypeInfo).ClassType);
    PPointer(@Result)^ := Pointer(LObj);
  end
  else if LTypeInfo.Kind = tkRecord then
  begin
    AProvider.SendAs(LTypeInfo, Result);
  end
  else
    raise Exception.CreateFmt(
      'SendAs<T> suporta apenas classes ou records (tipo fornecido: %s).',
      [LTypeInfo.Name]);
end;

class procedure TLLM<T>.SetResponseSchema(const AProvider: ILLMProvider; AStrict: Boolean);
begin
  if AProvider = nil then
    raise Exception.Create('Provedor LLM nao pode ser nulo.');
  AProvider.ResponseFormat.SetSchema(TypeInfo(T), AStrict);
end;

end.
