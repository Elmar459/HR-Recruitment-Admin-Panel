public with sharing class CandidateMatchingController {

    @AuraEnabled
    public static Decimal rescoreApplication(Id applicationId) {

        Decimal score =
            CandidateMatchingService.scoreApplication(applicationId);

        Application__c app = new Application__c(
            Id = applicationId,
            Match_Score__c = score
        );

        update app;

        return score;
    }
}