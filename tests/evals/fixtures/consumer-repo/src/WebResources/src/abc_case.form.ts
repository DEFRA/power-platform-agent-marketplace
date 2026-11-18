/// <reference types="xrm" />

export namespace Abc.Case.Form {
    export const SubmittedMessage = "Case submitted";

    /** OnSave handler: tells the user a submitted Case has been sent. */
    export function onSave(executionContext: Xrm.Events.EventContext): void {
        const formContext = executionContext.getFormContext();
        const status = formContext.getAttribute("abc_status").getValue();

        if (status === 2) {
            formContext.ui.setFormNotification(SubmittedMessage, "INFO", "abc_submitted");
        }
    }
}
