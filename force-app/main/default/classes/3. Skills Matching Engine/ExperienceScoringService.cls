public class ExperienceScoringService {

    public static Decimal calculate(
        List<Candidate_Skill__c> candidateSkills,
        List<Position_Skill__c> positionSkills
    ) {

        Decimal requiredYears = 0;
        Decimal candidateYears = 0;

        for(Position_Skill__c ps : positionSkills) {
            if(ps.Is_Mandatory__c == true) {
                requiredYears += ps.Weight__c;
            }
        }

        for(Candidate_Skill__c cs : candidateSkills) {
            candidateYears += cs.Years_of_Experience_with_Skill__c;
        }

        if(requiredYears == 0) return 100;

        Decimal ratio = candidateYears / requiredYears;
        Decimal score = 0;

        if(candidateYears >= requiredYears) {
            score = 100;

            if(ratio > 1.5) {
                score += 10;
            }
        } else {
            score = ratio * 100;
        }

        if(score > 110) score = 110;

        return score;
    }
}