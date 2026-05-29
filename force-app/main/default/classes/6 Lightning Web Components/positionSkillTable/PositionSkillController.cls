public with sharing class PositionSkillController {
    @AuraEnabled(cacheable=true)
    public static List<Position_Skill__c> getPositionSkills(Id positionId) {
        if (positionId == null) {
            throw new AuraHandledException('Position ID is required');
        }
        return [
            SELECT Id, Name, Minimum_Level__c,
                   Weight__c, Is_Mandatory__c, Skill__c, Skill__r.Name
            FROM Position_Skill__c
            WHERE Position__c = :positionId
            ORDER BY Skill__r.Name ASC
        ];
    }
}