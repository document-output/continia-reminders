pageextension 61185 "Temp Appr Req Entry List Ext" extends "Approval Request Entries"
{
    actions
    {
        addlast(Processing)
        {
            action(EventEntries)
            {
                ApplicationArea = All;
                Caption = 'Event Register Entries';
                Image = EntriesList;
                RunObject = page "Temp CDC Event Reg. List";
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
            }
            action(ActionName)
            {
                ApplicationArea = All;
                Caption = 'Send Notifications with Document Output';
                Image = SendMail;
                RunObject = codeunit "DOADV Send DC Reminders via JQ";
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
            }
        }
    }
}