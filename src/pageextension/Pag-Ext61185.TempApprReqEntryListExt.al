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
            action(SendNotifications)
            {
                ApplicationArea = All;
                Caption = 'Send Notifications with Document Output';
                Image = SendMail;
                RunObject = codeunit "DOADV Send DC Reminders via JQ";
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
            }
            action(StartDispatcher)
            {
                ApplicationArea = All;
                Caption = 'Start Dispatcher';
                Image = "Start";
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Starts running the queue entries.';
                trigger OnAction()
                var
                    DocOutputQueueMgt: Codeunit "CDO Queue Management";
                begin
                    DocOutputQueueMgt.SendQueue(-1);
                end;

            }
        }
    }
}