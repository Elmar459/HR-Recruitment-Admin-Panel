public class ExperienceScoringService {

    public static Decimal calculate(
        List<Candidate_Skill__c> candidateSkills,
        List<Position_Skill__c> positionSkills
    ) {

        Decimal requiredYears = 0;
        Decimal candidateYears = 0;

        // NULL safety
        if(positionSkills == null) {
            positionSkills = new List<Position_Skill__c>();
        }

        if(candidateSkills == null) {
            candidateSkills = new List<Candidate_Skill__c>();
        }

        // Position requirements
        for(Position_Skill__c ps : positionSkills) {

            if(
                ps.Is_Mandatory__c == true &&
                ps.Weight__c != null
            ) {

                requiredYears += ps.Weight__c;
            }
        }

        // Candidate experience
        for(Candidate_Skill__c cs : candidateSkills) {

            if(cs.Years_of_Experience_with_Skill__c != null) {

                candidateYears +=
                    cs.Years_of_Experience_with_Skill__c;
            }
        }

        // Avoid division by zero
        if(requiredYears == 0) {
            return 100;
        }

        Decimal ratio =
            candidateYears / requiredYears;

        Decimal score = 0;

        if(candidateYears >= requiredYears) {

            score = 100;

            if(ratio > 1.5) {
                score += 10;
            }

        } else {

            score = ratio * 100;
        }

        // Max cap
        if(score > 110) {
            score = 110;
        }

        return score;
    }
}