@isTest
private class DEPT_CaseTriggerHandlerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Create test Case with specified fields
        Case testCase = new Case(
            ContactId = testContact.Id,
            AccountId = testAccount.Id,
            CurrencyIsoCode = 'EUR',
            Status = 'In wachstand',
            Origin = 'E-mail',
            Priority = 'High',
            Subject = 'Aa',
            Description = 'aaa',
            Type = 'Probleem'
        );
        insert testCase;
    }
    
    @isTest
    static void testHandleBeforeUpdate_StatusChangedToClosed() {
        // Given
        Case testCase = [SELECT Id, ContactId, AccountId, CurrencyIsoCode, Status, Origin, Priority, Subject, Description, Type, ClosedDate FROM Case LIMIT 1];
        Map<Id, Case> oldCaseMap = new Map<Id, Case>();
        oldCaseMap.put(testCase.Id, testCase.clone(true, true, true, true));
        testCase.Status = 'Closed';
        // When
        Test.startTest();
        DEPT_CaseTriggerHandler.handleBeforeUpdate(new List<Case>{testCase}, oldCaseMap);
        Test.stopTest();
        // Then
        Assert.isNotNull(testCase.ClosedDate, 'ClosedDate should be populated when status changes to Closed');
        Assert.areEqual(Date.today(), testCase.ClosedDate, 'ClosedDate should be set to today\'s date');
    }
}