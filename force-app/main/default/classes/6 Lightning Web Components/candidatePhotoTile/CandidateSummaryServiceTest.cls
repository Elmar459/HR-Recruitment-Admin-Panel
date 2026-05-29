@isTest
private class CandidateSummaryServiceTest {
    
    /**
     * Test data setup - creates test Candidate records
     */
    @testSetup
    static void setupTestData() {
        // Create candidate with all fields populated
        Candidate__c candidateWithPhoto = new Candidate__c(
            Name = 'John Doe',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Email__c = 'john.doe@example.com',
            Phone__c = '+1234567890',
            Location__c = 'New York',
            Years_of_Experience__c = 5
        );
        insert candidateWithPhoto;
        
        // Create candidate without photo URL
        Candidate__c candidateWithoutPhoto = new Candidate__c(
            Name = 'Jane Smith',
            First_Name__c = 'Jane',
            Last_Name__c = 'Smith',
            Email__c = 'jane.smith@example.com',
            Phone__c = '+9876543210',
            Location__c = 'San Francisco',
            Years_of_Experience__c = 3
        );
        insert candidateWithoutPhoto;
        
        // Create candidate with minimal data
        Candidate__c minimalCandidate = new Candidate__c(
            Name = 'Bob Johnson',
            First_Name__c = 'Bob',
            Last_Name__c = 'Johnson'
        );
        insert minimalCandidate;
    }
    
    /**
     * Test successful retrieval of candidate summary with photo
     */
    @isTest
    static void testGetCandidateSummaryWithPhoto() {
        // Given
        Candidate__c candidate = [
            SELECT Id 
            FROM Candidate__c 
            WHERE Email__c = 'john.doe@example.com' 
            LIMIT 1
        ];
        
        // When
        Test.startTest();
        CandidateSummaryService.CandidateSummary result = 
            CandidateSummaryService.getCandidateSummary(candidate.Id);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(candidate.Id, result.id, 'Candidate Id should match');
        System.assertEquals('John Doe', result.name, 'Name should match');
        System.assertEquals('John', result.firstName, 'First name should match');
        System.assertEquals('Doe', result.lastName, 'Last name should match');
        System.assertEquals('john.doe@example.com', result.email, 'Email should match');
        System.assertEquals('+1234567890', result.phone, 'Phone should match');
        System.assertEquals('New York', result.location, 'Location should match');
        System.assertEquals('https://example.com/photos/johndoe.jpg', result.photoUrl, 
            'Photo URL should match');
        System.assertEquals(5, result.yearsOfExperience, 'Years of experience should match');
        System.assertEquals(80000, result.desiredSalary, 'Desired salary should match');
        System.assertEquals('Bachelor\'s Degree', result.highestEducation, 
            'Education level should match');
    }
    
    /**
     * Test successful retrieval of candidate summary without photo
     */
    @isTest
    static void testGetCandidateSummaryWithoutPhoto() {
        // Given
        Candidate__c candidate = [
            SELECT Id 
            FROM Candidate__c 
            WHERE Email__c = 'jane.smith@example.com' 
            LIMIT 1
        ];
        
        // When
        Test.startTest();
        CandidateSummaryService.CandidateSummary result = 
            CandidateSummaryService.getCandidateSummary(candidate.Id);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(candidate.Id, result.id, 'Candidate Id should match');
        System.assertEquals('Jane Smith', result.name, 'Name should match');
        System.assertEquals('jane.smith@example.com', result.email, 'Email should match');
        System.assertEquals(null, result.photoUrl, 'Photo URL should be null');
        System.assertEquals(3, result.yearsOfExperience, 'Years of experience should match');
    }
    
    /**
     * Test retrieval of candidate with minimal data
     */
    @isTest
    static void testGetCandidateSummaryWithMinimalData() {
        // Given
        Candidate__c candidate = [
            SELECT Id 
            FROM Candidate__c 
            WHERE First_Name__c = 'Bob' 
            LIMIT 1
        ];
        
        // When
        Test.startTest();
        CandidateSummaryService.CandidateSummary result = 
            CandidateSummaryService.getCandidateSummary(candidate.Id);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(candidate.Id, result.id, 'Candidate Id should match');
        System.assertEquals('Bob Johnson', result.name, 'Name should match');
        System.assertEquals('Bob', result.firstName, 'First name should match');
        System.assertEquals('Johnson', result.lastName, 'Last name should match');
        System.assertEquals(null, result.email, 'Email should be null');
        System.assertEquals(null, result.photoUrl, 'Photo URL should be null');
    }
    
    /**
     * Test error handling with null candidateId
     */
    @isTest
    static void testGetCandidateSummaryWithNullId() {
        // When
        Test.startTest();
        Exception caughtException;
        try {
            CandidateSummaryService.getCandidateSummary(null);
            System.assert(false, 'Expected exception was not thrown');
        } catch (AuraHandledException e) {
            caughtException = e;
        }
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, caughtException, 'Exception should be thrown');
        System.assert(caughtException.getMessage().contains('Invalid candidate ID'), 
            'Exception message should indicate invalid ID');
    }
    
    /**
     * Test error handling with invalid candidateId (non-existent record)
     */
    @isTest
    static void testGetCandidateSummaryWithInvalidId() {
        // Given - Create a fake candidate Id that doesn't exist
        Id fakeCandidateId = Schema.SObjectType.Candidate__c.getKeyPrefix() + 
            '000000000000AAA';
        
        // When
        Test.startTest();
        Exception caughtException;
        try {
            CandidateSummaryService.getCandidateSummary(fakeCandidateId);
            System.assert(false, 'Expected exception was not thrown');
        } catch (AuraHandledException e) {
            caughtException = e;
        }
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, caughtException, 'Exception should be thrown');
        System.assert(caughtException.getMessage().contains('Candidate not found'), 
            'Exception message should indicate candidate not found');
    }
    
    /**
     * Test wrapper class instantiation and field access
     */
    @isTest
    static void testCandidateSummaryWrapperClass() {
        // Given
        Candidate__c testCandidate = [
            SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, 
                   Phone__c, Location__c, 
                   Years_of_Experience__c
            FROM Candidate__c 
            WHERE Email__c = 'john.doe@example.com' 
            LIMIT 1
        ];
        
        // When
        Test.startTest();
        CandidateSummaryService.CandidateSummary wrapper = 
            new CandidateSummaryService.CandidateSummary();
        wrapper.id = testCandidate.Id;
        wrapper.name = testCandidate.Name;
        wrapper.firstName = testCandidate.First_Name__c;
        wrapper.lastName = testCandidate.Last_Name__c;
        wrapper.email = testCandidate.Email__c;
        wrapper.phone = testCandidate.Phone__c;
        wrapper.location = testCandidate.Location__c;
        // Photo, desired salary and highest education fields are not present on Candidate__c in this org.
        // Keep only fields that exist to avoid compile-time errors.
        wrapper.yearsOfExperience = testCandidate.Years_of_Experience__c;
        Test.stopTest();
        
        // Then
        System.assertEquals(testCandidate.Id, wrapper.id, 'Wrapper Id should match');
        System.assertEquals(testCandidate.Name, wrapper.name, 'Wrapper name should match');
        System.assertEquals(testCandidate.First_Name__c, wrapper.firstName, 
            'Wrapper firstName should match');
        System.assertEquals(testCandidate.Last_Name__c, wrapper.lastName, 
            'Wrapper lastName should match');
        System.assertEquals(testCandidate.Email__c, wrapper.email, 
            'Wrapper email should match');
        // Photo field not present in this org; ensure photoUrl remains null by default
        System.assertEquals(null, wrapper.photoUrl, 'Wrapper photoUrl should be null');
    }
    
    /**
     * Test multiple concurrent calls to getCandidateSummary
     * Tests caching behavior and concurrent execution
     */
    @isTest
    static void testGetCandidateSummaryMultipleCalls() {
        // Given
        Candidate__c candidate = [
            SELECT Id 
            FROM Candidate__c 
            WHERE Email__c = 'john.doe@example.com' 
            LIMIT 1
        ];
        
        // When
        Test.startTest();
        CandidateSummaryService.CandidateSummary result1 = 
            CandidateSummaryService.getCandidateSummary(candidate.Id);
        CandidateSummaryService.CandidateSummary result2 = 
            CandidateSummaryService.getCandidateSummary(candidate.Id);
        CandidateSummaryService.CandidateSummary result3 = 
            CandidateSummaryService.getCandidateSummary(candidate.Id);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result1, 'First result should not be null');
        System.assertNotEquals(null, result2, 'Second result should not be null');
        System.assertNotEquals(null, result3, 'Third result should not be null');
        System.assertEquals(result1.id, result2.id, 'Results should have same Id');
        System.assertEquals(result1.name, result2.name, 'Results should have same name');
        System.assertEquals(result2.id, result3.id, 'Results should have same Id');
    }
    
    /**
     * Test with different candidate records in bulk
     * Ensures method works correctly with different data sets
     */
    @isTest
    static void testGetCandidateSummaryBulk() {
        // Given
        List<Candidate__c> candidates = [
            SELECT Id 
            FROM Candidate__c 
            ORDER BY Name
        ];
        
        System.assertEquals(3, candidates.size(), 'Should have 3 test candidates');
        
        // When
        Test.startTest();
        List<CandidateSummaryService.CandidateSummary> results = 
            new List<CandidateSummaryService.CandidateSummary>();
        
        for (Candidate__c candidate : candidates) {
            CandidateSummaryService.CandidateSummary result = 
                CandidateSummaryService.getCandidateSummary(candidate.Id);
            results.add(result);
        }
        Test.stopTest();
        
        // Then
        System.assertEquals(3, results.size(), 'Should have 3 results');
        
        for (Integer i = 0; i < candidates.size(); i++) {
            System.assertNotEquals(null, results[i], 'Result should not be null');
            System.assertEquals(candidates[i].Id, results[i].id, 
                'Candidate Id should match at index ' + i);
        }
    }
}