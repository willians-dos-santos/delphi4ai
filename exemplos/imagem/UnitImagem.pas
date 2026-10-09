unit UnitImagem;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Diagnostics,
  System.IOUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage,
  Vcl.Clipbrd,
  Image.Interfaces,
  Image.Factory,
  LLM.Exceptions,
  Gemini.Image.Provider,
  Pollinations.Image.Provider;

type
  TFormImagem = class(TForm)
    pnlControls: TPanel;
    grpConfig: TGroupBox;
    lblProvider: TLabel;
    lblApiKey: TLabel;
    lblModel: TLabel;
    lblAspectRatio: TLabel;
    lblSize: TLabel;
    lblFormat: TLabel;
    lblThinking: TLabel;
    cbProvider: TComboBox;
    edtApiKey: TEdit;
    cbModel: TComboBox;
    cbAspectRatio: TComboBox;
    cbSize: TComboBox;
    cbFormat: TComboBox;
    cbThinking: TComboBox;
    chkGoogleSearch: TCheckBox;
    chkImageSearch: TCheckBox;
    grpPrompt: TGroupBox;
    lblPrompt: TLabel;
    lblExemplos: TLabel;
    memPrompt: TMemo;
    cbExemplos: TComboBox;
    grpReferencia: TGroupBox;
    chkUsarRef: TCheckBox;
    edtRefPath: TEdit;
    btnCarregarRef: TButton;
    btnLimparRef: TButton;
    pnlGerar: TPanel;
    lblStatus: TLabel;
    btnGerar: TButton;
    pnlPreviewArea: TPanel;
    pnlActions: TPanel;
    lblInfoImagem: TLabel;
    btnSalvar: TButton;
    btnCopiarBase64: TButton;
    btnLimparPreview: TButton;
    pnlImagemContainer: TPanel;
    lblAguardando: TLabel;
    imgPreview: TImage;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbProviderChange(Sender: TObject);
    procedure btnGerarClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnCopiarBase64Click(Sender: TObject);
    procedure btnLimparPreviewClick(Sender: TObject);
    procedure btnCarregarRefClick(Sender: TObject);
    procedure btnLimparRefClick(Sender: TObject);
    procedure chkUsarRefClick(Sender: TObject);
    procedure chkGoogleSearchClick(Sender: TObject);
    procedure cbExemplosChange(Sender: TObject);
  private
    FLastBytes: TBytes;
    FLastMimeType: string;
    FLastBase64: string;

    procedure ConfigurarControlesIniciais;
    procedure SetCarregando(const ACarregando: Boolean; const AStatus: string = '');
    procedure CarregarBytesNoPreview(const ABytes: TBytes; const AMimeType: string);
    function ObterAspectRatioSelecionado: TLLMImageAspectRatio;
    function ObterImageSizeSelecionado: TLLMImageSize;
    function ObterFormatSelecionado: TLLMImageMimeType;
    function ObterThinkingLevelSelecionado: TLLMImageThinkingLevel;
  public
  end;

var
  FormImagem: TFormImagem;

implementation

{$R *.dfm}

{ TFormImagem }

procedure TFormImagem.FormCreate(Sender: TObject);
begin
  ConfigurarControlesIniciais;
end;

procedure TFormImagem.FormDestroy(Sender: TObject);
begin
  SetLength(FLastBytes, 0);
end;

procedure TFormImagem.ConfigurarControlesIniciais;
begin
  // Provedores
  cbProvider.Items.Clear;
  cbProvider.Items.Add('Pollinations.ai (100% Grátis / Sem API Key / FLUX.1)');
  cbProvider.Items.Add('Google Gemini (Nano Banana / Requer Faturamento)');
  cbProvider.ItemIndex := 0; // Inicia em Pollinations para teste imediato gratuito

  // Aspect Ratios
  cbAspectRatio.Items.Clear;
  cbAspectRatio.Items.Add('1:1 (Quadrado)');
  cbAspectRatio.Items.Add('16:9 (Widescreen)');
  cbAspectRatio.Items.Add('9:16 (Stories/Reels)');
  cbAspectRatio.Items.Add('3:2 (Paisagem)');
  cbAspectRatio.Items.Add('2:3 (Retrato)');
  cbAspectRatio.Items.Add('4:3');
  cbAspectRatio.Items.Add('3:4');
  cbAspectRatio.Items.Add('4:5');
  cbAspectRatio.Items.Add('5:4');
  cbAspectRatio.Items.Add('21:9 (Ultrawide)');
  cbAspectRatio.ItemIndex := 0;

  // Image Size
  cbSize.Items.Clear;
  cbSize.Items.Add('Padrão (1K)');
  cbSize.Items.Add('512px (Rápido)');
  cbSize.Items.Add('1K (1024px)');
  cbSize.Items.Add('2K (2048px)');
  cbSize.Items.Add('4K (Ultra HD)');
  cbSize.ItemIndex := 0;

  // Formato MIME
  cbFormat.Items.Clear;
  cbFormat.Items.Add('JPEG (image/jpeg)');
  cbFormat.Items.Add('PNG (image/png)');
  cbFormat.Items.Add('WebP (image/webp)');
  cbFormat.ItemIndex := 0;

  // Thinking Level
  cbThinking.Items.Clear;
  cbThinking.Items.Add('Padrão (Medium)');
  cbThinking.Items.Add('Minimal');
  cbThinking.Items.Add('Medium');
  cbThinking.Items.Add('High (Máximo Raciocínio)');
  cbThinking.ItemIndex := 0;

  // Exemplos rápidos
  cbExemplos.Items.Clear;
  cbExemplos.Items.Add('(Selecione um exemplo...)');
  cbExemplos.Items.Add('Panda Vermelho kawaii com chapéu de bambu');
  cbExemplos.Items.Add('Cidade futurista cyberpunk à noite com néon');
  cbExemplos.Items.Add('Logotipo minimalista para cafeteria');
  cbExemplos.Items.Add('Fotografia de estúdio de um produto');
  cbExemplos.Items.Add('Infográfico de previsão do tempo');
  cbExemplos.Items.Add('Esboço anatômico da borboleta estilo Da Vinci');
  cbExemplos.ItemIndex := 1;
  cbExemplosChange(nil);

  // Dispara a configuracao dos modelos para o provedor selecionado
  cbProviderChange(nil);
end;

procedure TFormImagem.cbProviderChange(Sender: TObject);
begin
  if cbProvider.ItemIndex = 0 then
  begin
    // Pollinations.ai (Gratis com chave gerada no enter.pollinations.ai via GitHub)
    edtApiKey.TextHint := 'Chave do enter.pollinations.ai (grátis via GitHub)';
    chkGoogleSearch.Enabled := False;
    chkGoogleSearch.Checked := False;
    chkImageSearch.Enabled := False;
    chkImageSearch.Checked := False;
    cbThinking.Enabled := False;
    chkUsarRef.Enabled := False;
    chkUsarRef.Checked := False;
    chkUsarRefClick(nil);

    cbModel.Items.Clear;
    cbModel.Items.Add(POLLINATIONS_MODEL_FLUX + ' (Recomendado - FLUX.1)');
    cbModel.Items.Add(POLLINATIONS_MODEL_TURBO + ' (Ultra-rápido)');
    cbModel.Items.Add(POLLINATIONS_MODEL_REALISM + ' (Fotorealismo)');
    cbModel.Items.Add(POLLINATIONS_MODEL_ANIME + ' (Estilo Anime)');
    cbModel.Items.Add(POLLINATIONS_MODEL_3D + ' (Render 3D)');
    cbModel.ItemIndex := 0;

    lblStatus.Caption := 'Pollinations.ai: Grátis via GitHub em enter.pollinations.ai.';
  end
  else
  begin
    // Google Gemini (Nano Banana)
    edtApiKey.TextHint := 'Cole sua Gemini API Key (AIzaSy...)';
    chkGoogleSearch.Enabled := True;
    cbThinking.Enabled := True;
    chkUsarRef.Enabled := True;

    cbModel.Items.Clear;
    cbModel.Items.Add(GEMINI_MODEL_NANO_BANANA_2_1 + ' (Recomendado)');
    cbModel.Items.Add(GEMINI_MODEL_3_1_FLASH_LITE + ' (Mais rápido / 1K)');
    cbModel.Items.Add(GEMINI_MODEL_3_1_FLASH + ' (Nano Banana 2)');
    cbModel.Items.Add(GEMINI_MODEL_3_PRO + ' (Nano Banana Pro / Interleaved)');
    cbModel.Items.Add(GEMINI_MODEL_2_5_FLASH + ' (Legacy)');
    cbModel.ItemIndex := 0;

    lblStatus.Caption := 'Google Gemini selecionado: Requer chave de API e conta com faturamento ativo.';
  end;
end;

function TFormImagem.ObterAspectRatioSelecionado: TLLMImageAspectRatio;
begin
  case cbAspectRatio.ItemIndex of
    0: Result := ar1_1;
    1: Result := ar16_9;
    2: Result := ar9_16;
    3: Result := ar3_2;
    4: Result := ar2_3;
    5: Result := ar4_3;
    6: Result := ar3_4;
    7: Result := ar4_5;
    8: Result := ar5_4;
    9: Result := ar21_9;
  else
    Result := arDefault;
  end;
end;

function TFormImagem.ObterImageSizeSelecionado: TLLMImageSize;
begin
  case cbSize.ItemIndex of
    1: Result := is512px;
    2: Result := is1K;
    3: Result := is2K;
    4: Result := is4K;
  else
    Result := isDefault;
  end;
end;

function TFormImagem.ObterFormatSelecionado: TLLMImageMimeType;
begin
  case cbFormat.ItemIndex of
    0: Result := imJPEG;
    1: Result := imPNG;
    2: Result := imWebP;
  else
    Result := imDefault;
  end;
end;

function TFormImagem.ObterThinkingLevelSelecionado: TLLMImageThinkingLevel;
begin
  case cbThinking.ItemIndex of
    1: Result := tlMinimal;
    2: Result := tlMedium;
    3: Result := tlHigh;
  else
    Result := tlDefault;
  end;
end;

procedure TFormImagem.cbExemplosChange(Sender: TObject);
begin
  case cbExemplos.ItemIndex of
    1: // Panda Vermelho
    begin
      memPrompt.Text := 'A kawaii-style sticker of a happy red panda wearing a tiny bamboo hat and snacking on green leaves. Bold outlines, vibrant colors, white background.';
      cbAspectRatio.ItemIndex := 0; // 1:1
      cbFormat.ItemIndex := 1; // PNG
    end;
    2: // Cyberpunk
    begin
      memPrompt.Text := 'A cinematic, highly detailed wide shot of a futuristic cyberpunk megacity at night under heavy rain, vibrant neon holograms reflecting on wet asphalt, flying vehicles.';
      cbAspectRatio.ItemIndex := 1; // 16:9
      cbSize.ItemIndex := 3; // 2K
      cbFormat.ItemIndex := 0; // JPEG
    end;
    3: // Logo
    begin
      memPrompt.Text := 'Create a modern, minimalist logo for a coffee shop called ''The Daily Grind''. Bold sans-serif typography, clean geometry, black and white color scheme.';
      cbAspectRatio.ItemIndex := 0; // 1:1
      cbFormat.ItemIndex := 1; // PNG
    end;
    4: // Produto
    begin
      memPrompt.Text := 'A high-resolution, studio-lit commercial product photograph of a matte black ceramic coffee mug on a polished concrete pedestal, three-point softbox lighting, ultra-realistic.';
      cbAspectRatio.ItemIndex := 0; // 1:1
      cbFormat.ItemIndex := 0; // JPEG
    end;
    5: // Clima
    begin
      memPrompt.Text := 'Clean, modern visual weather forecast chart for São Paulo with stylish icons and vibrant temperatures.';
      cbAspectRatio.ItemIndex := 1; // 16:9
      cbFormat.ItemIndex := 0; // JPEG
    end;
    6: // Da Vinci
    begin
      memPrompt.Text := 'Da Vinci style anatomical sketch of a dissected Monarch butterfly. Detailed drawings of head, wings, and legs on aged textured parchment with vintage notes.';
      cbAspectRatio.ItemIndex := 0; // 1:1
      cbSize.ItemIndex := 2; // 1K
      cbFormat.ItemIndex := 0; // JPEG
    end;
  end;
end;

procedure TFormImagem.chkGoogleSearchClick(Sender: TObject);
begin
  chkImageSearch.Enabled := chkGoogleSearch.Checked;
  if not chkGoogleSearch.Checked then
    chkImageSearch.Checked := False;
end;

procedure TFormImagem.chkUsarRefClick(Sender: TObject);
begin
  edtRefPath.Enabled := chkUsarRef.Checked;
  btnCarregarRef.Enabled := chkUsarRef.Checked;
  btnLimparRef.Enabled := chkUsarRef.Checked and (not Trim(edtRefPath.Text).IsEmpty);
end;

procedure TFormImagem.btnCarregarRefClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    edtRefPath.Text := OpenDialog1.FileName;
    btnLimparRef.Enabled := True;
  end;
end;

procedure TFormImagem.btnLimparRefClick(Sender: TObject);
begin
  edtRefPath.Clear;
  btnLimparRef.Enabled := False;
end;

procedure TFormImagem.SetCarregando(const ACarregando: Boolean; const AStatus: string);
begin
  btnGerar.Enabled := not ACarregando;
  grpConfig.Enabled := not ACarregando;
  grpPrompt.Enabled := not ACarregando;
  grpReferencia.Enabled := not ACarregando;

  if ACarregando then
  begin
    Screen.Cursor := crHourGlass;
    lblStatus.Font.Color := clNavy;
    lblStatus.Caption := AStatus;
  end
  else
  begin
    Screen.Cursor := crDefault;
    lblStatus.Font.Color := clWindowText;
    if not AStatus.IsEmpty then
      lblStatus.Caption := AStatus;
  end;
end;

procedure TFormImagem.CarregarBytesNoPreview(const ABytes: TBytes; const AMimeType: string);
var
  LStream: TBytesStream;
  LPng: TPngImage;
  LJpeg: TJPEGImage;
begin
  if Length(ABytes) = 0 then
    Exit;

  LStream := TBytesStream.Create(ABytes);
  try
    try
      if AMimeType.ToLower.Contains('png') then
      begin
        LPng := TPngImage.Create;
        try
          LPng.LoadFromStream(LStream);
          imgPreview.Picture.Assign(LPng);
        finally
          LPng.Free;
        end;
      end
      else
      begin
        LJpeg := TJPEGImage.Create;
        try
          LJpeg.LoadFromStream(LStream);
          imgPreview.Picture.Assign(LJpeg);
        finally
          LJpeg.Free;
        end;
      end;
    except
      // Fallback genérico caso o stream seja tratado nativamente pelo VCL TPicture
      LStream.Position := 0;
      imgPreview.Picture.LoadFromStream(LStream);
    end;

    imgPreview.Visible := True;
    lblAguardando.Visible := False;
    btnSalvar.Enabled := True;
    btnCopiarBase64.Enabled := True;

    lblInfoImagem.Caption := Format('%dx%d  |  %s  |  %d KB', [
      imgPreview.Picture.Width,
      imgPreview.Picture.Height,
      AMimeType,
      Length(ABytes) div 1024
    ]);
  finally
    LStream.Free;
  end;
end;

procedure TFormImagem.btnGerarClick(Sender: TObject);
var
  LIsPollinations: Boolean;
  LProviderType: TImageProviderType;
  LApiKey, LPrompt, LModel: string;
  LReq: TLLMImageRequest;
  LRefPath: string;
  LStopwatch: TStopwatch;
begin
  LIsPollinations := (cbProvider.ItemIndex = 0);
  LApiKey := Trim(edtApiKey.Text);

  // Gemini exige API Key; Pollinations nao exige
  if (not LIsPollinations) and LApiKey.IsEmpty then
  begin
    ShowMessage('Por favor, informe sua Gemini API Key antes de gerar imagens com o Gemini.');
    edtApiKey.SetFocus;
    Exit;
  end;

  LPrompt := Trim(memPrompt.Text);
  if LPrompt.IsEmpty then
  begin
    ShowMessage('Por favor, digite uma descrição (prompt) para a imagem.');
    memPrompt.SetFocus;
    Exit;
  end;

  // Extrai o identificador do modelo (sem a descricao adicional do combobox)
  LModel := cbModel.Text;
  if LModel.Contains(' ') then
    LModel := LModel.Substring(0, LModel.IndexOf(' '));

  // Define o provedor correspondente
  if LIsPollinations then
    LProviderType := iptPollinations
  else
    LProviderType := iptGemini;

  // Monta a requisicao fluente
  LReq := TLLMImageRequest.New(LPrompt)
    .SetModel(LModel)
    .SetAspectRatio(ObterAspectRatioSelecionado)
    .SetImageSize(ObterImageSizeSelecionado)
    .SetFormat(ObterFormatSelecionado)
    .SetThinkingLevel(ObterThinkingLevelSelecionado)
    .EnableGoogleSearch(chkGoogleSearch.Checked, chkImageSearch.Checked);

  // Se tiver imagem de referencia ativada
  if chkUsarRef.Checked then
  begin
    LRefPath := Trim(edtRefPath.Text);
    if not LRefPath.IsEmpty and FileExists(LRefPath) then
      LReq.AddReferenceFile(LRefPath);
  end;

  if LIsPollinations then
    SetCarregando(True, 'Gerando imagem gratuitamente via Pollinations.ai (FLUX.1)...')
  else
    SetCarregando(True, 'Enviando requisição ao Google Gemini Nano Banana...');

  LStopwatch := TStopwatch.StartNew;

  // Executa em thread separada para não congelar a interface VCL
  TThread.CreateAnonymousThread(
    procedure
    var
      LProvider: ILLMImageProvider;
      LResp: ILLMImageResponse;
      LBytes: TBytes;
      LMime, LBase64, LTextResp, LErro: string;
    begin
      LErro := EmptyStr;
      SetLength(LBytes, 0);
      LMime := EmptyStr;
      LBase64 := EmptyStr;
      LTextResp := EmptyStr;

      try
        LProvider := CreateImageProvider(LProviderType, LApiKey, LModel);
        LResp := LProvider.Generate(LReq);

        if LResp.HasImages then
        begin
          LBytes := LResp.First.AsBytes;
          LMime := LResp.First.MimeType;
          LBase64 := LResp.First.Base64;
          LTextResp := LResp.Text;
        end
        else
        begin
          LErro := 'A API respondeu mas não retornou nenhuma imagem.';
        end;
      except
        on E: Exception do
          LErro := E.Message;
      end;

      LStopwatch.Stop;

      // Retorna para a thread principal da interface
      TThread.Synchronize(nil,
        procedure
        var
          LElapsedSec: Double;
        begin
          LElapsedSec := LStopwatch.ElapsedMilliseconds / 1000.0;

          if not LErro.IsEmpty then
          begin
            SetCarregando(False, Format('Erro (%.2fs): %s', [LElapsedSec, LErro]));
            ShowMessage('Erro ao gerar imagem:'#13#10 + LErro);
          end
          else
          begin
            FLastBytes := LBytes;
            FLastMimeType := LMime;
            FLastBase64 := LBase64;

            CarregarBytesNoPreview(FLastBytes, FLastMimeType);

            if not LTextResp.IsEmpty then
              SetCarregando(False, Format('Sucesso em %.2fs! %s', [LElapsedSec, LTextResp]))
            else
              SetCarregando(False, Format('Imagem gerada com sucesso em %.2fs!', [LElapsedSec]));
          end;
        end);
    end
  ).Start;
end;

procedure TFormImagem.btnSalvarClick(Sender: TObject);
begin
  if Length(FLastBytes) = 0 then
    Exit;

  if FLastMimeType.Contains('png') then
  begin
    SaveDialog1.DefaultExt := 'png';
    SaveDialog1.FilterIndex := 2;
    SaveDialog1.FileName := 'imagem_gerada.png';
  end
  else
  begin
    SaveDialog1.DefaultExt := 'jpg';
    SaveDialog1.FilterIndex := 1;
    SaveDialog1.FileName := 'imagem_gerada.jpg';
  end;

  if SaveDialog1.Execute then
  begin
    try
      TFile.WriteAllBytes(SaveDialog1.FileName, FLastBytes);
      ShowMessage(Format('Imagem salva com sucesso em:'#13#10'%s', [SaveDialog1.FileName]));
    except
      on E: Exception do
        ShowMessage('Falha ao salvar arquivo: ' + E.Message);
    end;
  end;
end;

procedure TFormImagem.btnCopiarBase64Click(Sender: TObject);
begin
  if FLastBase64.IsEmpty then
    Exit;

  Clipboard.AsText := FLastBase64;
  ShowMessage('String Base64 copiada para a área de transferência com sucesso!');
end;

procedure TFormImagem.btnLimparPreviewClick(Sender: TObject);
begin
  imgPreview.Picture := nil;
  imgPreview.Visible := False;
  lblAguardando.Visible := True;
  lblInfoImagem.Caption := EmptyStr;
  btnSalvar.Enabled := False;
  btnCopiarBase64.Enabled := False;
  SetLength(FLastBytes, 0);
  FLastBase64 := EmptyStr;
  lblStatus.Caption := 'Preview limpo. Pronto para nova geração.';
end;

end.
