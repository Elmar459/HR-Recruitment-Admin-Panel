public with sharing class CandidateComparisonController {
    
    public class CandidateComparisonData {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal matchScore;
        @AuraEnabled public Decimal yearsOfExperience;
        @AuraEnabled public Decimal expectedSalary;
        @AuraEnabled public String stage;
        @AuraEnabled public Boolean slaBreached;
        @AuraEnabled public Decimal avgInterviewScore;
        @AuraEnabled public List<SkillData> skills;
    }
    
    public class SkillData {
        @AuraEnabled public String skillName;
        @AuraEnabled public String category;
        @AuraEnabled public Decimal proficiency;
    }

    @AuraEnabled(cacheable=true)
    public static List<CandidateComparisonData> getCandidatesForPosition(String positionId) {
        if (String.isBlank(positionId)) {
            return new List<CandidateComparisonData>();
        }
        
        List<CandidateComparisonData> result = new List<CandidateComparisonData>();
        
        try {
            List<Application__c> apps = [
                SELECT Id, Candidate__c, Candidate__r.Name, Candidate__r.Years_of_Experience__c,
                       Candidate__r.Expected_Salary__c, Match_Score__c, Status__c, SLA_Breach__c
                FROM Application__c
                WHERE Position__c = :positionId 
                AND Status__c NOT IN ('Hired','Rejected','Withdrawn')
                ORDER BY Match_Score__c DESC
            ];
            
            if (apps.isEmpty()) return result;
            
            Set<Id> candidateIds = new Set<Id>();
            for (Application__c app : apps) candidateIds.add(app.Candidate__c);
            
            Map<Id, List<SkillData>> skillsMap = getCandidateSkills(candidateIds);
            Map<Id, Decimal> avgScores = getAverageInterviewScores(candidateIds);
            
            for (Application__c app : apps) {
                CandidateComparisonData d = new CandidateComparisonData();
                d.id = app.Candidate__c;
                d.name = app.Candidate__r.Name;
                d.matchScore = app.Match_Score__c;
                d.yearsOfExperience = app.Candidate__r.Years_of_Experience__c;
                d.expectedSalary = app.Candidate__r.Expected_Salary__c;
                d.stage = app.Status__c;
                d.slaBreached = app.SLA_Breach__c;
                d.avgInterviewScore = avgScores.get(app.Candidate__c);
                d.skills = skillsMap.get(app.Candidate__c);
                result.add(d);
            }
        } catch (Exception e) {
            throw new AuraHandledException('getCandidatesForPosition error: ' + e.getMessage());
        }
        return result;
    }
    
    @AuraEnabled
    public static List<CandidateComparisonData> getComparisonData(List<String> candidateIds) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            return new List<CandidateComparisonData>();
        }
        
        List<CandidateComparisonData> result = new List<CandidateComparisonData>();
        
        try {
            List<Candidate__c> candidates = [
                SELECT Id, Name, Years_of_Experience__c, Expected_Salary__c
                FROM Candidate__c
                WHERE Id IN :candidateIds
            ];
            
            // Получаем последнюю заявку для каждого кандидата
            Map<Id, Application__c> lastAppMap = new Map<Id, Application__c>();
            for (Application__c app : [
                SELECT Candidate__c, Match_Score__c, Status__c, SLA_Breach__c
                FROM Application__c
                WHERE Candidate__c IN :candidateIds
                AND Status__c NOT IN ('Hired','Rejected','Withdrawn')
                ORDER BY CreatedDate DESC
            ]) {
                if (!lastAppMap.containsKey(app.Candidate__c)) {
                    lastAppMap.put(app.Candidate__c, app);
                }
            }
            
            // Преобразуем List<String> в Set<Id>
            Set<Id> candidateIdSet = new Set<Id>();
            for (String idStr : candidateIds) {
                candidateIdSet.add((Id) idStr);
            }
            
            Map<Id, List<SkillData>> skillsMap = getCandidateSkills(candidateIdSet);
            Map<Id, Decimal> avgScores = getAverageInterviewScores(candidateIdSet);
            
            for (Candidate__c cand : candidates) {
                CandidateComparisonData d = new CandidateComparisonData();
                d.id = cand.Id;
                d.name = cand.Name;
                d.yearsOfExperience = cand.Years_of_Experience__c;
                d.expectedSalary = cand.Expected_Salary__c;
                d.avgInterviewScore = avgScores.get(cand.Id);
                d.skills = skillsMap.get(cand.Id);
                
                Application__c app = lastAppMap.get(cand.Id);
                if (app != null) {
                    d.matchScore = app.Match_Score__c;
                    d.stage = app.Status__c;
                    d.slaBreached = app.SLA_Breach__c;
                }
                result.add(d);
            }
        } catch (Exception e) {
            throw new AuraHandledException('getComparisonData error: ' + e.getMessage());
        }
        return result;
    }
    
    private static Map<Id, List<SkillData>> getCandidateSkills(Set<Id> candidateIds) {
        Map<Id, List<SkillData>> result = new Map<Id, List<SkillData>>();
        for (Candidate_Skill__c cs : [
            SELECT Candidate__c, Skill__r.Name, Skill__r.Category__c, Proficiency_Level__c
            FROM Candidate_Skill__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            SkillData sd = new SkillData();
            sd.skillName = cs.Skill__r.Name;
            sd.category = cs.Skill__r.Category__c;
            sd.proficiency = convertProficiencyToDecimal(cs.Proficiency_Level__c);
            if (!result.containsKey(cs.Candidate__c)) {
                result.put(cs.Candidate__c, new List<SkillData>());
            }
            result.get(cs.Candidate__c).add(sd);
        }
        return result;
    }
    
    private static Decimal convertProficiencyToDecimal(String proficiency) {
        if (String.isBlank(proficiency)) return 0;
        String lower = proficiency.toLowerCase();
        if (lower.contains('beginner')) return 1;
        if (lower.contains('intermediate')) return 2;
        if (lower.contains('advanced')) return 3;
        if (lower.contains('expert')) return 4;
        if (lower.contains('master')) return 5;
        try {
            return Decimal.valueOf(proficiency);
        } catch (Exception e) {
            return 0;
        }
    }
    
    private static Map<Id, Decimal> getAverageInterviewScores(Set<Id> candidateIds) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        try {
            for (Interview_Feedback__c fb : [
                SELECT Interview__r.Application__r.Candidate__c, Composite_Score__c
                FROM Interview_Feedback__c
                WHERE Interview__r.Application__r.Candidate__c IN :candidateIds
                AND Composite_Score__c != null
                ORDER BY Interview__r.Date_Time__c DESC
            ]) {
                Id candId = fb.Interview__r.Application__r.Candidate__c;
                if (!result.containsKey(candId)) {
                    result.put(candId, fb.Composite_Score__c);
                }
            }
        } catch (Exception e) {
            // Игнорируем ошибки доступа к полям или связям
            System.debug('getAverageInterviewScores error: ' + e.getMessage());
        }
        return result;
    }
}