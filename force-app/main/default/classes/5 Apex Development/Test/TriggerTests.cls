@IsTest
private class TriggerTests {
    @IsTest
    static void candidateAndApplicationTriggersRun() {
        Candidate__c candidate = TestDataFactory.candidate('trigger@example.com');
        Position__c position = TestDataFactory.position();
        Skill__c skill = TestDataFactory.skill();
        insert new List<SObject>{ candidate, position, skill };

        insert TestDataFactory.candidateSkill(candidate.Id, skill.Id);
        insert TestDataFactory.positionSkill(position.Id, skill.Id);

        Test.startTest();
        Application__c app = TestDataFactory.application(candidate.Id, position.Id);
        insert app;
        app = [SELECT Id, Status__c, Match_Score__c FROM Application__c WHERE Id = :app.Id];
        app.Status__c = 'Screening';
        update app;
        Test.stopTest();

        Application__c scored = [SELECT Match_Score__c FROM Application__c WHERE Id = :app.Id];
        System.assert(scored.Match_Score__c >= 0);
    }

    @IsTest
    static void candidateNamesAreNormalizedBeforeSave() {
        Candidate__c candidate = TestDataFactory.candidate('normalize@example.com');
        candidate.First_Name__c = 'sMOKE';
        candidate.Last_Name__c = 'SMoKe';

        insert candidate;

        Candidate__c saved = [
            SELECT First_Name__c, Last_Name__c
            FROM Candidate__c
            WHERE Id = :candidate.Id
        ];
        System.assertEquals('Smoke', saved.First_Name__c);
        System.assertEquals('Smoke', saved.Last_Name__c);
    }
}
