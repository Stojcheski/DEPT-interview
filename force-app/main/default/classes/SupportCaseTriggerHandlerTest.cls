/**
 * @description: Test class for SupportCaseTriggerHandler
 */
@isTest
public class SupportCaseTriggerHandlerTest {
    private static final String SUPPORT_CASE_NAME = 'Test Support Case before update';
    /**
     * Setup test data
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Create test contacts
        List<Contact> testContacts = new List<Contact>();
        testContacts.add(new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            Phone = '555-1234',
            AccountId = testAccount.Id
        ));
        testContacts.add(new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@test.com',
            Phone = '555-5678',
            AccountId = testAccount.Id
        ));
        insert testContacts;
        
        List<Support_Case__c> testCases = new List<Support_Case__c>();
        testCases.add(new Support_Case__c(
            Subject__c = SUPPORT_CASE_NAME,
            Type__c = 'Incident',
            Priority__c = 'High',
            Status__c = 'New',
            Contact__c = testContacts[0].Id,
            Account__c = testAccount.Id
        ));
        insert testCases;
    }
    
    /**
     * Test case number generation for new cases
     */
    @isTest
    static void testCaseNumberGeneration_NewCases() {
        // Given
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        Integer existingIncidents = getExistingCaseCount('1');
        Integer existingComplaints = getExistingCaseCount('2');
        Integer existingQuestions = getExistingCaseCount('3');
        Integer existingRequests = getExistingCaseCount('4');
        
        List<Support_Case__c> testCases = new List<Support_Case__c>();
        testCases.add(new Support_Case__c(
            Subject__c = 'Test Incident',
            Type__c = 'Incident',
            Priority__c = 'High',
            Status__c = 'New',
            Contact__c = testContact.Id
        ));
        testCases.add(new Support_Case__c(
            Subject__c = 'Test Complaint',
            Type__c = 'Complaint',
            Priority__c = 'Medium',
            Status__c = 'New',
            Contact__c = testContact.Id
        ));
        testCases.add(new Support_Case__c(
            Subject__c = 'Test Question',
            Type__c = 'Question',
            Priority__c = 'Low',
            Status__c = 'New',
            Contact__c = testContact.Id
        ));
        testCases.add(new Support_Case__c(
            Subject__c = 'Test Request',
            Type__c = 'Request new',
            Priority__c = 'High',
            Status__c = 'New',
            Contact__c = testContact.Id
        ));
        // When
        Test.startTest();
        SupportCaseTriggerHandler.handleBeforeInsert(testCases);
        Test.stopTest();
        // Then
        String expectedIncident = '1' + String.valueOf(existingIncidents + 1).leftPad(5, '0');
        String expectedComplaint = '2' + String.valueOf(existingComplaints + 1).leftPad(5, '0');
        String expectedQuestion = '3' + String.valueOf(existingQuestions + 1).leftPad(5, '0');
        String expectedRequest = '4' + String.valueOf(existingRequests + 1).leftPad(5, '0');
        
        Assert.areEqual(expectedIncident, testCases[0].Case_Number__c, 'Incident case number should be next in sequence');
        Assert.areEqual(expectedComplaint, testCases[1].Case_Number__c, 'Complaint case number should be next in sequence');
        Assert.areEqual(expectedQuestion, testCases[2].Case_Number__c, 'Question case number should be next in sequence');
        Assert.areEqual(expectedRequest, testCases[3].Case_Number__c, 'Request new case number should be next in sequence');
        
        Assert.areEqual('John', testCases[0].First_Name__c, 'First name should be populated from contact');
        Assert.areEqual('Doe', testCases[0].Last_Name__c, 'Last name should be populated from contact');
        Assert.areEqual(Date.today(), testCases[0].Start_date__c, 'Start date should be set to today');
    }
    
    /**
     * Test sequential case number generation
     */
    @isTest
    static void testCaseNumberGeneration_Sequential() {
        // Given
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        Integer existingIncidents = getExistingCaseCount('1');
        
        List<Support_Case__c> firstBatch = new List<Support_Case__c>();
        for (Integer i = 0; i < 3; i++) {
            firstBatch.add(new Support_Case__c(
                Subject__c = 'Test Incident ' + i,
                Type__c = 'Incident',
                Priority__c = 'High',
                Status__c = 'New',
                Contact__c = testContact.Id
            ));
        }
        // When
        Test.startTest();
        SupportCaseTriggerHandler.handleBeforeInsert(firstBatch);
        insert firstBatch;
        
        List<Support_Case__c> secondBatch = new List<Support_Case__c>();
        for (Integer i = 0; i < 2; i++) {
            secondBatch.add(new Support_Case__c(
                Subject__c = 'Test Incident Second ' + i,
                Type__c = 'Incident',
                Priority__c = 'Medium',
                Status__c = 'New',
                Contact__c = testContact.Id
            ));
        }
        SupportCaseTriggerHandler.handleBeforeInsert(secondBatch);
        Test.stopTest();
        // Then
        String expectedFirst = '1' + String.valueOf(existingIncidents + 1).leftPad(5, '0');
        String expectedSecond = '1' + String.valueOf(existingIncidents + 2).leftPad(5, '0');
        String expectedThird = '1' + String.valueOf(existingIncidents + 3).leftPad(5, '0');
        String expectedFourth = '1' + String.valueOf(existingIncidents + 4).leftPad(5, '0');
        String expectedFifth = '1' + String.valueOf(existingIncidents + 5).leftPad(5, '0');
        
        Assert.areEqual(expectedFirst, firstBatch[0].Case_Number__c, 'First incident should be next in sequence');
        Assert.areEqual(expectedSecond, firstBatch[1].Case_Number__c, 'Second incident should be sequential');
        Assert.areEqual(expectedThird, firstBatch[2].Case_Number__c, 'Third incident should be sequential');
        Assert.areEqual(expectedFourth, secondBatch[0].Case_Number__c, 'Fourth incident should be sequential');
        Assert.areEqual(expectedFifth, secondBatch[1].Case_Number__c, 'Fifth incident should be sequential');
    }
    
    /**
     * Test contact field population
     */
    @isTest
    static void testContactFieldPopulation() {
        // Given
        List<Contact> testContacts = [SELECT Id, FirstName, LastName FROM Contact];
        Contact johnContact = testContacts[0];
        Contact janeContact = testContacts[1];
        
        List<Support_Case__c> testCases = new List<Support_Case__c>();
        testCases.add(new Support_Case__c(
            Subject__c = 'Test Case 1',
            Type__c = 'Incident',
            Priority__c = 'High',
            Status__c = 'New',
            Contact__c = johnContact.Id
        ));
        testCases.add(new Support_Case__c(
            Subject__c = 'Test Case 2',
            Type__c = 'Question',
            Priority__c = 'Low',
            Status__c = 'New',
            Contact__c = janeContact.Id
        ));
        testCases.add(new Support_Case__c(
            Subject__c = 'Test Case 3',
            Type__c = 'Complaint',
            Priority__c = 'Medium',
            Status__c = 'New'
            // No contact assigned
        ));
        // When
        Test.startTest();
        SupportCaseTriggerHandler.handleBeforeInsert(testCases);
        Test.stopTest();
        // Then
        Assert.areEqual('John', testCases[0].First_Name__c, 'First name should match contact');
        Assert.areEqual('Doe', testCases[0].Last_Name__c, 'Last name should match contact');
        Assert.areEqual(Date.today(), testCases[0].Start_date__c, 'Start date should be set');
        
        Assert.areEqual('Jane', testCases[1].First_Name__c, 'First name should match second contact');
        Assert.areEqual('Smith', testCases[1].Last_Name__c, 'Last name should match second contact');
        
        Assert.isNull(testCases[2].First_Name__c, 'First name should be null when no contact');
        Assert.isNull(testCases[2].Last_Name__c, 'Last name should be null when no contact');
    }
    
    /**
     * Test before update - contact change
     */
    @isTest
    static void testBeforeUpdate_ContactChange() {
        // Given
        List<Contact> testContacts = [SELECT Id FROM Contact];
        Contact janeContact = testContacts[0];
        Contact johnContact = testContacts[1];
        
        Support_Case__c testCase = new Support_Case__c(
            Subject__c = 'Test Case',
            Type__c = 'Incident',
            Priority__c = 'High',
            Status__c = 'New',
            Contact__c = janeContact.Id
        );
        
        SupportCaseTriggerHandler.handleBeforeInsert(new List<Support_Case__c>{testCase});
        insert testCase;
        
        Map<Id, Support_Case__c> oldCaseMap = new Map<Id, Support_Case__c>();
        oldCaseMap.put(testCase.Id, testCase.clone(true));
        
        testCase.Contact__c = johnContact.Id;
        // When
        Test.startTest();
        SupportCaseTriggerHandler.handleBeforeUpdate(new List<Support_Case__c>{testCase}, oldCaseMap);
        Test.stopTest();
        // Then
        Assert.areEqual('Jane', testCase.First_Name__c, 'First name should be updated to Jane');
        Assert.areEqual('Smith', testCase.Last_Name__c, 'Last name should be updated to Smith');
    }
    
    /**
     * Test before update - type change
     */
    @isTest
    static void testBeforeUpdate_TypeChange() {
        // Given
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        Integer existingComplaints = getExistingCaseCount('2');
        
        Support_Case__c testCase = new Support_Case__c(
            Subject__c = 'Test Case',
            Type__c = 'Incident',
            Priority__c = 'High',
            Status__c = 'New',
            Contact__c = testContact.Id
        );
        
        SupportCaseTriggerHandler.handleBeforeInsert(new List<Support_Case__c>{testCase});
        insert testCase;
        
        String originalCaseNumber = testCase.Case_Number__c;
        Assert.isTrue(originalCaseNumber.startsWith('1'), 'Original case number should start with 1 (Incident)');
        
        Map<Id, Support_Case__c> oldCaseMap = new Map<Id, Support_Case__c>();
        oldCaseMap.put(testCase.Id, testCase.clone(true));
        
        testCase.Type__c = 'Complaint';
        // When
        Test.startTest();
        SupportCaseTriggerHandler.handleBeforeUpdate(new List<Support_Case__c>{testCase}, oldCaseMap);
        Test.stopTest();
        
        String expectedComplaint = '2' + String.valueOf(existingComplaints + 1).leftPad(5, '0');
        // Then
        Assert.areEqual(expectedComplaint, testCase.Case_Number__c, 'Case number should be regenerated for Complaint type');
        Assert.areNotEqual(originalCaseNumber, testCase.Case_Number__c, 'Case number should be different from original');
        Assert.isTrue(testCase.Case_Number__c.startsWith('2'), 'New case number should start with 2 (Complaint)');
    }
    
    /**
     * Test bulk operations
     */
    @isTest
    static void testBulkOperations() {
        // Given
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        Integer existingIncidents = getExistingCaseCount('1');
        Integer existingQuestions = getExistingCaseCount('3');
        
        List<Support_Case__c> bulkCases = new List<Support_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkCases.add(new Support_Case__c(
                Subject__c = 'Bulk Test Case ' + i,
                Type__c = Math.mod(i, 2) == 0 ? 'Incident' : 'Question',
                Priority__c = 'Medium',
                Status__c = 'New',
                Contact__c = testContact.Id
            ));
        }
        // When
        Test.startTest();
        SupportCaseTriggerHandler.handleBeforeInsert(bulkCases);
        Test.stopTest();
        
        Integer incidentCount = existingIncidents + 1;
        Integer questionCount = existingQuestions + 1;
        // Then
        for (Integer i = 0; i < bulkCases.size(); i++) {
            Support_Case__c caseRecord = bulkCases[i];
            Assert.isNotNull(caseRecord.Case_Number__c, 'Case number should not be null');
            Assert.areEqual('John', caseRecord.First_Name__c, 'First name should be populated');
            Assert.areEqual('Doe', caseRecord.Last_Name__c, 'Last name should be populated');
            
            if (caseRecord.Type__c == 'Incident') {
                String expectedNumber = '1' + String.valueOf(incidentCount).leftPad(5, '0');
                Assert.areEqual(expectedNumber, caseRecord.Case_Number__c, 
                    'Incident case number should be sequential: ' + expectedNumber);
                incidentCount++;
            } else if (caseRecord.Type__c == 'Question') {
                String expectedNumber = '3' + String.valueOf(questionCount).leftPad(5, '0');
                Assert.areEqual(expectedNumber, caseRecord.Case_Number__c, 
                    'Question case number should be sequential: ' + expectedNumber);
                questionCount++;
            }
        }
        Assert.areEqual(existingIncidents + 101, incidentCount, 'Should have processed 100 incidents');
        Assert.areEqual(existingQuestions + 101, questionCount, 'Should have processed 100 questions');
    }
    
    /**
     * Test edge case - null contact
     */
    @isTest
    static void testEdgeCase_NullContact() {
        // Given
        Integer existingIncidents = getExistingCaseCount('1');
        
        Support_Case__c testCase = new Support_Case__c(
            Subject__c = 'Test Case No Contact',
            Type__c = 'Incident',
            Priority__c = 'High',
            Status__c = 'New'
        );
        // When
        Test.startTest();
        SupportCaseTriggerHandler.handleBeforeInsert(new List<Support_Case__c>{testCase});
        Test.stopTest();
        
        String expectedNumber = '1' + String.valueOf(existingIncidents + 1).leftPad(5, '0');
        // Then
        Assert.areEqual(expectedNumber, testCase.Case_Number__c, 'Case number should be generated even without contact');     
        Assert.isNull(testCase.First_Name__c, 'First name should be null');
        Assert.isNull(testCase.Last_Name__c, 'Last name should be null');
        Assert.isNull(testCase.Start_date__c, 'Start date should be null when no contact');
    }
    
    /**
     * Helper method to get existing case count for a given prefix
     * @param prefix The case number prefix ('1', '2', '3', '4')
     * @return Count of existing cases with that prefix
     */
    private static Integer getExistingCaseCount(String prefix) {
        try {
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
                return Integer.valueOf(numberPart);
            } else {
                return 0;
            }
        } catch (Exception e) {
            return 0;
        }
    }
    
    /**
     * Test edge case - invalid type
     */
    @isTest
    static void testEdgeCase_InvalidType() {
        // Given
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        Support_Case__c testCase = new Support_Case__c(
            Subject__c = 'Test Case Invalid Type',
            Type__c = 'InvalidType',
            Priority__c = 'High',
            Status__c = 'New',
            Contact__c = testContact.Id
        );
        // When
        Test.startTest();
        SupportCaseTriggerHandler.handleBeforeInsert(new List<Support_Case__c>{testCase});
        Test.stopTest();
        // Then
        Assert.isNull(testCase.Case_Number__c, 'Case number should not be generated for invalid type');
        
        Assert.areEqual('John', testCase.First_Name__c, 'First name should still be populated');
        Assert.areEqual('Doe', testCase.Last_Name__c, 'Last name should still be populated');
    }
    /**
     * Test for covering before and after update trigger
     */
    @isTest
    static void testUpdateScenario() {
        // Given
        List<Support_Case__c> testCase = [SELECT Id, Subject__c FROM Support_Case__c WHERE Subject__c = :SUPPORT_CASE_NAME];
        testCase[0].Subject__c = 'Updated subject';
        // When
        update testCase;
        // Then
        List<Support_Case__c> updatedCase = [SELECT Id, Subject__c FROM Support_Case__c WHERE Subject__c = :SUPPORT_CASE_NAME];
        Assert.areNotEqual(SUPPORT_CASE_NAME, testCase[0].Subject__c, 'The subject should be changed');
    }
}