public with sharing class MatchScoringContext {
    public Map<Id, Application__c> applicationsById { get; private set; }
    public Map<Id, List<Candidate_Skill__c>> candidateSkills { get; private set; }
    public Map<Id, Map<Id, Candidate_Skill__c>> candidateSkillMaps { get; private set; }
    public Map<Id, List<Position_Skill__c>> positionSkills { get; private set; }

    public MatchScoringContext(Set<Id> applicationIds) {
        applicationsById = new Map<Id, Application__c>();
        candidateSkills = new Map<Id, List<Candidate_Skill__c>>();
        candidateSkillMaps = new Map<Id, Map<Id, Candidate_Skill__c>>();
        positionSkills = new Map<Id, List<Position_Skill__c>>();
        load(applicationIds);
    }

    private void load(Set<Id> applicationIds) {
        if (applicationIds == null || applicationIds.isEmpty()) {
            return;
        }

        applicationsById = new Map<Id, Application__c>([
            SELECT Id, Candidate__c, Position__c, Status__c,
                   Candidate__r.Education_Level__c,
                   Candidate__r.Expected_Salary__c,
                   Candidate__r.Location__c,
                   Candidate__r.Remote_Work__c,
                   Position__r.Education_Level__c,
                   Position__r.Salary_Min__c,
                   Position__r.Salary_Max__c,
                   Position__r.Location__c,
                   Position__r.Remote_Eligible__c
            FROM Application__c
            WHERE Id IN :applicationIds
        ]);

        Set<Id> candidateIds = new Set<Id>();
        Set<Id> positionIds = new Set<Id>();
        for (Application__c item : applicationsById.values()) {
            candidateIds.add(item.Candidate__c);
            positionIds.add(item.Position__c);
        }

        loadCandidateSkills(candidateIds);
        loadPositionSkills(positionIds);
    }

    private void loadCandidateSkills(Set<Id> candidateIds) {
        for (Candidate_Skill__c skill : [
            SELECT Id, Candidate__c, Skill__c, Proficiency_Level__c,
                   Years_of_Experience_with_Skill__c
            FROM Candidate_Skill__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (!candidateSkills.containsKey(skill.Candidate__c)) {
                candidateSkills.put(skill.Candidate__c, new List<Candidate_Skill__c>());
                candidateSkillMaps.put(skill.Candidate__c, new Map<Id, Candidate_Skill__c>());
            }
            candidateSkills.get(skill.Candidate__c).add(skill);
            candidateSkillMaps.get(skill.Candidate__c).put(skill.Skill__c, skill);
        }
    }

    private void loadPositionSkills(Set<Id> positionIds) {
        for (Position_Skill__c skill : [
            SELECT Id, Position__c, Skill__c, Weight__c,
                   Minimum_Level__c, Is_Mandatory__c
            FROM Position_Skill__c
            WHERE Position__c IN :positionIds
        ]) {
            if (!positionSkills.containsKey(skill.Position__c)) {
                positionSkills.put(skill.Position__c, new List<Position_Skill__c>());
            }
            positionSkills.get(skill.Position__c).add(skill);
        }
    }
}
