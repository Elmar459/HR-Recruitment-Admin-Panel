public with sharing class CandidateMatchingService {

    public static Decimal scoreApplication(Id applicationId) {

        Application__c app = [
        SELECT Id,
           Candidate__c,
           Candidate__r.Education_Level__c,
           Position__c,
           Position__r.Education_Level__c,
           Candidate__r.Expected_Salary__c,
           Position__r.Salary_Min__c,
           Position__r.Salary_Max__c,
           Candidate__r.Location__c,
           Candidate__r.Remote_Work__c,
           Position__r.Location__c,
           Position__r.Remote_Eligible__c
        FROM Application__c
        WHERE Id = :applicationId
        LIMIT 1
        ];

        // Fetch Candidate Skills
        List<Candidate_Skill__c> candidateSkills = [
            SELECT Id,
                   Skill__c,
                   Proficiency_Level__c,
                   Years_of_Experience_with_Skill__c
            FROM Candidate_Skill__c
            WHERE Candidate__c = :app.Candidate__c
        ];


        // Create a map of Candidate Skills for easy lookup
        Map<Id, Candidate_Skill__c> candidateSkillMap = new Map<Id, Candidate_Skill__c>();

        for(Candidate_Skill__c cs : candidateSkills) {
            candidateSkillMap.put(cs.Skill__c, cs);
        }

        // Fetch Position Skills
        List<Position_Skill__c> positionSkills = [
            SELECT Id,
                   Skill__c,
                   Weight__c,
                   Minimum_Level__c,
                   Is_Mandatory__c
            FROM Position_Skill__c
            WHERE Position__c = :app.Position__c
        ];

        // SKILLS Overlap (35%)
        Decimal skillsScore = SkillsScoringService.calculate(candidateSkillMap, positionSkills);

        // EXPERIENCE Level (25%)
        Decimal experienceScore = ExperienceScoringService.calculate(candidateSkills, positionSkills);

        // EDUCATION Fit (15%)
        Decimal educationScore = EducationScoringService.calculate(app.Candidate__r.Education_Level__c, app.Position__r.Education_Level__c);

        // Salary Fit (15%)
        Decimal salaryScore =
            SalaryScoringService.calculate(
            app.Candidate__r.Expected_Salary__c,
            app.Position__r.Salary_Min__c,
            app.Position__r.Salary_Max__c
        );

        // LOCATION Fit (10%)
        Decimal locationScore =
            LocationScoringService.calculate(
            app.Candidate__r.Location__c,
            app.Position__r.Location__c,
            app.Candidate__r.Remote_Work__c,
            app.Position__r.Remote_Eligible__c
        );

        // FINAL SCORE
        Decimal finalScore =
            (skillsScore * 0.35) +
            (experienceScore * 0.25) +
            (educationScore * 0.15)+
            (salaryScore * 0.15)+
            (locationScore * 0.10);

            finalScore = Math.min(finalScore, 100);

        app.Match_Score__c = finalScore;
        

    // For anonyous testing. Could be removed in production.
    System.debug('SKILLS = ' + skillsScore);
    System.debug('EXPERIENCE = ' + experienceScore);
    System.debug('EDUCATION = ' + educationScore);
    System.debug('SALARY = ' + salaryScore);
    System.debug('LOCATION = ' + locationScore);
    System.debug('FINAL SCORE = ' + finalScore);
    
        return finalScore;
    }
}