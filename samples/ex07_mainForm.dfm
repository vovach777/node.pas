object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 299
  ClientWidth = 634
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    634
    299)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 50
    Height = 13
    Caption = 'Request:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Edit1: TEdit
    Left = 64
    Top = 8
    Width = 482
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    Text = 
      'https://raw.githubusercontent.com/vovach777/node.pas/master/READ' +
      'ME.md'
  end
  object Button1: TButton
    Left = 552
    Top = 8
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'GET'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Memo1: TMemo
    Left = 8
    Top = 35
    Width = 619
    Height = 256
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      
        'This example demonstrates the operation of several options for t' +
        'he framework: JSON Parser, Promise, Http (s) request. And '
      'it also shows how to build an Event Loop into a GUI application.')
    TabOrder = 2
  end
  object ApplicationEvents1: TApplicationEvents
    OnMessage = ApplicationEvents1Message
    Left = 16
    Top = 88
  end
  object Timer1: TTimer
    Interval = 10
    OnTimer = Timer1Timer
    Left = 56
    Top = 88
  end
end
