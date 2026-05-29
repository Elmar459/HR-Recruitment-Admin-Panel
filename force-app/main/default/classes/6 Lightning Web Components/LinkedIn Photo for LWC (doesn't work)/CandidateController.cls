public with sharing class CandidateController {
    @AuraEnabled(cacheable=true)
    public static String getLinkedInUrl(Id candidateId) {
        Candidate__c cand = [SELECT LinkedIn_URL__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
        return cand.LinkedIn_URL__c;
    }
}