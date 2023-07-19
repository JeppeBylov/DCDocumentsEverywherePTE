#pragma warning disable AA0072
page 50100 "DC Addin GLEntries BYL"
{
    Caption = 'Document Capture Client Addin';
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = ListPart;
    Permissions = TableData 6085780 = rimd;
    SourceTable = "G/L Entry";

    layout
    {
        area(content)
        {

            usercontrol(CaptureUIWeb; "CDC Capture UI AddIn")
            {
                Visible = SHOWCAPTUREWEBUI;
                ApplicationArea = All;

                trigger OnControlAddIn(index: Integer; data: Text)
                begin
                    OnControlAddInEvent(Index, Data);
                end;

                trigger AddInReady()
                begin
                    AddInReady := true;
                    UpdatePage();
                end;
            }
        }
    }

    actions
    {
    }

    trigger OnAfterGetRecord()
    var
        PurchCrMemoHdr: record "Purch. Cr. Memo Hdr.";
        PurchInvHeader: Record "Purch. Inv. Header";
        PreAssNo: Code[20];
        DocType: Integer;
    begin
        if GuiAllowed then begin

            PreAssNo := '';
            case Rec."Document Type" of
                Rec."Document Type"::Invoice:
                    begin
                        DocType := 2;
                        if PurchInvHeader.GET(Rec."Document No.") then
                            PreAssNo := PurchInvHeader."Pre-Assigned No.";
                    end;
                Rec."Document Type"::"Credit Memo":
                    begin
                        DocType := 3;
                        if PurchCrMemoHdr.GET(Rec."Document No.") then
                            PreAssNo := PurchCrMemoHdr."Pre-Assigned No.";
                    end;
            end;
            if ((Rec."Document Type" <> xRec."Document Type") or (Rec."Document No." <> xRec."Document No.")) and (DocType <> 0) then begin
                Document.SETCURRENTKEY("Created Doc. Table No.", "Created Doc. Subtype", "Created Doc. No.", "Created Doc. Ref. No.");
                Document.SETRANGE("Created Doc. Table No.", DATABASE::"Purchase Header");
                Document.SETRANGE("Created Doc. Subtype", DocType);
                Document.SETRANGE("Created Doc. No.", PreAssNo);
                Document.SETFILTER("File Type", '%1|%2', Document."File Type"::OCR, Document."File Type"::XML);
                if not Document.FINDFIRST() then
                    CLEAR(Document);
                UpdateImage();
                SendCommand(CaptureXmlDoc);
            end else
                if (SendAllPendingCommands and (not CaptureXmlDoc.IsEmpty())) then begin
                    SendAllPendingCommands := false;
                    SendCommand(CaptureXmlDoc);
                end;

        end
    end;

    trigger OnOpenPage()
    begin
        if ContiniaUserProp.GET(USERID) and (ContiniaUserProp."Image Zoom" > 0) then
            CurrZoom := ContiniaUserProp."Image Zoom"
        else
            CurrZoom := 50;

        ShowCaptureWebUI := WebClientMgt.IsWebClient();

        if ContiniaUserProp.GET(USERID) and (ContiniaUserProp."Add-In Min Width" > 0) then
            AddInWidth := ContiniaUserProp."Add-In Min Width"
        else
            AddInWidth := 725;

        CaptureAddinLib.BuildSetAddInWidthCommand(AddInWidth, CaptureXmlDoc);
    end;

    var
        ContiniaUserProp: Record "CDC Continia User Property";
        Document: Record "cdc document";
        CaptureAddinLib: Codeunit "CDC Capture RTC Library";
        TIFFMgt: Codeunit "CDC TIFF Management";
        WebClientMgt: Codeunit "CDC Web Client Management";
        CaptureXmlDoc: Codeunit "CSC XML Document";
        AddInReady: Boolean;
        SendAllPendingCommands: Boolean;
        [InDataSet]
        ShowCaptureWebUI: Boolean;
        CurrZoom: Decimal;
        AddInWidth: Integer;
        CurrentPageNo: Integer;
        PageInTotalLbl: Label '(1 page in total)';
        PagesInTotalLbl: Label '(%1 pages in total)', Comment = '%1 show the number of pages';
        PageNoLbl: Label 'Page %1', Comment = '%1 Shows the page number';
        CaptureUISource: Text;
        CurrentZoomText: Text[30];
        HeaderFieldsFormName: Text[50];
        LineFieldsFormName: Text[50];
        CurrentPageText: Text[30];

    procedure UpdateImage()
    var
        "Page": Record "CDC Document Page";
        TempFile: Record "CDC Temp File" temporary;
        HasImage: Boolean;
        FileName: Text[1024];
    begin
        if Document."No." = '' then
            if not WebClientMgt.IsWebClient() then
                CaptureAddinLib.BuildSetImageCommand(FileName, true, CaptureXmlDoc);

        if Document."File Type" = Document."File Type"::XML then
            HasImage := Document.GetVisualFile(TempFile)
        else
            if WebClientMgt.IsWebClient() then begin
                HasImage := Document.GetPngFile(TempFile, 1);
                if not HasImage then
                    HasImage := Document.GetTiffFile(TempFile);
            end else
                HasImage := Document.GetTiffFile(TempFile);

        if (FileName = '') and not HasImage then begin
            CaptureAddinLib.BuildClearImageCommand(CaptureXmlDoc);
            UpdateCurrPageNo(0);
            exit;
        end else
            if (FileName = '') and not WebClientMgt.IsWebClient() then begin
                FileName := CopyStr(TempFile.GetClientFilePath(), 1, 1024);
                CaptureAddinLib.BuildSetImageCommand(FileName, true, CaptureXmlDoc);
            end else
                if Document."File Type" = Document."File Type"::XML then
                    CaptureAddinLib.BuildSetImageDataCommand(TempFile.GetContentAsDataUrl(), true, CaptureXmlDoc);


        UpdateCurrPageNo(1);

        CaptureAddinLib.BuildScrollTopCommand(CaptureXmlDoc);

        if (ContiniaUserProp."Image Zoom" = 0) and (Page.GET(Document."No.", 1)) and (Page.Width > 0) then begin
            if not WebClientMgt.IsWebClient() then
                CurrZoom := ROUND(((AddInWidth - 50) / Page.Width) * 100, 1, '<')
            else
                CurrZoom := ROUND(((AddInWidth - 80) / Page.Width) * 100, 1, '<');
        end else
            CurrZoom := ContiniaUserProp."Image Zoom";

        Zoom(CurrZoom, false);

        if Document."No. of Pages" = 1 then
            CaptureAddinLib.BuildTotalNoOfPagesTextCommand(PageInTotalLbl, CaptureXmlDoc)
        else
            CaptureAddinLib.BuildTotalNoOfPagesTextCommand(STRSUBSTNO(PagesInTotalLbl, Document."No. of Pages"), CaptureXmlDoc);
    end;

    procedure UpdateCurrPageNo(PageNo: Integer)
    var
        TempFile: Record "CDC Temp File" temporary;
        ImageManagement: Codeunit "CDC Image Management";
        ImageDataUrl: Text;
    begin
        Document.CALCFIELDS("No. of Pages");

        CurrentPageNo := PageNo;
        CurrentPageText := STRSUBSTNO(PageNoLbl, CurrentPageNo);

        if (WebClientMgt.IsWebClient() and (PageNo > 0)) then begin
            if Document.GetPngFile(TempFile, PageNo) then
                ImageDataUrl := ImageManagement.GetImageDataAsJpegDataUrl(TempFile, 100)
            else
                if Document.GetTiffFile(TempFile) then
                    ImageDataUrl := TIFFMgt.GetPageAsDataUrl(TempFile, PageNo, false);

            if ImageDataUrl <> '' then
                CaptureAddinLib.BuildSetImageDataCommand(ImageDataUrl, true, CaptureXmlDoc);
        end;

        CaptureAddinLib.BuildSetActivePageCommand(PageNo, CurrentPageText, CaptureXmlDoc);
    end;

    procedure ParsePageText(PageText: Text[30])
    var
        NewPageNo: Integer;
    begin
        if STRPOS(PageText, ' ') = 0 then begin
            if EVALUATE(NewPageNo, PageText) then;
        end else
            if EVALUATE(NewPageNo, COPYSTR(PageText, STRPOS(PageText, ' '))) then;

        Document.CALCFIELDS("No. of Pages");
        if (NewPageNo <= 0) or (NewPageNo > Document."No. of Pages") then
            UpdateCurrPageNo(CurrentPageNo)
        else
            UpdateCurrPageNo(NewPageNo);
    end;

    procedure Zoom(ZoomPct: Decimal; UpdateUserProp: Boolean)
    begin
        if ZoomPct < 1 then
            ZoomPct := 1;
        CurrZoom := ZoomPct;
        CurrentZoomText := FORMAT(CurrZoom) + '%';

        if UpdateUserProp then
            if not ContiniaUserProp.GET(USERID) then begin
                ContiniaUserProp.init();
                ContiniaUserProp."User ID" := CopyStr(UserId, 0, 50);
                ContiniaUserProp."Image Zoom" := CurrZoom;
                ContiniaUserProp.INSERT();
            end else
                if ContiniaUserProp."Image Zoom" <> CurrZoom then begin
                    ContiniaUserProp."Image Zoom" := CurrZoom;
                    ContiniaUserProp.MODIFY();
                end;

        CaptureAddinLib.BuildZoomCommand(CurrZoom, CaptureXmlDoc);
        CaptureAddinLib.BuildZoomTextCommand(CurrentZoomText, CaptureXmlDoc);
    end;

    procedure SendCommand(var XmlDoc: Codeunit "CSC XML Document")
    var
        NewXmlDoc: Codeunit "CSC XML Document";
    begin
        if not AddInReady and WebClientMgt.IsWebClient() then
            exit;

        CaptureAddinLib.XmlToText(XmlDoc, CaptureUISource);
        CaptureAddinLib.TextToXml(NewXmlDoc, CaptureUISource);

        if WebClientMgt.IsWebClient() then
            CurrPage.CaptureUIWeb.SourceValueChanged(CaptureUISource);

        CLEAR(CaptureXmlDoc);
    end;

    procedure SetConfig(NewHeaderFieldsFormName: Text[50]; NewLineFieldsFormName: Text[50]; NewChannel: Code[50])
    begin
        HeaderFieldsFormName := NewHeaderFieldsFormName;
        LineFieldsFormName := NewLineFieldsFormName;
    end;

    procedure HandleSimpleCommand(Command: Text[1024])
    begin
        case Command of
            'ZoomIn':
                Zoom(ROUND(CurrZoom, 5, '<') + 5, true);

            'ZoomOut':
                Zoom(ROUND(CurrZoom, 5, '>') - 5, true);

            'FirstPage':
                begin
                    Document.CALCFIELDS("No. of Pages");
                    if Document."No. of Pages" > 0 then
                        UpdateCurrPageNo(1);
                end;

            'NextPage':
                begin
                    Document.CALCFIELDS("No. of Pages");
                    if CurrentPageNo < Document."No. of Pages" then
                        UpdateCurrPageNo(CurrentPageNo + 1);
                end;

            'PrevPage':
                if CurrentPageNo > 1 then
                    UpdateCurrPageNo(CurrentPageNo - 1);

            'LastPage':
                begin
                    Document.CALCFIELDS("No. of Pages");
                    UpdateCurrPageNo(Document."No. of Pages");
                end;
        end;

        SendCommand(CaptureXmlDoc);
    end;

    procedure HandleXmlCommand(Command: Text[1024]; var InXmlDoc: Codeunit "CSC XML Document")
    var
        XmlLib: Codeunit "CDC Xml Library";
        DocumentElement: Codeunit "CSC XML Node";
    begin
        InXmlDoc.GetDocumentElement(DocumentElement);
        case Command of
            'ZoomTextChanged':
                begin
                    CurrentZoomText := CopyStr(XmlLib.GetNodeText(DocumentElement, 'Text'), 1, 30);
                    if EVALUATE(CurrZoom, DELCHR(CurrentZoomText, '=', '%')) then;
                    Zoom(CurrZoom, true);
                end;

            'PageTextChanged':
                begin
                    CurrentPageText := CopyStr(XmlLib.GetNodeText(DocumentElement, 'Text'), 1, 30);
                    ParsePageText(CurrentPageText);
                end;

            'ChangePage':
                UpdateCurrPageNo(XmlLib.Text2Int(XmlLib.GetNodeText(DocumentElement, 'NewPageNo')));

            'InfoPaneResized':
                AddInWidth := XmlLib.Text2Int(XmlLib.GetNodeText(DocumentElement, 'Width'));
        end;

        if not CaptureXmlDoc.IsEmpty() then
            SendCommand(CaptureXmlDoc);
    end;

    procedure SetSendAllPendingCommands(NewSendAllPendingCommands: Boolean)
    begin
        SendAllPendingCommands := NewSendAllPendingCommands;
    end;

    procedure ClearImage()
    begin
        CaptureAddinLib.BuildClearImageCommand(CaptureXmlDoc);
        UpdateCurrPageNo(0);
        SendCommand(CaptureXmlDoc);
        CurrPage.UPDATE(false);
    end;

    procedure UpdatePage()
    begin
        UpdateImage();
        CaptureAddinLib.BuildCaptureEnabledCommand(false, CaptureXmlDoc);
        SendCommand(CaptureXmlDoc);
        CurrPage.UPDATE(false);
    end;

    local procedure OnControlAddInEvent(Index: Integer; Data: Variant)
    var
        XmlLib: Codeunit "CDC Xml Library";
        InXmlDoc: Codeunit "CSC XML Document";
        DocumentElement: Codeunit "CSC XML Node";
    begin
        if Index = 0 then
            HandleSimpleCommand(Data)
        else begin
            CaptureAddinLib.TextToXml(InXmlDoc, Data);
            InXmlDoc.GetDocumentElement(DocumentElement);
            if WebClientMgt.IsWebClient() then
                HandleXmlCommand(CopyStr(XmlLib.GetNodeText(DocumentElement, 'Event'), 1, 1024), InXmlDoc)
            else
                HandleXmlCommand(CopyStr(XmlLib.GetNodeText(DocumentElement, 'Command'), 1, 1024), InXmlDoc);
        end;
    end;
#pragma warning restore
}