public class CriterionScore {
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public Decimal rawScore { get; set; }
    @AuraEnabled public Decimal weight { get; set; }
    @AuraEnabled public Decimal weightedScore { get; set; }

    public CriterionScore(String name, Decimal rawScore, Decimal weight) {
        this.name = name;
        this.rawScore = rawScore == null ? 0 : rawScore;
        this.weight = weight == null ? 0 : weight;
        this.weightedScore = (this.rawScore * this.weight).setScale(2);
    }
}