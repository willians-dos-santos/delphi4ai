object FormImagem: TFormImagem
  Left = 0
  Top = 0
  Caption = 'Delphi4AI - Gera'#231#227'o de Imagens (Pollinations.ai / Google Gemini)'
  ClientHeight = 700
  ClientWidth = 1040
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlControls: TPanel
    Left = 0
    Top = 0
    Width = 435
    Height = 700
    Align = alLeft
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 8
    Padding.Right = 8
    Padding.Bottom = 8
    TabOrder = 0
    object grpConfig: TGroupBox
      Left = 8
      Top = 8
      Width = 419
      Height = 205
      Align = alTop
      Caption = ' Configura'#231#245'es do Provedor '
      TabOrder = 0
      object lblProvider: TLabel
        Left = 12
        Top = 22
        Width = 51
        Height = 15
        Caption = 'Provedor:'
      end
      object lblApiKey: TLabel
        Left = 12
        Top = 52
        Width = 43
        Height = 15
        Caption = 'API Key:'
      end
      object lblModel: TLabel
        Left = 12
        Top = 81
        Width = 44
        Height = 15
        Caption = 'Modelo:'
      end
      object lblAspectRatio: TLabel
        Left = 12
        Top = 111
        Width = 39
        Height = 15
        Caption = 'Aspect:'
      end
      object lblSize: TLabel
        Left = 215
        Top = 111
        Width = 53
        Height = 15
        Caption = 'Tamanho:'
      end
      object lblFormat: TLabel
        Left = 12
        Top = 141
        Width = 48
        Height = 15
        Caption = 'Formato:'
      end
      object lblThinking: TLabel
        Left = 215
        Top = 141
        Width = 49
        Height = 15
        Caption = 'Thinking:'
      end
      object cbProvider: TComboBox
        Left = 70
        Top = 19
        Width = 336
        Height = 23
        Style = csDropDownList
        TabOrder = 0
        OnChange = cbProviderChange
      end
      object edtApiKey: TEdit
        Left = 70
        Top = 49
        Width = 336
        Height = 23
        PasswordChar = '*'
        TabOrder = 1
        TextHint = 'Opcional para Pollinations (100% gr'#225'tis)'
      end
      object cbModel: TComboBox
        Left = 70
        Top = 78
        Width = 336
        Height = 23
        Style = csDropDownList
        TabOrder = 2
      end
      object cbAspectRatio: TComboBox
        Left = 70
        Top = 108
        Width = 130
        Height = 23
        Style = csDropDownList
        TabOrder = 3
      end
      object cbSize: TComboBox
        Left = 276
        Top = 108
        Width = 130
        Height = 23
        Style = csDropDownList
        TabOrder = 4
      end
      object cbFormat: TComboBox
        Left = 70
        Top = 138
        Width = 130
        Height = 23
        Style = csDropDownList
        TabOrder = 5
      end
      object cbThinking: TComboBox
        Left = 276
        Top = 138
        Width = 130
        Height = 23
        Style = csDropDownList
        TabOrder = 6
      end
      object chkGoogleSearch: TCheckBox
        Left = 12
        Top = 173
        Width = 180
        Height = 17
        Caption = 'Grounding Google Search'
        Enabled = False
        TabOrder = 7
        OnClick = chkGoogleSearchClick
      end
      object chkImageSearch: TCheckBox
        Left = 205
        Top = 173
        Width = 200
        Height = 17
        Caption = 'Incluir Google Image Search'
        Enabled = False
        TabOrder = 8
      end
    end
    object grpPrompt: TGroupBox
      Left = 8
      Top = 213
      Width = 419
      Height = 195
      Align = alTop
      Caption = ' Prompt Visual '
      TabOrder = 1
      object lblPrompt: TLabel
        Left = 12
        Top = 22
        Width = 202
        Height = 15
        Caption = 'Descreva a imagem que deseja gerar:'
      end
      object lblExemplos: TLabel
        Left = 12
        Top = 155
        Width = 98
        Height = 15
        Caption = 'Exemplos r'#225'pidos:'
      end
      object memPrompt: TMemo
        Left = 12
        Top = 42
        Width = 394
        Height = 98
        Lines.Strings = (
          'A photo of a cute red panda wearing a tiny bamboo hat and snacking on green leaves, studio lighting, detailed fur')
        ScrollBars = ssVertical
        TabOrder = 0
      end
      object cbExemplos: TComboBox
        Left = 118
        Top = 152
        Width = 288
        Height = 23
        Style = csDropDownList
        TabOrder = 1
        OnChange = cbExemplosChange
      end
    end
    object grpReferencia: TGroupBox
      Left = 8
      Top = 408
      Width = 419
      Height = 100
      Align = alTop
      Caption = ' Imagem de Refer'#234'ncia / Edi'#231#227'o (Gemini) '
      TabOrder = 2
      object chkUsarRef: TCheckBox
        Left = 12
        Top = 24
        Width = 394
        Height = 17
        Caption = 'Ativar Edi'#231#227'o / Image-to-Image'
        TabOrder = 0
        OnClick = chkUsarRefClick
      end
      object edtRefPath: TEdit
        Left = 12
        Top = 53
        Width = 265
        Height = 23
        Color = clBtnFace
        Enabled = False
        ReadOnly = True
        TabOrder = 1
        TextHint = 'Nenhuma imagem selecionada'
      end
      object btnCarregarRef: TButton
        Left = 285
        Top = 52
        Width = 72
        Height = 25
        Caption = 'Abrir...'
        Enabled = False
        TabOrder = 2
        OnClick = btnCarregarRefClick
      end
      object btnLimparRef: TButton
        Left = 362
        Top = 52
        Width = 44
        Height = 25
        Caption = 'X'
        Enabled = False
        TabOrder = 3
        OnClick = btnLimparRefClick
      end
    end
    object pnlGerar: TPanel
      Left = 8
      Top = 508
      Width = 419
      Height = 184
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 3
      object lblStatus: TLabel
        Left = 12
        Top = 64
        Width = 394
        Height = 90
        AutoSize = False
        Caption = 'Pronto. Selecione Pollinations para testar gr'#225'tis ou Gemini se tiver faturamento ativo.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        WordWrap = True
      end
      object btnGerar: TButton
        Left = 12
        Top = 12
        Width = 394
        Height = 44
        Caption = #9889' Gerar Imagem'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
        OnClick = btnGerarClick
      end
    end
  end
  object pnlPreviewArea: TPanel
    Left = 435
    Top = 0
    Width = 605
    Height = 700
    Align = alClient
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 8
    Padding.Right = 8
    Padding.Bottom = 8
    TabOrder = 1
    object pnlActions: TPanel
      Left = 8
      Top = 644
      Width = 589
      Height = 48
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 0
      object lblInfoImagem: TLabel
        Left = 410
        Top = 15
        Width = 170
        Height = 15
        Alignment = taRightJustify
        AutoSize = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object btnSalvar: TButton
        Left = 8
        Top = 10
        Width = 135
        Height = 30
        Caption = #128190' Salvar Imagem...'
        Enabled = False
        TabOrder = 0
        OnClick = btnSalvarClick
      end
      object btnCopiarBase64: TButton
        Left = 150
        Top = 10
        Width = 135
        Height = 30
        Caption = #128203' Copiar Base64'
        Enabled = False
        TabOrder = 1
        OnClick = btnCopiarBase64Click
      end
      object btnLimparPreview: TButton
        Left = 292
        Top = 10
        Width = 90
        Height = 30
        Caption = #128465' Limpar'
        TabOrder = 2
        OnClick = btnLimparPreviewClick
      end
    end
    object pnlImagemContainer: TPanel
      Left = 8
      Top = 8
      Width = 589
      Height = 636
      Align = alClient
      BevelOuter = bvLowered
      Color = clWhite
      ParentBackground = False
      TabOrder = 1
      object lblAguardando: TLabel
        Left = 1
        Top = 1
        Width = 587
        Height = 634
        Align = alClient
        Alignment = taCenter
        Caption = 'A imagem gerada aparecer'#225' aqui.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clSilver
        Font.Height = -16
        Font.Name = 'Segoe UI'
        Font.Style = []
        Layout = tlCenter
        ParentFont = False
        ExplicitWidth = 241
        ExplicitHeight = 21
      end
      object imgPreview: TImage
        Left = 1
        Top = 1
        Width = 587
        Height = 634
        Align = alClient
        Center = True
        Proportional = True
        Stretch = True
        Visible = False
      end
    end
  end
  object OpenDialog1: TOpenDialog
    Filter = 
      'Arquivos de Imagem (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;' +
      '*.webp|Todos os Arquivos (*.*)|*.*'
    Title = 'Selecionar Imagem de Refer'#234'ncia'
    Left = 472
    Top = 120
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'jpg'
    Filter = 'JPEG Image (*.jpg)|*.jpg|PNG Image (*.png)|*.png'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Salvar Imagem Gerada'
    Left = 560
    Top = 120
  end
end
