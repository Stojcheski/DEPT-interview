trigger DEPT_CaseTrigger on Case (before update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        // DEPT_CaseTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}