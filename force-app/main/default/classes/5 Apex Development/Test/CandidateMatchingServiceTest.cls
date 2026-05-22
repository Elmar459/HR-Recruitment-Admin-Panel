@IsTest
private class CandidateMatchingServiceTest {
    @IsTest
    static void scoresIndividualCriteria() {
        Map<Id, Candidate_Skill__c> candidateSkills = new Map<Id, Candidate_Skill__c>();
        Id skillId = Id.valueOf('a01000000000001AAA');
        candidateSkills.put(skillId, new Candidate_Skill__c(
            Skill__c = skillId,
            Proficiency_Level__c = 'Advanced',
            Years_of_Experience_with_Skill__c = 4
        ));

        List<Position_Skill__c> positionSkills = new List<Position_Skill__c>{
            new Position_Skill__c(
                Skill__c = skillId,
                Weight__c = 4,
                Minimum_Level__c = 'Intermediate',
                Is_Mandatory__c = true
            )
        };

        System.assertEquals(100, SkillsScoringService.calculate(candidateSkills, positionSkills));
        System.assert(EducationScoringService.calculate('Master', 'Bachelor') > 0);
        System.assert(SalaryScoringService.calculate(90000, 80000, 100000) == 100);
        System.assert(LocationScoringService.calculate('Baku', 'Baku', false, false) == 100);
    }
}
