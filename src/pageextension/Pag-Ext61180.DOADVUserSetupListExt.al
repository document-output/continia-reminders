pageextension 61180 "DOADV User Setup List Ext" extends "CTS-CBF User Setup List"
{
    layout
    {
        addlast(UserSetupList)
        {
            field("PTE User Language Code"; Rec."DOADV User Language Code")
            {
                ToolTip = 'Specifies the preferred language code of the user.';
                ApplicationArea = All;
                Enabled = true;
            }
            field("Salesperson Code"; rec."Salesperson Code")
            {
                ToolTip = 'Specifies the salesperson code of the user. This can be used for filtering in the document output queues.';
                ApplicationArea = All;
                Enabled = true;
            }
        }
    }
    actions
    {
        addlast(Processing)
        {
            action(Test)
            {
                ApplicationArea = All;
                Caption = 'Send Document Capture Reminders';
                Image = SendMail;
                trigger OnAction()
                var
                    SendDCReminders: Codeunit "DOADV Send DC Reminders via JQ";
                begin
                    SendDCReminders.Run();
                end;
            }

            action(StartAction)
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
