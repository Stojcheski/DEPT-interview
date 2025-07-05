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
                // Since the requirement is: Should be auto populated with the Created Date, 
                // I assume it's meant only in insert scenarios but I'm leaving it to work on update and insert for now
                // if(Trigger.isInsert){
                    caseRecord.Start_date__c = Date.today(); 
                // }         
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
        createFollowUpTasks(newCases, oldCaseMap);
    }
    /**
     * Creates follow-up tasks for cases that are newly closed
     * @param newCases List of updated Support Case records
     * @param oldCaseMap Map of old Support Case records
     */
    private static void createFollowUpTasks(List<Support_Case__c> newCases, Map<Id, Support_Case__c> oldCaseMap) {
        List<Task> followUpTasks = new List<Task>();
        
        for (Support_Case__c newCase : newCases) {
            Support_Case__c oldCase = oldCaseMap.get(newCase.Id);
            
            if (newCase.Status__c == 'Resolved' && oldCase.Status__c != 'Resolved') {
                
                Task followUpTask = new Task();
                followUpTask.Subject = 'Follow-up on Case: ' + newCase.Case_Number__c;
                followUpTask.Description = 'Follow-up task for resolved case: ' + newCase.Case_Number__c + 
                                        '\nCase Subject: ' + (String.isNotBlank(newCase.Subject__c) ? newCase.Subject__c : 'N/A') +
                                        '\nCase resolved on: ' + Date.today().format();
                followUpTask.OwnerId = newCase.OwnerId;
                followUpTask.WhatId = newCase.Id;
                followUpTask.ActivityDate = Date.today().addDays(2);
                followUpTask.Priority = 'Normal';
                followUpTask.Status = 'Not Started';
                followUpTask.Type = 'Follow-up';
                
                followUpTasks.add(followUpTask);
            }
        }
        
        if (!followUpTasks.isEmpty()) {
            try {
                insert followUpTasks;
            } catch (Exception e) {
                System.debug('Error creating follow-up tasks: ' + e.getMessage());
            }
        }
    }
    /**
     * @description Retrieves list of open support cases for the LWC component
     * @return List<Support_Case__c> List of open cases with related data
     */
    @AuraEnabled(cacheable=true)
    public static List<Support_Case__c> getCaseList() {
        try {
            return [
                SELECT Id, Case_Number__c, Subject__c, Priority__c, Status__c, 
                    CreatedDate, Contact__c, Contact__r.Name, Contact__r.Email,
                    Account__c, Account__r.Name, Owner.Name, Description__c,
                    Type__c, Impact__c, Case_Origin__c, Internal_Notes__c
                FROM Support_Case__c 
                WHERE Status__c IN ('New', 'Open', 'In Progress', 'Waiting on customer', 'On Hold')
                ORDER BY CreatedDate DESC
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving case list: ' + e.getMessage());
        }
    }

    /**
     * @description Updates the status of a support case
     * @param caseId The ID of the case to update
     * @param newStatus The new status to set
     */
    @AuraEnabled
    public static void updateCaseStatus(Id caseId, String newStatus) {
        try {
            // Validate input
            if (caseId == null || String.isBlank(newStatus)) {
                throw new AuraHandledException('Case ID and new status are required.');
            }
            
            // Validate status value
            List<String> validStatuses = new List<String>{
                'New', 'Open', 'In Progress', 'Waiting on customer', 'Resolved', 'On Hold'
            };
            
            if (!validStatuses.contains(newStatus)) {
                throw new AuraHandledException('Invalid status value provided.');
            }
            
            Support_Case__c caseToUpdate = new Support_Case__c(
                Id = caseId,
                Status__c = newStatus
            );
                        if (newStatus == 'Resolved') {
                caseToUpdate.Close_Date__c = Date.today();
            }
            
            update caseToUpdate;
            
        } catch (DmlException e) {
            throw new AuraHandledException('Error updating case status: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error updating case status: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves detailed information for a specific case
     * @param caseId The ID of the case to retrieve
     * @return Support_Case__c The case record with full details
     */
    @AuraEnabled(cacheable=true)
    public static Support_Case__c getCaseDetails(Id caseId) {
        try {
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required.');
            }
            
            return [
                SELECT Id, Case_Number__c, Subject__c, Priority__c, Status__c, 
                    CreatedDate, Close_Date__c, Start_Date__c, Contact__c, 
                    Contact__r.Name, Contact__r.Email, Contact__r.Phone,
                    Account__c, Account__r.Name, Owner.Name, Description__c,
                    Type__c, Impact__c, Case_Origin__c, Internal_Notes__c,
                    First_Name__c, Last_Name__c, Email__c, Phone__c, Address__c
                FROM Support_Case__c 
                WHERE Id = :caseId
                LIMIT 1
            ];
        } catch (QueryException e) {
            throw new AuraHandledException('Case not found.');
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving case details: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves cases assigned to the current user
     * @return List<Support_Case__c> List of cases assigned to current user
     */
    @AuraEnabled(cacheable=true)
    public static List<Support_Case__c> getMyCases() {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            return [
                SELECT Id, Case_Number__c, Subject__c, Priority__c, Status__c, 
                    CreatedDate, Contact__c, Contact__r.Name, Contact__r.Email,
                    Account__c, Account__r.Name, Description__c, Type__c, Impact__c
                FROM Support_Case__c 
                WHERE OwnerId = :currentUserId
                AND Status__c IN ('New', 'Open', 'In Progress', 'Waiting on customer', 'On Hold')
                ORDER BY Priority__c DESC, CreatedDate DESC
                LIMIT 500
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving your cases: ' + e.getMessage());
        }
    }
}