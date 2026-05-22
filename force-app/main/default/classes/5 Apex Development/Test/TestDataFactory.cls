@IsTest
public class TestDataFactory {
    public static Candidate__c candidate(String email) {
        return new Candidate__c(
            First_Name__c = 'Test',
            Last_Name__c = 'Candidate',
            Email__c = email,
            Phone__c = '555-0100',
            Status__c = 'Active',
            Education_Level__c = 'Bachelor',
            Expected_Salary__c = 90000,
            Location__c = 'Baku',
            Remote_Work__c = true
        );
    }

    public static Position__c position() {
        return new Position__c(
            Department__c = 'IT',
            Status__c = 'Open',
            Education_Level__c = 'Bachelor',
            Headcount__c = 1,
            Priority__c = 'High',
            Open_Date__c = Date.today(),
            Salary_Min__c = 80000,
            Salary_Max__c = 100000,
            Location__c = 'Baku',
            Remote_Eligible__c = true
        );
    }

    public static Candidate_Skill__c candidateSkill(Id candidateId, Id skillId) {
        return new Candidate_Skill__c(
            Candidate__c = candidateId,
            Skill__c = skillId,
            Proficiency_Level__c = 'Advanced',
            Years_of_Experience_with_Skill__c = 4
        );
    }

    public static Position_Skill__c positionSkill(Id positionId, Id skillId) {
        return new Position_Skill__c(
            Position__c = positionId,
            Skill__c = skillId,
            Weight__c = 4,
            Minimum_Level__c = 'Intermediate',
            Is_Mandatory__c = true
        );
    }

    public static Skill__c skill() {
        return new Skill__c(
            Name = 'Apex',
            Category__c = 'Technical',
            Level__c = 'Advanced'
        );
    }

    public static Application__c application(Id candidateId, Id positionId) {
        return new Application__c(
            Candidate__c = candidateId,
            Position__c = positionId,
            Status__c = 'New',
            Applied_Date__c = Date.today()
        );
    }
}
