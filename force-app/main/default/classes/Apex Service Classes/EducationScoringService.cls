public class EducationScoringService {

    public static Decimal calculate( String candidateEducation, String requiredEducation) {

        Integer candidateLevel = getLevel(candidateEducation);
        Integer requiredLevel  = getLevel(requiredEducation);

        if(candidateLevel >= requiredLevel) { return 100; }

        if(candidateLevel == requiredLevel - 1) { return 60; }

        return 0;
    }

    private static Integer getLevel(String edu) {

        if(edu == null) return 0;

    switch on edu {
        when 'High School' { return 1; }
        when 'Associate' { return 2; }
        when 'Bachelor' { return 3; }       
        when 'Master' { return 4; }     
        when 'PhD' { return 5; }
        when else { return 0; }
    }
}
}