@isTest
public class RecruiterWorkloadServiceTest {
    @testSetup
    static void setup() {
        // Создаём пользователя-рекрутера, позицию, кандидата, заявку, интервью, оффер
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Recruiter' LIMIT 1];
        User recruiter = new User(Alias = 'testrec', Email='rec@test.com', EmailEncodingKey='UTF-8',
                                  LastName='TestRec', LanguageLocaleKey='en_US', LocaleSidKey='en_US',
                                  ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles',
                                  UserName='recruiter@test.com');
        insert recruiter;
        
        Position__c pos = new Position__c(Title='Dev', Status__c='Open');
        insert pos;
        Candidate__c cand = new Candidate__c(FirstName='Test', LastName='User', Email='cand@test.com');
        insert cand;
        Application__c app = new Application__c(Candidate__c=cand.Id, Position__c=pos.Id, 
                                                Recruiter__c=recruiter.Id, Status__c='New');
        insert app;
        Interview__c intr = new Interview__c(Application__c=app.Id, Status__c='Scheduled',
                                             Date_Time__c=System.today().addDays(2));
        insert intr;
        Offer__c off = new Offer__c(Application__c=app.Id, Status__c='Sent', Base_Salary__c=100000);
        insert off;
    }
    
    @isTest
    static void testUpdateSingleRecruiter() {
        User rec = [SELECT Id FROM User WHERE Alias='testrec' LIMIT 1];
        Test.startTest();
        RecruiterWorkloadService.updateWorkloadForRecruiter(rec.Id);
        Test.stopTest();
        
        Recruiter_Workload__c wl = [SELECT Active_Applications__c, Interviews_This_Week__c, 
                                    Offers_Pending__c, Workload_Count__c 
                                   FROM Recruiter_Workload__c WHERE Recruiter__c = :rec.Id];
        System.assertEquals(1, wl.Active_Applications__c);
        System.assertEquals(1, wl.Interviews_This_Week__c);
        System.assertEquals(1, wl.Offers_Pending__c);
        System.assertEquals(1, wl.Workload_Count__c);
    }
    
    @isTest
    static void testUpdateAll() {
        Test.startTest();
        RecruiterWorkloadService.updateAllWorkloads();
        Test.stopTest();
        List<Recruiter_Workload__c> workloads = [SELECT Id FROM Recruiter_Workload__c];
        System.assert(!workloads.isEmpty());
    }
}