import { Abc } from "../src/abc_case.form";

describe("Abc.Case.Form.onSave", () => {
    it("shows a notification when the Case is submitted", () => {
        const setFormNotification = jest.fn();
        const context = {
            getFormContext: () => ({
                getAttribute: () => ({ getValue: () => 2 }),
                ui: { setFormNotification },
            }),
        } as unknown as Xrm.Events.EventContext;

        Abc.Case.Form.onSave(context);

        expect(setFormNotification).toHaveBeenCalledWith("Case submitted", "INFO", "abc_submitted");
    });
});
