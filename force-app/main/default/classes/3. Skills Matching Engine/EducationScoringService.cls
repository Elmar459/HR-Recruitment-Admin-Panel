public class EducationScoringService {

    public static Decimal calculate(
        String candidateEducation,
        String requiredEducation
    ) {

        Integer candidateLevel = getLevel(candidateEducation);
        Integer requiredLevel  = getLevel(requiredEducation);

        if(candidateLevel >= requiredLevel) {
            return 100;
        }

        if(candidateLevel == requiredLevel - 1) {
            return 60;
        }

        return 0;
    }

    private static Integer getLevel(String edu) {

        if(edu == 'High School') return 1;
        if(edu == 'Associate') return 2;
        if(edu == 'Bachelor') return 3;
        if(edu == 'Master') return 4;
        if(edu == 'PhD') return 5;

        return 0;
    }
}