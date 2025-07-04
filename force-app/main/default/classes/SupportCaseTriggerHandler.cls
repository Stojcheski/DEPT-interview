/**
 * @description: Handler class for Support Case trigger operations
 */
public with sharing class SupportCaseTriggerHandler {
    // Constants for case number prefixes
    private static final String INCIDENT_PREFIX = '1';
    private static final String COMPLAINT_PREFIX = '2';
    private static final String QUESTION_PREFIX = '3';
    private static final String REQUEST_NEW_PREFIX = '4';

    /**
     * Handles before insert operations
     * @param newCases List of new Support Case records
     */
    public static void handleBeforeInsert(List<Support_Case__c> newCases) {
        populateContactFields(newCases);
        generateCaseNumbers(newCases);
        
    }

    /**
     * Handles before update operations
     * @param newCases List of updated Support Case records
     * @param oldCaseMap Map of old Support Case records
     */
    public static void handleBeforeUpdate(List<Support_Case__c> newCases, Map<Id, Support_Case__c> oldCaseMap) {
        List<Support_Case__c> casesWithContactChange = new List<Support_Case__c>();
        List<Support_Case__c> casesWithTypeChange = new List<Support_Case__c>();
        
        for (Support_Case__c newCase : newCases) {
            Support_Case__c oldCase = oldCaseMap.get(newCase.Id);
            
            // Check if Contact lookup changed
            if (newCase.Contact__c != oldCase.Contact__c) {
                casesWithContactChange.add(newCase);
            }
            
            // Check if Type changed (regenerate case number if needed)
            if (newCase.Type__c != oldCase.Type__c) {
                casesWithTypeChange.add(newCase);
            }
        }
        
        if (!casesWithContactChange.isEmpty()) {
            populateContactFields(casesWithContactChange);
        }
        
        if (!casesWithTypeChange.isEmpty()) {
            generateCaseNumbers(casesWithTypeChange);
        }
    }

    /**
     * Populates First Name, Last Name from Contact lookup
     * @param cases List of Support Case records
     */
    private static void populateContactFields(List<Support_Case__c> cases) {
        Set<Id> contactIds = new Set<Id>();
        
        for (Support_Case__c caseRecord : cases) {
            if (caseRecord.Contact__c != null) {
                contactIds.add(caseRecord.Contact__c);
            }
        }
        
        if (contactIds.isEmpty()) return;
        
        Map<Id, Contact> contactMap = new Map<Id, Contact>([
            SELECT Id, FirstName, LastName
            FROM Contact 
            WHERE Id IN :contactIds
        ]);
        
        for (Support_Case__c caseRecord : cases) {
            if (caseRecord.Contact__c != null && contactMap.containsKey(caseRecord.Contact__c)) {
                Contact relatedContact = contactMap.get(caseRecord.Contact__c);
                
                caseRecord.First_Name__c = relatedContact.FirstName;
                caseRecord.Last_Name__c = relatedContact.LastName;
                // Since the requirement is: Should be auto populated with the Created Date, I assume it's meant only in insert scenarios
                if(Trigger.isInsert){
                    caseRecord.Start_date__c = Date.today(); 
                }         
            }
        }
    }

    /**
     * Generates Case Numbers based on Type
     * @param cases List of Support Case records
     */
    private static void generateCaseNumbers(List<Support_Case__c> cases) {
        Map<String, String> typeToPrefix = new Map<String, String>{
            'Incident' => INCIDENT_PREFIX,
            'Complaint' => COMPLAINT_PREFIX,
            'Question' => QUESTION_PREFIX,
            'Request new' => REQUEST_NEW_PREFIX
        };
        
        Map<String, Integer> typeToNextNumber = new Map<String, Integer>();
        
        // Get the highest existing case number for each type
        for (String caseType : typeToPrefix.keySet()) {
            String prefix = typeToPrefix.get(caseType);
            Integer nextNumber = getNextCaseNumber(prefix);
            typeToNextNumber.put(caseType, nextNumber);
        }
        
        for (Support_Case__c caseRecord : cases) {
            if (String.isNotBlank(caseRecord.Type__c) && typeToPrefix.containsKey(caseRecord.Type__c)) {
                String prefix = typeToPrefix.get(caseRecord.Type__c);
                Integer nextNumber = typeToNextNumber.get(caseRecord.Type__c);
                
                caseRecord.Case_Number__c = prefix + String.valueOf(nextNumber).leftPad(5, '0');
                
                // Increment for next case of same type
                typeToNextNumber.put(caseRecord.Type__c, nextNumber + 1);
            }
        }
    }
    /**
     * Gets the next available case number for a given prefix
     * @param prefix The case number prefix (e.g., '1', '2')
     * @return Next available number
     */
    private static Integer getNextCaseNumber(String prefix) {
        try {
            // Query for the highest existing case number with this prefix
            List<Support_Case__c> existingCases = [
                SELECT Case_Number__c 
                FROM Support_Case__c 
                WHERE Case_Number__c LIKE :prefix + '%'
                ORDER BY Case_Number__c DESC 
                LIMIT 1
            ];
            
            if (!existingCases.isEmpty()) {
                String lastCaseNumber = existingCases[0].Case_Number__c;
                String numberPart = lastCaseNumber.substring(prefix.length());
                Integer lastNumber = Integer.valueOf(numberPart);
                return lastNumber + 1;
            } else {
                // First case of this type - start with 00001
                return 1;
            }
        } catch (Exception e) {
            System.debug('Error getting next case number: ' + e.getMessage());
            // Fallback to default starting number
            return 1;
        }
    }
    /**
     * Handles after insert operations
     * @param newCases List of new Support Case records
     */
    public static void handleAfterInsert(List<Support_Case__c> newCases) {
        
    }
    /**
     * Handles after update operations
     * @param newCases List of updated Support Case records
     * @param oldCaseMap Map of old Support Case records
     */
    public static void handleAfterUpdate(List<Support_Case__c> newCases, Map<Id, Support_Case__c> oldCaseMap) {

    }
}