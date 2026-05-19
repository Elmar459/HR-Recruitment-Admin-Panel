public class MatchResult {
    @AuraEnabled public Decimal matchScore { get; set; }
    @AuraEnabled public String matchPercentage { get; set; }
    @AuraEnabled public String matchLevel { get; set; }
    @AuraEnabled public List<SkillMatch> skillMatches { get; set; }
    @AuraEnabled public List<String> missingSkills { get; set; }
    @AuraEnabled public List<String> strengths { get; set; }
    @AuraEnabled public List<String> weaknesses { get; set; }
    @AuraEnabled public String summary { get; set; }

    public MatchResult() {
        this.matchScore = 0;
        this.matchPercentage = '0%';
        this.matchLevel = 'No Match';
        this.skillMatches = new List<SkillMatch>();
        this.missingSkills = new List<String>();
        this.strengths = new List<String>();
        this.weaknesses = new List<String>();
        this.summary = '';
    }

    public class SkillMatch {
        @AuraEnabled public String skillName { get; set; }
        @AuraEnabled public String candidateProficiency { get; set; }
        @AuraEnabled public Decimal candidateProficiencyValue { get; set; }
        @AuraEnabled public String requiredProficiency { get; set; }
        @AuraEnabled public Decimal requiredProficiencyValue { get; set; }
        @AuraEnabled public Decimal proficiencyGap { get; set; }
        @AuraEnabled public Boolean isMet { get; set; }
        @AuraEnabled public Decimal weight { get; set; }
        @AuraEnabled public Decimal score { get; set; }

        public SkillMatch(String skillName, String candidateProficiency, Decimal candidateProficiencyValue,
                          String requiredProficiency, Decimal requiredProficiencyValue, Decimal weight) {
            this.skillName = skillName;
            this.candidateProficiency = candidateProficiency;
            this.candidateProficiencyValue = candidateProficiencyValue;
            this.requiredProficiency = requiredProficiency;
            this.requiredProficiencyValue = requiredProficiencyValue;
            this.weight = weight;
            this.proficiencyGap = requiredProficiencyValue - candidateProficiencyValue;
            this.isMet = candidateProficiencyValue >= requiredProficiencyValue;
            this.score = 0;
        }
    }
}
