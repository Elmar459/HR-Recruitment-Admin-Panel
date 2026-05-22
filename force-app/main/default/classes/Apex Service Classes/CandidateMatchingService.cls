public with sharing class CandidateMatchingService {
    public static Decimal scoreApplication(Id applicationId) {
        MatchResult result = getMatchDetails(applicationId);
        update new Application__c(Id = applicationId, Match_Score__c = result.matchScore);
        return result.matchScore;
    }

    public static void scoreAllApplicationsForPosition(Id positionId) {
        List<Application__c> apps = [
            SELECT Id FROM Application__c
            WHERE Position__c = :positionId AND Status__c NOT IN ('Hired', 'Rejected')
        ];
        updateScores(scoreApplications(new Map<Id, Application__c>(apps).keySet()));
    }

    @AuraEnabled(cacheable=true)
    public static MatchResult getMatchDetails(Id applicationId) {
        Map<Id, MatchResult> results = scoreApplications(new Set<Id>{ applicationId });
        return results.containsKey(applicationId) ? results.get(applicationId) : new MatchResult();
    }

    @AuraEnabled(cacheable=true)
    public static List<MatchResult> getTopCandidates(Id positionId, Decimal minScore, Integer rowLimit) {
        List<Application__c> apps = [
            SELECT Id FROM Application__c
            WHERE Position__c = :positionId AND Status__c NOT IN ('Hired', 'Rejected')
            LIMIT 200
        ];
        List<MatchResult> results = sortByScore(scoreApplications(
            new Map<Id, Application__c>(apps).keySet()).values());
        Integer maxRows = rowLimit == null ? 10 : rowLimit;
        List<MatchResult> filtered = new List<MatchResult>();
        for (MatchResult item : results) {
            if ((minScore == null || item.matchScore >= minScore) && filtered.size() < maxRows) {
                filtered.add(item);
            }
        }
        return filtered;
    }

    public static Map<Id, MatchResult> scoreApplications(Set<Id> applicationIds) {
        MatchScoringContext context = new MatchScoringContext(applicationIds);
        Map<Id, MatchResult> results = new Map<Id, MatchResult>();
        for (Application__c app : context.applicationsById.values()) {
            results.put(app.Id, scoreOne(app, context));
        }
        return results;
    }

    public static void updateScores(Map<Id, MatchResult> results) {
        List<Application__c> updates = new List<Application__c>();
        for (Id appId : results.keySet()) {
            updates.add(new Application__c(Id = appId, Match_Score__c = results.get(appId).matchScore));
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static MatchResult scoreOne(Application__c app, MatchScoringContext context) {
        List<Candidate_Skill__c> cSkills = context.candidateSkills.get(app.Candidate__c);
        List<Position_Skill__c> pSkills = context.positionSkills.get(app.Position__c);
        Map<Id, Candidate_Skill__c> skillMap = context.candidateSkillMaps.get(app.Candidate__c);
        if (cSkills == null) cSkills = new List<Candidate_Skill__c>();
        if (pSkills == null) pSkills = new List<Position_Skill__c>();
        if (skillMap == null) skillMap = new Map<Id, Candidate_Skill__c>();

        MatchResult result = new MatchResult();
        result.applicationId = app.Id;
        result.candidateId = app.Candidate__c;
        result.positionId = app.Position__c;
        result.addScore('Skills', SkillsScoringService.calculate(skillMap, pSkills), 0.35);
        result.addScore('Experience', ExperienceScoringService.calculate(cSkills, pSkills), 0.25);
        result.addScore('Education', EducationScoringService.calculate(
            app.Candidate__r.Education_Level__c, app.Position__r.Education_Level__c), 0.15);
        result.addScore('Salary', SalaryScoringService.calculate(
            app.Candidate__r.Expected_Salary__c, app.Position__r.Salary_Min__c,
            app.Position__r.Salary_Max__c), 0.15);
        result.addScore('Location', LocationScoringService.calculate(
            app.Candidate__r.Location__c, app.Position__r.Location__c,
            app.Candidate__r.Remote_Work__c, app.Position__r.Remote_Eligible__c), 0.10);
        addMissingSkills(result, skillMap, pSkills);
        result.finish();
        return result;
    }

    private static void addMissingSkills(MatchResult result, Map<Id, Candidate_Skill__c> skills,
                                         List<Position_Skill__c> positionSkills) {
        for (Position_Skill__c item : positionSkills) {
            if (item.Is_Mandatory__c == true && !skills.containsKey(item.Skill__c)) {
                result.missingSkills.add(String.valueOf(item.Skill__c));
            }
        }
    }

    private static List<MatchResult> sortByScore(List<MatchResult> items) {
        List<MatchResult> sorted = new List<MatchResult>();
        for (MatchResult item : items) {
            Integer insertAt = sorted.size();
            for (Integer i = 0; i < sorted.size(); i++) {
                if (item.matchScore > sorted[i].matchScore) {
                    insertAt = i;
                    break;
                }
            }
            sorted.add(insertAt, item);
        }
        return sorted;
    }
}
