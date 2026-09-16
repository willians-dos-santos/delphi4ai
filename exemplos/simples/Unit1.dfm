object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Delphi4AI - Exemplo Simples (Chat VCL)'
  ClientHeight = 600
  ClientWidth = 780
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
  object pnlConfig: TPanel
    Left = 0
    Top = 0
    Width = 780
    Height = 150
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 8
    Padding.Right = 8
    Padding.Bottom = 8
    TabOrder = 0
    ExplicitWidth = 778
    object grpConfig: TGroupBox
      Left = 8
      Top = 8
      Width = 764
      Height = 134
      Align = alClient
      Caption = ' Configura'#231#245'es do Provedor de IA '
      TabOrder = 0
      ExplicitWidth = 762
      object lblBaseURL: TLabel
        Left = 16
        Top = 24
        Width = 51
        Height = 15
        Caption = 'Base URL:'
      end
      object lblModel: TLabel
        Left = 472
        Top = 24
        Width = 44
        Height = 15
        Caption = 'Modelo:'
      end
      object lblApiKey: TLabel
        Left = 16
        Top = 52
        Width = 43
        Height = 15
        Caption = 'API Key:'
      end
      object lblStrategy: TLabel
        Left = 472
        Top = 52
        Width = 54
        Height = 15
        Caption = 'Estrat'#233'gia:'
      end
      object lblSystemPrompt: TLabel
        Left = 16
        Top = 80
        Width = 84
        Height = 15
        Caption = 'System Prompt:'
      end
      object lblInfo: TLabel
        Left = 256
        Top = 108
        Width = 457
        Height = 13
        Caption = 
          'Dica: voc'#234' tamb'#233'm pode usar Groq, Ollama (localhost:11434) ou qu' +
          'alquer API compat'#237'vel!'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object edtBaseURL: TEdit
        Left = 104
        Top = 21
        Width = 350
        Height = 23
        TabOrder = 0
        Text = 'http://localhost:11434/v1/chat/completions'
      end
      object edtModel: TEdit
        Left = 536
        Top = 21
        Width = 210
        Height = 23
        TabOrder = 1
        Text = 'gpt-oss:120b-cloud'
      end
      object edtApiKey: TEdit
        Left = 104
        Top = 49
        Width = 350
        Height = 23
        PasswordChar = '*'
        TabOrder = 2
        TextHint = 'Cole sua API Key aqui (sk-...)'
      end
      object cbbStrategy: TComboBox
        Left = 536
        Top = 49
        Width = 210
        Height = 23
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 3
        Text = 'Janela Deslizante (Sliding Window)'
        OnChange = cbbStrategyChange
        Items.Strings = (
          'Janela Deslizante (Sliding Window)'
          'Sumariza'#231#227'o (Summarize)'
          'Sem Poda (None)')
      end
      object edtSystemPrompt: TEdit
        Left = 104
        Top = 77
        Width = 642
        Height = 23
        TabOrder = 4
        Text = 'Voc'#234' '#233' um assistente prestativo e amig'#225'vel.'
      end
      object btnAplicar: TButton
        Left = 104
        Top = 104
        Width = 140
        Height = 24
        Caption = 'Reiniciar Conversa'
        TabOrder = 5
        OnClick = btnAplicarClick
      end
    end
  end
  object pnlClient: TPanel
    Left = 0
    Top = 150
    Width = 780
    Height = 385
    Align = alClient
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Right = 8
    TabOrder = 1
    ExplicitWidth = 778
    ExplicitHeight = 377
    object memChat: TMemo
      Left = 8
      Top = 0
      Width = 764
      Height = 385
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
      ExplicitWidth = 762
      ExplicitHeight = 377
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 535
    Width = 780
    Height = 65
    Align = alBottom
    BevelOuter = bvNone
    Padding.Left = 8
    Padding.Top = 4
    Padding.Right = 8
    Padding.Bottom = 8
    TabOrder = 2
    ExplicitTop = 527
    ExplicitWidth = 778
    object lblStatus: TLabel
      Left = 8
      Top = 42
      Width = 138
      Height = 15
      Caption = 'Mensagens no hist'#243'rico: 0'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object edtInput: TEdit
      Left = 8
      Top = 10
      Width = 660
      Height = 25
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      TextHint = 'Digite sua mensagem e pressione Enter ou clique em Enviar...'
      OnKeyDown = edtInputKeyDown
    end
    object btnEnviar: TButton
      Left = 676
      Top = 10
      Width = 96
      Height = 25
      Caption = 'Enviar'
      Default = True
      TabOrder = 1
      OnClick = btnEnviarClick
    end
    object btnLimpar: TButton
      Left = 676
      Top = 38
      Width = 96
      Height = 22
      Caption = 'Limpar Chat'
      TabOrder = 2
      OnClick = btnLimparClick
    end
  end
end
