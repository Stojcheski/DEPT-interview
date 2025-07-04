
/**
 * @description: Handler class for Case trigger operations
 */
public with sharing class DEPT_CaseTriggerHandler {
    /**
     * Handles before update operations
     * @param newCases List of updated Case records
     * @param oldCaseMap Map of old Case records
     */
    public static void handleBeforeUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            if (newCase.Status == 'Closed' && oldCase.Status != 'Closed') {
                // CloseDate is not writtable - System.SObjectException: Field is not writeable: Case.ClosedDate
                // Since from the requirements it is not clear if ClosedDate should be created as custom field 
                // I'm commenting the below code to prevent blocking closure of the cases
                // Furthermore, on field CloseDate there was no picklist value 'Closed' in the org, but I created as part of the exam
                // newCase.ClosedDate = Date.today();
            }
        }
    }
}