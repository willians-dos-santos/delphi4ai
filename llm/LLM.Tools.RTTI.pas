unit LLM.Tools.RTTI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.RTTI,
  System.Generics.Collections,
  LLM.Tools,
  LLM.Tools.Attributes;

type
  /// <summary>
  /// Gerenciador de registro de ferramentas (Tools) via RTTI
  /// Permite registrar classes ou instancias decoradas com [TLLMTool] e [TLLMParam]
  /// </summary>
  TLLMRTTIManager = class
  private
    FCtx: TRttiContext;
    FToolRegistry: ILLMToolRegistry;
    FInstances: TObjectDictionary<TClass, TObject>;

    function CreateInstance(AClass: TClass; ATyp: TRttiType): TObject;
    procedure RegisterMethodTool(AInstance: TObject; AMethod: TRttiMethod;
      const AToolName, AToolDesc: string; AParamsSchema: TJSONObject);
    function ExtractArgValue(const AJSONArgs: TJSONObject; const AParamName: string;
      AParamType: TRttiType): TValue;
  public
    constructor Create(AToolRegistry: ILLMToolRegistry);
    destructor Destroy; override;

    procedure RegisterTool(AClass: TClass); overload;
    procedure RegisterTool(AInstance: TObject); overload;
    procedure ClearTools;
  end;

implementation

{ TLLMRTTIManager }

constructor TLLMRTTIManager.Create(AToolRegistry: ILLMToolRegistry);
begin
  inherited Create;
  FCtx := TRttiContext.Create;
  FToolRegistry := AToolRegistry;
  // [doOwnsValues] garante a destruicao automatica das instancias criadas internamente
  FInstances := TObjectDictionary<TClass, TObject>.Create([doOwnsValues]);
end;

destructor TLLMRTTIManager.Destroy;
begin
  FInstances.Free;
  FCtx.Free;
  inherited;
end;

procedure TLLMRTTIManager.ClearTools;
begin
  FInstances.Clear;
end;

function TLLMRTTIManager.CreateInstance(AClass: TClass; ATyp: TRttiType): TObject;
var
  ConsMeth: TRttiMethod;
  LVal: TValue;
begin
  Result := nil;

  // 1. Tenta invocar construtor sem parametros via RTTI caso exista
  if Assigned(ATyp) then
  begin
    for ConsMeth in ATyp.GetMethods do
    begin
      if ConsMeth.IsConstructor and (Length(ConsMeth.GetParameters) = 0) then
      begin
        try
          LVal := ConsMeth.Invoke(AClass, []);
          if not LVal.IsEmpty then
            Result := LVal.AsObject;
        except
          Result := nil;
        end;
        Break;
      end;
    end;
  end;

  // 2. Se a invocacao via RTTI retornar nil (por exemplo, quando a classe nao possui
  // RTTI de ClassInfo gerado para construtores), instancia usando o construtor padrao de TClass (TObject.Create)
  if Result = nil then
    Result := AClass.Create;
end;

procedure TLLMRTTIManager.RegisterTool(AClass: TClass);
var
  LInstance: TObject;
  Typ: TRttiType;
begin
  if (AClass = nil) or FInstances.ContainsKey(AClass) then
    Exit;

  Typ := FCtx.GetType(AClass);
  if Typ = nil then
    Exit;

  LInstance := CreateInstance(AClass, Typ);
  FInstances.Add(AClass, LInstance);

  RegisterTool(LInstance);
end;

procedure TLLMRTTIManager.RegisterTool(AInstance: TObject);
var
  Typ: TRttiType;
  Meth: TRttiMethod;
  Attr: TCustomAttribute;
  Param: TRttiParameter;
  ParamAttr: TCustomAttribute;
  LToolName, LToolDesc: string;
  LParamsObj, LPropsObj, LParamDef: TJSONObject;
  LReqArray: TJSONArray;
  LIsRequired: Boolean;
begin
  if AInstance = nil then
    Exit;

  Typ := FCtx.GetType(AInstance.ClassType);
  if Typ = nil then
    Exit;

  for Meth in Typ.GetMethods do
  begin
    LToolName := EmptyStr;
    LToolDesc := EmptyStr;

    for Attr in Meth.GetAttributes do
    begin
      if Attr is TLLMToolAttribute then
      begin
        LToolName := TLLMToolAttribute(Attr).Name;
        LToolDesc := TLLMToolAttribute(Attr).Description;
        Break;
      end;
    end;

    if LToolName <> EmptyStr then
    begin
      LParamsObj := TJSONObject.Create;
      try
        LParamsObj.AddPair('type', 'object');
        LPropsObj := TJSONObject.Create;
        LReqArray := TJSONArray.Create;

        for Param in Meth.GetParameters do
        begin
          LParamDef := TJSONObject.Create;

          case Param.ParamType.TypeKind of
            tkInteger, tkInt64:
              LParamDef.AddPair('type', 'integer');
            tkFloat:
              LParamDef.AddPair('type', 'number');
            tkEnumeration:
              if SameText(Param.ParamType.Name, 'Boolean') then
                LParamDef.AddPair('type', 'boolean')
              else
                LParamDef.AddPair('type', 'string');
          else
            LParamDef.AddPair('type', 'string');
          end;

          LIsRequired := True;
          for ParamAttr in Param.GetAttributes do
          begin
            if ParamAttr is TLLMParamAttribute then
            begin
              LParamDef.AddPair('description', TLLMParamAttribute(ParamAttr).Description);
              LIsRequired := TLLMParamAttribute(ParamAttr).Required;
              Break;
            end;
          end;

          LPropsObj.AddPair(Param.Name.ToLower, LParamDef);
          if LIsRequired then
            LReqArray.Add(Param.Name.ToLower);
        end;

        LParamsObj.AddPair('properties', LPropsObj);
        if LReqArray.Count > 0 then
          LParamsObj.AddPair('required', LReqArray)
        else
          LReqArray.Free;

        // Isola o registro em metodo dedicado para garantir captura correta das variaveis de closure
        RegisterMethodTool(AInstance, Meth, LToolName, LToolDesc, LParamsObj);
      finally
        // FToolRegistry.RegisterTool clona internamente o AParamsSchema, logo podemos liberar com seguranca
        LParamsObj.Free;
      end;
    end;
  end;
end;

procedure TLLMRTTIManager.RegisterMethodTool(AInstance: TObject; AMethod: TRttiMethod;
  const AToolName, AToolDesc: string; AParamsSchema: TJSONObject);
begin
  FToolRegistry.RegisterTool(AToolName, AToolDesc, AParamsSchema,
    function(const AArgsJSON: string): string
    var
      LJSONVal: TJSONValue;
      LJSONArgs: TJSONObject;
      LParamsList: TArray<TRttiParameter>;
      LArgsArray: TArray<TValue>;
      I: Integer;
      LResultVal: TValue;
    begin
      LJSONArgs := nil;
      if not AArgsJSON.Trim.IsEmpty then
      begin
        LJSONVal := TJSONObject.ParseJSONValue(AArgsJSON);
        if LJSONVal is TJSONObject then
          LJSONArgs := TJSONObject(LJSONVal)
        else if Assigned(LJSONVal) then
          LJSONVal.Free;
      end;

      try
        LParamsList := AMethod.GetParameters;
        SetLength(LArgsArray, Length(LParamsList));

        for I := 0 to High(LParamsList) do
          LArgsArray[I] := ExtractArgValue(LJSONArgs, LParamsList[I].Name, LParamsList[I].ParamType);

        LResultVal := AMethod.Invoke(AInstance, LArgsArray);

        if AMethod.ReturnType <> nil then
        begin
          if LResultVal.IsEmpty then
            Result := EmptyStr
          else if LResultVal.Kind = tkUString then
            Result := LResultVal.AsString
          else
            Result := LResultVal.ToString;
        end
        else
          Result := '{"status":"ok"}';
      finally
        LJSONArgs.Free;
      end;
    end);
end;

function TLLMRTTIManager.ExtractArgValue(const AJSONArgs: TJSONObject;
  const AParamName: string; AParamType: TRttiType): TValue;
var
  LItemVal: TJSONValue;
  LStrVal: string;
  LFS: TFormatSettings;
  LPair: TJSONPair;
begin
  LItemVal := nil;
  LFS := TFormatSettings.Invariant;

  if Assigned(AJSONArgs) then
  begin
    // 1. Busca exata pelo nome do parametro
    LItemVal := AJSONArgs.FindValue(AParamName);

    // 2. Busca pelo nome em minusculo
    if LItemVal = nil then
      LItemVal := AJSONArgs.FindValue(AParamName.ToLower);

    // 3. Busca case-insensitive percorrendo os pares
    if LItemVal = nil then
    begin
      for LPair in AJSONArgs do
      begin
        if SameText(LPair.JsonString.Value, AParamName) then
        begin
          LItemVal := LPair.JsonValue;
          Break;
        end;
      end;
    end;
  end;

  // Se nao foi fornecido nenhum valor no JSON, define valores padrao validos (nunca TValue.Empty para tipos primitivos)
  if LItemVal = nil then
  begin
    if AParamType = nil then
      Exit(TValue.Empty);

    case AParamType.TypeKind of
      tkInteger, tkInt64:
        Result := TValue.From<Int64>(0);
      tkFloat:
        Result := TValue.From<Double>(0.0);
      tkEnumeration:
        if SameText(AParamType.Name, 'Boolean') then
          Result := TValue.From<Boolean>(False)
        else
          Result := TValue.From<Integer>(0);
      tkString, tkLString, tkWString, tkUString:
        Result := TValue.From<string>(EmptyStr);
    else
      Result := TValue.Empty;
    end;
    Exit;
  end;

  LStrVal := LItemVal.Value;

  if AParamType = nil then
    Exit(TValue.From<string>(LStrVal));

  case AParamType.TypeKind of
    tkInteger:
      if LItemVal is TJSONNumber then
        Result := TValue.From<Integer>(TJSONNumber(LItemVal).AsInt)
      else
        Result := TValue.From<Integer>(StrToIntDef(LStrVal, 0));

    tkInt64:
      if LItemVal is TJSONNumber then
        Result := TValue.From<Int64>(TJSONNumber(LItemVal).AsInt64)
      else
        Result := TValue.From<Int64>(StrToInt64Def(LStrVal, 0));

    tkFloat:
      if LItemVal is TJSONNumber then
        Result := TValue.From<Double>(TJSONNumber(LItemVal).AsDouble)
      else
        Result := TValue.From<Double>(StrToFloatDef(LStrVal, 0.0, LFS));

    tkEnumeration:
      if SameText(AParamType.Name, 'Boolean') then
      begin
        if LItemVal is TJSONBool then
          Result := TValue.From<Boolean>(TJSONBool(LItemVal).AsBoolean)
        else
          Result := TValue.From<Boolean>(SameText(LStrVal, 'true'));
      end
      else
        Result := TValue.From<Integer>(StrToIntDef(LStrVal, 0));

    tkString, tkLString, tkWString, tkUString:
      Result := TValue.From<string>(LStrVal);
  else
    if (LItemVal is TJSONObject) or (LItemVal is TJSONArray) then
      Result := TValue.From<string>(LItemVal.ToJSON)
    else
      Result := TValue.From<string>(LStrVal);
  end;
end;

end.
