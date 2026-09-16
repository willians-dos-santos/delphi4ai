unit Test.Utils.JSONArray;

interface

uses
  System.SysUtils,
  System.JSON,
  TestFramework,
  Utils.JSONArray;

type
  TTestJSONArrayHelper = class(TTestCase)
  private
    FArray: TJSONArray;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestClearEmptyArray;
    procedure TestClearPopulatedArray;
    procedure TestRemoveFirstEmptyArray;
    procedure TestRemoveFirstReturnsItemAndShifts;
    procedure TestRemoveFirstAndFreeEmptyArray;
    procedure TestRemoveFirstAndFreePopulatedArray;
  end;

implementation

{ TTestJSONArrayHelper }

procedure TTestJSONArrayHelper.SetUp;
begin
  inherited;
  FArray := TJSONArray.Create;
end;

procedure TTestJSONArrayHelper.TearDown;
begin
  FArray.Free;
  inherited;
end;

procedure TTestJSONArrayHelper.TestClearEmptyArray;
begin
  CheckEquals(0, FArray.Count, 'O array recém-criado deve estar vazio');
  FArray.Clear;
  CheckEquals(0, FArray.Count, 'Clear em array vazio deve manter Count = 0');
end;

procedure TTestJSONArrayHelper.TestClearPopulatedArray;
begin
  FArray.Add('Item 1');
  FArray.Add(123);
  FArray.AddElement(TJSONObject.Create.AddPair('chave', 'valor'));

  CheckEquals(3, FArray.Count, 'Array deve conter 3 itens adicionados');
  FArray.Clear;
  CheckEquals(0, FArray.Count, 'Clear deve liberar os itens e zerar o Count');
end;

procedure TTestJSONArrayHelper.TestRemoveFirstEmptyArray;
var
  LItem: TJSONValue;
begin
  LItem := FArray.RemoveFirst;
  CheckNull(LItem, 'RemoveFirst em array vazio deve retornar nil');
  CheckEquals(0, FArray.Count, 'Count deve permanecer 0');
end;

procedure TTestJSONArrayHelper.TestRemoveFirstReturnsItemAndShifts;
var
  LItem: TJSONValue;
begin
  FArray.Add('primeiro');
  FArray.Add('segundo');
  FArray.Add('terceiro');

  LItem := FArray.RemoveFirst;
  try
    CheckNotNull(LItem, 'RemoveFirst deve retornar o item desvinculado');
    CheckEquals('primeiro', LItem.Value, 'O valor retornado deve ser o primeiro item');
    CheckEquals(2, FArray.Count, 'Count deve diminuir para 2');
    CheckEquals('segundo', FArray.Items[0].Value, 'O segundo elemento deve ter se tornado o índice 0');
    CheckEquals('terceiro', FArray.Items[1].Value, 'O terceiro elemento deve ter se tornado o índice 1');
  finally
    LItem.Free;
  end;
end;

procedure TTestJSONArrayHelper.TestRemoveFirstAndFreeEmptyArray;
begin
  // Não deve lançar Access Violation nem erro
  FArray.RemoveFirstAndFree;
  CheckEquals(0, FArray.Count, 'Count deve permanecer 0');
end;

procedure TTestJSONArrayHelper.TestRemoveFirstAndFreePopulatedArray;
begin
  FArray.Add('mensagem_antiga');
  FArray.Add('mensagem_recente');

  CheckEquals(2, FArray.Count, 'Array deve iniciar com 2 itens');
  FArray.RemoveFirstAndFree;

  CheckEquals(1, FArray.Count, 'Após RemoveFirstAndFree, Count deve ser 1');
  CheckEquals('mensagem_recente', FArray.Items[0].Value, 'Item restante deve ser o recente');
end;

initialization
  RegisterTest(TTestJSONArrayHelper.Suite);

end.
