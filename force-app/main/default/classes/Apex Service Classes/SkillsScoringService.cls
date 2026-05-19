public class SkillsScoringService {

    public static Decimal calculate(Map<Id, Candidate_Skill__c> candidateSkillMap,List<Position_Skill__c> positionSkills) {

        Decimal totalWeight = 0;
        Decimal earnedScore = 0;

        for(Position_Skill__c ps : positionSkills) {

            totalWeight += ps.Weight__c;

            if(candidateSkillMap.containsKey(ps.Skill__c)) {

                Candidate_Skill__c cs = candidateSkillMap.get(ps.Skill__c);

                Integer candidateLevel = getLevel(cs.Proficiency_Level__c);

                Integer requiredLevel = getLevel(ps.Minimum_Level__c);

                if(candidateLevel >= requiredLevel) {
                    earnedScore += ps.Weight__c;
                }
                else if(candidateLevel == requiredLevel - 1) {
                    earnedScore += ps.Weight__c * 0.5;
                }
            }
        }

        if(totalWeight == 0) return 0;

        return (earnedScore / totalWeight) * 100;
    }

    private static Integer getLevel(String level) {

        switch on level {
    when 'Beginner' {
        return 1;
    }
    when 'Intermediate' {
        return 2;
    }
    when 'Advanced' {
        return 3;
    }
    when 'Expert' {
        return 4;
    }
    when else {
        return 0;
    }
}
    }
}