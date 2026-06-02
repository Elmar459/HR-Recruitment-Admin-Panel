public with sharing class CandidateSkillController {
    @AuraEnabled(cacheable=true)
    public static List<Candidate_Skill__c> getCandidateSkills(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required');
        }
        return [
            SELECT Id, Name, Skill__c, Skill__r.Name, Proficiency_Level__c,
                   Years_of_Experience_with_Skill__c, Is_Verified__c,
                   Verified_By__c, Verified_By__r.Name,
                   CreatedBy.Name, LastModifiedBy.Name
            FROM Candidate_Skill__c
            WHERE Candidate__c = :candidateId
            ORDER BY Skill__r.Name ASC
        ];
    }
}