unit Utils.JSONArray;

interface

uses
  System.JSON;

type
  TJSONArrayHelper = class helper for TJSONArray
  public
    procedure Clear;
    function RemoveFirst:TJSONValue;
    procedure RemoveFirstAndFree;
  end;

implementation

{ TJSONArrayHelper }

procedure TJSONArrayHelper.Clear;
begin
  // Remove do fim para o início para evitar deslocamento contínuo de memória (O(1) por item)
  // No System.JSON, Remove() apenas desvincula e retorna a instância,
  // sendo obrigatório chamar .Free para não gerar memory leak.
  while Count > 0 do
    Remove(Count - 1).Free;

end;

procedure TJSONArrayHelper.RemoveFirstAndFree;
begin
  var
  LJV := RemoveFirst;
  if LJV <> nil then
    LJV.Free;

end;

function TJSONArrayHelper.RemoveFirst:TJSONValue;
begin
  Result := nil;
  if Count > 0 then
    Result := Remove(0);

end;

end.
