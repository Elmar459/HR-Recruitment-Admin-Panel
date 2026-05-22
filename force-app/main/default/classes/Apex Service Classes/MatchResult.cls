public class MatchResult {
    @AuraEnabled public Id applicationId { get; set; }
    @AuraEnabled public Id candidateId { get; set; }
    @AuraEnabled public Id positionId { get; set; }
    @AuraEnabled public Decimal matchScore { get; set; }
    @AuraEnabled public String matchPercentage { get; set; }
    @AuraEnabled public String matchLevel { get; set; }
    @AuraEnabled public List<CriterionScore> breakdown { get; set; }
    @AuraEnabled public List<String> missingSkills { get; set; }
    @AuraEnabled public String summary { get; set; }

    public MatchResult() {
        matchScore = 0;
        matchPercentage = '0%';
        matchLevel = 'No Match';
        breakdown = new List<CriterionScore>();
        missingSkills = new List<String>();
        summary = '';
    }

    public void addScore(String name, Decimal rawScore, Decimal weight) {
        breakdown.add(new CriterionScore(name, rawScore, weight));
    }

    public void finish() {
        Decimal total = 0;
        for (CriterionScore item : breakdown) {
            total += item.weightedScore;
        }
        matchScore = Math.min(100, total.setScale(2));
        matchPercentage = String.valueOf(matchScore) + '%';
        matchLevel = matchScore >= 80 ? 'Strong' : matchScore >= 60 ? 'Good' : 'Weak';
        summary = matchLevel + ' match with ' + matchPercentage + ' total score.';
    }
}
