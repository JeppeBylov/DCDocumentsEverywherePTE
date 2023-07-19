#pragma warning disable AA0072
pageextension 50100 "DC Documents GL Entries BYL" extends "General Ledger Entries"
{
    layout
    {
        addfirst(FactBoxes)
        {
            part(CDCCaptureUI; "DC Addin GLEntries BYL")
            {
                Caption = 'Document';
                SubPageLink = "Entry No." = field("Entry No.");
                SubPageView = sorting("Entry No.");
                ApplicationArea = Basic, Suite;
                AccessByPermission = tabledata "CDC Document Capture Setup" = R;
                Visible = CDCHasDCDocument;
            }
        }
    }
    var
        CDCHasAccess: Boolean;
        CDCHasDCDocument: Boolean;

    trigger OnOpenPage()
    begin
        CDCCheckIfHasAccess();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        if CDCHasAccess then
            CDCEnableFields();
    end;

    local procedure CDCEnableFields();
    begin
        CDCHasDCDocument := HasDocumentsVendLedgEntry(Rec);
    end;

    local procedure HasDocumentsVendLedgEntry(GLEntry: record "G/L Entry"): Boolean
    var
        Doc: Record "CDC Document";
        PurchCrMemoHdr: record "Purch. Cr. Memo Hdr.";
        PurchInvHeader: Record "Purch. Inv. Header";
        PreAssNo: Code[20];
        DocType: Integer;

    begin

        PreAssNo := '';
        case GLEntry."Document Type" of
            GLEntry."Document Type"::Invoice:
                begin
                    DocType := 2;
                    if PurchInvHeader.GET(GLEntry."Document No.") then
                        PreAssNo := PurchInvHeader."Pre-Assigned No.";
                end;
            GLEntry."Document Type"::"Credit Memo":
                begin
                    DocType := 3;
                    if PurchCrMemoHdr.GET(GLEntry."Document No.") then
                        PreAssNo := PurchCrMemoHdr."Pre-Assigned No.";
                end;
            else
                exit(false);
        end;

        Doc.SETCURRENTKEY("Created Doc. Table No.", "Created Doc. Subtype", "Created Doc. No.", "Created Doc. Ref. No.");
        Doc.SETRANGE("Created Doc. Table No.", DATABASE::"Purchase Header");
        Doc.SETRANGE("Created Doc. Subtype", DocType);
        Doc.SETRANGE("Created Doc. No.", PreAssNo);
        Doc.SETFILTER("File Type", '%1|%2', Doc."File Type"::OCR, Doc."File Type"::XML);
        exit(not Doc.ISEMPTY);

    end;

    local procedure CDCCheckIfHasAccess()
    var
        CDCLicenseMgt: Codeunit "CDC Continia License Mgt.";
    begin
        CDCHasAccess := CDCLicenseMgt.HasAccessToDC();
    end;

}
#pragma warning restore